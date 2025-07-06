import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/models/purchase_invoice_models.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Service for managing purchase invoices with Supabase integration
class PurchaseInvoiceService {
  static final PurchaseInvoiceService _instance = PurchaseInvoiceService._internal();
  factory PurchaseInvoiceService() => _instance;
  PurchaseInvoiceService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create a new purchase invoice
  Future<Map<String, dynamic>> createPurchaseInvoice(PurchaseInvoice invoice) async {
    try {
      AppLogger.info('إنشاء فاتورة مشتريات جديدة: ${invoice.id}');

      // Validate invoice before creation
      final validation = PurchaseInvoiceValidator.validateInvoice(invoice);
      if (!validation['isValid']) {
        AppLogger.error('فشل في التحقق من صحة فاتورة المشتريات: ${validation['errors']}');
        return {
          'success': false,
          'message': 'بيانات الفاتورة غير صحيحة: ${validation['errors'].join(', ')}',
        };
      }

      // Get current user
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'يجب تسجيل الدخول أولاً',
        };
      }

      // Prepare invoice data for database
      final invoiceData = {
        'id': invoice.id,
        'user_id': currentUser.id,
        'supplier_name': invoice.supplierName,
        'total_amount': invoice.totalAmount,
        'status': invoice.status,
        'notes': invoice.notes,
        'created_at': invoice.createdAt.toIso8601String(),
        'updated_at': invoice.updatedAt.toIso8601String(),
      };

      // Insert main invoice record
      final invoiceResponse = await _supabase
          .from('purchase_invoices')
          .insert(invoiceData)
          .select()
          .single();

      AppLogger.info('✅ تم إنشاء سجل الفاتورة الرئيسي: ${invoiceResponse['id']}');

      // Insert invoice items
      final itemsData = invoice.items.map((item) => {
        'purchase_invoice_id': invoice.id,
        'product_name': item.productName,
        'product_image_url': item.productImage,
        'yuan_price': item.yuanPrice,
        'exchange_rate': item.exchangeRate,
        'profit_margin_percent': item.profitMarginPercent,
        'quantity': item.quantity,
        'final_egp_price': item.finalEgpPrice,
        'notes': item.notes,
        'created_at': item.createdAt.toIso8601String(),
      }).toList();

      if (itemsData.isNotEmpty) {
        await _supabase
            .from('purchase_invoice_items')
            .insert(itemsData);

        AppLogger.info('✅ تم إدراج ${itemsData.length} عنصر للفاتورة');
      }

