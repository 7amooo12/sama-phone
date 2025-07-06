import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/widgets/common/custom_loader.dart';
import 'package:smartbiztracker_new/models/manufacturing/manufacturing_tool.dart';
import 'package:smartbiztracker_new/services/manufacturing/manufacturing_tools_service.dart';
import 'package:smartbiztracker_new/screens/manufacturing/widgets/manufacturing_tool_card.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'dart:async';

/// شاشة إدارة أدوات التصنيع الرئيسية مع تتبع المخزون الذكي
class ManufacturingToolsScreen extends StatefulWidget {
  const ManufacturingToolsScreen({super.key});

  @override
  State<ManufacturingToolsScreen> createState() => _ManufacturingToolsScreenState();
}

class _ManufacturingToolsScreenState extends State<ManufacturingToolsScreen> {
  final ManufacturingToolsService _toolsService = ManufacturingToolsService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<ManufacturingTool> _tools = [];
  List<ManufacturingTool> _filteredTools = [];
  bool _isLoading = true;
  String _selectedStockFilter = 'all';
  Timer? _searchDebouncer;
  Map<String, dynamic>? _statistics;

  @override
  void initState() {
    super.initState();
    _loadTools();
    _loadStatistics();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebouncer?.cancel();
    super.dispose();
  }

  /// تحميل الأدوات من الخدمة
  Future<void> _loadTools() async {
    try {
      setState(() => _isLoading = true);
      
      final tools = await _toolsService.getAllTools();
      
      if (mounted) {
        setState(() {
          _tools = tools;
          _filteredTools = tools;
          _isLoading = false;
        });
        
        AppLogger.info('✅ Loaded ${tools.length} manufacturing tools');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('فشل في تحميل الأدوات: $e');
      }
      AppLogger.error('❌ Error loading tools: $e');
    }
  }

  /// تحميل الإحصائيات
  Future<void> _loadStatistics() async {
    try {
      final stats = await _toolsService.getToolsStatistics();
      if (mounted) {
        setState(() => _statistics = stats);
      }
    } catch (e) {
      AppLogger.error('❌ Error loading statistics: $e');
    }
  }

  /// معالجة تغيير البحث مع التأخير
  void _onSearchChanged() {
    _searchDebouncer?.cancel();
    _searchDebouncer = Timer(const Duration(milliseconds: 1500), () {
      _performSearch(_searchController.text);
    });
  }

