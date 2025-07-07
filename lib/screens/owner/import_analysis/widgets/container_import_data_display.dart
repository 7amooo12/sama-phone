/// Container Import Data Display Widget
/// 
/// Professional interface for displaying extracted container import data
/// with comprehensive data handling and edge case management.

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
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildStatisticsCards(),
          _buildFiltersAndControls(),
          Expanded(child: _buildDataTable()),
          if (widget.result?.hasIssues == true) _buildIssuesSection(),
          _buildActionButtons(),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3);
  }

  /// Build header section
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
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
              children: [
                Text(
                  'بيانات استيراد الحاوية',
                  style: AccountantThemeConfig.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'تم استخراج ${widget.items.length} منتج بنجاح',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: AccountantThemeConfig.white70,
                  ),
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
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build statistics cards
  Widget _buildStatisticsCards() {
    final stats = _calculateStatistics();
    
    return Container(
      padding: const EdgeInsets.all(16),
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

  /// Build individual statistics card
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
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AccountantThemeConfig.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().scale(duration: 400.ms);
  }

  /// Build filters and controls
  Widget _buildFiltersAndControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'البحث في المنتجات...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _sortBy,
            onChanged: (value) => setState(() => _sortBy = value!),
            items: const [
              DropdownMenuItem(value: 'productName', child: Text('اسم المنتج')),
              DropdownMenuItem(value: 'cartons', child: Text('عدد الكراتين')),
              DropdownMenuItem(value: 'quantity', child: Text('الكمية')),
            ],
          ),
          IconButton(
            onPressed: () => setState(() => _sortAscending = !_sortAscending),
            icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
          ),
          FilterChip(
            label: const Text('التناقضات فقط'),
            selected: _showOnlyDiscrepancies,
            onSelected: (value) => setState(() => _showOnlyDiscrepancies = value),
          ),
        ],
      ),
    );
  }

  /// Build data table
  Widget _buildDataTable() {
    final filteredItems = _getFilteredAndSortedItems();
    
    if (filteredItems.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3),
          1: FlexColumnWidth(1.5),
          2: FlexColumnWidth(1.5),
          3: FlexColumnWidth(1.5),
          4: FlexColumnWidth(2),
          5: FlexColumnWidth(1),
        },
        children: [
          _buildTableHeader(),
          ...filteredItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildTableRow(item, index);
          }),
        ],
      ),
    );
  }

  /// Build table header
  TableRow _buildTableHeader() {
    return TableRow(
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardBackground1.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      children: [
        _buildHeaderCell('اسم المنتج'),
        _buildHeaderCell('عدد الكراتين'),
        _buildHeaderCell('قطعة/كرتون'),
        _buildHeaderCell('إجمالي الكمية'),
        _buildHeaderCell('ملاحظات'),
        _buildHeaderCell('الحالة'),
      ],
    );
  }

  /// Build header cell
  Widget _buildHeaderCell(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: AccountantThemeConfig.bodyMedium.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Build table row
  TableRow _buildTableRow(ContainerImportItem item, int index) {
    final isEven = index % 2 == 0;
    final hasDiscrepancy = !item.isQuantityConsistent;
    
    return TableRow(
      decoration: BoxDecoration(
        color: hasDiscrepancy 
            ? Colors.red.withOpacity(0.1)
            : isEven 
                ? Colors.grey.withOpacity(0.05)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      children: [
        _buildDataCell(item.productName, isTitle: true),
        _buildDataCell(item.numberOfCartons.toString()),
        _buildDataCell(item.piecesPerCarton.toString()),
        _buildDataCell(Formatters.formatNumber(item.totalQuantity)),
        _buildDataCell(item.remarks.isEmpty ? '-' : item.remarks),
        _buildStatusCell(item),
      ],
    );
  }

  /// Build data cell
  Widget _buildDataCell(String text, {bool isTitle = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: AccountantThemeConfig.bodySmall.copyWith(
          fontWeight: isTitle ? FontWeight.w600 : FontWeight.normal,
          color: isTitle ? Colors.grey[800] : Colors.grey[600],
        ),
        textAlign: isTitle ? TextAlign.start : TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Build status cell
  Widget _buildStatusCell(ContainerImportItem item) {
    final isConsistent = item.isQuantityConsistent;
    
    return Container(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isConsistent ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isConsistent ? Icons.check_circle : Icons.warning,
              size: 16,
              color: isConsistent ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 4),
            Text(
              isConsistent ? 'صحيح' : 'تناقض',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: isConsistent ? Colors.green[700] : Colors.red[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد نتائج مطابقة للبحث',
            style: AccountantThemeConfig.titleMedium.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
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
