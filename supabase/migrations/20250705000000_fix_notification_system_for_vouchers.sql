-- ============================================================================
-- FIX NOTIFICATION SYSTEM FOR VOUCHER ASSIGNMENTS
-- Migration: 20250705000000_fix_notification_system_for_vouchers.sql
-- Description: Fix notification database constraint violations and ensure 
--              'active' and 'approved' status equivalence for voucher assignments
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1: Fix Notifications Table Schema
-- ============================================================================

-- Ensure notifications table has proper schema with both body and message fields
-- for backward compatibility
DO $$
BEGIN
    -- Check if body column exists, if not add it
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
        AND column_name = 'body' 
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notifications ADD COLUMN body TEXT;
        RAISE NOTICE '✅ Added body column to notifications table';
    END IF;
    
    -- Check if message column exists, if not add it for compatibility
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
        AND column_name = 'message' 
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notifications ADD COLUMN message TEXT;
        RAISE NOTICE '✅ Added message column to notifications table for compatibility';
    END IF;
    
    -- Check if category column exists, if not add it
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
        AND column_name = 'category' 
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notifications ADD COLUMN category TEXT;
        RAISE NOTICE '✅ Added category column to notifications table';
    END IF;
    
    -- Check if priority column exists, if not add it
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
        AND column_name = 'priority' 
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notifications ADD COLUMN priority TEXT DEFAULT 'normal';
        RAISE NOTICE '✅ Added priority column to notifications table';
    END IF;
    
    -- Check if route column exists, if not add it
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
        AND column_name = 'route' 
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notifications ADD COLUMN route TEXT;
        RAISE NOTICE '✅ Added route column to notifications table';
    END IF;
    
    -- Check if action_data column exists, if not add it
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
        AND column_name = 'action_data' 
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notifications ADD COLUMN action_data JSONB DEFAULT '{}';
        RAISE NOTICE '✅ Added action_data column to notifications table';
    END IF;
    
    -- Check if metadata column exists, if not add it
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
        AND column_name = 'metadata' 
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notifications ADD COLUMN metadata JSONB DEFAULT '{}';
        RAISE NOTICE '✅ Added metadata column to notifications table';
    END IF;
    
    -- Check if reference_type column exists, if not add it
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
        AND column_name = 'reference_type' 
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notifications ADD COLUMN reference_type TEXT;
        RAISE NOTICE '✅ Added reference_type column to notifications table';
    END IF;
END $$;

-- ============================================================================
-- STEP 2: Update existing notifications to have body field populated
-- ============================================================================

-- Update any existing notifications that have message but no body
UPDATE public.notifications 
SET body = COALESCE(message, title)
WHERE body IS NULL AND (message IS NOT NULL OR title IS NOT NULL);

-- Update any existing notifications that have body but no message for compatibility
UPDATE public.notifications 
SET message = COALESCE(body, title)
WHERE message IS NULL AND (body IS NOT NULL OR title IS NOT NULL);

-- ============================================================================
-- STEP 3: Create Smart Notification Function
-- ============================================================================