      return {
        'success': true,
        'invoice_id': invoice.id,
        'message': 'تم إنشاء فاتورة المشتريات بنجاح',
        'data': invoiceResponse,
      };
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء فاتورة المشتريات: $e');
      return {
        'success': false,
        'message': 'فشل في إنشاء فاتورة المشتريات: ${e.toString()}',
      };
    }
  }

  /// Get all purchase invoices for current user
  Future<List<PurchaseInvoice>> getPurchaseInvoices({
    String? supplierName,
    String? status,
    String? sortBy = 'created_at',
    bool desc = true,
  }) async {
    try {
      AppLogger.info('جلب فواتير المشتريات...');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        AppLogger.warning('المستخدم غير مسجل الدخول');
        return [];
      }

      // Build query
      var query = _supabase
          .from('purchase_invoices')
          .select('*, purchase_invoice_items(*)')
          .eq('user_id', currentUser.id);

      // Apply filters
      if (supplierName != null && supplierName.isNotEmpty) {
        query = query.ilike('supplier_name', '%$supplierName%');
      }

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      // Apply sorting - handle nullable sortBy parameter
      final sortColumn = sortBy ?? 'created_at';
      final response = await query.order(sortColumn, ascending: !desc);

      // Convert response to PurchaseInvoice objects
      final invoices = response.map((data) {
        // Extract items data
        final itemsData = data['purchase_invoice_items'] as List<dynamic>? ?? [];
        final items = itemsData
            .map((item) => PurchaseInvoiceItem.fromJson(item as Map<String, dynamic>))
            .toList();

        // Create invoice with items
        final invoiceData = Map<String, dynamic>.from(data as Map<String, dynamic>);
        invoiceData['items'] = items.map((item) => item.toJson()).toList();

        return PurchaseInvoice.fromJson(invoiceData);
      }).toList();

      AppLogger.info('✅ تم جلب ${invoices.length} فاتورة مشتريات');
      return invoices;
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب فواتير المشتريات: $e');
      return [];
    }
  }

  /// Get single purchase invoice by ID
  Future<PurchaseInvoice?> getPurchaseInvoice(String invoiceId) async {
    try {
      AppLogger.info('جلب تفاصيل فاتورة المشتريات: $invoiceId');

      final response = await _supabase
          .from('purchase_invoices')
          .select('*, purchase_invoice_items(*)')
          .eq('id', invoiceId)
          .single();

      // Extract items data
      final itemsData = response['purchase_invoice_items'] as List<dynamic>? ?? [];
      final items = itemsData
          .map((item) => PurchaseInvoiceItem.fromJson(item as Map<String, dynamic>))
          .toList();

      // Create invoice with items
      final invoiceData = Map<String, dynamic>.from(response);
      invoiceData['items'] = items.map((item) => item.toJson()).toList();

      final invoice = PurchaseInvoice.fromJson(invoiceData);

      AppLogger.info('✅ تم جلب تفاصيل الفاتورة بنجاح');
      return invoice;
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب تفاصيل فاتورة المشتريات: $e');
      return null;
    }
  }

  /// Update purchase invoice
  Future<Map<String, dynamic>> updatePurchaseInvoice(PurchaseInvoice invoice) async {
    try {
      AppLogger.info('تحديث فاتورة المشتريات: ${invoice.id}');

      // Validate invoice
      final validation = PurchaseInvoiceValidator.validateInvoice(invoice);
      if (!(validation['isValid'] as bool)) {
        return {
          'success': false,
          'message': 'بيانات الفاتورة غير صحيحة: ${validation['errors'].join(', ')}',
        };
      }

      // Update main invoice record
      final invoiceData = {
        'supplier_name': invoice.supplierName,
        'total_amount': invoice.totalAmount,
        'status': invoice.status,
        'notes': invoice.notes,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('purchase_invoices')
          .update(invoiceData)
          .eq('id', invoice.id);

      // Delete existing items
      await _supabase
          .from('purchase_invoice_items')
          .delete()
          .eq('purchase_invoice_id', invoice.id);

      // Insert updated items
      final itemsData = invoice.items.map((item) => {
        'purchase_invoice_id': invoice.id,
        'product_name': item.productName,
        'product_image_url': item.productImage,
        'yuan_price': item.yuanPrice,
        'exchange_rate': item.exchangeRate,
        'profit_margin_percent': item.profitMarginPercent,
        'quantity': item.quantity,
        'final_egp_price': item.finalEgpPrice,
        'notes': item.notes,
        'created_at': item.createdAt.toIso8601String(),
      }).toList();

      if (itemsData.isNotEmpty) {
        await _supabase
            .from('purchase_invoice_items')
            .insert(itemsData);
      }

      AppLogger.info('✅ تم تحديث فاتورة المشتريات بنجاح');

      return {
        'success': true,
        'invoice_id': invoice.id,
        'message': 'تم تحديث فاتورة المشتريات بنجاح',
      };
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث فاتورة المشتريات: $e');
      return {
        'success': false,
        'message': 'فشل في تحديث فاتورة المشتريات: ${e.toString()}',
      };
    }
  }

  /// Delete purchase invoice
  Future<Map<String, dynamic>> deletePurchaseInvoice(String invoiceId) async {
    try {
      AppLogger.info('حذف فاتورة المشتريات: $invoiceId');

      // Delete items first (due to foreign key constraint)
      await _supabase
          .from('purchase_invoice_items')
          .delete()
          .eq('purchase_invoice_id', invoiceId);

      // Delete main invoice record
      await _supabase
          .from('purchase_invoices')
          .delete()
          .eq('id', invoiceId);

      AppLogger.info('✅ تم حذف فاتورة المشتريات بنجاح');

      return {
        'success': true,
        'message': 'تم حذف فاتورة المشتريات بنجاح',
      };
    } catch (e) {
      AppLogger.error('❌ خطأ في حذف فاتورة المشتريات: $e');
      return {
        'success': false,
        'message': 'فشل في حذف فاتورة المشتريات: ${e.toString()}',
      };
    }
  }

  /// Get purchase invoice statistics
  Future<Map<String, dynamic>> getPurchaseInvoiceStats() async {
    try {
      AppLogger.info('جلب إحصائيات فواتير المشتريات...');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        return {
          'totalInvoices': 0,
          'totalAmount': 0.0,
          'pendingInvoices': 0,
          'completedInvoices': 0,
        };
      }

      final response = await _supabase
          .from('purchase_invoices')
          .select('status, total_amount')
          .eq('user_id', currentUser.id);

      final totalInvoices = response.length;
      final totalAmount = response.fold<double>(
        0.0,
        (sum, invoice) => sum + (invoice['total_amount'] as num).toDouble(),
      );
      final pendingInvoices = response.where((invoice) => invoice['status'] == 'pending').length;
      final completedInvoices = response.where((invoice) => invoice['status'] == 'completed').length;

      return {
        'totalInvoices': totalInvoices,
        'totalAmount': totalAmount,
        'pendingInvoices': pendingInvoices,
        'completedInvoices': completedInvoices,
      };
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب إحصائيات فواتير المشتريات: $e');
      return {
        'totalInvoices': 0,
        'totalAmount': 0.0,
        'pendingInvoices': 0,
        'completedInvoices': 0,
      };
    }
  }
}
