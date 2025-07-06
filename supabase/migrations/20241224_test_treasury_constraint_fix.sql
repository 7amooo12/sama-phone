-- Test Treasury Constraint Fix
-- This migration tests the treasury unique constraint fix to ensure it works correctly

-- Test 1: Verify we can create multiple sub-treasuries
DO $$
DECLARE
    test_user_id UUID := '00000000-0000-0000-0000-000000000001'; -- Test user ID
    vault1_id UUID;
    vault2_id UUID;
    vault3_id UUID;
BEGIN
    RAISE NOTICE 'Starting treasury constraint fix tests...';
    
    -- Test creating multiple sub-treasuries (should work)
    RAISE NOTICE 'Test 1: Creating multiple sub-treasuries...';
    
    -- Create first sub-treasury
    INSERT INTO treasury_vaults (
        name, currency, balance, exchange_rate_to_egp, 
        is_main_treasury, created_by
    ) VALUES (
        'Test Sub Treasury 1', 'USD', 100.00, 0.032, 
        false, test_user_id
    ) RETURNING id INTO vault1_id;
    
    -- Create second sub-treasury
    INSERT INTO treasury_vaults (
        name, currency, balance, exchange_rate_to_egp, 
        is_main_treasury, created_by
    ) VALUES (
        'Test Sub Treasury 2', 'CNY', 200.00, 0.14, 
        false, test_user_id
    ) RETURNING id INTO vault2_id;
    
    -- Create third sub-treasury
    INSERT INTO treasury_vaults (
        name, currency, balance, exchange_rate_to_egp, 
        is_main_treasury, created_by
    ) VALUES (
        'Test Sub Treasury 3', 'SAR', 300.00, 0.27, 
        false, test_user_id
    ) RETURNING id INTO vault3_id;
    
    RAISE NOTICE 'Successfully created 3 sub-treasuries: %, %, %', vault1_id, vault2_id, vault3_id;
    
    -- Clean up test data
    DELETE FROM treasury_vaults WHERE id IN (vault1_id, vault2_id, vault3_id);
    RAISE NOTICE 'Cleaned up test sub-treasuries';
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Test 1 FAILED: %', SQLERRM;
    -- Clean up on error
    DELETE FROM treasury_vaults WHERE created_by = test_user_id AND is_main_treasury = false;
END $$;

-- Test 2: Verify we cannot create multiple main treasuries
DO $$
DECLARE
    test_user_id UUID := '00000000-0000-0000-0000-000000000002'; -- Different test user ID
    main_vault1_id UUID;
    main_vault2_id UUID;
    existing_main_count INTEGER;
BEGIN
    RAISE NOTICE 'Test 2: Testing main treasury constraint...';
    
    -- Check if a main treasury already exists
    SELECT COUNT(*) INTO existing_main_count
    FROM treasury_vaults 
    WHERE is_main_treasury = true;
    
    IF existing_main_count > 0 THEN
        RAISE NOTICE 'Main treasury already exists, testing constraint enforcement...';
        
        -- Try to create another main treasury (should fail)
        BEGIN
            INSERT INTO treasury_vaults (
                name, currency, balance, exchange_rate_to_egp, 
                is_main_treasury, created_by
            ) VALUES (
                'Test Main Treasury 2', 'EGP', 0.00, 1.0, 
                true, test_user_id
            ) RETURNING id INTO main_vault2_id;
            
            -- If we reach here, the constraint failed
            RAISE EXCEPTION 'CONSTRAINT FAILED: Multiple main treasuries were allowed!';
            
        EXCEPTION WHEN unique_violation THEN
            RAISE NOTICE 'SUCCESS: Constraint correctly prevented multiple main treasuries';
        END;
    ELSE
        RAISE NOTICE 'No main treasury exists, creating one for testing...';
        
        -- Create first main treasury (should work)
        INSERT INTO treasury_vaults (
            name, currency, balance, exchange_rate_to_egp, 
            is_main_treasury, created_by
        ) VALUES (
            'Test Main Treasury 1', 'EGP', 0.00, 1.0, 
            true, test_user_id
        ) RETURNING id INTO main_vault1_id;
        
        RAISE NOTICE 'Created first main treasury: %', main_vault1_id;
        
        -- Try to create second main treasury (should fail)
        BEGIN
            INSERT INTO treasury_vaults (
                name, currency, balance, exchange_rate_to_egp, 
                is_main_treasury, created_by
            ) VALUES (
                'Test Main Treasury 2', 'EGP', 0.00, 1.0, 
                true, test_user_id
            ) RETURNING id INTO main_vault2_id;
            
            -- If we reach here, the constraint failed
            RAISE EXCEPTION 'CONSTRAINT FAILED: Multiple main treasuries were allowed!';
            
        EXCEPTION WHEN unique_violation THEN
            RAISE NOTICE 'SUCCESS: Constraint correctly prevented multiple main treasuries';
        END;
        
        -- Clean up test main treasury
        DELETE FROM treasury_vaults WHERE id = main_vault1_id;
        RAISE NOTICE 'Cleaned up test main treasury';
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Test 2 FAILED: %', SQLERRM;
    -- Clean up on error
    DELETE FROM treasury_vaults WHERE created_by = test_user_id;
END $$;

-- Test 3: Verify constraint information
DO $$
DECLARE
    constraint_exists BOOLEAN := FALSE;
    index_exists BOOLEAN := FALSE;
BEGIN
    RAISE NOTICE 'Test 3: Verifying constraint implementation...';
    
    -- Check if the old constraint was removed
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'treasury_vaults' 
        AND constraint_name = 'unique_main_treasury'
    ) INTO constraint_exists;
    
    -- Check if the new partial unique index exists
    SELECT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'treasury_vaults' 
        AND indexname = 'idx_unique_main_treasury'
    ) INTO index_exists;
    
    RAISE NOTICE 'Old constraint exists: %', constraint_exists;
    RAISE NOTICE 'New partial index exists: %', index_exists;
    
    IF constraint_exists THEN
        RAISE WARNING 'Old constraint still exists - migration may not have been applied correctly';
    END IF;
    
    IF NOT index_exists THEN
        RAISE WARNING 'New partial index does not exist - migration may not have been applied correctly';
    END IF;
    
    IF NOT constraint_exists AND index_exists THEN
        RAISE NOTICE 'SUCCESS: Constraint fix has been applied correctly';
    END IF;
    
END $$;

-- Final summary
DO $$
DECLARE
    total_vaults INTEGER;
    main_vaults INTEGER;
    sub_vaults INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_vaults FROM treasury_vaults;
    SELECT COUNT(*) INTO main_vaults FROM treasury_vaults WHERE is_main_treasury = true;
    SELECT COUNT(*) INTO sub_vaults FROM treasury_vaults WHERE is_main_treasury = false;
    
    RAISE NOTICE '=== TREASURY CONSTRAINT FIX TEST SUMMARY ===';
    RAISE NOTICE 'Total treasury vaults: %', total_vaults;
    RAISE NOTICE 'Main treasuries: %', main_vaults;
    RAISE NOTICE 'Sub treasuries: %', sub_vaults;
    RAISE NOTICE '=== TEST COMPLETED ===';
END $$;
