-- Migration: Fix notifications category constraint to include customer_service
-- Date: 2025-01-06
-- Purpose: Add 'customer_service' to the allowed values in notifications_category_check constraint
-- This fixes the PostgreSQL check constraint violation error when creating customer service notifications

-- Step 1: Drop the existing constraint
DO $$
BEGIN
    -- Check if the constraint exists before trying to drop it
    IF EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints 
        WHERE constraint_name = 'notifications_category_check' 
        AND table_name = 'notifications'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notifications DROP CONSTRAINT notifications_category_check;
        RAISE NOTICE '✅ Successfully dropped existing notifications_category_check constraint';
    ELSE
        RAISE NOTICE '⚠️  Constraint notifications_category_check does not exist, skipping drop';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'ERROR dropping constraint: %', SQLERRM;
END $$;

-- Step 2: Create the updated constraint with customer_service included
DO $$
BEGIN
    ALTER TABLE public.notifications
    ADD CONSTRAINT notifications_category_check CHECK (category IN (
        'orders', 'vouchers', 'tasks', 'rewards', 'inventory', 'system', 'general', 'customer_service'
    ));

    RAISE NOTICE '✅ Successfully created updated notifications_category_check constraint with customer_service support';
EXCEPTION
    WHEN check_violation THEN
        RAISE EXCEPTION 'CONSTRAINT VIOLATION: The category constraint could not be applied. There are invalid category values in the notifications table. Error: %', SQLERRM;
    WHEN OTHERS THEN
        RAISE EXCEPTION 'UNEXPECTED ERROR while creating constraint: %', SQLERRM;
END $$;

-- Step 2.5: Update the type constraint to include customer service types
DO $$
BEGIN
    -- Check if the type constraint exists before trying to drop it
    IF EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE constraint_name = 'notifications_type_check'
        AND table_name = 'notifications'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notifications DROP CONSTRAINT notifications_type_check;
        RAISE NOTICE '✅ Successfully dropped existing notifications_type_check constraint';
    ELSE
        RAISE NOTICE '⚠️  Constraint notifications_type_check does not exist, skipping drop';
    END IF;

    -- Create the updated type constraint
    ALTER TABLE public.notifications
    ADD CONSTRAINT notifications_type_check CHECK (type IN (
        'order_created', 'order_status_changed', 'order_completed', 'payment_received',
        'voucher_assigned', 'voucher_used', 'voucher_expired',
        'task_assigned', 'task_completed', 'task_feedback',
        'reward_received', 'penalty_applied', 'bonus_awarded',
        'inventory_low', 'inventory_updated', 'product_added',
        'account_approved', 'system_alert', 'general',
        'customer_service_request', 'customer_service_update'
    ));

    RAISE NOTICE '✅ Successfully created updated notifications_type_check constraint with customer service types';
EXCEPTION
    WHEN check_violation THEN
        RAISE EXCEPTION 'CONSTRAINT VIOLATION: The type constraint could not be applied. There are invalid type values in the notifications table. Error: %', SQLERRM;
    WHEN OTHERS THEN
        RAISE EXCEPTION 'UNEXPECTED ERROR while updating type constraint: %', SQLERRM;
END $$;

-- Step 3: Verify the constraint was created successfully
DO $$
DECLARE
    constraint_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints 
        WHERE constraint_name = 'notifications_category_check' 
        AND table_name = 'notifications'
        AND table_schema = 'public'
    ) INTO constraint_exists;
    
    IF constraint_exists THEN
        RAISE NOTICE '✅ Verification successful: notifications_category_check constraint exists';
    ELSE
        RAISE EXCEPTION '❌ Verification failed: notifications_category_check constraint was not created';
    END IF;
END $$;

-- Step 4: Test the constraints by checking current data
DO $$
DECLARE
    invalid_categories TEXT[];
    invalid_types TEXT[];
    category_val TEXT;
    type_val TEXT;
BEGIN
    -- Get any existing invalid category values
    SELECT ARRAY_AGG(DISTINCT category) INTO invalid_categories
    FROM public.notifications
    WHERE category NOT IN ('orders', 'vouchers', 'tasks', 'rewards', 'inventory', 'system', 'general', 'customer_service');

    -- Get any existing invalid type values
    SELECT ARRAY_AGG(DISTINCT type) INTO invalid_types
    FROM public.notifications
    WHERE type NOT IN (
        'order_created', 'order_status_changed', 'order_completed', 'payment_received',
        'voucher_assigned', 'voucher_used', 'voucher_expired',
        'task_assigned', 'task_completed', 'task_feedback',
        'reward_received', 'penalty_applied', 'bonus_awarded',
        'inventory_low', 'inventory_updated', 'product_added',
        'account_approved', 'system_alert', 'general',
        'customer_service_request', 'customer_service_update'
    );

    IF invalid_categories IS NOT NULL AND array_length(invalid_categories, 1) > 0 THEN
        RAISE NOTICE '⚠️  Found existing invalid category values in notifications table:';
        FOREACH category_val IN ARRAY invalid_categories
        LOOP
            RAISE NOTICE '   - Invalid category: "%"', category_val;
        END LOOP;
        RAISE NOTICE 'These category values will need to be updated manually.';
    ELSE
        RAISE NOTICE '✅ All existing category values in notifications table are valid';
    END IF;

    IF invalid_types IS NOT NULL AND array_length(invalid_types, 1) > 0 THEN
        RAISE NOTICE '⚠️  Found existing invalid type values in notifications table:';
        FOREACH type_val IN ARRAY invalid_types
        LOOP
            RAISE NOTICE '   - Invalid type: "%"', type_val;
        END LOOP;
        RAISE NOTICE 'These type values will need to be updated manually.';
    ELSE
        RAISE NOTICE '✅ All existing type values in notifications table are valid';
    END IF;
END $$;

-- Step 5: Display the allowed values for reference
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '📋 ALLOWED CATEGORY VALUES:';
    RAISE NOTICE '   - orders';
    RAISE NOTICE '   - vouchers';
    RAISE NOTICE '   - tasks';
    RAISE NOTICE '   - rewards';
    RAISE NOTICE '   - inventory';
    RAISE NOTICE '   - system';
    RAISE NOTICE '   - general';
    RAISE NOTICE '   - customer_service (newly added)';
    RAISE NOTICE '';
    RAISE NOTICE '📋 ALLOWED TYPE VALUES (newly added):';
    RAISE NOTICE '   - customer_service_request';
    RAISE NOTICE '   - customer_service_update';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Customer service notifications can now use:';
    RAISE NOTICE '   - category: "customer_service"';
    RAISE NOTICE '   - type: "customer_service_request" or "customer_service_update"';
END $$;
