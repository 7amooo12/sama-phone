import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/warehouse_provider.dart';
import 'package:smartbiztracker_new/models/warehouse_model.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/widgets/warehouse/warehouse_card.dart';
import 'package:smartbiztracker_new/widgets/warehouse/warehouse_details_screen.dart';
import 'package:smartbiztracker_new/widgets/warehouse/add_warehouse_dialog.dart';
import 'package:smartbiztracker_new/providers/warehouse_search_provider.dart';
import 'package:smartbiztracker_new/widgets/warehouse/warehouse_search_widget.dart';
import 'package:smartbiztracker_new/screens/warehouse/warehouse_reports_screen.dart';

/// واجهة المخازن الموحدة - نسخة مطابقة من Warehouse Manager Dashboard
/// تضمن عرض نفس البيانات والوظائف عبر جميع الأدوار
class UnifiedWarehouseInterface extends StatefulWidget {
  final String userRole;

  const UnifiedWarehouseInterface({
    super.key,
    required this.userRole,
  });

  @override
  State<UnifiedWarehouseInterface> createState() => _UnifiedWarehouseInterfaceState();
}

class _UnifiedWarehouseInterfaceState extends State<UnifiedWarehouseInterface> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // تحميل البيانات عند تهيئة الواجهة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWarehouseData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// تحميل بيانات المخازن - نسخة مطابقة من Warehouse Manager
  Future<void> _loadWarehouseData() async {
    try {
      AppLogger.info('🏢 تحميل بيانات المخازن للدور: ${widget.userRole}');
      final warehouseProvider = Provider.of<WarehouseProvider>(context, listen: false);
      await warehouseProvider.loadWarehouses(forceRefresh: true);
      AppLogger.info('✅ تم تحميل بيانات المخازن بنجاح - عدد المخازن: ${warehouseProvider.warehouses.length}');
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل بيانات المخازن: $e');
    }
  }

  /// التحقق من صلاحيات الإضافة - جميع الأدوار لها صلاحية كاملة
  bool get _canAdd => true;

  /// التحقق من صلاحيات التعديل - جميع الأدوار لها صلاحية كاملة
  bool get _canEdit => true;

  /// التحقق من صلاحيات الحذف - جميع الأدوار لها صلاحية كاملة
  bool get _canDelete => true;

  @override
  Widget build(BuildContext context) {
    return Consumer<WarehouseProvider>(
      builder: (context, warehouseProvider, child) {
        return Column(
          children: [
            // شريط الأدوات مع زر إضافة مخزن - نسخة مطابقة
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'إدارة المخازن',
                      style: AccountantThemeConfig.headlineMedium,
                    ),
                  ),
                  // زر التقارير المتقدمة
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      gradient: AccountantThemeConfig.greenGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                    ),
                    child: IconButton(
                      onPressed: () => _showWarehouseReports(),
                      icon: const Icon(
                        Icons.analytics_rounded,
                        color: Colors.white,
                      ),
                      tooltip: 'تقارير المخازن المتقدمة',
                    ),
                  ),

                  // زر البحث في المنتجات (للأدوار المصرح لها)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      gradient: AccountantThemeConfig.blueGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
                    ),
                    child: IconButton(
                      onPressed: () => _showWarehouseSearchDialog(),
                      icon: const Icon(
                        Icons.search,
                        color: Colors.white,
                      ),
                      tooltip: 'البحث في المنتجات والفئات',
                    ),
                  ),
                  _buildAddWarehouseButton(),
                ],
              ),
            ),

            // شريط البحث في المخازن
            _buildWarehouseSearchBar(),

            // محتوى المخازن - نسخة مطابقة
            Expanded(
              child: _buildWarehousesContent(warehouseProvider),
            ),
          ],
        );
      },
    );
  }

  /// بناء زر إضافة مخزن - نسخة مطابقة من Warehouse Manager
  Widget _buildAddWarehouseButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.greenGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showAddWarehouseDialog,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.add_business_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'إضافة مخزن',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// بناء محتوى المخازن - نسخة مطابقة من Warehouse Manager
  Widget _buildWarehousesContent(WarehouseProvider provider) {
    if (provider.isLoadingWarehouses) {
      return _buildWarehousesLoadingState();
    }

    if (provider.error != null) {
      return _buildWarehousesErrorState(provider.error!, provider);
    }

    if (provider.warehouses.isEmpty) {
      return _buildEmptyWarehousesState();
    }

    final filteredWarehouses = _getFilteredWarehouses(provider.warehouses);

    if (filteredWarehouses.isEmpty && _searchQuery.isNotEmpty) {
      return _buildNoSearchResultsState();
    }

    return _buildWarehousesGrid(provider.warehouses);
  }

  /// بناء حالة تحميل المخازن - نسخة مطابقة من Warehouse Manager
  Widget _buildWarehousesLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AccountantThemeConfig.greenGradient,
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'جاري تحميل المخازن...',
            style: AccountantThemeConfig.bodyLarge,
          ),
        ],
      ),
    );
  }

  /// بناء حالة خطأ المخازن - نسخة مطابقة من Warehouse Manager
  Widget _buildWarehousesErrorState(String errorMessage, WarehouseProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AccountantThemeConfig.warningOrange,
          ),
          const SizedBox(height: 16),
          Text(
            'خطأ في تحميل المخازن',
            style: AccountantThemeConfig.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage,
            style: AccountantThemeConfig.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => provider.loadWarehouses(forceRefresh: true),
            icon: const Icon(Icons.refresh),
            label: Text(
              'إعادة المحاولة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء حالة عدم وجود مخازن - نسخة مطابقة من Warehouse Manager
  Widget _buildEmptyWarehousesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.warehouse_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد مخازن',
            style: AccountantThemeConfig.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ بإضافة مخزن جديد لإدارة المخزون',
            style: AccountantThemeConfig.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildAddWarehouseButton(),
        ],
      ),
    );
  }

  /// بناء حالة عدم وجود نتائج بحث
  Widget _buildNoSearchResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.withOpacity(0.3),
                  Colors.orange.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 50,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'لا توجد نتائج للبحث',
            style: AccountantThemeConfig.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'لم يتم العثور على مخازن تطابق "${_searchQuery}"',
            style: AccountantThemeConfig.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'جرب كلمات بحث مختلفة أو تأكد من الإملاء',
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.blueGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.clear_all,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'مسح البحث',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء شريط البحث في المخازن
  Widget _buildWarehouseSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            // أيقونة البحث
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: _searchQuery.isNotEmpty
                    ? AccountantThemeConfig.greenGradient
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.search,
                color: _searchQuery.isNotEmpty
                    ? Colors.white
                    : AccountantThemeConfig.primaryGreen,
                size: 20,
              ),
            ),

            const SizedBox(width: 12),

            // حقل البحث
            Expanded(
              child: TextField(
                controller: _searchController,
                textDirection: TextDirection.rtl,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'البحث في المخازن (اسم، عنوان)...',
                  hintStyle: GoogleFonts.cairo(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (query) {
                  setState(() {
                    _searchQuery = query;
                  });
                },
              ),
            ),

            // زر المسح
            if (_searchQuery.isNotEmpty)
              IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
                icon: Icon(
                  Icons.clear,
                  color: Colors.white.withOpacity(0.7),
                  size: 18,
                ),
                tooltip: 'مسح البحث',
              ),
          ],
        ),
      ),
    );
  }

  /// فلترة المخازن حسب البحث
  List<WarehouseModel> _getFilteredWarehouses(List<WarehouseModel> warehouses) {
    if (_searchQuery.isEmpty) {
      return warehouses;
    }

    final query = _searchQuery.toLowerCase();
    return warehouses.where((warehouse) {
      final name = warehouse.name.toLowerCase();
      final address = warehouse.address?.toLowerCase() ?? '';

      return name.contains(query) || address.contains(query);
    }).toList();
  }

  /// بناء شبكة المخازن - مع تصميم متجاوب لمنع overflow
  Widget _buildWarehousesGrid(List<WarehouseModel> warehouses) {
    final filteredWarehouses = _getFilteredWarehouses(warehouses);

    return RefreshIndicator(
      onRefresh: () async {
        final provider = Provider.of<WarehouseProvider>(context, listen: false);
        await provider.loadWarehouses(forceRefresh: true);
      },
      backgroundColor: AccountantThemeConfig.cardBackground1,
      color: AccountantThemeConfig.primaryGreen,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final isTablet = screenWidth > 768;
          final isLargePhone = screenWidth > 600;

          // Responsive grid parameters
          final crossAxisCount = isTablet ? 3 : isLargePhone ? 2 : 1;
          final childAspectRatio = isTablet ? 0.85 : isLargePhone ? 0.9 : 1.1;
          final spacing = isTablet ? 20.0 : isLargePhone ? 16.0 : 12.0;
          final padding = isTablet ? 20.0 : 16.0;

          return GridView.builder(
            padding: EdgeInsets.all(padding),
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            itemCount: filteredWarehouses.length,
            itemBuilder: (context, index) {
              final warehouse = filteredWarehouses[index];
              final provider = Provider.of<WarehouseProvider>(context, listen: false);
              final stats = provider.getWarehouseStatistics(warehouse.id);

              // تسجيل تفصيلي للإحصائيات المرسلة للبطاقة
              AppLogger.info('🏭 إحصائيات المخزن ${warehouse.name} (${warehouse.id}):');
              AppLogger.info('  - عدد المنتجات: ${stats['productCount']}');
              AppLogger.info('  - الكمية الإجمالية: ${stats['totalQuantity']}');
              AppLogger.info('  - إجمالي الكراتين: ${stats['totalCartons']}');
              AppLogger.info('  - الإحصائيات الكاملة: $stats');

              return _buildSafeWidget(() => WarehouseCard(
                warehouse: warehouse,
                productCount: stats['productCount'],
                totalQuantity: stats['totalQuantity'],
                totalCartons: stats['totalCartons'], // إضافة إجمالي الكراتين
                onTap: () => _showWarehouseDetails(warehouse),
                onEdit: _canEdit ? () => _showEditWarehouseDialog(warehouse) : null,
                onDelete: _canDelete ? () => _showDeleteWarehouseDialog(warehouse) : null,
              ));
            },
          );
        },
      ),
    );
  }

  // Safe widget wrapper to prevent crashes
  Widget _buildSafeWidget(Widget Function() builder) {
    try {
      return builder();
    } catch (e) {
      AppLogger.error('⚠️ خطأ في بناء ويدجت المخزن: $e');
      return _buildErrorPlaceholder();
    }
  }

  // Error placeholder widget
  Widget _buildErrorPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.dangerRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.dangerRed.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning,
            color: AccountantThemeConfig.dangerRed,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'تعذر تحميل هذا المخزن. يرجى المحاولة مرة أخرى.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  /// عرض حوار إضافة مخزن - نسخة مطابقة من Warehouse Manager
  void _showAddWarehouseDialog() {
    showDialog(
      context: context,
      builder: (context) => AddWarehouseDialog(
        onWarehouseAdded: (warehouse) {
          // تحديث قائمة المخازن
          final provider = Provider.of<WarehouseProvider>(context, listen: false);
          provider.loadWarehouses(forceRefresh: true);
        },
      ),
    );
  }

  /// عرض حوار تعديل مخزن - نسخة مطابقة من Warehouse Manager
  void _showEditWarehouseDialog(WarehouseModel warehouse) {
    showDialog(
      context: context,
      builder: (context) => AddWarehouseDialog(
        warehouse: warehouse,
        onWarehouseAdded: (updatedWarehouse) {
          // تحديث قائمة المخازن
          final provider = Provider.of<WarehouseProvider>(context, listen: false);
          provider.loadWarehouses(forceRefresh: true);
        },
      ),
    );
  }

  /// عرض تفاصيل المخزن - نسخة مطابقة من Warehouse Manager
  void _showWarehouseDetails(WarehouseModel warehouse) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WarehouseDetailsScreen(warehouse: warehouse),
      ),
    );
  }

  /// عرض حوار حذف مخزن - نسخة مطابقة من Warehouse Manager
  void _showDeleteWarehouseDialog(WarehouseModel warehouse) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardBackground1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'حذف المخزن',
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'هل أنت متأكد من حذف المخزن "${warehouse.name}"؟\nسيتم حذف جميع البيانات المرتبطة به.',
          style: GoogleFonts.cairo(
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteWarehouse(warehouse);
              },
              child: Text(
                'حذف',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// حذف المخزن - نسخة مطابقة من Warehouse Manager
  Future<void> _deleteWarehouse(WarehouseModel warehouse) async {
    try {
      final warehouseProvider = Provider.of<WarehouseProvider>(context, listen: false);
      await warehouseProvider.deleteWarehouse(warehouse.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم حذف المخزن "${warehouse.name}" بنجاح',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في حذف المخزن: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'فشل في حذف المخزن: $e',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// عرض حوار البحث في المخازن - نسخة مطابقة من Warehouse Manager
  void _showWarehouseSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider(
        create: (context) => WarehouseSearchProvider(),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.mainBackgroundGradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: Column(
              children: [
                // شريط العنوان
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                        AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AccountantThemeConfig.greenGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.search,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'البحث في المنتجات والفئات',
                          style: GoogleFonts.cairo(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.6),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white70,
                          size: 24,
                        ),
                        tooltip: 'إغلاق',
                      ),
                    ],
                  ),
                ),

                // محتوى البحث
                const Expanded(
                  child: WarehouseSearchWidget(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// عرض شاشة تقارير المخازن المتقدمة - نسخة مطابقة من Warehouse Manager
  void _showWarehouseReports() {
    AppLogger.info('🔍 فتح شاشة تقارير المخازن المتقدمة للدور: ${widget.userRole}');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const WarehouseReportsScreen(),
      ),
    );
  }
}
