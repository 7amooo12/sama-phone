-- =====================================================
-- TEST DEVICE HASH GENERATION
-- =====================================================
-- 
-- This script tests the device hash generation logic to ensure
-- it produces valid 64-character hashes that meet the constraint
--

-- Test 1: Basic device hash generation
DO $$
DECLARE
    test_hash TEXT;
    hash_length INTEGER;
    worker_id_sample UUID := '6a9eb412-d07a-4c65-ae26-2f9d5a4b63af';
BEGIN
    RAISE NOTICE '=== TESTING DEVICE HASH GENERATION ===';
    
    -- Generate test hash using the same logic as the fix script
    SELECT LOWER(MD5(worker_id_sample::text || EXTRACT(EPOCH FROM NOW())::text)) || 
           LOWER(MD5(worker_id_sample::text || 'smartbiztracker' || EXTRACT(EPOCH FROM NOW())::text))
    INTO test_hash;
    
    hash_length := LENGTH(test_hash);
    
    RAISE NOTICE 'Generated hash: %', test_hash;
    RAISE NOTICE 'Hash length: % characters', hash_length;
    
    IF hash_length = 64 THEN
        RAISE NOTICE '✅ Device hash generation test PASSED';
    ELSE
        RAISE NOTICE '❌ Device hash generation test FAILED - Expected 64 characters, got %', hash_length;
    END IF;
END $$;

-- Test 2: Verify MD5 function produces 32-character hashes
DO $$
DECLARE
    md5_hash TEXT;
    md5_length INTEGER;
BEGIN
    RAISE NOTICE '=== TESTING MD5 FUNCTION ===';
    
    SELECT LOWER(MD5('test_string')) INTO md5_hash;
    md5_length := LENGTH(md5_hash);
    
    RAISE NOTICE 'MD5 hash: %', md5_hash;
    RAISE NOTICE 'MD5 length: % characters', md5_length;
    
    IF md5_length = 32 THEN
        RAISE NOTICE '✅ MD5 function test PASSED (32 chars)';
        RAISE NOTICE '✅ Two MD5 hashes concatenated = 64 chars';
    ELSE
        RAISE NOTICE '❌ MD5 function test FAILED - Expected 32 characters, got %', md5_length;
    END IF;
END $$;

-- Test 3: Check constraint compatibility
DO $$
DECLARE
    test_hash TEXT;
    constraint_check BOOLEAN;
BEGIN
    RAISE NOTICE '=== TESTING CONSTRAINT COMPATIBILITY ===';
    
    -- Generate test hash
    SELECT LOWER(MD5('test_worker_id' || EXTRACT(EPOCH FROM NOW())::text)) || 
           LOWER(MD5('test_worker_id' || 'smartbiztracker' || EXTRACT(EPOCH FROM NOW())::text))
    INTO test_hash;
    
    -- Test the constraint logic
    constraint_check := (LENGTH(test_hash) = 64);
    
    RAISE NOTICE 'Constraint check (LENGTH = 64): %', constraint_check;
    
    IF constraint_check THEN
        RAISE NOTICE '✅ Constraint compatibility test PASSED';
    ELSE
        RAISE NOTICE '❌ Constraint compatibility test FAILED';
    END IF;
END $$;

-- Test 4: Generate sample hashes for all 4 workers
DO $$
DECLARE
    worker_ids UUID[] := ARRAY[
        '21777a0d-d504-4a65-93d1-d5394f642655'::UUID,  -- Mahmoud
        '3185a8c6-af71-448b-a305-6ca7fcae8491'::UUID,  -- مستخدم جديد
        '6a9eb412-d07a-4c65-ae26-2f9d5a4b63af'::UUID,  -- هاشم
        'd73492e1-8eb9-4038-bda2-1c972a23f8b1'::UUID   -- عطيه
    ];
    worker_names TEXT[] := ARRAY['Mahmoud', 'مستخدم جديد', 'هاشم', 'عطيه'];
    worker_id UUID;
    worker_name TEXT;
    generated_hash TEXT;
    i INTEGER;
BEGIN
    RAISE NOTICE '=== GENERATING SAMPLE HASHES FOR ALL 4 WORKERS ===';
    
    FOR i IN 1..array_length(worker_ids, 1) LOOP
        worker_id := worker_ids[i];
        worker_name := worker_names[i];
        
        -- Generate hash for this worker
        SELECT LOWER(MD5(worker_id::text || EXTRACT(EPOCH FROM NOW())::text)) || 
               LOWER(MD5(worker_id::text || 'smartbiztracker' || EXTRACT(EPOCH FROM NOW())::text))
        INTO generated_hash;
        
        RAISE NOTICE 'Worker: % (%) -> Hash: % (% chars)', 
                     worker_name, worker_id, generated_hash, LENGTH(generated_hash);
        
        -- Small delay to ensure different timestamps
        PERFORM pg_sleep(0.1);
    END LOOP;
END $$;

-- Final summary
SELECT 
    '🔍 DEVICE HASH GENERATION TEST COMPLETE' as status,
    'Review the results above to verify hash generation works correctly' as instruction;
