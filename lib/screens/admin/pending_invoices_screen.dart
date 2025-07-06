import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/invoice_models.dart';
import '../../services/invoice_creation_service.dart';
import '../../services/invoice_pdf_service.dart';
import '../../services/whatsapp_service.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/invoice/invoice_details_dialog.dart';

class PendingInvoicesScreen extends StatefulWidget {
  const PendingInvoicesScreen({super.key});

  @override
  State<PendingInvoicesScreen> createState() => _PendingInvoicesScreenState();
}

class _PendingInvoicesScreenState extends State<PendingInvoicesScreen> {
  final InvoiceCreationService _invoiceService = InvoiceCreationService();
  final InvoicePdfService _pdfService = InvoicePdfService();
  final WhatsAppService _whatsappService = WhatsAppService();

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'ar_EG',
    symbol: 'جنيه',
    decimalDigits: 2,
  );

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy', 'ar');

  List<Invoice> _pendingInvoices = [];
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadPendingInvoices();
  }

  Future<void> _loadPendingInvoices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final invoices = await _invoiceService.getPendingInvoices();
      setState(() {
        _pendingInvoices = invoices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('خطأ في تحميل الفواتير: ${e.toString()}');
    }
  }

  Future<void> _markAsCompleted(Invoice invoice) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      final result = await _invoiceService.updateInvoiceStatus(invoice.id, 'completed');
      
      if ((result['success'] as bool?) == true) {
        setState(() {
          _pendingInvoices.removeWhere((inv) => inv.id == invoice.id);
        });
        _showSuccessSnackBar('تم تأكيد الفاتورة بنجاح');
      } else {
        _showErrorSnackBar((result['message'] as String?) ?? 'خطأ غير معروف');
      }
    } catch (e) {
      _showErrorSnackBar('خطأ في تأكيد الفاتورة: ${e.toString()}');
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _generatePdf(Invoice invoice) async {
    try {
      setState(() {
        _isUpdating = true;
      });

      final pdfBytes = await _pdfService.generateInvoicePdf(invoice);
      final fileName = 'invoice_${invoice.id}.pdf';
      final filePath = await _pdfService.savePdfToDevice(pdfBytes, fileName);

      if (filePath != null) {
        _showSuccessSnackBar('تم حفظ PDF في: $filePath');
      } else {
        _showErrorSnackBar('فشل في حفظ PDF');
      }
    } catch (e) {
      _showErrorSnackBar('خطأ في إنشاء PDF: ${e.toString()}');
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _shareViaWhatsApp(Invoice invoice) async {
    try {
      setState(() {
        _isUpdating = true;
      });

      final success = await _whatsappService.shareInvoiceViaWhatsApp(
        invoice: invoice,
        phoneNumber: invoice.customerPhone,
      );

      if (success) {
        _showSuccessSnackBar('تم فتح واتساب للمشاركة');
      } else {
        _showErrorSnackBar('فشل في فتح واتساب');
      }
    } catch (e) {
      _showErrorSnackBar('خطأ في مشاركة واتساب: ${e.toString()}');
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  void _showInvoiceDetails(Invoice invoice) {
    showDialog(
      context: context,
      builder: (context) => InvoiceDetailsDialog(
        invoice: invoice,
        onMarkCompleted: () => _markAsCompleted(invoice),
        onGeneratePdf: () => _generatePdf(invoice),
        onShareWhatsApp: () => _shareViaWhatsApp(invoice),
        currencyFormat: _currencyFormat,
        dateFormat: _dateFormat,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const CustomAppBar(
        title: 'الفواتير المعلقة',
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        showBackButton: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_pendingInvoices.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadPendingInvoices,
            color: const Color(0xFF10B981),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pendingInvoices.length,
              itemBuilder: (context, index) {
                final invoice = _pendingInvoices[index];
                return _buildInvoiceCard(invoice);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade900,
            Colors.black,
          ],
        ),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade700),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.pending_actions, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الفواتير المعلقة (${_pendingInvoices.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                Text(
                  'فواتير تحتاج إلى مراجعة وتأكيد',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadPendingInvoices,
            icon: const Icon(Icons.refresh, color: Color(0xFF10B981)),
            tooltip: 'تحديث',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981).withValues(alpha: 0.1),
                  const Color(0xFF10B981).withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'لا توجد فواتير معلقة',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'جميع الفواتير تم تأكيدها',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 16,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _loadPendingInvoices,
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text(
              'تحديث',
              style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade900,
            Colors.black,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt, color: Colors.white, size: 24),
            ),
            title: Text(
              'فاتورة ${invoice.id}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'العميل: ${invoice.customerName}',
                  style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                ),
                Text(
                  'التاريخ: ${_dateFormat.format(invoice.createdAt)}',
                  style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _currencyFormat.format(invoice.totalAmount),
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Text(
                    'معلقة',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            onTap: () => _showInvoiceDetails(invoice),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUpdating ? null : () => _showInvoiceDetails(invoice),
                    icon: const Icon(Icons.visibility, color: Color(0xFF10B981)),
                    label: const Text(
                      'عرض التفاصيل',
                      style: TextStyle(color: Color(0xFF10B981), fontFamily: 'Cairo'),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF10B981)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUpdating ? null : () => _markAsCompleted(invoice),
                    icon: _isUpdating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle, color: Colors.white),
                    label: Text(
                      _isUpdating ? 'جاري التأكيد...' : 'تأكيد الفاتورة',
                      style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
