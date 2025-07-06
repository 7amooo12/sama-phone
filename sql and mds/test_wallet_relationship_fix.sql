-- Test script for wallet-user_profile relationship fix
-- Run this after applying the migration to verify everything works

-- 1. Check if the migration was applied successfully
SELECT 'Checking migration status...' as step;

-- Check if user_profile_id column exists
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'wallets' 
            AND column_name = 'user_profile_id'
        ) 
        THEN '✅ user_profile_id column exists in wallets table'
        ELSE '❌ user_profile_id column missing in wallets table'
    END as column_check;

-- Check if foreign key constraint exists
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
            WHERE tc.table_name = 'wallets'
            AND tc.constraint_type = 'FOREIGN KEY'
            AND kcu.column_name = 'user_profile_id'
        ) 
        THEN '✅ Foreign key constraint exists for user_profile_id'
        ELSE '❌ Foreign key constraint missing for user_profile_id'
    END as fk_check;

-- 2. Validate existing wallet relationships
SELECT 'Validating wallet relationships...' as step;

SELECT * FROM validate_wallet_relationships();

-- 3. Count wallets by status
SELECT 
    'Wallet relationship summary:' as step,
    COUNT(*) as total_wallets,
    COUNT(CASE WHEN user_profile_id IS NOT NULL THEN 1 END) as wallets_with_profile_id,
    COUNT(CASE WHEN user_profile_id IS NULL THEN 1 END) as wallets_missing_profile_id
FROM public.wallets;

-- 4. Test the relationship with a sample query
SELECT 'Testing relationship query...' as step;

-- This should work now without PGRST200 error
SELECT 
    w.id as wallet_id,
    w.role as wallet_role,
    w.balance,
    up.name as user_name,
    up.email as user_email,
    up.role as user_role,
    up.status as user_status
FROM public.wallets w
JOIN public.user_profiles up ON w.user_profile_id = up.id
WHERE up.status = 'approved'
LIMIT 5;

-- 5. Check for any inconsistencies
SELECT 'Checking for inconsistencies...' as step;

SELECT 
    COUNT(*) as inconsistent_wallets
FROM public.wallets w
LEFT JOIN public.user_profiles up ON w.user_profile_id = up.id
WHERE w.user_id != w.user_profile_id 
   OR up.id IS NULL 
   OR w.user_profile_id IS NULL;

-- 6. Test role-based filtering (simulating the app query)
SELECT 'Testing role-based filtering...' as step;

-- Test for client role
SELECT 
    'Client wallets:' as test_type,
    COUNT(*) as count
FROM public.wallets w
JOIN public.user_profiles up ON w.user_profile_id = up.id
WHERE w.role = 'client' 
  AND up.role = 'client' 
  AND up.status = 'approved';

-- Test for worker role
SELECT 
    'Worker wallets:' as test_type,
    COUNT(*) as count
FROM public.wallets w
JOIN public.user_profiles up ON w.user_profile_id = up.id
WHERE w.role = 'worker' 
  AND up.role = 'worker' 
  AND up.status = 'approved';

-- 7. Performance check - ensure indexes exist
SELECT 'Checking indexes...' as step;

SELECT 
    indexname,
    tablename,
    indexdef
FROM pg_indexes 
WHERE tablename = 'wallets' 
  AND (indexname LIKE '%user_profile_id%' OR indexname LIKE '%user_id%')
ORDER BY indexname;

-- 8. Final summary
SELECT 
    'Fix validation complete!' as result,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'wallets' AND column_name = 'user_profile_id'
        ) AND NOT EXISTS (
            SELECT 1 FROM public.wallets 
            WHERE user_profile_id IS NULL
        )
        THEN '✅ All checks passed - relationship fix successful!'
        ELSE '⚠️ Some issues remain - check validation results above'
    END as status;
