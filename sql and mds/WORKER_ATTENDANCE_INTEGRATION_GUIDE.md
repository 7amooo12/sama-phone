# دليل تكامل نظام حضور العمال - SmartBizTracker

## نظرة عامة

تم تطوير نظام حضور العمال الاحترافي لـ SmartBizTracker بأعلى معايير الأمان والجودة. يوفر النظام مسح QR آمن مع تشفير HMAC-SHA256، تتبع فوري للحضور، وواجهة مستخدم احترافية باللغة العربية.

## المكونات الرئيسية

### 1. النماذج (Models)
- `WorkerAttendanceModel`: نموذج بيانات الحضور
- `QRAttendanceToken`: رمز QR آمن مع التوقيع الرقمي
- `DeviceInfo`: معلومات الجهاز للأمان
- `AttendanceValidationResponse`: استجابة التحقق
- `AttendanceStatistics`: إحصائيات الحضور

### 2. الخدمات (Services)
- `WorkerAttendanceService`: خدمة إدارة الحضور الأساسية
- `WorkerAttendanceRealtimeService`: التحديثات الفورية
- `WorkerAttendanceSecurity`: نظام الأمان والتشفير
- `WorkerAttendanceErrorHandler`: معالجة الأخطاء الشاملة

### 3. المزودات (Providers)
- `WorkerAttendanceProvider`: إدارة حالة التطبيق

### 4. واجهة المستخدم (UI Components)
- `ProfessionalQRScannerWidget`: ماسح QR احترافي
- `AttendanceSuccessWidget`: واجهة النجاح المتحركة
- `AttendanceFailureWidget`: واجهة الأخطاء التفاعلية
- `WorkerAttendanceDashboardTab`: لوحة التحكم الرئيسية
- `AttendanceAnimations`: مجموعة الرسوم المتحركة

## ميزات الأمان

### 1. التشفير والتوقيع الرقمي
- **HMAC-SHA256**: توقيع رقمي آمن لكل رمز QR
- **Device Fingerprinting**: بصمة فريدة لكل جهاز
- **Nonce System**: منع إعادة استخدام الرموز
- **Timestamp Validation**: صلاحية 20 ثانية فقط

### 2. قواعد العمل
- **15-Hour Gap Rule**: حد أدنى 15 ساعة بين التسجيلات
- **Sequence Validation**: تسلسل منطقي (دخول → خروج → دخول)
- **Device Binding**: ربط الرمز بجهاز محدد
- **Replay Attack Prevention**: منع الهجمات المتكررة

### 3. التحقق متعدد المستويات
```dart
// مثال على التحقق الشامل
final validationResponse = await WorkerAttendanceSecurity.validateTokenSecurity(
  token,
  currentDeviceHash,
  usedNonces,
  lastAttendanceTime,
  lastAttendanceType,
);
```

## التكامل مع قاعدة البيانات

### الجداول المطلوبة
```sql
-- جدول ملفات العمال
CREATE TABLE worker_attendance_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id VARCHAR(50) UNIQUE NOT NULL,
    worker_name VARCHAR(100) NOT NULL,
    employee_id VARCHAR(50) UNIQUE NOT NULL,
    device_hash VARCHAR(64),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- جدول سجلات الحضور
CREATE TABLE worker_attendance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id VARCHAR(50) NOT NULL,
    attendance_type attendance_type_enum NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    device_hash VARCHAR(64) NOT NULL,
    status attendance_status_enum DEFAULT 'confirmed',
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (worker_id) REFERENCES worker_attendance_profiles(worker_id)
);

-- جدول النونسات المستخدمة
CREATE TABLE qr_nonce_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nonce VARCHAR(32) UNIQUE NOT NULL,
    worker_id VARCHAR(50) NOT NULL,
    used_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL
);
```

### الدوال المطلوبة
```sql
-- دالة التحقق من صحة الرمز
CREATE OR REPLACE FUNCTION validate_qr_attendance_token(
    p_worker_id VARCHAR(50),
    p_device_hash VARCHAR(64),
    p_nonce VARCHAR(32),
    p_timestamp INTEGER
) RETURNS JSON AS $$
-- تنفيذ التحقق الشامل
$$;

-- دالة معالجة الحضور
CREATE OR REPLACE FUNCTION process_qr_attendance(
    p_worker_id VARCHAR(50),
    p_device_hash VARCHAR(64),
    p_nonce VARCHAR(32),
    p_timestamp INTEGER
) RETURNS JSON AS $$
-- تنفيذ تسجيل الحضور
$$;

-- دالة الإحصائيات
CREATE OR REPLACE FUNCTION get_attendance_statistics()
RETURNS JSON AS $$
-- إرجاع إحصائيات الحضور
$$;
```

## التكامل مع لوحة التحكم

### 1. إضافة التبويب الخامس
```dart
// في warehouse_manager_dashboard.dart
_tabController = TabController(length: 5, vsync: this); // تحديث العدد

// إضافة التبويب
Tab(
  icon: Icon(Icons.qr_code_scanner, size: 20),
  text: 'حضور العمال',
),

// إضافة المحتوى
Widget _buildWorkerAttendanceTab() {
  return ChangeNotifierProvider(
    create: (context) => WorkerAttendanceProvider(),
    child: const WorkerAttendanceDashboardTab(),
  );
}
```

