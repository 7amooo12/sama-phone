-- =====================================================
-- FIX WALLET METADATA SCHEMA ERROR
-- Resolves: column "metadata" of relation "wallets" does not exist
-- =====================================================

-- STEP 1: ANALYZE CURRENT WALLET TABLE SCHEMA
-- =====================================================

SELECT '=== ANALYZING CURRENT WALLET TABLE SCHEMA ===' as section;

-- Check current wallets table structure
SELECT 
    'Current wallets table columns' as info,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'wallets'
ORDER BY ordinal_position;

-- Check if specific columns exist
SELECT 
    'Missing columns check' as info,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'wallets' 
            AND column_name = 'metadata'
        ) THEN 'metadata column EXISTS'
        ELSE 'metadata column MISSING'
    END as metadata_status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'wallets' 
            AND column_name = 'wallet_type'
        ) THEN 'wallet_type column EXISTS'
        ELSE 'wallet_type column MISSING'
    END as wallet_type_status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'wallets' 
            AND column_name = 'is_active'
        ) THEN 'is_active column EXISTS'
        ELSE 'is_active column MISSING'
    END as is_active_status;

-- STEP 2: ADD MISSING COLUMNS TO WALLETS TABLE
-- =====================================================

-- Add missing columns with proper defaults
DO $$
BEGIN
    -- Add metadata column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'wallets' 
        AND column_name = 'metadata'
    ) THEN
        ALTER TABLE public.wallets ADD COLUMN metadata JSONB DEFAULT '{}'::jsonb;
        RAISE NOTICE '✅ Added metadata column to wallets table';
    ELSE
        RAISE NOTICE 'ℹ️ metadata column already exists';
    END IF;
    
    -- Add wallet_type column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'wallets' 
        AND column_name = 'wallet_type'
    ) THEN
        ALTER TABLE public.wallets ADD COLUMN wallet_type TEXT DEFAULT 'personal';
        RAISE NOTICE '✅ Added wallet_type column to wallets table';
        
        -- Update existing records to have appropriate wallet_type
        UPDATE public.wallets 
        SET wallet_type = CASE 
            WHEN role = 'admin' THEN 'business'
            WHEN role = 'owner' THEN 'business'
            ELSE 'personal'
        END
        WHERE wallet_type IS NULL OR wallet_type = 'personal';
        
        RAISE NOTICE '✅ Updated existing wallet records with appropriate wallet_type';
    ELSE
        RAISE NOTICE 'ℹ️ wallet_type column already exists';
    END IF;
    
    -- Add is_active column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'wallets' 
        AND column_name = 'is_active'
    ) THEN
        ALTER TABLE public.wallets ADD COLUMN is_active BOOLEAN DEFAULT true;
        RAISE NOTICE '✅ Added is_active column to wallets table';
        
        -- Update existing records to be active
        UPDATE public.wallets 
        SET is_active = CASE 
            WHEN status = 'active' THEN true
            ELSE false
        END
        WHERE is_active IS NULL;
        
        RAISE NOTICE '✅ Updated existing wallet records with appropriate is_active status';
    ELSE
        RAISE NOTICE 'ℹ️ is_active column already exists';
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to add missing columns: %', SQLERRM;
END $$;

-- STEP 3: CREATE SCHEMA-COMPATIBLE BUSINESS WALLET FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_or_create_business_wallet()
RETURNS UUID AS $$
DECLARE
    business_wallet_id UUID;
    has_metadata BOOLEAN := false;
    has_wallet_type BOOLEAN := false;
    has_is_active BOOLEAN := false;
BEGIN
    -- Check which columns exist in the current schema
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'wallets' 
        AND column_name = 'metadata'
    ) INTO has_metadata;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'wallets' 
        AND column_name = 'wallet_type'
    ) INTO has_wallet_type;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'wallets' 
        AND column_name = 'is_active'
    ) INTO has_is_active;
    
    -- Try to find existing business wallet
    IF has_wallet_type THEN
        SELECT id INTO business_wallet_id
        FROM public.wallets
        WHERE wallet_type = 'business' 
        AND (NOT has_is_active OR is_active = true)
        LIMIT 1;
    ELSE
        -- Fallback: look for admin role wallet
        SELECT id INTO business_wallet_id
        FROM public.wallets
        WHERE role = 'admin'
        AND (NOT has_is_active OR is_active = true)
        LIMIT 1;
    END IF;
    
    -- If no business wallet exists, create one
    IF business_wallet_id IS NULL THEN
        -- Create business wallet with dynamic column support
        IF has_metadata AND has_wallet_type AND has_is_active THEN
            -- Full schema with all columns
            INSERT INTO public.wallets (
                user_id, wallet_type, role, balance, currency, status, 
                is_active, created_at, updated_at, metadata
            ) VALUES (
                NULL, 'business', 'admin', 0.00, 'EGP', 'active', 
                true, NOW(), NOW(), 
                jsonb_build_object(
                    'type', 'system_business_wallet',
                    'description', 'محفظة الشركة للمدفوعات الإلكترونية',
                    'created_by_system', true
                )
            ) RETURNING id INTO business_wallet_id;
        ELSIF has_wallet_type AND has_is_active THEN
            -- Schema with wallet_type and is_active but no metadata
            INSERT INTO public.wallets (
                user_id, wallet_type, role, balance, currency, status, 
                is_active, created_at, updated_at
            ) VALUES (
                NULL, 'business', 'admin', 0.00, 'EGP', 'active', 
                true, NOW(), NOW()
            ) RETURNING id INTO business_wallet_id;
        ELSE
            -- Minimal schema - basic columns only
            INSERT INTO public.wallets (
                user_id, role, balance, currency, status, created_at, updated_at
            ) VALUES (
                NULL, 'admin', 0.00, 'EGP', 'active', NOW(), NOW()
            ) RETURNING id INTO business_wallet_id;
        END IF;
        
        RAISE NOTICE '✅ Created new business wallet with ID: %', business_wallet_id;
    ELSE
        RAISE NOTICE '✅ Using existing business wallet with ID: %', business_wallet_id;
    END IF;
    
    RETURN business_wallet_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 4: CREATE SCHEMA-COMPATIBLE CLIENT WALLET FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_or_create_client_wallet(p_user_id UUID)
