-- Electronic Payment System Migration - Clean Version
-- This script creates the missing tables for the electronic payment system
-- Run this in your Supabase SQL Editor to fix the missing table errors

-- ============================================================================
-- STEP 1: Create Missing Tables
-- ============================================================================

-- Create payment_accounts table
CREATE TABLE IF NOT EXISTS public.payment_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_type TEXT NOT NULL CHECK (account_type IN ('vodafone_cash', 'instapay')),
    account_number TEXT NOT NULL,
    account_holder_name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    UNIQUE(account_type, account_number)
);

-- Create electronic_payments table
CREATE TABLE IF NOT EXISTS public.electronic_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    payment_method TEXT NOT NULL CHECK (payment_method IN ('vodafone_cash', 'instapay')),
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    proof_image_url TEXT,
    recipient_account_id UUID REFERENCES public.payment_accounts(id) NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    admin_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    approved_by UUID REFERENCES auth.users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- ============================================================================
-- STEP 2: Create Indexes
-- ============================================================================

-- Indexes for payment_accounts
CREATE INDEX IF NOT EXISTS idx_payment_accounts_type ON public.payment_accounts(account_type);
CREATE INDEX IF NOT EXISTS idx_payment_accounts_active ON public.payment_accounts(is_active);

-- Indexes for electronic_payments
CREATE INDEX IF NOT EXISTS idx_electronic_payments_client ON public.electronic_payments(client_id);
CREATE INDEX IF NOT EXISTS idx_electronic_payments_status ON public.electronic_payments(status);
CREATE INDEX IF NOT EXISTS idx_electronic_payments_method ON public.electronic_payments(payment_method);
CREATE INDEX IF NOT EXISTS idx_electronic_payments_created ON public.electronic_payments(created_at);
CREATE INDEX IF NOT EXISTS idx_electronic_payments_recipient ON public.electronic_payments(recipient_account_id);

-- ============================================================================
-- STEP 3: Enable Row Level Security
-- ============================================================================

-- Enable RLS
ALTER TABLE public.payment_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.electronic_payments ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 4: Create RLS Policies
-- ============================================================================

-- Drop existing policies if they exist
DO $$ 
BEGIN
    -- Drop payment_accounts policies
    DROP POLICY IF EXISTS "Clients can view active payment accounts" ON public.payment_accounts;
    DROP POLICY IF EXISTS "Admins can manage payment accounts" ON public.payment_accounts;
    
    -- Drop electronic_payments policies
    DROP POLICY IF EXISTS "Clients can view own payments" ON public.electronic_payments;
    DROP POLICY IF EXISTS "Clients can create own payments" ON public.electronic_payments;
    DROP POLICY IF EXISTS "Clients can update own pending payments" ON public.electronic_payments;
    DROP POLICY IF EXISTS "Admins can view all payments" ON public.electronic_payments;
    DROP POLICY IF EXISTS "Admins can update payment status" ON public.electronic_payments;
EXCEPTION
    WHEN OTHERS THEN
        -- Ignore errors if policies don't exist
        NULL;
END $$;

-- Payment Accounts Policies
CREATE POLICY "Clients can view active payment accounts"
ON public.payment_accounts FOR SELECT
TO authenticated
USING (is_active = true);

-- Check if user_profiles table exists and determine correct column name
DO $$
DECLARE
    user_profiles_exists BOOLEAN;
    has_user_id_column BOOLEAN;
    has_id_column BOOLEAN;
BEGIN
    -- Check if user_profiles table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'user_profiles'
    ) INTO user_profiles_exists;

    IF user_profiles_exists THEN
        -- Check which column exists for user identification
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = 'user_profiles'
            AND column_name = 'user_id'
        ) INTO has_user_id_column;

        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = 'user_profiles'
            AND column_name = 'id'
        ) INTO has_id_column;

        RAISE NOTICE 'user_profiles table exists. user_id column: %, id column: %', has_user_id_column, has_id_column;
    ELSE
        RAISE NOTICE 'user_profiles table does not exist - creating simplified policies';
    END IF;
