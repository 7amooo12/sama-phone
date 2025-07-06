import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';
import '../models/order_model.dart';
import '../utils/logger.dart';
import 'supabase_storage_service.dart';
import 'supabase_service.dart';

/// خدمة متخصصة لإدارة الفواتير
class InvoiceStorageService {
  final _storageService = SupabaseStorageService();
  final _supabaseService = SupabaseService();
  final _uuid = const Uuid();

  /// إنشاء وحفظ فاتورة PDF
  Future<String?> createAndSaveInvoice({
    required OrderModel order,
    required String customerName,
    required String customerPhone,
    String? customerAddress,
    String? notes,
  }) async {
    try {
      AppLogger.info('إنشاء فاتورة للطلب: ${order.id}');

      // إنشاء PDF
      final pdfBytes = await _generateInvoicePDF(
        order: order,
        customerName: customerName,
        customerPhone: customerPhone,
        customerAddress: customerAddress,
        notes: notes,
      );

      if (pdfBytes == null) {
        AppLogger.error('فشل في إنشاء PDF');
        return null;
      }

      // إنشاء اسم الملف
      final invoiceId = _uuid.v4();
      final fileName = 'invoice_${order.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = 'invoices/${DateTime.now().year}/${DateTime.now().month}/$fileName';

      // رفع الفاتورة
      final url = await _storageService.uploadFromBytes(
        SupabaseStorageService.invoicesBucket,
        filePath,
        pdfBytes,
        contentType: 'application/pdf',
      );

      if (url != null) {
        // حفظ معلومات الفاتورة في قاعدة البيانات
        await _saveInvoiceRecord(
          invoiceId: invoiceId,
          orderId: order.id,
          customerName: customerName,
          customerPhone: customerPhone,
          customerAddress: customerAddress,
          notes: notes,
          pdfUrl: url,
          totalAmount: order.totalAmount,
        );

        AppLogger.info('تم إنشاء وحفظ الفاتورة: $url');
      }

      return url;
    } catch (e) {
      AppLogger.error('خطأ في إنشاء الفاتورة: $e');
      return null;
    }
  }

