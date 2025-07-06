-- Check current notifications table structure
-- Run this to see what columns exist before applying the fix

SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'notifications' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check if specific columns exist
DO $$
DECLARE
    missing_columns TEXT[] := ARRAY[]::TEXT[];
    col_count INTEGER;
BEGIN
    RAISE NOTICE '=== CHECKING NOTIFICATIONS TABLE COLUMNS ===';
    
    -- Check for message column
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns 
    WHERE table_name = 'notifications' AND column_name = 'message';
    
    IF col_count = 0 THEN
        missing_columns := array_append(missing_columns, 'message');
        RAISE NOTICE '❌ MISSING: message column';
    ELSE
        RAISE NOTICE '✅ EXISTS: message column';
    END IF;
    
    -- Check for is_read column
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns 
    WHERE table_name = 'notifications' AND column_name = 'is_read';
    
    IF col_count = 0 THEN
        missing_columns := array_append(missing_columns, 'is_read');
        RAISE NOTICE '❌ MISSING: is_read column';
    ELSE
        RAISE NOTICE '✅ EXISTS: is_read column';
    END IF;
    
    -- Check for title column
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns 
    WHERE table_name = 'notifications' AND column_name = 'title';
    
    IF col_count = 0 THEN
        missing_columns := array_append(missing_columns, 'title');
        RAISE NOTICE '❌ MISSING: title column';
    ELSE
        RAISE NOTICE '✅ EXISTS: title column';
    END IF;
    
    -- Check for user_id column
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns 
    WHERE table_name = 'notifications' AND column_name = 'user_id';
    
    IF col_count = 0 THEN
        missing_columns := array_append(missing_columns, 'user_id');
        RAISE NOTICE '❌ MISSING: user_id column';
    ELSE
        RAISE NOTICE '✅ EXISTS: user_id column';
    END IF;
    
    -- Check for type column
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns 
    WHERE table_name = 'notifications' AND column_name = 'type';
    
    IF col_count = 0 THEN
        missing_columns := array_append(missing_columns, 'type');
        RAISE NOTICE '❌ MISSING: type column';
    ELSE
        RAISE NOTICE '✅ EXISTS: type column';
    END IF;
    
    RAISE NOTICE '';
    IF array_length(missing_columns, 1) > 0 THEN
        RAISE NOTICE '⚠️  MISSING COLUMNS: %', array_to_string(missing_columns, ', ');
        RAISE NOTICE '🔧 RUN fix_notifications_schema.sql to add missing columns';
    ELSE
        RAISE NOTICE '✅ ALL REQUIRED COLUMNS EXIST!';
        RAISE NOTICE '🎉 Your notifications table should work with task creation';
    END IF;
END $$;
