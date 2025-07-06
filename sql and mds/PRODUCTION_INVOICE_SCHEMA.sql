-- =====================================================
-- SMARTBIZTRACKER INVOICE SYSTEM - PRODUCTION SCHEMA
-- =====================================================
-- Complete production-ready SQL setup for Supabase
-- Execute this script in Supabase SQL Editor
-- =====================================================

-- =====================================================
-- 1. CREATE INVOICES TABLE WITH COMPLETE SCHEMA
-- =====================================================

-- Drop table if exists (for clean setup)
DROP TABLE IF EXISTS public.invoices CASCADE;

-- Create invoices table with exact specifications
CREATE TABLE public.invoices (
    -- Primary key: Invoice ID (e.g., 'INV-1234567890')
    id TEXT PRIMARY KEY,
    
    -- Foreign key to auth.users (user who created the invoice)
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Customer information
    customer_name TEXT NOT NULL,
    customer_phone TEXT,
    customer_email TEXT,
    customer_address TEXT,
    
    -- Invoice items stored as JSONB array
    -- Structure: [{"product_id": "...", "product_name": "...", "quantity": 1, "unit_price": 100.00, "subtotal": 100.00, "notes": "..."}]
    items JSONB NOT NULL,
    
    -- Financial calculations (NO TAX/VAT)
    subtotal NUMERIC(12,2) NOT NULL CHECK (subtotal >= 0),
    discount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (discount >= 0),
    total_amount NUMERIC(12,2) NOT NULL CHECK (total_amount >= 0),
    
    -- Additional information
    notes TEXT,
    
    -- Status with valid values
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled')),
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- =====================================================
-- 2. CREATE PERFORMANCE OPTIMIZATION INDEXES
-- =====================================================

-- Index for fast queries by user_id (user-specific invoice lists)
CREATE INDEX idx_invoices_user_id ON public.invoices(user_id);

-- Index for fast queries by status (pending/completed filtering)
CREATE INDEX idx_invoices_status ON public.invoices(status);

-- Index for fast queries by created_at (chronological sorting)
CREATE INDEX idx_invoices_created_at ON public.invoices(created_at DESC);

-- Composite index for user-specific status filtering
CREATE INDEX idx_invoices_user_status ON public.invoices(user_id, status);

-- Composite index for user-specific chronological queries
CREATE INDEX idx_invoices_user_created ON public.invoices(user_id, created_at DESC);

-- Composite index for status and date filtering
CREATE INDEX idx_invoices_status_created ON public.invoices(status, created_at DESC);

-- Index for customer name searches (case-insensitive)
CREATE INDEX idx_invoices_customer_name ON public.invoices(LOWER(customer_name));

-- GIN index for JSONB items field (for searching within invoice items)
CREATE INDEX idx_invoices_items_gin ON public.invoices USING GIN(items);

-- =====================================================
-- 3. CREATE DATABASE FUNCTIONS AND TRIGGERS
-- =====================================================

-- Function to automatically update total_amount when subtotal or discount changes
CREATE OR REPLACE FUNCTION calculate_invoice_total()
RETURNS TRIGGER AS $$
BEGIN
    -- Calculate total_amount = subtotal - discount (NO TAX)
    NEW.total_amount := NEW.subtotal - NEW.discount;
    
    -- Ensure total_amount is not negative
    IF NEW.total_amount < 0 THEN
        NEW.total_amount := 0;
    END IF;
    
    -- Update the updated_at timestamp
    NEW.updated_at := NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically calculate total_amount on INSERT and UPDATE
CREATE TRIGGER trigger_calculate_invoice_total
    BEFORE INSERT OR UPDATE ON public.invoices
    FOR EACH ROW
    EXECUTE FUNCTION calculate_invoice_total();

-- Function to validate JSONB items structure
CREATE OR REPLACE FUNCTION validate_invoice_items()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if items is an array
    IF jsonb_typeof(NEW.items) != 'array' THEN
        RAISE EXCEPTION 'Invoice items must be a JSON array';
    END IF;
    
    -- Check if items array is not empty
    IF jsonb_array_length(NEW.items) = 0 THEN
        RAISE EXCEPTION 'Invoice must contain at least one item';
    END IF;
    
    -- Validate each item in the array
    FOR i IN 0..jsonb_array_length(NEW.items) - 1 LOOP
        -- Check required fields exist
        IF NOT (NEW.items->i ? 'product_id' AND 
                NEW.items->i ? 'product_name' AND 
                NEW.items->i ? 'quantity' AND 
                NEW.items->i ? 'unit_price' AND 
                NEW.items->i ? 'subtotal') THEN
            RAISE EXCEPTION 'Each invoice item must have product_id, product_name, quantity, unit_price, and subtotal';
        END IF;
        
        -- Check data types and values
        IF NOT (jsonb_typeof(NEW.items->i->'quantity') = 'number' AND 
                (NEW.items->i->>'quantity')::NUMERIC > 0) THEN
            RAISE EXCEPTION 'Item quantity must be a positive number';
        END IF;
        
        IF NOT (jsonb_typeof(NEW.items->i->'unit_price') = 'number' AND 
                (NEW.items->i->>'unit_price')::NUMERIC >= 0) THEN
            RAISE EXCEPTION 'Item unit_price must be a non-negative number';
        END IF;
        
        IF NOT (jsonb_typeof(NEW.items->i->'subtotal') = 'number' AND 
                (NEW.items->i->>'subtotal')::NUMERIC >= 0) THEN
            RAISE EXCEPTION 'Item subtotal must be a non-negative number';
        END IF;
    END LOOP;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to validate items structure on INSERT and UPDATE
CREATE TRIGGER trigger_validate_invoice_items
    BEFORE INSERT OR UPDATE ON public.invoices
    FOR EACH ROW
    EXECUTE FUNCTION validate_invoice_items();

-- =====================================================
-- 4. ENABLE ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Enable RLS on invoices table
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 5. CREATE RLS POLICIES FOR ROLE-BASED ACCESS
-- =====================================================

-- Policy for admin role: Full access to all invoices
CREATE POLICY "Admin full access to invoices" ON public.invoices
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'admin'
            AND user_profiles.status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'admin'
            AND user_profiles.status = 'approved'
        )
    );

