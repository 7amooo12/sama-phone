/// شاشة معاينة التوزيع الذكي متعدد المخازن
/// Distribution Preview Screen for Multi-Warehouse Intelligent Distribution

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/models/multi_warehouse_dispatch_models.dart';
import 'package:smartbiztracker_new/models/global_inventory_models.dart';
import 'package:smartbiztracker_new/services/intelligent_multi_warehouse_dispatch_service.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

class DistributionPreviewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final String invoiceId;
  final String customerName;
  final double totalAmount;
  final String requestedBy;
  final String? notes;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const DistributionPreviewScreen({
    super.key,
    required this.items,
    required this.invoiceId,
    required this.customerName,
    required this.totalAmount,
    required this.requestedBy,
    this.notes,
    this.onConfirm,
    this.onCancel,
  });

  @override
  State<DistributionPreviewScreen> createState() => _DistributionPreviewScreenState();
}

class _DistributionPreviewScreenState extends State<DistributionPreviewScreen> {
  final IntelligentMultiWarehouseDispatchService _distributionService = IntelligentMultiWarehouseDispatchService();
  
  DistributionPreview? _preview;
  bool _isLoading = true;
  String? _error;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _loadDistributionPreview();
  }

  /// تحميل معاينة التوزيع
  Future<void> _loadDistributionPreview() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      AppLogger.info('🔍 تحميل معاينة التوزيع للفاتورة: ${widget.invoiceId}');

      final preview = await _distributionService.createDistributionPreview(
        items: widget.items,
        strategy: WarehouseSelectionStrategy.balanced,
      );

      if (mounted) {
        setState(() {
          _preview = preview;
          _isLoading = false;
        });
      }

      AppLogger.info('✅ تم تحميل معاينة التوزيع بنجاح');
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل معاينة التوزيع: $e');

      if (mounted) {
        setState(() {
          _error = _getLocalizedErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  /// تأكيد التوزيع وإنشاء طلبات الصرف
  Future<void> _confirmDistribution() async {
    if (_preview == null || !_preview!.canProceed) return;

    try {
      setState(() {
        _isConfirming = true;
      });

      AppLogger.info('✅ تأكيد التوزيع الذكي للفاتورة: ${widget.invoiceId}');

      final result = await _distributionService.createIntelligentDispatchFromInvoice(
        invoiceId: widget.invoiceId,
        customerName: widget.customerName,
        totalAmount: widget.totalAmount,
        items: widget.items,
        requestedBy: widget.requestedBy,
        notes: widget.notes,
        strategy: WarehouseSelectionStrategy.balanced,
      );

      if (mounted) {
        if (result.success) {
          // إظهار رسالة نجاح
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم إنشاء ${result.totalDispatchesCreated} طلب صرف بنجاح',
                style: GoogleFonts.cairo(color: Colors.white),
              ),
              backgroundColor: AccountantThemeConfig.primaryGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );

          // العودة مع النتيجة
          Navigator.of(context).pop(result);
          widget.onConfirm?.call();
        } else {
          // إظهار رسالة خطأ
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'فشل في التوزيع: ${result.errors.join(', ')}',
                style: GoogleFonts.cairo(color: Colors.white),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تأكيد التوزيع: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطأ في تأكيد التوزيع: $e',
              style: GoogleFonts.cairo(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConfirming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.luxuryBlack,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildContent(),
          ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  /// بناء رأس الشاشة
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.blueGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onCancel?.call();
                },
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'معاينة التوزيع الذكي',
                      style: GoogleFonts.cairo(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'فاتورة: ${widget.customerName}',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.3, end: 0);
  }

  /// بناء محتوى الشاشة
  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_preview == null) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(),
          const SizedBox(height: 24),
          _buildWarehousesList(),
          const SizedBox(height: 24),
          if (_preview!.unfulfillableProducts > 0) _buildWarningCard(),
        ],
      ),
    );
  }

  /// بناء حالة التحميل
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AccountantThemeConfig.accentBlue),
          ),
          const SizedBox(height: 24),
          Text(
            'جاري تحليل التوزيع الذكي...',
            style: GoogleFonts.cairo(
              fontSize: 18,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'يتم البحث في جميع المخازن المتاحة',
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  /// بناء حالة الخطأ
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 64,
          ),
          const SizedBox(height: 24),
          Text(
            'خطأ في تحليل التوزيع',
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadDistributionPreview,
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.accentBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'إعادة المحاولة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  /// بناء حالة فارغة
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: Colors.white30,
            size: 64,
          ),
          const SizedBox(height: 24),
          Text(
            'لا توجد بيانات للعرض',
            style: GoogleFonts.cairo(
              fontSize: 18,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  /// بناء بطاقة الملخص
  Widget _buildSummaryCard() {
    if (_preview == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.analytics_outlined,
                  color: AccountantThemeConfig.accentBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'ملخص التوزيع',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'إجمالي المنتجات',
                  '${_preview!.totalProducts}',
                  Icons.inventory_2_outlined,
                  AccountantThemeConfig.accentBlue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryItem(
                  'المخازن المشاركة',
                  '${_preview!.warehousesCount}',
                  Icons.warehouse_outlined,
                  AccountantThemeConfig.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'قابل للتلبية',
                  '${_preview!.fulfillableProducts}',
                  Icons.check_circle_outline,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryItem(
                  'غير متوفر',
                  '${_preview!.unfulfillableProducts}',
                  Icons.error_outline,
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _preview!.canProceed
                  ? AccountantThemeConfig.primaryGreen.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _preview!.canProceed
                    ? AccountantThemeConfig.primaryGreen.withOpacity(0.3)
                    : Colors.red.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _preview!.canProceed ? Icons.check_circle : Icons.warning,
                  color: _preview!.canProceed
                      ? AccountantThemeConfig.primaryGreen
                      : Colors.red,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _preview!.canProceed
                        ? 'يمكن المتابعة مع التوزيع الذكي'
                        : 'لا يمكن المتابعة - منتجات غير متوفرة',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _preview!.canProceed
                          ? AccountantThemeConfig.primaryGreen
                          : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideX(begin: -0.3, end: 0);
  }

  /// بناء عنصر ملخص
  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// بناء قائمة المخازن
  Widget _buildWarehousesList() {
    if (_preview == null || _preview!.warehouseSummaries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'توزيع المخازن',
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(
          _preview!.warehouseSummaries.length,
          (index) => _buildWarehouseCard(_preview!.warehouseSummaries[index], index),
        ),
      ],
    );
  }

  /// بناء بطاقة مخزن
  Widget _buildWarehouseCard(WarehouseDistributionSummary warehouse, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.warehouse,
                  color: AccountantThemeConfig.primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  warehouse.warehouseName,
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: warehouse.canFulfillCompletely
                      ? Colors.green.withOpacity(0.2)
                      : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: warehouse.canFulfillCompletely
                        ? Colors.green.withOpacity(0.5)
                        : Colors.orange.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  warehouse.canFulfillCompletely ? 'مكتمل' : 'جزئي',
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: warehouse.canFulfillCompletely ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildWarehouseInfo(
                  'عدد المنتجات',
                  '${warehouse.productCount}',
                  Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildWarehouseInfo(
                  'إجمالي الكمية',
                  '${warehouse.totalQuantity}',
                  Icons.numbers_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: 200 * index))
        .fadeIn(duration: 600.ms)
        .slideX(begin: 0.3, end: 0);
  }

  /// بناء معلومات المخزن
  Widget _buildWarehouseInfo(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AccountantThemeConfig.accentBlue, size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// بناء بطاقة التحذير
  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 24),
              const SizedBox(width: 12),
              Text(
                'تحذير - منتجات غير متوفرة',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'يوجد ${_preview!.unfulfillableProducts} منتج غير متوفر في أي مخزن. '
            'لن يتم تضمين هذه المنتجات في طلبات الصرف.',
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.3, end: 0);
  }

  /// بناء أزرار الإجراءات
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardBackground1,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onCancel?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'إلغاء',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: (_preview?.canProceed == true && !_isConfirming)
                  ? _confirmDistribution
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isConfirming
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'جاري التنفيذ...',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'تأكيد التوزيع',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 1000.ms).slideY(begin: 1, end: 0);
  }

  /// الحصول على رسالة خطأ محلية
  String _getLocalizedErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // خطأ قاعدة البيانات
    if (errorString.contains('connection') || errorString.contains('network')) {
      return 'خطأ في الاتصال. يرجى التحقق من الإنترنت والمحاولة مرة أخرى.';
    }

    // خطأ المصادقة
    if (errorString.contains('auth') || errorString.contains('unauthorized')) {
      return 'انتهت صلاحية الجلسة. يرجى تسجيل الدخول مرة أخرى.';
    }

    // خطأ المخزون
    if (errorString.contains('stock') || errorString.contains('inventory')) {
      return 'لا توجد منتجات متوفرة في أي مخزن للتوزيع.';
    }

    // خطأ المنتجات
    if (errorString.contains('product') || errorString.contains('item')) {
      return 'خطأ في بيانات المنتجات. يرجى التحقق من الفاتورة.';
    }

    // خطأ المخازن
    if (errorString.contains('warehouse')) {
      return 'لا توجد مخازن متاحة للتوزيع. يرجى التواصل مع المدير.';
    }

    // خطأ التوزيع
    if (errorString.contains('distribution') || errorString.contains('allocation')) {
      return 'فشل في تحليل التوزيع. قد تكون الكميات المطلوبة كبيرة جداً.';
    }

    // خطأ عام
    return 'حدث خطأ في تحليل التوزيع. يرجى المحاولة مرة أخرى.';
  }

  /// التحقق من صحة البيانات
  bool _validateInputData() {
    if (widget.items.isEmpty) {
      _showErrorMessage('لا توجد منتجات للتوزيع');
      return false;
    }

    if (widget.customerName.isEmpty) {
      _showErrorMessage('اسم العميل مطلوب');
      return false;
    }

    if (widget.totalAmount <= 0) {
      _showErrorMessage('مبلغ الفاتورة غير صحيح');
      return false;
    }

    return true;
  }

  /// إظهار رسالة خطأ
  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.cairo(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  /// إظهار رسالة نجاح
  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.cairo(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: AccountantThemeConfig.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
}