  /// إنشاء PDF للفاتورة
  Future<Uint8List?> _generateInvoicePDF({
    required OrderModel order,
    required String customerName,
    required String customerPhone,
    String? customerAddress,
    String? notes,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // رأس الفاتورة
                _buildInvoiceHeader(),
                
                pw.SizedBox(height: 20),
                
                // معلومات العميل
                _buildCustomerInfo(customerName, customerPhone, customerAddress),
                
                pw.SizedBox(height: 20),
                
                // معلومات الطلب
                _buildOrderInfo(order),
                
                pw.SizedBox(height: 20),
                
                // جدول المنتجات
                _buildProductsTable(order),
                
                pw.SizedBox(height: 20),
                
                // الإجمالي
                _buildTotalSection(order),
                
                if (notes != null && notes.isNotEmpty) ...[
                  pw.SizedBox(height: 20),
                  _buildNotesSection(notes),
                ],
                
                pw.Spacer(),
                
                // تذييل الفاتورة
                _buildInvoiceFooter(),
              ],
            );
          },
        ),
      );

      return await pdf.save();
    } catch (e) {
      AppLogger.error('خطأ في إنشاء PDF: $e');
      return null;
    }
  }

  /// بناء رأس الفاتورة
  pw.Widget _buildInvoiceHeader() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'فاتورة مبيعات',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'SAMA Store',
            style: const pw.TextStyle(
              fontSize: 18,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// بناء معلومات العميل
  pw.Widget _buildCustomerInfo(String customerName, String customerPhone, String? customerAddress) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'معلومات العميل',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Text('الاسم: $customerName'),
          pw.Text('الهاتف: $customerPhone'),
          if (customerAddress != null && customerAddress.isNotEmpty)
            pw.Text('العنوان: $customerAddress'),
        ],
      ),
    );
  }

  /// بناء معلومات الطلب
  pw.Widget _buildOrderInfo(OrderModel order) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('رقم الطلب: ${order.id}'),
            pw.Text('تاريخ الطلب: ${_formatDate(order.createdAt)}'),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('رقم الفاتورة: INV-${DateTime.now().millisecondsSinceEpoch}'),
            pw.Text('تاريخ الفاتورة: ${_formatDate(DateTime.now())}'),
          ],
        ),
      ],
    );
  }

  /// بناء جدول المنتجات
  pw.Widget _buildProductsTable(OrderModel order) {
    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        // رأس الجدول
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('المنتج', isHeader: true),
            _buildTableCell('الكمية', isHeader: true),
            _buildTableCell('السعر', isHeader: true),
            _buildTableCell('الإجمالي', isHeader: true),
          ],
        ),
        // صفوف المنتجات
        ...order.items.map((item) => pw.TableRow(
          children: [
            _buildTableCell(item.productName),
            _buildTableCell(item.quantity.toString()),
            _buildTableCell('${item.price.toStringAsFixed(2)} ج.م'),
            _buildTableCell('${(item.price * item.quantity).toStringAsFixed(2)} ج.م'),
          ],
        )),
      ],
    );
  }

  /// بناء خلية الجدول
  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  /// بناء قسم الإجمالي
  pw.Widget _buildTotalSection(OrderModel order) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            'المجموع الكلي: ${order.totalAmount.toStringAsFixed(2)} ج.م',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// بناء قسم الملاحظات
  pw.Widget _buildNotesSection(String notes) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ملاحظات:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text(notes),
        ],
      ),
    );
  }

  /// بناء تذييل الفاتورة
  pw.Widget _buildInvoiceFooter() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey)),
      ),
      child: pw.Text(
        'شكراً لتعاملكم معنا - SAMA Store',
        style: const pw.TextStyle(fontSize: 12),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  /// حفظ سجل الفاتورة في قاعدة البيانات
  Future<void> _saveInvoiceRecord({
    required String invoiceId,
    required String orderId,
    required String customerName,
    required String customerPhone,
    String? customerAddress,
    String? notes,
    required String pdfUrl,
    required double totalAmount,
  }) async {
    try {
      final invoiceData = {
        'id': invoiceId,
        'order_id': orderId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_address': customerAddress,
        'notes': notes,
        'pdf_url': pdfUrl,
        'total_amount': totalAmount,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _supabaseService.createRecord('invoices', invoiceData);
    } catch (e) {
      AppLogger.error('خطأ في حفظ سجل الفاتورة: $e');
    }
  }

  /// تنسيق التاريخ
  String _formatDate(DateTime date) {
    // Convert to local time if UTC to ensure proper timezone handling
    final localDate = date.isUtc ? date.toLocal() : date;
    return '${localDate.day}/${localDate.month}/${localDate.year}';
  }

  /// الحصول على جميع الفواتير
  Future<List<Map<String, dynamic>>> getAllInvoices() async {
    try {
      return await _supabaseService.queryRecords(
        'invoices',
        orderBy: 'created_at',
        ascending: false,
      );
    } catch (e) {
      AppLogger.error('خطأ في الحصول على الفواتير: $e');
      return [];
    }
  }

  /// حذف فاتورة
  Future<bool> deleteInvoice(String invoiceId) async {
    try {
      // الحصول على الفاتورة
      final invoice = await _supabaseService.getRecord('invoices', invoiceId);
      if (invoice == null) return false;

      // حذف ملف PDF
      final pdfUrl = invoice['pdf_url'] as String?;
      if (pdfUrl != null) {
        await _storageService.deleteFileFromUrl(pdfUrl);
      }

      // حذف السجل من قاعدة البيانات
      await _supabaseService.deleteRecord('invoices', invoiceId);
      
      return true;
    } catch (e) {
      AppLogger.error('خطأ في حذف الفاتورة: $e');
      return false;
    }
  }
}
