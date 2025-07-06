-- =====================================================================
-- CRITICAL DATABASE SCHEMA AND USER APPROVAL FIXES
-- =====================================================================
-- This script fixes two critical issues:
-- 1. Schema mismatch causing PGRST204 errors
-- 2. User approval status inconsistencies preventing client debt display
-- =====================================================================

-- Step 1: Verify current database schema
DO $$
BEGIN
    RAISE NOTICE '🔍 DIAGNOSING DATABASE SCHEMA ISSUES...';
    
    -- Check if phone column exists (it shouldn't)
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'user_profiles' 
        AND column_name = 'phone'
    ) THEN
        RAISE NOTICE '❌ PROBLEM: "phone" column exists in user_profiles table';
        RAISE NOTICE '💡 SOLUTION: This column should be "phone_number" instead';
    ELSE
        RAISE NOTICE '✅ GOOD: No "phone" column found in user_profiles table';
    END IF;
    
    -- Check if phone_number column exists (it should)
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'user_profiles' 
        AND column_name = 'phone_number'
    ) THEN
        RAISE NOTICE '✅ GOOD: "phone_number" column exists in user_profiles table';
    ELSE
        RAISE NOTICE '❌ PROBLEM: "phone_number" column missing from user_profiles table';
        RAISE NOTICE '💡 SOLUTION: Adding phone_number column...';
        
        -- Add the missing phone_number column
        ALTER TABLE public.user_profiles ADD COLUMN phone_number TEXT;
        RAISE NOTICE '✅ FIXED: Added phone_number column to user_profiles table';
    END IF;
END $$;

-- Step 2: Diagnose user approval status issues
DO $$
DECLARE
    users_with_wallets_count INTEGER;
    approved_users_count INTEGER;
    users_needing_approval_count INTEGER;
BEGIN
    RAISE NOTICE '🔍 DIAGNOSING USER APPROVAL STATUS ISSUES...';
    
    -- Count users who have wallets
    SELECT COUNT(DISTINCT w.user_id) INTO users_with_wallets_count
    FROM wallets w
    WHERE w.role = 'client' AND w.status = 'active';
    
    RAISE NOTICE '📊 Users with active client wallets: %', users_with_wallets_count;
    
    -- Count approved users
    SELECT COUNT(*) INTO approved_users_count
    FROM user_profiles up
    WHERE up.role = 'client' AND up.status = 'approved';
    
    RAISE NOTICE '📊 Approved client users: %', approved_users_count;
    
    -- Count users who have wallets but are not approved
    SELECT COUNT(DISTINCT w.user_id) INTO users_needing_approval_count
    FROM wallets w
    LEFT JOIN user_profiles up ON w.user_id = up.id
    WHERE w.role = 'client' 
    AND w.status = 'active'
    AND (up.status != 'approved' OR up.status IS NULL);
    
    RAISE NOTICE '📊 Users with wallets but not approved: %', users_needing_approval_count;
    
    IF users_needing_approval_count > 0 THEN
        RAISE NOTICE '❌ PROBLEM: % users have wallets but are not approved', users_needing_approval_count;
        RAISE NOTICE '💡 SOLUTION: These users will be approved in the next step';
    ELSE
        RAISE NOTICE '✅ GOOD: All users with wallets are properly approved';
    END IF;
END $$;

-- Step 3: Show detailed information about problematic users
DO $$
DECLARE
    rec RECORD;
BEGIN
    RAISE NOTICE '🔍 DETAILED ANALYSIS OF PROBLEMATIC USERS:';
    
    -- Show users who have wallets but are not approved
    FOR rec IN (
        SELECT 
            w.user_id,
            up.name,
            up.email,
            up.status as user_status,
            w.balance,
            w.status as wallet_status
        FROM wallets w
        LEFT JOIN user_profiles up ON w.user_id = up.id
        WHERE w.role = 'client' 
        AND w.status = 'active'
        AND (up.status != 'approved' OR up.status IS NULL)
        ORDER BY w.balance DESC
    ) LOOP
        RAISE NOTICE '   👤 User: % (%) - Status: % - Balance: % EGP', 
            COALESCE(rec.name, 'Unknown'), 
            rec.user_id, 
            COALESCE(rec.user_status, 'NULL'), 
            rec.balance;
    END LOOP;
END $$;

-- Step 4: Fix user approval status for users with active wallets
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    RAISE NOTICE '🔧 FIXING USER APPROVAL STATUS...';
    
    -- Update users who have active wallets to approved status
    WITH users_to_approve AS (
        SELECT DISTINCT w.user_id
        FROM wallets w
        LEFT JOIN user_profiles up ON w.user_id = up.id
        WHERE w.role = 'client' 
        AND w.status = 'active'
        AND (up.status != 'approved' OR up.status IS NULL)
    )
    UPDATE user_profiles 
    SET 
        status = 'approved',
        updated_at = NOW()
    WHERE id IN (SELECT user_id FROM users_to_approve);
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    
    RAISE NOTICE '✅ FIXED: Updated % users to approved status', updated_count;
END $$;

-- Step 5: Create missing user profiles for users who have wallets but no profile
DO $$
DECLARE
    created_count INTEGER := 0;
    rec RECORD;
