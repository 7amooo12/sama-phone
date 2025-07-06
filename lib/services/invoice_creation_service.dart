import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/invoice_models.dart';
import '../models/product_model.dart';
import '../utils/app_logger.dart';
import 'external_product_sync_service.dart';
import 'auth_state_manager.dart';
import '../services/supabase_service.dart';

class InvoiceCreationService {
  factory InvoiceCreationService() => _instance;
  InvoiceCreationService._internal();
  static final InvoiceCreationService _instance = InvoiceCreationService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;
  final ExternalProductSyncService _productSyncService = ExternalProductSyncService();

  /// Create a new invoice with product images (Enhanced for external API products)
  Future<Map<String, dynamic>> createInvoiceWithImages(Invoice invoice, {List<ProductModel>? externalProducts}) async {
    try {
      AppLogger.info('إنشاء فاتورة جديدة مع صور المنتجات: ${invoice.id}');

      // If external products are provided, sync them to Supabase first
      if (externalProducts != null && externalProducts.isNotEmpty) {
        AppLogger.info('🔄 مزامنة ${externalProducts.length} منتج خارجي مع Supabase...');
        await _productSyncService.syncMultipleProducts(externalProducts);
      }

      // Use database function to create invoice with images
      try {
        // Enhanced authentication check using AuthStateManager
        final currentUser = await AuthStateManager.getCurrentUser(forceRefresh: true);
        if (currentUser == null) {
          AppLogger.error('❌ No authenticated user found for invoice creation');
          throw Exception('المستخدم غير مسجل الدخول');
        }

        AppLogger.info('✅ Authenticated user found: ${currentUser.id}');

        // Prepare items data
        final itemsData = invoice.items.map((item) => {
          'product_id': item.productId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'subtotal': item.subtotal,
          'notes': item.notes,
        }).toList();

        final result = await _supabase.rpc('create_invoice_with_images', params: {
          'p_invoice_id': invoice.id,
          'p_user_id': currentUser.id,
          'p_customer_name': invoice.customerName,
          'p_customer_phone': invoice.customerPhone,
          'p_customer_email': invoice.customerEmail,
          'p_customer_address': invoice.customerAddress,
          'p_items': itemsData,
          'p_subtotal': invoice.subtotal,
          'p_discount': invoice.discount,
          'p_total_amount': invoice.totalAmount,
          'p_notes': invoice.notes,
        });

        if (result != null) {
          AppLogger.info('✅ تم إنشاء الفاتورة مع الصور بنجاح: $result');
          return {
            'success': true,
            'invoice_id': result,
            'message': 'تم إنشاء الفاتورة مع صور المنتجات بنجاح',
          };
        }
      } catch (functionError) {
        AppLogger.warning('⚠️ Database function failed, using fallback: $functionError');
      }

      // Fallback to regular invoice creation
      return await createInvoice(invoice);
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء الفاتورة مع الصور: $e');
      return {
        'success': false,
        'message': 'فشل في إنشاء الفاتورة مع الصور: ${e.toString()}',
      };
    }
  }

