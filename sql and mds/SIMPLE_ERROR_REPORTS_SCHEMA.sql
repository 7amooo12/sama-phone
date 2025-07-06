-- 🚨 نظام إدارة تقارير الأخطاء والمرتجعات - إصدار مبسط
-- Simplified Error Reports & Product Returns Management System

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
    order_number TEXT NOT NULL,
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

CREATE INDEX IF NOT EXISTS idx_product_returns_customer_id ON public.product_returns(customer_id);
CREATE INDEX IF NOT EXISTS idx_product_returns_status ON public.product_returns(status);
CREATE INDEX IF NOT EXISTS idx_product_returns_order_number ON public.product_returns(order_number);
CREATE INDEX IF NOT EXISTS idx_product_returns_created_at ON public.product_returns(created_at);

-- 4. تفعيل Row Level Security (RLS)
ALTER TABLE public.error_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_returns ENABLE ROW LEVEL SECURITY;

-- 5. إنشاء سياسات الأمان البسيطة (RLS Policies)

-- سياسات تقارير الأخطاء - مفتوحة للاختبار
DROP POLICY IF EXISTS "error_reports_open_policy" ON public.error_reports;
CREATE POLICY "error_reports_open_policy" ON public.error_reports FOR ALL USING (true);

-- سياسات طلبات الإرجاع - مفتوحة للاختبار  
DROP POLICY IF EXISTS "product_returns_open_policy" ON public.product_returns;
CREATE POLICY "product_returns_open_policy" ON public.product_returns FOR ALL USING (true);

-- 6. إنشاء دالة تحديث updated_at
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 7. إنشاء المحفزات (Triggers)
DROP TRIGGER IF EXISTS update_error_reports_updated_at ON public.error_reports;
CREATE TRIGGER update_error_reports_updated_at
    BEFORE UPDATE ON public.error_reports
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_product_returns_updated_at ON public.product_returns;
CREATE TRIGGER update_product_returns_updated_at
    BEFORE UPDATE ON public.product_returns
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 8. إدراج بيانات تجريبية للاختبار
INSERT INTO public.error_reports (customer_id, customer_name, title, description, location, priority, status) 
VALUES 
    ((SELECT id FROM auth.users WHERE email = 'test@sama.com' LIMIT 1), 'عميل تجريبي', 'خطأ في تحميل الصفحة', 'لا تظهر المنتجات في صفحة التسوق', 'صفحة المنتجات', 'high', 'pending'),
    ((SELECT id FROM auth.users WHERE email = 'cust@sama.com' LIMIT 1), 'عميل آخر', 'مشكلة في الدفع', 'لا يمكنني إكمال عملية الدفع', 'صفحة الدفع', 'medium', 'processing')
ON CONFLICT DO NOTHING;

INSERT INTO public.product_returns (customer_id, customer_name, product_name, order_number, reason, status, has_receipt) 
VALUES 
    ((SELECT id FROM auth.users WHERE email = 'test@sama.com' LIMIT 1), 'عميل تجريبي', 'هاتف ذكي', 'ORD-001', 'المنتج معيب', 'pending', true),
    ((SELECT id FROM auth.users WHERE email = 'cust@sama.com' LIMIT 1), 'عميل آخر', 'لابتوب', 'ORD-002', 'لا يعمل بشكل صحيح', 'approved', false)
ON CONFLICT DO NOTHING;

-- 9. منح الصلاحيات
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON public.error_reports TO authenticated;
GRANT ALL ON public.product_returns TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_updated_at_column() TO authenticated;

-- تم إنشاء نظام إدارة تقارير الأخطاء والمرتجعات بنجاح! ✅
-- يمكن الآن استخدام النظام من خلال التطبيق
