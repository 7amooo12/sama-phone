/// Container Import Data Display Widget
/// 
/// Professional interface for displaying extracted container import data
/// with comprehensive data handling and edge case management.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/models/container_import_models.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/formatters.dart';

/// Widget for displaying container import data with professional styling
class ContainerImportDataDisplay extends StatefulWidget {
  final List<ContainerImportItem> items;
  final ContainerImportResult? result;
  final VoidCallback? onExport;
  final VoidCallback? onSave;

  const ContainerImportDataDisplay({
    super.key,
    required this.items,
    this.result,
    this.onExport,
    this.onSave,
  });

  @override
  State<ContainerImportDataDisplay> createState() => _ContainerImportDataDisplayState();
}

class _ContainerImportDataDisplayState extends State<ContainerImportDataDisplay> {
  String _searchQuery = '';
  String _sortBy = 'productName';
  bool _sortAscending = true;
  bool _showOnlyDiscrepancies = false;

  @override
  Widget build(BuildContext context) {
    // Debug logging
    print('🔍 ContainerImportDataDisplay - Building with ${widget.items.length} items');

    if (widget.items.isEmpty) {
      return _buildEmptyDataState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: constraints.maxHeight, // Use available height
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AccountantThemeConfig.cardShadows,
            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fixed height sections
              _buildHeader(),
              _buildStatisticsCards(),
              _buildFiltersAndControls(),

              // Flexible data table section
              Expanded(
                child: _buildDataTable(),
              ),

              // Conditional sections with fixed heights
              if (widget.result?.hasIssues == true)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: _buildIssuesSection(),
                ),

              // Fixed height action buttons
              Container(
                height: 80,
                child: _buildActionButtons(),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3);
      },
    );
  }

  /// Build empty data state
  Widget _buildEmptyDataState() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(Colors.orange.withOpacity(0.3)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.warning_amber,
                size: 64,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد بيانات حاوية للعرض',
              style: AccountantThemeConfig.titleMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'يرجى التأكد من معالجة الملف بشكل صحيح',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build header section with fixed height
  Widget _buildHeader() {
    return Container(
      height: 100, // Fixed height to prevent overflow
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.greenGradient,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.inventory_2,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'بيانات استيراد الحاوية',
                  style: AccountantThemeConfig.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'تم استخراج ${widget.items.length} منتج بنجاح',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: AccountantThemeConfig.white70,
                    fontSize: 14,
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (widget.result != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${(widget.result!.successRate * 100).toStringAsFixed(1)}% نجاح',
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build statistics cards with fixed height
  Widget _buildStatisticsCards() {
    final stats = _calculateStatistics();

    return Container(
      height: 120, // Fixed height to prevent overflow
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
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
    );
  }

  /// Build individual statistics card with proper text rendering
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      height: 96, // Fixed height for consistency
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ).animate().scale(duration: 400.ms);
  }

  /// Build filters and controls with fixed height
  Widget _buildFiltersAndControls() {
    return Container(
      height: 70, // Fixed height to prevent overflow
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardBackground1.withOpacity(0.3),
        border: Border(
          top: BorderSide(color: Colors.grey.withOpacity(0.2)),
          bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              height: 48,
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.3,
                ),
                decoration: InputDecoration(
                  hintText: 'البحث في المنتجات...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    height: 1.3,
                  ),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: DropdownButton<String>(
              value: _sortBy,
              onChanged: (value) => setState(() => _sortBy = value!),
              underline: const SizedBox(),
              style: TextStyle(
                fontSize: 14,
                height: 1.3,
                color: Colors.grey[700],
              ),
              items: const [
                DropdownMenuItem(value: 'productName', child: Text('اسم المنتج')),
                DropdownMenuItem(value: 'cartons', child: Text('عدد الكراتين')),
                DropdownMenuItem(value: 'quantity', child: Text('الكمية')),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: IconButton(
              onPressed: () => setState(() => _sortAscending = !_sortAscending),
              icon: Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 20,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 48,
            child: FilterChip(
              label: Text(
                'التناقضات فقط',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
              selected: _showOnlyDiscrepancies,
              onSelected: (value) => setState(() => _showOnlyDiscrepancies = value),
              backgroundColor: Colors.white,
              selectedColor: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
              checkmarkColor: AccountantThemeConfig.primaryGreen,
              side: BorderSide(color: Colors.grey.withOpacity(0.3)),
            ),
          ),
        ],
      ),
    );
  }

  /// Build data table with proper layout constraints
  Widget _buildDataTable() {
    final filteredItems = _getFilteredAndSortedItems();

    print('🔍 ContainerImportDataDisplay - Filtered items: ${filteredItems.length}');

    if (filteredItems.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Data count header with improved styling
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.table_chart,
                  color: AccountantThemeConfig.primaryGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'عرض ${filteredItems.length} من ${widget.items.length} منتج',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: AccountantThemeConfig.primaryGreen,
                    fontWeight: FontWeight.bold,
                    height: 1.4, // Proper line height
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Properly constrained scrollable data table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildScrollableTable(filteredItems),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build scrollable table with proper constraints
  Widget _buildScrollableTable(List<ContainerImportItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            width: math.max(constraints.maxWidth, 800), // Minimum width for proper display
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: _buildDataTableWidget(items),
            ),
          ),
        );
      },
    );
  }

  /// Build the actual DataTable widget with improved styling
  Widget _buildDataTableWidget(List<ContainerImportItem> items) {
    return DataTable(
      headingRowHeight: 56, // Fixed height for headers
      dataRowHeight: 64, // Fixed height for data rows to prevent overlap
      headingRowColor: MaterialStateProperty.all(
        AccountantThemeConfig.primaryGreen.withOpacity(0.1),
      ),
      headingTextStyle: AccountantThemeConfig.bodyMedium.copyWith(
        color: AccountantThemeConfig.primaryGreen,
        fontWeight: FontWeight.bold,
        fontSize: 14,
        height: 1.3, // Proper line height for Arabic text
      ),
      dataTextStyle: AccountantThemeConfig.bodySmall.copyWith(
        color: Colors.grey[800],
        fontSize: 13,
        height: 1.4, // Proper line height to prevent character stacking
      ),
      columnSpacing: 20, // Increased spacing between columns
      horizontalMargin: 16,
      border: TableBorder.all(
        color: Colors.grey[300]!,
        width: 0.5,
        borderRadius: BorderRadius.circular(8),
      ),
      columns: _buildTableColumns(),
      rows: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return _buildOptimizedDataRow(item, index);
      }).toList(),
    );
  }

  /// Build table columns with proper styling
  List<DataColumn> _buildTableColumns() {
    return [
      DataColumn(
        label: Container(
          width: 180,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'اسم المنتج',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        onSort: (columnIndex, ascending) => _sortTable('productName', ascending),
      ),
      DataColumn(
        label: Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'كراتين',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        numeric: true,
        onSort: (columnIndex, ascending) => _sortTable('cartons', ascending),
      ),
      DataColumn(
        label: Container(
          width: 100,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'قطعة/كرتون',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        numeric: true,
      ),
      DataColumn(
        label: Container(
          width: 100,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'إجمالي الكمية',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        numeric: true,
        onSort: (columnIndex, ascending) => _sortTable('quantity', ascending),
      ),
      DataColumn(
        label: Container(
          width: 120,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'ملاحظات',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      DataColumn(
        label: Container(
          width: 100,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'الحالة',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ];
  }

  /// Build optimized data row with proper text rendering
  DataRow _buildOptimizedDataRow(ContainerImportItem item, int index) {
    final hasDiscrepancy = !item.isQuantityConsistent;

    return DataRow(
      color: MaterialStateProperty.all(
        hasDiscrepancy
            ? Colors.red.withOpacity(0.08)
            : index % 2 == 0
                ? Colors.grey.withOpacity(0.03)
                : Colors.transparent,
      ),
      cells: [
        // Product Name Cell
        DataCell(
          Container(
            width: 180,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Tooltip(
              message: item.productName,
              child: Text(
                item.productName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                  fontSize: 13,
                  height: 1.4, // Proper line height to prevent stacking
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right, // RTL alignment
              ),
            ),
          ),
        ),
        // Number of Cartons Cell
        DataCell(
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            child: Text(
              item.numberOfCartons.toString(),
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // Pieces per Carton Cell
        DataCell(
          Container(
            width: 100,
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            child: Text(
              item.piecesPerCarton.toString(),
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // Total Quantity Cell
        DataCell(
          Container(
            width: 100,
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            child: Text(
              Formatters.formatNumber(item.totalQuantity),
              style: TextStyle(
                color: hasDiscrepancy ? Colors.red[700] : Colors.grey[700],
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // Remarks Cell
        DataCell(
          Container(
            width: 120,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Tooltip(
              message: item.remarks.isEmpty ? 'لا توجد ملاحظات' : item.remarks,
              child: Text(
                item.remarks.isEmpty ? '-' : item.remarks,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right, // RTL alignment
              ),
            ),
          ),
        ),
        // Status Cell
        DataCell(
          Container(
            width: 100,
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            child: _buildStatusChip(item),
          ),
        ),
      ],
    );
  }

  /// Build status chip with proper constraints
  Widget _buildStatusChip(ContainerImportItem item) {
    final isConsistent = item.isQuantityConsistent;

    return Container(
      constraints: const BoxConstraints(
        minWidth: 60,
        maxWidth: 90,
        minHeight: 24,
        maxHeight: 32,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isConsistent ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isConsistent ? Colors.green.withOpacity(0.4) : Colors.red.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isConsistent ? Icons.check_circle_outline : Icons.warning_amber,
            size: 12,
            color: isConsistent ? Colors.green[600] : Colors.red[600],
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              isConsistent ? 'صحيح' : 'تناقض',
              style: TextStyle(
                color: isConsistent ? Colors.green[700] : Colors.red[700],
                fontWeight: FontWeight.w600,
                fontSize: 10,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Sort table by column
  void _sortTable(String column, bool ascending) {
    setState(() {
      _sortBy = column;
      _sortAscending = ascending;
    });
  }



  /// Build empty state
  Widget _buildEmptyState() {
    return Container(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد نتائج مطابقة للبحث',
              style: AccountantThemeConfig.titleMedium.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'جرب تعديل معايير البحث أو الفلاتر',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build issues section
  Widget _buildIssuesSection() {
    if (widget.result?.hasIssues != true) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                'تحذيرات ومشاكل',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.result!.errors.isNotEmpty) ...[
            Text('أخطاء:', style: AccountantThemeConfig.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
            ...widget.result!.errors.map((error) => Text('• $error', style: AccountantThemeConfig.bodySmall)),
          ],
          if (widget.result!.warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('تحذيرات:', style: AccountantThemeConfig.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
            ...widget.result!.warnings.map((warning) => Text('• $warning', style: AccountantThemeConfig.bodySmall)),
          ],
        ],
      ),
    );
  }

  /// Build action buttons
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onExport,
              icon: const Icon(Icons.download),
              label: const Text('تصدير البيانات'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: widget.onSave,
              icon: const Icon(Icons.save),
              label: const Text('حفظ البيانات'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Calculate statistics
  Map<String, dynamic> _calculateStatistics() {
    final totalCartons = widget.items.fold(0, (sum, item) => sum + item.numberOfCartons);
    final totalQuantity = widget.items.fold(0, (sum, item) => sum + item.totalQuantity);
    final uniqueProducts = widget.items.map((item) => item.productName).toSet().length;

    return {
      'totalItems': widget.items.length,
      'totalCartons': totalCartons,
      'totalQuantity': totalQuantity,
      'uniqueProducts': uniqueProducts,
    };
  }

  /// Get filtered and sorted items
  List<ContainerImportItem> _getFilteredAndSortedItems() {
    var items = List<ContainerImportItem>.from(widget.items);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      items = items.where((item) =>
          item.productName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.remarks.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    // Apply discrepancy filter
    if (_showOnlyDiscrepancies) {
      items = items.where((item) => !item.isQuantityConsistent).toList();
    }

    // Apply sorting
    items.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'productName':
          comparison = a.productName.compareTo(b.productName);
          break;
        case 'cartons':
          comparison = a.numberOfCartons.compareTo(b.numberOfCartons);
          break;
        case 'quantity':
          comparison = a.totalQuantity.compareTo(b.totalQuantity);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return items;
  }
}
