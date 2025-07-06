# دليل تكامل نظام الحضور البيومتري والموقعي - SmartBizTracker

## نظرة عامة

تم تطوير نظام الحضور البيومتري والموقعي المتقدم لـ SmartBizTracker بأعلى معايير الأمان والجودة. يوفر النظام مصادقة بيومترية مع التحقق من الموقع، واجهة مقسمة للعملاء، وإدارة شاملة للمواقع من لوحة الإدارة.

## المكونات الرئيسية

### 1. النماذج (Models)
- `WarehouseLocationSettings`: إعدادات مواقع المخازن
- `LocationValidationResult`: نتائج التحقق من الموقع
- `AttendanceLocationInfo`: معلومات الموقع للحضور
- `GeofenceSettings`: إعدادات الجيوفنس
- `BiometricAvailabilityResult`: نتائج توفر المصادقة البيومترية
- `BiometricAttendanceResult`: نتائج الحضور البيومتري

### 2. الخدمات (Services)
- `LocationService`: خدمة إدارة الموقع والجيوفنس
- `BiometricAttendanceService`: خدمة المصادقة البيومترية
- تحديث `AttendanceProvider`: دعم البيومتري والموقع

### 3. واجهة المستخدم (UI Components)
- `BiometricSplitScreenWidget`: واجهة مقسمة للحضور والانصراف
- `LocationManagementWidget`: إدارة المواقع للمدير
- `LocationAnalyticsWidget`: تحليلات الموقع والحضور

## ميزات النظام

### 1. المصادقة البيومترية
- دعم بصمة الإصبع والوجه
- تشفير آمن للبيانات البيومترية
- تكامل مع نظام QR الحالي

### 2. التحقق من الموقع
- جيوفنس قابل للتخصيص (10-5000 متر)
- حساب دقيق للمسافات
- تسامح مع دقة GPS

### 3. واجهة العميل المقسمة
- قسم تسجيل الحضور (يسار)
- قسم تسجيل الانصراف (يمين)
- خيارات بيومترية و QR لكل قسم

### 4. إدارة المواقع (المدير)
- تحديد إحداثيات المخزن
- ضبط نطاق الجيوفنس
- خريطة تفاعلية للمواقع

## قاعدة البيانات

### الجداول الجديدة
```sql
-- إعدادات مواقع المخازن
CREATE TABLE warehouse_location_settings (
    id UUID PRIMARY KEY,
    warehouse_name VARCHAR(255),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    geofence_radius DECIMAL(8, 2),
    is_active BOOLEAN,
    description TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    created_by UUID
);
```

### الحقول المضافة
```sql
-- حقول الموقع في جدول الحضور
ALTER TABLE worker_attendance_records 
ADD COLUMN latitude DECIMAL(10, 8),
ADD COLUMN longitude DECIMAL(11, 8),
ADD COLUMN location_validated BOOLEAN,
ADD COLUMN distance_from_warehouse DECIMAL(8, 2),
ADD COLUMN attendance_method VARCHAR(20),
ADD COLUMN biometric_verified BOOLEAN;
```

### الدوال الجديدة
- `process_biometric_attendance()`: معالجة الحضور البيومتري
- `get_location_attendance_stats()`: إحصائيات الموقع
- `validate_warehouse_location()`: التحقق من إعدادات الموقع

## التكامل

### 1. إضافة التبويب في لوحة الإدارة
```dart
// في admin_dashboard.dart
Tab(text: 'إدارة المواقع', icon: Icon(Icons.location_on)),

// في TabBarView
const LocationManagementWidget(),
```

### 2. استخدام الواجهة المقسمة
```dart
// في worker dashboard
BiometricSplitScreenWidget(
  workerId: currentUser.id,
  onAttendanceSuccess: () {
    // تحديث البيانات
    _refreshAttendanceData();
  },
  onError: (error) {
    // عرض رسالة الخطأ
    _showErrorMessage(error);
  },
)
```

### 3. التحقق من المصادقة البيومترية
```dart
final attendanceProvider = Provider.of<AttendanceProvider>(context);

// فحص التوفر
await attendanceProvider.checkBiometricAvailability();

if (attendanceProvider.biometricAvailability?.isAvailable == true) {
  // المصادقة البيومترية متاحة
  final result = await attendanceProvider.processBiometricAttendance(
    workerId: workerId,
    attendanceType: AttendanceType.checkIn,
  );
}
```

