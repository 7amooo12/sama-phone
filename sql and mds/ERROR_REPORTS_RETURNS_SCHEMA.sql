-- 🚨 نظام إدارة تقارير الأخطاء والمرتجعات
-- Error Reports & Product Returns Management System

-- 1. إنشاء جدول تقارير الأخطاء (Error Reports Table)
CREATE TABLE IF NOT EXISTS public.error_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    customer_name TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    location TEXT NOT NULL,
    priority TEXT NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'resolved', 'rejected')),
    screenshot_url TEXT,
    admin_notes TEXT,
    assigned_to UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    resolved_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- 2. إنشاء جدول طلبات إرجاع المنتجات (Product Returns Table)
CREATE TABLE IF NOT EXISTS public.product_returns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    customer_name TEXT NOT NULL,
    product_name TEXT NOT NULL,
    order_number TEXT,
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'processing', 'completed')),
    phone TEXT,
    date_purchased TIMESTAMP WITH TIME ZONE,
    has_receipt BOOLEAN DEFAULT FALSE,
    terms_accepted BOOLEAN DEFAULT FALSE,
    product_images JSONB DEFAULT '[]',
    admin_notes TEXT,
    admin_response TEXT,
    refund_amount DECIMAL(10, 2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    processed_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- 3. إنشاء الفهارس لتحسين الأداء
CREATE INDEX IF NOT EXISTS idx_error_reports_customer_id ON public.error_reports(customer_id);
CREATE INDEX IF NOT EXISTS idx_error_reports_status ON public.error_reports(status);
CREATE INDEX IF NOT EXISTS idx_error_reports_priority ON public.error_reports(priority);
CREATE INDEX IF NOT EXISTS idx_error_reports_created_at ON public.error_reports(created_at);
CREATE INDEX IF NOT EXISTS idx_error_reports_assigned_to ON public.error_reports(assigned_to);

CREATE INDEX IF NOT EXISTS idx_product_returns_customer_id ON public.product_returns(customer_id);
CREATE INDEX IF NOT EXISTS idx_product_returns_status ON public.product_returns(status);
CREATE INDEX IF NOT EXISTS idx_product_returns_order_number ON public.product_returns(order_number);
CREATE INDEX IF NOT EXISTS idx_product_returns_created_at ON public.product_returns(created_at);

-- 4. تفعيل Row Level Security (RLS)
ALTER TABLE public.error_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_returns ENABLE ROW LEVEL SECURITY;

-- 5. إنشاء سياسات الأمان (RLS Policies)

-- سياسات تقارير الأخطاء
-- العملاء يمكنهم رؤية تقاريرهم فقط
CREATE POLICY "Users can view their own error reports" ON public.error_reports
    FOR SELECT USING (auth.uid() = customer_id);

-- العملاء يمكنهم إنشاء تقارير جديدة
CREATE POLICY "Users can create error reports" ON public.error_reports
    FOR INSERT WITH CHECK (auth.uid() = customer_id);

-- العملاء يمكنهم تحديث تقاريرهم (محدود)
CREATE POLICY "Users can update their own error reports" ON public.error_reports
    FOR UPDATE USING (auth.uid() = customer_id)
    WITH CHECK (auth.uid() = customer_id);

-- الإداريون يمكنهم رؤية جميع التقارير
CREATE POLICY "Admins can view all error reports" ON public.error_reports
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid()
            AND role IN ('admin', 'owner', 'accountant')
        )
    );

-- الإداريون يمكنهم تحديث جميع التقارير
CREATE POLICY "Admins can update all error reports" ON public.error_reports
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid()
            AND role IN ('admin', 'owner', 'accountant')
        )
    );

-- سياسات طلبات الإرجاع
-- العملاء يمكنهم رؤية طلباتهم فقط
CREATE POLICY "Users can view their own product returns" ON public.product_returns
    FOR SELECT USING (auth.uid() = customer_id);

-- العملاء يمكنهم إنشاء طلبات إرجاع جديدة
CREATE POLICY "Users can create product returns" ON public.product_returns
    FOR INSERT WITH CHECK (auth.uid() = customer_id);

