import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/providers/import_analysis_provider.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';

/// خطوة مراجعة والتحقق من البيانات - الخطوة الثالثة في سير عمل استيراد الحاوية
class DataReviewStep extends StatefulWidget {
  final ImportAnalysisProvider provider;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const DataReviewStep({
    super.key,
    required this.provider,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<DataReviewStep> createState() => _DataReviewStepState();
}

class _DataReviewStepState extends State<DataReviewStep> {
  String _searchQuery = '';
  bool _showAllColumns = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(),
          const SizedBox(height: 24),
          _buildSearchAndFilters(),
          const SizedBox(height: 16),
          Expanded(
            child: _buildDataTable(),
          ),
          const SizedBox(height: 24),
          _buildActionButtons(),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3);
  }

  /// بناء رأس الخطوة
  Widget _buildStepHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple, Colors.purple.shade700],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: AccountantThemeConfig.glowShadows(Colors.purple),
          ),
          child: const Icon(
            Icons.table_view,
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
                'الخطوة 3: مراجعة والتحقق من البيانات',
                style: AccountantThemeConfig.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'راجع البيانات المستخرجة وتأكد من صحتها',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: AccountantThemeConfig.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// بناء البحث والفلاتر
  Widget _buildSearchAndFilters() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue.withOpacity(0.3)),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                widget.provider.search(value);
              },
              textDirection: TextDirection.rtl,
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: 'البحث برقم الصنف أو الملاحظات...',
                hintStyle: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white54,
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.blueGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AccountantThemeConfig.accentBlue,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: AccountantThemeConfig.cardBackground1.withOpacity(0.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AccountantThemeConfig.cardBackground1.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Switch(
                value: _showAllColumns,
                onChanged: (value) {
                  setState(() {
                    _showAllColumns = value;
                  });
                },
                activeColor: AccountantThemeConfig.primaryGreen,
                inactiveThumbColor: Colors.white70,
                inactiveTrackColor: Colors.white30,
              ),
              const SizedBox(width: 8),
              Text(
                'عرض جميع الأعمدة',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// بناء جدول البيانات
  Widget _buildDataTable() {
    final items = widget.provider.currentItems;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AccountantThemeConfig.cardBackground1.withOpacity(0.3),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.table_rows,
                size: 64,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد بيانات للعرض',
              style: AccountantThemeConfig.titleMedium.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(16),
        color: AccountantThemeConfig.cardBackground1.withOpacity(0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عرض إحصائيات البيانات
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.primaryGreen.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
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
                  'إجمالي البيانات المستخرجة: ${items.length} صف',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // الجدول مع جميع البيانات
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(
                    AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                  ),
                  headingTextStyle: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  dataTextStyle: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white70,
                  ),
                  columns: _buildColumns(),
                  // عرض جميع البيانات بدون حدود
                  rows: items.map((item) => _buildDataRow(item)).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء أعمدة الجدول
  List<DataColumn> _buildColumns() {
    final basicColumns = [
      const DataColumn(label: Text('رقم الصنف')),
      const DataColumn(label: Text('الكمية')),
      const DataColumn(label: Text('كراتين')),
      const DataColumn(label: Text('قطع/كرتون')),
      const DataColumn(label: Text('ملاحظات')),
    ];

    if (_showAllColumns) {
      basicColumns.addAll([
        const DataColumn(label: Text('الأبعاد')),
        const DataColumn(label: Text('الوزن')),
        const DataColumn(label: Text('السعر')),
      ]);
    }

    return basicColumns;
  }

  /// بناء صف البيانات
  DataRow _buildDataRow(dynamic item) {
    final basicCells = [
      DataCell(Text(item.itemNumber ?? '')),
      DataCell(_buildEnhancedQuantityCell(item)),
      DataCell(Text(item.cartonCount?.toString() ?? '')),
      DataCell(Text(item.piecesPerCarton?.toString() ?? '')),
      DataCell(Text(_getRemarks(item))),
    ];

    if (_showAllColumns) {
      basicCells.addAll([
        DataCell(Text(_getDimensions(item))),
        DataCell(Text(_getWeights(item))),
        DataCell(Text(item.rmbPrice?.toString() ?? '')),
      ]);
    }

    return DataRow(cells: basicCells);
  }

  /// بناء خلية الكمية المحسنة مع المواد
  Widget _buildEnhancedQuantityCell(dynamic item) {
    final totalQuantity = item.totalQuantity?.toString() ?? '0';
    final materials = item.materials as List<dynamic>?;

    if (materials == null || materials.isEmpty) {
      return Text(
        totalQuantity,
        style: AccountantThemeConfig.bodyMedium.copyWith(
          color: Colors.white70,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // الكمية الإجمالية
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'إجمالي: $totalQuantity',
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // المواد مع كمياتها - عرض جميع المواد
        ...materials.map((material) {
          final materialName = material.materialName ?? material['material_name'] ?? '';
          final materialQuantity = material.quantity ?? material['quantity'] ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.accentBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${_truncateText(materialName.toString(), 15)} ($materialQuantity)',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.white60,
                fontSize: 10,
              ),
            ),
          );
        }).toList(),
        // إظهار إجمالي عدد المواد
        if (materials.length > 5)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            child: Text(
              'إجمالي ${materials.length} مادة',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.green.withOpacity(0.7),
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  /// اقتطاع النص إلى طول محدد
  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// الحصول على الملاحظات
  String _getRemarks(dynamic item) {
    if (item.remarks != null) {
      final remarks = item.remarks as Map<String, dynamic>;
      return remarks['remarks_a']?.toString() ?? '';
    }
    return '';
  }

  /// الحصول على الأبعاد
  String _getDimensions(dynamic item) {
    if (item.dimensions != null) {
      final dims = item.dimensions as Map<String, dynamic>;
      final size1 = dims['size1']?.toString() ?? '';
      final size2 = dims['size2']?.toString() ?? '';
      final size3 = dims['size3']?.toString() ?? '';
      return '$size1×$size2×$size3';
    }
    return '';
  }

  /// الحصول على الأوزان
  String _getWeights(dynamic item) {
    if (item.weights != null) {
      final weights = item.weights as Map<String, dynamic>;
      final netWeight = weights['net_weight']?.toString() ?? '';
      final grossWeight = weights['gross_weight']?.toString() ?? '';
      return '$netWeight/$grossWeight';
    }
    return '';
  }

  /// بناء أزرار الإجراءات
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.white70),
            ),
            child: OutlinedButton(
              onPressed: widget.onBack,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: BorderSide.none,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'السابق',
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.greenGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: ElevatedButton(
              onPressed: widget.onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'التالي',
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
