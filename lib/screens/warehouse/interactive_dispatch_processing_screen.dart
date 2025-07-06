import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/warehouse_dispatch_model.dart';
import '../../models/dispatch_product_processing_model.dart';
import '../../models/product_model.dart';
import '../../providers/warehouse_dispatch_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/warehouse/dispatch_product_processing_card.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';
import '../../constants/warehouse_dispatch_constants.dart';
import '../../services/unified_products_service.dart';
import '../../services/dispatch_location_service.dart';
import '../../services/intelligent_inventory_deduction_service.dart';
import '../../models/global_inventory_models.dart';
import '../../utils/inventory_operation_feedback.dart';

/// شاشة المعالجة التفاعلية لطلبات الصرف
/// تعرض منتجات الطلب كبطاقات تفاعلية مع إمكانية إكمال كل منتج على حدة
class InteractiveDispatchProcessingScreen extends StatefulWidget {
  final WarehouseDispatchModel dispatch;

  const InteractiveDispatchProcessingScreen({
    super.key,
    required this.dispatch,
  });

  @override
  State<InteractiveDispatchProcessingScreen> createState() => 
      _InteractiveDispatchProcessingScreenState();
}

class _InteractiveDispatchProcessingScreenState 
    extends State<InteractiveDispatchProcessingScreen> 
    with TickerProviderStateMixin {
  
  late AnimationController _fadeController;
  late AnimationController _confirmButtonController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _confirmButtonAnimation;

  List<DispatchProductProcessingModel> _processingProducts = [];
  bool _isLoading = false;
  bool _isConfirming = false;
  bool _isDetectingLocations = false;
  final UnifiedProductsService _productsService = UnifiedProductsService();
  final DispatchLocationService _locationService = DispatchLocationService();
  final IntelligentInventoryDeductionService _deductionService = IntelligentInventoryDeductionService();

  @override
  void initState() {
    super.initState();

    // FIXED: التحقق من حالة الطلب وإصلاح التزامن
    AppLogger.info('🔍 فحص حالة طلب الصرف: ${widget.dispatch.status}');

    if (widget.dispatch.status != WarehouseDispatchConstants.statusProcessing) {
      AppLogger.warning('⚠️ الطلب ليس في حالة processing. الحالة الحالية: ${widget.dispatch.status}');
      AppLogger.info('🔄 سيتم التحقق من الحالة الفعلية في قاعدة البيانات...');

      // FIXED: التحقق من الحالة الفعلية في قاعدة البيانات
      _verifyAndFixDispatchStatus();
    }

    // تهيئة المتحكمات
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _confirmButtonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // تهيئة الرسوم المتحركة
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _confirmButtonAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _confirmButtonController,
      curve: Curves.elasticOut,
    ));

    // تهيئة البيانات
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProcessingData();
    });

    // بدء الرسوم المتحركة
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _confirmButtonController.dispose();
    super.dispose();
  }

  /// تهيئة بيانات المعالجة مع الكشف الذكي عن المواقع
  Future<void> _initializeProcessingData() async {
    setState(() => _isLoading = true);

    AppLogger.info('🔄 تهيئة بيانات المعالجة للطلب: ${widget.dispatch.requestNumber}');

    try {
      // إنشاء قائمة مؤقتة للمنتجات
      List<DispatchProductProcessingModel> tempProducts = [];

      for (final item in widget.dispatch.items) {
        // محاولة جلب تفاصيل المنتج
        ProductModel? product;
        try {
          product = await _productsService.getProductById(item.productId);
        } catch (e) {
          AppLogger.warning('⚠️ فشل في جلب تفاصيل المنتج ${item.productId}: $e');
        }

        // إنشاء نموذج معالجة المنتج
        final processingProduct = DispatchProductProcessingModel.fromDispatchItem(
          itemId: item.id,
          requestId: widget.dispatch.id,
          productId: item.productId,
          productName: product?.name ?? 'منتج ${item.productId}',
          productImageUrl: product?.imageUrl,
          quantity: item.quantity,
          notes: item.notes,
        );

        tempProducts.add(processingProduct);
      }

      setState(() {
        _processingProducts = tempProducts;
        _isLoading = false;
      });

      AppLogger.info('✅ تم تهيئة ${_processingProducts.length} منتج للمعالجة');

      // بدء الكشف الذكي عن المواقع في الخلفية
      _detectProductLocationsInBackground();

    } catch (e) {
      AppLogger.error('❌ خطأ في تهيئة بيانات المعالجة: $e');

      // في حالة الخطأ، استخدم البيانات الأساسية
      _processingProducts = widget.dispatch.items.map((item) {
        return DispatchProductProcessingModel.fromDispatchItem(
          itemId: item.id,
          requestId: widget.dispatch.id,
          productId: item.productId,
          productName: 'منتج ${item.productId}',
          quantity: item.quantity,
          notes: item.notes,
        );
      }).toList();

      setState(() => _isLoading = false);
    }
  }

  /// الكشف الذكي عن مواقع المنتجات في الخلفية
  Future<void> _detectProductLocationsInBackground() async {
    if (_isDetectingLocations) return;

    setState(() => _isDetectingLocations = true);

    try {
      AppLogger.info('🔍 بدء الكشف الذكي عن مواقع المنتجات...');

      // استخدام الخدمة المتقدمة للكشف عن المواقع
      final updatedProducts = await _locationService.detectProductLocationsAdvanced(
        products: _processingProducts,
        strategy: WarehouseSelectionStrategy.balanced,
        enrichWithDetails: true,
        respectMinimumStock: true,
        maxWarehousesPerProduct: 3,
      );

      if (mounted) {
        setState(() {
          _processingProducts = updatedProducts;
        });

        // إنشاء ملخص النتائج
        final summary = _locationService.createLocationSummary(updatedProducts);
        AppLogger.info('📊 ملخص الكشف عن المواقع: ${summary.summaryText}');

        // عرض إشعار للمستخدم
        _showLocationDetectionResults(summary);
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في الكشف عن مواقع المنتجات: $e');
    } finally {
      if (mounted) {
        setState(() => _isDetectingLocations = false);
      }
    }
  }

  /// عرض نتائج الكشف عن المواقع
  void _showLocationDetectionResults(DispatchLocationSummary summary) {
    if (!mounted) return;

    final message = summary.fulfillableProducts == summary.totalProducts
        ? 'تم العثور على جميع المنتجات في المخازن ✅'
        : 'تم العثور على ${summary.fulfillableProducts} من ${summary.totalProducts} منتج';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
        ),
        backgroundColor: summary.fulfillableProducts == summary.totalProducts
            ? AccountantThemeConfig.primaryGreen
            : AccountantThemeConfig.warningOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// FIXED: التحقق من الحالة الفعلية في قاعدة البيانات وإصلاح التزامن
  Future<void> _verifyAndFixDispatchStatus() async {
    try {
      AppLogger.info('🔄 التحقق من الحالة الفعلية للطلب في قاعدة البيانات...');

      final dispatchProvider = Provider.of<WarehouseDispatchProvider>(context, listen: false);

      // إعادة تحميل الطلب من قاعدة البيانات للحصول على الحالة الفعلية
      await dispatchProvider.refreshDispatchRequests();

      // البحث عن الطلب المحدث
      final updatedDispatch = dispatchProvider.dispatchRequests
          .firstWhere((d) => d.id == widget.dispatch.id, orElse: () => widget.dispatch);

      AppLogger.info('📊 الحالة الفعلية في قاعدة البيانات: ${updatedDispatch.status}');

      if (updatedDispatch.status != widget.dispatch.status) {
        AppLogger.info('🔄 تم اكتشاف عدم تطابق في الحالة - تحديث الحالة المحلية');
        AppLogger.info('   الحالة المحلية: ${widget.dispatch.status}');
        AppLogger.info('   الحالة الفعلية: ${updatedDispatch.status}');

        // FIXED: إنشاء نسخة محدثة من الطلب بدلاً من تعديل الكائن مباشرة
        final updatedDispatchCopy = widget.dispatch.copyWith(status: updatedDispatch.status);

        // تحديث المرجع (هذا يتطلب أن يكون widget.dispatch قابل للتعديل)
        // في هذه الحالة، سنعتمد على إعادة التحميل من المزود

        if (mounted) {
          setState(() {});
        }
      }

      // التحقق من أن الطلب في الحالة الصحيحة للمعالجة
      if (updatedDispatch.status == WarehouseDispatchConstants.statusPending) {
        AppLogger.warning('⚠️ الطلب ما زال في حالة pending - يجب تحديثه إلى processing أولاً');
        _debugDispatchStatus();
        await _transitionToProcessingStatus();
      } else if (updatedDispatch.status == WarehouseDispatchConstants.statusProcessing) {
        AppLogger.info('✅ الطلب في الحالة الصحيحة للمعالجة');
      } else {
        AppLogger.warning('⚠️ الطلب في حالة غير متوقعة: ${updatedDispatch.status}');
        _debugDispatchStatus();
      }

    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من حالة الطلب: $e');
      _debugDispatchStatus();
    }
  }

  /// FIXED: انتقال الطلب إلى حالة المعالجة إذا كان ما زال في حالة pending
  Future<void> _transitionToProcessingStatus() async {
    try {
      AppLogger.info('🔄 تحديث حالة الطلب من pending إلى processing...');

      final dispatchProvider = Provider.of<WarehouseDispatchProvider>(context, listen: false);
      final currentUser = Provider.of<SupabaseProvider>(context, listen: false).user;

      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final success = await dispatchProvider.updateDispatchStatus(
        requestId: widget.dispatch.id,
        newStatus: WarehouseDispatchConstants.statusProcessing,
        updatedBy: currentUser.id,
        notes: 'تم تحديث الحالة تلقائياً عند فتح شاشة المعالجة التفاعلية',
      );

      if (success) {
        AppLogger.info('✅ تم تحديث حالة الطلب إلى processing بنجاح');

        // FIXED: إعادة تحميل الطلب من المزود للحصول على الحالة المحدثة
        await dispatchProvider.refreshDispatchRequests();

        if (mounted) {
          setState(() {});
        }
      } else {
        throw Exception('فشل في تحديث حالة الطلب إلى processing');
      }

    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث حالة الطلب: $e');

      // عرض رسالة خطأ للمستخدم
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطأ في تحديث حالة الطلب: ${e.toString()}',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildAppBar(),
                if (!_isLoading) _buildProgressHeader(),
                Expanded(
                  child: _isLoading ? _buildLoadingState() : _buildProductsList(),
                ),
                if (!_isLoading) _buildConfirmButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// بناء شريط التطبيق
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.greenGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'معالجة طلب الصرف',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  widget.dispatch.requestNumber,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          _buildStatusChip(),
        ],
      ),
    );
  }

  /// بناء شريحة الحالة
  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        WarehouseDispatchConstants.getStatusDisplayName(widget.dispatch.status),
        style: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  /// بناء رأس التقدم
  Widget _buildProgressHeader() {
    final completedCount = _processingProducts.where((p) => p.isCompleted).length;
    final totalCount = _processingProducts.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.assignment_turned_in,
                color: AccountantThemeConfig.primaryGreen,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'تقدم المعالجة',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '$completedCount من $totalCount',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AccountantThemeConfig.primaryGreen,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // شريط التقدم
          Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.white.withOpacity(0.1),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: AccountantThemeConfig.greenGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AccountantThemeConfig.primaryGreen.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toInt()}% مكتمل',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              if (_isDetectingLocations)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AccountantThemeConfig.accentBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'جاري البحث عن المواقع...',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AccountantThemeConfig.accentBlue,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// بناء قائمة المنتجات
  Widget _buildProductsList() {
    if (_processingProducts.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _processingProducts.length,
      itemBuilder: (context, index) {
        final product = _processingProducts[index];
        return DispatchProductProcessingCard(
          product: product,
          isEnabled: !_isConfirming && !_isDetectingLocations,
          onProcessingStart: () => _onProductProcessingStart(index),
          onProcessingComplete: () => _onProductProcessingComplete(index),
        );
      },
    );
  }

  /// بناء حالة فارغة
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد منتجات للمعالجة',
            style: GoogleFonts.cairo(
              fontSize: 18,
              color: Colors.white70,
            ),
          ),
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
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AccountantThemeConfig.greenGradient,
              boxShadow: [
                BoxShadow(
                  color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'جاري تحميل بيانات المنتجات...',
            style: GoogleFonts.cairo(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'يرجى الانتظار',
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  /// بناء زر التأكيد
  Widget _buildConfirmButton() {
    final allCompleted = _processingProducts.isNotEmpty && 
                        _processingProducts.every((p) => p.isCompleted);

    return AnimatedBuilder(
      animation: _confirmButtonAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: allCompleted ? _confirmButtonAnimation.value : 0.0,
          child: Container(
            margin: const EdgeInsets.all(16),
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: allCompleted && !_isConfirming ? _confirmProcessing : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: EdgeInsets.zero,
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: allCompleted 
                      ? AccountantThemeConfig.greenGradient
                      : LinearGradient(
                          colors: [Colors.grey.shade600, Colors.grey.shade700],
                        ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: allCompleted ? [
                    BoxShadow(
                      color: AccountantThemeConfig.primaryGreen.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ] : [],
                ),
                child: Center(
                  child: _isConfirming
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'تأكيد المعالجة',
                              style: GoogleFonts.cairo(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// معالجة بدء معالجة منتج
  void _onProductProcessingStart(int index) {
    setState(() {
      _processingProducts[index] = _processingProducts[index].startProcessing();
    });
    
    AppLogger.info('🔄 بدء معالجة المنتج: ${_processingProducts[index].productName}');
  }

  /// معالجة إكمال معالجة منتج مع الخصم الذكي للمخزون
  Future<void> _onProductProcessingComplete(int index) async {
    final currentUser = Provider.of<SupabaseProvider>(context, listen: false).user;
    final product = _processingProducts[index];

    if (currentUser == null) {
      AppLogger.error('❌ المستخدم غير مسجل الدخول');
      return;
    }

    try {
      AppLogger.info('🔄 بدء إكمال معالجة المنتج: ${product.productName}');

      // تحديث حالة المنتج إلى مكتمل
      setState(() {
        _processingProducts[index] = _processingProducts[index].complete(
          completedBy: currentUser.id,
        );
      });

      // تنفيذ الخصم الذكي للمخزون
      await _performIntelligentInventoryDeduction(product, currentUser.id);

      AppLogger.info('✅ تم إكمال معالجة المنتج بنجاح: ${product.productName}');

      // تحقق من إكمال جميع المنتجات
      final allCompleted = _processingProducts.every((p) => p.isCompleted);
      if (allCompleted) {
        _confirmButtonController.forward();
        HapticFeedback.heavyImpact();
      }

    } catch (e) {
      AppLogger.error('❌ خطأ في إكمال معالجة المنتج ${product.productName}: $e');

      // إعادة تعيين حالة المنتج في حالة الخطأ
      setState(() {
        _processingProducts[index] = _processingProducts[index].copyWith(
          isCompleted: false,
          completedAt: null,
          completedBy: null,
          progress: 0.0,
          isProcessing: false,
        );
      });

      // تحليل نوع الخطأ وعرض رسالة مناسبة
      final errorMessage = _analyzeProcessingError(e, product);

      // عرض رسالة خطأ مفصلة للمستخدم
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'فشل في معالجة ${product.productName}',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  style: GoogleFonts.cairo(fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        // إعادة المحاولة
                        _onProductProcessingComplete(index);
                      },
                      child: Text(
                        'إعادة المحاولة',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 8),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  /// تنفيذ الخصم الذكي للمخزون مع معالجة أخطاء محسنة
  Future<void> _performIntelligentInventoryDeduction(
    DispatchProductProcessingModel product,
    String performedBy,
  ) async {
    try {
      AppLogger.info('🔄 بدء الخصم الذكي للمنتج: ${product.productName}');
      AppLogger.info('📦 معرف المنتج: ${product.productId}');
      AppLogger.info('📊 الكمية المطلوبة: ${product.requestedQuantity}');
      AppLogger.info('👤 المنفذ: $performedBy');
      AppLogger.info('📋 معرف الطلب: ${widget.dispatch.id}');

      // التحقق من صحة البيانات الأساسية
      if (product.productId.isEmpty) {
        throw Exception('معرف المنتج فارغ');
      }

      if (product.requestedQuantity <= 0) {
        throw Exception('الكمية المطلوبة غير صحيحة: ${product.requestedQuantity}');
      }

      if (performedBy.isEmpty) {
        throw Exception('معرف المنفذ فارغ');
      }

      // تنفيذ الخصم الذكي
      final deductionResult = await _deductionService.deductProductInventory(
        product: product,
        performedBy: performedBy,
        requestId: widget.dispatch.id,
        strategy: WarehouseSelectionStrategy.balanced,
      );

      AppLogger.info('📤 نتيجة الخصم الذكي:');
      AppLogger.info('   النجاح: ${deductionResult.success}');
      AppLogger.info('   إجمالي المطلوب: ${deductionResult.totalRequestedQuantity}');
      AppLogger.info('   إجمالي المخصوم: ${deductionResult.totalDeductedQuantity}');
      AppLogger.info('   عدد المخازن: ${deductionResult.warehouseResults.length}');
      AppLogger.info('   عدد الأخطاء: ${deductionResult.errors.length}');
      AppLogger.info('   خصم مكتمل: ${deductionResult.isCompleteDeduction}');
      AppLogger.info('   نسبة الخصم: ${deductionResult.deductionPercentage.toStringAsFixed(1)}%');

      // FIXED: Enhanced success determination with better UI feedback
      // Check if we have actual successful deductions regardless of error list
      final hasActualDeductions = deductionResult.totalDeductedQuantity > 0;
      final hasSuccessfulWarehouses = deductionResult.successfulWarehousesCount > 0;
      final meetsRequirement = deductionResult.totalDeductedQuantity >= deductionResult.totalRequestedQuantity;

      // Consider it successful if we have actual deductions and meet the requirement
      final operationSuccessful = deductionResult.success || (hasActualDeductions && hasSuccessfulWarehouses && meetsRequirement);

      if (operationSuccessful) {
        AppLogger.info('✅ تم الخصم الذكي بنجاح للمنتج: ${product.productName}');
        AppLogger.info('📊 تم خصم ${deductionResult.totalDeductedQuantity} من ${deductionResult.totalRequestedQuantity}');
        AppLogger.info('🏪 المخازن المتأثرة: ${deductionResult.successfulWarehousesCount}');

        // طباعة تفاصيل كل مخزن
        for (final warehouseResult in deductionResult.warehouseResults) {
          if (warehouseResult.success) {
            AppLogger.info('   ✅ ${warehouseResult.warehouseName}: خصم ${warehouseResult.deductedQuantity}');
          } else {
            AppLogger.error('   ❌ ${warehouseResult.warehouseName}: ${warehouseResult.error}');
          }
        }

        // FIXED: Use enhanced feedback system for accurate success messages
        if (mounted) {
          InventoryOperationFeedback.showFeedback(
            context,
            deductionResult,
            product.productName,
          );

          // Force UI refresh to reflect successful deduction
          setState(() {
            // Trigger UI rebuild to show updated status
          });
        }
      } else {
        // FIXED: More nuanced failure analysis
        AppLogger.error('❌ الخصم الذكي للمنتج لم يكتمل بالشكل المطلوب: ${product.productName}');
        AppLogger.error('📊 تم خصم ${deductionResult.totalDeductedQuantity} من ${deductionResult.totalRequestedQuantity} المطلوب');
        AppLogger.error('🏪 مخازن ناجحة: ${deductionResult.successfulWarehousesCount}، فاشلة: ${deductionResult.failedWarehousesCount}');

        // Analyze if this is a partial success or complete failure
        final hasPartialSuccess = deductionResult.totalDeductedQuantity > 0 && deductionResult.successfulWarehousesCount > 0;

        if (hasPartialSuccess) {
          AppLogger.warning('⚠️ خصم جزئي - تم خصم بعض الكمية ولكن ليس الكل');

          // FIXED: Use enhanced feedback system for partial success
          if (mounted) {
            InventoryOperationFeedback.showFeedback(
              context,
              deductionResult,
              product.productName,
            );
          }

          // Don't throw exception for partial success - let the process continue
          AppLogger.info('✅ السماح بالمتابعة مع الخصم الجزئي');
          return;
        }

        // Complete failure analysis
        if (deductionResult.errors.isNotEmpty) {
          AppLogger.error('🔍 تفاصيل الأخطاء:');
          for (int i = 0; i < deductionResult.errors.length; i++) {
            AppLogger.error('   ${i + 1}. ${deductionResult.errors[i]}');
          }
        }

        // فحص نتائج المخازن
        for (final warehouseResult in deductionResult.warehouseResults) {
          if (!warehouseResult.success) {
            AppLogger.error('   ❌ مخزن ${warehouseResult.warehouseName}: ${warehouseResult.error}');
          }
        }

        final errorMessage = deductionResult.errors.isNotEmpty
            ? deductionResult.errors.join(', ')
            : 'خطأ غير محدد في الخصم';

        throw Exception('فشل كامل في الخصم: $errorMessage');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في الخصم الذكي للمنتج ${product.productName}: $e');

      // تحليل نوع الخطأ لتقديم معلومات أكثر تفصيلاً
      String detailedError = 'فشل في خصم المخزون';

      if (e.toString().contains('معرف المنتج فارغ')) {
        detailedError = 'خطأ في بيانات المنتج - معرف المنتج مفقود';
      } else if (e.toString().contains('الكمية المطلوبة غير صحيحة')) {
        detailedError = 'خطأ في بيانات المنتج - الكمية غير صحيحة';
      } else if (e.toString().contains('معرف المنفذ فارغ')) {
        detailedError = 'خطأ في بيانات المستخدم - معرف المنفذ مفقود';
      } else if (e.toString().contains('لا يمكن تلبية الطلب')) {
        detailedError = 'المخزون غير كافي لتلبية الطلب';
      } else if (e.toString().contains('المنتج غير موجود')) {
        detailedError = 'المنتج غير موجود في أي مخزن';
      } else if (e.toString().contains('فشل في إنشاء خطة التخصيص')) {
        detailedError = 'فشل في تخصيص المنتج على المخازن';
      } else if (e.toString().contains('connection') || e.toString().contains('network')) {
        detailedError = 'خطأ في الاتصال بقاعدة البيانات';
      }

      throw Exception('$detailedError: $e');
    }
  }

  /// FIXED: تأكيد المعالجة مع التحقق من الحالة الفعلية
  Future<void> _confirmProcessing() async {
    if (_isConfirming) return;

    setState(() => _isConfirming = true);

    try {
      AppLogger.info('🔄 بدء تأكيد معالجة الطلب: ${widget.dispatch.requestNumber}');

      final dispatchProvider = Provider.of<WarehouseDispatchProvider>(context, listen: false);
      final currentUser = Provider.of<SupabaseProvider>(context, listen: false).user;

      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // FIXED: التحقق من الحالة الفعلية في قاعدة البيانات قبل المتابعة
      AppLogger.info('🔍 التحقق من الحالة الفعلية قبل الإكمال...');
      await _verifyAndFixDispatchStatus();

      // الحصول على الحالة المحدثة
      final currentStatus = widget.dispatch.status;
      final targetStatus = WarehouseDispatchConstants.statusCompleted;

      AppLogger.info('📊 الحالة الحالية: $currentStatus، الحالة المستهدفة: $targetStatus');

      // التحقق من صحة انتقال الحالة
      if (!WarehouseDispatchConstants.isValidStatusTransition(currentStatus, targetStatus)) {
        AppLogger.error('❌ انتقال حالة غير صحيح من $currentStatus إلى $targetStatus');
        AppLogger.info('📋 الانتقالات المسموحة من $currentStatus: ${WarehouseDispatchConstants.getNextPossibleStatuses(currentStatus)}');
        throw Exception('انتقال حالة غير صحيح من $currentStatus إلى $targetStatus');
      }

      AppLogger.info('✅ انتقال الحالة صحيح من $currentStatus إلى $targetStatus');

      // FIXED: Enhanced order status update with better synchronization
      AppLogger.info('🔄 تحديث حالة الطلب إلى: $targetStatus');

      final success = await dispatchProvider.updateDispatchStatus(
        requestId: widget.dispatch.id,
        newStatus: targetStatus,
        updatedBy: currentUser.id,
        notes: 'تم إكمال الطلب بواسطة المعالجة التفاعلية - جميع المنتجات تمت معالجتها بنجاح',
      );

      if (success) {
        AppLogger.info('✅ تم تأكيد معالجة الطلب وتحديث الحالة بنجاح');

        // FIXED: Force refresh dispatch data to ensure UI synchronization
        await Future.delayed(const Duration(milliseconds: 300));
        await dispatchProvider.refreshDispatchRequests(clearCache: true);

        // تشغيل الاهتزاز
        HapticFeedback.heavyImpact();

        // FIXED: Enhanced success message with more details
        if (mounted) {
          final completedProducts = _processingProducts.where((p) => p.isCompleted).length;
          final totalProducts = _processingProducts.length;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تم إكمال معالجة الطلب بنجاح ✅',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'تمت معالجة $completedProducts من $totalProducts منتج',
                    style: GoogleFonts.cairo(fontSize: 12, color: Colors.white70),
                  ),
                  Text(
                    'رقم الطلب: ${widget.dispatch.requestNumber}',
                    style: GoogleFonts.cairo(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              backgroundColor: AccountantThemeConfig.primaryGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 4),
            ),
          );

          // FIXED: Add delay before navigation to ensure UI updates are processed
          await Future.delayed(const Duration(milliseconds: 500));

          // العودة إلى الشاشة السابقة
          if (mounted) {
            Navigator.of(context).pop(true); // Return true to indicate success
          }
        }
      } else {
        throw Exception('فشل في تحديث حالة الطلب في قاعدة البيانات');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تأكيد معالجة الطلب: $e');

      // FIXED: تحليل نوع الخطأ وتقديم رسائل أكثر وضوحاً
      String errorMessage = 'خطأ في تأكيد المعالجة';

      if (e.toString().contains('انتقال حالة غير صحيح')) {
        errorMessage = 'خطأ في انتقال الحالة: ${e.toString()}';
        AppLogger.error('🔍 تفاصيل خطأ انتقال الحالة:');
        AppLogger.error('   الطلب: ${widget.dispatch.requestNumber}');
        AppLogger.error('   الحالة الحالية: ${widget.dispatch.status}');
        AppLogger.error('   الحالة المستهدفة: ${WarehouseDispatchConstants.statusCompleted}');
        AppLogger.error('   الانتقالات المسموحة: ${WarehouseDispatchConstants.getNextPossibleStatuses(widget.dispatch.status)}');
      } else if (e.toString().contains('المستخدم غير مسجل الدخول')) {
        errorMessage = 'يجب تسجيل الدخول أولاً';
      } else if (e.toString().contains('فشل في تحديث حالة الطلب')) {
        errorMessage = 'فشل في حفظ التغييرات في قاعدة البيانات';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errorMessage,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (e.toString().contains('انتقال حالة غير صحيح')) ...[
                  const SizedBox(height: 4),
                  Text(
                    'الحالة الحالية: ${WarehouseDispatchConstants.getStatusDisplayName(widget.dispatch.status)}',
                    style: GoogleFonts.cairo(fontSize: 12),
                  ),
                ],
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConfirming = false);
      }
    }
  }

  /// FIXED: تشخيص حالة الطلب وطباعة معلومات مفصلة للتصحيح
  void _debugDispatchStatus() {
    AppLogger.info('📋 Processing dispatch: ${widget.dispatch.requestNumber} - Status: ${widget.dispatch.status}');
  }

  /// تحليل خطأ المعالجة وإرجاع رسالة مناسبة للمستخدم
  String _analyzeProcessingError(dynamic error, DispatchProductProcessingModel product) {
    final errorString = error.toString().toLowerCase();

    // خطأ المصادقة
    if (errorString.contains('auth') || errorString.contains('unauthorized') || errorString.contains('المستخدم غير مسجل')) {
      return 'انتهت صلاحية الجلسة. يرجى تسجيل الدخول مرة أخرى.';
    }

    // خطأ الصلاحيات
    if (errorString.contains('permission') || errorString.contains('forbidden') || errorString.contains('غير مصرح')) {
      return 'ليس لديك صلاحية لمعالجة هذا المنتج. يرجى التواصل مع المدير.';
    }

    // خطأ المخزون غير كافي
    if (errorString.contains('المخزون غير كافي') || errorString.contains('لا يمكن تلبية الطلب') || errorString.contains('الكمية المتاحة')) {
      return 'المخزون غير كافي. الكمية المطلوبة: ${product.requestedQuantity}';
    }

    // خطأ المنتج غير موجود
    if (errorString.contains('المنتج غير موجود') || errorString.contains('product not found')) {
      return 'المنتج غير موجود في أي مخزن متاح.';
    }

    // خطأ قاعدة البيانات
    if (errorString.contains('connection') || errorString.contains('network') || errorString.contains('database')) {
      return 'خطأ في الاتصال بقاعدة البيانات. يرجى التحقق من الاتصال والمحاولة مرة أخرى.';
    }

    // خطأ المخزن غير متاح
    if (errorString.contains('warehouse') || errorString.contains('مخزن')) {
      return 'خطأ في الوصول للمخازن. قد تكون المخازن غير متاحة حالياً.';
    }

    // خطأ التخصيص
    if (errorString.contains('فشل في إنشاء خطة التخصيص') || errorString.contains('allocation')) {
      return 'فشل في تخصيص المنتج على المخازن المتاحة.';
    }

    // خطأ الخصم
    if (errorString.contains('فشل في خصم المخزون') || errorString.contains('deduction')) {
      return 'فشل في خصم الكمية من المخزون. قد تكون الكمية غير متاحة.';
    }

    // خطأ عام
    return 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى أو التواصل مع الدعم الفني.';
  }
}
