-- ============================================================================
-- VOUCHER/DISCOUNT MANAGEMENT SYSTEM
-- Migration: 20241225000000_create_voucher_system.sql
-- Description: Create comprehensive voucher and discount management system
-- ============================================================================

-- ============================================================================
-- STEP 1: Drop existing tables if they exist (for clean migration)
-- ============================================================================

DROP TABLE IF EXISTS public.client_vouchers CASCADE;
DROP TABLE IF EXISTS public.vouchers CASCADE;

-- ============================================================================
-- STEP 2: Create Vouchers Table
-- ============================================================================

CREATE TABLE public.vouchers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Voucher identification
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL, -- Human-readable voucher name
    description TEXT,
    
    -- Voucher type and target
    type TEXT NOT NULL CHECK (type IN ('category', 'product')),
    target_id TEXT NOT NULL, -- Category name or product ID
    target_name TEXT NOT NULL, -- Display name for target
    
    -- Discount configuration
    discount_percentage INTEGER NOT NULL CHECK (discount_percentage >= 1 AND discount_percentage <= 100),
    
    -- Validity and status
    expiration_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT true,
    
    -- Audit fields
    created_by UUID REFERENCES auth.users(id) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    
    -- Additional metadata
    metadata JSONB DEFAULT '{}',
    
    -- Constraints
    CONSTRAINT vouchers_expiration_future CHECK (expiration_date > created_at),
    CONSTRAINT vouchers_code_format CHECK (code ~ '^VOUCHER-[0-9]{8}-[A-Z0-9]{6}$')
);

-- ============================================================================
-- STEP 3: Create Client Vouchers Table (Assignment and Usage Tracking)
-- ============================================================================

CREATE TABLE public.client_vouchers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Relationships
    voucher_id UUID REFERENCES public.vouchers(id) ON DELETE CASCADE NOT NULL,
    client_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    
    -- Status tracking
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'used', 'expired')),
    
    -- Usage tracking
    used_at TIMESTAMP WITH TIME ZONE,
    order_id UUID, -- References client_orders(id) but not enforced to avoid circular dependency
    discount_amount DECIMAL(10, 2) DEFAULT 0.00,
    
    -- Assignment tracking
    assigned_by UUID REFERENCES auth.users(id) NOT NULL,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    
    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    
    -- Additional metadata
    metadata JSONB DEFAULT '{}',
    
    -- Constraints
    UNIQUE(voucher_id, client_id),
    CONSTRAINT client_vouchers_used_at_check CHECK (
        (status = 'used' AND used_at IS NOT NULL) OR 
        (status != 'used' AND used_at IS NULL)
    )
);

-- ============================================================================
-- STEP 4: Create Indexes for Performance
-- ============================================================================

-- Vouchers table indexes
CREATE INDEX idx_vouchers_type ON public.vouchers(type);
CREATE INDEX idx_vouchers_target_id ON public.vouchers(target_id);
CREATE INDEX idx_vouchers_expiration_date ON public.vouchers(expiration_date);
CREATE INDEX idx_vouchers_is_active ON public.vouchers(is_active);
CREATE INDEX idx_vouchers_created_by ON public.vouchers(created_by);
CREATE INDEX idx_vouchers_code ON public.vouchers(code);

-- Client vouchers table indexes
CREATE INDEX idx_client_vouchers_voucher_id ON public.client_vouchers(voucher_id);
CREATE INDEX idx_client_vouchers_client_id ON public.client_vouchers(client_id);
CREATE INDEX idx_client_vouchers_status ON public.client_vouchers(status);
CREATE INDEX idx_client_vouchers_assigned_by ON public.client_vouchers(assigned_by);
CREATE INDEX idx_client_vouchers_used_at ON public.client_vouchers(used_at);

-- Composite indexes for common queries (without WHERE clauses to avoid immutability issues)
CREATE INDEX idx_vouchers_active_unexpired ON public.vouchers(is_active, expiration_date);
CREATE INDEX idx_client_vouchers_active_client ON public.client_vouchers(client_id, status);

-- ============================================================================
-- STEP 5: Enable Row Level Security (RLS)
-- ============================================================================

ALTER TABLE public.vouchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_vouchers ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 6: Create RLS Policies
-- ============================================================================

-- Vouchers table policies
-- Admin and Owner can see all vouchers
CREATE POLICY "Admin and Owner can view all vouchers" ON public.vouchers
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner') 
            AND status = 'approved'
        )
    );

