-- تحديث جدول السلف لدعم اسم العميل كنص
-- Update advances table to support client name as text

-- إضافة عمود client_name إذا لم يكن موجوداً
ALTER TABLE public.advances 
ADD COLUMN IF NOT EXISTS client_name TEXT;

-- جعل client_id اختياري
ALTER TABLE public.advances 
ALTER COLUMN client_id DROP NOT NULL;

-- تحديث السلف الموجودة لإضافة أسماء العملاء
UPDATE public.advances 
SET client_name = COALESCE(
  (SELECT name FROM public.user_profiles WHERE id = advances.client_id),
  'عميل غير معروف'
)
WHERE client_name IS NULL;

-- إنشاء فهرس على client_name للبحث السريع
CREATE INDEX IF NOT EXISTS idx_advances_client_name 
ON public.advances(client_name);

-- تحديث سياسات الأمان لدعم العمود الجديد
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.advances;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.advances;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.advances;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.advances;

-- سياسة القراءة
CREATE POLICY "Enable read access for authenticated users" ON public.advances
FOR SELECT USING (auth.role() = 'authenticated');

-- سياسة الإدراج
CREATE POLICY "Enable insert for authenticated users" ON public.advances
FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- سياسة التحديث
CREATE POLICY "Enable update for authenticated users" ON public.advances
FOR UPDATE USING (auth.role() = 'authenticated');

-- سياسة الحذف
CREATE POLICY "Enable delete for authenticated users" ON public.advances
FOR DELETE USING (auth.role() = 'authenticated');

-- إضافة تعليق على الجدول
COMMENT ON TABLE public.advances IS 'جدول السلف المالية مع دعم اسم العميل كنص';
COMMENT ON COLUMN public.advances.client_name IS 'اسم العميل كنص عادي';
COMMENT ON COLUMN public.advances.client_id IS 'معرف العميل (اختياري للسلف الجديدة)';

-- إنشاء دالة للبحث في السلف
CREATE OR REPLACE FUNCTION search_advances(search_term TEXT)
RETURNS TABLE (
  id UUID,
  advance_name TEXT,
  client_name TEXT,
  amount DECIMAL,
  status TEXT,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    a.id,
    a.advance_name,
    a.client_name,
    a.amount,
    a.status,
    a.created_at
  FROM public.advances a
  WHERE 
    a.advance_name ILIKE '%' || search_term || '%' OR
    a.client_name ILIKE '%' || search_term || '%' OR
    a.description ILIKE '%' || search_term || '%'
  ORDER BY a.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- منح الصلاحيات للدالة
GRANT EXECUTE ON FUNCTION search_advances(TEXT) TO authenticated;

-- إنشاء دالة لإحصائيات السلف
CREATE OR REPLACE FUNCTION get_advances_statistics()
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'total_advances', COUNT(*),
    'pending_advances', COUNT(*) FILTER (WHERE status = 'pending'),
    'approved_advances', COUNT(*) FILTER (WHERE status = 'approved'),
    'rejected_advances', COUNT(*) FILTER (WHERE status = 'rejected'),
    'paid_advances', COUNT(*) FILTER (WHERE status = 'paid'),
    'total_amount', COALESCE(SUM(amount), 0),
    'pending_amount', COALESCE(SUM(amount) FILTER (WHERE status = 'pending'), 0),
    'approved_amount', COALESCE(SUM(amount) FILTER (WHERE status = 'approved'), 0),
    'paid_amount', COALESCE(SUM(amount) FILTER (WHERE status = 'paid'), 0)
  ) INTO result
  FROM public.advances;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- منح الصلاحيات للدالة
GRANT EXECUTE ON FUNCTION get_advances_statistics() TO authenticated;

-- إنشاء مشغل لتحديث updated_at تلقائياً
CREATE OR REPLACE FUNCTION update_advances_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- إضافة عمود updated_at إذا لم يكن موجوداً
ALTER TABLE public.advances 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- إنشاء المشغل
DROP TRIGGER IF EXISTS trigger_update_advances_updated_at ON public.advances;
CREATE TRIGGER trigger_update_advances_updated_at
  BEFORE UPDATE ON public.advances
  FOR EACH ROW
  EXECUTE FUNCTION update_advances_updated_at();

-- تحديث البيانات الموجودة
UPDATE public.advances 
SET updated_at = created_at 
WHERE updated_at IS NULL;

-- إنشاء مؤشرات إضافية للأداء
CREATE INDEX IF NOT EXISTS idx_advances_status ON public.advances(status);
CREATE INDEX IF NOT EXISTS idx_advances_created_at ON public.advances(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_advances_amount ON public.advances(amount);

-- إنشاء view للسلف مع معلومات إضافية
CREATE OR REPLACE VIEW advances_with_details AS
SELECT 
  a.*,
  CASE 
    WHEN a.status = 'pending' THEN 'في الانتظار'
    WHEN a.status = 'approved' THEN 'معتمدة'
    WHEN a.status = 'rejected' THEN 'مرفوضة'
    WHEN a.status = 'paid' THEN 'مدفوعة'
    ELSE 'غير معروف'
  END as status_arabic,
  EXTRACT(DAYS FROM (NOW() - a.created_at)) as days_since_creation,
  creator.name as created_by_name,
  approver.name as approved_by_name
FROM public.advances a
LEFT JOIN public.user_profiles creator ON a.created_by = creator.id
LEFT JOIN public.user_profiles approver ON a.approved_by = approver.id;

-- منح الصلاحيات للـ view
GRANT SELECT ON advances_with_details TO authenticated;

-- إضافة قيود للتحقق من صحة البيانات
ALTER TABLE public.advances 
ADD CONSTRAINT check_amount_positive 
CHECK (amount > 0);

ALTER TABLE public.advances 
ADD CONSTRAINT check_status_valid 
CHECK (status IN ('pending', 'approved', 'rejected', 'paid'));

-- إضافة قيد للتأكد من وجود اسم العميل
ALTER TABLE public.advances 
ADD CONSTRAINT check_client_name_not_empty 
CHECK (client_name IS NOT NULL AND LENGTH(TRIM(client_name)) > 0);

-- تحديث البيانات الموجودة لضمان التوافق
UPDATE public.advances 
SET client_name = 'عميل غير معروف' 
WHERE client_name IS NULL OR TRIM(client_name) = '';

COMMIT;
