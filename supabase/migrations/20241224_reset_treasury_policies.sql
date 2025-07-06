-- Reset and Fix All Treasury Management RLS Policies
-- This migration completely resets all treasury-related RLS policies
-- and recreates them with the correct configuration
-- This migration is idempotent and safe to run multiple times

-- Step 1: Enable Row Level Security on all treasury tables
ALTER TABLE treasury_vaults ENABLE ROW LEVEL SECURITY;
ALTER TABLE treasury_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE treasury_transactions ENABLE ROW LEVEL SECURITY;

-- Step 2: Drop ALL existing treasury policies to ensure clean state
-- treasury_vaults policies
DROP POLICY IF EXISTS "Users can view treasury vaults" ON treasury_vaults;
DROP POLICY IF EXISTS "Accountants and owners can manage treasury vaults" ON treasury_vaults;
DROP POLICY IF EXISTS "Treasury vaults are viewable by everyone" ON treasury_vaults;
DROP POLICY IF EXISTS "Treasury vaults manageable by authorized users" ON treasury_vaults;

-- treasury_connections policies  
DROP POLICY IF EXISTS "Users can view treasury connections" ON treasury_connections;
DROP POLICY IF EXISTS "Accountants and owners can manage treasury connections" ON treasury_connections;
DROP POLICY IF EXISTS "Treasury connections are viewable by everyone" ON treasury_connections;
DROP POLICY IF EXISTS "Treasury connections manageable by authorized users" ON treasury_connections;

-- treasury_transactions policies
DROP POLICY IF EXISTS "Users can view treasury transactions" ON treasury_transactions;
DROP POLICY IF EXISTS "System can insert treasury transactions" ON treasury_transactions;
DROP POLICY IF EXISTS "Treasury transactions are viewable by everyone" ON treasury_transactions;
DROP POLICY IF EXISTS "Treasury transactions insertable by system" ON treasury_transactions;

-- Step 3: Create standardized RLS policies for treasury_vaults
CREATE POLICY "Users can view treasury vaults" ON treasury_vaults
    FOR SELECT USING (true);

CREATE POLICY "Accountants and owners can manage treasury vaults" ON treasury_vaults
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE user_profiles.id = auth.uid()
            AND user_profiles.role IN ('accountant', 'owner', 'admin')
            AND user_profiles.status IN ('approved', 'active')
        )
    );

-- Step 4: Create standardized RLS policies for treasury_connections
CREATE POLICY "Users can view treasury connections" ON treasury_connections
    FOR SELECT USING (true);

CREATE POLICY "Accountants and owners can manage treasury connections" ON treasury_connections
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE user_profiles.id = auth.uid()
            AND user_profiles.role IN ('accountant', 'owner', 'admin')
            AND user_profiles.status IN ('approved', 'active')
        )
    );

-- Step 5: Create standardized RLS policies for treasury_transactions
CREATE POLICY "Users can view treasury transactions" ON treasury_transactions
    FOR SELECT USING (true);

CREATE POLICY "System can insert treasury transactions" ON treasury_transactions
    FOR INSERT WITH CHECK (true);

-- Step 6: Verify policy creation
DO $$
DECLARE
    vault_policies INTEGER;
    connection_policies INTEGER;
    transaction_policies INTEGER;
BEGIN
    -- Count policies for each table
    SELECT COUNT(*) INTO vault_policies
    FROM pg_policies 
    WHERE tablename = 'treasury_vaults' AND schemaname = 'public';
    
    SELECT COUNT(*) INTO connection_policies
    FROM pg_policies 
    WHERE tablename = 'treasury_connections' AND schemaname = 'public';
    
    SELECT COUNT(*) INTO transaction_policies
    FROM pg_policies 
    WHERE tablename = 'treasury_transactions' AND schemaname = 'public';
    
    RAISE NOTICE 'Treasury RLS Policies Created:';
    RAISE NOTICE '  treasury_vaults: % policies', vault_policies;
    RAISE NOTICE '  treasury_connections: % policies', connection_policies;
    RAISE NOTICE '  treasury_transactions: % policies', transaction_policies;
    
    -- Verify expected policy counts
    IF vault_policies != 2 THEN
        RAISE WARNING 'Expected 2 policies for treasury_vaults, found %', vault_policies;
    END IF;
    
    IF connection_policies != 2 THEN
        RAISE WARNING 'Expected 2 policies for treasury_connections, found %', connection_policies;
    END IF;
    
    IF transaction_policies != 2 THEN
        RAISE WARNING 'Expected 2 policies for treasury_transactions, found %', transaction_policies;
    END IF;
    
    IF vault_policies = 2 AND connection_policies = 2 AND transaction_policies = 2 THEN
        RAISE NOTICE 'SUCCESS: All treasury RLS policies created correctly';
    END IF;
END $$;

-- Step 7: List all created policies for verification
DO $$
DECLARE
    policy_record RECORD;
BEGIN
    RAISE NOTICE 'Treasury RLS Policy Details:';
    
    FOR policy_record IN 
        SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
        FROM pg_policies 
        WHERE tablename IN ('treasury_vaults', 'treasury_connections', 'treasury_transactions')
        AND schemaname = 'public'
        ORDER BY tablename, policyname
    LOOP
        RAISE NOTICE '  Table: %, Policy: %, Command: %', 
            policy_record.tablename, 
            policy_record.policyname, 
            policy_record.cmd;
    END LOOP;
END $$;
