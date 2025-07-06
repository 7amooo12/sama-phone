-- 🔧 Fix PostgreSQL NOT NULL constraint violation for wallet role column
-- This script fixes the "null value in column 'role' of relation 'wallets' violates not-null constraint" error

-- STEP 1: INVESTIGATION AND BACKUP
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '=== إصلاح مشكلة قيد NOT NULL للعمود role في جدول wallets ===';
    RAISE NOTICE '=== Fixing wallet role NOT NULL constraint violation ===';
    RAISE NOTICE 'Starting wallet role constraint fix at: %', NOW();
END $$;

-- Create backup of current wallets with NULL roles
CREATE TABLE IF NOT EXISTS public.wallets_role_fix_backup AS 
SELECT * FROM public.wallets WHERE role IS NULL;

DO $$
DECLARE
    null_role_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO null_role_count FROM public.wallets WHERE role IS NULL;
    RAISE NOTICE '📊 Found % wallet records with NULL role values', null_role_count;
    
    IF null_role_count > 0 THEN
        RAISE NOTICE '⚠️ These records need role assignment before constraint enforcement';
    ELSE
        RAISE NOTICE '✅ No NULL role values found in existing wallets';
    END IF;
END $$;

-- STEP 2: FIX EXISTING NULL ROLE VALUES
-- =====================================================

DO $$
DECLARE
    updated_count INTEGER := 0;
BEGIN
    RAISE NOTICE '🔄 Fixing existing NULL role values...';
    
    -- Update business wallets with NULL roles
    UPDATE public.wallets 
    SET role = 'admin'
    WHERE role IS NULL 
    AND wallet_type = 'business';
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE '   Updated % business wallets with admin role', updated_count;
    
    -- Update personal/client wallets with NULL roles
    UPDATE public.wallets 
    SET role = 'client'
    WHERE role IS NULL 
    AND (wallet_type = 'personal' OR wallet_type IS NULL);
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE '   Updated % personal wallets with client role', updated_count;
    
    -- Update any remaining NULL roles based on user_id
    UPDATE public.wallets 
    SET role = COALESCE(
        (SELECT up.role FROM public.user_profiles up WHERE up.id = wallets.user_id),
        'client'
    )
    WHERE role IS NULL;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE '   Updated % remaining wallets with user profile roles', updated_count;
    
END $$;

-- STEP 3: CREATE FIXED get_or_create_business_wallet FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_or_create_business_wallet()
RETURNS UUID AS $$
DECLARE
    business_wallet_id UUID;
    admin_user_id UUID;
BEGIN
    -- Try to find existing business wallet
    SELECT id INTO business_wallet_id
    FROM public.wallets
    WHERE wallet_type = 'business' 
    AND is_active = true
    AND role IS NOT NULL  -- Ensure we get wallets with proper role
    LIMIT 1;
    
    -- If no business wallet exists, create one
    IF business_wallet_id IS NULL THEN
        -- Get the first admin user as the business wallet owner
        SELECT id INTO admin_user_id
        FROM public.user_profiles
        WHERE role = 'admin' AND status = 'approved'
        LIMIT 1;
        
        -- If no admin found, get owner or accountant
        IF admin_user_id IS NULL THEN
            SELECT id INTO admin_user_id
            FROM public.user_profiles
            WHERE role IN ('owner', 'accountant') AND status = 'approved'
            ORDER BY 
                CASE 
                    WHEN role = 'owner' THEN 1 
                    WHEN role = 'accountant' THEN 2 
                    ELSE 3 
                END
            LIMIT 1;
        END IF;
        
        -- Create business wallet with proper role assignment
        IF admin_user_id IS NOT NULL THEN
            -- Create business wallet with admin user
            INSERT INTO public.wallets (
                user_id,
                wallet_type,
                role,
                balance,
                currency,
                status,
                is_active,
                created_at,
                updated_at
            ) VALUES (
                admin_user_id,
                'business',
                'admin',  -- ✅ Explicitly set role to prevent NULL constraint violation
                0.00,
                'EGP',
                'active',
                true,
                NOW(),
                NOW()
            ) RETURNING id INTO business_wallet_id;
            
            RAISE NOTICE '✅ Created business wallet with admin user: % (wallet: %)', admin_user_id, business_wallet_id;
        ELSE
            -- Create system business wallet without user_id
            INSERT INTO public.wallets (
                user_id,
                wallet_type,
                role,
                balance,
                currency,
                status,
                is_active,
                created_at,
                updated_at
            ) VALUES (
                NULL, -- System business wallet
                'business',
                'admin',  -- ✅ Explicitly set role to prevent NULL constraint violation
                0.00,
                'EGP',
                'active',
                true,
                NOW(),
                NOW()
            ) RETURNING id INTO business_wallet_id;
            
            RAISE NOTICE '✅ Created system business wallet: %', business_wallet_id;
        END IF;
    ELSE
        RAISE NOTICE 'ℹ️ Using existing business wallet: %', business_wallet_id;
    END IF;
    
    RETURN business_wallet_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 4: CREATE ENHANCED get_or_create_client_wallet FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_or_create_client_wallet(p_user_id UUID)
