import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/models/container_import_models.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/formatters.dart';
import 'package:smartbiztracker_new/screens/owner/import_analysis/widgets/container_import_data_display.dart';

/// شاشة تفاصيل الحاوية المحفوظة
class ContainerDetailScreen extends StatefulWidget {
  final ContainerImportBatch batch;

  const ContainerDetailScreen({
    super.key,
    required this.batch,
  });

  @override
  State<ContainerDetailScreen> createState() => _ContainerDetailScreenState();
}

class _ContainerDetailScreenState extends State<ContainerDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.backgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          _buildHeaderInfo(),
          _buildTabBar(),
          _buildTabContent(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showShareOptions();
        },
        backgroundColor: AccountantThemeConfig.primaryGreen,
        foregroundColor: Colors.white,
        child: const Icon(Icons.share),
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
            'تفاصيل الحاوية',
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

  /// بناء معلومات الرأس
  Widget _buildHeaderInfo() {
    final stats = _calculateStatistics();
    
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AccountantThemeConfig.cardShadows,
          border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.inventory_2,
                    color: AccountantThemeConfig.primaryGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.batch.originalFilename,
                        style: AccountantThemeConfig.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'تم الإنشاء: ${Formatters.formatDate(widget.batch.createdAt)}',
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: AccountantThemeConfig.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AccountantThemeConfig.accentBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    Formatters.formatFileSize(widget.batch.fileSize),
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: AccountantThemeConfig.accentBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Statistics cards
            Row(
              children: [
                Expanded(child: _buildStatCard('إجمالي المنتجات', stats['totalItems'].toString(), Icons.inventory, AccountantThemeConfig.accentBlue)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('إجمالي الكراتين', stats['totalCartons'].toString(), Icons.all_inbox, AccountantThemeConfig.warningOrange)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('إجمالي الكمية', Formatters.formatNumber(stats['totalQuantity']), Icons.analytics, AccountantThemeConfig.primaryGreen)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('منتجات فريدة', stats['uniqueProducts'].toString(), Icons.category, Colors.purple)),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3),
    );
  }

  /// بناء بطاقة إحصائية
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: AccountantThemeConfig.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.grey[600],
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ).animate().scale(duration: 400.ms);
  }

  /// بناء شريط التبويبات
  Widget _buildTabBar() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AccountantThemeConfig.cardShadows,
          border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue.withOpacity(0.3)),
        ),
        child: TabBar(
          controller: _tabController,
          labelColor: AccountantThemeConfig.primaryGreen,
          unselectedLabelColor: AccountantThemeConfig.white70,
          indicatorColor: AccountantThemeConfig.primaryGreen,
          indicatorWeight: 3,
          labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: AccountantThemeConfig.bodyMedium,
          tabs: const [
            Tab(text: 'البيانات'),
            Tab(text: 'الإحصائيات'),
            Tab(text: 'المعلومات'),
          ],
        ),
      ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2),
    );
  }

  /// بناء محتوى التبويبات
  Widget _buildTabContent() {
    return SliverFillRemaining(
      child: Container(
        margin: const EdgeInsets.all(16),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildDataTab(),
            _buildStatisticsTab(),
            _buildInfoTab(),
          ],
        ),
      ),
    );
  }

  /// تبويب البيانات
  Widget _buildDataTab() {
    return ContainerImportDataDisplay(
      items: widget.batch.items,
      result: null, // No result needed for saved data
    );
  }

  /// تبويب الإحصائيات
  Widget _buildStatisticsTab() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إحصائيات مفصلة',
            style: AccountantThemeConfig.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          _buildDetailedStatistics(),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3);
  }

  /// تبويب المعلومات
  Widget _buildInfoTab() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'معلومات الملف',
            style: AccountantThemeConfig.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          _buildFileInfo(),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3);
  }

  /// بناء الإحصائيات المفصلة
  Widget _buildDetailedStatistics() {
    final stats = _calculateStatistics();
    final productStats = _calculateProductStatistics();

    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // إحصائيات عامة
            _buildStatSection('إحصائيات عامة', [
              _buildStatRow('إجمالي المنتجات', stats['totalItems'].toString()),
              _buildStatRow('إجمالي الكراتين', stats['totalCartons'].toString()),
              _buildStatRow('إجمالي الكمية', Formatters.formatNumber(stats['totalQuantity'])),
              _buildStatRow('منتجات فريدة', stats['uniqueProducts'].toString()),
              _buildStatRow('متوسط الكمية لكل منتج', stats['averageQuantityPerProduct'].toString()),
              _buildStatRow('متوسط الكراتين لكل منتج', stats['averageCartonsPerProduct'].toString()),
            ]),

            const SizedBox(height: 20),

            // إحصائيات المنتجات
            _buildStatSection('أكثر المنتجات كمية', [
              ...productStats['topProducts'].map<Widget>((product) =>
                _buildStatRow(product['name'], Formatters.formatNumber(product['quantity']))),
            ]),
          ],
        ),
      ),
    );
  }

  /// بناء قسم الإحصائيات
  Widget _buildStatSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AccountantThemeConfig.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AccountantThemeConfig.primaryGreen,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  /// بناء صف الإحصائيات
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.white70,
            ),
          ),
          Text(
            value,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// بناء معلومات الملف
  Widget _buildFileInfo() {
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildInfoCard('معلومات الملف', [
              _buildInfoRow('اسم الملف الأصلي', widget.batch.originalFilename),
              _buildInfoRow('اسم الملف المحفوظ', widget.batch.filename),
              _buildInfoRow('نوع الملف', widget.batch.fileType.toUpperCase()),
              _buildInfoRow('حجم الملف', Formatters.formatFileSize(widget.batch.fileSize)),
              _buildInfoRow('تاريخ الإنشاء', Formatters.formatDate(widget.batch.createdAt)),
              _buildInfoRow('معرف الدفعة', widget.batch.id),
            ]),

            const SizedBox(height: 20),

            if (widget.batch.metadata != null)
              _buildInfoCard('معلومات إضافية', [
                ...widget.batch.metadata!.entries.map((entry) =>
                  _buildInfoRow(entry.key, entry.value.toString())),
              ]),
          ],
        ),
      ),
    );
  }

  /// بناء بطاقة المعلومات
  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AccountantThemeConfig.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AccountantThemeConfig.accentBlue,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  /// بناء صف المعلومات
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: AccountantThemeConfig.white70,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Divider(color: Colors.white.withOpacity(0.1), height: 1),
        ],
      ),
    );
  }

  /// حساب الإحصائيات
  Map<String, dynamic> _calculateStatistics() {
    final totalCartons = widget.batch.items.fold(0, (sum, item) => sum + item.numberOfCartons);
    final totalQuantity = widget.batch.items.fold(0, (sum, item) => sum + item.totalQuantity);
    final uniqueProducts = widget.batch.items.map((item) => item.productName).toSet().length;
    final averageQuantityPerProduct = widget.batch.items.isNotEmpty ? totalQuantity / widget.batch.items.length : 0;
    final averageCartonsPerProduct = widget.batch.items.isNotEmpty ? totalCartons / widget.batch.items.length : 0;

    return {
      'totalItems': widget.batch.items.length,
      'totalCartons': totalCartons,
      'totalQuantity': totalQuantity,
      'uniqueProducts': uniqueProducts,
      'averageQuantityPerProduct': averageQuantityPerProduct.round(),
      'averageCartonsPerProduct': averageCartonsPerProduct.round(),
    };
  }

  /// حساب إحصائيات المنتجات
  Map<String, dynamic> _calculateProductStatistics() {
    final productQuantities = <String, int>{};

    for (final item in widget.batch.items) {
      productQuantities[item.productName] = (productQuantities[item.productName] ?? 0) + item.totalQuantity;
    }

    final sortedProducts = productQuantities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topProducts = sortedProducts.take(5).map((entry) => {
      'name': entry.key,
      'quantity': entry.value,
    }).toList();

    return {
      'topProducts': topProducts,
    };
  }

  /// عرض خيارات المشاركة
  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'مشاركة تفاصيل الحاوية',
              style: AccountantThemeConfig.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(
                Icons.picture_as_pdf,
                color: Colors.red[400],
              ),
              title: const Text(
                'تصدير كـ PDF',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _exportAsPdf();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.table_chart,
                color: Colors.green[400],
              ),
              title: const Text(
                'تصدير كـ Excel',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _exportAsExcel();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.code,
                color: Colors.blue[400],
              ),
              title: const Text(
                'تصدير كـ JSON',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _exportAsJson();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// تصدير كـ PDF
  void _exportAsPdf() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('سيتم تنفيذ تصدير PDF قريباً'),
        backgroundColor: AccountantThemeConfig.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// تصدير كـ Excel
  void _exportAsExcel() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('سيتم تنفيذ تصدير Excel قريباً'),
        backgroundColor: AccountantThemeConfig.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// تصدير كـ JSON
  void _exportAsJson() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('سيتم تنفيذ تصدير JSON قريباً'),
        backgroundColor: AccountantThemeConfig.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
