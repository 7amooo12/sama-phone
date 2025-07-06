-- Electronic Payment System Migration - Simple Version
-- This script creates tables without complex RLS dependencies
-- Use this if you're having issues with user_profiles table

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

CREATE INDEX IF NOT EXISTS idx_payment_accounts_type ON public.payment_accounts(account_type);
CREATE INDEX IF NOT EXISTS idx_payment_accounts_active ON public.payment_accounts(is_active);
CREATE INDEX IF NOT EXISTS idx_electronic_payments_client ON public.electronic_payments(client_id);
CREATE INDEX IF NOT EXISTS idx_electronic_payments_status ON public.electronic_payments(status);
CREATE INDEX IF NOT EXISTS idx_electronic_payments_method ON public.electronic_payments(payment_method);
CREATE INDEX IF NOT EXISTS idx_electronic_payments_created ON public.electronic_payments(created_at);
CREATE INDEX IF NOT EXISTS idx_electronic_payments_recipient ON public.electronic_payments(recipient_account_id);

-- ============================================================================
-- STEP 3: Enable Row Level Security
-- ============================================================================

ALTER TABLE public.payment_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.electronic_payments ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 4: Create Simple RLS Policies (No user_profiles dependency)
-- ============================================================================

-- Drop existing policies if they exist
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Clients can view active payment accounts" ON public.payment_accounts;
    DROP POLICY IF EXISTS "Admins can manage payment accounts" ON public.payment_accounts;
    DROP POLICY IF EXISTS "Clients can view own payments" ON public.electronic_payments;
    DROP POLICY IF EXISTS "Clients can create own payments" ON public.electronic_payments;
    DROP POLICY IF EXISTS "Clients can update own pending payments" ON public.electronic_payments;
    DROP POLICY IF EXISTS "Admins can view all payments" ON public.electronic_payments;
    DROP POLICY IF EXISTS "Admins can update payment status" ON public.electronic_payments;
EXCEPTION
    WHEN OTHERS THEN
        NULL; -- Ignore errors if policies don't exist
END $$;

-- Payment Accounts Policies (Simple - all authenticated users can view active accounts)
CREATE POLICY "Clients can view active payment accounts"
ON public.payment_accounts FOR SELECT
TO authenticated
USING (is_active = true);

-- Allow all authenticated users to manage payment accounts for now
CREATE POLICY "Authenticated users can manage payment accounts"
ON public.payment_accounts FOR ALL
TO authenticated
USING (true);

-- Electronic Payments Policies
-- Clients can view their own payments
CREATE POLICY "Clients can view own payments"
ON public.electronic_payments FOR SELECT
TO authenticated
USING (client_id = auth.uid());

-- Clients can create their own payments
CREATE POLICY "Clients can create own payments"
ON public.electronic_payments FOR INSERT
TO authenticated
WITH CHECK (client_id = auth.uid());

-- Clients can update their own pending payments
CREATE POLICY "Clients can update own pending payments"
ON public.electronic_payments FOR UPDATE
TO authenticated
USING (client_id = auth.uid() AND status = 'pending')
WITH CHECK (client_id = auth.uid() AND status = 'pending');

-- Allow all authenticated users to view all payments (can be restricted later)
CREATE POLICY "Authenticated users can view all payments"
ON public.electronic_payments FOR SELECT
TO authenticated
USING (true);

-- Allow all authenticated users to update payment status (can be restricted later)
CREATE POLICY "Authenticated users can update payment status"
ON public.electronic_payments FOR UPDATE
TO authenticated
USING (true);

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
-- STEP 7: Verification and Success Message
-- ============================================================================

DO $$
DECLARE
    payment_accounts_count INTEGER;
    electronic_payments_count INTEGER;
    default_accounts_count INTEGER;
    policies_count INTEGER;
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
    
    -- Check policies
    SELECT COUNT(*) INTO policies_count
    FROM pg_policies 
    WHERE tablename IN ('payment_accounts', 'electronic_payments')
    AND schemaname = 'public';
    
    -- Report results
    IF payment_accounts_count = 0 THEN
        RAISE EXCEPTION 'FAILED: payment_accounts table was not created';
    END IF;
    
    IF electronic_payments_count = 0 THEN
        RAISE EXCEPTION 'FAILED: electronic_payments table was not created';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🚀 ELECTRONIC PAYMENT SYSTEM MIGRATION SUCCESSFUL!';
    RAISE NOTICE '================================================';
    RAISE NOTICE '✅ Tables created: payment_accounts, electronic_payments';
    RAISE NOTICE '✅ RLS enabled on both tables';
    RAISE NOTICE '✅ Simple RLS policies created (% policies)', policies_count;
    RAISE NOTICE '✅ Indexes created for performance';
    RAISE NOTICE '✅ Update triggers configured';
    RAISE NOTICE '✅ Default payment accounts: %', default_accounts_count;
    RAISE NOTICE '';
    RAISE NOTICE '📋 NEXT STEPS:';
    RAISE NOTICE '1. Test your Flutter app - electronic payment errors should be resolved';
    RAISE NOTICE '2. Run TEST_ELECTRONIC_PAYMENT_TABLES.sql to verify everything works';
    RAISE NOTICE '3. If you have user_profiles table, you can later update RLS policies for better security';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  NOTE: Current RLS policies are permissive for testing.';
    RAISE NOTICE '   Consider restricting admin access once user_profiles is properly configured.';
    RAISE NOTICE '';
END $$;

-- Display final status
SELECT 
    'MIGRATION COMPLETE' as status,
    'payment_accounts' as table_name,
    COUNT(*) as record_count
FROM public.payment_accounts
UNION ALL
SELECT 
    'MIGRATION COMPLETE' as status,
    'electronic_payments' as table_name,
    COUNT(*) as record_count
FROM public.electronic_payments;
