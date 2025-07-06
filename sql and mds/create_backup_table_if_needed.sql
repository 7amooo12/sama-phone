-- 🔧 CREATE BACKUP TABLE FOR ROLE CORRECTIONS
-- Ensures we have audit trail for role changes

-- Create backup table if it doesn't exist
CREATE TABLE IF NOT EXISTS user_profiles_backup_role_correction (
  id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL,
  email TEXT NOT NULL,
  old_role TEXT NOT NULL,
  new_role TEXT NOT NULL,
  change_reason TEXT NOT NULL,
  changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_profiles_backup_user_id 
ON user_profiles_backup_role_correction(user_id);

CREATE INDEX IF NOT EXISTS idx_user_profiles_backup_changed_at 
ON user_profiles_backup_role_correction(changed_at);

-- Show table structure
SELECT 
  '📋 BACKUP TABLE READY' as status,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'user_profiles_backup_role_correction'
ORDER BY ordinal_position;
