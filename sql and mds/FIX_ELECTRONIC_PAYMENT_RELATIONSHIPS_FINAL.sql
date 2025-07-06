-- =====================================================
-- FINAL FIX FOR ELECTRONIC PAYMENT RELATIONSHIPS
-- =====================================================
-- This script fixes the database relationship issues for electronic payments
-- Run this in your Supabase SQL editor

-- =====================================================
-- 1. ENSURE USER_PROFILES TABLE EXISTS
-- =====================================================

-- Check if user_profiles table exists, if not create it
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'user_profiles'
    ) THEN
        -- Create user_profiles table
        CREATE TABLE public.user_profiles (
            id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
            email TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            phone_number TEXT,
            role TEXT NOT NULL DEFAULT 'client',
            status TEXT NOT NULL DEFAULT 'pending',
            profile_image TEXT,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
        );
        
        -- Enable RLS
        ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
        
        -- Create RLS policies
        CREATE POLICY "Public profiles are viewable by everyone" 
        ON public.user_profiles FOR SELECT USING (true);
        
        CREATE POLICY "Users can update own profile" 
        ON public.user_profiles FOR UPDATE USING (auth.uid() = id);
        
        RAISE NOTICE '✅ Created user_profiles table with RLS policies';
    ELSE
        RAISE NOTICE 'ℹ️ user_profiles table already exists';
    END IF;
END $$;

-- =====================================================
-- 2. POPULATE MISSING USER PROFILES
-- =====================================================

-- Insert missing profiles for auth users
INSERT INTO public.user_profiles (
    id,
    email,
    name,
    role,
    status,
    created_at,
    updated_at
)
SELECT 
    au.id,
    COALESCE(au.email, 'user_' || au.id::text || '@example.com'),
    COALESCE(
        au.raw_user_meta_data->>'name',
        au.raw_user_meta_data->>'full_name',
        'User ' || SUBSTRING(au.id::text, 1, 8)
    ),
    COALESCE(au.raw_user_meta_data->>'role', 'client'),
    'approved',
    au.created_at,
    NOW()
FROM auth.users au
LEFT JOIN public.user_profiles up ON au.id = up.id
WHERE up.id IS NULL
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- 3. ENSURE ELECTRONIC PAYMENTS TABLE EXISTS
-- =====================================================

-- Create electronic_payments table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.electronic_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    payment_method TEXT NOT NULL CHECK (payment_method IN ('vodafone_cash', 'instapay')),
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    proof_image_url TEXT,
    recipient_account_id UUID REFERENCES public.payment_accounts(id) NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    admin_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    approved_by UUID REFERENCES auth.users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Enable RLS on electronic_payments
ALTER TABLE public.electronic_payments ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 4. CREATE RLS POLICIES FOR ELECTRONIC PAYMENTS
-- =====================================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own payments" ON public.electronic_payments;
DROP POLICY IF EXISTS "Users can create own payments" ON public.electronic_payments;
DROP POLICY IF EXISTS "Admins can view all payments" ON public.electronic_payments;
DROP POLICY IF EXISTS "Admins can update all payments" ON public.electronic_payments;

-- Create new policies
CREATE POLICY "Users can view own payments" 
ON public.electronic_payments FOR SELECT 
USING (auth.uid() = client_id);

CREATE POLICY "Users can create own payments" 
ON public.electronic_payments FOR INSERT 
WITH CHECK (auth.uid() = client_id);

CREATE POLICY "Admins can view all payments" 
ON public.electronic_payments FOR SELECT 
USING (
    EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE id = auth.uid() 
        AND role IN ('admin', 'accountant')
    )
);

CREATE POLICY "Admins can update all payments" 
ON public.electronic_payments FOR UPDATE 
USING (
    EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE id = auth.uid() 
        AND role IN ('admin', 'accountant')
    )
);

-- =====================================================
-- 5. ENSURE PAYMENT ACCOUNTS TABLE EXISTS
-- =====================================================

-- Create payment_accounts table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.payment_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_type TEXT NOT NULL CHECK (account_type IN ('vodafone_cash', 'instapay')),
    account_number TEXT NOT NULL,
    account_holder_name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    UNIQUE(account_type, account_number)
);

