# 🚀 نظام الطلبات المتكامل مع Supabase

## 📋 نظرة عامة

تم إنشاء نظام طلبات متكامل باستخدام Supabase يوفر:
- ✅ تخزين الطلبات مع تتبع كامل
- ✅ تاريخ مفصل لكل طلب
- ✅ روابط المتابعة والتتبع
- ✅ نظام إشعارات متقدم
- ✅ إحصائيات شاملة
- ✅ أمان متقدم مع RLS

## 🗄️ هيكل قاعدة البيانات

### الجداول الرئيسية:

#### 1. `client_orders` - جدول الطلبات الرئيسي
```sql
- id (UUID) - معرف الطلب
- client_id (UUID) - معرف العميل
- client_name (TEXT) - اسم العميل
- client_email (TEXT) - بريد العميل
- client_phone (TEXT) - هاتف العميل
- order_number (TEXT) - رقم الطلب (يتم توليده تلقائياً)
- status (TEXT) - حالة الطلب
- payment_status (TEXT) - حالة الدفع
- total_amount (DECIMAL) - المبلغ الإجمالي
- shipping_address (JSONB) - عنوان الشحن
- notes (TEXT) - ملاحظات
- assigned_to (UUID) - الموظف المعين
- created_at, updated_at - تواريخ الإنشاء والتحديث
```

#### 2. `client_order_items` - عناصر الطلب
```sql
- id (UUID) - معرف العنصر
- order_id (UUID) - معرف الطلب
- product_id (TEXT) - معرف المنتج
- product_name (TEXT) - اسم المنتج
- product_image (TEXT) - صورة المنتج
- unit_price (DECIMAL) - سعر الوحدة
- quantity (INTEGER) - الكمية
- subtotal (DECIMAL) - المجموع الفرعي
```

#### 3. `order_tracking_links` - روابط التتبع
```sql
- id (UUID) - معرف الرابط
- order_id (UUID) - معرف الطلب
- title (TEXT) - عنوان الرابط
- description (TEXT) - وصف الرابط
- url (TEXT) - الرابط
- link_type (TEXT) - نوع الرابط
- created_by (UUID) - منشئ الرابط
- is_active (BOOLEAN) - حالة الرابط
```

#### 4. `order_history` - تاريخ الطلبات
```sql
- id (UUID) - معرف السجل
- order_id (UUID) - معرف الطلب
- action (TEXT) - نوع العملية
- old_status, new_status (TEXT) - الحالة القديمة والجديدة
- description (TEXT) - وصف التغيير
- changed_by (UUID) - من قام بالتغيير
- created_at - وقت التغيير
```

#### 5. `order_notifications` - الإشعارات
```sql
- id (UUID) - معرف الإشعار
- order_id (UUID) - معرف الطلب
- title (TEXT) - عنوان الإشعار
- message (TEXT) - رسالة الإشعار
- notification_type (TEXT) - نوع الإشعار
- recipient_id (UUID) - المستلم
- is_read (BOOLEAN) - حالة القراءة
```

## 🔧 الميزات المتقدمة

### 1. توليد رقم الطلب التلقائي
```sql
-- مثال: ORD-20241201-0001
CREATE FUNCTION generate_order_number()
```

### 2. Triggers التلقائية
- **عند إنشاء طلب جديد**: إضافة سجل في التاريخ + إرسال إشعارات
- **عند تغيير الحالة**: تسجيل التغيير + إشعار العميل والإدارة
- **عند إضافة رابط تتبع**: إشعار العميل

### 3. نظام الأمان (RLS)
- العملاء يرون طلباتهم فقط
- الإدارة ترى جميع الطلبات
- الموظفون يرون الطلبات المعينة لهم
- المحاسبون يرون جميع الطلبات للمراجعة

### 4. الإحصائيات المتقدمة
```sql
-- دالة للحصول على إحصائيات شاملة
get_order_statistics(start_date, end_date)
```

## 📱 التطبيق

### خدمة Supabase الجديدة
```dart
class SupabaseOrdersService {
  // إنشاء طلب جديد
  Future<String?> createOrder({...})
  
  // جلب الطلبات
  Future<List<ClientOrder>> getClientOrders(String clientId)
  Future<List<ClientOrder>> getAllOrders()
  Future<ClientOrder?> getOrderById(String orderId)
  
  // تحديث الطلبات
  Future<bool> updateOrderStatus(String orderId, OrderStatus status)
  Future<bool> updatePaymentStatus(String orderId, PaymentStatus status)
  Future<bool> assignOrderTo(String orderId, String assignedTo)
  
  // روابط التتبع
  Future<bool> addTrackingLink({...})
  
  // التاريخ والإشعارات
  Future<List<Map<String, dynamic>>> getOrderHistory(String orderId)
  Future<List<Map<String, dynamic>>> getUserNotifications(String userId)
  
  // الإحصائيات
  Future<Map<String, dynamic>?> getOrderStatistics({...})
}
```