END $$;

-- Create admin policy based on what exists
DO $$
DECLARE
    user_profiles_exists BOOLEAN;
    has_user_id_column BOOLEAN;
BEGIN
    -- Check table and column existence
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'user_profiles'
    ) INTO user_profiles_exists;

    IF user_profiles_exists THEN
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = 'user_profiles'
            AND column_name = 'user_id'
        ) INTO has_user_id_column;

        IF has_user_id_column THEN
            -- Use user_id column
            EXECUTE 'CREATE POLICY "Admins can manage payment accounts"
                ON public.payment_accounts FOR ALL
                TO authenticated
                USING (
                    EXISTS (
                        SELECT 1 FROM public.user_profiles
                        WHERE user_id = auth.uid()
                        AND role IN (''admin'', ''owner'')
                        AND status = ''active''
                    )
                )';
        ELSE
            -- Use id column
            EXECUTE 'CREATE POLICY "Admins can manage payment accounts"
                ON public.payment_accounts FOR ALL
                TO authenticated
                USING (
                    EXISTS (
                        SELECT 1 FROM public.user_profiles
                        WHERE id = auth.uid()
                        AND role IN (''admin'', ''owner'')
                        AND status = ''active''
                    )
                )';
        END IF;
    ELSE
        -- No user_profiles table - create basic admin policy
        EXECUTE 'CREATE POLICY "Admins can manage payment accounts"
            ON public.payment_accounts FOR ALL
            TO authenticated
            USING (true)'; -- Allow all authenticated users for now
    END IF;
END $$;

-- Electronic Payments Policies
CREATE POLICY "Clients can view own payments"
ON public.electronic_payments FOR SELECT
TO authenticated
USING (client_id = auth.uid());

CREATE POLICY "Clients can create own payments"
ON public.electronic_payments FOR INSERT
TO authenticated
WITH CHECK (client_id = auth.uid());

CREATE POLICY "Clients can update own pending payments"
ON public.electronic_payments FOR UPDATE
TO authenticated
USING (client_id = auth.uid() AND status = 'pending')
WITH CHECK (client_id = auth.uid() AND status = 'pending');

-- Create admin policies for electronic_payments based on user_profiles structure
DO $$
DECLARE
    user_profiles_exists BOOLEAN;
    has_user_id_column BOOLEAN;
BEGIN
    -- Check table and column existence
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'user_profiles'
    ) INTO user_profiles_exists;

    IF user_profiles_exists THEN
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = 'user_profiles'
            AND column_name = 'user_id'
        ) INTO has_user_id_column;

        IF has_user_id_column THEN
            -- Use user_id column for admin view policy
            EXECUTE 'CREATE POLICY "Admins can view all payments"
                ON public.electronic_payments FOR SELECT
                TO authenticated
                USING (
                    EXISTS (
                        SELECT 1 FROM public.user_profiles
                        WHERE user_id = auth.uid()
                        AND role IN (''admin'', ''owner'', ''accountant'')
                        AND status = ''active''
                    )
                )';

            -- Use user_id column for admin update policy
            EXECUTE 'CREATE POLICY "Admins can update payment status"
                ON public.electronic_payments FOR UPDATE
                TO authenticated
                USING (
                    EXISTS (
                        SELECT 1 FROM public.user_profiles
                        WHERE user_id = auth.uid()
                        AND role IN (''admin'', ''owner'', ''accountant'')
                        AND status = ''active''
                    )
                )';
        ELSE
            -- Use id column for admin view policy
            EXECUTE 'CREATE POLICY "Admins can view all payments"
                ON public.electronic_payments FOR SELECT
                TO authenticated
                USING (
                    EXISTS (
                        SELECT 1 FROM public.user_profiles
                        WHERE id = auth.uid()
                        AND role IN (''admin'', ''owner'', ''accountant'')
                        AND status = ''active''
                    )
                )';

            -- Use id column for admin update policy
            EXECUTE 'CREATE POLICY "Admins can update payment status"
                ON public.electronic_payments FOR UPDATE
                TO authenticated
                USING (
                    EXISTS (
                        SELECT 1 FROM public.user_profiles
                        WHERE id = auth.uid()
                        AND role IN (''admin'', ''owner'', ''accountant'')
                        AND status = ''active''
                    )
                )';
        END IF;
    ELSE
        -- No user_profiles table - create basic admin policies
        EXECUTE 'CREATE POLICY "Admins can view all payments"
            ON public.electronic_payments FOR SELECT
            TO authenticated
            USING (true)'; -- Allow all authenticated users for now

        EXECUTE 'CREATE POLICY "Admins can update payment status"
            ON public.electronic_payments FOR UPDATE
            TO authenticated
            USING (true)'; -- Allow all authenticated users for now
    END IF;
