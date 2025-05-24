# نقل المشروع إلى Supabase

## المقدمة

تم نقل مشروع Smart Biz Tracker من Firebase إلى Supabase بنجاح. Supabase هي منصة مفتوحة المصدر تقدم بديلاً مجانياً لـ Firebase مع دعم SQL الكامل.

## الميزات

1. **المصادقة**: دعم كامل للمصادقة بالبريد الإلكتروني وكلمة المرور
2. **قاعدة البيانات**: قاعدة بيانات PostgreSQL كاملة المزايا
3. **التخزين**: تخزين الملفات بكفاءة 
4. **دعم وضع عدم الاتصال**: العمل حتى عند عدم وجود اتصال بالإنترنت

## الفوائد

1. **مجاني للاستخدام**: Supabase يوفر خطة مجانية سخية مع:
   - 500 ميغابايت تخزين قاعدة بيانات
   - 1 غيغابايت تخزين ملفات
   - 2 غيغابايت نقل بيانات شهريًا
   - 50,000 مستخدم مسجل
   - 100,000 عملية API الحقيقية

2. **تحكم كامل**: قاعدة بيانات SQL تقليدية يمكن الوصول إليها مباشرة

3. **تكاليف أقل**: تكاليف أقل بكثير من Firebase عند توسيع المشروع

## ملاحظات تقنية

### الهيكل

- `lib/services/supabase_service.dart`: خدمة للتعامل مع Supabase
- `lib/providers/supabase_provider.dart`: مزود حالة للتعامل مع حالة Supabase
- `lib/services/local_storage_service.dart`: خدمة التخزين المحلي للعمل في وضع عدم الاتصال
- `lib/supabase_schema.sql`: مخطط قاعدة البيانات

### التكوين

تم تكوين Supabase مع الإعدادات التالية:

```dart
await Supabase.initialize(
  url: 'https://ivtjacsppwmjgmuskxis.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml2dGphY3NwcHdtamdtdXNreGlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc3NzUyMjUsImV4cCI6MjA2MzM1MTIyNX0.Ls9Kh3VHhIebuied6N1-QlWkSrEDuLl5vy3XkUVRjHw',
);
```

### أفضل الممارسات في Supabase

1. **الفصل بين المصادقة والملفات الشخصية**:
   - لا نعدل جدول `auth.users` مباشرة، بل نستخدم جدول `user_profiles` مرتبط به
   - نستخدم علاقة الـ UUID (معرف المستخدم الفريد) للربط بين الجدولين

2. **سياسات الأمان (RLS Policies)**:
   - تطبيق سياسات السطر (Row Level Security) على الجداول العامة
   - تحديد الوصول إلى السجلات حسب دور المستخدم

3. **الاستخدام الآمن**:
   ```dart
   // مثال على إضافة بيانات المستخدم بشكل صحيح
   final user = Supabase.instance.client.auth.currentUser;
   await Supabase.instance.client
       .from('user_profiles')
       .insert({'id': user!.id, 'full_name': 'محمد أحمد'});
   ```

### الجداول

1. **user_profiles**: معلومات المستخدمين الإضافية المرتبطة بـ `auth.users`
2. **products**: المنتجات
3. **orders**: الطلبات
4. **order_items**: عناصر الطلبات
5. **categories**: الفئات
6. **notifications**: الإشعارات
7. **favorites**: المفضلة
8. **todos**: نموذج اختبار

## اختبار التكامل

يمكنك اختبار التكامل مع Supabase عن طريق:

1. الانتقال إلى الشاشة الرئيسية
2. النقر على زر "اختبار Supabase" في الأسفل
3. استخدام واجهة المهام لإضافة وتعديل وحذف المهام

## الخطوات التالية

1. مزامنة البيانات الحالية من Firebase إلى Supabase
2. اختبار جميع الميزات للتأكد من العمل بشكل صحيح
3. التحسين للأداء المتميز 

## الأمان

تم تكوين قواعد أمان RLS (Row Level Security) للتأكد من أن:

1. المستخدمون يمكنهم فقط الوصول إلى بياناتهم الخاصة
2. المسؤولون لديهم حق الوصول الكامل إلى جميع البيانات
3. البيانات العامة مثل المنتجات يمكن الوصول إليها من قبل الجميع

## الاستضافة

يستضيف Supabase قاعدة البيانات والتخزين والواجهة الخلفية كاملة. لا حاجة لخدمات استضافة منفصلة. 