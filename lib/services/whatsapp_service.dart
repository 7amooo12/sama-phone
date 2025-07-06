import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/invoice_models.dart';
import '../utils/app_logger.dart';
import 'invoice_pdf_service.dart';

class WhatsAppService {
  factory WhatsAppService() => _instance;
  WhatsAppService._internal();
  static final WhatsAppService _instance = WhatsAppService._internal();

  final InvoicePdfService _pdfService = InvoicePdfService();

  /// Share invoice via WhatsApp
  Future<bool> shareInvoiceViaWhatsApp({
    required Invoice invoice,
    String? phoneNumber,
    String? customMessage,
  }) async {
    try {
      AppLogger.info('مشاركة الفاتورة عبر واتساب: ${invoice.id}');

      // Generate PDF
      final pdfBytes = await _pdfService.generateInvoicePdf(invoice);
      
      // Save PDF to temporary directory
      final tempDir = await getTemporaryDirectory();
      final fileName = 'invoice_${invoice.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      // Prepare message
      final message = customMessage ?? _generateDefaultMessage(invoice);

      // Share via WhatsApp
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        return await _shareToSpecificContact(phoneNumber, message, file.path);
      } else {
        return await _shareToWhatsApp(message, file.path);
      }
    } catch (e) {
      AppLogger.error('خطأ في مشاركة الفاتورة عبر واتساب: $e');
      return false;
    }
  }

  /// Share invoice text only via WhatsApp
  Future<bool> shareInvoiceTextViaWhatsApp({
    required Invoice invoice,
    String? phoneNumber,
    String? customMessage,
  }) async {
    try {
      AppLogger.info('مشاركة نص الفاتورة عبر واتساب: ${invoice.id}');

      final message = customMessage ?? _generateDetailedMessage(invoice);

      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        return await _sendTextToContact(phoneNumber, message);
      } else {
        return await _shareTextToWhatsApp(message);
      }
    } catch (e) {
      AppLogger.error('خطأ في مشاركة نص الفاتورة عبر واتساب: $e');
      return false;
    }
  }

  /// Share to specific WhatsApp contact
  Future<bool> _shareToSpecificContact(String phoneNumber, String message, String filePath) async {
    try {
      // Clean phone number
      final cleanPhone = _cleanPhoneNumber(phoneNumber);
      
      // Try to open WhatsApp with specific contact
      final whatsappUrl = 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}';
      
      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(Uri.parse(whatsappUrl), mode: LaunchMode.externalApplication);
        
        // Share the PDF file separately
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'فاتورة PDF',
        );
        
        return true;
      } else {
        // Fallback to general sharing
        return await _shareToWhatsApp(message, filePath);
      }
    } catch (e) {
      AppLogger.error('خطأ في المشاركة لجهة اتصال محددة: $e');
      return false;
    }
  }

  /// Share to WhatsApp (general)
  Future<bool> _shareToWhatsApp(String message, String filePath) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        text: message,
      );
      return true;
    } catch (e) {
      AppLogger.error('خطأ في المشاركة العامة: $e');
      return false;
    }
  }

  /// Send text message to specific contact
  Future<bool> _sendTextToContact(String phoneNumber, String message) async {
    try {
      final cleanPhone = _cleanPhoneNumber(phoneNumber);
      final whatsappUrl = 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}';
      
      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(Uri.parse(whatsappUrl), mode: LaunchMode.externalApplication);
        return true;
      } else {
        return await _shareTextToWhatsApp(message);
      }
    } catch (e) {
      AppLogger.error('خطأ في إرسال النص لجهة اتصال محددة: $e');
      return false;
    }
  }

  /// Share text to WhatsApp (general)
  Future<bool> _shareTextToWhatsApp(String message) async {
    try {
      await Share.share(message);
      return true;
    } catch (e) {
      AppLogger.error('خطأ في مشاركة النص: $e');
      return false;
    }
  }

  /// Generate default message for invoice
  String _generateDefaultMessage(Invoice invoice) {
    return '''
🧾 *فاتورة من سمارت بيزنس تراكر*

📋 رقم الفاتورة: ${invoice.id}
👤 العميل: ${invoice.customerName}
📅 التاريخ: ${_formatDate(invoice.createdAt)}
💰 الإجمالي: ${_formatCurrency(invoice.totalAmount)} جنيه

📎 يرجى العثور على الفاتورة المرفقة بصيغة PDF

شكراً لتعاملكم معنا! 🙏
''';
  }

  /// Generate detailed message for invoice
  String _generateDetailedMessage(Invoice invoice) {
    final buffer = StringBuffer();
    
    buffer.writeln('🧾 *فاتورة من سمارت بيزنس تراكر*');
    buffer.writeln('');
    buffer.writeln('📋 رقم الفاتورة: ${invoice.id}');
    buffer.writeln('👤 العميل: ${invoice.customerName}');
    if (invoice.customerPhone != null) {
      buffer.writeln('📞 الهاتف: ${invoice.customerPhone}');
    }
    buffer.writeln('📅 التاريخ: ${_formatDate(invoice.createdAt)}');
    buffer.writeln('📊 الحالة: ${_getStatusText(invoice.status)}');
    buffer.writeln('');
    
    buffer.writeln('🛍️ *تفاصيل المنتجات:*');
    for (int i = 0; i < invoice.items.length; i++) {
      final item = invoice.items[i];
      buffer.writeln('${i + 1}. ${item.productName}');
      buffer.writeln('   الكمية: ${item.quantity}');
      buffer.writeln('   السعر: ${_formatCurrency(item.unitPrice)}');
      buffer.writeln('   الإجمالي: ${_formatCurrency(item.subtotal)}');
      buffer.writeln('');
    }
    
    buffer.writeln('💰 *الملخص المالي:*');
    buffer.writeln('المجموع الفرعي: ${_formatCurrency(invoice.subtotal)}');
    if (invoice.discount > 0) {
      buffer.writeln('الخصم: ${_formatCurrency(invoice.discount)}');
    }
    buffer.writeln('الضريبة: ${_formatCurrency(invoice.taxAmount)}');
    buffer.writeln('*الإجمالي النهائي: ${_formatCurrency(invoice.totalAmount)}*');
    
    if (invoice.notes != null && invoice.notes!.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('📝 ملاحظات: ${invoice.notes}');
    }
    
    buffer.writeln('');
    buffer.writeln('شكراً لتعاملكم معنا! 🙏');
    
    return buffer.toString();
  }

  /// Clean phone number for WhatsApp
  String _cleanPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Add country code if not present
    if (cleaned.startsWith('01')) {
      cleaned = '2$cleaned'; // Egypt country code
    } else if (cleaned.startsWith('1') && cleaned.length == 10) {
      cleaned = '2$cleaned'; // Egypt country code
    } else if (!cleaned.startsWith('2') && cleaned.length >= 10) {
      cleaned = '2$cleaned'; // Default to Egypt
    }
    
    return cleaned;
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Format currency for display
  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} جنيه';
  }

  /// Get status text in Arabic
  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'قيد الانتظار ⏳';
      case 'completed':
        return 'مكتملة ✅';
      case 'cancelled':
        return 'ملغاة ❌';
      default:
        return status;
    }
  }

  /// Check if WhatsApp is installed
  Future<bool> isWhatsAppInstalled() async {
    try {
      const whatsappUrl = 'https://wa.me/';
      return await canLaunchUrl(Uri.parse(whatsappUrl));
    } catch (e) {
      AppLogger.error('خطأ في فحص تثبيت واتساب: $e');
      return false;
    }
  }

  /// Open WhatsApp Business if available
  Future<bool> openWhatsAppBusiness() async {
    try {
      const whatsappBusinessUrl = 'whatsapp://';
      if (await canLaunchUrl(Uri.parse(whatsappBusinessUrl))) {
        await launchUrl(Uri.parse(whatsappBusinessUrl));
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('خطأ في فتح واتساب بيزنس: $e');
      return false;
    }
  }

  /// Validate phone number format
  bool isValidPhoneNumber(String phoneNumber) {
    final cleaned = _cleanPhoneNumber(phoneNumber);
    return cleaned.length >= 10 && cleaned.length <= 15;
  }

  /// Format phone number for display
  String formatPhoneNumber(String phoneNumber) {
    final cleaned = _cleanPhoneNumber(phoneNumber);
    if (cleaned.startsWith('2') && cleaned.length == 12) {
      // Egyptian number format: +20 1X XXXX XXXX
      return '+${cleaned.substring(0, 2)} ${cleaned.substring(2, 4)} ${cleaned.substring(4, 8)} ${cleaned.substring(8)}';
    }
    return phoneNumber;
  }
}
