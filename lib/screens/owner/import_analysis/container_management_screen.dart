import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/providers/import_analysis_provider.dart';
import 'package:smartbiztracker_new/models/container_import_models.dart';
import 'package:smartbiztracker_new/utils/formatters.dart';
import 'package:smartbiztracker_new/screens/owner/import_analysis/container_detail_screen.dart';
import 'package:smartbiztracker_new/widgets/common/custom_loader.dart';

/// شاشة إدارة الحاويات المحفوظة
class ContainerManagementScreen extends StatefulWidget {
  const ContainerManagementScreen({super.key});

  @override
  State<ContainerManagementScreen> createState() => _ContainerManagementScreenState();
}

class _ContainerManagementScreenState extends State<ContainerManagementScreen> {
  String _searchQuery = '';
  String _sortBy = 'date';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ImportAnalysisProvider>().loadContainerBatches();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.backgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<ImportAnalysisProvider>().loadContainerBatches();
        },
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            _buildSearchAndFilters(),
            _buildContent(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushReplacementNamed(context, '/container_import');
        },
        backgroundColor: AccountantThemeConfig.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('حاوية جديدة'),
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
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: FlexibleSpaceBar(
          title: Text(
            'إدارة الحاويات المحفوظة',
            style: AccountantThemeConfig.headlineMedium.copyWith(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          background: Container(
            decoration: const BoxDecoration(
              gradient: AccountantThemeConfig.mainBackgroundGradient,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.1,
                    child: CustomPaint(
                      painter: _BackgroundPatternPainter(),
                      size: Size.infinite,
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

  /// بناء البحث والفلاتر
  Widget _buildSearchAndFilters() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AccountantThemeConfig.cardShadows,
          border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'البحث في الحاويات...',
                      hintStyle: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.grey[500],
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AccountantThemeConfig.accentBlue,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: DropdownButton<String>(
                    value: _sortBy,
                    onChanged: (value) => setState(() => _sortBy = value!),
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'date', child: Text('التاريخ')),
                      DropdownMenuItem(value: 'name', child: Text('الاسم')),
                      DropdownMenuItem(value: 'size', child: Text('الحجم')),
                      DropdownMenuItem(value: 'items', child: Text('عدد المنتجات')),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => setState(() => _sortAscending = !_sortAscending),
                  icon: Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    color: AccountantThemeConfig.accentBlue,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
    );
  }

  /// بناء المحتوى
  Widget _buildContent() {
    return Consumer<ImportAnalysisProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return SliverToBoxAdapter(
            child: Container(
              height: 300,
              child: const Center(
                child: CustomLoader(
                  message: 'تحميل الحاويات المحفوظة...',
                ),
              ),
            ),
          );
        }

        if (provider.errorMessage != null) {
          return SliverToBoxAdapter(
            child: _buildErrorState(provider.errorMessage!),
          );
        }

        final filteredBatches = _getFilteredAndSortedBatches(provider.containerBatches);

        if (filteredBatches.isEmpty) {
          return SliverToBoxAdapter(
            child: _buildEmptyState(),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _getCrossAxisCount(context),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: _getChildAspectRatio(context),
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final batch = filteredBatches[index];
                return _buildContainerCard(batch, provider);
              },
              childCount: filteredBatches.length,
            ),
          ),
        );
      },
    );
  }

  /// بناء بطاقة الحاوية
  Widget _buildContainerCard(ContainerImportBatch batch, ImportAnalysisProvider provider) {
    final stats = _calculateBatchStatistics(batch);

    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _openContainerDetail(batch),
          borderRadius: BorderRadius.circular(20),
          splashColor: AccountantThemeConfig.primaryGreen.withOpacity(0.1),
          highlightColor: AccountantThemeConfig.primaryGreen.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon and menu
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.inventory_2,
                        color: AccountantThemeConfig.primaryGreen,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      onSelected: (value) => _handleMenuAction(value, batch, provider),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(Icons.visibility, size: 16),
                              SizedBox(width: 8),
                              Text('عرض التفاصيل'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text('حذف', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // File name
                Text(
                  batch.originalFilename,
                  style: AccountantThemeConfig.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 8),

                // Date
                Text(
                  Formatters.formatDate(batch.createdAt),
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: AccountantThemeConfig.white70,
                  ),
                ),

                const SizedBox(height: 12),

                // Statistics
                Expanded(
                  child: Column(
                    children: [
                      _buildStatRow('المنتجات', stats['totalItems'].toString(), Icons.inventory),
                      const SizedBox(height: 6),
                      _buildStatRow('الكراتين', stats['totalCartons'].toString(), Icons.all_inbox),
                      const SizedBox(height: 6),
                      _buildStatRow('الكمية', Formatters.formatNumber(stats['totalQuantity']), Icons.analytics),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // File size
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AccountantThemeConfig.accentBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    Formatters.formatFileSize(batch.fileSize),
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: AccountantThemeConfig.accentBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3);
  }

  /// بناء صف الإحصائيات
  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: AccountantThemeConfig.white70,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: AccountantThemeConfig.white70,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// بناء حالة فارغة
  Widget _buildEmptyState() {
    return Container(
      height: 400,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue.withOpacity(0.3)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AccountantThemeConfig.accentBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 60,
                color: AccountantThemeConfig.accentBlue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'لا توجد حاويات محفوظة',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ابدأ بإستيراد حاوية جديدة لتظهر هنا',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: AccountantThemeConfig.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3);
  }

  /// بناء حالة الخطأ
  Widget _buildErrorState(String error) {
    return Container(
      height: 300,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(Colors.red.withOpacity(0.3)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red[400],
            ),
            const SizedBox(height: 24),
            Text(
              'حدث خطأ',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              error,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.read<ImportAnalysisProvider>().loadContainerBatches();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.primaryGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// فتح تفاصيل الحاوية
  void _openContainerDetail(ContainerImportBatch batch) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContainerDetailScreen(batch: batch),
      ),
    );
  }

  /// التعامل مع إجراءات القائمة
  void _handleMenuAction(String action, ContainerImportBatch batch, ImportAnalysisProvider provider) {
    switch (action) {
      case 'view':
        _openContainerDetail(batch);
        break;
      case 'delete':
        _showDeleteConfirmation(batch, provider);
        break;
    }
  }

  /// عرض تأكيد الحذف
  void _showDeleteConfirmation(ContainerImportBatch batch, ImportAnalysisProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف الحاوية "${batch.originalFilename}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              provider.deleteContainerBatch(batch.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  /// حساب إحصائيات الدفعة
  Map<String, dynamic> _calculateBatchStatistics(ContainerImportBatch batch) {
    final totalCartons = batch.items.fold(0, (sum, item) => sum + item.numberOfCartons);
    final totalQuantity = batch.items.fold(0, (sum, item) => sum + item.totalQuantity);

    return {
      'totalItems': batch.items.length,
      'totalCartons': totalCartons,
      'totalQuantity': totalQuantity,
    };
  }

  /// الحصول على الدفعات المفلترة والمرتبة
  List<ContainerImportBatch> _getFilteredAndSortedBatches(List<ContainerImportBatch> batches) {
    var filteredBatches = List<ContainerImportBatch>.from(batches);

    // تطبيق البحث
    if (_searchQuery.isNotEmpty) {
      filteredBatches = filteredBatches.where((batch) =>
          batch.originalFilename.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          batch.filename.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    // تطبيق الترتيب
    filteredBatches.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'date':
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case 'name':
          comparison = a.originalFilename.compareTo(b.originalFilename);
          break;
        case 'size':
          comparison = a.fileSize.compareTo(b.fileSize);
          break;
        case 'items':
          comparison = a.items.length.compareTo(b.items.length);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filteredBatches;
  }

  /// الحصول على عدد الأعمدة حسب حجم الشاشة
  int _getCrossAxisCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) {
      return 4; // شاشات كبيرة جداً
    } else if (screenWidth > 800) {
      return 3; // شاشات كبيرة
    } else if (screenWidth > 600) {
      return 2; // شاشات متوسطة
    } else {
      return 1; // شاشات صغيرة
    }
  }

  /// الحصول على نسبة العرض إلى الارتفاع حسب حجم الشاشة
  double _getChildAspectRatio(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) {
      return 0.9; // شاشات كبيرة جداً
    } else if (screenWidth > 800) {
      return 0.85; // شاشات كبيرة
    } else if (screenWidth > 600) {
      return 0.85; // شاشات متوسطة
    } else {
      return 1.2; // شاشات صغيرة - أطول
    }
  }
}

/// رسام نمط الخلفية
class _BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;

    const spacing = 30.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
