-- Purchase Invoices System Migration
-- Creates tables for purchase invoice management with proper indexes and RLS policies

-- Create purchase_invoices table
CREATE TABLE IF NOT EXISTS public.purchase_invoices (
    -- Primary key: Purchase Invoice ID (e.g., 'PINV-1234567890')
    id TEXT PRIMARY KEY,
    
    -- Foreign key to auth.users (user who created the invoice)
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Supplier information (optional)
    supplier_name TEXT,
    
    -- Financial calculations
    total_amount NUMERIC(12,2) NOT NULL CHECK (total_amount >= 0),
    
    -- Status with valid values
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled')),
    
    -- Additional information
    notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Create purchase_invoice_items table
CREATE TABLE IF NOT EXISTS public.purchase_invoice_items (
    -- Primary key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Foreign key to purchase_invoices
    purchase_invoice_id TEXT NOT NULL REFERENCES public.purchase_invoices(id) ON DELETE CASCADE,
    
    -- Product information
    product_name TEXT NOT NULL,
    product_image_url TEXT,
    
    -- Pricing in Chinese Yuan
    yuan_price NUMERIC(12,2) NOT NULL CHECK (yuan_price > 0),
    
    -- Exchange rate (Yuan to EGP)
    exchange_rate NUMERIC(8,4) NOT NULL CHECK (exchange_rate > 0),
    
    -- Profit margin percentage
    profit_margin_percent NUMERIC(5,2) NOT NULL CHECK (profit_margin_percent >= 0 AND profit_margin_percent <= 1000),

    -- Quantity of items
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),

    -- Final calculated price in EGP
    final_egp_price NUMERIC(12,2) NOT NULL CHECK (final_egp_price > 0),
    
    -- Additional information
    notes TEXT,
    
    -- Timestamp
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Create indexes for better performance

-- Indexes on purchase_invoices table
CREATE INDEX IF NOT EXISTS idx_purchase_invoices_user_id ON public.purchase_invoices(user_id);
CREATE INDEX IF NOT EXISTS idx_purchase_invoices_created_at ON public.purchase_invoices(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_purchase_invoices_status ON public.purchase_invoices(status);
CREATE INDEX IF NOT EXISTS idx_purchase_invoices_supplier_name ON public.purchase_invoices(supplier_name);
CREATE INDEX IF NOT EXISTS idx_purchase_invoices_total_amount ON public.purchase_invoices(total_amount);

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_purchase_invoices_user_status ON public.purchase_invoices(user_id, status);
CREATE INDEX IF NOT EXISTS idx_purchase_invoices_user_created ON public.purchase_invoices(user_id, created_at DESC);

-- Indexes on purchase_invoice_items table
CREATE INDEX IF NOT EXISTS idx_purchase_invoice_items_invoice_id ON public.purchase_invoice_items(purchase_invoice_id);
CREATE INDEX IF NOT EXISTS idx_purchase_invoice_items_product_name ON public.purchase_invoice_items(product_name);
CREATE INDEX IF NOT EXISTS idx_purchase_invoice_items_yuan_price ON public.purchase_invoice_items(yuan_price);
CREATE INDEX IF NOT EXISTS idx_purchase_invoice_items_quantity ON public.purchase_invoice_items(quantity);
CREATE INDEX IF NOT EXISTS idx_purchase_invoice_items_final_price ON public.purchase_invoice_items(final_egp_price);

-- Create updated_at trigger function if it doesn't exist
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for updated_at on purchase_invoices
DROP TRIGGER IF EXISTS update_purchase_invoices_updated_at ON public.purchase_invoices;
CREATE TRIGGER update_purchase_invoices_updated_at
    BEFORE UPDATE ON public.purchase_invoices
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- Enable Row Level Security (RLS)
ALTER TABLE public.purchase_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_invoice_items ENABLE ROW LEVEL SECURITY;

-- RLS Policies for purchase_invoices table

-- Policy: Users can view their own purchase invoices
CREATE POLICY "Users can view own purchase invoices" ON public.purchase_invoices
    FOR SELECT USING (auth.uid() = user_id);

-- Policy: Users can insert their own purchase invoices
CREATE POLICY "Users can insert own purchase invoices" ON public.purchase_invoices
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own purchase invoices
CREATE POLICY "Users can update own purchase invoices" ON public.purchase_invoices
    FOR UPDATE USING (auth.uid() = user_id);

-- Policy: Users can delete their own purchase invoices
CREATE POLICY "Users can delete own purchase invoices" ON public.purchase_invoices
    FOR DELETE USING (auth.uid() = user_id);

-- Policy: Admins can view all purchase invoices
CREATE POLICY "Admins can view all purchase invoices" ON public.purchase_invoices
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
        )
    );

-- Policy: Admins can update all purchase invoices
CREATE POLICY "Admins can update all purchase invoices" ON public.purchase_invoices
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
        )
    );

-- RLS Policies for purchase_invoice_items table

-- Policy: Users can view items of their own purchase invoices
CREATE POLICY "Users can view own purchase invoice items" ON public.purchase_invoice_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.purchase_invoices 
            WHERE id = purchase_invoice_id 
            AND user_id = auth.uid()
        )
    );

