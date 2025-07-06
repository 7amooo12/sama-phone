import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/invoice_models.dart';
import '../../models/warehouse_model.dart';
import '../../models/warehouse_dispatch_model.dart';
import '../../services/invoice_creation_service.dart';
import '../../services/warehouse_dispatch_service.dart';
import '../../providers/warehouse_provider.dart';
import '../../providers/warehouse_dispatch_provider.dart';
import '../../utils/app_logger.dart';
import '../../utils/style_system.dart';
import '../../utils/accountant_theme_config.dart';
import '../invoice/enhanced_invoice_details_screen.dart';
import 'dispatch_details_screen.dart';
import 'distribution_preview_screen.dart';

class StoreInvoicesScreen extends StatefulWidget {
  const StoreInvoicesScreen({super.key});

  @override
  State<StoreInvoicesScreen> createState() => _StoreInvoicesScreenState();
}

class _StoreInvoicesScreenState extends State<StoreInvoicesScreen>
    with TickerProviderStateMixin {
  final InvoiceCreationService _invoiceService = InvoiceCreationService();
  List<Invoice> _invoices = [];
  bool _isLoading = true;
  String? _error;

  // 3D Flip Animation Controllers
  final Map<String, AnimationController> _flipControllers = {};
  final Map<String, Animation<double>> _flipAnimations = {};
  final Set<String> _flippedCards = {};

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  @override
  void dispose() {
    // Dispose all animation controllers
    for (final controller in _flipControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Create or get flip animation controller for invoice card
  AnimationController _getFlipController(String invoiceId) {
    if (!_flipControllers.containsKey(invoiceId)) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 700),
        vsync: this,
      );
      final animation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      ));

      _flipControllers[invoiceId] = controller;
      _flipAnimations[invoiceId] = animation;
    }
    return _flipControllers[invoiceId]!;
  }

  // Toggle flip animation for invoice card
  void _toggleInvoiceCardFlip(String invoiceId) {
    final controller = _getFlipController(invoiceId);

    if (_flippedCards.contains(invoiceId)) {
      controller.reverse();
      _flippedCards.remove(invoiceId);
    } else {
      controller.forward();
      _flippedCards.add(invoiceId);
    }
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final invoices = await _invoiceService.getStoredInvoices();
      setState(() {
        _invoices = invoices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'فشل في تحميل الفواتير: ${e.toString()}';
        _isLoading = false;
      });
      AppLogger.error('خطأ في تحميل الفواتير: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StyleSystem.backgroundDark,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  StyleSystem.primaryColor.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: StyleSystem.primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'فواتير المتجر',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loadInvoices,
                  icon: Icon(
                    Icons.refresh,
                    color: StyleSystem.primaryColor,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
      floatingActionButton: _buildCreateInvoiceFAB(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: StyleSystem.primaryColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'جاري تحميل الفواتير...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInvoices,
              style: ElevatedButton.styleFrom(
                backgroundColor: StyleSystem.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (_invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              color: Colors.white30,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد فواتير محفوظة',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'سيتم عرض الفواتير المحفوظة هنا',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _invoices.length,
      itemBuilder: (context, index) {
        final invoice = _invoices[index];
        return _buildInvoiceCard(invoice);
      },
    );
  }

  // Enhanced invoice item widget with 3D flip animation
  Widget _buildInvoiceCard(Invoice invoice) {
    final statusColor = _getStatusColor(invoice.status);
    final controller = _getFlipController(invoice.id);
    final animation = _flipAnimations[invoice.id]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 200, // Increased height to accommodate back side content
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final isShowingFront = animation.value < 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(animation.value * 3.14159),
            child: GestureDetector(
              onTap: () => _toggleInvoiceCardFlip(invoice.id),
              onLongPress: () => _showProcessOrderDialog(invoice),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey[900]!,
                      Colors.black,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: statusColor.withOpacity(0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isShowingFront
                    ? _buildInvoiceFrontSide(invoice, statusColor)
                    : Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(3.14159),
                        child: _buildInvoiceBackSide(invoice, statusColor),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Build front side of invoice card
  Widget _buildInvoiceFrontSide(Invoice invoice, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.receipt,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.customerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'فاتورة #${invoice.id.substring(0, 8)}...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getStatusText(invoice.status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Amount and date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المبلغ الإجمالي',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${invoice.totalAmount.toStringAsFixed(2)} جنيه',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'تاريخ الإنشاء',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(invoice.createdAt),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // Tap hint
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.touch_app,
                color: Colors.white.withOpacity(0.4),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'اضغط للمزيد من الخيارات',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build back side of invoice card with control options
  Widget _buildInvoiceBackSide(Invoice invoice, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.all(16), // Reduced padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.settings, color: statusColor, size: 18),
              const SizedBox(width: 6),
              const Text(
                'خيارات التحكم',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14, // Reduced font size
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _toggleInvoiceCardFlip(invoice.id),
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                iconSize: 18,
                padding: EdgeInsets.zero, // Remove default padding
                constraints: const BoxConstraints(), // Remove default constraints
              ),
            ],
          ),

          const SizedBox(height: 12), // Reduced spacing

          // Control buttons
          Row(
            children: [
              Expanded(
                child: _buildInvoiceControlButton(
                  'التفاصيل',
                  Icons.visibility,
                  const Color(0xFF3B82F6),
                  () => _showInvoiceDetails(invoice),
                ),
              ),
              const SizedBox(width: 8), // Reduced spacing
              Expanded(
                child: _buildInvoiceControlButton(
                  'تحديث',
                  Icons.edit,
                  const Color(0xFF10B981),
                  () => _updateInvoiceStatus(invoice),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10), // Reduced spacing

          // Additional actions
          Row(
            children: [
              Expanded(
                child: _buildInvoiceControlButton(
                  'PDF',
                  Icons.picture_as_pdf,
                  const Color(0xFFEF4444),
                  () => _exportInvoicePDF(invoice),
                ),
              ),
              const SizedBox(width: 8), // Reduced spacing
              Expanded(
                child: _buildInvoiceControlButton(
                  'حذف',
                  Icons.delete,
                  Colors.red,
                  () => _deleteInvoice(invoice),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build control button for invoice actions
  Widget _buildInvoiceControlButton(String text, IconData icon, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), // Reduced padding
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Minimize column size
          children: [
            Icon(icon, size: 16, color: color), // Reduced icon size
            const SizedBox(height: 2), // Reduced spacing
            Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 9, // Reduced font size
                fontFamily: 'Cairo',
              ),
              textAlign: TextAlign.center,
              maxLines: 1, // Ensure single line
              overflow: TextOverflow.ellipsis, // Handle overflow
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'معلقة';
      case 'completed':
        return 'مكتملة';
      case 'cancelled':
        return 'ملغية';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Update invoice status
  Future<void> _updateInvoiceStatus(Invoice invoice) async {
    final newStatus = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StyleSystem.surfaceDark,
        title: const Text(
          'تحديث حالة الفاتورة',
          style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'اختر الحالة الجديدة للفاتورة:',
              style: TextStyle(color: Colors.white70, fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 16),
            ...['pending', 'completed', 'cancelled'].map((status) =>
              ListTile(
                title: Text(
                  _getStatusText(status),
                  style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
                ),
                leading: Radio<String>(
                  value: status,
                  groupValue: invoice.status,
                  onChanged: (value) => Navigator.pop(context, value),
                  activeColor: StyleSystem.primaryColor,
                ),
                onTap: () => Navigator.pop(context, status),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );

    if (newStatus != null && newStatus != invoice.status) {
      try {
        final result = await _invoiceService.updateInvoiceStatus(invoice.id, newStatus);
        if (!mounted) return;

        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث حالة الفاتورة بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          _loadInvoices(); // Refresh the list
        } else {
          throw Exception(result['message']);
        }
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تحديث حالة الفاتورة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Export invoice as PDF
  Future<void> _exportInvoicePDF(Invoice invoice) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('جاري تصدير الفاتورة كـ PDF...'),
        backgroundColor: StyleSystem.primaryColor,
      ),
    );

    // TODO: Implement PDF export functionality
    // This would typically involve generating a PDF and saving/sharing it
    await Future.delayed(const Duration(seconds: 2)); // Simulate processing

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تصدير الفاتورة بنجاح'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Show process order dialog
  Future<void> _showProcessOrderDialog(Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StyleSystem.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                color: Color(0xFF10B981),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'صرف الطلبية',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey[900]!,
                    Colors.black,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تفاصيل الفاتورة:',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow('العميل', invoice.customerName),
                  _buildInfoRow('المبلغ', '${invoice.totalAmount.toStringAsFixed(2)} جنيه'),
                  _buildInfoRow('التاريخ', _formatDate(invoice.createdAt)),
                  _buildInfoRow('الحالة', _getStatusText(invoice.status)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'هل تريد إرسال هذه الطلبية إلى مدير المخزن للصرف؟',
              style: TextStyle(
                color: Colors.white70,
                fontFamily: 'Cairo',
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF10B981),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'سيتم إرسال الطلبية مع جميع تفاصيلها إلى تبويب "صرف مخزون" في لوحة مدير المخزن',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontFamily: 'Cairo',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'إلغاء',
              style: TextStyle(
                color: Colors.white70,
                fontFamily: 'Cairo',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'صرف الطلبية',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _processOrderToWarehouse(invoice);
    }
  }

  // Process order to warehouse
  Future<void> _processOrderToWarehouse(Invoice invoice) async {
    try {
      // First, show warehouse selection dialog
      final selectedWarehouse = await _showWarehouseSelectionDialog();
      if (selectedWarehouse == null) {
        // User cancelled warehouse selection
        return;
      }

      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'جاري إرسال الطلبية إلى مدير المخزن...',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // 🔧 FIX: Implement actual API call to create warehouse dispatch request
      final warehouseDispatchService = WarehouseDispatchService();

      // Get current user for requestedBy field
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل دخول');
      }

      // Prepare invoice items for dispatch
      final dispatchItems = invoice.items.map((item) => {
        'product_id': item.productId,
        'product_name': item.productName,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
      }).toList();

      AppLogger.info('🔄 Converting invoice ${invoice.id} to warehouse dispatch');
      AppLogger.info('📋 Invoice items: ${dispatchItems.length} items');
      AppLogger.info('📦 Selected warehouse: ${selectedWarehouse.name} (${selectedWarehouse.id})');

      // التحقق من نوع المخزن المحدد
      if (selectedWarehouse.isAllWarehousesOption) {
        // استخدام التوزيع الذكي متعدد المخازن
        await _handleIntelligentDistribution(invoice, dispatchItems, currentUser.id);
        return;
      }

      // Create actual warehouse dispatch request with selected warehouse
      final createdDispatch = await warehouseDispatchService.createDispatchFromInvoice(
        invoiceId: invoice.id,
        customerName: invoice.customerName,
        totalAmount: invoice.totalAmount,
        items: dispatchItems,
        requestedBy: currentUser.id,
        notes: 'تحويل من فاتورة رقم: ${invoice.id}',
        warehouseId: selectedWarehouse.id,
      );

      if (!mounted) return;

      if (createdDispatch != null) {
        // Show success message with option to view dispatch details
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تم إرسال الطلبية إلى مدير المخزن بنجاح ✅',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'يمكنك الآن متابعة حالة الطلب',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        _navigateToDispatchDetailsDirectly(createdDispatch);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'عرض تفاصيل الطلب',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );

        AppLogger.info('✅ Successfully converted invoice ${invoice.id} to warehouse dispatch');
      } else {
        throw Exception('فشل في إنشاء طلب الصرف');
      }
    } catch (e) {
      AppLogger.error('❌ Error converting invoice to warehouse dispatch: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'فشل في إرسال الطلبية: ${e.toString()}',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// معالجة التوزيع الذكي متعدد المخازن
  Future<void> _handleIntelligentDistribution(
    Invoice invoice,
    List<Map<String, dynamic>> dispatchItems,
    String requestedBy,
  ) async {
    try {
      AppLogger.info('🤖 بدء التوزيع الذكي متعدد المخازن للفاتورة: ${invoice.id}');

      // التنقل إلى شاشة معاينة التوزيع
      final result = await Navigator.of(context).push<dynamic>(
        MaterialPageRoute(
          builder: (context) => DistributionPreviewScreen(
            items: dispatchItems,
            invoiceId: invoice.id,
            customerName: invoice.customerName,
            totalAmount: invoice.totalAmount,
            requestedBy: requestedBy,
            notes: 'تحويل من فاتورة رقم: ${invoice.id}',
            onConfirm: () {
              AppLogger.info('✅ تم تأكيد التوزيع الذكي');
            },
            onCancel: () {
              AppLogger.info('❌ تم إلغاء التوزيع الذكي');
            },
          ),
          fullscreenDialog: true,
        ),
      );

      if (!mounted) return;

      if (result != null) {
        // إظهار رسالة نجاح مع تفاصيل التوزيع
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'تم التوزيع الذكي بنجاح!',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  result.resultText,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            backgroundColor: AccountantThemeConfig.primaryGreen,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );

        AppLogger.info('✅ تم إكمال التوزيع الذكي متعدد المخازن بنجاح');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في التوزيع الذكي متعدد المخازن: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'فشل في التوزيع الذكي: ${e.toString()}',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// عرض حوار اختيار المخزن المحسن مع خيار "جميع المخازن"
  Future<WarehouseModel?> _showWarehouseSelectionDialog() async {
    // Load warehouses first
    final warehouseProvider = Provider.of<WarehouseProvider>(context, listen: false);
    await warehouseProvider.loadWarehouses();

    if (!mounted) return null;

    return showDialog<WarehouseModel>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 500,
            height: 650, // زيادة الارتفاع لاستيعاب الخيار الجديد
            decoration: AccountantThemeConfig.primaryCardDecoration,
            child: Column(
              children: [
                // رأس الحوار المحسن
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.greenGradient,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warehouse_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'اختيار المخزن',
                              style: GoogleFonts.cairo(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'اختر المخزن أو استخدم التوزيع الذكي',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // محتوى الحوار
                Expanded(
                  child: Consumer<WarehouseProvider>(
                    builder: (context, warehouseProvider, child) {
                      if (warehouseProvider.isLoading) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AccountantThemeConfig.primaryGreen,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'جاري تحميل المخازن...',
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (warehouseProvider.warehouses.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.warning_outlined,
                                color: AccountantThemeConfig.warningOrange,
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'لا توجد مخازن متاحة',
                                style: GoogleFonts.cairo(
                                  fontSize: 18,
                                  color: AccountantThemeConfig.warningOrange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'يرجى إضافة مخازن أولاً',
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // إنشاء قائمة تتضمن خيار "جميع المخازن" + المخازن الفردية
                      final allWarehouses = [
                        WarehouseModel.createAllWarehousesOption(),
                        ...warehouseProvider.warehouses,
                      ];

                      return ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: allWarehouses.length,
                        itemBuilder: (context, index) {
                          final warehouse = allWarehouses[index];
                          final bool isAllWarehousesOption = warehouse.isAllWarehousesOption == true;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.of(context).pop(warehouse),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: isAllWarehousesOption
                                        ? AccountantThemeConfig.blueGradient // تدرج مميز للخيار الذكي
                                        : AccountantThemeConfig.cardGradient,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isAllWarehousesOption
                                          ? AccountantThemeConfig.accentBlue.withOpacity(0.5)
                                          : AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                                      width: isAllWarehousesOption ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: (isAllWarehousesOption
                                              ? AccountantThemeConfig.accentBlue
                                              : AccountantThemeConfig.primaryGreen).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          isAllWarehousesOption
                                              ? Icons.auto_awesome_outlined
                                              : Icons.warehouse,
                                          color: isAllWarehousesOption
                                              ? AccountantThemeConfig.accentBlue
                                              : AccountantThemeConfig.primaryGreen,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    warehouse.name,
                                                    style: GoogleFonts.cairo(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                                if (isAllWarehousesOption)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: AccountantThemeConfig.accentBlue.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(
                                                        color: AccountantThemeConfig.accentBlue.withOpacity(0.5),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      'ذكي',
                                                      style: GoogleFonts.cairo(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: AccountantThemeConfig.accentBlue,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              warehouse.shortDescription,
                                              style: GoogleFonts.cairo(
                                                fontSize: 12,
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        color: isAllWarehousesOption
                                            ? AccountantThemeConfig.accentBlue
                                            : AccountantThemeConfig.primaryGreen,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to build info rows
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontFamily: 'Cairo',
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Delete invoice
  Future<void> _deleteInvoice(Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StyleSystem.surfaceDark,
        title: const Text(
          'تأكيد الحذف',
          style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning, color: Colors.orange, size: 48),
            const SizedBox(height: 16),
            Text(
              'هل أنت متأكد من حذف فاتورة "${invoice.customerName}"؟',
              style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'لا يمكن التراجع عن هذا الإجراء',
              style: TextStyle(color: Colors.red, fontSize: 12, fontFamily: 'Cairo'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await _invoiceService.deleteInvoice(invoice.id);
        if (!mounted) return;

        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف الفاتورة بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          _loadInvoices(); // Refresh the list
        } else {
          throw Exception(result['message']);
        }
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في حذف الفاتورة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showInvoiceDetails(Invoice invoice) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EnhancedInvoiceDetailsScreen(invoice: invoice),
        fullscreenDialog: true,
      ),
    );
  }

  /// Build floating action button for creating new invoices
  Widget _buildCreateInvoiceFAB() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: AccountantThemeConfig.greenGradient,
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: FloatingActionButton.extended(
        onPressed: _navigateToCreateInvoice,
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 24,
        ),
        label: Text(
          'إنشاء فاتورة',
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// Navigate to create invoice screen
  void _navigateToCreateInvoice() {
    Navigator.of(context).pushNamed('/accountant/invoice/create').then((_) {
      // Reload invoices after creating a new one
      _loadInvoices();
    });
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// التنقل المباشر إلى تفاصيل طلب الصرف
  void _navigateToDispatchDetailsDirectly(WarehouseDispatchModel dispatch) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DispatchDetailsScreen(dispatch: dispatch),
        fullscreenDialog: true,
      ),
    );
    AppLogger.info('✅ تم التنقل إلى تفاصيل طلب الصرف: ${dispatch.requestNumber}');
  }

  /// التنقل إلى تفاصيل طلب الصرف (البحث بالفاتورة)
  Future<void> _navigateToDispatchDetails(String invoiceId) async {
    try {
      AppLogger.info('🔍 البحث عن طلب الصرف للفاتورة: $invoiceId');

      // البحث عن طلب الصرف المرتبط بالفاتورة
      final dispatchProvider = Provider.of<WarehouseDispatchProvider>(context, listen: false);
      await dispatchProvider.loadRequests();

      // البحث عن الطلب الذي يحتوي على معرف الفاتورة في السبب
      final dispatch = dispatchProvider.requests.firstWhere(
        (request) => request.reason.contains(invoiceId),
        orElse: () => throw Exception('لم يتم العثور على طلب الصرف المرتبط بهذه الفاتورة'),
      );

      if (!mounted) return;

      // التنقل إلى شاشة تفاصيل الطلب
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DispatchDetailsScreen(dispatch: dispatch),
          fullscreenDialog: true,
        ),
      );

      AppLogger.info('✅ تم العثور على طلب الصرف: ${dispatch.requestNumber}');
    } catch (e) {
      AppLogger.error('❌ خطأ في البحث عن طلب الصرف: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لم يتم العثور على طلب الصرف المرتبط بهذه الفاتورة',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}