  /// Create a new invoice (Local Supabase storage - no external API)
  Future<Map<String, dynamic>> createInvoice(Invoice invoice) async {
    try {
      AppLogger.info('إنشاء فاتورة جديدة محلياً: ${invoice.id}');

      // Validate invoice before creation
      final validation = validateInvoice(invoice);
      if (!validation['isValid']) {
        AppLogger.error('فشل في التحقق من صحة الفاتورة: ${validation['errors']}');
        return {
          'success': false,
          'message': 'بيانات الفاتورة غير صحيحة: ${validation['errors'].join(', ')}',
        };
      }

      // Enhanced authentication check using AuthStateManager
      final currentUser = await AuthStateManager.getCurrentUser(forceRefresh: true);
      if (currentUser == null) {
        AppLogger.error('❌ No authenticated user found for invoice creation');
        throw Exception('المستخدم غير مسجل الدخول');
      }

      AppLogger.info('✅ Authenticated user found for invoice creation: ${currentUser.id}');

      // Prepare invoice data for Supabase (without VAT/tax)
      final invoiceData = _prepareLocalInvoiceData(invoice, currentUser.id);

      // Validate JSONB structure before sending to database
      final itemsData = invoiceData['items'] as List<Map<String, dynamic>>;
      if (!_validateJsonbItemsStructure(itemsData)) {
        throw Exception('فشل في التحقق من صحة بنية عناصر الفاتورة');
      }

      // Log the data structure for debugging
      AppLogger.info('📋 بيانات الفاتورة المُعدة للإرسال:');
      AppLogger.info('- معرف الفاتورة: ${invoiceData['id']}');
      AppLogger.info('- عدد العناصر: ${itemsData.length}');
      AppLogger.info('- نوع بيانات العناصر: ${invoiceData['items'].runtimeType}');
      AppLogger.info('- بنية العنصر الأول: ${itemsData.isNotEmpty ? itemsData.first.keys.toList() : 'لا توجد عناصر'}');

      // Insert invoice into Supabase
      final response = await _supabase
          .from('invoices')
          .insert(invoiceData)
          .select()
          .single();

      AppLogger.info('✅ تم إنشاء الفاتورة بنجاح في قاعدة البيانات المحلية: ${response['id']}');

      // NOTE: We do NOT deduct product quantities automatically
      // This is now a record-only operation as requested
      AppLogger.info('💡 تم إنشاء الفاتورة كسجل فقط - لم يتم خصم الكميات من المخزون');

      return {
        'success': true,
        'invoice_id': response['id'],
        'message': 'تم إنشاء الفاتورة بنجاح',
        'data': response,
      };
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء الفاتورة: $e');

      // Provide more specific error messages
      String errorMessage = 'فشل في إنشاء الفاتورة';
      if (e.toString().contains('Invoice items must be a JSON array')) {
        errorMessage = 'خطأ في تنسيق عناصر الفاتورة - يجب أن تكون مصفوفة JSON صحيحة';
      } else if (e.toString().contains('P0001')) {
        errorMessage = 'خطأ في التحقق من صحة بيانات الفاتورة';
      } else if (e.toString().contains('auth')) {
        errorMessage = 'خطأ في المصادقة - يرجى تسجيل الدخول مرة أخرى';
      }

      return {
        'success': false,
        'message': '$errorMessage: ${e.toString()}',
      };
    }
  }

  /// Get stored invoices from Supabase
  Future<List<Invoice>> getStoredInvoices() async {
    try {
      AppLogger.info('جلب الفواتير المحفوظة من قاعدة البيانات...');

      final response = await _supabase
          .from('invoices')
          .select('*')
          .order('created_at', ascending: false);

      final invoices = <Invoice>[];
      for (final json in (response as List)) {
        try {
          final invoice = Invoice.fromJson(json as Map<String, dynamic>);
          invoices.add(invoice);
        } catch (e) {
          AppLogger.error('خطأ في تحليل فاتورة: $e');
          // Continue processing other invoices instead of failing completely
          continue;
        }
      }

      AppLogger.info('تم جلب ${invoices.length} فاتورة محفوظة');
      return invoices;
    } catch (e) {
      AppLogger.error('خطأ في جلب الفواتير المحفوظة: $e');
      return [];
    }
  }

  /// Get pending invoices for admin
  Future<List<Invoice>> getPendingInvoices() async {
    try {
      AppLogger.info('جلب الفواتير المعلقة...');

      final response = await _supabase
          .from('invoices')
          .select('*')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final invoices = <Invoice>[];
      for (final json in (response as List)) {
        try {
          final invoice = Invoice.fromJson(json as Map<String, dynamic>);
          invoices.add(invoice);
        } catch (e) {
          AppLogger.error('خطأ في تحليل فاتورة معلقة: $e');
          // Continue processing other invoices instead of failing completely
          continue;
        }
      }

      AppLogger.info('تم جلب ${invoices.length} فاتورة معلقة');
      return invoices;
    } catch (e) {
      AppLogger.error('خطأ في جلب الفواتير المعلقة: $e');
      return [];
    }
  }

