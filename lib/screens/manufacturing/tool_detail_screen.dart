import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/widgets/common/custom_loader.dart';
import 'package:smartbiztracker_new/models/manufacturing/manufacturing_tool.dart';
import 'package:smartbiztracker_new/models/manufacturing/production_batch.dart';
import 'package:smartbiztracker_new/models/manufacturing/tool_deletion_info.dart';
import 'package:smartbiztracker_new/services/manufacturing/manufacturing_tools_service.dart';
import 'package:smartbiztracker_new/services/manufacturing/production_service.dart';
import 'package:smartbiztracker_new/widgets/manufacturing/tool_deletion_dialog.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// شاشة تفاصيل أداة التصنيع مع إدارة المخزون وتاريخ الاستخدام
class ToolDetailScreen extends StatefulWidget {
  final ManufacturingTool tool;

  const ToolDetailScreen({
    super.key,
    required this.tool,
  });

  @override
  State<ToolDetailScreen> createState() => _ToolDetailScreenState();
}

class _ToolDetailScreenState extends State<ToolDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ManufacturingToolsService _toolsService = ManufacturingToolsService();
  final ProductionService _productionService = ProductionService();
  
  ManufacturingTool? _currentTool;
  List<ToolUsageHistory> _usageHistory = [];
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _isLoadingData = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentTool = widget.tool;
    _loadToolDetails();
    _loadUsageHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// تحميل تفاصيل الأداة المحدثة
  Future<void> _loadToolDetails() async {
    if (!mounted || _isLoadingData) return; // Early exit if widget is disposed or already loading

    try {
      if (mounted) {
        setState(() => _isLoadingData = true);
      }

      final tool = await _toolsService.getToolById(widget.tool.id);
      if (tool != null && mounted) {
        setState(() {
          _currentTool = tool;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      AppLogger.error('❌ Error loading tool details: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  /// تحميل تاريخ الاستخدام
  Future<void> _loadUsageHistory() async {
    if (!mounted) return; // Early exit if widget is disposed

    try {
      final history = await _productionService.getToolUsageHistory(
        toolId: widget.tool.id,
        limit: 100,
      );
      if (mounted) {
        setState(() => _usageHistory = history);
      }
    } catch (e) {
      AppLogger.error('❌ Error loading usage history: $e');
    }
  }

  /// إظهار حوار تعديل الكمية
  Future<void> _showEditQuantityDialog() async {
    final TextEditingController quantityController = TextEditingController(
      text: _currentTool!.quantity.toString(),
    );
    final TextEditingController notesController = TextEditingController();

    Map<String, dynamic>? result;

    try {
      result = await showDialog<Map<String, dynamic>?>(
        context: context,
        barrierDismissible: false, // Prevent accidental dismissal
        builder: (context) => AlertDialog(
          backgroundColor: AccountantThemeConfig.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'تعديل الكمية',
            style: AccountantThemeConfig.headlineSmall.copyWith(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: quantityController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'الكمية الجديدة',
                  labelStyle: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AccountantThemeConfig.primaryGreen),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'ملاحظات (اختيارية)',
                  labelStyle: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AccountantThemeConfig.primaryGreen),
                  ),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(
                'إلغاء',
                style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final newQuantity = double.tryParse(quantityController.text);
                if (newQuantity != null && newQuantity >= 0) {
                  // Return the values instead of calling async operation in dialog
                  Navigator.pop(context, {
                    'quantity': newQuantity,
                    'notes': notesController.text,
                  });
                }
              },
              style: AccountantThemeConfig.primaryButtonStyle,
              child: Text('تحديث'),
            ),
          ],
        ),
      );
    } finally {
      // Safely dispose controllers immediately after dialog closes
      // but before processing the result
      quantityController.dispose();
      notesController.dispose();
    }

    // Process the result after controllers are disposed
    if (result != null && mounted) {
      // Add a small delay to ensure dialog is fully closed and UI is stable
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        await _updateQuantity(result['quantity'], result['notes']);
      }
    }
  }

  /// تحديث كمية الأداة
  Future<void> _updateQuantity(double newQuantity, String notes) async {
    if (!mounted || _isUpdating) return; // Early exit if widget is disposed or already updating

    try {
      if (mounted) {
        setState(() => _isUpdating = true);
      }

      final request = UpdateToolQuantityRequest(
        toolId: _currentTool!.id,
        newQuantity: newQuantity,
        operationType: 'adjustment',
        notes: notes.isEmpty ? null : notes,
      );

      await _toolsService.updateToolQuantity(request);

      // إعادة تحميل البيانات مع التحقق من mounted
      if (mounted) {
        await _loadToolDetails();
        await _loadUsageHistory();
        _showSuccessSnackBar('تم تحديث الكمية بنجاح');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('فشل في تحديث الكمية: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  /// إظهار حوار تحديث المخزون الأولي
  Future<void> _showSetInitialStockDialog() async {
    final TextEditingController controller = TextEditingController(
      text: _currentTool!.initialStock.toString(),
    );

    double? result;

    try {
      result = await showDialog<double?>(
        context: context,
        barrierDismissible: false, // Prevent accidental dismissal
        builder: (context) => AlertDialog(
          backgroundColor: AccountantThemeConfig.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'تحديد المخزون الأولي',
            style: AccountantThemeConfig.headlineSmall.copyWith(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'المخزون الأولي',
              labelStyle: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AccountantThemeConfig.primaryGreen),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(
                'إلغاء',
                style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final initialStock = double.tryParse(controller.text);
                if (initialStock != null && initialStock >= 0) {
                  // Return the value instead of calling async operation in dialog
                  Navigator.pop(context, initialStock);
                }
              },
              style: AccountantThemeConfig.primaryButtonStyle,
              child: Text('تحديث'),
            ),
          ],
        ),
      );
    } finally {
      // Safely dispose controller immediately after dialog closes
      // but before processing the result
      controller.dispose();
    }

    // Process the result after controller is disposed
    if (result != null && mounted) {
      // Add a small delay to ensure dialog is fully closed and UI is stable
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        await _updateInitialStock(result);
      }
    }
  }

  /// تحديث المخزون الأولي
  Future<void> _updateInitialStock(double initialStock) async {
    if (!mounted || _isUpdating) return; // Early exit if widget is disposed or already updating

    try {
      if (mounted) {
        setState(() => _isUpdating = true);
      }

      await _toolsService.updateInitialStock(_currentTool!.id, initialStock);

      // إعادة تحميل البيانات مع التحقق من mounted
      if (mounted) {
        await _loadToolDetails();
        _showSuccessSnackBar('تم تحديث المخزون الأولي بنجاح');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('فشل في تحديث المخزون الأولي: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  /// إظهار رسالة خطأ
  void _showErrorSnackBar(String message) {
    if (!mounted) return; // Prevent showing SnackBar if widget is disposed

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: AccountantThemeConfig.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4), // Longer duration for error messages
        ),
      );
    } catch (e) {
      // Fallback: log error if SnackBar fails to show
      AppLogger.error('Failed to show error SnackBar: $e');
    }
  }

  /// حذف الأداة فوراً بدون حوار تأكيد (الحذف القسري)
  Future<void> _forceDeleteTool() async {
    if (!mounted) return; // Early exit if widget is disposed

    try {
      if (mounted) {
        setState(() => _isUpdating = true);
      }

      AppLogger.info('🔥 Starting force deletion for tool: ${_currentTool!.name}');

      // تنفيذ الحذف القسري مباشرة
      await _toolsService.deleteTool(_currentTool!.id, forceDelete: true);

      if (mounted) {
        _showSuccessSnackBar('تم حذف الأداة بنجاح');
        // العودة إلى شاشة الأدوات فوراً
        Navigator.pop(context, true);
      }
    } catch (e) {
      AppLogger.error('❌ Force deletion failed: $e');
      if (mounted) {
        _showErrorSnackBar('فشل في حذف الأداة: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  /// إظهار حوار حذف الأداة المحسن (مهجور - للاستخدام الداخلي فقط)
  @deprecated
  Future<void> _showDeleteToolDialog() async {
    if (!mounted) return; // Early exit if widget is disposed

    try {
      if (mounted) {
        setState(() => _isUpdating = true);
      }

      // التحقق من قيود الحذف أولاً
      final deletionInfo = await _toolsService.checkToolDeletionConstraints(_currentTool!.id);

      if (mounted) {
        setState(() => _isUpdating = false);

        // إظهار الحوار المحسن
        final result = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => ToolDeletionDialog(
            deletionInfo: deletionInfo,
            onConfirm: () {
              // سيتم استدعاء _deleteTool من خلال النتيجة
            },
          ),
        );

        if (result == true && mounted) {
          await _deleteTool(forceDelete: !deletionInfo.canDelete);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        _showErrorSnackBar('فشل في التحقق من قيود الحذف: $e');
      }
    }
  }

  /// إظهار حوار حذف الأداة البسيط (للاستخدام في حالات الطوارئ)
  Future<void> _showSimpleDeleteDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardColor,
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
              style: AccountantThemeConfig.headlineSmall.copyWith(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل أنت متأكد من حذف الأداة "${_currentTool!.name}"؟',
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AccountantThemeConfig.dangerRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AccountantThemeConfig.dangerRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AccountantThemeConfig.dangerRed,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لا يمكن التراجع عن هذا الإجراء',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: AccountantThemeConfig.dangerRed,
                        fontWeight: FontWeight.w500,
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

    if (result == true) {
      await _deleteTool();
    }
  }

  /// حذف الأداة مع دعم الحذف القسري
  Future<void> _deleteTool({bool forceDelete = false}) async {
    if (!mounted) return; // Early exit if widget is disposed

    try {
      if (mounted) {
        setState(() => _isUpdating = true);
      }

      await _toolsService.deleteTool(_currentTool!.id, forceDelete: forceDelete);

      if (mounted) {
        _showSuccessSnackBar('تم حذف الأداة بنجاح');
        // العودة إلى شاشة الأدوات
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        if (e is ToolDeletionException) {
          _showErrorSnackBar('لا يمكن حذف الأداة: ${e.message}');
        } else {
          _showErrorSnackBar('فشل في حذف الأداة: $e');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  /// إظهار حوار إعادة تسمية الأداة
  Future<void> _showRenameToolDialog() async {
    final TextEditingController nameController = TextEditingController(
      text: _currentTool!.name,
    );

    String? result;

    try {
      result = await showDialog<String?>(
        context: context,
        barrierDismissible: false, // Prevent accidental dismissal
        builder: (context) => AlertDialog(
          backgroundColor: AccountantThemeConfig.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                Icons.drive_file_rename_outline,
                color: AccountantThemeConfig.accentBlue,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'إعادة تسمية الأداة',
                style: AccountantThemeConfig.headlineSmall.copyWith(color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'اسم الأداة الجديد',
                  labelStyle: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AccountantThemeConfig.accentBlue),
                  ),
                  prefixIcon: Icon(
                    Icons.build_circle_outlined,
                    color: AccountantThemeConfig.accentBlue,
                  ),
                ),
                textDirection: TextDirection.rtl,
                maxLength: 100,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AccountantThemeConfig.accentBlue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AccountantThemeConfig.accentBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'يجب أن يكون اسم الأداة فريداً',
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: AccountantThemeConfig.accentBlue,
                          fontWeight: FontWeight.w500,
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
              onPressed: () => Navigator.pop(context, null),
              child: Text(
                'إلغاء',
                style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty && newName != _currentTool!.name) {
                  // Return the new name instead of calling async operation in dialog
                  Navigator.pop(context, newName);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.accentBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('حفظ'),
            ),
          ],
        ),
      );
    } finally {
      // Safely dispose controller immediately after dialog closes
      // but before processing the result
      nameController.dispose();
    }

    // Process the result after controller is disposed
    if (result != null && mounted) {
      // Add a small delay to ensure dialog is fully closed and UI is stable
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        await _renameTool(result);
      }
    }
  }

  /// إعادة تسمية الأداة
  Future<void> _renameTool(String newName) async {
    if (!mounted || _isUpdating) return; // Early exit if widget is disposed or already updating

    try {
      if (mounted) {
        setState(() => _isUpdating = true);
      }

      await _toolsService.renameTool(_currentTool!.id, newName);

      // إعادة تحميل البيانات لتحديث الواجهة مع التحقق من mounted
      if (mounted) {
        await _loadToolDetails();
        _showSuccessSnackBar('تم تغيير اسم الأداة بنجاح');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('فشل في تغيير اسم الأداة: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  /// إظهار رسالة نجاح
  void _showSuccessSnackBar(String message) {
    if (!mounted) return; // Prevent showing SnackBar if widget is disposed

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: AccountantThemeConfig.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3), // Standard duration for success messages
        ),
      );
    } catch (e) {
      // Fallback: log error if SnackBar fails to show
      AppLogger.error('Failed to show success SnackBar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _currentTool == null) {
      return Scaffold(
        backgroundColor: AccountantThemeConfig.backgroundColor,
        body: const Center(
          child: CustomLoader(message: 'جاري تحميل تفاصيل الأداة...'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AccountantThemeConfig.backgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          _buildToolInfo(),
          _buildTabBar(),
          _buildTabContent(),
        ],
      ),
    );
  }

  /// بناء SliverAppBar
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: FlexibleSpaceBar(
          title: Text(
            _currentTool!.name,
            style: AccountantThemeConfig.headlineMedium.copyWith(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
      ),
    );
  }

  /// بناء معلومات الأداة
  Widget _buildToolInfo() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
        padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
          border: AccountantThemeConfig.glowBorder(_currentTool!.stockIndicatorColor),
          boxShadow: AccountantThemeConfig.cardShadows,
        ),
        child: Column(
          children: [
            // الكمية الحالية ومؤشر المخزون
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    'الكمية الحالية',
                    '${_currentTool!.quantity} ${_currentTool!.unit}',
                    _currentTool!.stockIndicatorColor,
                    Icons.inventory,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    'حالة المخزون',
                    _currentTool!.stockStatusText,
                    _currentTool!.stockIndicatorColor,
                    _currentTool!.stockStatusIcon,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // شريط التقدم
            _buildProgressBar(),
            
            const SizedBox(height: 16),
            
            // معلومات إضافية
            if (_currentTool!.color != null || _currentTool!.size != null)
              Row(
                children: [
                  if (_currentTool!.color != null)
                    Expanded(
                      child: _buildInfoCard(
                        'اللون',
                        _currentTool!.color!,
                        ToolColors.getColorValue(_currentTool!.color!),
                        Icons.palette,
                      ),
                    ),
                  if (_currentTool!.color != null && _currentTool!.size != null)
                    const SizedBox(width: 12),
                  if (_currentTool!.size != null)
                    Expanded(
                      child: _buildInfoCard(
                        'المقاس',
                        _currentTool!.size!,
                        AccountantThemeConfig.accentBlue,
                        Icons.aspect_ratio,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0),
    );
  }

  /// بناء بطاقة معلومات
  Widget _buildInfoCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// بناء شريط التقدم
  Widget _buildProgressBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'نسبة المخزون',
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
            ),
            Text(
              '${_currentTool!.stockPercentage.toStringAsFixed(1)}%',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: _currentTool!.stockIndicatorColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                width: MediaQuery.of(context).size.width * (_currentTool!.stockPercentage / 100),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _currentTool!.stockIndicatorColor.withOpacity(0.8),
                      _currentTool!.stockIndicatorColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: _currentTool!.stockIndicatorColor.withOpacity(0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// بناء شريط التبويبات
  Widget _buildTabBar() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AccountantThemeConfig.defaultPadding),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
          border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
        ),
        child: TabBar(
          controller: _tabController,
          indicatorColor: AccountantThemeConfig.primaryGreen,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'إدارة المخزون', icon: Icon(Icons.inventory_2)),
            Tab(text: 'تاريخ الاستخدام', icon: Icon(Icons.history)),
          ],
        ),
      ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
    );
  }

  /// بناء محتوى التبويبات
  Widget _buildTabContent() {
    return SliverFillRemaining(
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildStockManagementTab(),
          _buildUsageHistoryTab(),
        ],
      ),
    );
  }

  /// بناء تبويب إدارة المخزون
  Widget _buildStockManagementTab() {
    return Container(
      margin: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      child: Column(
        children: [
          const SizedBox(height: 16),
          
          // أزرار إدارة المخزون
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUpdating ? null : _showEditQuantityDialog,
                  icon: const Icon(Icons.edit),
                  label: const Text('تعديل الكمية'),
                  style: AccountantThemeConfig.primaryButtonStyle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUpdating ? null : _showSetInitialStockDialog,
                  icon: const Icon(Icons.settings),
                  label: const Text('المخزون الأولي'),
                  style: AccountantThemeConfig.secondaryButtonStyle,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // أزرار إدارة الأداة
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUpdating ? null : _showRenameToolDialog,
                  icon: const Icon(Icons.drive_file_rename_outline),
                  label: const Text('إعادة تسمية الأداة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AccountantThemeConfig.accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUpdating ? null : _forceDeleteTool,
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('حذف فوري'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AccountantThemeConfig.dangerRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // معلومات المخزون
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.cardGradient,
              borderRadius: BorderRadius.circular(12),
              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'معلومات المخزون',
                  style: AccountantThemeConfig.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStockInfoRow('المخزون الأولي', '${_currentTool!.initialStock} ${_currentTool!.unit}'),
                _buildStockInfoRow('المخزون الحالي', '${_currentTool!.quantity} ${_currentTool!.unit}'),
                _buildStockInfoRow('المستهلك', '${_currentTool!.initialStock - _currentTool!.quantity} ${_currentTool!.unit}'),
                _buildStockInfoRow('تاريخ الإنشاء', _formatDate(_currentTool!.createdAt)),
                _buildStockInfoRow('آخر تحديث', _formatDate(_currentTool!.updatedAt)),
              ],
            ),
          ),
          
          if (_isUpdating) ...[
            const SizedBox(height: 24),
            const CustomLoader(message: 'جاري التحديث...'),
          ],
        ],
      ),
    );
  }

  /// بناء صف معلومات المخزون
  Widget _buildStockInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
          ),
          Text(
            value,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// بناء تبويب تاريخ الاستخدام
  Widget _buildUsageHistoryTab() {
    if (_usageHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              'لا يوجد تاريخ استخدام',
              style: AccountantThemeConfig.headlineSmall.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'لم يتم استخدام هذه الأداة بعد',
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      itemCount: _usageHistory.length,
      itemBuilder: (context, index) {
        final usage = _usageHistory[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(12),
            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      usage.descriptiveOperationName,
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    usage.formattedUsageDateTime,
                    style: AccountantThemeConfig.bodySmall.copyWith(color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'الكمية المستخدمة: ${usage.quantityUsed.toStringAsFixed(1)}',
                style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
              ),
              Text(
                'المخزون المتبقي: ${usage.remainingStock.toStringAsFixed(1)}',
                style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
              ),
              if (usage.warehouseManagerName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'بواسطة: ${usage.warehouseManagerName}',
                  style: AccountantThemeConfig.bodySmall.copyWith(color: Colors.white70),
                ),
              ],
              if (usage.notes != null && usage.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'ملاحظات: ${usage.notes}',
                  style: AccountantThemeConfig.bodySmall.copyWith(color: Colors.white70),
                ),
              ],
            ],
          ),
        ).animate().fadeIn(duration: 600.ms, delay: (index * 100).ms);
      },
    );
  }

  /// تنسيق التاريخ
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
