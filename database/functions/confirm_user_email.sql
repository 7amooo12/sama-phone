-- Function to confirm user email for admin-approved users
-- This function should be created in Supabase SQL Editor

CREATE OR REPLACE FUNCTION confirm_user_email(
  user_id UUID,
  user_email TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_record RECORD;
BEGIN
  -- Check if user exists and is approved
  SELECT * INTO user_record
  FROM user_profiles
  WHERE id = user_id AND email = user_email
  AND (status = 'approved' OR status = 'active');
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found or not approved: %', user_email;
  END IF;
  
  -- Update user_profiles table
  UPDATE user_profiles
  SET 
    email_confirmed = true,
    email_confirmed_at = NOW(),
    status = 'active',
    updated_at = NOW()
  WHERE id = user_id;
  
  -- Try to update auth.users table if accessible
  -- Note: This might require service role permissions
  BEGIN
    UPDATE auth.users
    SET 
      email_confirmed_at = NOW(),
      updated_at = NOW()
    WHERE id = user_id;
  EXCEPTION
    WHEN insufficient_privilege THEN
      -- Log the error but don't fail the function
      RAISE NOTICE 'Could not update auth.users table - insufficient privileges';
    WHEN OTHERS THEN
      -- Log other errors but don't fail
      RAISE NOTICE 'Error updating auth.users table: %', SQLERRM;
  END;
  
  RETURN true;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION confirm_user_email(UUID, TEXT) TO authenticated;

-- Alternative function for admin use only
CREATE OR REPLACE FUNCTION admin_confirm_user_email(
  user_id UUID,
  user_email TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_user_role TEXT;
  user_record RECORD;
BEGIN
  -- Check if current user is admin
  SELECT role INTO current_user_role
  FROM user_profiles
  WHERE id = auth.uid();
  
  IF current_user_role != 'admin' THEN
    RAISE EXCEPTION 'Access denied: Admin privileges required';
  END IF;
  
  -- Check if target user exists
  SELECT * INTO user_record
  FROM user_profiles
  WHERE id = user_id AND email = user_email;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found: %', user_email;
  END IF;
  
  -- Update user_profiles table
  UPDATE user_profiles
  SET 
    email_confirmed = true,
    email_confirmed_at = NOW(),
    status = 'active',
    updated_at = NOW()
  WHERE id = user_id;
  
  -- Try to update auth.users table
  BEGIN
    UPDATE auth.users
    SET 
      email_confirmed_at = NOW(),
      updated_at = NOW()
    WHERE id = user_id;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE NOTICE 'Could not update auth.users table: %', SQLERRM;
  END;
  
  RETURN true;
END;
$$;

-- Grant execute permission to authenticated users (function checks admin role internally)
GRANT EXECUTE ON FUNCTION admin_confirm_user_email(UUID, TEXT) TO authenticated;

-- Function to fix all approved users with email confirmation issues
CREATE OR REPLACE FUNCTION fix_approved_users_email_confirmation()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_record RECORD;
  fixed_count INTEGER := 0;
BEGIN
  -- Check if current user is admin
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Access denied: Admin privileges required';
  END IF;
  
  -- Fix all approved users who don't have email confirmed
  FOR user_record IN
    SELECT id, email
    FROM user_profiles
    WHERE (status = 'approved' OR status = 'active')
    AND (email_confirmed IS NULL OR email_confirmed = false)
    AND role != 'client'
  LOOP
    BEGIN
      -- Update user_profiles
      UPDATE user_profiles
      SET 
        email_confirmed = true,
        email_confirmed_at = NOW(),
        status = 'active',
        updated_at = NOW()
      WHERE id = user_record.id;
      
      -- Try to update auth.users
      BEGIN
        UPDATE auth.users
        SET 
          email_confirmed_at = NOW(),
          updated_at = NOW()
        WHERE id = user_record.id;
      EXCEPTION
        WHEN OTHERS THEN
          -- Continue even if auth.users update fails
          NULL;
      END;
      
      fixed_count := fixed_count + 1;
      
    EXCEPTION
      WHEN OTHERS THEN
        -- Log error but continue with other users
        RAISE NOTICE 'Error fixing user %: %', user_record.email, SQLERRM;
    END;
  END LOOP;
  
  RETURN fixed_count;
END;
$$;

-- Grant execute permission to authenticated users (function checks admin role internally)
GRANT EXECUTE ON FUNCTION fix_approved_users_email_confirmation() TO authenticated;

-- Usage examples:
-- 
-- 1. Confirm specific user email:
-- SELECT confirm_user_email('c4e6d714-0bf9-4334-ab2c-9fecabdef6ad', 'tesz@sama.com');
--
-- 2. Admin confirm user email:
-- SELECT admin_confirm_user_email('c4e6d714-0bf9-4334-ab2c-9fecabdef6ad', 'tesz@sama.com');
--
-- 3. Fix all approved users:
-- SELECT fix_approved_users_email_confirmation();