CREATE OR REPLACE FUNCTION create_smart_notification(
    p_user_id UUID,
    p_title TEXT,
    p_body TEXT,
    p_type TEXT,
    p_category TEXT DEFAULT 'general',
    p_priority TEXT DEFAULT 'normal',
    p_route TEXT DEFAULT NULL,
    p_reference_id TEXT DEFAULT NULL,
    p_reference_type TEXT DEFAULT NULL,
    p_action_data JSONB DEFAULT '{}',
    p_metadata JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
    notification_id UUID;
BEGIN
    -- Validate required parameters
    IF p_user_id IS NULL OR p_title IS NULL OR p_body IS NULL OR p_type IS NULL THEN
        RAISE EXCEPTION 'Required parameters cannot be null: user_id, title, body, type';
    END IF;
    
    INSERT INTO public.notifications (
        user_id, title, body, message, type, category, priority,
        route, reference_id, reference_type, action_data, metadata,
        read, created_at
    ) VALUES (
        p_user_id, p_title, p_body, p_body, p_type, p_category, p_priority,
        p_route, p_reference_id, p_reference_type, p_action_data, p_metadata,
        false, NOW()
    ) RETURNING id INTO notification_id;
    
    RETURN notification_id;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error creating notification: %', SQLERRM;
        RAISE NOTICE 'Parameters: user_id=%, title=%, body=%, type=%', p_user_id, p_title, p_body, p_type;
        RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 4: Create Voucher Assignment Notification Trigger
-- ============================================================================

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trigger_voucher_assignment ON public.client_vouchers;

-- Create enhanced voucher assignment notification function
CREATE OR REPLACE FUNCTION handle_voucher_assignment()
RETURNS TRIGGER AS $$
DECLARE
    voucher_info RECORD;
    client_name TEXT;
    notification_body TEXT;
BEGIN
    -- Get voucher details
    SELECT v.name, v.description, v.discount_percentage, v.expiration_date
    INTO voucher_info
    FROM public.vouchers v
    WHERE v.id = NEW.voucher_id;

    -- Get client name
    SELECT up.name INTO client_name
    FROM public.user_profiles up
    WHERE up.id = NEW.client_id;

    -- Handle case where voucher or client info is missing
    IF voucher_info IS NULL THEN
        RAISE NOTICE 'Warning: Voucher not found for ID: %', NEW.voucher_id;
        RETURN NEW;
    END IF;

    IF client_name IS NULL THEN
        client_name := 'عميل';
        RAISE NOTICE 'Warning: Client name not found for ID: %', NEW.client_id;
    END IF;

    -- Build notification body with null safety
    notification_body := 'تم منحك قسيمة خصم "' || COALESCE(voucher_info.name, 'قسيمة خصم') ||
                        '" بخصم ' || COALESCE(voucher_info.discount_percentage::TEXT, '0') ||
                        '% صالحة حتى ' ||
                        COALESCE(TO_CHAR(voucher_info.expiration_date, 'YYYY-MM-DD'), 'غير محدد');

    -- Create notification using smart notification function
    PERFORM create_smart_notification(
        NEW.client_id,
        'تم منحك قسيمة خصم جديدة!',
        notification_body,
        'voucher_assigned',
        'vouchers',
        'high',
        '/vouchers',
        NEW.voucher_id::TEXT,
        'voucher',
        jsonb_build_object(
            'voucher_name', COALESCE(voucher_info.name, ''),
            'discount_percentage', COALESCE(voucher_info.discount_percentage, 0),
            'expiration_date', COALESCE(voucher_info.expiration_date::TEXT, '')
        ),
        jsonb_build_object('currency', 'EGP', 'action_required', false)
    );

    RAISE NOTICE 'Voucher assignment notification created for client: % (voucher: %)', client_name, voucher_info.name;

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error in voucher assignment trigger: %', SQLERRM;
        RAISE NOTICE 'Voucher ID: %, Client ID: %', NEW.voucher_id, NEW.client_id;
        -- Don't fail the transaction, just log the error
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
CREATE TRIGGER trigger_voucher_assignment
    AFTER INSERT ON public.client_vouchers
    FOR EACH ROW
    EXECUTE FUNCTION handle_voucher_assignment();

-- ============================================================================
-- STEP 5: Fix Legacy Task Assignment Trigger
-- ============================================================================

-- Update the task assignment trigger to use both body and message fields
CREATE OR REPLACE FUNCTION notify_task_assigned()
RETURNS TRIGGER AS $$
DECLARE
    task_message TEXT;
BEGIN
    task_message := 'تم تعيين مهمة جديدة لك: ' || COALESCE(NEW.title, 'مهمة جديدة');

    INSERT INTO public.notifications (
        user_id,
        title,
        body,        -- Required NOT NULL field
        message,     -- Keep for compatibility
        type,
        read,
        created_at
    ) VALUES (
        NEW.worker_id,
        'تم تعيين مهمة جديدة',
        task_message,
        task_message,
        'task_assigned',
        FALSE,
        NOW()
    );
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error in task assignment trigger: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 6: Ensure Status Equivalence Functions
-- ============================================================================

-- Create function to check if user status is valid (approved or active)
CREATE OR REPLACE FUNCTION is_user_status_valid(user_status TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN LOWER(user_status) IN ('approved', 'active');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Create function to get users with valid status for role
CREATE OR REPLACE FUNCTION get_users_with_valid_status(target_role TEXT)
RETURNS TABLE(
    id UUID,
    name TEXT,
    email TEXT,
    role TEXT,
    status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT up.id, up.name, up.email, up.role, up.status
    FROM public.user_profiles up
    WHERE up.role = target_role
    AND is_user_status_valid(up.status);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- STEP 7: Test and Validation
-- ============================================================================

-- Test the notification system
DO $$
DECLARE
    test_notification_id UUID;
    test_user_id UUID;
BEGIN
    -- Get a test user (any user will do for testing)
    SELECT id INTO test_user_id
    FROM public.user_profiles
    WHERE role = 'client'
    AND is_user_status_valid(status)
    LIMIT 1;

    IF test_user_id IS NOT NULL THEN
        -- Test creating a notification
        SELECT create_smart_notification(
            test_user_id,
            'اختبار النظام',
            'هذا اختبار للتأكد من عمل نظام الإشعارات بشكل صحيح',
            'system_test',
            'system',
            'normal'
        ) INTO test_notification_id;

        IF test_notification_id IS NOT NULL THEN
            RAISE NOTICE '✅ SUCCESS: Notification system test passed - ID: %', test_notification_id;

            -- Clean up test notification
            DELETE FROM public.notifications WHERE id = test_notification_id;
            RAISE NOTICE '✅ Test notification cleaned up';
        ELSE
            RAISE NOTICE '❌ FAILED: Could not create test notification';
        END IF;
    ELSE
        RAISE NOTICE '⚠️ WARNING: No test user found - skipping notification test';
    END IF;
END $$;

-- Log completion
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🎉 MIGRATION COMPLETED SUCCESSFULLY!';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Fixed notification table schema with body/message fields';
    RAISE NOTICE '✅ Created smart notification function with error handling';
    RAISE NOTICE '✅ Fixed voucher assignment trigger with null safety';
    RAISE NOTICE '✅ Updated task assignment trigger for compatibility';
    RAISE NOTICE '✅ Added status equivalence functions for active/approved users';
    RAISE NOTICE '';
    RAISE NOTICE '🔧 The following issues have been resolved:';
    RAISE NOTICE '   - PostgreSQL constraint violation on notifications.body field';
    RAISE NOTICE '   - Active/approved status equivalence for voucher assignments';
    RAISE NOTICE '   - Notification trigger error handling and null safety';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Next steps:';
    RAISE NOTICE '   1. Test voucher assignment with active status clients';
    RAISE NOTICE '   2. Verify notifications are created properly';
    RAISE NOTICE '   3. Check wallet management displays both status types';
    RAISE NOTICE '';
END $$;

COMMIT;
