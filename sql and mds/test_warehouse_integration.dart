import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/services/warehouse_release_orders_service.dart';
import 'package:smartbiztracker_new/services/warehouse_dispatch_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// اختبار تكامل بيانات أذون الصرف
/// يتحقق من أن البيانات تظهر من كلا المصدرين:
/// 1. warehouse_release_orders (الطلبات المعلقة)
/// 2. warehouse_requests (فواتير المتجر)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🧪 بدء اختبار تكامل بيانات أذون الصرف...');
  
  try {
    final releaseOrdersService = WarehouseReleaseOrdersService();
    final dispatchService = WarehouseDispatchService();
    
    // 1. اختبار تحميل طلبات الصرف من warehouse_requests
    print('\n📦 اختبار تحميل طلبات الصرف من warehouse_requests...');
    final dispatchRequests = await dispatchService.getDispatchRequests(limit: 10);
    print('✅ تم تحميل ${dispatchRequests.length} طلب صرف');
    
    // عرض تفاصيل طلبات الصرف من فواتير المتجر
    final storeInvoiceRequests = dispatchRequests.where((request) => 
      request.reason.contains('صرف فاتورة') || 
      request.isMultiWarehouseDistribution
    ).toList();
    
    print('📋 طلبات الصرف من فواتير المتجر: ${storeInvoiceRequests.length}');
    for (final request in storeInvoiceRequests.take(3)) {
      print('   - ${request.requestNumber}: ${request.reason}');
      print('     الحالة: ${request.status} | العناصر: ${request.items.length}');
      print('     تاريخ الإنشاء: ${request.requestedAt}');
      if (request.originalInvoiceId != null) {
        print('     الفاتورة الأصلية: ${request.originalInvoiceId}');
      }
    }
    
    // 2. اختبار تحميل أذون الصرف الموحدة
    print('\n🔄 اختبار تحميل أذون الصرف الموحدة...');
    final allReleaseOrders = await releaseOrdersService.getAllReleaseOrders(limit: 20);
    print('✅ تم تحميل ${allReleaseOrders.length} أذن صرف موحد');
    
    // تحليل مصادر البيانات
    final fromPendingOrders = allReleaseOrders.where((order) => 
      order.metadata?['source'] != 'warehouse_dispatch'
    ).length;
    
    final fromStoreInvoices = allReleaseOrders.where((order) => 
      order.metadata?['source'] == 'warehouse_dispatch'
    ).length;
    
    print('📊 تحليل المصادر:');
    print('   - من الطلبات المعلقة: $fromPendingOrders');
    print('   - من فواتير المتجر: $fromStoreInvoices');
    
    // عرض عينة من أذون الصرف
    print('\n📋 عينة من أذون الصرف الموحدة:');
    for (final order in allReleaseOrders.take(5)) {
      final source = order.metadata?['source'] ?? 'pending_orders';
      print('   - ${order.releaseOrderNumber}: ${order.clientName}');
      print('     المصدر: $source | الحالة: ${order.statusText}');
      print('     المبلغ: ${order.finalAmount} جنيه | العناصر: ${order.items.length}');
      print('     تاريخ الإنشاء: ${order.createdAt}');
      
      if (source == 'warehouse_dispatch') {
        final originalDispatchId = order.metadata?['original_dispatch_id'];
        final warehouseId = order.metadata?['warehouse_id'];
        print('     معرف الطلب الأصلي: $originalDispatchId');
        print('     المخزن: $warehouseId');
      }
      print('');
    }
    
    // 3. اختبار البحث عن الفاتورة المحددة في السجلات
    print('🔍 البحث عن الفاتورة INV-1750586253893...');
    final targetInvoiceOrders = allReleaseOrders.where((order) => 
      order.originalOrderId.contains('1750586253893') ||
      order.releaseOrderNumber.contains('1750586253893') ||
      (order.metadata?['original_dispatch_id']?.toString().contains('1750586253893') ?? false)
    ).toList();
    
    if (targetInvoiceOrders.isNotEmpty) {
      print('✅ تم العثور على ${targetInvoiceOrders.length} أذن صرف للفاتورة المستهدفة:');
      for (final order in targetInvoiceOrders) {
        print('   - ${order.releaseOrderNumber}: ${order.clientName}');
        print('     المصدر: ${order.metadata?['source'] ?? 'pending_orders'}');
        print('     الحالة: ${order.statusText}');
      }
    } else {
      print('⚠️ لم يتم العثور على أذون صرف للفاتورة INV-1750586253893');
      print('   قد تكون الفاتورة لم تُحول بعد أو تحتاج إلى وقت للمزامنة');
    }
    
    // 4. اختبار إحصائيات الحالات
    print('\n📊 إحصائيات الحالات:');
    final statusStats = <String, int>{};
    for (final order in allReleaseOrders) {
      final status = order.statusText;
      statusStats[status] = (statusStats[status] ?? 0) + 1;
    }
    
    statusStats.forEach((status, count) {
      print('   - $status: $count');
    });
    
    print('\n✅ اكتمل اختبار تكامل البيانات بنجاح!');
    print('📋 الملخص:');
    print('   - إجمالي أذون الصرف: ${allReleaseOrders.length}');
    print('   - من الطلبات المعلقة: $fromPendingOrders');
    print('   - من فواتير المتجر: $fromStoreInvoices');
    print('   - طلبات الصرف الأصلية: ${dispatchRequests.length}');
    print('   - طلبات فواتير المتجر: ${storeInvoiceRequests.length}');
    
  } catch (e) {
    print('❌ خطأ في اختبار التكامل: $e');
    print('تفاصيل الخطأ: ${e.toString()}');
  }
}
