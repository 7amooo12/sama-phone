-- =====================================================
-- WAREHOUSE SCHEMA AND RELATIONSHIP OPTIMIZATION
-- =====================================================
-- This migration ensures all warehouse-related tables have proper
-- foreign key relationships, constraints, and performance indexes
-- to resolve the user_profiles relationship issues and improve
-- query performance for warehouse operations.
--
-- SAFETY GUARANTEES:
-- ✅ Idempotent - can run multiple times safely
-- ✅ No data loss - only adds constraints and indexes
-- ✅ Production-safe - preserves all existing data
-- ✅ Performance-focused - optimizes query execution
-- =====================================================

-- Step 1: Ensure user_profiles table exists with proper structure
DO $$
BEGIN
    -- Check if user_profiles table exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'user_profiles'
    ) THEN
        -- Create user_profiles table if it doesn't exist
        CREATE TABLE public.user_profiles (
            id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
            email TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            phone_number TEXT,
            role TEXT NOT NULL DEFAULT 'client',
            status TEXT NOT NULL DEFAULT 'pending',
            profile_image TEXT,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
            metadata JSONB DEFAULT '{}'::jsonb
        );
        
        RAISE NOTICE '✅ Created user_profiles table';
    ELSE
        RAISE NOTICE 'ℹ️ user_profiles table already exists';
    END IF;
END $$;

-- Step 2: Ensure warehouses table has proper foreign key to user_profiles
DO $$
BEGIN
    -- Check if manager_id column exists in warehouses table
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'warehouses' 
        AND column_name = 'manager_id'
    ) THEN
        -- Check if foreign key constraint exists
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
            WHERE tc.table_name = 'warehouses'
            AND tc.constraint_type = 'FOREIGN KEY'
            AND kcu.column_name = 'manager_id'
        ) THEN
            -- Add foreign key constraint
            ALTER TABLE public.warehouses
            ADD CONSTRAINT fk_warehouses_manager_id
            FOREIGN KEY (manager_id) REFERENCES public.user_profiles(id) ON DELETE SET NULL;
            
            RAISE NOTICE '✅ Added foreign key constraint for warehouses.manager_id';
        ELSE
            RAISE NOTICE 'ℹ️ Foreign key constraint for warehouses.manager_id already exists';
        END IF;
    END IF;
END $$;

-- Step 3: Fix warehouse_requests table relationships
DO $$
BEGIN
    -- Ensure warehouse_requests table exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'warehouse_requests'
    ) THEN
        -- Create warehouse_requests table with proper structure
        CREATE TABLE public.warehouse_requests (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            warehouse_id UUID,
            type TEXT NOT NULL DEFAULT 'general',
            status TEXT NOT NULL DEFAULT 'pending',
            reason TEXT,
            requested_by UUID,
            approved_by UUID,
            executed_by UUID,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
            metadata JSONB DEFAULT '{}'::jsonb
        );
        
        RAISE NOTICE '✅ Created warehouse_requests table';
    END IF;
    
    -- Add foreign key constraints for warehouse_requests
    -- requested_by -> user_profiles
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        WHERE tc.table_name = 'warehouse_requests'
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'requested_by'
    ) THEN
        ALTER TABLE public.warehouse_requests
        ADD CONSTRAINT fk_warehouse_requests_requested_by
        FOREIGN KEY (requested_by) REFERENCES public.user_profiles(id) ON DELETE SET NULL;
        
        RAISE NOTICE '✅ Added foreign key constraint for warehouse_requests.requested_by';
    END IF;
    
    -- approved_by -> user_profiles
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        WHERE tc.table_name = 'warehouse_requests'
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'approved_by'
    ) THEN
        ALTER TABLE public.warehouse_requests
        ADD CONSTRAINT fk_warehouse_requests_approved_by
        FOREIGN KEY (approved_by) REFERENCES public.user_profiles(id) ON DELETE SET NULL;
        
        RAISE NOTICE '✅ Added foreign key constraint for warehouse_requests.approved_by';
    END IF;
    
    -- executed_by -> user_profiles
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        WHERE tc.table_name = 'warehouse_requests'
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'executed_by'
    ) THEN
        ALTER TABLE public.warehouse_requests
        ADD CONSTRAINT fk_warehouse_requests_executed_by
        FOREIGN KEY (executed_by) REFERENCES public.user_profiles(id) ON DELETE SET NULL;
        
        RAISE NOTICE '✅ Added foreign key constraint for warehouse_requests.executed_by';
    END IF;
    
    -- warehouse_id -> warehouses (if warehouse_id is not null)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        WHERE tc.table_name = 'warehouse_requests'
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'warehouse_id'
    ) THEN
        ALTER TABLE public.warehouse_requests
        ADD CONSTRAINT fk_warehouse_requests_warehouse_id
        FOREIGN KEY (warehouse_id) REFERENCES public.warehouses(id) ON DELETE CASCADE;
        
        RAISE NOTICE '✅ Added foreign key constraint for warehouse_requests.warehouse_id';
    END IF;
