import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
import '../shared/dispatch_details_screen.dart';

class BusinessOwnerStoreInvoicesScreen extends StatefulWidget {
  const BusinessOwnerStoreInvoicesScreen({super.key});

  @override
  State<BusinessOwnerStoreInvoicesScreen> createState() => _BusinessOwnerStoreInvoicesScreenState();
}

class _BusinessOwnerStoreInvoicesScreenState extends State<BusinessOwnerStoreInvoicesScreen>
    with TickerProviderStateMixin {
  final InvoiceCreationService _invoiceService = InvoiceCreationService();
  List<Invoice> _invoices = [];
  bool _isLoading = true;
  String? _error;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;

  // 3D Flip Animation Controllers
  final Map<String, AnimationController> _flipControllers = {};
  final Map<String, Animation<double>> _flipAnimations = {};
  final Set<String> _flippedCards = {};

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadInvoices();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    // Dispose all flip animation controllers
    for (final controller in _flipControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeController.forward();
    _slideController.forward();
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
      backgroundColor: AccountantThemeConfig.luxuryBlack,
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildCreateInvoiceFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AccountantThemeConfig.cardBackground1,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AccountantThemeConfig.cardShadows,
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.blueGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'فواتير المبيعات',
            style: GoogleFonts.cairo(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ).animate(controller: _fadeController).fadeIn(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      ).slideX(
        begin: -0.3,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      ),
      actions: [
        IconButton(
          onPressed: _loadInvoices,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.cardBackground1,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AccountantThemeConfig.cardShadows,
            ),
            child: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildBody() {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.mainBackgroundGradient,
      ),
      child: _buildContent(),
    ).animate(controller: _slideController).slideY(
      begin: 0.1,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_invoices.isEmpty) {
      return _buildEmptyState();
    }

    return _buildInvoicesList();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.cardBackground1,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AccountantThemeConfig.cardShadows,
            ),
            child: CircularProgressIndicator(
              color: AccountantThemeConfig.accentBlue,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'جاري تحميل الفواتير...',
            style: GoogleFonts.cairo(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AccountantThemeConfig.cardBackground1,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AccountantThemeConfig.cardShadows,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.red,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _error!,
              style: GoogleFonts.cairo(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadInvoices,
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.accentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'إعادة المحاولة',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AccountantThemeConfig.cardBackground1,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AccountantThemeConfig.cardShadows,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.blueGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: Colors.white,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'لا توجد فواتير محفوظة',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'سيتم عرض فواتير المبيعات المحفوظة هنا',
              style: GoogleFonts.cairo(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToCreateInvoice,
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.accentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'إنشاء فاتورة جديدة',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _invoices.length,
      itemBuilder: (context, index) {
        final invoice = _invoices[index];
        return _buildInvoiceCard(invoice, index);
      },
    );
  }

  Widget _buildInvoiceCard(Invoice invoice, int index) {
    final statusColor = _getStatusColor(invoice.status);
    final controller = _getFlipController(invoice.id);
    final animation = _flipAnimations[invoice.id]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 200,
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
              onLongPress: () => _navigateToDispatchDetails(invoice.id),
              child: Container(
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.cardGradient,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: statusColor.withOpacity(0.4),
                    width: 1.5,
                  ),
                  boxShadow: AccountantThemeConfig.glowShadows(statusColor),
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
    ).animate(delay: Duration(milliseconds: index * 100)).fadeIn(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    ).slideY(
      begin: 0.3,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  // Helper methods
  Color _getStatusColor(String status) {
    return AccountantThemeConfig.getStatusColor(status);
  }

  String _getStatusText(String status) {
    return AccountantThemeConfig.getStatusText(status);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'فاتورة #${invoice.id.substring(0, 8)}...',
                      style: AccountantThemeConfig.bodySmall,
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
                  style: AccountantThemeConfig.labelSmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
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
                    style: AccountantThemeConfig.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${invoice.totalAmount.toStringAsFixed(2)} جنيه',
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'تاريخ الإنشاء',
                    style: AccountantThemeConfig.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(invoice.createdAt),
                    style: AccountantThemeConfig.bodyMedium,
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
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: Colors.white.withOpacity(0.4),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.settings, color: statusColor, size: 18),
              const SizedBox(width: 6),
              Text(
                'خيارات التحكم',
                style: AccountantThemeConfig.labelLarge,
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _toggleInvoiceCardFlip(invoice.id),
                icon: const Icon(Icons.close, color: Colors.white70, size: 18),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.visibility_rounded,
                  label: 'عرض',
                  color: AccountantThemeConfig.accentBlue,
                  onPressed: () => _showInvoiceDetails(invoice),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.delete_rounded,
                  label: 'حذف',
                  color: AccountantThemeConfig.dangerRed,
                  onPressed: () => _deleteInvoice(invoice),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: AccountantThemeConfig.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showInvoiceDetails(Invoice invoice) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EnhancedInvoiceDetailsScreen(invoice: invoice),
        fullscreenDialog: true,
      ),
    );
  }



  Future<void> _deleteInvoice(Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardBackground1,
        title: Text(
          'تأكيد الحذف',
          style: AccountantThemeConfig.headlineSmall,
        ),
        content: Text(
          'هل أنت متأكد من حذف هذه الفاتورة؟\nلا يمكن التراجع عن هذا الإجراء.',
          style: AccountantThemeConfig.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'إلغاء',
              style: AccountantThemeConfig.labelMedium.copyWith(
                color: Colors.white70,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.dangerRed,
            ),
            child: Text(
              'حذف',
              style: AccountantThemeConfig.labelMedium,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await _invoiceService.deleteInvoice(invoice.id);
        if (!mounted) return;

        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم حذف الفاتورة بنجاح',
                style: AccountantThemeConfig.bodyMedium,
              ),
              backgroundColor: AccountantThemeConfig.successGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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
            content: Text(
              'فشل في حذف الفاتورة: $e',
              style: AccountantThemeConfig.bodyMedium,
            ),
            backgroundColor: AccountantThemeConfig.dangerRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  /// Navigate to create invoice screen
  void _navigateToCreateInvoice() {
    Navigator.of(context).pushNamed('/accountant/invoice/create').then((_) {
      // Reload invoices after creating a new one
      _loadInvoices();
    });
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
          style: AccountantThemeConfig.labelLarge,
        ),
      ),
    );
  }

  /// Navigate to dispatch details for the given invoice
  Future<void> _navigateToDispatchDetails(String invoiceId) async {
    try {
      AppLogger.info('🔍 البحث عن طلب الصرف للفاتورة: $invoiceId');

      // Search for dispatch request related to the invoice
      final dispatchProvider = Provider.of<WarehouseDispatchProvider>(context, listen: false);
      await dispatchProvider.loadRequests();

      // Find the request that contains the invoice ID in the reason
      final dispatch = dispatchProvider.requests.firstWhere(
        (request) => request.reason.contains(invoiceId),
        orElse: () => throw Exception('لم يتم العثور على طلب الصرف المرتبط بهذه الفاتورة'),
      );

      if (!mounted) return;

      // Navigate to dispatch details screen
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
            style: AccountantThemeConfig.bodyMedium,
          ),
          backgroundColor: AccountantThemeConfig.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}