  /// Update invoice status (Local Supabase only)
  Future<Map<String, dynamic>> updateInvoiceStatus(String invoiceId, String status) async {
    try {
      AppLogger.info('تحديث حالة الفاتورة: $invoiceId إلى $status');

      await _supabase
          .from('invoices')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', invoiceId);

      AppLogger.info('تم تحديث حالة الفاتورة بنجاح');
      return {
        'success': true,
        'message': 'تم تحديث حالة الفاتورة بنجاح',
      };
    } catch (e) {
      AppLogger.error('خطأ في تحديث حالة الفاتورة: $e');
      return {
        'success': false,
        'message': 'فشل في تحديث حالة الفاتورة: ${e.toString()}',
      };
    }
  }

  /// Get invoice details (Local Supabase only)
  Future<Invoice?> getInvoice(String invoiceId) async {
    try {
      AppLogger.info('جلب تفاصيل الفاتورة: $invoiceId');

      final response = await _supabase
          .from('invoices')
          .select()
          .eq('id', invoiceId)
          .single();

      // Convert Supabase JSONB response to Invoice model
      // For JSONB columns, Supabase returns the data as native Dart objects
      final itemsData = response['items'];
      final items = (itemsData as List)
          .map((item) => InvoiceItem.fromJson(item as Map<String, dynamic>))
          .toList();

      // Calculate required values
      final subtotal = response['subtotal']?.toDouble() ??
          items.fold<double>(0.0, (sum, item) => sum + item.subtotal);
      final discount = response['discount']?.toDouble() ?? 0.0;
      final totalAmount = response['total_amount']?.toDouble() ?? (subtotal - discount);

      return Invoice(
        id: response['id'],
        customerName: response['customer_name'],
        customerPhone: response['customer_phone'],
        customerEmail: response['customer_email'],
        customerAddress: response['customer_address'],
        items: items,
        subtotal: subtotal,
        taxAmount: 0.0, // No tax in this system
        discount: discount,
        totalAmount: totalAmount,
        notes: response['notes'],
        status: response['status'] ?? 'draft',
        createdAt: DateTime.parse(response['created_at']),
      );
        } catch (e) {
      AppLogger.error('خطأ في جلب تفاصيل الفاتورة: $e');
      return null;
    }
  }

  /// Update invoice (Local Supabase only)
  Future<Map<String, dynamic>> updateInvoice(Invoice invoice) async {
    try {
      AppLogger.info('تحديث الفاتورة: ${invoice.id}');

      // Validate invoice before update
      final validation = validateInvoice(invoice);
      if (!validation['isValid']) {
        AppLogger.error('فشل في التحقق من صحة الفاتورة: ${validation['errors']}');
        return {
          'success': false,
          'message': 'بيانات الفاتورة غير صحيحة: ${validation['errors'].join(', ')}',
        };
      }

      // Get current user
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // Prepare updated invoice data
      final invoiceData = _prepareLocalInvoiceData(invoice, currentUser.id);
      invoiceData['updated_at'] = DateTime.now().toIso8601String();

      // Validate JSONB structure
      final itemsData = invoiceData['items'] as List<Map<String, dynamic>>;
      if (!_validateJsonbItemsStructure(itemsData)) {
        throw Exception('فشل في التحقق من صحة بنية عناصر الفاتورة');
      }

      // Update invoice in Supabase
      final response = await _supabase
          .from('invoices')
          .update(invoiceData)
          .eq('id', invoice.id)
          .select()
          .single();

      AppLogger.info('✅ تم تحديث الفاتورة بنجاح: ${response['id']}');

      return {
        'success': true,
        'invoice_id': response['id'],
        'message': 'تم تحديث الفاتورة بنجاح',
        'data': response,
      };
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث الفاتورة: $e');

      String errorMessage = 'فشل في تحديث الفاتورة';
      if (e.toString().contains('Invoice items must be a JSON array')) {
        errorMessage = 'خطأ في تنسيق عناصر الفاتورة - يجب أن تكون مصفوفة JSON صحيحة';
      } else if (e.toString().contains('P0001')) {
        errorMessage = 'خطأ في التحقق من صحة بيانات الفاتورة';
      }

      return {
        'success': false,
        'message': '$errorMessage: ${e.toString()}',
      };
    }
  }