### Provider محدث
```dart
class ClientOrdersProvider {
  // دعم Supabase والخدمة القديمة
  bool _useSupabase = true;
  
  // جميع الدوال محدثة لتدعم النظامين
  Future<String?> createOrder({...})
  Future<void> loadClientOrders(String clientId)
  Future<bool> updateOrderStatus(String orderId, OrderStatus status)
  
  // دوال جديدة خاصة بـ Supabase
  Future<bool> updatePaymentStatus(String orderId, PaymentStatus status)
  Future<List<Map<String, dynamic>>> getOrderHistory(String orderId)
  Future<List<Map<String, dynamic>>> getUserNotifications(String userId)
  Future<Map<String, dynamic>?> getOrderStatistics({...})
}
```

## 🎯 حالات الاستخدام

### 1. إنشاء طلب جديد
```dart
final orderId = await orderProvider.createOrder(
  clientId: currentUser.id,
  clientName: currentUser.name,
  clientEmail: currentUser.email,
  clientPhone: currentUser.phone,
  cartItems: cartItems,
  notes: 'ملاحظات خاصة',
  shippingAddress: 'العنوان الكامل',
);
```

### 2. تتبع الطلب
```dart
// جلب تاريخ الطلب
final history = await orderProvider.getOrderHistory(orderId);

// إضافة رابط تتبع
await orderProvider.addTrackingLink(
  orderId: orderId,
  url: 'https://tracking.example.com/123',
  title: 'تتبع الشحن',
  description: 'رابط تتبع الطرد مع شركة الشحن',
  createdBy: adminId,
);
```

### 3. إدارة الطلبات
```dart
// تحديث حالة الطلب
await orderProvider.updateOrderStatus(orderId, OrderStatus.confirmed);

// تحديث حالة الدفع
await orderProvider.updatePaymentStatus(orderId, PaymentStatus.paid);

// تعيين موظف
await orderProvider.assignOrderTo(orderId, employeeId);
```

### 4. الإشعارات
```dart
// جلب الإشعارات
final notifications = await orderProvider.getUserNotifications(userId);

// تحديد كمقروء
await orderProvider.markNotificationAsRead(notificationId);
```

## 📊 الإحصائيات

```dart
final stats = await orderProvider.getOrderStatistics(
  startDate: DateTime.now().subtract(Duration(days: 30)),
  endDate: DateTime.now(),
);

// النتيجة:
{
  'total_orders': 150,
  'pending_orders': 25,
  'confirmed_orders': 50,
  'delivered_orders': 60,
  'total_revenue': 45000.00,
  'average_order_value': 300.00,
}
```

## 🔄 Migration والتطبيق

### 1. تشغيل Migrations
```bash
# في Supabase Dashboard أو CLI
supabase migration up
```

### 2. تفعيل النظام الجديد
```dart
// في ClientOrdersProvider
bool _useSupabase = true; // تغيير إلى true
```

### 3. اختبار النظام
- إنشاء طلب جديد
- تتبع التاريخ
- إضافة روابط تتبع
- فحص الإشعارات

## 🛡️ الأمان

- **Row Level Security (RLS)** مفعل على جميع الجداول
- **سياسات أمان** مخصصة لكل دور
- **تشفير البيانات** الحساسة
- **تسجيل العمليات** في التاريخ

## 🚀 المزايا

1. **تتبع كامل**: كل تغيير يُسجل مع التفاصيل
2. **إشعارات فورية**: تلقائية عند كل تحديث
3. **روابط متعددة**: تتبع، دفع، دعم، توصيل
4. **إحصائيات متقدمة**: تقارير شاملة
5. **أمان عالي**: حماية البيانات والخصوصية
6. **قابلية التوسع**: يدعم آلاف الطلبات
7. **سهولة الصيانة**: كود منظم ومفهوم

## 📝 الخطوات التالية

1. ✅ تطبيق Migrations في Supabase
2. ✅ اختبار النظام الجديد
3. 🔄 إضافة شاشات الإدارة
4. 🔄 تحسين الإشعارات
5. 🔄 إضافة تقارير متقدمة
6. 🔄 دمج مع نظام الدفع

---

**النظام جاهز للاستخدام ويوفر تتبع كامل وتاريخ شامل لجميع الطلبات! 🎉**
