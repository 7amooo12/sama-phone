import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/services/import_analysis/currency_conversion_service.dart';

/// Smart Summary Widget for Import Analysis
/// Displays comprehensive summary with totals, REMARKS grouping, and export functionality
class SmartSummaryWidget extends StatefulWidget {
  final Map<String, dynamic> smartSummary;
  final VoidCallback? onExportJson;

  const SmartSummaryWidget({
    super.key,
    required this.smartSummary,
    this.onExportJson,
  });

  @override
  State<SmartSummaryWidget> createState() => _SmartSummaryWidgetState();
}

class _SmartSummaryWidgetState extends State<SmartSummaryWidget> {
  bool _showEgpConversion = false;
  Map<String, double>? _convertedTotals;

  @override
  void initState() {
    super.initState();
    _loadCurrencyConversion();
  }

  Future<void> _loadCurrencyConversion() async {
    try {
      final totals = widget.smartSummary['totals'] as Map<String, dynamic>;
      final rmbAmount = (totals['RMB'] as num?)?.toDouble() ?? 0.0;
      final priceAmount = (totals['PRICE'] as num?)?.toDouble() ?? 0.0;
      
      if (rmbAmount > 0 || priceAmount > 0) {
        final convertedRmb = await CurrencyConversionService.convertRmbToEgp(rmbAmount);
        final convertedPrice = await CurrencyConversionService.convertRmbToEgp(priceAmount);
        
        setState(() {
          _convertedTotals = {
            'RMB_EGP': convertedRmb,
            'PRICE_EGP': convertedPrice,
          };
        });
      }
    } catch (e) {
      // Handle conversion error silently
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(
          AccountantThemeConfig.primaryGreen.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const Divider(height: 1),
          _buildTotalsSection(),
          const Divider(height: 1),
          _buildRemarksSection(),
          const Divider(height: 1),
          _buildProductsSection(),
          const Divider(height: 1),
          _buildExportSection(),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3);
  }

  Widget _buildHeader() {
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.analytics,
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
                  'التقرير الذكي الشامل',
                  style: AccountantThemeConfig.headlineMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'تحليل متقدم للبيانات مع تجميع ذكي للملاحظات',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          if (widget.onExportJson != null)
            IconButton(
              onPressed: widget.onExportJson,
              icon: const Icon(Icons.download, color: Colors.white),
              tooltip: 'تصدير JSON',
            ),
        ],
      ),
    );
  }

  Widget _buildTotalsSection() {
    final totals = widget.smartSummary['totals'] as Map<String, dynamic>;
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calculate,
                color: AccountantThemeConfig.primaryGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'الإجماليات الرقمية',
                style: AccountantThemeConfig.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_convertedTotals != null)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showEgpConversion = !_showEgpConversion;
                    });
                  },
                  icon: Icon(
                    _showEgpConversion ? Icons.visibility_off : Icons.visibility,
                    size: 16,
                  ),
                  label: Text(_showEgpConversion ? 'إخفاء EGP' : 'عرض EGP'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTotalsGrid(totals),
        ],
      ),
    );
  }

  Widget _buildTotalsGrid(Map<String, dynamic> totals) {
    final items = [
      {'label': 'إجمالي الكراتين', 'value': totals['ctn'], 'unit': 'كرتون'},
      {'label': 'قطع/كرتون', 'value': totals['pc_ctn'], 'unit': 'قطعة'},
      {'label': 'إجمالي الكمية', 'value': totals['QTY'], 'unit': 'قطعة'},
      {'label': 'إجمالي الحجم', 'value': totals['t_cbm'], 'unit': 'م³'},
      {'label': 'الوزن الصافي', 'value': totals['N_W'], 'unit': 'كجم'},
      {'label': 'الوزن الإجمالي', 'value': totals['G_W'], 'unit': 'كجم'},
      {'label': 'إجمالي الوزن الصافي', 'value': totals['T_NW'], 'unit': 'كجم'},
      {'label': 'إجمالي الوزن الإجمالي', 'value': totals['T_GW'], 'unit': 'كجم'},
      {'label': 'إجمالي السعر', 'value': totals['PRICE'], 'unit': 'وحدة'},
      {'label': 'إجمالي RMB', 'value': totals['RMB'], 'unit': '¥'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildTotalCard(
          item['label'] as String,
          item['value'],
          item['unit'] as String,
        );
      },
    );
  }

  Widget _buildTotalCard(String label, dynamic value, String unit) {
    final displayValue = value is num ? value : 0;
    final formattedValue = displayValue is double 
        ? displayValue.toStringAsFixed(2)
        : displayValue.toString();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  formattedValue,
                  style: AccountantThemeConfig.headlineMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AccountantThemeConfig.primaryGreen,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                unit,
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          if (_showEgpConversion && _convertedTotals != null && 
              (label.contains('RMB') || label.contains('السعر')))
            Text(
              _getEgpConversion(label),
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: AccountantThemeConfig.warningOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  String _getEgpConversion(String label) {
    if (_convertedTotals == null) return '';
    
    if (label.contains('RMB')) {
      final egpValue = _convertedTotals!['RMB_EGP'] ?? 0.0;
      return '${egpValue.toStringAsFixed(2)} ج.م';
    } else if (label.contains('السعر')) {
      final egpValue = _convertedTotals!['PRICE_EGP'] ?? 0.0;
      return '${egpValue.toStringAsFixed(2)} ج.م';
    }
    
    return '';
  }

  Widget _buildRemarksSection() {
    final remarksSummary = widget.smartSummary['remarks_summary'] as List<dynamic>? ?? [];
    
    if (remarksSummary.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.comment,
                color: AccountantThemeConfig.accentBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'ملخص الملاحظات (مجمعة حسب الكمية)',
                style: AccountantThemeConfig.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...remarksSummary.take(10).map((remark) => _buildRemarkItem(remark)),
          if (remarksSummary.length > 10)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'و ${remarksSummary.length - 10} ملاحظات أخرى...',
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRemarkItem(dynamic remark) {
    final text = remark['text'] as String? ?? '';
    final qty = remark['qty'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AccountantThemeConfig.accentBlue.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: AccountantThemeConfig.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.accentBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$qty',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AccountantThemeConfig.accentBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSection() {
    final products = widget.smartSummary['products'] as List<dynamic>? ?? [];
    
    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.inventory,
                color: AccountantThemeConfig.warningOrange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'ملخص المنتجات (${products.length} منتج)',
                style: AccountantThemeConfig.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'إجمالي المنتجات المختلفة: ${products.length}',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'إجمالي الكمية: ${products.fold(0, (sum, product) => sum + (product['total_qty'] as int? ?? 0))}',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(
            Icons.file_download,
            color: AccountantThemeConfig.successGreen,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'تصدير البيانات',
            style: AccountantThemeConfig.headlineMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: widget.onExportJson,
            icon: const Icon(Icons.code),
            label: const Text('تصدير JSON'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.successGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
