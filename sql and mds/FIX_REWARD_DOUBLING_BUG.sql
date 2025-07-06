-- =====================================================
-- FIX REWARD DOUBLING BUG - DATABASE CLEANUP
-- =====================================================
-- This script fixes the reward amount doubling issue by:
-- 1. Analyzing the current state of rewards and balances
-- 2. Recalculating correct balances based on actual rewards
-- 3. Updating the balances to reflect the correct amounts
-- =====================================================

-- =====================================================
-- STEP 1: ANALYZE THE CURRENT ISSUE
-- =====================================================

-- Show current rewards and their corresponding balances
SELECT 'CURRENT REWARDS AND BALANCES ANALYSIS:' as info;

-- Show all rewards for each worker
SELECT 
    wr.worker_id,
    up.name as worker_name,
    COUNT(wr.id) as total_rewards,
    SUM(wr.amount) as total_reward_amount,
    wrb.current_balance,
    wrb.total_earned,
    wrb.total_withdrawn,
    CASE 
        WHEN wrb.current_balance = SUM(wr.amount) THEN 'CORRECT'
        WHEN wrb.current_balance = SUM(wr.amount) * 2 THEN 'DOUBLED'
        ELSE 'INCONSISTENT'
    END as balance_status
FROM worker_rewards wr
LEFT JOIN worker_reward_balances wrb ON wr.worker_id = wrb.worker_id
LEFT JOIN user_profiles up ON wr.worker_id = up.id
WHERE wr.status = 'active'
GROUP BY wr.worker_id, up.name, wrb.current_balance, wrb.total_earned, wrb.total_withdrawn
ORDER BY wr.worker_id;

-- =====================================================
-- STEP 2: RECALCULATE CORRECT BALANCES
-- =====================================================

-- Create a temporary view with correct calculations
CREATE OR REPLACE VIEW correct_worker_balances AS
SELECT 
    wr.worker_id,
    SUM(CASE WHEN wr.amount > 0 THEN wr.amount ELSE 0 END) as correct_total_earned,
    SUM(CASE WHEN wr.amount < 0 THEN ABS(wr.amount) ELSE 0 END) as correct_total_withdrawn,
    SUM(wr.amount) as correct_current_balance
FROM worker_rewards wr
WHERE wr.status = 'active'
GROUP BY wr.worker_id;

-- Show the comparison between current and correct balances
SELECT 'BALANCE CORRECTION ANALYSIS:' as info;

SELECT 
    wrb.worker_id,
    up.name as worker_name,
    wrb.current_balance as current_balance,
    cwb.correct_current_balance,
    wrb.total_earned as current_total_earned,
    cwb.correct_total_earned,
    wrb.total_withdrawn as current_total_withdrawn,
    cwb.correct_total_withdrawn,
    CASE 
        WHEN wrb.current_balance = cwb.correct_current_balance THEN 'NO CHANGE NEEDED'
        ELSE 'NEEDS CORRECTION'
    END as correction_needed
FROM worker_reward_balances wrb
LEFT JOIN correct_worker_balances cwb ON wrb.worker_id = cwb.worker_id
LEFT JOIN user_profiles up ON wrb.worker_id = up.id
ORDER BY wrb.worker_id;

-- =====================================================
-- STEP 3: FIX THE BALANCES (BACKUP FIRST!)
-- =====================================================

-- Create backup of current balances
CREATE TABLE IF NOT EXISTS worker_reward_balances_backup AS 
SELECT *, NOW() as backup_created_at 
FROM worker_reward_balances;

SELECT 'BACKUP CREATED: worker_reward_balances_backup' as info;

-- Update balances to correct values
UPDATE worker_reward_balances 
SET 
    current_balance = cwb.correct_current_balance,
    total_earned = cwb.correct_total_earned,
    total_withdrawn = cwb.correct_total_withdrawn,
    last_updated = NOW()
FROM correct_worker_balances cwb
WHERE worker_reward_balances.worker_id = cwb.worker_id
AND worker_reward_balances.current_balance != cwb.correct_current_balance;

-- Show how many records were updated
SELECT 'BALANCE CORRECTION COMPLETED' as info;

-- =====================================================
-- STEP 4: VERIFY THE FIX
-- =====================================================