END $$;

-- Step 4: Fix warehouse_inventory table relationships
DO $$
BEGIN
    -- updated_by -> user_profiles
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'warehouse_inventory' 
        AND column_name = 'updated_by'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
            WHERE tc.table_name = 'warehouse_inventory'
            AND tc.constraint_type = 'FOREIGN KEY'
            AND kcu.column_name = 'updated_by'
        ) THEN
            ALTER TABLE public.warehouse_inventory
            ADD CONSTRAINT fk_warehouse_inventory_updated_by
            FOREIGN KEY (updated_by) REFERENCES public.user_profiles(id) ON DELETE SET NULL;
            
            RAISE NOTICE '✅ Added foreign key constraint for warehouse_inventory.updated_by';
        END IF;
    END IF;
END $$;

-- Step 5: Fix warehouse_transactions table relationships
DO $$
BEGIN
    -- performed_by -> user_profiles
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'warehouse_transactions' 
        AND column_name = 'performed_by'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
            WHERE tc.table_name = 'warehouse_transactions'
            AND tc.constraint_type = 'FOREIGN KEY'
            AND kcu.column_name = 'performed_by'
        ) THEN
            ALTER TABLE public.warehouse_transactions
            ADD CONSTRAINT fk_warehouse_transactions_performed_by
            FOREIGN KEY (performed_by) REFERENCES public.user_profiles(id) ON DELETE SET NULL;
            
            RAISE NOTICE '✅ Added foreign key constraint for warehouse_transactions.performed_by';
        END IF;
    END IF;
END $$;

-- Step 6: Create comprehensive performance indexes
-- These indexes will significantly improve query performance for warehouse operations

-- Indexes for user_profiles table
CREATE INDEX IF NOT EXISTS idx_user_profiles_role 
ON public.user_profiles(role);

CREATE INDEX IF NOT EXISTS idx_user_profiles_status 
ON public.user_profiles(status);

CREATE INDEX IF NOT EXISTS idx_user_profiles_email 
ON public.user_profiles(email);

-- Indexes for warehouses table
CREATE INDEX IF NOT EXISTS idx_warehouses_manager_id 
ON public.warehouses(manager_id);

CREATE INDEX IF NOT EXISTS idx_warehouses_is_active 
ON public.warehouses(is_active) WHERE is_active = true;

-- Indexes for warehouse_requests table (already added in performance migration)
CREATE INDEX IF NOT EXISTS idx_warehouse_requests_requested_by 
ON public.warehouse_requests(requested_by);

CREATE INDEX IF NOT EXISTS idx_warehouse_requests_approved_by 
ON public.warehouse_requests(approved_by);

CREATE INDEX IF NOT EXISTS idx_warehouse_requests_executed_by 
ON public.warehouse_requests(executed_by);

-- Indexes for warehouse_inventory table
CREATE INDEX IF NOT EXISTS idx_warehouse_inventory_updated_by 
ON public.warehouse_inventory(updated_by);

-- Indexes for warehouse_transactions table
CREATE INDEX IF NOT EXISTS idx_warehouse_transactions_performed_by 
ON public.warehouse_transactions(performed_by);

-- Step 7: Update table statistics for query planner optimization
ANALYZE public.user_profiles;
ANALYZE public.warehouses;
ANALYZE public.warehouse_requests;
ANALYZE public.warehouse_inventory;
ANALYZE public.warehouse_transactions;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Warehouse schema and relationship optimization completed successfully!';
    RAISE NOTICE '🔗 All foreign key relationships verified and created';
    RAISE NOTICE '📊 Performance indexes added for optimal query execution';
    RAISE NOTICE '⚡ Database statistics updated for query planner optimization';
END $$;
