-- =====================================================
-- DISTRIBUTORS MANAGEMENT SYSTEM - DATABASE SCHEMA
-- =====================================================
-- Created: 2024-12-25
-- Purpose: Complete schema for distribution centers and distributors management
-- Author: SAMA Business System

-- =====================================================
-- 1. CREATE DISTRIBUTION CENTERS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.distribution_centers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    address TEXT,
    city VARCHAR(100),
    region VARCHAR(100),
    postal_code VARCHAR(20),
    manager_name VARCHAR(255),
    manager_phone VARCHAR(20),
    manager_email VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id),
    
    -- Constraints
    CONSTRAINT distribution_centers_name_not_empty CHECK (LENGTH(TRIM(name)) > 0),
    CONSTRAINT distribution_centers_manager_phone_format CHECK (
        manager_phone IS NULL OR 
        manager_phone ~ '^[\+]?[0-9\-\(\)\s]{10,20}$'
    ),
    CONSTRAINT distribution_centers_manager_email_format CHECK (
        manager_email IS NULL OR 
        manager_email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
    )
);

-- =====================================================
-- 2. CREATE DISTRIBUTORS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.distributors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    distribution_center_id UUID NOT NULL REFERENCES public.distribution_centers(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    contact_phone VARCHAR(20) NOT NULL,
    showroom_name VARCHAR(255) NOT NULL,
    showroom_address TEXT,
    email VARCHAR(255),
    national_id VARCHAR(50),
    license_number VARCHAR(100),
    tax_number VARCHAR(100),
    bank_account_number VARCHAR(100),
    bank_name VARCHAR(100),
    commission_rate DECIMAL(5,2) DEFAULT 0.00,
    credit_limit DECIMAL(15,2) DEFAULT 0.00,
    current_balance DECIMAL(15,2) DEFAULT 0.00,
    join_date DATE DEFAULT CURRENT_DATE,
    contract_start_date DATE,
    contract_end_date DATE,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended', 'pending')),
    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id),
    updated_by UUID REFERENCES auth.users(id),
    
    -- Constraints
    CONSTRAINT distributors_name_not_empty CHECK (LENGTH(TRIM(name)) > 0),
    CONSTRAINT distributors_showroom_name_not_empty CHECK (LENGTH(TRIM(showroom_name)) > 0),
    CONSTRAINT distributors_contact_phone_not_empty CHECK (LENGTH(TRIM(contact_phone)) > 0),
    CONSTRAINT distributors_contact_phone_format CHECK (
        contact_phone ~ '^[\+]?[0-9\-\(\)\s]{10,20}$'
    ),
    CONSTRAINT distributors_email_format CHECK (
        email IS NULL OR 
        email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
    ),
    CONSTRAINT distributors_commission_rate_valid CHECK (
        commission_rate >= 0 AND commission_rate <= 100
    ),
    CONSTRAINT distributors_credit_limit_valid CHECK (credit_limit >= 0),
    CONSTRAINT distributors_contract_dates_valid CHECK (
        contract_start_date IS NULL OR 
        contract_end_date IS NULL OR 
        contract_end_date >= contract_start_date
    )
);

-- =====================================================
-- 3. CREATE INDEXES FOR PERFORMANCE
-- =====================================================

-- Distribution Centers Indexes
CREATE INDEX IF NOT EXISTS idx_distribution_centers_name ON public.distribution_centers(name);
CREATE INDEX IF NOT EXISTS idx_distribution_centers_city ON public.distribution_centers(city);
CREATE INDEX IF NOT EXISTS idx_distribution_centers_is_active ON public.distribution_centers(is_active);
CREATE INDEX IF NOT EXISTS idx_distribution_centers_created_at ON public.distribution_centers(created_at);
CREATE INDEX IF NOT EXISTS idx_distribution_centers_created_by ON public.distribution_centers(created_by);

-- Distributors Indexes
CREATE INDEX IF NOT EXISTS idx_distributors_center_id ON public.distributors(distribution_center_id);
CREATE INDEX IF NOT EXISTS idx_distributors_name ON public.distributors(name);
CREATE INDEX IF NOT EXISTS idx_distributors_showroom_name ON public.distributors(showroom_name);
CREATE INDEX IF NOT EXISTS idx_distributors_contact_phone ON public.distributors(contact_phone);
CREATE INDEX IF NOT EXISTS idx_distributors_status ON public.distributors(status);
CREATE INDEX IF NOT EXISTS idx_distributors_is_active ON public.distributors(is_active);
CREATE INDEX IF NOT EXISTS idx_distributors_created_at ON public.distributors(created_at);
CREATE INDEX IF NOT EXISTS idx_distributors_created_by ON public.distributors(created_by);

-- Composite Indexes
CREATE INDEX IF NOT EXISTS idx_distributors_center_status ON public.distributors(distribution_center_id, status);
CREATE INDEX IF NOT EXISTS idx_distributors_center_active ON public.distributors(distribution_center_id, is_active);

-- =====================================================
-- 4. CREATE TRIGGERS FOR AUTOMATIC TIMESTAMPS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for distribution_centers
DROP TRIGGER IF EXISTS update_distribution_centers_updated_at ON public.distribution_centers;
CREATE TRIGGER update_distribution_centers_updated_at
    BEFORE UPDATE ON public.distribution_centers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Triggers for distributors
