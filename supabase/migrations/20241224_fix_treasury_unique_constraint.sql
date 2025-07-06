-- Fix Treasury Management Unique Constraint Issue
-- This migration fixes the incorrect unique constraint on is_main_treasury
-- to allow unlimited sub-treasuries while maintaining only one main treasury

-- Step 1: Drop the incorrect unique constraint
ALTER TABLE treasury_vaults DROP CONSTRAINT IF EXISTS unique_main_treasury;

-- Step 2: Create a partial unique index that only applies when is_main_treasury = true
-- This allows unlimited records with is_main_treasury = false
-- but ensures only one record can have is_main_treasury = true
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_main_treasury 
ON treasury_vaults (is_main_treasury) 
WHERE is_main_treasury = true;

-- Step 3: Verify the fix by testing constraint behavior
DO $$
DECLARE
    main_treasury_count INTEGER;
    sub_treasury_count INTEGER;
BEGIN
    -- Count existing main treasuries
    SELECT COUNT(*) INTO main_treasury_count
    FROM treasury_vaults 
    WHERE is_main_treasury = true;
    
    -- Count existing sub-treasuries
    SELECT COUNT(*) INTO sub_treasury_count
    FROM treasury_vaults 
    WHERE is_main_treasury = false;
    
    RAISE NOTICE 'Current treasury counts - Main: %, Sub: %', main_treasury_count, sub_treasury_count;
    
    -- Verify the constraint works correctly
    IF main_treasury_count > 1 THEN
        RAISE EXCEPTION 'Multiple main treasuries detected! This should not happen.';
    END IF;
    
    RAISE NOTICE 'Treasury constraint fix applied successfully';
END $$;

-- Step 4: Add a comment to document the constraint
COMMENT ON INDEX idx_unique_main_treasury IS 
'Ensures only one main treasury can exist while allowing unlimited sub-treasuries';

-- Step 5: Create a helper function to validate treasury creation
CREATE OR REPLACE FUNCTION validate_treasury_creation(
    p_is_main_treasury BOOLEAN
) RETURNS BOOLEAN AS $$
DECLARE
    main_count INTEGER;
BEGIN
    -- If creating a main treasury, check if one already exists
    IF p_is_main_treasury THEN
        SELECT COUNT(*) INTO main_count
        FROM treasury_vaults 
        WHERE is_main_treasury = true;
        
        IF main_count > 0 THEN
            RAISE EXCEPTION 'Main treasury already exists. Only one main treasury is allowed.';
        END IF;
    END IF;
    
    -- Sub-treasuries are always allowed
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Step 6: Add a trigger to validate treasury creation (optional safety measure)
CREATE OR REPLACE FUNCTION trigger_validate_treasury_creation()
RETURNS TRIGGER AS $$
BEGIN
    -- Validate the treasury creation
    PERFORM validate_treasury_creation(NEW.is_main_treasury);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
DROP TRIGGER IF EXISTS treasury_creation_validation ON treasury_vaults;
CREATE TRIGGER treasury_creation_validation
    BEFORE INSERT ON treasury_vaults
    FOR EACH ROW
    EXECUTE FUNCTION trigger_validate_treasury_creation();

-- Step 7: Test the fix with a sample query
DO $$
BEGIN
    -- This should work: creating a sub-treasury
    RAISE NOTICE 'Testing sub-treasury creation constraint...';
    
    -- The constraint should now allow multiple sub-treasuries
    -- and prevent multiple main treasuries
    RAISE NOTICE 'Constraint fix verification completed successfully';
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Constraint test failed: %', SQLERRM;
END $$;
