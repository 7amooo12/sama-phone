# دليل حل مشاكل Supabase Storage

## 🚨 المشاكل الشائعة والحلول

### ⚠️ **المشكلة الحالية: فشل في رفع الصور**

#### التشخيص من اللوج:
```json
{
  "operation": "storage.object.list",
  "project": "ivtjacsppwmjgmuskxis",
  "url": "/object/list/profile-images",
  "statusCode": 200,
  "responseTime": 25.29ms
}
```

**التحليل**: العملية تنجح في الوصول للبكت `profile-images` ولكن تفشل في الرفع.

#### ✅ **الحلول المطبقة:**

1. **إصلاح تضارب أسماء البكتات**:
   - تم توحيد الاسم إلى `'profile-images'` في جميع الملفات
   - تم تحديث `supabase_service.dart` و `supabase_storage_service.dart`

2. **إضافة فحص البكتات التلقائي**:
   ```dart
   await _ensureBucketExists(profileImagesBucket);
   ```

3. **تحسين معالجة الأخطاء**:
   - إضافة لوجات مفصلة
   - معالجة أفضل للاستثناءات

4. **تهيئة البكتات عند بدء التطبيق**:
   ```dart
   // في main.dart
   final storageService = SupabaseStorageService();
   await storageService.initializeBuckets();
   ```

#### 🧪 **أدوات التشخيص الجديدة:**
```dart
// اختبار شامل
await StorageTestHelper.runFullStorageTest();

// اختبار سريع
await StorageTestHelper.quickConnectivityTest();

// معلومات التشخيص
StorageTestHelper.printDiagnosticInfo();
```

### 1. مشكلة عدم القدرة على رفع الملفات

#### الأسباب المحتملة:
- ❌ المنطقة (Region) غير صحيحة في التكوين
- ❌ مفاتيح S3 غير صحيحة أو منتهية الصلاحية
- ❌ البكتات غير موجودة أو غير مُعدة بشكل صحيح
- ❌ صلاحيات المستخدم غير كافية

#### الحلول:

##### 1. تحديث التكوين
```dart
// في lib/config/supabase_config.dart
class SupabaseConfig {
  static const String s3Region = 'eu-central-1'; // ✅ المنطقة الصحيحة
  static const String s3AccessKeyId = '26c3b0dac50200a2c77a7173d8ec8400';
  static const String s3SecretAccessKey = 'c8c227195853cbfa33d728aef98835165f05c511872d46748445abbc2125eeb3';
  static const String s3Endpoint = 'https://ivtjacsppwmjgmuskxis.supabase.co/storage/v1/s3';
}
```

##### 2. تهيئة البكتات
```dart
final storageService = SupabaseStorageService();
await storageService.initializeBuckets();
```

##### 3. اختبار الاتصال
```dart
// اختبار بسيط لرفع ملف
try {
  final url = await storageService.uploadProductImage(
    'test-product-id',
    File('path/to/image.jpg'),
  );

  if (url != null) {
    print('✅ نجح الرفع: $url');
  } else {
    print('❌ فشل الرفع');
  }
} catch (e) {
  print('❌ خطأ: $e');
}
```

### 2. مشكلة إضافة منتج جديد

#### الكود الصحيح:
```dart
final productStorageService = ProductStorageService();

// اختيار صور من المعرض
final imageFiles = await ImagePicker().pickMultiImage();

if (imageFiles.isNotEmpty) {
  // إنشاء المنتج مع الصور
  final product = await productStorageService.createProductWithImages(
    name: 'نجفة كريستال فاخرة',
    description: 'نجفة كريستال عالية الجودة',
    price: 2500.0,
    quantity: 10,
    category: 'نجف',
    sku: 'CRYSTAL-001',
    imageFiles: imageFiles.map((file) => File(file.path)).toList(),
    tags: ['نجفة', 'كريستال', 'فاخر'],
  );

  if (product != null) {
    print('✅ تم إنشاء المنتج: ${product.name}');
    print('عدد الصور: ${product.imageUrls.length}');
  } else {
    print('❌ فشل في إنشاء المنتج');
  }
}
```

