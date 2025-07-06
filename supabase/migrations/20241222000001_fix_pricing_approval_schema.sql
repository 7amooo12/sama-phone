-- =====================================================
-- Fix Pricing Approval Schema Migration
-- Created: 2024-12-22
-- Purpose: Ensure all pricing approval columns exist and are properly configured
-- =====================================================

-- Add missing pricing approval columns to client_orders table
DO $$
BEGIN
    -- Add pricing_status column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'client_orders' AND column_name = 'pricing_status') THEN
        ALTER TABLE public.client_orders 
        ADD COLUMN pricing_status TEXT DEFAULT 'pending_pricing' 
        CHECK (pricing_status IN ('pending_pricing', 'pricing_approved', 'pricing_rejected'));
    END IF;

    -- Add pricing_approved_by column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'client_orders' AND column_name = 'pricing_approved_by') THEN
        ALTER TABLE public.client_orders 
        ADD COLUMN pricing_approved_by UUID REFERENCES auth.users(id);
    END IF;

    -- Add pricing_approved_at column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'client_orders' AND column_name = 'pricing_approved_at') THEN
        ALTER TABLE public.client_orders 
        ADD COLUMN pricing_approved_at TIMESTAMP WITH TIME ZONE;
    END IF;

    -- Add pricing_notes column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'client_orders' AND column_name = 'pricing_notes') THEN
        ALTER TABLE public.client_orders 
        ADD COLUMN pricing_notes TEXT;
    END IF;
END $$;

-- Add missing pricing approval columns to client_order_items table
DO $$
BEGIN
    -- Add approved_unit_price column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'client_order_items' AND column_name = 'approved_unit_price') THEN
        ALTER TABLE public.client_order_items 
        ADD COLUMN approved_unit_price DECIMAL(10, 2);
    END IF;

    -- Add approved_subtotal column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'client_order_items' AND column_name = 'approved_subtotal') THEN
        ALTER TABLE public.client_order_items 
        ADD COLUMN approved_subtotal DECIMAL(10, 2);
    END IF;

    -- Add original_unit_price column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'client_order_items' AND column_name = 'original_unit_price') THEN
        ALTER TABLE public.client_order_items 
        ADD COLUMN original_unit_price DECIMAL(10, 2);
    END IF;

    -- Add pricing_approved column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'client_order_items' AND column_name = 'pricing_approved') THEN
        ALTER TABLE public.client_order_items 
        ADD COLUMN pricing_approved BOOLEAN DEFAULT FALSE;
    END IF;

    -- Add pricing_approved_by column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'client_order_items' AND column_name = 'pricing_approved_by') THEN
        ALTER TABLE public.client_order_items 
        ADD COLUMN pricing_approved_by UUID REFERENCES auth.users(id);
    END IF;

    -- Add pricing_approved_at column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'client_order_items' AND column_name = 'pricing_approved_at') THEN
        ALTER TABLE public.client_order_items 
        ADD COLUMN pricing_approved_at TIMESTAMP WITH TIME ZONE;
    END IF;
END $$;

-- Create order_pricing_history table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.order_pricing_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.client_orders(id) ON DELETE CASCADE NOT NULL,
    
    -- معلومات التسعير
    item_id UUID REFERENCES public.client_order_items(id) ON DELETE CASCADE NOT NULL,
    original_price DECIMAL(10, 2) NOT NULL,
    approved_price DECIMAL(10, 2) NOT NULL,
    price_difference DECIMAL(10, 2) NOT NULL,
    
    -- معلومات المحاسب
    approved_by UUID REFERENCES auth.users(id) NOT NULL,
    approved_by_name TEXT NOT NULL,
    approved_by_role TEXT DEFAULT 'accountant',
    
    -- ملاحظات التسعير
    pricing_notes TEXT,
    approval_reason TEXT,
    
    -- التوقيت
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    
    -- معلومات إضافية
    metadata JSONB DEFAULT '{}'
);

-- Add missing indexes for pricing approval
CREATE INDEX IF NOT EXISTS idx_client_orders_pricing_status ON public.client_orders(pricing_status);
CREATE INDEX IF NOT EXISTS idx_client_orders_pricing_approved_by ON public.client_orders(pricing_approved_by);
CREATE INDEX IF NOT EXISTS idx_client_order_items_pricing_approved ON public.client_order_items(pricing_approved);
CREATE INDEX IF NOT EXISTS idx_client_order_items_pricing_approved_by ON public.client_order_items(pricing_approved_by);
CREATE INDEX IF NOT EXISTS idx_order_pricing_history_order_id ON public.order_pricing_history(order_id);
CREATE INDEX IF NOT EXISTS idx_order_pricing_history_item_id ON public.order_pricing_history(item_id);
CREATE INDEX IF NOT EXISTS idx_order_pricing_history_approved_by ON public.order_pricing_history(approved_by);
CREATE INDEX IF NOT EXISTS idx_order_pricing_history_created_at ON public.order_pricing_history(created_at DESC);

-- Enable RLS on pricing history table
ALTER TABLE public.order_pricing_history ENABLE ROW LEVEL SECURITY;

-- Update existing orders to have pricing_status if null
UPDATE public.client_orders 
SET pricing_status = CASE 
    WHEN status = 'pending' THEN 'pending_pricing'
    ELSE 'pricing_approved'
END
WHERE pricing_status IS NULL;

-- Update order history constraint to include pricing_approved action
DO $$
BEGIN
    -- Drop existing constraint if it exists
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints 
               WHERE table_name = 'order_history' AND constraint_name = 'valid_action') THEN
        ALTER TABLE public.order_history DROP CONSTRAINT valid_action;
    END IF;
    
    -- Add updated constraint
    ALTER TABLE public.order_history 
    ADD CONSTRAINT valid_action CHECK (action IN (
        'created', 'status_changed', 'assigned', 'payment_updated', 
        'tracking_added', 'cancelled', 'completed', 'pricing_approved'
    ));
END $$;

-- Grant necessary permissions for pricing approval functions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.client_orders TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.client_order_items TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.order_pricing_history TO authenticated;
GRANT SELECT, INSERT ON public.order_history TO authenticated;