-- Policy: Users can insert items for their own purchase invoices
CREATE POLICY "Users can insert own purchase invoice items" ON public.purchase_invoice_items
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.purchase_invoices 
            WHERE id = purchase_invoice_id 
            AND user_id = auth.uid()
        )
    );

-- Policy: Users can update items of their own purchase invoices
CREATE POLICY "Users can update own purchase invoice items" ON public.purchase_invoice_items
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.purchase_invoices 
            WHERE id = purchase_invoice_id 
            AND user_id = auth.uid()
        )
    );

-- Policy: Users can delete items of their own purchase invoices
CREATE POLICY "Users can delete own purchase invoice items" ON public.purchase_invoice_items
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.purchase_invoices 
            WHERE id = purchase_invoice_id 
            AND user_id = auth.uid()
        )
    );

-- Policy: Admins can view all purchase invoice items
CREATE POLICY "Admins can view all purchase invoice items" ON public.purchase_invoice_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
        )
    );

-- Policy: Admins can update all purchase invoice items
CREATE POLICY "Admins can update all purchase invoice items" ON public.purchase_invoice_items
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
        )
    );

-- Create helpful database functions

-- Function to get purchase invoice statistics
CREATE OR REPLACE FUNCTION public.get_purchase_invoice_stats(user_uuid UUID DEFAULT auth.uid())
RETURNS JSON AS $$
DECLARE
    stats JSON;
BEGIN
    SELECT json_build_object(
        'total_invoices', COUNT(*),
        'total_amount', COALESCE(SUM(total_amount), 0),
        'pending_invoices', COUNT(*) FILTER (WHERE status = 'pending'),
        'completed_invoices', COUNT(*) FILTER (WHERE status = 'completed'),
        'cancelled_invoices', COUNT(*) FILTER (WHERE status = 'cancelled'),
        'avg_invoice_amount', COALESCE(AVG(total_amount), 0),
        'this_month_invoices', COUNT(*) FILTER (WHERE created_at >= date_trunc('month', CURRENT_DATE)),
        'this_month_amount', COALESCE(SUM(total_amount) FILTER (WHERE created_at >= date_trunc('month', CURRENT_DATE)), 0)
    ) INTO stats
    FROM public.purchase_invoices
    WHERE user_id = user_uuid;
    
    RETURN stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to calculate total profit from purchase invoices
CREATE OR REPLACE FUNCTION public.get_purchase_invoice_profit_stats(user_uuid UUID DEFAULT auth.uid())
RETURNS JSON AS $$
DECLARE
    stats JSON;
BEGIN
    SELECT json_build_object(
        'total_yuan_amount', COALESCE(SUM(pii.yuan_price * pii.quantity), 0),
        'total_base_egp_amount', COALESCE(SUM(pii.yuan_price * pii.exchange_rate * pii.quantity), 0),
        'total_profit_amount', COALESCE(SUM(pii.yuan_price * pii.exchange_rate * pii.profit_margin_percent / 100 * pii.quantity), 0),
        'total_final_amount', COALESCE(SUM(pii.final_egp_price * pii.quantity), 0),
        'total_quantity', COALESCE(SUM(pii.quantity), 0),
        'avg_profit_margin', COALESCE(AVG(pii.profit_margin_percent), 0),
        'avg_exchange_rate', COALESCE(AVG(pii.exchange_rate), 0),
        'avg_quantity_per_item', COALESCE(AVG(pii.quantity), 0)
    ) INTO stats
    FROM public.purchase_invoice_items pii
    JOIN public.purchase_invoices pi ON pii.purchase_invoice_id = pi.id
    WHERE pi.user_id = user_uuid;
    
    RETURN stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON public.purchase_invoices TO authenticated;
GRANT ALL ON public.purchase_invoice_items TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_purchase_invoice_stats TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_purchase_invoice_profit_stats TO authenticated;

-- Add comments for documentation
COMMENT ON TABLE public.purchase_invoices IS 'Purchase invoices for business owner invoice management system';
COMMENT ON TABLE public.purchase_invoice_items IS 'Items within purchase invoices with Yuan pricing and profit calculations';
COMMENT ON COLUMN public.purchase_invoice_items.yuan_price IS 'Product price per unit in Chinese Yuan';
COMMENT ON COLUMN public.purchase_invoice_items.exchange_rate IS 'Exchange rate from Yuan to Egyptian Pound';
COMMENT ON COLUMN public.purchase_invoice_items.profit_margin_percent IS 'Profit margin percentage applied to base price';
COMMENT ON COLUMN public.purchase_invoice_items.quantity IS 'Quantity of items purchased';
COMMENT ON COLUMN public.purchase_invoice_items.final_egp_price IS 'Final calculated price per unit in Egyptian Pounds';

-- Insert sample data for testing (optional - remove in production)
-- This is commented out by default
/*
INSERT INTO public.purchase_invoices (id, user_id, supplier_name, total_amount, status, notes) VALUES
('PINV-1234567890', auth.uid(), 'مورد تجريبي', 1500.00, 'pending', 'فاتورة تجريبية للاختبار');

INSERT INTO public.purchase_invoice_items (purchase_invoice_id, product_name, yuan_price, exchange_rate, profit_margin_percent, quantity, final_egp_price) VALUES
('PINV-1234567890', 'منتج تجريبي', 100.00, 2.45, 20.0, 1, 294.00);
*/
