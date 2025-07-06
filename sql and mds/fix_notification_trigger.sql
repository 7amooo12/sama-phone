-- Fix the notification trigger to handle NOT NULL constraints
-- This updates the trigger to provide values for all required fields

BEGIN;

-- Update the trigger function to handle the body field properly
CREATE OR REPLACE FUNCTION notify_task_assigned()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.notifications (
        user_id,
        title,
        body,        -- Add body field (required NOT NULL)
        message,     -- Keep message field for compatibility
        type,
        is_read
    ) VALUES (
        NEW.worker_id,
        'تم تعيين مهمة جديدة',
        'تم تعيين مهمة جديدة لك: ' || NEW.title,  -- Use same text for body
        'تم تعيين مهمة جديدة لك: ' || NEW.title,  -- Keep message for compatibility
        'task_assigned',
        FALSE
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Alternative: Make body column nullable if we don't want to change the trigger
-- Uncomment the line below if you prefer this approach:
-- ALTER TABLE public.notifications ALTER COLUMN body DROP NOT NULL;

-- Alternative: Set a default value for body column
-- Uncomment the line below if you prefer this approach:
-- ALTER TABLE public.notifications ALTER COLUMN body SET DEFAULT '';

COMMIT;

-- Test the fix
DO $$
BEGIN
    RAISE NOTICE '✅ SUCCESS: Notification trigger updated to handle body field';
    RAISE NOTICE 'The trigger now provides values for all required NOT NULL columns:';
    RAISE NOTICE '- user_id: NEW.worker_id';
    RAISE NOTICE '- title: "تم تعيين مهمة جديدة"';
    RAISE NOTICE '- body: "تم تعيين مهمة جديدة لك: " || NEW.title';
    RAISE NOTICE '- message: "تم تعيين مهمة جديدة لك: " || NEW.title';
    RAISE NOTICE '- type: "task_assigned"';
    RAISE NOTICE '- is_read: FALSE';
    RAISE NOTICE '';
    RAISE NOTICE '🎉 Your task creation should now work completely!';
END $$;