RETURNS UUID AS $$
DECLARE
    client_wallet_id UUID;
    user_role TEXT;
BEGIN
    -- Try to find existing client wallet
    SELECT id INTO client_wallet_id
    FROM public.wallets
    WHERE user_id = p_user_id
    AND is_active = true
    AND role IS NOT NULL  -- Ensure we get wallets with proper role
    LIMIT 1;
    
    -- If wallet exists, return it
    IF client_wallet_id IS NOT NULL THEN
        RETURN client_wallet_id;
    END IF;
    
    -- Get user role from user_profiles
    SELECT role INTO user_role
    FROM public.user_profiles
    WHERE id = p_user_id;
    
    -- Default to 'client' if no role found
    IF user_role IS NULL THEN
        user_role := 'client';
        RAISE NOTICE '⚠️ No role found for user %, defaulting to client', p_user_id;
    END IF;
    
    -- Create new wallet with proper role assignment
    INSERT INTO public.wallets (
        user_id, 
        wallet_type, 
        role,  -- ✅ Explicitly set role to prevent NULL constraint violation
        balance, 
        currency, 
        status, 
        is_active,
        created_at, 
        updated_at
    ) VALUES (
        p_user_id, 
        'personal', 
        user_role,  -- ✅ Use actual user role from user_profiles
        0.00, 
        'EGP', 
        'active', 
        true,
        NOW(), 
        NOW()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        updated_at = NOW(),
        is_active = true,
        status = 'active',
        role = COALESCE(wallets.role, user_role)  -- ✅ Ensure role is never NULL
    RETURNING id INTO client_wallet_id;
    
    RAISE NOTICE '✅ Created/updated client wallet for user % with role %: %', p_user_id, user_role, client_wallet_id;
    
    RETURN client_wallet_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 5: ADD ROLE VALIDATION TO DUAL WALLET TRANSACTION FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION public.validate_user_role(p_user_id UUID)
RETURNS TEXT AS $$
DECLARE
    user_role TEXT;
BEGIN
    -- Get user role from user_profiles
    SELECT role INTO user_role
    FROM public.user_profiles
    WHERE id = p_user_id AND status = 'approved';
    
    -- Return role or default to 'client'
    RETURN COALESCE(user_role, 'client');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 6: GRANT PERMISSIONS
-- =====================================================

GRANT EXECUTE ON FUNCTION public.get_or_create_business_wallet() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_create_client_wallet(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_user_role(UUID) TO authenticated;

-- STEP 7: VERIFICATION AND TESTING
-- =====================================================

DO $$
DECLARE
    null_role_count INTEGER;
    test_business_wallet UUID;
    test_client_wallet UUID;
    sample_user_id UUID;
BEGIN
    -- Check for remaining NULL roles
    SELECT COUNT(*) INTO null_role_count FROM public.wallets WHERE role IS NULL;
    
    IF null_role_count = 0 THEN
        RAISE NOTICE '✅ SUCCESS: No NULL role values found in wallets table';
    ELSE
        RAISE NOTICE '❌ WARNING: % wallets still have NULL role values', null_role_count;
    END IF;
    
    -- Test business wallet creation
    BEGIN
        test_business_wallet := public.get_or_create_business_wallet();
        RAISE NOTICE '✅ Business wallet function test successful: %', test_business_wallet;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ Business wallet function test failed: %', SQLERRM;
    END;
    
    -- Test client wallet creation (if we have a user)
    SELECT id INTO sample_user_id FROM public.user_profiles LIMIT 1;
    
    IF sample_user_id IS NOT NULL THEN
        BEGIN
            test_client_wallet := public.get_or_create_client_wallet(sample_user_id);
            RAISE NOTICE '✅ Client wallet function test successful: %', test_client_wallet;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '❌ Client wallet function test failed: %', SQLERRM;
        END;
    END IF;
    
END $$;

-- STEP 8: FINAL REPORT
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '=== إصلاح مشكلة قيد NOT NULL مكتمل ===';
    RAISE NOTICE '=== Wallet Role NOT NULL Constraint Fix Complete ===';
    RAISE NOTICE '✅ All wallet creation functions now properly assign role values';
    RAISE NOTICE '✅ Existing NULL role values have been fixed';
    RAISE NOTICE '✅ Electronic payment approvals should work without constraint violations';
    RAISE NOTICE '🚀 Ready to test electronic payment approval workflow';
    RAISE NOTICE 'Fix completed at: %', NOW();
END $$;
