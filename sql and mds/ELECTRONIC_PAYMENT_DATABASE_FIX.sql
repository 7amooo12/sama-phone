-- Electronic Payment System Database Fix
-- This script creates the missing tables for the electronic payment system
-- Run this in your Supabase SQL Editor to fix the missing table errors

-- Begin transaction for atomicity
BEGIN;

-- ============================================================================
-- STEP 1: Create Missing Tables
-- ============================================================================

-- Create payment_accounts table for managing Vodafone Cash and InstaPay accounts
CREATE TABLE IF NOT EXISTS public.payment_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_type TEXT NOT NULL CHECK (account_type IN ('vodafone_cash', 'instapay')),
    account_number TEXT NOT NULL,
    account_holder_name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,

    -- Constraints
    UNIQUE(account_type, account_number)
);

-- Create electronic_payments table for tracking payment requests
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
-- STEP 2: Create Indexes for Performance
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
-- STEP 3: Enable Row Level Security (RLS)
-- ============================================================================

-- Enable RLS on payment_accounts
ALTER TABLE public.payment_accounts ENABLE ROW LEVEL SECURITY;

-- Enable RLS on electronic_payments
ALTER TABLE public.electronic_payments ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 4: Create RLS Policies
-- ============================================================================

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Clients can view active payment accounts" ON public.payment_accounts;
DROP POLICY IF EXISTS "Admins can manage payment accounts" ON public.payment_accounts;
DROP POLICY IF EXISTS "Clients can view own payments" ON public.electronic_payments;
DROP POLICY IF EXISTS "Clients can create own payments" ON public.electronic_payments;
DROP POLICY IF EXISTS "Clients can update own pending payments" ON public.electronic_payments;
DROP POLICY IF EXISTS "Admins can view all payments" ON public.electronic_payments;
DROP POLICY IF EXISTS "Admins can update payment status" ON public.electronic_payments;

-- Payment Accounts Policies
-- Clients can view active payment accounts
CREATE POLICY "Clients can view active payment accounts"
ON public.payment_accounts FOR SELECT
TO authenticated
USING (is_active = true);

-- Admins can manage all payment accounts
CREATE POLICY "Admins can manage payment accounts"
ON public.payment_accounts FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE user_id = auth.uid()
        AND role IN ('admin', 'owner')
        AND status = 'active'
    )
);

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

-- Admins can view all payments
CREATE POLICY "Admins can view all payments"
ON public.electronic_payments FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE user_id = auth.uid()
        AND role IN ('admin', 'owner', 'accountant')
        AND status = 'active'
    )
);

-- Admins can update payment status
CREATE POLICY "Admins can update payment status"
ON public.electronic_payments FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE user_id = auth.uid()
        AND role IN ('admin', 'owner', 'accountant')
        AND status = 'active'
    )
);

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

-- Trigger for payment_accounts
DROP TRIGGER IF EXISTS update_payment_accounts_updated_at ON public.payment_accounts;
CREATE TRIGGER update_payment_accounts_updated_at
    BEFORE UPDATE ON public.payment_accounts
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- Trigger for electronic_payments
DROP TRIGGER IF EXISTS update_electronic_payments_updated_at ON public.electronic_payments;
CREATE TRIGGER update_electronic_payments_updated_at
    BEFORE UPDATE ON public.electronic_payments
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- STEP 6: Insert Default Payment Accounts
-- ============================================================================

-- Insert default payment accounts (these can be updated by admins later)
INSERT INTO public.payment_accounts (account_type, account_number, account_holder_name, is_active) VALUES
('vodafone_cash', '01000000000', 'SAMA Store - Vodafone Cash', true),
('instapay', 'SAMA@instapay', 'SAMA Store - InstaPay', true)
ON CONFLICT (account_type, account_number) DO NOTHING;

-- ============================================================================
-- STEP 7: Verification
-- ============================================================================

-- Verify tables were created
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'payment_accounts' AND table_schema = 'public') THEN
        RAISE EXCEPTION 'FAILED: payment_accounts table was not created';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'electronic_payments' AND table_schema = 'public') THEN
        RAISE EXCEPTION 'FAILED: electronic_payments table was not created';
    END IF;

    RAISE NOTICE '✅ Electronic payment tables created successfully';
    RAISE NOTICE '✅ RLS policies configured';
    RAISE NOTICE '✅ Indexes created for performance';
    RAISE NOTICE '✅ Default payment accounts inserted';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Electronic payment system is ready!';
END $$;

-- Commit the transaction
COMMIT;

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
