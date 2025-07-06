import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/invoice_models.dart';
import '../../utils/style_system.dart';
import '../../utils/app_logger.dart';
import '../../utils/accountant_theme_config.dart';
import '../../services/supabase_storage_service.dart';
import '../../services/invoice_pdf_service.dart';
import '../../services/whatsapp_service.dart';

class EnhancedInvoiceDetailsScreen extends StatefulWidget {

  const EnhancedInvoiceDetailsScreen({
    super.key,
    required this.invoice,
  });
  final Invoice invoice;

  @override
  State<EnhancedInvoiceDetailsScreen> createState() => _EnhancedInvoiceDetailsScreenState();
}

class _EnhancedInvoiceDetailsScreenState extends State<EnhancedInvoiceDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final SupabaseStorageService _storageService = SupabaseStorageService();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    AppLogger.info('📋 Opening enhanced invoice details for: ${widget.invoice.id}');
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.luxuryBlack,
      body: Container(
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInvoiceHeader(),
                        const SizedBox(height: 24),
                        _buildCustomerInfo(),
                        const SizedBox(height: 24),
                        _buildItemsSection(),
                        const SizedBox(height: 24),
                        _buildTotalsSection(),
                        if (widget.invoice.notes != null && widget.invoice.notes!.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildNotesSection(),
                        ],
                        const SizedBox(height: 100), // Bottom padding for FAB
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AccountantThemeConfig.cardBackground1,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'فاتورة #${widget.invoice.id.substring(0, 8)}',
          style: AccountantThemeConfig.headlineSmall,
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.blueGradient,
          ),
          child: Center(
            child: Icon(
              Icons.receipt_long_rounded,
              color: Colors.white.withOpacity(0.3),
              size: 64,
            ),
          ),
        ),
      ),
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AccountantThemeConfig.cardBackground1.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: _shareInvoice,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.cardBackground1.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.share_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        IconButton(
          onPressed: _printInvoice,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.cardBackground1.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.print_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildInvoiceHeader() {
    final statusColor = _getStatusColor(widget.invoice.status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: AccountantThemeConfig.glowShadows(statusColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'رقم الفاتورة',
                    style: AccountantThemeConfig.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '#${widget.invoice.id}',
                    style: AccountantThemeConfig.headlineSmall.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  _getStatusText(widget.invoice.status),
                  style: AccountantThemeConfig.labelMedium.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                color: AccountantThemeConfig.accentBlue,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'تاريخ الإنشاء: ${_formatDate(widget.invoice.createdAt)}',
                style: AccountantThemeConfig.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AccountantThemeConfig.accentBlue.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.blueGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'معلومات العميل',
                style: AccountantThemeConfig.headlineSmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('اسم العميل', widget.invoice.customerName),
          if (widget.invoice.customerPhone != null)
            _buildInfoRow('رقم الهاتف', widget.invoice.customerPhone!),
          if (widget.invoice.customerEmail != null)
            _buildInfoRow('البريد الإلكتروني', widget.invoice.customerEmail!),
          if (widget.invoice.customerAddress != null)
            _buildInfoRow('العنوان', widget.invoice.customerAddress!),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.greenGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shopping_cart_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'عناصر الفاتورة',
                style: AccountantThemeConfig.headlineSmall,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AccountantThemeConfig.primaryGreen),
                ),
                child: Text(
                  '${widget.invoice.items.length} عنصر',
                  style: AccountantThemeConfig.labelSmall.copyWith(
                    color: AccountantThemeConfig.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...widget.invoice.items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildInvoiceItem(item, index);
          }),
        ],
      ),
    );
  }

  Widget _buildInvoiceItem(InvoiceItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardBackground1.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Product Image
          _buildProductImage(item),
          const SizedBox(width: 16),
          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildItemDetail('الكمية', '${item.quantity}'),
                    const SizedBox(width: 16),
                    _buildItemDetail('السعر', '${item.unitPrice.toStringAsFixed(2)} جنيه'),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'الإجمالي: ${item.subtotal.toStringAsFixed(2)} جنيه',
                    style: AccountantThemeConfig.labelMedium.copyWith(
                      color: AccountantThemeConfig.primaryGreen,
                      fontWeight: FontWeight.bold,
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

  Widget _buildProductImage(InvoiceItem item) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: FutureBuilder<String?>(
          future: _getProductImageUrl(item.productId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                color: Colors.grey.shade800,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: StyleSystem.primaryColor,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              );
            }

            if (snapshot.hasData && snapshot.data != null) {
              AppLogger.info('🖼️ Displaying image for URL: ${snapshot.data}');
              return Image.network(
                snapshot.data!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: AccountantThemeConfig.cardBackground1,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AccountantThemeConfig.accentBlue,
                          strokeWidth: 2,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  AppLogger.error('❌ Error loading image: $error for URL: ${snapshot.data}');
                  return _buildFallbackImage();
                },
                headers: const {
                  'Cache-Control': 'no-cache',
                },
              );
            }

            return _buildFallbackImage();
          },
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      color: AccountantThemeConfig.cardBackground1,
      child: Center(
        child: Icon(
          Icons.image_not_supported_rounded,
          color: AccountantThemeConfig.neutralColor,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildItemDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTotalsSection() {
    return AnimationConfiguration.staggeredList(
      position: 3,
      duration: const Duration(milliseconds: 600),
      child: SlideAnimation(
        verticalOffset: 30,
        child: FadeInAnimation(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  StyleSystem.primaryColor.withOpacity(0.1),
                  Colors.grey.shade900,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: StyleSystem.primaryColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calculate,
                      color: StyleSystem.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'ملخص الفاتورة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildTotalRow('المجموع الفرعي', widget.invoice.subtotal, false),
                if (widget.invoice.discount > 0) ...[
                  const SizedBox(height: 12),
                  _buildTotalRow('الخصم', widget.invoice.discount, false, isDiscount: true),
                ],
                if (widget.invoice.taxAmount > 0) ...[
                  const SizedBox(height: 12),
                  _buildTotalRow('الضريبة', widget.invoice.taxAmount, false),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: StyleSystem.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: StyleSystem.primaryColor),
                  ),
                  child: _buildTotalRow('الإجمالي النهائي', widget.invoice.totalAmount, true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, bool isTotal, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? StyleSystem.primaryColor : Colors.white,
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Text(
          '${isDiscount ? '-' : ''}${amount.toStringAsFixed(2)} ج.م',
          style: TextStyle(
            color: isDiscount
                ? Colors.red
                : isTotal
                    ? StyleSystem.primaryColor
                    : Colors.white,
            fontSize: isTotal ? 18 : 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return AnimationConfiguration.staggeredList(
      position: 4,
      duration: const Duration(milliseconds: 600),
      child: SlideAnimation(
        verticalOffset: 30,
        child: FadeInAnimation(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade700,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.note,
                      color: StyleSystem.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'ملاحظات',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade800,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    widget.invoice.notes ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _shareInvoice,
      backgroundColor: StyleSystem.primaryColor,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.share),
      label: const Text('مشاركة الفاتورة'),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Utility Methods
  Future<String?> _getProductImageUrl(String productId) async {
    try {
      AppLogger.info('🖼️ Loading image for product: $productId');
      final imageUrl = await _storageService.getProductImageUrl(productId);

      if (imageUrl != null && imageUrl.isNotEmpty && imageUrl != 'null') {
        AppLogger.info('✅ Raw image URL from database: $imageUrl');

        // Convert filename to external URL using the same pattern as working screens
        String finalUrl;
        if (imageUrl.startsWith('http')) {
          // Already a complete URL
          finalUrl = imageUrl;
        } else {
          // Convert filename to external URL
          finalUrl = 'https://samastock.pythonanywhere.com/static/uploads/$imageUrl';
        }

        AppLogger.info('🔗 Final image URL: $finalUrl');
        return finalUrl;
      } else {
        AppLogger.warning('⚠️ No image found for product: $productId');
        return null;
      }
    } catch (e) {
      AppLogger.error('❌ Error loading image for product $productId: $e');
      return null;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
      case 'pending':
        return Colors.orange;
      case 'sent':
      case 'confirmed':
        return Colors.blue;
      case 'paid':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'overdue':
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return 'مسودة';
      case 'pending':
        return 'معلقة';
      case 'sent':
        return 'مرسلة';
      case 'confirmed':
        return 'مؤكدة';
      case 'paid':
        return 'مدفوعة';
      case 'completed':
        return 'مكتملة';
      case 'cancelled':
        return 'ملغية';
      case 'overdue':
        return 'متأخرة';
      default:
        return status;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _shareInvoice() async {
    AppLogger.info('📤 Sharing invoice: ${widget.invoice.id}');

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Show sharing options dialog
      Navigator.of(context).pop(); // Close loading

      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: const Text(
            'مشاركة الفاتورة',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.text_fields, color: Colors.green),
                title: const Text('مشاركة كنص', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(context).pop('text'),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text('مشاركة PDF', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(context).pop('pdf'),
              ),
              ListTile(
                leading: const Icon(Icons.chat, color: Colors.green),
                title: const Text('مشاركة عبر واتساب', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(context).pop('whatsapp'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      );

      if (result != null) {
        await _handleShareOption(result);
      }
    } catch (e) {
      AppLogger.error('❌ Error sharing invoice: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في مشاركة الفاتورة: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleShareOption(String option) async {
    try {
      switch (option) {
        case 'text':
          await _shareAsText();
          break;
        case 'pdf':
          await _shareAsPdf();
          break;
        case 'whatsapp':
          await _shareViaWhatsApp();
          break;
      }
    } catch (e) {
      AppLogger.error('❌ Error in share option $option: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في المشاركة: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _shareAsText() async {
    final invoiceText = _generateInvoiceText();
    await Share.share(
      invoiceText,
      subject: 'فاتورة رقم ${widget.invoice.id}',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم فتح نافذة المشاركة'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareAsPdf() async {
    final pdfService = InvoicePdfService();
    final pdfBytes = await pdfService.generateInvoicePdf(widget.invoice);

    // Save to temporary directory
    final tempDir = await getTemporaryDirectory();
    final fileName = 'invoice_${widget.invoice.id}.pdf';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'فاتورة رقم ${widget.invoice.id}',
      text: 'فاتورة PDF مرفقة',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إنشاء ومشاركة PDF'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareViaWhatsApp() async {
    final whatsappService = WhatsAppService();
    final success = await whatsappService.shareInvoiceViaWhatsApp(
      invoice: widget.invoice,
      phoneNumber: widget.invoice.customerPhone,
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم فتح واتساب للمشاركة'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل في فتح واتساب'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _generateInvoiceText() {
    final buffer = StringBuffer();
    buffer.writeln('🧾 فاتورة من سمارت بيزنس تراكر');
    buffer.writeln('');
    buffer.writeln('📋 رقم الفاتورة: ${widget.invoice.id}');
    buffer.writeln('👤 العميل: ${widget.invoice.customerName}');
    buffer.writeln('📅 التاريخ: ${_formatDate(widget.invoice.createdAt)}');

    if (widget.invoice.customerPhone?.isNotEmpty == true) {
      buffer.writeln('📞 الهاتف: ${widget.invoice.customerPhone}');
    }

    buffer.writeln('');
    buffer.writeln('📦 العناصر:');

    for (final item in widget.invoice.items) {
      final itemTotal = item.quantity * item.unitPrice;
      buffer.writeln('• ${item.productName} x${item.quantity} = ${itemTotal.toStringAsFixed(2)} جنيه');
    }

    buffer.writeln('');
    buffer.writeln('💰 المجموع الفرعي: ${widget.invoice.subtotal.toStringAsFixed(2)} جنيه');

    if (widget.invoice.discount > 0) {
      buffer.writeln('🏷️ الخصم: ${widget.invoice.discount.toStringAsFixed(2)} جنيه');
    }

    buffer.writeln('💳 الإجمالي: ${widget.invoice.totalAmount.toStringAsFixed(2)} جنيه');

    if (widget.invoice.notes?.isNotEmpty == true) {
      buffer.writeln('');
      buffer.writeln('📝 ملاحظات: ${widget.invoice.notes}');
    }

    buffer.writeln('');
    buffer.writeln('شكراً لتعاملكم معنا! 🙏');

    return buffer.toString();
  }

  Future<void> _printInvoice() async {
    AppLogger.info('🖨️ Printing invoice: ${widget.invoice.id}');

    try {
      // Generate PDF and share for printing
      await _shareAsPdf();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء PDF للطباعة'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      AppLogger.error('❌ Error printing invoice: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في الطباعة: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
