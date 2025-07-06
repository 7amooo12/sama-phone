# دليل استخدام Supabase Storage

## 📋 نظرة عامة

تم إعداد نظام شامل لإدارة الملفات باستخدام Supabase Storage مع S3 credentials. يتضمن النظام:

- ✅ رفع وإدارة صور المنتجات
- ✅ رفع وإدارة الصور الشخصية
- ✅ إنشاء وحفظ الفواتير PDF
- ✅ رفع المرفقات والوثائق
- ✅ ضغط وتحسين الصور تلقائياً
- ✅ إدارة البكتات (Buckets) تلقائياً

## 🔧 الإعداد

### 1. إعداد Supabase

```dart
// في lib/config/supabase_config.dart
class SupabaseConfig {
  static const String url = 'https://ivtjacsppwmjgmuskxis.supabase.co';
  static const String anonKey = 'your-anon-key';
  static const String serviceRoleKey = 'your-service-role-key';
  
  // S3 Storage Configuration
  static const String s3AccessKeyId = '26c3b0dac50200a2c77a7173d8ec8400';
  static const String s3SecretAccessKey = 'c8c227195853cbfa33d728aef98835165f05c511872d46748445abbc2125eeb3';
}
```

### 2. تهيئة البكتات

```dart
final storageService = SupabaseStorageService();
await storageService.initializeBuckets();
```

## 🚀 الاستخدام

### 1. إضافة منتج جديد مع صور

```dart
final productStorageService = ProductStorageService();

// اختيار صور من المعرض
final imageFiles = await ImagePicker().pickMultiImage();

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
  print('تم إنشاء المنتج: ${product.name}');
  print('عدد الصور: ${product.imageUrls.length}');
}
```

### 2. تحديث الصورة الشخصية

```dart
final profileStorageService = ProfileStorageService();

// اختيار صورة
final imageFile = await ImagePicker().pickImage(source: ImageSource.gallery);

if (imageFile != null) {
  // تحديث الصورة الشخصية
  final imageUrl = await profileStorageService.updateProfileImage(
    'user-id',
    File(imageFile.path),
  );
  
  if (imageUrl != null) {
    print('تم تحديث الصورة: $imageUrl');
  }
}
```

### 3. إنشاء فاتورة PDF

```dart
final invoiceStorageService = InvoiceStorageService();

// إنشاء الفاتورة
final invoiceUrl = await invoiceStorageService.createAndSaveInvoice(
  order: orderModel,
  customerName: 'أحمد محمد علي',
  customerPhone: '01234567890',
  customerAddress: 'القاهرة، مصر الجديدة',
  notes: 'يرجى التسليم في المواعيد المحددة',
);

if (invoiceUrl != null) {
  print('تم إنشاء الفاتورة: $invoiceUrl');
}
```

### 4. رفع مرفق عام

```dart
final storageService = SupabaseStorageService();

// رفع ملف
final attachmentUrl = await storageService.uploadAttachment(
  'documents',
  File('path/to/file.pdf'),
);

if (attachmentUrl != null) {
  print('تم رفع المرفق: $attachmentUrl');
}
```

### 5. إدارة صور المنتج

```dart
final productStorageService = ProductStorageService();

// إضافة صورة جديدة للمنتج
final success = await productStorageService.addProductImage(
  'product-id',
  File('path/to/new-image.jpg'),
);

// حذف صورة من المنتج
await productStorageService.removeProductImage(
  'product-id',
  'image-url-to-remove',
);

// تحديث جميع صور المنتج
await productStorageService.updateProductImages(
  'product-id',
  [File('image1.jpg'), File('image2.jpg')],
);
```

## 📁 هيكل البكتات

```
supabase-storage/
├── profile-images/          # الصور الشخصية
│   └── users/
│       └── {user-id}/
├── product-images/          # صور المنتجات
│   └── products/
│       └── {product-id}/
├── invoices/               # الفواتير
│   └── {year}/
│       └── {month}/
├── attachments/            # المرفقات العامة
│   └── {category}/
└── documents/              # الوثائق
    └── {category}/
```

## 🎯 الميزات المتقدمة

### 1. ضغط الصور تلقائياً

```dart
// يتم ضغط الصور تلقائياً قبل الرفع
// - تصغير الصور الكبيرة إلى 1200px
// - ضغط بجودة 85% للمنتجات
// - ضغط بجودة 90% للصور الشخصية
// - تحويل الصور الشخصية إلى مربع 400x400
```

### 2. إنشاء صورة شخصية افتراضية

```dart
final profileStorageService = ProfileStorageService();

// إنشاء صورة افتراضية بالأحرف الأولى
final defaultImageBytes = await profileStorageService.generateDefaultProfileImage('أحمد محمد');

// رفع الصورة الافتراضية
final imageUrl = await profileStorageService.updateProfileImageFromBytes(
  'user-id',
  defaultImageBytes,
);
```

### 3. رفع من البايتات مباشرة

```dart
final storageService = SupabaseStorageService();

// رفع بايتات مباشرة
final url = await storageService.uploadFromBytes(
  'bucket-name',
  'file-path',
  bytes,
  contentType: 'image/jpeg',
);
```

## 🛡️ الأمان والتحقق

### 1. التحقق من نوع الملف

```dart
final storageService = SupabaseStorageService();

// التحقق من نوع الملف
if (storageService.isValidFileType('image.jpg')) {
  // الملف مسموح
}

// التحقق من حجم الملف
final maxSize = storageService.getMaxFileSize(); // 50MB
```

### 2. أنواع الملفات المسموحة

```dart
// الصور
- .jpg, .jpeg, .png, .gif, .webp

// الوثائق
- .pdf, .doc, .docx, .xls, .xlsx, .txt, .csv
```

## 🔄 إدارة الملفات

### 1. حذف الملفات

```dart
final storageService = SupabaseStorageService();

// حذف ملف من URL
await storageService.deleteFileFromUrl('file-url');

// حذف ملف من مسار
await storageService.deleteFile('bucket-name', 'file-path');
```

### 2. الحصول على قائمة الملفات

```dart
final files = await storageService.listFiles('bucket-name', 'folder-path');
```

## 📊 مراقبة الأداء

```dart
// جميع العمليات تتضمن logging تلقائي
AppLogger.info('تم رفع الملف بنجاح: $url');
AppLogger.error('خطأ في رفع الملف: $error');
```

## 🚨 معالجة الأخطاء

```dart
try {
  final url = await storageService.uploadFile(...);
  if (url != null) {
    // نجح الرفع
  } else {
    // فشل الرفع
  }
} catch (e) {
  // معالجة الخطأ
  AppLogger.error('خطأ: $e');
}
```

## 📱 أمثلة كاملة

راجع ملف `lib/examples/storage_usage_examples.dart` للحصول على أمثلة شاملة لجميع الاستخدامات.

## 🔗 الروابط المفيدة

- [Supabase Storage Documentation](https://supabase.com/docs/guides/storage)
- [Flutter Image Picker](https://pub.dev/packages/image_picker)
- [PDF Generation](https://pub.dev/packages/pdf)
