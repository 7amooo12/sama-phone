-- Diagnose Treasury Management RLS Policies
-- This script checks the current state of treasury-related RLS policies
-- Run this before applying any policy fixes to understand the current state

-- Check if tables exist and have RLS enabled
DO $$
DECLARE
    table_record RECORD;
BEGIN
    RAISE NOTICE '=== TREASURY TABLES AND RLS STATUS ===';
    
    FOR table_record IN 
        SELECT 
            schemaname,
            tablename,
            rowsecurity as rls_enabled
        FROM pg_tables 
        WHERE tablename IN ('treasury_vaults', 'treasury_connections', 'treasury_transactions')
        AND schemaname = 'public'
        ORDER BY tablename
    LOOP
        RAISE NOTICE 'Table: %.% - RLS Enabled: %', 
            table_record.schemaname,
            table_record.tablename, 
            table_record.rls_enabled;
    END LOOP;
END $$;

-- Check existing policies
DO $$
DECLARE
    policy_record RECORD;
    table_name TEXT;
    policy_count INTEGER;
BEGIN
    RAISE NOTICE '=== EXISTING TREASURY RLS POLICIES ===';
    
    -- Check each treasury table
    FOR table_name IN VALUES ('treasury_vaults'), ('treasury_connections'), ('treasury_transactions')
    LOOP
        SELECT COUNT(*) INTO policy_count
        FROM pg_policies 
        WHERE tablename = table_name AND schemaname = 'public';
        
        RAISE NOTICE 'Table: % - Policy Count: %', table_name, policy_count;
        
        -- List individual policies
        FOR policy_record IN 
            SELECT policyname, cmd, permissive
            FROM pg_policies 
            WHERE tablename = table_name AND schemaname = 'public'
            ORDER BY policyname
        LOOP
            RAISE NOTICE '  Policy: "%" - Command: % - Permissive: %', 
                policy_record.policyname,
                policy_record.cmd,
                policy_record.permissive;
        END LOOP;
        
        IF policy_count = 0 THEN
            RAISE NOTICE '  No policies found for %', table_name;
        END IF;
    END LOOP;
END $$;

-- Check for duplicate or conflicting policies
DO $$
DECLARE
    duplicate_record RECORD;
    duplicate_count INTEGER := 0;
BEGIN
    RAISE NOTICE '=== CHECKING FOR DUPLICATE POLICIES ===';
    
    -- Look for policies with similar names that might conflict
    FOR duplicate_record IN 
        SELECT 
            tablename,
            policyname,
            COUNT(*) as count
        FROM pg_policies 
        WHERE tablename IN ('treasury_vaults', 'treasury_connections', 'treasury_transactions')
        AND schemaname = 'public'
        GROUP BY tablename, policyname
        HAVING COUNT(*) > 1
    LOOP
        RAISE WARNING 'DUPLICATE POLICY: Table "%" has % policies named "%"', 
            duplicate_record.tablename,
            duplicate_record.count,
            duplicate_record.policyname;
        duplicate_count := duplicate_count + 1;
    END LOOP;
    
    IF duplicate_count = 0 THEN
        RAISE NOTICE 'No duplicate policies found';
    ELSE
        RAISE WARNING 'Found % duplicate policy names', duplicate_count;
    END IF;
END $$;

-- Check policy definitions for common issues
DO $$
DECLARE
    policy_record RECORD;
    issue_count INTEGER := 0;
BEGIN
    RAISE NOTICE '=== CHECKING POLICY DEFINITIONS FOR ISSUES ===';
    
    FOR policy_record IN 
        SELECT 
            tablename,
            policyname,
            qual,
            with_check
        FROM pg_policies 
        WHERE tablename IN ('treasury_vaults', 'treasury_connections', 'treasury_transactions')
        AND schemaname = 'public'
        ORDER BY tablename, policyname
    LOOP
        -- Check for references to 'users' table instead of 'user_profiles'
        IF policy_record.qual LIKE '%FROM users%' OR policy_record.with_check LIKE '%FROM users%' THEN
            RAISE WARNING 'Policy "%" on table "%" references "users" table instead of "user_profiles"',
                policy_record.policyname,
                policy_record.tablename;
            issue_count := issue_count + 1;
        END IF;
        
        -- Check for Arabic role names
        IF policy_record.qual LIKE '%محاسب%' OR policy_record.qual LIKE '%صاحب العمل%' OR
           policy_record.with_check LIKE '%محاسب%' OR policy_record.with_check LIKE '%صاحب العمل%' THEN
            RAISE WARNING 'Policy "%" on table "%" uses Arabic role names instead of English',
                policy_record.policyname,
                policy_record.tablename;
            issue_count := issue_count + 1;
        END IF;
    END LOOP;
    
    IF issue_count = 0 THEN
        RAISE NOTICE 'No policy definition issues found';
    ELSE
        RAISE WARNING 'Found % policy definition issues', issue_count;
    END IF;
END $$;

-- Summary and recommendations
DO $$
DECLARE
    total_policies INTEGER;
    vault_policies INTEGER;
    connection_policies INTEGER;
    transaction_policies INTEGER;
BEGIN
    RAISE NOTICE '=== SUMMARY AND RECOMMENDATIONS ===';
    
    -- Count policies by table
    SELECT COUNT(*) INTO vault_policies
    FROM pg_policies 
    WHERE tablename = 'treasury_vaults' AND schemaname = 'public';
    
    SELECT COUNT(*) INTO connection_policies
    FROM pg_policies 
    WHERE tablename = 'treasury_connections' AND schemaname = 'public';
    
    SELECT COUNT(*) INTO transaction_policies
    FROM pg_policies 
    WHERE tablename = 'treasury_transactions' AND schemaname = 'public';
    
    total_policies := vault_policies + connection_policies + transaction_policies;
    
    RAISE NOTICE 'Total treasury policies: %', total_policies;
    RAISE NOTICE '  treasury_vaults: %', vault_policies;
    RAISE NOTICE '  treasury_connections: %', connection_policies;
    RAISE NOTICE '  treasury_transactions: %', transaction_policies;
    
    -- Provide recommendations
    IF total_policies = 0 THEN
        RAISE NOTICE 'RECOMMENDATION: Run the main treasury migration to create policies';
    ELSIF vault_policies != 2 OR connection_policies != 2 OR transaction_policies != 2 THEN
        RAISE NOTICE 'RECOMMENDATION: Run the policy reset migration to fix policy count';
    ELSE
        RAISE NOTICE 'RECOMMENDATION: Policy count looks correct, check for definition issues';
    END IF;
    
    RAISE NOTICE 'Expected policy structure:';
    RAISE NOTICE '  Each table should have exactly 2 policies:';
    RAISE NOTICE '    1. SELECT policy for viewing (open to all)';
    RAISE NOTICE '    2. ALL policy for management (restricted to authorized roles)';
END $$;