### 3. مشكلة تحديث الصورة الشخصية

#### الكود الصحيح:
```dart
final profileStorageService = ProfileStorageService();

// اختيار صورة
final imageFile = await ImagePicker().pickImage(source: ImageSource.gallery);

if (imageFile != null) {
  // تحديث الصورة الشخصية
  final imageUrl = await profileStorageService.updateProfileImage(
    'user-id', // استخدم معرف المستخدم الحقيقي
    File(imageFile.path),
  );

  if (imageUrl != null) {
    print('✅ تم تحديث الصورة: $imageUrl');
    // تحديث واجهة المستخدم هنا
  } else {
    print('❌ فشل في تحديث الصورة');
  }
}
```

### 4. مشكلة إنشاء فاتورة

#### الكود الصحيح:
```dart
final invoiceStorageService = InvoiceStorageService();

// إنشاء الفاتورة
final invoiceUrl = await invoiceStorageService.createAndSaveInvoice(
  order: orderModel, // كائن الطلب
  customerName: 'أحمد محمد علي',
  customerPhone: '01234567890',
  customerAddress: 'القاهرة، مصر الجديدة',
  notes: 'يرجى التسليم في المواعيد المحددة',
);

if (invoiceUrl != null) {
  print('✅ تم إنشاء الفاتورة: $invoiceUrl');
  // يمكنك الآن مشاركة الرابط أو عرض الفاتورة
} else {
  print('❌ فشل في إنشاء الفاتورة');
}
```

## 🔧 خطوات التشخيص

### 1. فحص الاتصال
```dart
// تحقق من الاتصال بـ Supabase
final response = await Supabase.instance.client
    .from('user_profiles')
    .select('id')
    .limit(1);

if (response.isNotEmpty) {
  print('✅ الاتصال بقاعدة البيانات يعمل');
} else {
  print('❌ مشكلة في الاتصال');
}
```

### 2. فحص البكتات
```dart
// تحقق من وجود البكتات
try {
  final buckets = await Supabase.instance.client.storage.listBuckets();
  print('البكتات الموجودة: ${buckets.map((b) => b.name).toList()}');
} catch (e) {
  print('خطأ في الحصول على البكتات: $e');
}
```

### 3. فحص الصلاحيات
```dart
// تحقق من صلاحيات المستخدم الحالي
final user = Supabase.instance.client.auth.currentUser;
if (user != null) {
  print('✅ المستخدم مسجل الدخول: ${user.id}');
} else {
  print('❌ المستخدم غير مسجل الدخول');
}
```

## 🚀 اختبار سريع

استخدم الشاشة التجريبية للاختبار:

```dart
// في main.dart أو أي مكان مناسب
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const TestStorageScreen(),
  ),
);
```

## 📞 الحصول على المساعدة

إذا استمرت المشاكل:

1. **تحقق من سجلات الأخطاء:**
   ```dart
   AppLogger.error('تفاصيل الخطأ: $error');
   ```

2. **تحقق من إعدادات Supabase Dashboard:**
   - Storage > Settings
   - تأكد من تفعيل S3 Protocol
   - تحقق من صلاحيات البكتات

3. **تحقق من الشبكة:**
   - تأكد من الاتصال بالإنترنت
   - تحقق من عدم وجود Firewall يحجب الطلبات

## 🔗 روابط مفيدة

- [Supabase Storage Documentation](https://supabase.com/docs/guides/storage)
- [Flutter Image Picker](https://pub.dev/packages/image_picker)
- [PDF Generation](https://pub.dev/packages/pdf)

---

**ملاحظة:** تأكد من تحديث جميع التبعيات في `pubspec.yaml` وتشغيل `flutter pub get` بعد أي تغييرات.
