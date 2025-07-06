-- Create comprehensive wallet system for SmartBizTracker
-- Migration: 20241215000000_create_wallet_system.sql

-- Create wallets table
CREATE TABLE IF NOT EXISTS public.wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    user_profile_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    balance DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    role TEXT NOT NULL,
    currency TEXT NOT NULL DEFAULT 'EGP',
    status TEXT NOT NULL DEFAULT 'active', -- active, suspended, closed
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}',

    -- Constraints
    CONSTRAINT wallets_balance_positive CHECK (balance >= 0),
    CONSTRAINT wallets_role_valid CHECK (role IN ('admin', 'accountant', 'worker', 'client', 'owner')),
    CONSTRAINT wallets_status_valid CHECK (status IN ('active', 'suspended', 'closed')),
    CONSTRAINT wallets_user_role_unique UNIQUE (user_id, role),
    -- Ensure user_id and user_profile_id reference the same user
    CONSTRAINT wallets_user_consistency CHECK (user_id = user_profile_id)
);

-- Create wallet_transactions table
CREATE TABLE IF NOT EXISTS public.wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id UUID REFERENCES public.wallets(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    transaction_type TEXT NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    balance_before DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    balance_after DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    description TEXT NOT NULL,
    reference_id UUID, -- Links to orders, tasks, etc.
    reference_type TEXT, -- 'order', 'task', 'reward', 'salary', 'manual'
    status TEXT NOT NULL DEFAULT 'completed',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    created_by UUID REFERENCES auth.users(id) NOT NULL,
    approved_by UUID REFERENCES auth.users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}',
    
    -- Constraints
    CONSTRAINT wallet_transactions_type_valid CHECK (
        transaction_type IN ('credit', 'debit', 'reward', 'salary', 'payment', 'refund', 'bonus', 'penalty', 'transfer')
    ),
    CONSTRAINT wallet_transactions_amount_positive CHECK (amount > 0),
    CONSTRAINT wallet_transactions_status_valid CHECK (
        status IN ('pending', 'completed', 'failed', 'cancelled')
    ),
    CONSTRAINT wallet_transactions_reference_type_valid CHECK (
        reference_type IS NULL OR reference_type IN ('order', 'task', 'reward', 'salary', 'manual', 'transfer')
    )
);

-- Enable RLS on both tables
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON public.wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_wallets_role ON public.wallets(role);
CREATE INDEX IF NOT EXISTS idx_wallets_status ON public.wallets(status);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_wallet_id ON public.wallet_transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_id ON public.wallet_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_type ON public.wallet_transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_reference ON public.wallet_transactions(reference_id, reference_type);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_created_at ON public.wallet_transactions(created_at DESC);

-- Create function to update wallet balance
CREATE OR REPLACE FUNCTION update_wallet_balance()
RETURNS TRIGGER AS $$
BEGIN
    -- Update wallet balance based on transaction
    IF NEW.transaction_type IN ('credit', 'reward', 'salary', 'bonus', 'refund') THEN
        UPDATE public.wallets 
        SET balance = balance + NEW.amount,
            updated_at = now()
        WHERE id = NEW.wallet_id;
    ELSIF NEW.transaction_type IN ('debit', 'payment', 'penalty') THEN
        UPDATE public.wallets 
        SET balance = balance - NEW.amount,
            updated_at = now()
        WHERE id = NEW.wallet_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update wallet balance
CREATE TRIGGER trigger_update_wallet_balance
    AFTER INSERT ON public.wallet_transactions
    FOR EACH ROW
    EXECUTE FUNCTION update_wallet_balance();

-- Create function to set balance_before and balance_after
CREATE OR REPLACE FUNCTION set_transaction_balances()
RETURNS TRIGGER AS $$
DECLARE
    current_balance DECIMAL(15, 2);
BEGIN
    -- Get current wallet balance
    SELECT balance INTO current_balance 
    FROM public.wallets 
    WHERE id = NEW.wallet_id;
    
    -- Set balance_before
    NEW.balance_before = current_balance;
    
    -- Calculate balance_after
    IF NEW.transaction_type IN ('credit', 'reward', 'salary', 'bonus', 'refund') THEN
        NEW.balance_after = current_balance + NEW.amount;
    ELSIF NEW.transaction_type IN ('debit', 'payment', 'penalty') THEN
        NEW.balance_after = current_balance - NEW.amount;
    ELSE
        NEW.balance_after = current_balance;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to set balances before insert
CREATE TRIGGER trigger_set_transaction_balances
    BEFORE INSERT ON public.wallet_transactions
    FOR EACH ROW
    EXECUTE FUNCTION set_transaction_balances();

-- Create function to automatically create wallet for new approved users
CREATE OR REPLACE FUNCTION create_user_wallet()
RETURNS TRIGGER AS $$
BEGIN
    -- Only create wallet when user status changes to 'approved'
    IF OLD.status != 'approved' AND NEW.status = 'approved' THEN
        INSERT INTO public.wallets (user_id, role, balance)
        VALUES (NEW.id, NEW.role, 0.00)
        ON CONFLICT (user_id, role) DO NOTHING;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic wallet creation
CREATE TRIGGER trigger_create_user_wallet
    AFTER UPDATE ON public.user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION create_user_wallet();