-- Enable RLS on payment_accounts
ALTER TABLE public.payment_accounts ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for payment_accounts
DROP POLICY IF EXISTS "Payment accounts are viewable by everyone" ON public.payment_accounts;
DROP POLICY IF EXISTS "Admins can manage payment accounts" ON public.payment_accounts;

CREATE POLICY "Payment accounts are viewable by everyone" 
ON public.payment_accounts FOR SELECT USING (true);

CREATE POLICY "Admins can manage payment accounts" 
ON public.payment_accounts FOR ALL 
USING (
    EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE id = auth.uid() 
        AND role IN ('admin', 'accountant')
    )
);

-- =====================================================
-- 6. CREATE STORAGE BUCKET FOR PAYMENT PROOFS
-- =====================================================

-- Create payment-proofs bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('payment-proofs', 'payment-proofs', true)
ON CONFLICT (id) DO NOTHING;

-- Create storage policies
DROP POLICY IF EXISTS "Payment proof upload policy" ON storage.objects;
DROP POLICY IF EXISTS "Payment proof view policy" ON storage.objects;

CREATE POLICY "Payment proof upload policy" 
ON storage.objects FOR INSERT 
WITH CHECK (
    bucket_id = 'payment-proofs' 
    AND auth.role() = 'authenticated'
);

CREATE POLICY "Payment proof view policy" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'payment-proofs');

-- =====================================================
-- 7. CREATE HELPFUL VIEWS
-- =====================================================

-- Create a view for payments with client information
CREATE OR REPLACE VIEW public.payments_with_client_info AS
SELECT 
    ep.*,
    up.name as client_name,
    up.email as client_email,
    up.phone_number as client_phone,
    pa.account_number as recipient_account_number,
    pa.account_holder_name as recipient_account_holder_name,
    approver.name as approved_by_name
FROM public.electronic_payments ep
LEFT JOIN public.user_profiles up ON ep.client_id = up.id
LEFT JOIN public.payment_accounts pa ON ep.recipient_account_id = pa.id
LEFT JOIN public.user_profiles approver ON ep.approved_by = approver.id;

-- =====================================================
-- 8. CREATE HELPFUL FUNCTIONS
-- =====================================================

-- Function to get payment statistics
CREATE OR REPLACE FUNCTION public.get_payment_statistics()
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'pending_count', (SELECT COUNT(*) FROM public.electronic_payments WHERE status = 'pending'),
        'approved_count', (SELECT COUNT(*) FROM public.electronic_payments WHERE status = 'approved'),
        'rejected_count', (SELECT COUNT(*) FROM public.electronic_payments WHERE status = 'rejected'),
        'total_approved_amount', (SELECT COALESCE(SUM(amount), 0) FROM public.electronic_payments WHERE status = 'approved'),
        'today_payments', (SELECT COUNT(*) FROM public.electronic_payments WHERE DATE(created_at) = CURRENT_DATE),
        'this_month_amount', (SELECT COALESCE(SUM(amount), 0) FROM public.electronic_payments WHERE status = 'approved' AND DATE_TRUNC('month', created_at) = DATE_TRUNC('month', CURRENT_DATE))
    ) INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 9. VERIFICATION QUERIES
-- =====================================================

-- Verify the setup
DO $$
BEGIN
    -- Check tables exist
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_profiles') THEN
        RAISE NOTICE '✅ user_profiles table exists';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'electronic_payments') THEN
        RAISE NOTICE '✅ electronic_payments table exists';
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'payment_accounts') THEN
        RAISE NOTICE '✅ payment_accounts table exists';
    END IF;
    
    -- Check bucket exists
    IF EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'payment-proofs') THEN
        RAISE NOTICE '✅ payment-proofs storage bucket exists';
    END IF;
    
    RAISE NOTICE '🎉 Electronic payment system setup completed successfully!';
END $$;

-- Show summary
SELECT 
    'Setup Summary' as info,
    (SELECT COUNT(*) FROM public.user_profiles) as user_profiles_count,
    (SELECT COUNT(*) FROM public.electronic_payments) as payments_count,
    (SELECT COUNT(*) FROM public.payment_accounts) as payment_accounts_count;
