-- Enhanced Unified Notifications System Schema
-- Consolidates all notification types with role-based filtering and intelligent triggers
-- Production-ready schema for SmartBizTracker notifications system

BEGIN;

-- ============================================================================
-- STEP 1: Create Enhanced Unified Notifications Table
-- ============================================================================

-- Drop existing notifications table if it exists to start fresh
DROP TABLE IF EXISTS public.notifications CASCADE;

-- Create comprehensive notifications table
CREATE TABLE public.notifications (
    -- Primary identification
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- User targeting
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    user_role TEXT, -- Cache user role for faster filtering

    -- Notification content
    title TEXT NOT NULL,
    body TEXT NOT NULL, -- Main notification message
    message TEXT, -- Alternative message field for compatibility

    -- Notification categorization
    type TEXT NOT NULL CHECK (type IN (
        'order_created', 'order_status_changed', 'order_completed', 'payment_received',
        'voucher_assigned', 'voucher_used', 'voucher_expired',
        'task_assigned', 'task_completed', 'task_feedback',
        'reward_received', 'penalty_applied', 'bonus_awarded',
        'inventory_low', 'inventory_updated', 'product_added',
        'account_approved', 'system_alert', 'general',
        'customer_service_request', 'customer_service_update'
    )),
    category TEXT NOT NULL CHECK (category IN (
        'orders', 'vouchers', 'tasks', 'rewards', 'inventory', 'system', 'general', 'customer_service'
    )),
    priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),

    -- Status tracking
    is_read BOOLEAN DEFAULT FALSE NOT NULL,
    read_at TIMESTAMP WITH TIME ZONE,

    -- Navigation and actions
    route TEXT, -- Deep link route for navigation
    action_data JSONB DEFAULT '{}', -- Action-specific data

    -- Reference tracking
    reference_id TEXT, -- ID of related entity (order_id, task_id, etc.)
    reference_type TEXT, -- Type of referenced entity

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE, -- Optional expiration

    -- Additional metadata
    metadata JSONB DEFAULT '{}',

    -- Constraints
    CONSTRAINT notifications_read_at_check CHECK (
        (is_read = TRUE AND read_at IS NOT NULL) OR
        (is_read = FALSE AND read_at IS NULL)
    )
);

-- ============================================================================
-- STEP 2: Create Performance Indexes
-- ============================================================================

-- Primary indexes for fast queries
CREATE INDEX idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX idx_notifications_user_role ON public.notifications(user_role);
CREATE INDEX idx_notifications_type ON public.notifications(type);
CREATE INDEX idx_notifications_category ON public.notifications(category);
CREATE INDEX idx_notifications_is_read ON public.notifications(is_read);
CREATE INDEX idx_notifications_created_at ON public.notifications(created_at DESC);
CREATE INDEX idx_notifications_priority ON public.notifications(priority);

-- Composite indexes for common queries
CREATE INDEX idx_notifications_user_unread ON public.notifications(user_id, is_read) WHERE is_read = FALSE;
CREATE INDEX idx_notifications_user_category ON public.notifications(user_id, category);
CREATE INDEX idx_notifications_role_type ON public.notifications(user_role, type);
CREATE INDEX idx_notifications_reference ON public.notifications(reference_type, reference_id);

-- ============================================================================
-- STEP 3: Create Triggers and Functions
-- ============================================================================

-- Function to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_notifications_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to auto-set read_at timestamp when is_read changes to true
CREATE OR REPLACE FUNCTION set_notification_read_at()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_read = TRUE AND OLD.is_read = FALSE THEN
        NEW.read_at = NOW();
    ELSIF NEW.is_read = FALSE THEN
        NEW.read_at = NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to cache user role for faster filtering
CREATE OR REPLACE FUNCTION cache_user_role()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.user_role IS NULL THEN
        SELECT role INTO NEW.user_role
        FROM public.user_profiles
        WHERE id = NEW.user_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
DROP TRIGGER IF EXISTS update_notifications_updated_at_trigger ON public.notifications;
CREATE TRIGGER update_notifications_updated_at_trigger
    BEFORE UPDATE ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION update_notifications_updated_at();

DROP TRIGGER IF EXISTS set_notification_read_at_trigger ON public.notifications;
CREATE TRIGGER set_notification_read_at_trigger
    BEFORE UPDATE ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION set_notification_read_at();

DROP TRIGGER IF EXISTS cache_user_role_trigger ON public.notifications;
CREATE TRIGGER cache_user_role_trigger
    BEFORE INSERT ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION cache_user_role();

-- ============================================================================
-- STEP 4: Row Level Security (RLS) Policies
-- ============================================================================

-- Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "System can create notifications" ON public.notifications;
DROP POLICY IF EXISTS "Admins can manage all notifications" ON public.notifications;

-- Policy: Users can view their own notifications
CREATE POLICY "Users can view their own notifications"
ON public.notifications
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Policy: Users can update their own notifications (mark as read, etc.)
CREATE POLICY "Users can update their own notifications"
ON public.notifications
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Policy: System can create notifications for any user
CREATE POLICY "System can create notifications"
ON public.notifications
FOR INSERT
TO service_role
WITH CHECK (true);

-- Policy: Authenticated users can create notifications (for system triggers)
CREATE POLICY "Authenticated can create notifications"
ON public.notifications
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy: Admins can manage all notifications
CREATE POLICY "Admins can manage all notifications"
ON public.notifications
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid()
        AND role IN ('admin', 'owner')
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid()
        AND role IN ('admin', 'owner')
    )
);

-- ============================================================================
-- STEP 5: Grant Permissions
-- ============================================================================

GRANT ALL ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;

COMMIT;

-- ============================================================================
-- STEP 6: Verification and Success Messages
-- ============================================================================

DO $$
DECLARE
    table_exists BOOLEAN;
    index_count INTEGER;
    trigger_count INTEGER;
BEGIN
    -- Check if table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'notifications'
    ) INTO table_exists;

    -- Count indexes
    SELECT COUNT(*) INTO index_count
    FROM pg_indexes
    WHERE tablename = 'notifications'
    AND schemaname = 'public';

    -- Count triggers
    SELECT COUNT(*) INTO trigger_count
    FROM information_schema.triggers
    WHERE event_object_table = 'notifications'
    AND event_object_schema = 'public';

    IF table_exists THEN
        RAISE NOTICE '✅ SUCCESS: Enhanced notifications table created successfully';
        RAISE NOTICE '📊 Indexes created: %', index_count;
        RAISE NOTICE '⚡ Triggers created: %', trigger_count;
        RAISE NOTICE '🔒 RLS policies enabled for security';
        RAISE NOTICE '🎯 Ready for production-level notification system';
        RAISE NOTICE '';
        RAISE NOTICE '📋 Supported notification types:';
        RAISE NOTICE '   • Orders: creation, status changes, completion, payments';
        RAISE NOTICE '   • Vouchers: assignment, usage, expiration';
        RAISE NOTICE '   • Tasks: assignment, completion, feedback';
        RAISE NOTICE '   • Rewards: bonuses, penalties, adjustments';
        RAISE NOTICE '   • Inventory: low stock, updates, new products';
        RAISE NOTICE '   • System: account approval, alerts, general';
        RAISE NOTICE '';
        RAISE NOTICE '🚀 Enhanced notification system is ready for SmartBizTracker!';
    ELSE
        RAISE NOTICE '❌ ERROR: Failed to create notifications table';
    END IF;
END $$;