  /// Delete invoice (Local Supabase only)
  Future<Map<String, dynamic>> deleteInvoice(String invoiceId) async {
    try {
      AppLogger.info('حذف الفاتورة: $invoiceId');

      await _supabase
          .from('invoices')
          .delete()
          .eq('id', invoiceId);

      AppLogger.info('تم حذف الفاتورة بنجاح');
      return {
        'success': true,
        'message': 'تم حذف الفاتورة بنجاح',
      };
    } catch (e) {
      AppLogger.error('خطأ في حذف الفاتورة: $e');
      return {
        'success': false,
        'message': 'فشل في حذف الفاتورة: ${e.toString()}',
      };
    }
  }

  /// Get invoice statistics (Local Supabase only)
  Future<Map<String, dynamic>> getInvoiceStatistics() async {
    try {
      AppLogger.info('جلب إحصائيات الفواتير...');

      // Get basic statistics from Supabase
      final response = await _supabase
          .from('invoices')
          .select('status, total_amount, created_at');

      final invoices = response as List;

      final totalInvoices = invoices.length;
      final totalAmount = invoices.fold<double>(0, (sum, invoice) =>
          sum + (invoice['total_amount']?.toDouble() ?? 0));

      final paidInvoices = invoices.where((inv) => inv['status'] == 'paid').length;
      final pendingInvoices = invoices.where((inv) => inv['status'] == 'pending').length;
      final draftInvoices = invoices.where((inv) => inv['status'] == 'draft').length;

      return {
        'total_invoices': totalInvoices,
        'total_amount': totalAmount,
        'paid_invoices': paidInvoices,
        'pending_invoices': pendingInvoices,
        'draft_invoices': draftInvoices,
      };
    } catch (e) {
      AppLogger.error('خطأ في جلب إحصائيات الفواتير: $e');
      return {};
    }
  }