-- Admin and Owner can create vouchers
CREATE POLICY "Admin and Owner can create vouchers" ON public.vouchers
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner') 
            AND status = 'approved'
        )
    );

-- Admin and Owner can update vouchers
CREATE POLICY "Admin and Owner can update vouchers" ON public.vouchers
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner') 
            AND status = 'approved'
        )
    );

-- Admin and Owner can delete vouchers
CREATE POLICY "Admin and Owner can delete vouchers" ON public.vouchers
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner') 
            AND status = 'approved'
        )
    );

-- Client vouchers table policies
-- Clients can only see their own vouchers
CREATE POLICY "Clients can view their own vouchers" ON public.client_vouchers
    FOR SELECT USING (
        client_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner', 'accountant') 
            AND status = 'approved'
        )
    );

-- Admin and Owner can assign vouchers to clients
CREATE POLICY "Admin and Owner can assign vouchers" ON public.client_vouchers
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner') 
            AND status = 'approved'
        )
    );

-- Admin, Owner, and Clients can update their voucher status (for usage)
CREATE POLICY "Update voucher usage" ON public.client_vouchers
    FOR UPDATE USING (
        client_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner', 'accountant') 
            AND status = 'approved'
        )
    );

-- Admin and Owner can delete client voucher assignments
CREATE POLICY "Admin and Owner can delete client vouchers" ON public.client_vouchers
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner') 
            AND status = 'approved'
        )
    );

-- ============================================================================
-- STEP 7: Create Helper Functions
-- ============================================================================

-- Function to generate voucher codes
CREATE OR REPLACE FUNCTION generate_voucher_code()
RETURNS TEXT AS $$
DECLARE
    date_part TEXT;
    random_part TEXT;
    voucher_code TEXT;
    code_exists BOOLEAN;
BEGIN
    -- Generate date part (YYYYMMDD)
    date_part := to_char(now(), 'YYYYMMDD');
    
    -- Generate random part and check for uniqueness
    LOOP
        random_part := upper(substring(md5(random()::text) from 1 for 6));
        voucher_code := 'VOUCHER-' || date_part || '-' || random_part;
        
        SELECT EXISTS(SELECT 1 FROM public.vouchers WHERE code = voucher_code) INTO code_exists;
        
        EXIT WHEN NOT code_exists;
    END LOOP;
    
    RETURN voucher_code;
END;
$$ LANGUAGE plpgsql;

-- Function to check if voucher is valid for use
CREATE OR REPLACE FUNCTION is_voucher_valid(voucher_code TEXT, client_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    voucher_record RECORD;
    client_voucher_record RECORD;
BEGIN
    -- Get voucher details
    SELECT * INTO voucher_record 
    FROM public.vouchers 
    WHERE code = voucher_code AND is_active = true;
    
    -- Check if voucher exists and is active
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- Check if voucher is expired
    IF voucher_record.expiration_date <= now() THEN
        RETURN FALSE;
    END IF;
    
    -- Get client voucher assignment
    SELECT * INTO client_voucher_record 
    FROM public.client_vouchers 
    WHERE voucher_id = voucher_record.id AND client_id = client_user_id;
    
    -- Check if voucher is assigned to client and not used
    IF NOT FOUND OR client_voucher_record.status != 'active' THEN
        RETURN FALSE;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 8: Create Triggers for Automatic Updates
-- ============================================================================

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers
CREATE TRIGGER update_vouchers_updated_at 
    BEFORE UPDATE ON public.vouchers 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_client_vouchers_updated_at 
    BEFORE UPDATE ON public.client_vouchers 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- STEP 9: Insert Sample Data (Optional - for testing)
-- ============================================================================

-- Note: Sample data will be inserted through the application interface
-- This section is kept for reference and testing purposes

-- ============================================================================
-- STEP 10: Grant Necessary Permissions
-- ============================================================================

-- Grant usage on sequences
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO service_role;

-- Grant permissions on tables
GRANT ALL ON public.vouchers TO authenticated;
GRANT ALL ON public.client_vouchers TO authenticated;
GRANT ALL ON public.vouchers TO service_role;
GRANT ALL ON public.client_vouchers TO service_role;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION generate_voucher_code() TO authenticated;
GRANT EXECUTE ON FUNCTION is_voucher_valid(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION update_updated_at_column() TO authenticated;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

-- Verify tables were created successfully
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'vouchers') AND
       EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'client_vouchers') THEN
        RAISE NOTICE 'Voucher system tables created successfully!';
    ELSE
        RAISE EXCEPTION 'Failed to create voucher system tables!';
    END IF;
END $$;
