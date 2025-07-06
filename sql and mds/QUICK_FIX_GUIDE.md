# دليل الإصلاح السريع للمستخدمين العالقين

## المشكلة الحالية
المستخدم `testo@sama.com` (ID: 6e12f9dc-2335-404d-8338-17fae71a3a77) موافق عليه من الأدمن لكن لا يستطيع تسجيل الدخول.

## الحلول السريعة

### 1. الحل الأول: SQL في Supabase Dashboard

اذهب إلى Supabase Dashboard → SQL Editor وشغل:

```sql
-- إصلاح المستخدم المحدد
UPDATE user_profiles 
SET 
    status = 'active',
    updated_at = NOW()
WHERE 
    email = 'testo@sama.com';

-- التحقق من النتيجة
SELECT id, email, status, updated_at 
FROM user_profiles 
WHERE email = 'testo@sama.com';
```

### 2. الحل الثاني: من التطبيق

1. اذهب إلى شاشة طلبات التسجيل الجديدة (الأدمن)
2. اضغط على أيقونة الإصلاح السريع (🔧)
3. في قسم "الإصلاح الطارئ":
   - اضغط "إصلاح testo@sama.com"
   - أو اضغط "إصلاح شامل طارئ" لإصلاح جميع المستخدمين

### 3. الحل الثالث: إصلاح يدوي في قاعدة البيانات

في Supabase Dashboard → Table Editor → user_profiles:

1. ابحث عن المستخدم `testo@sama.com`
2. غير `status` من `approved` إلى `active`
3. احفظ التغييرات

## اختبار الحل

بعد تطبيق أي من الحلول:

1. **من التطبيق**: استخدم زر "اختبار تسجيل دخول testo@sama.com"
2. **يدوياً**: حاول تسجيل الدخول بـ:
   - البريد: `testo@sama.com`
   - كلمة المرور: `password123` (أو كلمة المرور الصحيحة)

## الحل الشامل (للمستقبل)

لمنع هذه المشكلة مستقبلاً، شغل هذا SQL:

```sql
-- إضافة trigger تلقائي
CREATE OR REPLACE FUNCTION auto_activate_approved_users()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- إذا تم تغيير الحالة إلى approved، نفعل الحساب تلقائياً
    IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
        NEW.status = 'active';
    END IF;
    
    RETURN NEW;
END;
$$;

-- إنشاء trigger
DROP TRIGGER IF EXISTS trigger_auto_activate ON user_profiles;
CREATE TRIGGER trigger_auto_activate
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION auto_activate_approved_users();
```

## التحقق من النجاح

بعد الإصلاح، يجب أن ترى:

✅ **في قاعدة البيانات:**
- `status = 'active'`
- `updated_at` محدث

✅ **في التطبيق:**
- المستخدم يستطيع تسجيل الدخول
- يتم توجيهه للوحة التحكم المناسبة

## استكشاف الأخطاء

### إذا لم ينجح الحل:

1. **تحقق من كلمة المرور:**
   ```sql
   -- إعادة تعيين كلمة المرور
   UPDATE auth.users 
   SET encrypted_password = crypt('password123', gen_salt('bf'))
   WHERE email = 'testo@sama.com';
   ```

2. **تحقق من وجود المستخدم:**
   ```sql
   SELECT * FROM user_profiles WHERE email = 'testo@sama.com';
   SELECT * FROM auth.users WHERE email = 'testo@sama.com';
   ```

3. **فحص السجلات:**
   - تحقق من سجلات التطبيق
   - تحقق من سجلات Supabase

## الدعم الفني

إذا استمرت المشكلة:

1. استخدم أدوات الإصلاح السريع في التطبيق
2. راجع سجلات الأخطاء
3. تحقق من إعدادات RLS في Supabase
4. تأكد من صحة إعدادات المصادقة

## ملاحظات مهمة

⚠️ **تحذير:** هذه حلول سريعة للمشكلة الحالية. للحل الدائم، يجب تطبيق الحل الشامل المذكور أعلاه.

🔄 **التحديث التلقائي:** بعد تطبيق الحل الشامل، ستتم معالجة المستخدمين الجدد تلقائياً.

📊 **المراقبة:** استخدم أدوات التقارير في التطبيق لمراقبة حالة المستخدمين.