### 2. إضافة بطاقة الوصول السريع
```dart
WarehouseDashboardCard(
  title: 'حضور العمال',
  subtitle: 'مسح QR وتسجيل الحضور',
  icon: Icons.qr_code_scanner,
  color: const Color(0xFF8B5CF6),
  onTap: () => _tabController.animateTo(4),
),
```

## الاستخدام

### 1. تهيئة النظام
```dart
// في main.dart أو app.dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => WorkerAttendanceProvider()),
    // مزودات أخرى...
  ],
  child: MyApp(),
)
```

### 2. استخدام ماسح QR
```dart
ProfessionalQRScannerWidget(
  onQRDetected: (qrData) async {
    final provider = Provider.of<WorkerAttendanceProvider>(context, listen: false);
    final response = await provider.processQRCode(qrData);
    
    if (response.isValid) {
      // عرض رسالة النجاح
      showDialog(
        context: context,
        builder: (_) => AttendanceSuccessWidget(
          attendanceRecord: response.attendanceRecord!,
        ),
      );
    } else {
      // عرض رسالة الخطأ
      showDialog(
        context: context,
        builder: (_) => AttendanceFailureWidget(
          errorMessage: response.errorMessage!,
          errorCode: response.errorCode,
        ),
      );
    }
  },
)
```

### 3. مراقبة التحديثات الفورية
```dart
// الاستماع للإحصائيات
StreamBuilder<AttendanceStatistics>(
  stream: realtimeService.statisticsStream,
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return AttendanceStatisticsWidget(statistics: snapshot.data!);
    }
    return LoadingWidget();
  },
)

// الاستماع للحضور الجديد
StreamBuilder<WorkerAttendanceModel>(
  stream: realtimeService.newAttendanceStream,
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      // عرض إشعار الحضور الجديد
      return NewAttendanceNotification(attendance: snapshot.data!);
    }
    return SizedBox.shrink();
  },
)
```

## معالجة الأخطاء

### أكواد الأخطاء الرئيسية
- `TOKEN_EXPIRED`: انتهت صلاحية الرمز
- `INVALID_SIGNATURE`: توقيع غير صحيح
- `REPLAY_ATTACK`: إعادة استخدام الرمز
- `DEVICE_MISMATCH`: عدم تطابق الجهاز
- `GAP_VIOLATION`: انتهاك قاعدة 15 ساعة
- `SEQUENCE_ERROR`: خطأ في التسلسل
- `WORKER_NOT_FOUND`: العامل غير موجود

### مثال على معالجة الأخطاء
```dart
try {
  final response = await attendanceService.processAttendance(token);
  if (!response.isValid) {
    WorkerAttendanceErrorHandler.showErrorDialog(
      context,
      response.errorMessage!,
      response.errorCode,
      onRetry: () => _retryAttendance(),
    );
  }
} catch (e) {
  final errorResponse = WorkerAttendanceErrorHandler.handleGenericError(e);
  // عرض رسالة الخطأ
}
```

## الاختبار

### تشغيل الاختبارات
```bash
# اختبارات الوحدة
flutter test test/worker_attendance_test.dart

# اختبارات التكامل
flutter test integration_test/worker_attendance_integration_test.dart

# اختبارات الأداء
flutter test test/worker_attendance_performance_test.dart
```

### سيناريوهات الاختبار
1. **الوظائف الأساسية**: مسح QR، تسجيل الحضور، عرض الإحصائيات
2. **الأمان**: التحقق من التوقيع، منع إعادة الاستخدام، تطابق الجهاز
3. **قواعد العمل**: فجوة 15 ساعة، تسلسل الحضور، صلاحية الرمز
4. **معالجة الأخطاء**: أخطاء الشبكة، أخطاء الكاميرا، أخطاء قاعدة البيانات
5. **الأداء**: سرعة المسح، استهلاك الذاكرة، استجابة الواجهة

## الصيانة والمراقبة

### 1. تنظيف البيانات
```sql
-- تنظيف النونسات المنتهية الصلاحية
DELETE FROM qr_nonce_history 
WHERE expires_at < NOW() - INTERVAL '24 hours';

-- أرشفة سجلات الحضور القديمة
INSERT INTO worker_attendance_archive 
SELECT * FROM worker_attendance_records 
WHERE created_at < NOW() - INTERVAL '1 year';
```

### 2. مراقبة الأداء
- مراقبة أوقات الاستجابة
- تتبع معدلات الأخطاء
- مراقبة استخدام قاعدة البيانات
- تحليل أنماط الاستخدام

### 3. النسخ الاحتياطي
- نسخ احتياطية يومية لبيانات الحضور
- نسخ احتياطية أسبوعية للإحصائيات
- اختبار دوري لاستعادة البيانات

## الدعم والتطوير

للحصول على الدعم أو المساهمة في التطوير:
1. راجع الوثائق التقنية في `/docs`
2. تحقق من الاختبارات في `/test`
3. اتبع معايير الكود في `CODING_STANDARDS.md`
4. أبلغ عن الأخطاء في نظام تتبع المشاكل

---

**ملاحظة**: هذا النظام مصمم للاستخدام في بيئة إنتاج مع أعلى معايير الأمان والموثوقية. تأكد من اختبار جميع الوظائف قبل النشر.