### 4. إدارة الموقع
```dart
final locationService = LocationService();

// التحقق من الموقع
final validation = await locationService.validateLocationForAttendance(null);

if (validation.isValid) {
  // الموقع صحيح - يمكن تسجيل الحضور
} else {
  // عرض رسالة خطأ الموقع
  showLocationError(validation.errorMessage);
}
```

## الأذونات المطلوبة

### Android (android/app/src/main/AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
```

### iOS (ios/Runner/Info.plist)
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>يحتاج التطبيق للوصول للموقع للتحقق من الحضور</string>
<key>NSFaceIDUsageDescription</key>
<string>يستخدم التطبيق Face ID لتسجيل الحضور الآمن</string>
```

## معالجة الأخطاء

### أخطاء الموقع
- `LOCATION_DISABLED`: خدمة الموقع معطلة
- `PERMISSION_DENIED`: تم رفض إذن الموقع
- `OUTSIDE_GEOFENCE`: خارج النطاق المسموح
- `WAREHOUSE_LOCATION_NOT_SET`: موقع المخزن غير محدد

### أخطاء البيومتري
- `BIOMETRIC_NOT_AVAILABLE`: المصادقة البيومترية غير متاحة
- `BIOMETRIC_AUTH_FAILED`: فشلت المصادقة البيومترية
- `NO_BIOMETRIC_ENROLLED`: لا توجد بيانات بيومترية مسجلة

## الأمان

### 1. تشفير البيانات
- تشفير HMAC-SHA256 للرموز
- حماية البيانات البيومترية محلياً
- تشفير إحداثيات الموقع

### 2. التحقق من التسلسل
- منع التسجيل المتكرر
- فجوة 15 ساعة بين التسجيلات
- التحقق من تسلسل الحضور/الانصراف

### 3. حماية الخصوصية
- حذف بيانات الموقع القديمة
- عدم تخزين البيانات البيومترية
- تشفير المعلومات الحساسة

## التحليلات والتقارير

### 1. إحصائيات الموقع
- معدل التحقق من الموقع
- متوسط المسافة من المخزن
- عدد التسجيلات خارج النطاق

### 2. توزيع طرق الحضور
- نسبة الحضور البيومتري
- نسبة الحضور بـ QR
- مقارنة الفعالية

### 3. تحليلات زمنية
- أوقات الذروة للحضور
- أنماط الحضور الجغرافية
- تقارير الامتثال للموقع

## الاختبار

### 1. اختبار المصادقة البيومترية
```dart
// اختبار توفر البيومتري
final availability = await biometricService.checkBiometricAvailability();
assert(availability.isAvailable);

// اختبار المصادقة
final authResult = await biometricService.authenticateWithBiometrics(
  reason: 'اختبار المصادقة',
);
assert(authResult.isAuthenticated);
```

### 2. اختبار التحقق من الموقع
```dart
// اختبار الموقع الصحيح
final validation = await locationService.validateLocationForAttendance(null);
assert(validation.isValid);

// اختبار الموقع خارج النطاق
// (يتطلب تغيير الإحداثيات للاختبار)
```

### 3. اختبار التكامل
```dart
// اختبار الحضور البيومتري الكامل
final result = await attendanceProvider.processBiometricAttendance(
  workerId: 'test_worker_id',
  attendanceType: AttendanceType.checkIn,
);
assert(result.success);
```

## الصيانة

### 1. تنظيف البيانات
- تشغيل `cleanup_old_location_data()` دورياً
- أرشفة السجلات القديمة
- تحسين فهارس قاعدة البيانات

### 2. مراقبة الأداء
- مراقبة أوقات استجابة GPS
- تتبع معدلات نجاح المصادقة البيومترية
- مراقبة دقة التحقق من الموقع

### 3. التحديثات
- تحديث إعدادات الجيوفنس حسب الحاجة
- مراجعة أذونات التطبيق
- تحديث خوارزميات التحقق

## الدعم الفني

للحصول على الدعم الفني أو الإبلاغ عن مشاكل:
1. راجع سجلات التطبيق للأخطاء
2. تحقق من أذونات الجهاز
3. تأكد من تفعيل خدمات الموقع
4. تحقق من إعدادات المصادقة البيومترية

---

**ملاحظة**: هذا النظام يتطلب أجهزة تدعم المصادقة البيومترية وخدمات الموقع للعمل بكامل الوظائف.