-- العملاء يمكنهم تحديث طلباتهم (محدود)
CREATE POLICY "Users can update their own product returns" ON public.product_returns
    FOR UPDATE USING (auth.uid() = customer_id)
    WITH CHECK (auth.uid() = customer_id);

-- الإداريون يمكنهم رؤية جميع طلبات الإرجاع
CREATE POLICY "Admins can view all product returns" ON public.product_returns
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid()
            AND role IN ('admin', 'owner', 'accountant')
        )
    );

-- الإداريون يمكنهم تحديث جميع طلبات الإرجاع
CREATE POLICY "Admins can update all product returns" ON public.product_returns
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles
            WHERE id = auth.uid()
            AND role IN ('admin', 'owner', 'accountant')
        )
    );

-- 6. إنشاء دالة تحديث updated_at تلقائياً (إذا لم تكن موجودة)
CREATE OR REPLACE FUNCTION public.handle_updated_at_reports()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 7. إنشاء المحفزات (Triggers)
CREATE TRIGGER handle_updated_at_error_reports
    BEFORE UPDATE ON public.error_reports
    FOR EACH ROW EXECUTE PROCEDURE public.handle_updated_at_reports();

CREATE TRIGGER handle_updated_at_product_returns
    BEFORE UPDATE ON public.product_returns
    FOR EACH ROW EXECUTE PROCEDURE public.handle_updated_at_reports();

-- 8. إدراج بيانات تجريبية (اختيارية للاختبار)
-- يمكن حذف هذا القسم في الإنتاج

-- بيانات تجريبية لتقارير الأخطاء
INSERT INTO public.error_reports (customer_id, customer_name, title, description, location, priority, status) 
VALUES 
    ((SELECT id FROM auth.users WHERE email = 'test@sama.com' LIMIT 1), 'عميل تجريبي', 'خطأ في تحميل الصفحة', 'لا تظهر المنتجات في صفحة التسوق', 'صفحة المنتجات', 'high', 'pending'),
    ((SELECT id FROM auth.users WHERE email = 'cust@sama.com' LIMIT 1), 'عميل آخر', 'مشكلة في الدفع', 'لا يمكنني إكمال عملية الدفع', 'صفحة الدفع', 'medium', 'processing')
ON CONFLICT DO NOTHING;

-- بيانات تجريبية لطلبات الإرجاع
INSERT INTO public.product_returns (customer_id, customer_name, product_name, order_number, reason, status, has_receipt) 
VALUES 
    ((SELECT id FROM auth.users WHERE email = 'test@sama.com' LIMIT 1), 'عميل تجريبي', 'هاتف ذكي', 'ORD-001', 'المنتج معيب', 'pending', true),
    ((SELECT id FROM auth.users WHERE email = 'cust@sama.com' LIMIT 1), 'عميل آخر', 'لابتوب', 'ORD-002', 'لا يعمل بشكل صحيح', 'approved', false)
ON CONFLICT DO NOTHING;

-- 9. إنشاء دوال مساعدة للإحصائيات

-- دالة للحصول على عدد التقارير حسب الحالة
CREATE OR REPLACE FUNCTION public.get_error_reports_count_by_status()
RETURNS TABLE(status TEXT, count BIGINT) AS $$
BEGIN
    RETURN QUERY
    SELECT er.status, COUNT(*)
    FROM public.error_reports er
    GROUP BY er.status;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة للحصول على عدد طلبات الإرجاع حسب الحالة
CREATE OR REPLACE FUNCTION public.get_product_returns_count_by_status()
RETURNS TABLE(status TEXT, count BIGINT) AS $$
BEGIN
    RETURN QUERY
    SELECT pr.status, COUNT(*)
    FROM public.product_returns pr
    GROUP BY pr.status;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. منح الصلاحيات
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON public.error_reports TO authenticated;
GRANT ALL ON public.product_returns TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_error_reports_count_by_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_product_returns_count_by_status() TO authenticated;

-- تم إنشاء نظام إدارة تقارير الأخطاء والمرتجعات بنجاح! ✅
