-- ============================================================================
-- Electronic Wallet System Migration
-- This script creates the necessary tables for the comprehensive electronic wallet system
-- ============================================================================

-- Drop existing tables if they exist (for clean migration)
DROP TABLE IF EXISTS public.electronic_wallet_transactions CASCADE;
DROP TABLE IF EXISTS public.electronic_wallets CASCADE;

-- ============================================================================
-- STEP 1: Create Electronic Wallets Table
-- ============================================================================

-- Create electronic_wallets table for managing company electronic wallets
CREATE TABLE IF NOT EXISTS public.electronic_wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_type TEXT NOT NULL CHECK (wallet_type IN ('vodafone_cash', 'instapay')),
    phone_number TEXT NOT NULL,
    wallet_name TEXT NOT NULL,
    current_balance DECIMAL(12,2) DEFAULT 0.00 CHECK (current_balance >= 0),
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    created_by UUID REFERENCES auth.users(id),
    metadata JSONB DEFAULT '{}',

    -- Constraints
    UNIQUE(wallet_type, phone_number),
    CONSTRAINT valid_phone_number CHECK (
        phone_number ~ '^01[0125][0-9]{8}$'
    )
);

-- ============================================================================
-- STEP 2: Create Electronic Wallet Transactions Table
-- ============================================================================

-- Create electronic_wallet_transactions table for tracking wallet operations
CREATE TABLE IF NOT EXISTS public.electronic_wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id UUID REFERENCES public.electronic_wallets(id) ON DELETE CASCADE NOT NULL,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('deposit', 'withdrawal', 'transfer', 'payment', 'refund')),
    amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
    balance_before DECIMAL(12,2) NOT NULL CHECK (balance_before >= 0),
    balance_after DECIMAL(12,2) NOT NULL CHECK (balance_after >= 0),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'cancelled')),
    description TEXT,
    reference_id TEXT,
    payment_id UUID REFERENCES public.electronic_payments(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    processed_by UUID REFERENCES auth.users(id),
    metadata JSONB DEFAULT '{}'
);

-- ============================================================================
-- STEP 3: Update Electronic Payments Table
-- ============================================================================

-- Add new columns to electronic_payments table if they don't exist
DO $$
BEGIN
    -- Add sender_phone_number column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'electronic_payments'
        AND column_name = 'sender_phone_number'
    ) THEN
        ALTER TABLE public.electronic_payments 
        ADD COLUMN sender_phone_number TEXT;
    END IF;

    -- Add transaction_reference column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'electronic_payments'
        AND column_name = 'transaction_reference'
    ) THEN
        ALTER TABLE public.electronic_payments 
        ADD COLUMN transaction_reference TEXT;
    END IF;

    -- Add processed_at column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'electronic_payments'
        AND column_name = 'processed_at'
    ) THEN
        ALTER TABLE public.electronic_payments 
        ADD COLUMN processed_at TIMESTAMP WITH TIME ZONE;
    END IF;
END $$;

-- ============================================================================
-- STEP 4: Create Indexes for Performance
-- ============================================================================

-- Indexes for electronic_wallets
CREATE INDEX IF NOT EXISTS idx_electronic_wallets_wallet_type ON public.electronic_wallets(wallet_type);
CREATE INDEX IF NOT EXISTS idx_electronic_wallets_status ON public.electronic_wallets(status);
CREATE INDEX IF NOT EXISTS idx_electronic_wallets_phone_number ON public.electronic_wallets(phone_number);
CREATE INDEX IF NOT EXISTS idx_electronic_wallets_created_at ON public.electronic_wallets(created_at);

-- Indexes for electronic_wallet_transactions
CREATE INDEX IF NOT EXISTS idx_electronic_wallet_transactions_wallet_id ON public.electronic_wallet_transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_electronic_wallet_transactions_type ON public.electronic_wallet_transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_electronic_wallet_transactions_status ON public.electronic_wallet_transactions(status);
CREATE INDEX IF NOT EXISTS idx_electronic_wallet_transactions_created_at ON public.electronic_wallet_transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_electronic_wallet_transactions_payment_id ON public.electronic_wallet_transactions(payment_id);

-- Indexes for electronic_payments (new columns)
CREATE INDEX IF NOT EXISTS idx_electronic_payments_sender_phone ON public.electronic_payments(sender_phone_number);
CREATE INDEX IF NOT EXISTS idx_electronic_payments_transaction_ref ON public.electronic_payments(transaction_reference);
CREATE INDEX IF NOT EXISTS idx_electronic_payments_processed_at ON public.electronic_payments(processed_at);

-- ============================================================================
-- STEP 5: Create Triggers for Updated_at
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for electronic_wallets
DROP TRIGGER IF EXISTS update_electronic_wallets_updated_at ON public.electronic_wallets;
CREATE TRIGGER update_electronic_wallets_updated_at
    BEFORE UPDATE ON public.electronic_wallets
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Triggers for electronic_wallet_transactions
DROP TRIGGER IF EXISTS update_electronic_wallet_transactions_updated_at ON public.electronic_wallet_transactions;
CREATE TRIGGER update_electronic_wallet_transactions_updated_at
    BEFORE UPDATE ON public.electronic_wallet_transactions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- STEP 6: Insert Sample Data
-- ============================================================================

