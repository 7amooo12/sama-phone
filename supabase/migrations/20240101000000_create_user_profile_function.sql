-- Create function to handle user profile creation in a transaction
CREATE OR REPLACE FUNCTION create_user_profile(
  user_id UUID,
  user_email TEXT,
  user_name TEXT,
  user_phone TEXT,
  user_role TEXT,
  user_status TEXT DEFAULT 'pending'
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Start transaction
  BEGIN
    -- Insert user profile
    INSERT INTO user_profiles (
      id,
      email,
      name,
      phone_number,
      role,
      status,
      created_at,
      updated_at
    ) VALUES (
      user_id,
      user_email,
      user_name,
      user_phone,
      user_role,
      user_status,
      NOW(),
      NOW()
    );

    -- Create any necessary related records
    -- For example, create empty settings record
    INSERT INTO user_settings (
      user_id,
      notifications_enabled,
      theme_mode,
      language
    ) VALUES (
      user_id,
      true,
      'system',
      'ar'
    );

    -- Commit transaction
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      -- Rollback transaction on error
      ROLLBACK;
      RAISE EXCEPTION 'Failed to create user profile: %', SQLERRM;
  END;
END;
$$; 