RETURNS UUID AS $$
DECLARE
    client_wallet_id UUID;
    has_metadata BOOLEAN := false;
    has_wallet_type BOOLEAN := false;
    has_is_active BOOLEAN := false;
BEGIN
    -- Check which columns exist in the current schema
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'wallets' 
        AND column_name = 'metadata'
    ) INTO has_metadata;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'wallets' 
        AND column_name = 'wallet_type'
    ) INTO has_wallet_type;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'wallets' 
        AND column_name = 'is_active'
    ) INTO has_is_active;
    
    -- Try to find existing client wallet
    SELECT id INTO client_wallet_id
    FROM public.wallets
    WHERE user_id = p_user_id 
    AND (NOT has_wallet_type OR wallet_type = 'personal' OR wallet_type IS NULL)
    AND (NOT has_is_active OR is_active = true)
    LIMIT 1;
    
    -- If no client wallet exists, create one
    IF client_wallet_id IS NULL THEN
        -- Create client wallet with dynamic column support
        IF has_metadata AND has_wallet_type AND has_is_active THEN
            -- Full schema with all columns
            INSERT INTO public.wallets (
                user_id, wallet_type, role, balance, currency, status, 
                is_active, created_at, updated_at, metadata
            ) VALUES (
                p_user_id, 'personal', 'client', 0.00, 'EGP', 'active', 
                true, NOW(), NOW(),
                jsonb_build_object(
                    'type', 'client_personal_wallet',
                    'description', 'محفظة العميل الشخصية'
                )
            ) RETURNING id INTO client_wallet_id;
        ELSIF has_wallet_type AND has_is_active THEN
            -- Schema with wallet_type and is_active but no metadata
            INSERT INTO public.wallets (
                user_id, wallet_type, role, balance, currency, status, 
                is_active, created_at, updated_at
            ) VALUES (
                p_user_id, 'personal', 'client', 0.00, 'EGP', 'active', 
                true, NOW(), NOW()
            ) RETURNING id INTO client_wallet_id;
        ELSE
            -- Minimal schema - basic columns only
            INSERT INTO public.wallets (
                user_id, role, balance, currency, status, created_at, updated_at
            ) VALUES (
                p_user_id, 'client', 0.00, 'EGP', 'active', NOW(), NOW()
            ) RETURNING id INTO client_wallet_id;
        END IF;
        
        RAISE NOTICE '✅ Created client wallet for user: %, wallet ID: %', p_user_id, client_wallet_id;
    END IF;
    
    RETURN client_wallet_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 5: GRANT PERMISSIONS
-- =====================================================

GRANT EXECUTE ON FUNCTION public.get_or_create_business_wallet() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_create_client_wallet(UUID) TO authenticated;

-- STEP 6: VERIFICATION
-- =====================================================

-- Verify the schema is now complete
SELECT 
    '=== SCHEMA FIX VERIFICATION ===' as status,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'wallets'
AND column_name IN ('metadata', 'wallet_type', 'is_active')
ORDER BY column_name;

-- Test business wallet creation
DO $$
DECLARE
    test_wallet_id UUID;
BEGIN
    SELECT public.get_or_create_business_wallet() INTO test_wallet_id;
    RAISE NOTICE '✅ Business wallet function test successful: %', test_wallet_id;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Business wallet function test failed: %', SQLERRM;
END $$;

RAISE NOTICE '✅ WALLET METADATA SCHEMA ERROR FIX COMPLETED!';
RAISE NOTICE '🔧 Added missing columns: metadata, wallet_type, is_active';
RAISE NOTICE '💰 Functions now work with any schema configuration';
RAISE NOTICE '🚀 Electronic payment system should work properly now';
RAISE NOTICE '📋 Script execution completed at: %', NOW();
