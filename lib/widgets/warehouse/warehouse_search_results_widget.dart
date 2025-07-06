/// ودجت نتائج البحث في المخازن
/// Widget for displaying warehouse search results

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartbiztracker_new/models/warehouse_search_models.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

class WarehouseSearchResultsWidget extends StatefulWidget {
  final WarehouseSearchResults searchResults;
  final VoidCallback? onLoadMore;
  final bool isLoadingMore;

  const WarehouseSearchResultsWidget({
    super.key,
    required this.searchResults,
    this.onLoadMore,
    this.isLoadingMore = false,
  });

  @override
  State<WarehouseSearchResultsWidget> createState() => _WarehouseSearchResultsWidgetState();
}

class _WarehouseSearchResultsWidgetState extends State<WarehouseSearchResultsWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (widget.onLoadMore != null && !widget.isLoadingMore) {
        widget.onLoadMore!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // إحصائيات البحث
        _buildSearchStats(),
        
        // النتائج
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              // نتائج المنتجات
              if (widget.searchResults.productResults.isNotEmpty) ...[
                _buildSectionHeader(
                  'المنتجات (${widget.searchResults.productResults.length})',
                  Icons.inventory_2_outlined,
                ),
                const SizedBox(height: 12),
                ...widget.searchResults.productResults.map((product) => 
                  _buildProductCard(product)
                ),
                const SizedBox(height: 24),
              ],
              
              // نتائج الفئات
              if (widget.searchResults.categoryResults.isNotEmpty) ...[
                _buildSectionHeader(
                  'الفئات (${widget.searchResults.categoryResults.length})',
                  Icons.category_outlined,
                ),
                const SizedBox(height: 12),
                ...widget.searchResults.categoryResults.map((category) => 
                  _buildCategoryCard(category)
                ),
                const SizedBox(height: 24),
              ],
              
              // مؤشر تحميل المزيد
              if (widget.isLoadingMore)
                _buildLoadMoreIndicator(),
              
              // مساحة إضافية في النهاية
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }

  /// بناء إحصائيات البحث
  Widget _buildSearchStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.analytics_outlined,
            color: AccountantThemeConfig.primaryGreen,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'تم العثور على ${widget.searchResults.totalResults} نتيجة في ${widget.searchResults.searchDuration.inMilliseconds}ms',
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (widget.searchResults.hasMore)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'المزيد متاح',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AccountantThemeConfig.accentBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// بناء عنوان القسم
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.greenGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AccountantThemeConfig.primaryGreen.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// بناء بطاقة المنتج
  Widget _buildProductCard(ProductSearchResult product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
        boxShadow: [
          BoxShadow(
            color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.greenGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: product.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    product.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.inventory_2,
                      color: Colors.white,
                    ),
                  ),
                )
              : const Icon(
                  Icons.inventory_2,
                  color: Colors.white,
                ),
        ),
        title: Text(
          product.productName,
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (product.productSku != null)
              Text(
                'SKU: ${product.productSku}',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AccountantThemeConfig.accentBlue,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AccountantThemeConfig.cardBackground2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    product.categoryName,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(int.parse('0xFF${product.stockStatusColor.substring(1)}')),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${product.totalQuantity} ${product.stockStatusText}',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          _buildWarehouseBreakdown(product.warehouseBreakdown),
        ],
      ),
    );
  }

  /// بناء تفصيل المخازن
  Widget _buildWarehouseBreakdown(List<WarehouseInventory> warehouses) {
    if (warehouses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AccountantThemeConfig.cardBackground2,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'لا توجد تفاصيل مخازن متاحة',
          style: GoogleFonts.cairo(
            fontSize: 14,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'توزيع المخازن (${warehouses.length})',
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AccountantThemeConfig.primaryGreen,
          ),
        ),
        const SizedBox(height: 8),
        ...warehouses.map((warehouse) => _buildWarehouseRow(warehouse)),
      ],
    );
  }

  /// بناء صف المخزن
  Widget _buildWarehouseRow(WarehouseInventory warehouse) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardBackground2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Color(int.parse('0xFF${warehouse.stockStatusColor.substring(1)}')).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warehouse,
            color: Color(int.parse('0xFF${warehouse.stockStatusColor.substring(1)}')),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  warehouse.warehouseName,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (warehouse.warehouseLocation != null)
                  Text(
                    warehouse.warehouseLocation!,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: Colors.white60,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Color(int.parse('0xFF${warehouse.stockStatusColor.substring(1)}')),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${warehouse.quantity}',
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء بطاقة الفئة
  Widget _buildCategoryCard(CategorySearchResult category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.blueGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.category,
            color: Colors.white,
          ),
        ),
        title: Text(
          category.categoryName,
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${category.productCount} منتج',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'إجمالي: ${category.totalQuantity}',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AccountantThemeConfig.primaryGreen,
                  ),
                ),
                if (category.totalValue != null) ...[
                  const SizedBox(width: 16),
                  Text(
                    'القيمة: ${category.totalValue!.toStringAsFixed(2)} جنيه',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: AccountantThemeConfig.accentBlue,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        children: [
          if (category.products.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المنتجات في هذه الفئة:',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AccountantThemeConfig.accentBlue,
                  ),
                ),
                const SizedBox(height: 8),
                ...category.products.take(3).map((product) => 
                  _buildCategoryProductRow(product)
                ),
                if (category.products.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'و ${category.products.length - 3} منتج آخر...',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: Colors.white60,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// بناء صف منتج في الفئة
  Widget _buildCategoryProductRow(ProductSearchResult product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardBackground2,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: AccountantThemeConfig.primaryGreen,
            size: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              product.productName,
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
          Text(
            '${product.totalQuantity}',
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: Color(int.parse('0xFF${product.stockStatusColor.substring(1)}')),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// بناء مؤشر تحميل المزيد
  Widget _buildLoadMoreIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              AccountantThemeConfig.primaryGreen,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'جاري تحميل المزيد...',
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