-- Policy for owner role: Full access to all invoices
CREATE POLICY "Owner full access to invoices" ON public.invoices
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'owner'
            AND user_profiles.status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'owner'
            AND user_profiles.status = 'approved'
        )
    );

-- Policy for accountant role: Full access to all invoices
CREATE POLICY "Accountant full access to invoices" ON public.invoices
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'accountant'
            AND user_profiles.status = 'approved'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'accountant'
            AND user_profiles.status = 'approved'
        )
    );

-- Policy for client role: Read-only access to invoices where customer matches their profile
CREATE POLICY "Client read access to own invoices" ON public.invoices
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'client'
            AND user_profiles.status = 'approved'
            AND (
                LOWER(invoices.customer_name) = LOWER(user_profiles.name) OR
                LOWER(invoices.customer_email) = LOWER(user_profiles.email) OR
                invoices.customer_phone = user_profiles.phone_number
            )
        )
    );

-- Policy to deny worker access to invoices
CREATE POLICY "Workers no access to invoices" ON public.invoices
    FOR ALL
    TO authenticated
    USING (
        NOT EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE user_profiles.id = auth.uid() 
            AND user_profiles.role = 'worker'
        )
    );

-- =====================================================
-- 6. CREATE HELPFUL DATABASE VIEWS
-- =====================================================

-- View for invoice statistics
CREATE OR REPLACE VIEW public.invoice_statistics AS
SELECT 
    COUNT(*) as total_invoices,
    COUNT(*) FILTER (WHERE status = 'pending') as pending_invoices,
    COUNT(*) FILTER (WHERE status = 'completed') as completed_invoices,
    COUNT(*) FILTER (WHERE status = 'cancelled') as cancelled_invoices,
    COALESCE(SUM(total_amount), 0) as total_revenue,
    COALESCE(SUM(total_amount) FILTER (WHERE status = 'pending'), 0) as pending_amount,
    COALESCE(SUM(total_amount) FILTER (WHERE status = 'completed'), 0) as completed_amount,
    COALESCE(AVG(total_amount), 0) as average_invoice_amount,
    DATE_TRUNC('month', created_at) as month
FROM public.invoices
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY month DESC;

-- View for recent invoices (last 30 days)
CREATE OR REPLACE VIEW public.recent_invoices AS
SELECT *
FROM public.invoices
WHERE created_at >= NOW() - INTERVAL '30 days'
ORDER BY created_at DESC;

-- =====================================================
-- 7. GRANT NECESSARY PERMISSIONS
-- =====================================================

-- Grant usage on schema
GRANT USAGE ON SCHEMA public TO authenticated;

-- Grant permissions on invoices table
GRANT SELECT, INSERT, UPDATE, DELETE ON public.invoices TO authenticated;

-- Grant permissions on views
GRANT SELECT ON public.invoice_statistics TO authenticated;
GRANT SELECT ON public.recent_invoices TO authenticated;

-- Grant usage on sequences (if any are created in the future)
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- =====================================================
-- 8. CREATE HELPFUL FUNCTIONS FOR APPLICATION USE
-- =====================================================

-- Function to get invoice count by status for a user
CREATE OR REPLACE FUNCTION get_user_invoice_stats(user_uuid UUID)
RETURNS TABLE(
    total_count BIGINT,
    pending_count BIGINT,
    completed_count BIGINT,
    cancelled_count BIGINT,
    total_amount NUMERIC,
    pending_amount NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_count,
        COUNT(*) FILTER (WHERE status = 'pending') as pending_count,
        COUNT(*) FILTER (WHERE status = 'completed') as completed_count,
        COUNT(*) FILTER (WHERE status = 'cancelled') as cancelled_count,
        COALESCE(SUM(invoices.total_amount), 0) as total_amount,
        COALESCE(SUM(invoices.total_amount) FILTER (WHERE status = 'pending'), 0) as pending_amount
    FROM public.invoices
    WHERE invoices.user_id = user_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to search invoices by customer name
CREATE OR REPLACE FUNCTION search_invoices_by_customer(search_term TEXT)
RETURNS SETOF public.invoices AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM public.invoices
    WHERE LOWER(customer_name) LIKE LOWER('%' || search_term || '%')
    ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- SETUP COMPLETE
-- =====================================================

-- Display success message
DO $$
BEGIN
    RAISE NOTICE '✅ SmartBizTracker Invoice System Database Setup Complete!';
    RAISE NOTICE '📋 Created: invoices table with complete schema';
    RAISE NOTICE '🚀 Created: Performance indexes for fast queries';
    RAISE NOTICE '🔒 Enabled: Row Level Security with role-based policies';
    RAISE NOTICE '⚡ Created: Automatic triggers for calculations and validation';
    RAISE NOTICE '📊 Created: Helpful views and functions';
    RAISE NOTICE '🎯 Ready for production use!';
END $$;

-- Show table structure for verification
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'invoices'
ORDER BY ordinal_position;

-- Show created indexes
SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'invoices' AND schemaname = 'public';

-- Show RLS policies
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'invoices' AND schemaname = 'public';