DROP TRIGGER IF EXISTS update_distributors_updated_at ON public.distributors;
CREATE TRIGGER update_distributors_updated_at
    BEFORE UPDATE ON public.distributors
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 5. CREATE ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on both tables
ALTER TABLE public.distribution_centers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.distributors ENABLE ROW LEVEL SECURITY;

-- Distribution Centers Policies
-- Allow admins and owners to view all centers
CREATE POLICY "distribution_centers_select_policy" ON public.distribution_centers
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner')
        )
    );

-- Allow admins and owners to insert centers
CREATE POLICY "distribution_centers_insert_policy" ON public.distribution_centers
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner')
        )
    );

-- Allow admins and owners to update centers
CREATE POLICY "distribution_centers_update_policy" ON public.distribution_centers
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner')
        )
    );

-- Allow admins and owners to delete centers
CREATE POLICY "distribution_centers_delete_policy" ON public.distribution_centers
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner')
        )
    );

-- Distributors Policies
-- Allow admins and owners to view all distributors
CREATE POLICY "distributors_select_policy" ON public.distributors
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner')
        )
    );

-- Allow admins and owners to insert distributors
CREATE POLICY "distributors_insert_policy" ON public.distributors
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner')
        )
    );

-- Allow admins and owners to update distributors
CREATE POLICY "distributors_update_policy" ON public.distributors
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner')
        )
    );

-- Allow admins and owners to delete distributors
CREATE POLICY "distributors_delete_policy" ON public.distributors
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'owner')
        )
    );

-- =====================================================
-- 6. CREATE UTILITY FUNCTIONS
-- =====================================================

-- Function to get distributor count for a center
CREATE OR REPLACE FUNCTION get_center_distributor_count(center_id UUID)
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)::INTEGER 
        FROM public.distributors 
        WHERE distribution_center_id = center_id 
        AND is_active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get center statistics
CREATE OR REPLACE FUNCTION get_center_statistics(center_id UUID)
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'total_distributors', COUNT(*),
        'active_distributors', COUNT(*) FILTER (WHERE status = 'active'),
        'inactive_distributors', COUNT(*) FILTER (WHERE status = 'inactive'),
        'suspended_distributors', COUNT(*) FILTER (WHERE status = 'suspended'),
        'pending_distributors', COUNT(*) FILTER (WHERE status = 'pending'),
        'total_credit_limit', COALESCE(SUM(credit_limit), 0),
        'total_current_balance', COALESCE(SUM(current_balance), 0)
    ) INTO result
    FROM public.distributors 
    WHERE distribution_center_id = center_id 
    AND is_active = true;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to search distributors
CREATE OR REPLACE FUNCTION search_distributors(search_term TEXT)
RETURNS TABLE (
    id UUID,
    distribution_center_id UUID,
    name VARCHAR(255),
    contact_phone VARCHAR(20),
    showroom_name VARCHAR(255),
    center_name VARCHAR(255)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.id,
        d.distribution_center_id,
        d.name,
        d.contact_phone,
        d.showroom_name,
        dc.name as center_name
    FROM public.distributors d
    JOIN public.distribution_centers dc ON d.distribution_center_id = dc.id
    WHERE d.is_active = true
    AND dc.is_active = true
    AND (
        LOWER(d.name) LIKE LOWER('%' || search_term || '%') OR
        LOWER(d.showroom_name) LIKE LOWER('%' || search_term || '%') OR
        d.contact_phone LIKE '%' || search_term || '%' OR
        LOWER(dc.name) LIKE LOWER('%' || search_term || '%')
    )
    ORDER BY d.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 7. INSERT SAMPLE DATA (OPTIONAL)
-- =====================================================

-- Insert sample distribution centers
INSERT INTO public.distribution_centers (name, description, city, region, manager_name, manager_phone)
VALUES 
    ('مركز توزيع القاهرة الرئيسي', 'المركز الرئيسي لتوزيع منتجات القاهرة الكبرى', 'القاهرة', 'القاهرة', 'أحمد محمد', '+201234567890'),
    ('مركز توزيع الإسكندرية', 'مركز توزيع منطقة الإسكندرية والساحل الشمالي', 'الإسكندرية', 'الإسكندرية', 'محمد علي', '+201234567891'),
    ('مركز توزيع الجيزة', 'مركز توزيع محافظة الجيزة والمناطق المجاورة', 'الجيزة', 'الجيزة', 'سارة أحمد', '+201234567892')
ON CONFLICT DO NOTHING;

-- =====================================================
-- 8. GRANT PERMISSIONS
-- =====================================================

-- Grant permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON public.distribution_centers TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.distributors TO authenticated;

-- Grant usage on sequences
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- =====================================================
-- SCHEMA CREATION COMPLETED SUCCESSFULLY
-- =====================================================

-- Log completion
DO $$
BEGIN
    RAISE NOTICE '✅ Distributors Management System schema created successfully!';
    RAISE NOTICE '📋 Tables created: distribution_centers, distributors';
    RAISE NOTICE '🔍 Indexes created for optimal performance';
    RAISE NOTICE '🔒 RLS policies configured for security';
    RAISE NOTICE '⚡ Triggers and functions ready';
    RAISE NOTICE '📊 Sample data inserted';
END $$;
