-- Fix Duplicate Policy Error for Treasury Management
-- This migration specifically addresses the error:
-- "policy 'Users can view treasury vaults' for table 'treasury_vaults' already exists"
-- 
-- This migration is idempotent and safe to run multiple times

-- Step 1: Check current state and log it
DO $$
DECLARE
    existing_policies TEXT[];
    policy_name TEXT;
BEGIN
    RAISE NOTICE 'Starting treasury policy duplicate fix...';
    
    -- Get list of existing policies
    SELECT ARRAY_AGG(policyname) INTO existing_policies
    FROM pg_policies 
    WHERE tablename = 'treasury_vaults' AND schemaname = 'public';
    
    IF existing_policies IS NOT NULL THEN
        RAISE NOTICE 'Existing treasury_vaults policies: %', array_to_string(existing_policies, ', ');
        
        FOREACH policy_name IN ARRAY existing_policies
        LOOP
            RAISE NOTICE '  Found policy: "%"', policy_name;
        END LOOP;
    ELSE
        RAISE NOTICE 'No existing policies found for treasury_vaults';
    END IF;
END $$;

-- Step 2: Drop all potentially conflicting policies
-- This ensures we start with a clean slate

-- Drop treasury_vaults policies
DROP POLICY IF EXISTS "Users can view treasury vaults" ON treasury_vaults;
DROP POLICY IF EXISTS "Accountants and owners can manage treasury vaults" ON treasury_vaults;
DROP POLICY IF EXISTS "Treasury vaults are viewable by everyone" ON treasury_vaults;
DROP POLICY IF EXISTS "Treasury vaults manageable by authorized users" ON treasury_vaults;

-- Drop treasury_connections policies
DROP POLICY IF EXISTS "Users can view treasury connections" ON treasury_connections;
DROP POLICY IF EXISTS "Accountants and owners can manage treasury connections" ON treasury_connections;
DROP POLICY IF EXISTS "Treasury connections are viewable by everyone" ON treasury_connections;
DROP POLICY IF EXISTS "Treasury connections manageable by authorized users" ON treasury_connections;

-- Drop treasury_transactions policies
DROP POLICY IF EXISTS "Users can view treasury transactions" ON treasury_transactions;
DROP POLICY IF EXISTS "System can insert treasury transactions" ON treasury_transactions;
DROP POLICY IF EXISTS "Treasury transactions are viewable by everyone" ON treasury_transactions;
DROP POLICY IF EXISTS "Treasury transactions insertable by system" ON treasury_transactions;

-- Step 3: Ensure RLS is enabled (idempotent)
ALTER TABLE treasury_vaults ENABLE ROW LEVEL SECURITY;
ALTER TABLE treasury_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE treasury_transactions ENABLE ROW LEVEL SECURITY;

-- Step 4: Create the correct policies with proper error handling
DO $$
BEGIN
    -- Create treasury_vaults policies
    BEGIN
        CREATE POLICY "Users can view treasury vaults" ON treasury_vaults
            FOR SELECT USING (true);
        RAISE NOTICE 'Created policy: "Users can view treasury vaults"';
    EXCEPTION WHEN duplicate_object THEN
        RAISE NOTICE 'Policy "Users can view treasury vaults" already exists, skipping';
    END;
    
    BEGIN
        CREATE POLICY "Accountants and owners can manage treasury vaults" ON treasury_vaults
            FOR ALL USING (
                EXISTS (
                    SELECT 1 FROM public.user_profiles
                    WHERE user_profiles.id = auth.uid()
                    AND user_profiles.role IN ('accountant', 'owner', 'admin')
                    AND user_profiles.status IN ('approved', 'active')
                )
            );
        RAISE NOTICE 'Created policy: "Accountants and owners can manage treasury vaults"';
    EXCEPTION WHEN duplicate_object THEN
        RAISE NOTICE 'Policy "Accountants and owners can manage treasury vaults" already exists, skipping';
    END;
    
    -- Create treasury_connections policies
    BEGIN
        CREATE POLICY "Users can view treasury connections" ON treasury_connections
            FOR SELECT USING (true);
        RAISE NOTICE 'Created policy: "Users can view treasury connections"';
    EXCEPTION WHEN duplicate_object THEN
        RAISE NOTICE 'Policy "Users can view treasury connections" already exists, skipping';
    END;
    
    BEGIN
        CREATE POLICY "Accountants and owners can manage treasury connections" ON treasury_connections
            FOR ALL USING (
                EXISTS (
                    SELECT 1 FROM public.user_profiles
                    WHERE user_profiles.id = auth.uid()
                    AND user_profiles.role IN ('accountant', 'owner', 'admin')
                    AND user_profiles.status IN ('approved', 'active')
                )
            );
        RAISE NOTICE 'Created policy: "Accountants and owners can manage treasury connections"';
    EXCEPTION WHEN duplicate_object THEN
        RAISE NOTICE 'Policy "Accountants and owners can manage treasury connections" already exists, skipping';
    END;
    
    -- Create treasury_transactions policies
    BEGIN
        CREATE POLICY "Users can view treasury transactions" ON treasury_transactions
            FOR SELECT USING (true);
        RAISE NOTICE 'Created policy: "Users can view treasury transactions"';
    EXCEPTION WHEN duplicate_object THEN
        RAISE NOTICE 'Policy "Users can view treasury transactions" already exists, skipping';
    END;
    
    BEGIN
        CREATE POLICY "System can insert treasury transactions" ON treasury_transactions
            FOR INSERT WITH CHECK (true);
        RAISE NOTICE 'Created policy: "System can insert treasury transactions"';
    EXCEPTION WHEN duplicate_object THEN
        RAISE NOTICE 'Policy "System can insert treasury transactions" already exists, skipping';
    END;
END $$;

-- Step 5: Verify the fix
DO $$
DECLARE
    vault_count INTEGER;
    connection_count INTEGER;
    transaction_count INTEGER;
    policy_record RECORD;
BEGIN
    RAISE NOTICE 'Verifying treasury policy fix...';
    
    -- Count policies for each table
    SELECT COUNT(*) INTO vault_count
    FROM pg_policies 
    WHERE tablename = 'treasury_vaults' AND schemaname = 'public';
    
    SELECT COUNT(*) INTO connection_count
    FROM pg_policies 
    WHERE tablename = 'treasury_connections' AND schemaname = 'public';
    
    SELECT COUNT(*) INTO transaction_count
    FROM pg_policies 
    WHERE tablename = 'treasury_transactions' AND schemaname = 'public';
    
    RAISE NOTICE 'Policy counts after fix:';
    RAISE NOTICE '  treasury_vaults: % policies', vault_count;
    RAISE NOTICE '  treasury_connections: % policies', connection_count;
    RAISE NOTICE '  treasury_transactions: % policies', transaction_count;
    
    -- List all policies for verification
    RAISE NOTICE 'Final policy list:';
    FOR policy_record IN 
        SELECT tablename, policyname
        FROM pg_policies 
        WHERE tablename IN ('treasury_vaults', 'treasury_connections', 'treasury_transactions')
        AND schemaname = 'public'
        ORDER BY tablename, policyname
    LOOP
        RAISE NOTICE '  %: "%"', policy_record.tablename, policy_record.policyname;
    END LOOP;
    
    -- Final status
    IF vault_count = 2 AND connection_count = 2 AND transaction_count = 2 THEN
        RAISE NOTICE 'SUCCESS: Treasury policy duplicate fix completed successfully';
    ELSE
        RAISE WARNING 'WARNING: Unexpected policy counts after fix';
    END IF;
END $$;
