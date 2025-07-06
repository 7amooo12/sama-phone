# 🚀 دليل الإعداد النهائي - SmartBizTracker

## 📋 خطوات الإعداد الكاملة

### 1️⃣ إعداد قاعدة البيانات Supabase

#### أ. إنشاء الجداول الأساسية:
```sql
-- في Supabase SQL Editor، تشغيل الملفات بالترتيب:

-- 1. إعداد ملفات المستخدمين
\i USER_PROFILES_SETUP.sql

-- 2. إعداد نظام المنتجات
\i PRODUCTS_SYSTEM_SETUP.sql

-- 3. إعداد نظام الطلبات
\i ORDERS_SYSTEM_SETUP.sql

-- 4. إعداد نظام المهام
\i TASKS_SYSTEM_SETUP.sql

-- 5. إعداد نظام المكافآت
\i REWARDS_SYSTEM_SETUP.sql

-- 6. إعداد نظام المحافظ
\i WALLET_RELATIONSHIP_FIX.sql

-- 7. إعداد نظام السلف
\i ADVANCES_SYSTEM_SETUP.sql

-- 8. إعداد نظام الإشعارات
\i NOTIFICATIONS_SYSTEM_SETUP.sql
```

#### ب. إنشاء Storage Buckets:
```sql
-- في Supabase Storage
INSERT INTO storage.buckets (id, name, public) VALUES 
('profile-images', 'profile-images', true),
('product-images', 'product-images', true),
('invoices', 'invoices', true),
('attachments', 'attachments', true),
('documents', 'documents', true),
('task-attachments', 'task-attachments', false),
('task-evidence', 'task-evidence', false),
('worker-documents', 'worker-documents', false),
('reward-certificates', 'reward-certificates', true);
```

### 2️⃣ إعداد Flutter Project

#### أ. تنظيف وتحديث المشروع:
```bash
cd flutter_app/smartbiztracker_new
flutter clean
flutter pub get
flutter pub upgrade
```

#### ب. إعداد متغيرات البيئة:
```dart
// في lib/config/supabase_config.dart
class SupabaseConfig {
  static const String url = 'YOUR_SUPABASE_URL';
  static const String anonKey = 'YOUR_SUPABASE_ANON_KEY';
}
```

### 3️⃣ إنشاء حسابات المستخدمين الأساسية

#### أ. حساب الأدمن الرئيسي:
```sql
-- إدراج أدمن رئيسي
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES (
  gen_random_uuid(),
  'admin@sama.com',
  crypt('admin123', gen_salt('bf')),
  now(),
  now(),
  now()
);

-- إنشاء ملف شخصي للأدمن
INSERT INTO public.user_profiles (id, name, email, role, status, phone_number)
SELECT 
  id,
  'مدير النظام',
  'admin@sama.com',
  'admin',
  'approved',
  '01000000000'
FROM auth.users WHERE email = 'admin@sama.com';
```

#### ب. حسابات تجريبية أخرى:
```sql
-- صاحب العمل
INSERT INTO public.user_profiles (name, email, role, status, phone_number)
VALUES ('صاحب العمل', 'owner@sama.com', 'owner', 'approved', '01111111111');

-- المحاسب
INSERT INTO public.user_profiles (name, email, role, status, phone_number)
VALUES ('المحاسب الرئيسي', 'accountant@sama.com', 'accountant', 'approved', '01222222222');

-- عامل تجريبي
INSERT INTO public.user_profiles (name, email, role, status, phone_number)
VALUES ('العامل الأول', 'worker@sama.com', 'worker', 'approved', '01333333333');

-- عميل تجريبي
INSERT INTO public.user_profiles (name, email, role, status, phone_number)
VALUES ('العميل الأول', 'client@sama.com', 'client', 'approved', '01444444444');
```

### 4️⃣ إضافة بيانات تجريبية

#### أ. منتجات تجريبية:
```sql
INSERT INTO public.products (name, description, price, stock_quantity, category, image_url, status)
VALUES 
('منتج تجريبي 1', 'وصف المنتج الأول', 100.00, 50, 'إلكترونيات', '', 'active'),
('منتج تجريبي 2', 'وصف المنتج الثاني', 200.00, 30, 'ملابس', '', 'active'),
('منتج تجريبي 3', 'وصف المنتج الثالث', 150.00, 25, 'أدوات منزلية', '', 'active');
```

