-- 💰 نظام السلف - إعداد قاعدة البيانات
-- Advances System Database Setup

-- 1. إنشاء جدول السلف (Advances Table)
CREATE TABLE IF NOT EXISTS public.advances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    advance_name TEXT NOT NULL,
    client_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0),
    description TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'paid')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    created_by UUID NOT NULL REFERENCES auth.users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    approved_by UUID REFERENCES auth.users(id),
    rejected_reason TEXT,
    paid_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}'
);

-- 2. إنشاء الفهارس للأداء
CREATE INDEX IF NOT EXISTS idx_advances_client_id ON public.advances(client_id);
CREATE INDEX IF NOT EXISTS idx_advances_status ON public.advances(status);
CREATE INDEX IF NOT EXISTS idx_advances_created_at ON public.advances(created_at);
CREATE INDEX IF NOT EXISTS idx_advances_created_by ON public.advances(created_by);
CREATE INDEX IF NOT EXISTS idx_advances_approved_by ON public.advances(approved_by);

-- 3. تفعيل Row Level Security
ALTER TABLE public.advances ENABLE ROW LEVEL SECURITY;

-- 4. إنشاء سياسات الأمان

-- سياسة للعملاء - يمكنهم رؤية سلفهم فقط
DROP POLICY IF EXISTS "Clients can view own advances" ON public.advances;
CREATE POLICY "Clients can view own advances" ON public.advances
    FOR SELECT USING (
        auth.uid() = client_id
        OR EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'client'
            AND id = advances.client_id
        )
    );

-- سياسة للمحاسبين والأدمن والمالكين - يمكنهم رؤية جميع السلف
DROP POLICY IF EXISTS "Accountants can view all advances" ON public.advances;
CREATE POLICY "Accountants can view all advances" ON public.advances
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'accountant', 'owner')
        )
    );

-- سياسة للمحاسبين - يمكنهم إنشاء سلف جديدة
DROP POLICY IF EXISTS "Accountants can create advances" ON public.advances;
CREATE POLICY "Accountants can create advances" ON public.advances
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'accountant')
        )
    );

-- سياسة للمحاسبين والأدمن - يمكنهم تحديث السلف
DROP POLICY IF EXISTS "Accountants can update advances" ON public.advances;
CREATE POLICY "Accountants can update advances" ON public.advances
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'accountant', 'owner')
        )
    );

-- سياسة للأدمن - يمكنهم حذف السلف
DROP POLICY IF EXISTS "Admins can delete advances" ON public.advances;
CREATE POLICY "Admins can delete advances" ON public.advances
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() 
            AND role = 'admin'
        )
    );