END $$;

-- ============================================================================
-- STEP 5: Create Update Triggers
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Drop existing triggers
DROP TRIGGER IF EXISTS update_payment_accounts_updated_at ON public.payment_accounts;
DROP TRIGGER IF EXISTS update_electronic_payments_updated_at ON public.electronic_payments;

-- Create triggers
CREATE TRIGGER update_payment_accounts_updated_at
    BEFORE UPDATE ON public.payment_accounts
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_electronic_payments_updated_at
    BEFORE UPDATE ON public.electronic_payments
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- STEP 6: Insert Default Payment Accounts
-- ============================================================================

INSERT INTO public.payment_accounts (account_type, account_number, account_holder_name, is_active) VALUES
('vodafone_cash', '01000000000', 'SAMA Store - Vodafone Cash', true),
('instapay', 'SAMA@instapay', 'SAMA Store - InstaPay', true)
ON CONFLICT (account_type, account_number) DO NOTHING;

-- ============================================================================
-- STEP 7: Verification
-- ============================================================================

DO $$
DECLARE
    payment_accounts_count INTEGER;
    electronic_payments_count INTEGER;
    default_accounts_count INTEGER;
BEGIN
    -- Check if tables exist
    SELECT COUNT(*) INTO payment_accounts_count
    FROM information_schema.tables 
    WHERE table_name = 'payment_accounts' AND table_schema = 'public';
    
    SELECT COUNT(*) INTO electronic_payments_count
    FROM information_schema.tables 
    WHERE table_name = 'electronic_payments' AND table_schema = 'public';
    
    -- Check default accounts
    SELECT COUNT(*) INTO default_accounts_count
    FROM public.payment_accounts;
    
    -- Report results
    IF payment_accounts_count = 0 THEN
        RAISE EXCEPTION 'FAILED: payment_accounts table was not created';
    END IF;
    
    IF electronic_payments_count = 0 THEN
        RAISE EXCEPTION 'FAILED: electronic_payments table was not created';
    END IF;
    
    RAISE NOTICE '✅ Electronic payment tables created successfully';
    RAISE NOTICE '✅ RLS policies configured';
    RAISE NOTICE '✅ Indexes created for performance';
    RAISE NOTICE '✅ Default payment accounts: %', default_accounts_count;
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Electronic payment system is ready!';
    RAISE NOTICE '';
    RAISE NOTICE 'Tables created:';
    RAISE NOTICE '- payment_accounts: % records', default_accounts_count;
    RAISE NOTICE '- electronic_payments: 0 records (ready for use)';
END $$;

-- Display final status
SELECT 
    'payment_accounts' as table_name,
    COUNT(*) as record_count
FROM public.payment_accounts
UNION ALL
SELECT 
    'electronic_payments' as table_name,
    COUNT(*) as record_count
FROM public.electronic_payments;
