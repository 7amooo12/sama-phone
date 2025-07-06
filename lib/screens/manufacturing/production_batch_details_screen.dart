import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/widgets/common/custom_loader.dart';
import 'package:smartbiztracker_new/widgets/common/optimized_image.dart';
import 'package:smartbiztracker_new/models/manufacturing/production_batch.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/services/manufacturing/production_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// شاشة تفاصيل دفعة الإنتاج مع إمكانية تعديل الكمية
class ProductionBatchDetailsScreen extends StatefulWidget {
  final ProductionBatch batch;
  final ProductModel? product;

  const ProductionBatchDetailsScreen({
    super.key,
    required this.batch,
    this.product,
  });

  @override
  State<ProductionBatchDetailsScreen> createState() => _ProductionBatchDetailsScreenState();
}

class _ProductionBatchDetailsScreenState extends State<ProductionBatchDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  final ProductionService _productionService = ProductionService();
  final TextEditingController _quantityController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isCompletingBatch = false;
  double _originalQuantity = 0;
  ProductionBatch? _currentBatch;
  List<Map<String, dynamic>> _warehouseLocations = [];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));
    
    _animationController.forward();
  }

  void _initializeData() {
    _currentBatch = widget.batch;
    _originalQuantity = widget.batch.unitsProduced;
    _quantityController.text = _originalQuantity.toStringAsFixed(
      _originalQuantity.truncateToDouble() == _originalQuantity ? 0 : 2
    );
    _loadWarehouseLocations();
  }

  /// تحميل مواقع المنتج في المخازن
  Future<void> _loadWarehouseLocations() async {
    try {
      if (widget.product != null) {
        final locations = await _productionService.getProductWarehouseLocations(
          widget.product!.id.toString()
        );

        if (mounted) {
          setState(() {
            _warehouseLocations = locations;
          });
        }
      }
    } catch (e) {
      AppLogger.error('❌ Error loading warehouse locations: $e');
    }
  }

  /// Helper method to get properly formatted image URL
  String _getProductImageUrl(ProductModel product) {
    // Check main image URL first
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      final imageUrl = product.imageUrl!;
      if (imageUrl.startsWith('http')) {
        return imageUrl;
      } else {
        return 'https://samastock.pythonanywhere.com/static/uploads/$imageUrl';
      }
    }

    // Check additional images
    for (final image in product.images) {
      if (image.isNotEmpty) {
        final imageUrl = image.startsWith('http')
            ? image
            : 'https://samastock.pythonanywhere.com/static/uploads/$image';
        return imageUrl;
      }
    }

    // Return placeholder if no images found
    return 'https://via.placeholder.com/400x400/E0E0E0/757575?text=لا+توجد+صورة';
  }

  /// الحصول على لون الحالة
  Color get _statusColor {
    final currentBatch = _currentBatch ?? widget.batch;
    switch (currentBatch.status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// الحصول على أيقونة الحالة
  IconData get _statusIcon {
    final currentBatch = _currentBatch ?? widget.batch;
    switch (currentBatch.status) {
      case 'completed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.hourglass_empty;
      case 'pending':
        return Icons.schedule;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  /// تبديل وضع التعديل
  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        // إلغاء التعديل - استعادة القيمة الأصلية
        _quantityController.text = _originalQuantity.toStringAsFixed(
          _originalQuantity.truncateToDouble() == _originalQuantity ? 0 : 2
        );
      }
    });
    HapticFeedback.lightImpact();
  }

  /// حفظ التغييرات
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final newQuantity = double.tryParse(_quantityController.text);
    if (newQuantity == null) return;

    setState(() => _isLoading = true);

    try {
      // استدعاء خدمة تحديث كمية دفعة الإنتاج
      final result = await _productionService.updateProductionBatchQuantity(
        batchId: widget.batch.id,
        newQuantity: newQuantity,
        notes: 'تحديث الكمية من شاشة تفاصيل الدفعة',
      );

      if (result['success'] == true) {
        final quantityDifference = result['quantityDifference'] as double;

        // إذا تم زيادة الكمية، أضف المخزون إلى المخزن
        if (quantityDifference > 0 && widget.product != null) {
          await _productionService.addProductionInventoryToWarehouse(
            productId: widget.product!.id.toString(),
            quantity: quantityDifference.round(),
            batchId: widget.batch.id,
            notes: 'إضافة مخزون من زيادة الإنتاج - دفعة رقم ${widget.batch.id}',
          );
        }

        // تحديث البيانات المحلية
        _currentBatch = widget.batch.copyWith(unitsProduced: newQuantity);

        setState(() {
          _originalQuantity = newQuantity;
          _isEditing = false;
          _isLoading = false;
        });

        // إعادة تحميل مواقع المخازن
        await _loadWarehouseLocations();

        // عرض معلومات إضافية عن العملية
        final recipesFound = result['recipesFound'] ?? 0;
        final toolsUpdated = result['toolsUpdated'] ?? 0;

        String message = result['message'] ?? 'تم حفظ التغييرات بنجاح';
        if (recipesFound > 0) {
          message += '\n🔧 تم تحديث $toolsUpdated من أدوات التصنيع';
        } else if (quantityDifference > 0) {
          message += '\n⚠️ لم يتم العثور على وصفات إنتاج لهذا المنتج';
        }

        _showSuccessSnackBar(message);
        HapticFeedback.mediumImpact();

        AppLogger.info('✅ Updated production batch quantity: ${widget.batch.id} -> $newQuantity');
        AppLogger.info('📋 Recipes found: $recipesFound, Tools updated: $toolsUpdated');
      } else {
        throw Exception('فشل في تحديث كمية دفعة الإنتاج');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('فشل في حفظ التغييرات: $e');
      AppLogger.error('❌ Error updating production batch: $e');
    }
  }

  /// إظهار حوار تأكيد حذف دفعة الإنتاج
  Future<void> _showDeleteBatchDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AccountantThemeConfig.dangerRed,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'تأكيد الحذف',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: AccountantThemeConfig.dangerRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل أنت متأكد من حذف دفعة الإنتاج رقم ${widget.batch.id}؟',
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AccountantThemeConfig.dangerRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AccountantThemeConfig.dangerRed.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AccountantThemeConfig.dangerRed,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'سيتم حذف جميع البيانات المرتبطة:',
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            color: AccountantThemeConfig.dangerRed,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• سجلات استخدام الأدوات\n• بيانات دفعة الإنتاج\n• لا يمكن التراجع عن هذا الإجراء',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: AccountantThemeConfig.dangerRed,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'إلغاء',
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.dangerRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteProductionBatch();
    }
  }

  /// حذف دفعة الإنتاج
  Future<void> _deleteProductionBatch() async {
    try {
      setState(() => _isCompletingBatch = true);

      await _productionService.deleteProductionBatch(widget.batch.id);

      _showSuccessSnackBar('تم حذف دفعة الإنتاج بنجاح');

      // العودة إلى شاشة الإنتاج
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showErrorSnackBar('فشل في حذف دفعة الإنتاج: $e');
    } finally {
      setState(() => _isCompletingBatch = false);
    }
  }

  /// إكمال دفعة الإنتاج
  Future<void> _completeBatch() async {
    // عرض تأكيد الإكمال
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AccountantThemeConfig.primaryGreen,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'تأكيد إكمال الإنتاج',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: AccountantThemeConfig.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من إكمال دفعة الإنتاج رقم ${widget.batch.id}؟\n\nسيتم تغيير حالة الدفعة إلى "مكتمل" ولن يمكن التراجع عن هذا الإجراء.',
          style: AccountantThemeConfig.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'إلغاء',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: AccountantThemeConfig.primaryButtonStyle,
            child: Text(
              'إكمال',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCompletingBatch = true);

    try {
      final result = await _productionService.updateProductionBatchStatus(
        batchId: widget.batch.id,
        newStatus: 'completed',
        notes: 'إكمال دفعة الإنتاج من واجهة تفاصيل الدفعة',
      );

      if (result['success'] == true) {
        // تحديث البيانات المحلية
        _currentBatch = widget.batch.copyWith(
          status: 'completed',
          completionDate: DateTime.now(),
        );

        setState(() {
          _isCompletingBatch = false;
        });

        _showSuccessSnackBar('تم إكمال دفعة الإنتاج بنجاح');

        // العودة إلى الشاشة السابقة مع تحديث البيانات
        Navigator.of(context).pop(true);
      } else {
        throw Exception(result['message'] ?? 'فشل في إكمال دفعة الإنتاج');
      }
    } catch (e) {
      _showErrorSnackBar('فشل في إكمال دفعة الإنتاج: $e');
    } finally {
      setState(() => _isCompletingBatch = false);
    }
  }

  /// إظهار رسالة نجاح
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AccountantThemeConfig.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// إظهار رسالة خطأ
  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AccountantThemeConfig.dangerRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentBatch = _currentBatch ?? widget.batch;

    return Scaffold(
      backgroundColor: AccountantThemeConfig.backgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          _buildContent(),
        ],
      ),
      floatingActionButton: _buildActionButtons(currentBatch),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  /// بناء أزرار الإجراءات
  Widget? _buildActionButtons(ProductionBatch currentBatch) {
    // إذا كانت الدفعة يمكن إكمالها، أظهر زر الإكمال
    if (currentBatch.canComplete) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // زر حذف دفعة الإنتاج
          FloatingActionButton.extended(
            onPressed: _isCompletingBatch ? null : _showDeleteBatchDialog,
            backgroundColor: AccountantThemeConfig.dangerRed,
            foregroundColor: Colors.white,
            elevation: 8,
            heroTag: "delete_batch",
            icon: Icon(Icons.delete_outline, size: 24),
            label: Text(
              'حذف دفعة الإنتاج',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 100.ms).slideY(begin: 1, end: 0),

          const SizedBox(height: 12),

          // زر الإكمال
          FloatingActionButton.extended(
            onPressed: _isCompletingBatch ? null : _completeBatch,
            backgroundColor: _isCompletingBatch
                ? Colors.grey[400]
                : AccountantThemeConfig.primaryGreen,
            foregroundColor: Colors.white,
            elevation: 8,
            heroTag: "complete_batch",
            icon: _isCompletingBatch
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(Icons.check_circle, size: 24),
            label: Text(
              _isCompletingBatch ? 'جاري الإكمال...' : 'إكمال',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ).animate().fadeIn(duration: 600.ms).slideY(begin: 1, end: 0),
        ],
      );
    } else {
      // إذا كانت الدفعة مكتملة، أظهر زر الحذف فقط
      return FloatingActionButton.extended(
        onPressed: _showDeleteBatchDialog,
        backgroundColor: AccountantThemeConfig.dangerRed,
        foregroundColor: Colors.white,
        elevation: 8,
        heroTag: "delete_batch_only",
        icon: Icon(Icons.delete_outline, size: 24),
        label: Text(
          'حذف دفعة الإنتاج',
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ).animate().fadeIn(duration: 600.ms).slideY(begin: 1, end: 0);
    }
  }

  /// بناء SliverAppBar
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: FlexibleSpaceBar(
          centerTitle: true,
          background: widget.product != null
              ? SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      margin: const EdgeInsets.only(top: 60, left: 20, right: 20),
                      child: Row(
                        children: [
                          // صورة المنتج الكبيرة
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _statusColor.withOpacity(0.5),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _statusColor.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(17),
                              child: OptimizedImage(
                                imageUrl: _getProductImageUrl(widget.product!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          // معلومات المنتج
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  widget.product!.name,
                                  style: AccountantThemeConfig.headlineSmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _statusColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: _statusColor.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _statusIcon,
                                        color: _statusColor,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        (_currentBatch ?? widget.batch).statusText,
                                        style: AccountantThemeConfig.bodySmall.copyWith(
                                          color: _statusColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  /// بناء المحتوى الرئيسي
  Widget _buildContent() {
    return SliverToBoxAdapter(
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQuantityEditSection(),
                const SizedBox(height: 24),
                _buildProductionDetailsSection(),
                const SizedBox(height: 24),
                if (_warehouseLocations.isNotEmpty) ...[
                  _buildWarehouseLocationsSection(),
                  const SizedBox(height: 24),
                ],
                _buildBatchInfoSection(),
                const SizedBox(height: 100), // Space for floating action button
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// بناء قسم تعديل الكمية
  Widget _buildQuantityEditSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: AccountantThemeConfig.glowBorder(
          _isEditing ? AccountantThemeConfig.primaryGreen : Colors.white.withOpacity(0.3)
        ),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.inventory_2,
                color: AccountantThemeConfig.primaryGreen,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'الكمية المنتجة',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (!_isEditing)
                IconButton(
                  onPressed: _toggleEditMode,
                  icon: Icon(
                    Icons.edit,
                    color: AccountantThemeConfig.primaryGreen,
                  ),
                  tooltip: 'تعديل الكمية',
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isEditing) ...[
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textDirection: TextDirection.ltr,
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      labelText: 'الكمية الجديدة',
                      labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white70,
                      ),
                      suffixText: 'وحدة',
                      suffixStyle: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white54,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AccountantThemeConfig.primaryGreen),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى إدخال الكمية';
                      }
                      final quantity = double.tryParse(value);
                      if (quantity == null || quantity < 0) {
                        return 'يرجى إدخال كمية صحيحة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _saveChanges,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(_isLoading ? 'جاري الحفظ...' : 'حفظ'),
                          style: AccountantThemeConfig.primaryButtonStyle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _toggleEditMode,
                          icon: const Icon(Icons.cancel),
                          label: const Text('إلغاء'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: BorderSide(color: Colors.white.withOpacity(0.3)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.production_quantity_limits,
                    color: AccountantThemeConfig.primaryGreen,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الكمية الحالية',
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        '${_originalQuantity.toStringAsFixed(_originalQuantity.truncateToDouble() == _originalQuantity ? 0 : 2)} وحدة',
                        style: AccountantThemeConfig.headlineMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0);
  }

  /// بناء قسم تفاصيل الإنتاج
  Widget _buildProductionDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: AccountantThemeConfig.glowBorder(Colors.white.withOpacity(0.3)),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AccountantThemeConfig.accentBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'تفاصيل الإنتاج',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDetailRow('رقم الدفعة', '#${widget.batch.id}', Icons.tag),
          _buildDetailRow('معرف المنتج', '${widget.batch.productId}', Icons.inventory),
          if (widget.product != null) ...[
            _buildDetailRow('اسم المنتج', widget.product!.name, Icons.shopping_bag),
            _buildDetailRow('فئة المنتج', widget.product!.category, Icons.category),
          ],
          _buildDetailRow('الحالة', (_currentBatch ?? widget.batch).statusText, _statusIcon, statusColor: _statusColor),
          _buildDetailRow('تاريخ الإكمال', widget.batch.formattedCompletionDate, Icons.calendar_today),
          _buildDetailRow('وقت الإكمال', widget.batch.formattedCompletionTime, Icons.access_time),
          if (widget.batch.warehouseManagerName != null)
            _buildDetailRow('مدير المخزن', widget.batch.warehouseManagerName!, Icons.person),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms, delay: 200.ms).slideY(begin: 0.3, end: 0);
  }

  /// بناء قسم مواقع المخازن
  Widget _buildWarehouseLocationsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AccountantThemeConfig.primaryGreen.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warehouse,
                color: AccountantThemeConfig.primaryGreen,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'مواقع المنتج في المخازن',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ..._warehouseLocations.map((location) => _buildWarehouseLocationCard(location)),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms, delay: 300.ms).slideY(begin: 0.3, end: 0);
  }

  /// بناء بطاقة موقع المخزن
  Widget _buildWarehouseLocationCard(Map<String, dynamic> location) {
    final warehouseName = location['warehouse_name'] as String? ?? 'مخزن غير محدد';
    final quantity = location['quantity'] as int? ?? 0;
    final stockStatus = location['stock_status'] as String? ?? 'غير محدد';
    final warehouseAddress = location['warehouse_address'] as String? ?? '';

    Color statusColor;
    IconData statusIcon;

    switch (stockStatus) {
      case 'نفد المخزون':
        statusColor = Colors.red;
        statusIcon = Icons.warning;
        break;
      case 'مخزون منخفض':
        statusColor = Colors.orange;
        statusIcon = Icons.warning_amber;
        break;
      default:
        statusColor = AccountantThemeConfig.primaryGreen;
        statusIcon = Icons.check_circle;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.backgroundColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.store,
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  warehouseName,
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      statusIcon,
                      color: statusColor,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$quantity وحدة',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (warehouseAddress.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Colors.grey[400],
                  size: 16,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    warehouseAddress,
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.grey[400],
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                stockStatus,
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// بناء قسم معلومات الدفعة
  Widget _buildBatchInfoSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: AccountantThemeConfig.glowBorder(Colors.white.withOpacity(0.3)),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.note_alt_outlined,
                color: AccountantThemeConfig.warningOrange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'معلومات إضافية',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (widget.batch.notes != null && widget.batch.notes!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ملاحظات الدفعة',
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.batch.notes!,
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Text(
                'لا توجد ملاحظات لهذه الدفعة',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white54,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 1000.ms, delay: 400.ms).slideY(begin: 0.3, end: 0);
  }

  /// بناء صف التفاصيل
  Widget _buildDetailRow(String label, String value, IconData icon, {Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (statusColor ?? AccountantThemeConfig.primaryGreen).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: statusColor ?? AccountantThemeConfig.primaryGreen,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