-- 5. إنشاء دالة لحساب إجمالي السلف حسب الحالة
CREATE OR REPLACE FUNCTION get_advances_summary()
RETURNS TABLE (
    total_advances BIGINT,
    pending_advances BIGINT,
    approved_advances BIGINT,
    rejected_advances BIGINT,
    paid_advances BIGINT,
    total_amount DECIMAL(15,2),
    pending_amount DECIMAL(15,2),
    approved_amount DECIMAL(15,2),
    paid_amount DECIMAL(15,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_advances,
        COUNT(*) FILTER (WHERE status = 'pending') as pending_advances,
        COUNT(*) FILTER (WHERE status = 'approved') as approved_advances,
        COUNT(*) FILTER (WHERE status = 'rejected') as rejected_advances,
        COUNT(*) FILTER (WHERE status = 'paid') as paid_advances,
        COALESCE(SUM(amount), 0) as total_amount,
        COALESCE(SUM(amount) FILTER (WHERE status = 'pending'), 0) as pending_amount,
        COALESCE(SUM(amount) FILTER (WHERE status = 'approved'), 0) as approved_amount,
        COALESCE(SUM(amount) FILTER (WHERE status = 'paid'), 0) as paid_amount
    FROM public.advances;
END;
$$ LANGUAGE plpgsql;

-- 6. إنشاء دالة لاعتماد السلفة
CREATE OR REPLACE FUNCTION approve_advance(
    p_advance_id UUID,
    p_approved_by UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    advance_exists BOOLEAN;
BEGIN
    -- التحقق من وجود السلفة وأنها في حالة انتظار
    SELECT EXISTS(
        SELECT 1 FROM public.advances 
        WHERE id = p_advance_id 
        AND status = 'pending'
    ) INTO advance_exists;
    
    IF NOT advance_exists THEN
        RAISE EXCEPTION 'Advance not found or not in pending status';
    END IF;
    
    -- تحديث حالة السلفة
    UPDATE public.advances 
    SET 
        status = 'approved',
        approved_by = p_approved_by,
        approved_at = now()
    WHERE id = p_advance_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 7. إنشاء دالة لرفض السلفة
CREATE OR REPLACE FUNCTION reject_advance(
    p_advance_id UUID,
    p_rejected_reason TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    advance_exists BOOLEAN;
BEGIN
    -- التحقق من وجود السلفة وأنها في حالة انتظار
    SELECT EXISTS(
        SELECT 1 FROM public.advances 
        WHERE id = p_advance_id 
        AND status = 'pending'
    ) INTO advance_exists;
    
    IF NOT advance_exists THEN
        RAISE EXCEPTION 'Advance not found or not in pending status';
    END IF;
    
    -- تحديث حالة السلفة
    UPDATE public.advances 
    SET 
        status = 'rejected',
        rejected_reason = p_rejected_reason
    WHERE id = p_advance_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 8. إنشاء دالة لتسديد السلفة
CREATE OR REPLACE FUNCTION pay_advance(p_advance_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    advance_exists BOOLEAN;
BEGIN
    -- التحقق من وجود السلفة وأنها معتمدة
    SELECT EXISTS(
        SELECT 1 FROM public.advances 
        WHERE id = p_advance_id 
        AND status = 'approved'
    ) INTO advance_exists;
    
    IF NOT advance_exists THEN
        RAISE EXCEPTION 'Advance not found or not in approved status';
    END IF;
    
    -- تحديث حالة السلفة
    UPDATE public.advances 
    SET 
        status = 'paid',
        paid_at = now()
    WHERE id = p_advance_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 9. إنشاء view لعرض السلف مع تفاصيل العملاء
CREATE OR REPLACE VIEW advances_with_client_details AS
SELECT 
    a.*,
    up.name as client_name,
    up.email as client_email,
    up.phone_number as client_phone,
    creator.name as created_by_name,
    approver.name as approved_by_name
FROM public.advances a
LEFT JOIN public.user_profiles up ON a.client_id = up.id
LEFT JOIN public.user_profiles creator ON a.created_by = creator.id
LEFT JOIN public.user_profiles approver ON a.approved_by = approver.id;

-- 10. إنشاء trigger لتحديث updated_at (إذا أردنا إضافة هذا العمود لاحقاً)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 11. إضافة بيانات تجريبية (اختيارية)
-- يمكن تشغيل هذا القسم لإضافة بيانات تجريبية للاختبار

/*
-- إدراج بعض السلف التجريبية
INSERT INTO public.advances (advance_name, client_id, amount, description, created_by) 
SELECT 
    'سلفة ' || (ROW_NUMBER() OVER()) as advance_name,
    client.id as client_id,
    (RANDOM() * 5000 + 500)::DECIMAL(15,2) as amount,
    'وصف السلفة رقم ' || (ROW_NUMBER() OVER()) as description,
    admin.id as created_by
FROM 
    (SELECT id FROM public.user_profiles WHERE role = 'client' LIMIT 3) client
CROSS JOIN 
    (SELECT id FROM public.user_profiles WHERE role = 'admin' LIMIT 1) admin;
*/

-- 12. عرض النتائج
SELECT 'Advances system setup completed successfully!' as message;

-- عرض ملخص الجداول المنشأة
SELECT 
    table_name,
    table_type
FROM information_schema.tables 
WHERE table_schema = 'public' 
    AND table_name IN ('advances');

-- عرض ملخص السلف (إذا كانت موجودة)
SELECT * FROM get_advances_summary();

-- ✅ تم إعداد نظام السلف بنجاح!
