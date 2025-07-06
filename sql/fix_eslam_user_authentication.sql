-- Fix authentication for eslam@sama.com user
-- This script ensures the user exists and is properly configured for login

-- 1. Check if user exists in user_profiles
SELECT 
    'CHECKING USER PROFILE' as step,
    id,
    name,
    email,
    role,
    status,
    email_confirmed,
    email_confirmed_at,
    created_at,
    updated_at
FROM user_profiles 
WHERE email = 'eslam@sama.com';

-- 2. Check if user exists in auth.users
SELECT 
    'CHECKING AUTH USER' as step,
    id,
    email,
    email_confirmed_at,
    last_sign_in_at,
    created_at,
    updated_at
FROM auth.users 
WHERE email = 'eslam@sama.com';

-- 3. Create or update user profile if needed
INSERT INTO user_profiles (
    id,
    name,
    email,
    phone_number,
    role,
    status,
    email_confirmed,
    email_confirmed_at,
    created_at,
    updated_at
)
VALUES (
    gen_random_uuid(),
    'إسلام',
    'eslam@sama.com',
    '+201234567890',
    'owner',
    'active',
    true,
    NOW(),
    NOW(),
    NOW()
)
ON CONFLICT (email) 
DO UPDATE SET
    role = 'owner',
    status = 'active',
    email_confirmed = true,
    email_confirmed_at = COALESCE(user_profiles.email_confirmed_at, NOW()),
    updated_at = NOW();

-- 4. Create function to fix user authentication issues
CREATE OR REPLACE FUNCTION fix_eslam_user_auth()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_id UUID;
    result_message TEXT;
BEGIN
    -- Get user ID from user_profiles
    SELECT id INTO user_id 
    FROM user_profiles 
    WHERE email = 'eslam@sama.com';
    
    IF user_id IS NULL THEN
        result_message := 'ERROR: User eslam@sama.com not found in user_profiles';
        RETURN result_message;
    END IF;
    
    -- Update user_profiles to ensure proper status
    UPDATE user_profiles 
    SET 
        role = 'owner',
        status = 'active',
        email_confirmed = true,
        email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
        updated_at = NOW()
    WHERE email = 'eslam@sama.com';
    
    -- Try to update auth.users if exists
    UPDATE auth.users 
    SET 
        email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
        updated_at = NOW()
    WHERE email = 'eslam@sama.com';
    
    result_message := 'SUCCESS: User eslam@sama.com fixed - ID: ' || user_id || ' at ' || NOW();
    
    RETURN result_message;
END;
$$;

-- 5. Run the fix function
SELECT fix_eslam_user_auth();

-- 6. Verify the fix
SELECT 
    'VERIFICATION AFTER FIX' as step,
    up.id,
    up.name,
    up.email,
    up.role,
    up.status,
    up.email_confirmed,
    up.email_confirmed_at,
    CASE 
        WHEN au.id IS NOT NULL THEN 'EXISTS IN AUTH'
        ELSE 'MISSING FROM AUTH'
    END as auth_status,
    au.email_confirmed_at as auth_email_confirmed_at
FROM user_profiles up
LEFT JOIN auth.users au ON up.email = au.email
WHERE up.email = 'eslam@sama.com';

-- 7. Create comprehensive test account setup function
CREATE OR REPLACE FUNCTION setup_test_accounts()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result_message TEXT := '';
    test_accounts TEXT[] := ARRAY[
        'eslam@sama.com:owner:إسلام',
        'admin@sama.com:admin:أدمن',
        'hima@sama.com:accountant:هيما',
        'worker@sama.com:worker:عامل',
        'test@sama.com:client:عميل تجريبي'
    ];
    account_string TEXT;
    account_parts TEXT[];
    account_email TEXT;
    account_role TEXT;
    account_name TEXT;
BEGIN
    -- Iterate through each account string in the array
    FOREACH account_string IN ARRAY test_accounts
    LOOP
        -- Split the account string by colon
        account_parts := string_to_array(account_string, ':');

        -- Extract email, role, and name from the parts
        account_email := account_parts[1];
        account_role := account_parts[2];
        account_name := account_parts[3];

        -- Validate that we have all required parts
        IF account_email IS NULL OR account_role IS NULL OR account_name IS NULL THEN
            result_message := result_message || 'ERROR: Invalid account format: ' || account_string || ' | ';
            CONTINUE;
        END IF;

        -- Insert or update user profile
        INSERT INTO user_profiles (
            id,
            name,
            email,
            role,
            status,
            email_confirmed,
            email_confirmed_at,
            created_at,
            updated_at
        )
        VALUES (
            gen_random_uuid(),
            account_name,
            account_email,
            account_role,
            'active',
            true,
            NOW(),
            NOW(),
            NOW()
        )
        ON CONFLICT (email)
        DO UPDATE SET
            role = EXCLUDED.role,
            status = 'active',
            email_confirmed = true,
            email_confirmed_at = COALESCE(user_profiles.email_confirmed_at, NOW()),
            updated_at = NOW();

        result_message := result_message || 'Fixed: ' || account_email || ' (' || account_role || ') | ';
    END LOOP;
    
    RETURN 'Test accounts setup completed: ' || result_message;
END;
$$;

-- 8. Run comprehensive test account setup
SELECT setup_test_accounts();

-- 9. Final verification of all test accounts
SELECT 
    'FINAL VERIFICATION' as step,
    email,
    name,
    role,
    status,
    email_confirmed,
    CASE 
        WHEN status = 'active' AND email_confirmed = true THEN 'READY FOR LOGIN'
        ELSE 'NEEDS ATTENTION'
    END as login_status
FROM user_profiles 
WHERE email LIKE '%@sama.com'
ORDER BY role, email;

-- 10. Show authentication troubleshooting info
SELECT 
    'TROUBLESHOOTING INFO' as info,
    'If authentication still fails after running this script:' as step1,
    '1. Check Supabase project URL and anon key in Flutter app' as step2,
    '2. Verify RLS policies allow access to user_profiles table' as step3,
    '3. Check if auth.users table needs manual user creation' as step4,
    '4. Use alternative login method for @sama.com test accounts' as step5;