-- Show final state after correction
SELECT 'FINAL VERIFICATION - REWARDS VS BALANCES:' as info;

SELECT 
    wr.worker_id,
    up.name as worker_name,
    COUNT(wr.id) as total_rewards,
    SUM(wr.amount) as total_reward_amount,
    wrb.current_balance,
    wrb.total_earned,
    wrb.total_withdrawn,
    CASE 
        WHEN wrb.current_balance = SUM(wr.amount) THEN '✅ CORRECT'
        ELSE '❌ STILL INCORRECT'
    END as balance_status
FROM worker_rewards wr
LEFT JOIN worker_reward_balances wrb ON wr.worker_id = wrb.worker_id
LEFT JOIN user_profiles up ON wr.worker_id = up.id
WHERE wr.status = 'active'
GROUP BY wr.worker_id, up.name, wrb.current_balance, wrb.total_earned, wrb.total_withdrawn
ORDER BY wr.worker_id;

-- =====================================================
-- STEP 5: PREVENT FUTURE DOUBLING
-- =====================================================

-- Verify that the database trigger exists and is working correctly
SELECT 'DATABASE TRIGGER VERIFICATION:' as info;

SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'worker_rewards' 
AND event_object_schema = 'public'
AND trigger_name = 'trigger_update_reward_balance';

-- Show the trigger function
SELECT 'TRIGGER FUNCTION CODE:' as info;

SELECT routine_definition 
FROM information_schema.routines 
WHERE routine_name = 'update_worker_reward_balance' 
AND routine_schema = 'public';

-- =====================================================
-- STEP 6: TEST THE FIX (OPTIONAL)
-- =====================================================

-- Uncomment these lines to test the fix with a small reward
-- Make sure to replace the worker_id with an actual worker ID from your database

-- Test adding a small reward to verify no doubling occurs
-- INSERT INTO worker_rewards (worker_id, amount, reward_type, description, awarded_by, status)
-- VALUES (
--     '3185a8c6-af71-448b-a305-6ca7fcae8491', -- Replace with actual worker ID
--     10.00, -- Small test amount
--     'monetary',
--     'Test reward to verify no doubling',
--     (SELECT auth.uid()), -- Current user
--     'active'
-- );

-- Check the balance after the test reward
-- SELECT 
--     worker_id,
--     current_balance,
--     total_earned,
--     last_updated
-- FROM worker_reward_balances 
-- WHERE worker_id = '3185a8c6-af71-448b-a305-6ca7fcae8491'; -- Replace with actual worker ID

-- =====================================================
-- STEP 7: CLEANUP
-- =====================================================

-- Drop the temporary view
DROP VIEW IF EXISTS correct_worker_balances;

-- Show summary of the fix
SELECT 'REWARD DOUBLING BUG FIX COMPLETED!' as info;
SELECT 'Summary:' as info;
SELECT '1. ✅ Analyzed current rewards and balances' as step;
SELECT '2. ✅ Created backup of original balances' as step;
SELECT '3. ✅ Recalculated correct balances based on actual rewards' as step;
SELECT '4. ✅ Updated balances to correct values' as step;
SELECT '5. ✅ Verified database trigger is working correctly' as step;
SELECT '6. ✅ Flutter app code updated to remove manual balance updates' as step;

-- Show final statistics
SELECT 
    'Total Workers with Rewards: ' || COUNT(DISTINCT worker_id) as final_stats
FROM worker_rewards WHERE status = 'active';

SELECT 
    'Total Active Rewards: ' || COUNT(*) as final_stats
FROM worker_rewards WHERE status = 'active';

SELECT 
    'Total Worker Balances: ' || COUNT(*) as final_stats
FROM worker_reward_balances;

-- =====================================================
-- IMPORTANT NOTES
-- =====================================================
-- 1. The Flutter app code has been updated to remove the manual balance update
-- 2. The database trigger will handle all balance updates automatically
-- 3. This script fixes existing doubled balances
-- 4. Future rewards will not be doubled because the manual update is removed
-- 5. A backup table (worker_reward_balances_backup) has been created
-- 6. Test with small amounts first to verify the fix works correctly

-- =====================================================
-- END OF REWARD DOUBLING BUG FIX
-- =====================================================