#### ب. محافظ أولية:
```sql
-- إنشاء محافظ للمستخدمين
SELECT create_wallet_for_user(
  (SELECT id FROM public.user_profiles WHERE email = 'admin@sama.com'),
  'admin',
  10000.00
);

SELECT create_wallet_for_user(
  (SELECT id FROM public.user_profiles WHERE email = 'owner@sama.com'),
  'owner',
  5000.00
);

SELECT create_wallet_for_user(
  (SELECT id FROM public.user_profiles WHERE email = 'accountant@sama.com'),
  'accountant',
  1000.00
);
```

### 5️⃣ اختبار النظام

#### أ. تشغيل التطبيق:
```bash
flutter run
```

#### ب. اختبار تسجيل الدخول:
- **الأدمن**: admin@sama.com / admin123
- **صاحب العمل**: owner@sama.com / owner123
- **المحاسب**: accountant@sama.com / accountant123
- **العامل**: worker@sama.com / worker123
- **العميل**: client@sama.com / client123

#### ج. اختبار الوظائف:
1. ✅ تسجيل الدخول لكل دور
2. ✅ التنقل بين الشاشات
3. ✅ إضافة منتج جديد
4. ✅ إنشاء طلب
5. ✅ تعيين مهمة
6. ✅ إضافة سلفة
7. ✅ عرض المحفظة

### 6️⃣ إعدادات الإنتاج

#### أ. تحسين الأداء:
```dart
// في main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تحسين الأداء
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  runApp(MyApp());
}
```

#### ب. إعدادات الأمان:
```sql
-- تفعيل RLS على جميع الجداول
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.advances ENABLE ROW LEVEL SECURITY;
```

### 7️⃣ النشر والتوزيع

#### أ. بناء APK للأندرويد:
```bash
flutter build apk --release
```

#### ب. بناء App Bundle:
```bash
flutter build appbundle --release
```

#### ج. بناء iOS (على macOS):
```bash
flutter build ios --release
```

### 8️⃣ الصيانة والمراقبة

#### أ. مراقبة قاعدة البيانات:
```sql
-- فحص حالة الجداول
SELECT 
  schemaname,
  tablename,
  attname,
  n_distinct,
  correlation
FROM pg_stats 
WHERE schemaname = 'public';
```

#### ب. تنظيف البيانات:
```sql
-- حذف البيانات القديمة (اختياري)
DELETE FROM public.notifications 
WHERE created_at < now() - interval '30 days';
```

### 9️⃣ استكشاف الأخطاء

#### أ. مشاكل شائعة:
```bash
# مشكلة في الاتصال بـ Supabase
flutter clean
flutter pub get
flutter run

# مشكلة في الصلاحيات
# تحقق من RLS policies في Supabase Dashboard
```

#### ب. سجلات الأخطاء:
```dart
// في التطبيق
try {
  // العملية
} catch (e) {
  print('Error: $e');
  // إرسال إلى نظام المراقبة
}
```

### 🔟 النسخ الاحتياطية

#### أ. نسخة احتياطية من قاعدة البيانات:
```bash
# في Supabase Dashboard > Settings > Database
# تحميل نسخة احتياطية يومية
```

#### ب. نسخة احتياطية من الكود:
```bash
git add .
git commit -m "Final production version"
git push origin main
```

## ✅ قائمة التحقق النهائية

- [ ] قاعدة البيانات معدة بالكامل
- [ ] جميع الجداول منشأة
- [ ] Storage buckets جاهزة
- [ ] حسابات المستخدمين منشأة
- [ ] بيانات تجريبية مضافة
- [ ] التطبيق يعمل بدون أخطاء
- [ ] جميع الوظائف مختبرة
- [ ] الأمان مفعل
- [ ] النسخ الاحتياطية جاهزة

## 🎉 المشروع جاهز للإنتاج!

بعد اتباع هذه الخطوات، سيكون تطبيق SmartBizTracker جاهزاً للاستخدام الفعلي في بيئة الإنتاج مع جميع الميزات تعمل بكفاءة عالية وأمان مضمون.

---

**تم إعداد المشروع بنجاح! 🚀**