-- Insert sample electronic wallets
INSERT INTO public.electronic_wallets (wallet_type, phone_number, wallet_name, current_balance, status, description, created_by)
VALUES 
    ('vodafone_cash', '01012345678', 'محفظة فودافون كاش الرئيسية', 50000.00, 'active', 'المحفظة الرئيسية لاستقبال مدفوعات فودافون كاش', (SELECT id FROM auth.users WHERE email = 'admin@sama.com' LIMIT 1)),
    ('instapay', '01098765432', 'محفظة إنستاباي الرئيسية', 30000.00, 'active', 'المحفظة الرئيسية لاستقبال مدفوعات إنستاباي', (SELECT id FROM auth.users WHERE email = 'admin@sama.com' LIMIT 1)),
    ('vodafone_cash', '01155555555', 'محفظة فودافون كاش احتياطية', 10000.00, 'inactive', 'محفظة احتياطية للطوارئ', (SELECT id FROM auth.users WHERE email = 'admin@sama.com' LIMIT 1))
ON CONFLICT (wallet_type, phone_number) DO NOTHING;

-- ============================================================================
-- STEP 7: Create RLS Policies
-- ============================================================================

-- Enable RLS on electronic_wallets
ALTER TABLE public.electronic_wallets ENABLE ROW LEVEL SECURITY;

-- Policy for electronic_wallets - Admin and Accountant can manage all wallets
CREATE POLICY "electronic_wallets_admin_policy" ON public.electronic_wallets
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = auth.uid()
            AND up.role IN ('admin', 'accountant')
            AND up.status IN ('active', 'approved')
        )
    );

-- Policy for electronic_wallets - Read access for authenticated users
CREATE POLICY "electronic_wallets_read_policy" ON public.electronic_wallets
    FOR SELECT USING (
        auth.role() = 'authenticated'
    );

-- Enable RLS on electronic_wallet_transactions
ALTER TABLE public.electronic_wallet_transactions ENABLE ROW LEVEL SECURITY;

-- Policy for electronic_wallet_transactions - Admin and Accountant can manage all transactions
CREATE POLICY "electronic_wallet_transactions_admin_policy" ON public.electronic_wallet_transactions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = auth.uid()
            AND up.role IN ('admin', 'accountant')
            AND up.status IN ('active', 'approved')
        )
    );

-- Policy for electronic_wallet_transactions - Read access for authenticated users
CREATE POLICY "electronic_wallet_transactions_read_policy" ON public.electronic_wallet_transactions
    FOR SELECT USING (
        auth.role() = 'authenticated'
    );

-- ============================================================================
-- STEP 8: Create Helper Functions
-- ============================================================================

-- Function to get wallet balance
CREATE OR REPLACE FUNCTION get_wallet_balance(wallet_uuid UUID)
RETURNS DECIMAL(12,2) AS $$
DECLARE
    balance DECIMAL(12,2);
BEGIN
    SELECT current_balance INTO balance
    FROM public.electronic_wallets
    WHERE id = wallet_uuid AND status = 'active';
    
    RETURN COALESCE(balance, 0.00);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update wallet balance
CREATE OR REPLACE FUNCTION update_wallet_balance(
    wallet_uuid UUID,
    transaction_amount DECIMAL(12,2),
    transaction_type_param TEXT,
    description_param TEXT DEFAULT NULL,
    reference_id_param TEXT DEFAULT NULL,
    payment_id_param UUID DEFAULT NULL,
    processed_by_param UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    wallet_current_balance DECIMAL(12,2);
    new_balance DECIMAL(12,2);
    transaction_id UUID;
BEGIN
    -- Get current balance
    SELECT ew.current_balance INTO wallet_current_balance
    FROM public.electronic_wallets ew
    WHERE ew.id = wallet_uuid AND ew.status = 'active';
    
    IF wallet_current_balance IS NULL THEN
        RAISE EXCEPTION 'Wallet not found or inactive';
    END IF;

    -- Calculate new balance based on transaction type
    IF transaction_type_param IN ('deposit', 'refund') THEN
        new_balance := wallet_current_balance + transaction_amount;
    ELSIF transaction_type_param IN ('withdrawal', 'payment') THEN
        IF wallet_current_balance < transaction_amount THEN
            RAISE EXCEPTION 'Insufficient balance';
        END IF;
        new_balance := wallet_current_balance - transaction_amount;
    ELSE
        RAISE EXCEPTION 'Invalid transaction type';
    END IF;
    
    -- Create transaction record
    INSERT INTO public.electronic_wallet_transactions (
        wallet_id, transaction_type, amount, balance_before, balance_after,
        status, description, reference_id, payment_id, processed_by
    ) VALUES (
        wallet_uuid, transaction_type_param, transaction_amount, current_balance, new_balance,
        'completed', description_param, reference_id_param, payment_id_param, processed_by_param
    ) RETURNING id INTO transaction_id;
    
    -- Update wallet balance
    UPDATE public.electronic_wallets
    SET current_balance = new_balance, updated_at = now()
    WHERE id = wallet_uuid;
    
    RETURN transaction_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 9: Grant Permissions
-- ============================================================================

-- Grant permissions to authenticated users
GRANT SELECT ON public.electronic_wallets TO authenticated;
GRANT SELECT ON public.electronic_wallet_transactions TO authenticated;

-- Grant full permissions to service_role
GRANT ALL ON public.electronic_wallets TO service_role;
GRANT ALL ON public.electronic_wallet_transactions TO service_role;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION get_wallet_balance(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION update_wallet_balance(UUID, DECIMAL, TEXT, TEXT, TEXT, UUID, UUID) TO authenticated;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Verify tables were created
SELECT 
    'Tables Created' as status,
    COUNT(*) as table_count
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('electronic_wallets', 'electronic_wallet_transactions');

-- Verify sample data was inserted
SELECT 
    'Sample Wallets' as status,
    COUNT(*) as wallet_count
FROM public.electronic_wallets;

-- Show wallet summary
SELECT 
    wallet_type,
    wallet_name,
    phone_number,
    current_balance,
    status
FROM public.electronic_wallets
ORDER BY wallet_type, created_at;
