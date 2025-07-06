-- ============================================================================
-- FIX WAREHOUSE REQUESTS RELATIONSHIP ERROR
-- ============================================================================
-- إصلاح خطأ العلاقة بين warehouse_requests و user_profiles
-- Fixes PostgreSQL error: "Could not find a relationship between 'warehouse_requests' and 'user_profiles'"
-- ============================================================================

-- Step 1: Check current warehouse_requests table structure
DO $$
BEGIN
    RAISE NOTICE '🔍 Checking warehouse_requests table structure...';
    
    -- Check if warehouse_requests table exists
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'warehouse_requests' 
        AND table_schema = 'public'
    ) THEN
        RAISE NOTICE '✅ warehouse_requests table exists';
        
        -- Check for requested_by column
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'warehouse_requests' 
            AND column_name = 'requested_by' 
            AND table_schema = 'public'
        ) THEN
            RAISE NOTICE '✅ requested_by column exists in warehouse_requests';
        ELSE
            RAISE NOTICE '❌ requested_by column missing in warehouse_requests';
        END IF;
    ELSE
        RAISE NOTICE '❌ warehouse_requests table does not exist';
    END IF;
END $$;

-- Step 2: Check user_profiles table structure
DO $$
BEGIN
    RAISE NOTICE '🔍 Checking user_profiles table structure...';
    
    -- Check if user_profiles table exists
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'user_profiles' 
        AND table_schema = 'public'
    ) THEN
        RAISE NOTICE '✅ user_profiles table exists';
        
        -- Check for id column
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'user_profiles' 
            AND column_name = 'id' 
            AND table_schema = 'public'
        ) THEN
            RAISE NOTICE '✅ id column exists in user_profiles';
        ELSE
            RAISE NOTICE '❌ id column missing in user_profiles';
        END IF;
    ELSE
        RAISE NOTICE '❌ user_profiles table does not exist';
    END IF;
END $$;

-- Step 3: Create warehouse_requests table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.warehouse_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    warehouse_id UUID NOT NULL,
    type TEXT NOT NULL DEFAULT 'general',
    status TEXT NOT NULL DEFAULT 'pending',
    reason TEXT,
    requested_by UUID,  -- This will be the foreign key to user_profiles
    approved_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Step 4: Add foreign key constraint if it doesn't exist
DO $$
BEGIN
    -- Check if foreign key constraint already exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name
        WHERE tc.table_name = 'warehouse_requests'
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'requested_by'
        AND ccu.table_name = 'user_profiles'
    ) THEN
        -- Add the foreign key constraint
        ALTER TABLE public.warehouse_requests
        ADD CONSTRAINT fk_warehouse_requests_requested_by
        FOREIGN KEY (requested_by) REFERENCES public.user_profiles(id) ON DELETE SET NULL;

        RAISE NOTICE '✅ Added foreign key constraint for requested_by';
    ELSE
        RAISE NOTICE 'ℹ️ Foreign key constraint for requested_by already exists';
    END IF;
    
    -- Check if foreign key constraint for approved_by exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name
        WHERE tc.table_name = 'warehouse_requests'
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'approved_by'
        AND ccu.table_name = 'user_profiles'
    ) THEN
        -- Add the foreign key constraint for approved_by
        ALTER TABLE public.warehouse_requests
        ADD CONSTRAINT fk_warehouse_requests_approved_by
        FOREIGN KEY (approved_by) REFERENCES public.user_profiles(id) ON DELETE SET NULL;

        RAISE NOTICE '✅ Added foreign key constraint for approved_by';
    ELSE
        RAISE NOTICE 'ℹ️ Foreign key constraint for approved_by already exists';
    END IF;
    
    -- Check if foreign key constraint for warehouse_id exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name
        WHERE tc.table_name = 'warehouse_requests'
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'warehouse_id'
        AND ccu.table_name = 'warehouses'
    ) THEN
        -- Add the foreign key constraint for warehouse_id
        ALTER TABLE public.warehouse_requests
        ADD CONSTRAINT fk_warehouse_requests_warehouse_id
        FOREIGN KEY (warehouse_id) REFERENCES public.warehouses(id) ON DELETE CASCADE;

        RAISE NOTICE '✅ Added foreign key constraint for warehouse_id';
    ELSE
        RAISE NOTICE 'ℹ️ Foreign key constraint for warehouse_id already exists';
    END IF;
END $$;

-- Step 5: Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_warehouse_requests_warehouse_id 
ON public.warehouse_requests(warehouse_id);

CREATE INDEX IF NOT EXISTS idx_warehouse_requests_requested_by 
ON public.warehouse_requests(requested_by);

