-- Fix Treasury Management RLS Policies
-- This migration fixes the Row-Level Security policies for treasury tables
-- to use the correct table name (user_profiles) and role values (English)
-- This migration is idempotent and can be run multiple times safely

-- Enable Row Level Security (idempotent)
ALTER TABLE treasury_vaults ENABLE ROW LEVEL SECURITY;
ALTER TABLE treasury_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE treasury_transactions ENABLE ROW LEVEL SECURITY;

-- Drop and recreate all treasury_vaults policies (idempotent)
DROP POLICY IF EXISTS "Users can view treasury vaults" ON treasury_vaults;
DROP POLICY IF EXISTS "Accountants and owners can manage treasury vaults" ON treasury_vaults;

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

-- Drop and recreate all treasury_connections policies (idempotent)
DROP POLICY IF EXISTS "Users can view treasury connections" ON treasury_connections;
DROP POLICY IF EXISTS "Accountants and owners can manage treasury connections" ON treasury_connections;

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

-- Drop and recreate all treasury_transactions policies (idempotent)
DROP POLICY IF EXISTS "Users can view treasury transactions" ON treasury_transactions;
DROP POLICY IF EXISTS "System can insert treasury transactions" ON treasury_transactions;

CREATE POLICY "Users can view treasury transactions" ON treasury_transactions
    FOR SELECT USING (true);

CREATE POLICY "System can insert treasury transactions" ON treasury_transactions
    FOR INSERT WITH CHECK (true);

-- Create function to safely create main treasury for authenticated users
CREATE OR REPLACE FUNCTION create_main_treasury_if_needed()
RETURNS UUID AS $$
DECLARE
    main_treasury_id UUID;
    current_user_id UUID;
BEGIN
    -- Get current authenticated user
    current_user_id := auth.uid();

    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated to create main treasury';
    END IF;

    -- Check if main treasury already exists
    SELECT id INTO main_treasury_id
    FROM treasury_vaults
    WHERE is_main_treasury = true
    LIMIT 1;

    -- Create main treasury if it doesn't exist
    IF main_treasury_id IS NULL THEN
        INSERT INTO treasury_vaults (
            name,
            currency,
            balance,
            is_main_treasury,
            created_by
        ) VALUES (
            'الخزنة الرئيسية',
            'EGP',
            0,
            true,
            current_user_id
        ) RETURNING id INTO main_treasury_id;

        RAISE NOTICE 'Created main treasury with ID: %', main_treasury_id;
    ELSE
        RAISE NOTICE 'Main treasury already exists with ID: %', main_treasury_id;
    END IF;

    RETURN main_treasury_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Verify the policies are working by testing with a sample query
-- This will help debug any remaining issues
DO $$
DECLARE
    policy_count INTEGER;
BEGIN
    -- Count policies on treasury_vaults
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE tablename = 'treasury_vaults'
    AND schemaname = 'public';

    RAISE NOTICE 'Treasury vaults policies count: %', policy_count;

    -- Count policies on treasury_connections
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE tablename = 'treasury_connections'
    AND schemaname = 'public';

    RAISE NOTICE 'Treasury connections policies count: %', policy_count;
END $$;
