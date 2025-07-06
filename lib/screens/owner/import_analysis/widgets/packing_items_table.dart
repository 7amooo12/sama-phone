import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/models/import_analysis_models.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/formatters.dart';

/// جدول عناصر قائمة التعبئة مع ترقيم الصفحات والفرز
/// يدعم RTL العربية والتفاعل مع البيانات
class PackingItemsTable extends StatefulWidget {
  final List<PackingListItem> items;
  final int totalPages;
  final int currentPage;
  final Function(int) onPageChanged;
  final Function(int) onItemsPerPageChanged;

  const PackingItemsTable({
    super.key,
    required this.items,
    required this.totalPages,
    required this.currentPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
  });

  @override
  State<PackingItemsTable> createState() => _PackingItemsTableState();
}

class _PackingItemsTableState extends State<PackingItemsTable> {
  String _sortColumn = 'itemNumber';
  bool _sortAscending = true;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(
          AccountantThemeConfig.primaryGreen.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان وأدوات التحكم
          _buildTableHeader(),
          
          // الجدول
          _buildDataTable(),
          
          // ترقيم الصفحات
          _buildPagination(),
        ],
      ),
    ).animate().fadeIn(duration: 700.ms).slideY(begin: 0.3);
  }

  /// بناء رأس الجدول
  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.mainBackgroundGradient,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.table_chart,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            'عناصر قائمة التعبئة',
            style: AccountantThemeConfig.headlineMedium.copyWith(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Text(
            '${widget.items.length} عنصر',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// بناء جدول البيانات
  Widget _buildDataTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortColumnIndex: _getSortColumnIndex(),
        sortAscending: _sortAscending,
        headingRowColor: MaterialStateProperty.all(
          AccountantThemeConfig.primaryGreen.withOpacity(0.1),
        ),
        headingTextStyle: AccountantThemeConfig.bodyMedium.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        dataTextStyle: AccountantThemeConfig.bodyMedium.copyWith(
          fontSize: 11,
        ),
        columnSpacing: 20,
        horizontalMargin: 20,
        columns: [
          DataColumn(
            label: const Text('رقم الصنف'),
            onSort: (columnIndex, ascending) => _sort('itemNumber', ascending),
          ),
          DataColumn(
            label: const Text('الكمية'),
            numeric: true,
            onSort: (columnIndex, ascending) => _sort('totalQuantity', ascending),
          ),
          DataColumn(
            label: const Text('السعر (¥)'),
            numeric: true,
            onSort: (columnIndex, ascending) => _sort('rmbPrice', ascending),
          ),
          DataColumn(
            label: const Text('القيمة الإجمالية'),
            numeric: true,
          ),
          DataColumn(
            label: const Text('التصنيف'),
            onSort: (columnIndex, ascending) => _sort('category', ascending),
          ),
          DataColumn(
            label: const Text('الحالة'),
            onSort: (columnIndex, ascending) => _sort('validationStatus', ascending),
          ),
        ],
        rows: widget.items.map((item) => _buildDataRow(item)).toList(),
      ),
    );
  }

  /// بناء صف البيانات
  DataRow _buildDataRow(PackingListItem item) {
    return DataRow(
      cells: [
        DataCell(
          Container(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              item.itemNumber,
              overflow: TextOverflow.ellipsis,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            AccountantThemeConfig.formatNumber(item.totalQuantity),
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.accentBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        DataCell(
          Text(
            item.rmbPrice != null 
                ? AccountantThemeConfig.formatCurrency(item.rmbPrice!)
                : '-',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.warningOrange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        DataCell(
          Text(
            AccountantThemeConfig.formatCurrency(item.totalRmbValue),
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.successGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getCategoryColor(item.category).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _getCategoryColor(item.category).withOpacity(0.3),
              ),
            ),
            child: Text(
              item.category ?? 'غير مصنف',
              style: TextStyle(
                fontSize: 10,
                color: _getCategoryColor(item.category),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Color(int.parse(
                item.validationStatusInfo.color.replaceAll('#', '0xFF')
              )).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              item.validationStatusInfo.label,
              style: TextStyle(
                fontSize: 10,
                color: Color(int.parse(
                  item.validationStatusInfo.color.replaceAll('#', '0xFF')
                )),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// بناء ترقيم الصفحات
  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          // عدد العناصر في الصفحة
          Text(
            'عرض:',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: 50, // Default value
            underline: const SizedBox(),
            style: AccountantThemeConfig.bodyMedium.copyWith(fontSize: 12),
            items: [25, 50, 100].map((value) {
              return DropdownMenuItem<int>(
                value: value,
                child: Text('$value'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                widget.onItemsPerPageChanged(value);
              }
            },
          ),
          
          const Spacer(),
          
          // أزرار التنقل
          Row(
            children: [
              IconButton(
                onPressed: widget.currentPage > 0 
                    ? () => widget.onPageChanged(widget.currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
                iconSize: 20,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${widget.currentPage + 1} من ${widget.totalPages}',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AccountantThemeConfig.primaryGreen,
                  ),
                ),
              ),
              IconButton(
                onPressed: widget.currentPage < widget.totalPages - 1
                    ? () => widget.onPageChanged(widget.currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
                iconSize: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// بناء الحالة الفارغة
  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد عناصر للعرض',
            style: AccountantThemeConfig.headlineMedium.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ارفع ملف قائمة التعبئة لعرض العناصر هنا',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// الفرز
  void _sort(String column, bool ascending) {
    setState(() {
      _sortColumn = column;
      _sortAscending = ascending;
    });
    // TODO: تنفيذ الفرز في المزود
  }

  /// الحصول على فهرس عمود الفرز
  int _getSortColumnIndex() {
    switch (_sortColumn) {
      case 'itemNumber': return 0;
      case 'totalQuantity': return 1;
      case 'rmbPrice': return 2;
      case 'category': return 4;
      case 'validationStatus': return 5;
      default: return 0;
    }
  }

  /// الحصول على لون التصنيف
  Color _getCategoryColor(String? category) {
    if (category == null) return Colors.grey;
    
    switch (category) {
      case 'إلكترونيات': return AccountantThemeConfig.accentBlue;
      case 'ملابس': return AccountantThemeConfig.warningOrange;
      case 'أدوات منزلية': return AccountantThemeConfig.successGreen;
      case 'ألعاب': return AccountantThemeConfig.dangerRed;
      default: return AccountantThemeConfig.primaryGreen;
    }
  }
}