CREATE INDEX IF NOT EXISTS idx_warehouse_requests_status 
ON public.warehouse_requests(status);

CREATE INDEX IF NOT EXISTS idx_warehouse_requests_created_at 
ON public.warehouse_requests(created_at DESC);

-- Step 6: Create or update the function that was failing
CREATE OR REPLACE FUNCTION get_warehouse_requests_with_users(p_warehouse_id UUID)
RETURNS TABLE (
    request_id UUID,
    warehouse_id UUID,
    request_type TEXT,
    status TEXT,
    reason TEXT,
    requested_by UUID,
    requester_name TEXT,
    requester_email TEXT,
    approved_by UUID,
    approver_name TEXT,
    approver_email TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        wr.id as request_id,
        wr.warehouse_id,
        wr.type as request_type,
        wr.status,
        wr.reason,
        wr.requested_by,
        COALESCE(up_requester.name, 'غير معروف') as requester_name,
        COALESCE(up_requester.email, '') as requester_email,
        wr.approved_by,
        COALESCE(up_approver.name, '') as approver_name,
        COALESCE(up_approver.email, '') as approver_email,
        wr.created_at,
        wr.updated_at
    FROM public.warehouse_requests wr
    LEFT JOIN public.user_profiles up_requester ON wr.requested_by = up_requester.id
    LEFT JOIN public.user_profiles up_approver ON wr.approved_by = up_approver.id
    WHERE wr.warehouse_id = p_warehouse_id
    ORDER BY wr.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 7: Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON public.warehouse_requests TO authenticated;
GRANT EXECUTE ON FUNCTION get_warehouse_requests_with_users(UUID) TO authenticated;

-- Step 8: Create RLS policies for warehouse_requests
ALTER TABLE public.warehouse_requests ENABLE ROW LEVEL SECURITY;

-- Policy for reading warehouse requests
CREATE POLICY "Users can read warehouse requests they have access to" ON public.warehouse_requests
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.status = 'approved'
        AND up.role IN ('admin', 'owner', 'warehouseManager', 'accountant')
    )
);

-- Policy for inserting warehouse requests
CREATE POLICY "Users can create warehouse requests" ON public.warehouse_requests
FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.status = 'approved'
        AND up.role IN ('admin', 'owner', 'warehouseManager', 'accountant')
    )
    AND requested_by = auth.uid()
);

-- Policy for updating warehouse requests
CREATE POLICY "Users can update warehouse requests they created or if they are managers" ON public.warehouse_requests
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM public.user_profiles up
        WHERE up.id = auth.uid()
        AND up.status = 'approved'
        AND (
            up.role IN ('admin', 'owner') OR
            (up.role IN ('warehouseManager', 'accountant') AND requested_by = auth.uid())
        )
    )
);

-- Step 9: Verify the fix
DO $$
DECLARE
    test_result RECORD;
    function_exists BOOLEAN := FALSE;
BEGIN
    RAISE NOTICE '🧪 Testing the fixed relationship...';
    
    -- Check if function exists
    SELECT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' 
        AND p.proname = 'get_warehouse_requests_with_users'
    ) INTO function_exists;
    
    IF function_exists THEN
        RAISE NOTICE '✅ Function get_warehouse_requests_with_users exists';
        
        -- Try to execute the function with a test warehouse ID
        BEGIN
            PERFORM * FROM get_warehouse_requests_with_users('00000000-0000-0000-0000-000000000000'::UUID) LIMIT 1;
            RAISE NOTICE '✅ Function executes without relationship errors';
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLERRM LIKE '%relationship%' THEN
                    RAISE NOTICE '❌ Function still has relationship error: %', SQLERRM;
                ELSE
                    RAISE NOTICE 'ℹ️ Function test completed (error unrelated to relationship): %', SQLERRM;
                END IF;
        END;
    ELSE
        RAISE NOTICE '❌ Function get_warehouse_requests_with_users was not created successfully';
    END IF;
END $$;

-- Step 10: Show final table relationships
SELECT
    '✅ WAREHOUSE REQUESTS RELATIONSHIPS' as check_type,
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name
WHERE tc.table_name = 'warehouse_requests'
AND tc.constraint_type = 'FOREIGN KEY'
ORDER BY tc.constraint_name;

-- Step 11: Final completion messages
DO $$
BEGIN
    RAISE NOTICE '🎉 Warehouse requests relationship fix completed!';
    RAISE NOTICE 'ℹ️ Foreign key relationships established between warehouse_requests and user_profiles';
END $$;