  /// Prepare invoice data for local Supabase storage (without VAT/tax)
  Map<String, dynamic> _prepareLocalInvoiceData(Invoice invoice, String userId) {
    // Calculate totals without VAT/tax
    final subtotal = invoice.items.fold<double>(0.0, (sum, item) => sum + item.subtotal);
    final totalAmount = subtotal - invoice.discount; // No tax added

    // Prepare items as List<Map<String, dynamic>> for JSONB column
    // DO NOT use json.encode() - Supabase expects native Dart objects for JSONB
    final itemsData = invoice.items.map((item) => {
      'product_id': item.productId,
      'product_name': item.productName,
      'quantity': item.quantity,
      'unit_price': item.unitPrice,
      'subtotal': item.subtotal,
      'notes': item.notes,
    }).toList();

    return {
      'id': invoice.id,
      'user_id': userId,
      'customer_name': invoice.customerName,
      'customer_phone': invoice.customerPhone,
      'customer_email': invoice.customerEmail,
      'customer_address': invoice.customerAddress,
      'items': itemsData, // Send as List<Map<String, dynamic>> for JSONB
      'subtotal': subtotal,
      'discount': invoice.discount,
      'total_amount': totalAmount, // No tax included
      'notes': invoice.notes,
      'status': invoice.status,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  /// Prepare invoice data for API (deprecated - kept for compatibility)
  Map<String, dynamic> _prepareInvoiceData(Invoice invoice) {
    return {
      'customer_name': invoice.customerName,
      'customer_phone': invoice.customerPhone,
      'customer_email': invoice.customerEmail,
      'customer_address': invoice.customerAddress,
      'items': invoice.items.map((item) => {
        'product_id': item.productId,
        'product_name': item.productName,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'subtotal': item.subtotal,
        'notes': item.notes,
      }).toList(),
      'subtotal': invoice.subtotal,
      'tax_amount': invoice.taxAmount,
      'discount': invoice.discount,
      'total_amount': invoice.totalAmount,
      'notes': invoice.notes,
      'status': invoice.status,
    };
  }



  /// Validate invoice before creation
  Map<String, dynamic> validateInvoice(Invoice invoice) {
    final errors = <String>[];

    // Validate invoice ID
    if (invoice.id.trim().isEmpty) {
      errors.add('معرف الفاتورة مطلوب');
    }

    // Validate customer information
    if (invoice.customerName.trim().isEmpty) {
      errors.add('اسم العميل مطلوب');
    }

    // Validate items
    if (invoice.items.isEmpty) {
      errors.add('يجب إضافة منتج واحد على الأقل');
    }

    // Validate each item for JSONB compatibility
    for (int i = 0; i < invoice.items.length; i++) {
      final item = invoice.items[i];

      // Check required fields
      if (item.productId.trim().isEmpty) {
        errors.add('معرف المنتج مطلوب للعنصر ${i + 1}');
      }

      if (item.productName.trim().isEmpty) {
        errors.add('اسم المنتج مطلوب للعنصر ${i + 1}');
      }

      // Check numeric values
      if (item.quantity <= 0) {
        errors.add('كمية المنتج ${item.productName} يجب أن تكون أكبر من صفر');
      }

      if (item.unitPrice < 0) {
        errors.add('سعر المنتج ${item.productName} يجب أن يكون أكبر من أو يساوي صفر');
      }

      if (item.subtotal < 0) {
        errors.add('المجموع الفرعي للمنتج ${item.productName} يجب أن يكون أكبر من أو يساوي صفر');
      }

      // Validate subtotal calculation
      final expectedSubtotal = item.quantity * item.unitPrice;
      if ((item.subtotal - expectedSubtotal).abs() > 0.01) {
        errors.add('المجموع الفرعي للمنتج ${item.productName} غير صحيح (متوقع: $expectedSubtotal، فعلي: ${item.subtotal})');
      }
    }

    // Validate totals
    if (invoice.subtotal < 0) {
      errors.add('المجموع الفرعي يجب أن يكون أكبر من أو يساوي صفر');
    }

    if (invoice.discount < 0) {
      errors.add('الخصم يجب أن يكون أكبر من أو يساوي صفر');
    }

    if (invoice.totalAmount <= 0) {
      errors.add('إجمالي الفاتورة يجب أن يكون أكبر من صفر');
    }

    // Validate status
    const validStatuses = ['pending', 'completed', 'cancelled', 'draft'];
    if (!validStatuses.contains(invoice.status)) {
      errors.add('حالة الفاتورة غير صحيحة: ${invoice.status}');
    }

    return {
      'isValid': errors.isEmpty,
      'errors': errors,
    };
  }

  /// Validate JSONB items structure before database insertion
  bool _validateJsonbItemsStructure(List<Map<String, dynamic>> items) {
    try {
      // Check if it's a valid list
      if (items.isEmpty) {
        AppLogger.error('❌ قائمة العناصر فارغة');
        return false;
      }

      // Validate each item structure
      for (int i = 0; i < items.length; i++) {
        final item = items[i];

        // Check required fields
        final requiredFields = ['product_id', 'product_name', 'quantity', 'unit_price', 'subtotal'];
        for (final field in requiredFields) {
          if (!item.containsKey(field)) {
            AppLogger.error('❌ العنصر $i يفتقد للحقل المطلوب: $field');
            return false;
          }
        }

        // Check data types
        if (item['product_id'] is! String || item['product_name'] is! String) {
          AppLogger.error('❌ العنصر $i: product_id و product_name يجب أن يكونا نصوص');
          return false;
        }

        if (item['quantity'] is! int || item['quantity'] <= 0) {
          AppLogger.error('❌ العنصر $i: quantity يجب أن يكون رقم صحيح أكبر من صفر');
          return false;
        }

        if (item['unit_price'] is! num || item['unit_price'] < 0) {
          AppLogger.error('❌ العنصر $i: unit_price يجب أن يكون رقم أكبر من أو يساوي صفر');
          return false;
        }

        if (item['subtotal'] is! num || item['subtotal'] < 0) {
          AppLogger.error('❌ العنصر $i: subtotal يجب أن يكون رقم أكبر من أو يساوي صفر');
          return false;
        }
      }

      AppLogger.info('✅ تم التحقق من صحة بنية عناصر JSONB بنجاح');
      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من بنية عناصر JSONB: $e');
      return false;
    }
  }
}
