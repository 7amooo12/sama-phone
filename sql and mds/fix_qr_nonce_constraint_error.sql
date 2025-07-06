-- =====================================================
-- Fix QR Nonce Constraint Error for SmartBizTracker
-- =====================================================
-- 
-- This script fixes the database schema constraint error:
-- "value too long for type character varying(36)"
-- 
-- Root Cause: The qr_nonce field in worker_attendance_records is VARCHAR(36)
-- but process_biometric_attendance generates 'biometric_' + UUID (46 chars)
--
-- Execute this script in your Supabase SQL Editor
-- =====================================================

-- Step 1: Identify the current constraint issue
SELECT 
    '🔍 CURRENT SCHEMA ANALYSIS' as check_type,
    table_name,
    column_name,
    data_type,
    character_maximum_length,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'worker_attendance_records' 
AND column_name = 'qr_nonce';

-- Step 2: Check current data in the table to ensure safe migration
SELECT 
    '📊 CURRENT DATA ANALYSIS' as check_type,
    COUNT(*) as total_records,
    MAX(LENGTH(qr_nonce)) as max_nonce_length,
    MIN(LENGTH(qr_nonce)) as min_nonce_length,
    COUNT(DISTINCT qr_nonce) as unique_nonces
FROM worker_attendance_records;

-- Step 3: Show sample data to understand current format
SELECT 
    '📝 SAMPLE DATA' as check_type,
    qr_nonce,
    LENGTH(qr_nonce) as nonce_length,
    attendance_method,
    created_at
FROM worker_attendance_records 
ORDER BY created_at DESC 
LIMIT 5;

-- Step 4: Alter the qr_nonce column to accommodate longer values
-- Change from VARCHAR(36) to VARCHAR(64) to handle biometric nonces
ALTER TABLE worker_attendance_records 
ALTER COLUMN qr_nonce TYPE VARCHAR(64);

-- Step 5: Update the constraint to allow both QR and biometric nonce formats
-- Drop the old constraint
ALTER TABLE worker_attendance_records 
DROP CONSTRAINT IF EXISTS valid_nonce_format_record;

-- Create new constraint that allows both formats:
-- 1. Standard UUID format (36 chars): 12345678-1234-1234-1234-123456789012
-- 2. Biometric format (46 chars): biometric_12345678-1234-1234-1234-123456789012
ALTER TABLE worker_attendance_records 
ADD CONSTRAINT valid_nonce_format_record CHECK (
    qr_nonce ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' OR
    qr_nonce ~ '^biometric_[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
);

-- Step 6: Also update qr_nonce_history table to match (if it exists and has the same issue)
-- Check if qr_nonce_history table exists and has the constraint
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'qr_nonce_history') THEN
        -- Check current column definition
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'qr_nonce_history' 
            AND column_name = 'nonce' 
            AND character_maximum_length = 36
        ) THEN
            -- Update the nonce column in qr_nonce_history table as well
            ALTER TABLE qr_nonce_history ALTER COLUMN nonce TYPE VARCHAR(64);
            
            -- Update constraint for qr_nonce_history
            ALTER TABLE qr_nonce_history DROP CONSTRAINT IF EXISTS valid_nonce_format;
            ALTER TABLE qr_nonce_history ADD CONSTRAINT valid_nonce_format CHECK (
                nonce ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' OR
                nonce ~ '^biometric_[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
            );
            
            RAISE NOTICE '✅ Updated qr_nonce_history table nonce column to VARCHAR(64)';
        ELSE
            RAISE NOTICE 'ℹ️ qr_nonce_history.nonce column already has sufficient length or different structure';
        END IF;
    ELSE
        RAISE NOTICE 'ℹ️ qr_nonce_history table does not exist';
    END IF;
END $$;

-- Step 7: Verify the changes
SELECT 
    '✅ UPDATED SCHEMA VERIFICATION' as check_type,
    table_name,
    column_name,
    data_type,
    character_maximum_length,
    is_nullable
FROM information_schema.columns 
WHERE table_name IN ('worker_attendance_records', 'qr_nonce_history')
AND column_name IN ('qr_nonce', 'nonce');

-- Step 8: Test the constraint with sample data
DO $$
DECLARE
    test_uuid_nonce VARCHAR(64) := gen_random_uuid()::text;
    test_biometric_nonce VARCHAR(64) := 'biometric_' || gen_random_uuid()::text;
BEGIN
    -- Test that both formats are now valid
    RAISE NOTICE '🧪 Testing nonce formats:';
    RAISE NOTICE 'Standard UUID nonce: % (length: %)', test_uuid_nonce, LENGTH(test_uuid_nonce);
    RAISE NOTICE 'Biometric nonce: % (length: %)', test_biometric_nonce, LENGTH(test_biometric_nonce);
    
    -- Verify the constraint allows both formats
    IF test_uuid_nonce ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
        RAISE NOTICE '✅ Standard UUID format validation: PASS';
    ELSE
        RAISE NOTICE '❌ Standard UUID format validation: FAIL';
    END IF;
    
    IF test_biometric_nonce ~ '^biometric_[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
        RAISE NOTICE '✅ Biometric nonce format validation: PASS';
    ELSE
        RAISE NOTICE '❌ Biometric nonce format validation: FAIL';
    END IF;
END $$;

-- Step 9: Update any indexes that might be affected
-- Recreate index on qr_nonce if it exists
DROP INDEX IF EXISTS idx_attendance_nonce;
CREATE INDEX IF NOT EXISTS idx_attendance_nonce 
ON worker_attendance_records(qr_nonce);

-- Step 10: Add comments for documentation
COMMENT ON COLUMN worker_attendance_records.qr_nonce IS 'QR nonce or biometric identifier. Supports both UUID format (36 chars) and biometric format (biometric_ + UUID, 46 chars)';

-- Final success message
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🎉 QR Nonce constraint error has been fixed!';
    RAISE NOTICE '✅ worker_attendance_records.qr_nonce column updated to VARCHAR(64)';
    RAISE NOTICE '✅ Constraint updated to allow both QR and biometric nonce formats';
    RAISE NOTICE '✅ Standard UUID nonces: 36 characters (existing QR codes)';
    RAISE NOTICE '✅ Biometric nonces: 46 characters (biometric_ + UUID)';
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Please test the biometric check-in functionality now';
    RAISE NOTICE '📱 The error "value too long for type character varying(36)" should be resolved';
END $$;