BEGIN
    RAISE NOTICE '🔧 CREATING MISSING USER PROFILES...';
    
    -- Find wallets without corresponding user profiles
    FOR rec IN (
        SELECT DISTINCT w.user_id, au.email
        FROM wallets w
        LEFT JOIN user_profiles up ON w.user_id = up.id
        LEFT JOIN auth.users au ON w.user_id = au.id
        WHERE w.role = 'client' 
        AND w.status = 'active'
        AND up.id IS NULL
        AND au.id IS NOT NULL
    ) LOOP
        -- Create user profile for this user
        INSERT INTO user_profiles (
            id, email, name, role, status, created_at, updated_at
        ) VALUES (
            rec.user_id,
            rec.email,
            COALESCE(SPLIT_PART(rec.email, '@', 1), 'عميل'),
            'client',
            'approved',
            NOW(),
            NOW()
        );
        
        created_count := created_count + 1;
        RAISE NOTICE '   ✅ Created profile for user: % (%)', rec.email, rec.user_id;
    END LOOP;
    
    RAISE NOTICE '✅ FIXED: Created % missing user profiles', created_count;
END $$;

-- Step 6: Verify the fixes
DO $$
DECLARE
    users_with_wallets_count INTEGER;
    approved_users_count INTEGER;
    remaining_issues_count INTEGER;
BEGIN
    RAISE NOTICE '🔍 VERIFYING FIXES...';
    
    -- Count users who have wallets
    SELECT COUNT(DISTINCT w.user_id) INTO users_with_wallets_count
    FROM wallets w
    WHERE w.role = 'client' AND w.status = 'active';
    
    -- Count approved users with wallets
    SELECT COUNT(DISTINCT w.user_id) INTO approved_users_count
    FROM wallets w
    INNER JOIN user_profiles up ON w.user_id = up.id
    WHERE w.role = 'client' 
    AND w.status = 'active'
    AND up.status = 'approved';
    
    -- Count remaining issues
    SELECT COUNT(DISTINCT w.user_id) INTO remaining_issues_count
    FROM wallets w
    LEFT JOIN user_profiles up ON w.user_id = up.id
    WHERE w.role = 'client' 
    AND w.status = 'active'
    AND (up.status != 'approved' OR up.status IS NULL);
    
    RAISE NOTICE '📊 VERIFICATION RESULTS:';
    RAISE NOTICE '   - Users with active wallets: %', users_with_wallets_count;
    RAISE NOTICE '   - Approved users with wallets: %', approved_users_count;
    RAISE NOTICE '   - Remaining issues: %', remaining_issues_count;
    
    IF remaining_issues_count = 0 THEN
        RAISE NOTICE '🎉 SUCCESS: All users with wallets are now properly approved!';
    ELSE
        RAISE NOTICE '⚠️ WARNING: % users still have issues that need manual review', remaining_issues_count;
    END IF;
END $$;

-- Step 7: Test the specific problematic user from the logs
DO $$
DECLARE
    test_user_id UUID := 'aaaaf98e-f3aa-489d-9586-573332ff6301';
    user_exists BOOLEAN;
    user_approved BOOLEAN;
    has_wallet BOOLEAN;
    wallet_balance NUMERIC;
BEGIN
    RAISE NOTICE '🧪 TESTING SPECIFIC USER: %', test_user_id;
    
    -- Check if user exists in user_profiles
    SELECT EXISTS(SELECT 1 FROM user_profiles WHERE id = test_user_id) INTO user_exists;
    
    -- Check if user is approved
    SELECT EXISTS(
        SELECT 1 FROM user_profiles 
        WHERE id = test_user_id AND status = 'approved'
    ) INTO user_approved;
    
    -- Check if user has wallet
    SELECT EXISTS(
        SELECT 1 FROM wallets 
        WHERE user_id = test_user_id AND role = 'client' AND status = 'active'
    ) INTO has_wallet;
    
    -- Get wallet balance
    SELECT balance INTO wallet_balance
    FROM wallets 
    WHERE user_id = test_user_id AND role = 'client' AND status = 'active'
    LIMIT 1;
    
    RAISE NOTICE '📊 TEST RESULTS FOR USER %:', test_user_id;
    RAISE NOTICE '   - User exists in profiles: %', user_exists;
    RAISE NOTICE '   - User is approved: %', user_approved;
    RAISE NOTICE '   - User has wallet: %', has_wallet;
    RAISE NOTICE '   - Wallet balance: % EGP', COALESCE(wallet_balance, 0);
    
    IF user_exists AND user_approved AND has_wallet THEN
        RAISE NOTICE '✅ SUCCESS: Test user should now appear in client debt management!';
    ELSE
        RAISE NOTICE '❌ ISSUE: Test user still has problems that need investigation';
    END IF;
END $$;

-- Step 8: Final completion message
DO $$
BEGIN
    RAISE NOTICE '🎉 CRITICAL DATABASE FIXES COMPLETED!';
    RAISE NOTICE '📝 NEXT STEPS:';
    RAISE NOTICE '   1. Test account information updates for all user roles';
    RAISE NOTICE '   2. Verify client debt management shows correct client count';
    RAISE NOTICE '   3. Confirm accountant dashboard displays client debt data';
END $$;