  /// تنفيذ البحث
  void _performSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredTools = _tools;
      } else {
        _filteredTools = _tools.where((tool) {
          return tool.name.toLowerCase().contains(query.toLowerCase()) ||
                 tool.unit.toLowerCase().contains(query.toLowerCase()) ||
                 (tool.color?.toLowerCase().contains(query.toLowerCase()) ?? false);
        }).toList();
      }
      _applyStockFilter();
    });
  }

  /// تطبيق فلتر حالة المخزون
  void _applyStockFilter() {
    if (_selectedStockFilter != 'all') {
      _filteredTools = _filteredTools.where((tool) {
        return tool.stockStatus == _selectedStockFilter;
      }).toList();
    }
  }

  /// تغيير فلتر المخزون
  void _onStockFilterChanged(String filter) {
    setState(() {
      _selectedStockFilter = filter;
      _performSearch(_searchController.text);
    });
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

  /// التنقل إلى شاشة إضافة أداة
  void _navigateToAddTool() {
    Navigator.pushNamed(context, '/manufacturing-tools/add').then((_) {
      _loadTools();
      _loadStatistics();
    });
  }

  /// التنقل إلى تفاصيل الأداة
  void _navigateToToolDetail(ManufacturingTool tool) {
    Navigator.pushNamed(
      context,
      '/manufacturing-tools/detail',
      arguments: {'tool': tool},
    ).then((result) {
      // Always refresh data when returning from tool detail screen
      if (mounted) {
        _refreshToolsList();

        // Show success message if tool was updated/deleted
        if (result == true) {
          _showSuccessSnackBar('تم تحديث قائمة الأدوات بنجاح');
        }
      }
    }).catchError((error) {
      // Handle navigation errors gracefully
      if (mounted) {
        AppLogger.error('Navigation error: $error');
        _showErrorSnackBar('حدث خطأ أثناء التنقل');
      }
    });
  }

  /// تحديث قائمة الأدوات فوراً (للاستخدام بعد الحذف القسري)
  Future<void> _refreshToolsList() async {
    if (!mounted) return;

    try {
      AppLogger.info('🔄 Refreshing tools list immediately');
      await _loadTools();
      await _loadStatistics();
      AppLogger.info('✅ Tools list refreshed successfully');
    } catch (e) {
      AppLogger.error('❌ Error refreshing tools list: $e');
      if (mounted) {
        _showErrorSnackBar('فشل في تحديث قائمة الأدوات: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.backgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(),
          _buildStatisticsSection(),
          _buildSearchAndFilters(),
          _buildToolsGrid(),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  /// بناء SliverAppBar مع تدرج
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: FlexibleSpaceBar(
          title: Text(
            'أدوات التصنيع',
            style: AccountantThemeConfig.headlineMedium.copyWith(
              color: Colors.white,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          background: Container(
            decoration: const BoxDecoration(
              gradient: AccountantThemeConfig.mainBackgroundGradient,
            ),
          ),
        ),
      ),
    );
  }

  /// بناء قسم الإحصائيات
  Widget _buildStatisticsSection() {
    if (_statistics == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
        padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
          border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
          boxShadow: AccountantThemeConfig.cardShadows,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'إحصائيات الأدوات',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildStatCard('إجمالي الأدوات', '${_statistics!['total_tools']}', Icons.build, AccountantThemeConfig.primaryGreen)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('مخزون جيد', '${_statistics!['green_stock']}', Icons.check_circle, Colors.green)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatCard('مخزون منخفض', '${_statistics!['orange_stock']}', Icons.warning, Colors.orange)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('مخزون نفد', '${_statistics!['red_stock']}', Icons.error, Colors.red)),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0),
    );
  }

  /// بناء بطاقة إحصائية
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
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

  /// بناء قسم البحث والفلاتر
  Widget _buildSearchAndFilters() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AccountantThemeConfig.defaultPadding),
        child: Column(
          children: [
            // شريط البحث
            Container(
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.cardGradient,
                borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
                boxShadow: AccountantThemeConfig.cardShadows,
              ),
              child: TextField(
                controller: _searchController,
                style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'البحث في الأدوات...',
                  hintStyle: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // فلاتر حالة المخزون
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('الكل', 'all'),
                  _buildFilterChip('مخزون جيد', 'green'),
                  _buildFilterChip('مخزون متوسط', 'yellow'),
                  _buildFilterChip('مخزون منخفض', 'orange'),
                  _buildFilterChip('مخزون نفد', 'red'),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideY(begin: 0.3, end: 0),
    );
  }

  /// بناء رقاقة الفلتر
  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedStockFilter == value;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _onStockFilterChanged(value),
        backgroundColor: Colors.transparent,
        selectedColor: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
        checkmarkColor: AccountantThemeConfig.primaryGreen,
        labelStyle: AccountantThemeConfig.bodySmall.copyWith(
          color: isSelected ? AccountantThemeConfig.primaryGreen : Colors.white70,
        ),
        side: BorderSide(
          color: isSelected ? AccountantThemeConfig.primaryGreen : Colors.white30,
        ),
      ),
    );
  }

  /// بناء شبكة الأدوات
  Widget _buildToolsGrid() {
    if (_isLoading) {
      return const SliverToBoxAdapter(
        child: Center(
          child: CustomLoader(message: 'جاري تحميل الأدوات...'),
        ),
      );
    }

    if (_filteredTools.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
          padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.warningOrange),
          ),
          child: Column(
            children: [
              Icon(
                Icons.build_circle_outlined,
                size: 64,
                color: Colors.white54,
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد أدوات',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'لم يتم العثور على أدوات تصنيع',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 600.ms),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75, // Further reduced to provide more height and prevent overflow
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final tool = _filteredTools[index];
            return ManufacturingToolCard(
              tool: tool,
              onTap: () => _navigateToToolDetail(tool),
            ).animate().fadeIn(
              duration: 600.ms,
              delay: (index * 100).ms,
            ).slideY(begin: 0.3, end: 0);
          },
          childCount: _filteredTools.length,
        ),
      ),
    );
  }

  /// بناء زر الإضافة العائم
  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _navigateToAddTool,
      backgroundColor: AccountantThemeConfig.primaryGreen,
      icon: const Icon(Icons.add, color: Colors.white),
      label: Text(
        'إضافة أداة',
        style: AccountantThemeConfig.bodyMedium.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    ).animate().scale(delay: 800.ms);
  }
}
