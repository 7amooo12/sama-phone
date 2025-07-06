import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/config/theme/accountant_theme_config.dart';

/// ويدجت عرض التقرير المحسن للتحليل الذكي
class EnhancedSummaryWidget extends StatelessWidget {
  final Map<String, dynamic> enhancedSummary;
  final Map<String, dynamic>? validationReport;

  const EnhancedSummaryWidget({
    Key? key,
    required this.enhancedSummary,
    this.validationReport,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverviewSection(),
          const SizedBox(height: 16),
          _buildProductAnalysisSection(),
          const SizedBox(height: 16),
          _buildMaterialAnalysisSection(),
          const SizedBox(height: 16),
          _buildQualityMetricsSection(),
          if (validationReport != null) ...[
            const SizedBox(height: 16),
            _buildValidationSection(),
          ],
          const SizedBox(height: 16),
          _buildRecommendationsSection(),
        ],
      ),
    );
  }

  Widget _buildOverviewSection() {
    final overview = enhancedSummary['overview'] as Map<String, dynamic>? ?? {};
    
    return _buildSectionCard(
      title: 'نظرة عامة',
      icon: Icons.dashboard_outlined,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'المنتجات الفريدة',
                  overview['total_unique_products']?.toString() ?? '0',
                  Icons.inventory_2,
                  AccountantThemeConfig.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'المواد المستخرجة',
                  overview['total_materials_extracted']?.toString() ?? '0',
                  Icons.science,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'الكمية الإجمالية',
                  overview['total_quantity']?.toString() ?? '0',
                  Icons.straighten,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'معدل استخراج المواد',
                  '${overview['material_extraction_rate']?.toString() ?? '0'}%',
                  Icons.analytics,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductAnalysisSection() {
    final productAnalysis = enhancedSummary['product_analysis'] as Map<String, dynamic>? ?? {};
    final topProducts = productAnalysis['top_products_by_quantity'] as List<dynamic>? ?? [];
    
    return _buildSectionCard(
      title: 'تحليل المنتجات',
      icon: Icons.bar_chart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'أعلى المنتجات كمية',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AccountantThemeConfig.textPrimaryColor,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 8),
          ...topProducts.map((product) => _buildProductItem(product)),
        ],
      ),
    );
  }

  Widget _buildMaterialAnalysisSection() {
    final materialAnalysis = enhancedSummary['material_analysis'] as Map<String, dynamic>? ?? {};
    final topMaterials = materialAnalysis['top_materials_by_frequency'] as List<dynamic>? ?? [];
    final categories = materialAnalysis['material_categories'] as Map<String, dynamic>? ?? {};
    
    return _buildSectionCard(
      title: 'تحليل المواد',
      icon: Icons.category,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // فئات المواد
          if (categories.isNotEmpty) ...[
            Text(
              'فئات المواد',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AccountantThemeConfig.textPrimaryColor,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: categories.entries.map((entry) => 
                _buildCategoryChip(entry.key, entry.value)
              ).toList(),
            ),
            const SizedBox(height: 16),
          ],
          
          // أكثر المواد تكراراً
          Text(
            'أكثر المواد تكراراً',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AccountantThemeConfig.textPrimaryColor,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 8),
          ...topMaterials.map((material) => _buildMaterialItem(material)),
        ],
      ),
    );
  }

  Widget _buildQualityMetricsSection() {
    final qualityMetrics = enhancedSummary['quality_metrics'] as Map<String, dynamic>? ?? {};
    
    return _buildSectionCard(
      title: 'مقاييس الجودة',
      icon: Icons.verified,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildQualityMetric(
                  'متوسط الثقة',
                  '${qualityMetrics['average_grouping_confidence']?.toString() ?? '0'}%',
                  Icons.trending_up,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQualityMetric(
                  'نقاط الجودة',
                  qualityMetrics['data_quality_score']?.toString() ?? '0',
                  Icons.star,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQualityMetric(
                  'مجموعات عالية الثقة',
                  qualityMetrics['high_confidence_groups']?.toString() ?? '0',
                  Icons.check_circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQualityMetric(
                  'مجموعات منخفضة الثقة',
                  qualityMetrics['low_confidence_groups']?.toString() ?? '0',
                  Icons.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValidationSection() {
    final validation = validationReport!;
    
    return _buildSectionCard(
      title: 'تقرير التحقق',
      icon: Icons.fact_check,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildValidationMetric(
                  'مجموعات صحيحة',
                  validation['valid_groups']?.toString() ?? '0',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildValidationMetric(
                  'مجموعات غير صحيحة',
                  validation['invalid_groups']?.toString() ?? '0',
                  Icons.error,
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildValidationMetric(
                  'تحذيرات',
                  validation['warning_groups']?.toString() ?? '0',
                  Icons.warning,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildValidationMetric(
                  'الحالة العامة',
                  validation['is_overall_valid'] == true ? 'صحيح' : 'يحتاج مراجعة',
                  validation['is_overall_valid'] == true ? Icons.verified : Icons.info,
                  validation['is_overall_valid'] == true ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    final recommendations = enhancedSummary['recommendations'] as List<dynamic>? ?? [];
    
    if (recommendations.isEmpty) return const SizedBox.shrink();
    
    return _buildSectionCard(
      title: 'التوصيات',
      icon: Icons.lightbulb_outline,
      child: Column(
        children: recommendations.map((rec) => _buildRecommendationItem(rec)).toList(),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.primaryColor.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: AccountantThemeConfig.primaryColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: AccountantThemeConfig.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AccountantThemeConfig.textPrimaryColor,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AccountantThemeConfig.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> product) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              product['item_number']?.toString() ?? '',
              style: const TextStyle(
                fontSize: 12,
                color: AccountantThemeConfig.textPrimaryColor,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              product['total_quantity']?.toString() ?? '0',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AccountantThemeConfig.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialItem(Map<String, dynamic> material) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              material['material_name']?.toString() ?? '',
              style: const TextStyle(
                fontSize: 12,
                color: AccountantThemeConfig.textPrimaryColor,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${material['frequency']} (${material['percentage']}%)',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category, dynamic count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.primaryColor.withOpacity(0.3),
        ),
      ),
      child: Text(
        '$category ($count)',
        style: TextStyle(
          fontSize: 11,
          color: AccountantThemeConfig.primaryColor,
        ),
        textDirection: TextDirection.rtl,
      ),
    );
  }

  Widget _buildQualityMetric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AccountantThemeConfig.primaryColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: AccountantThemeConfig.primaryColor, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AccountantThemeConfig.primaryColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AccountantThemeConfig.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  Widget _buildValidationMetric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AccountantThemeConfig.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(Map<String, dynamic> recommendation) {
    final type = recommendation['type']?.toString() ?? '';
    final title = recommendation['title']?.toString() ?? '';
    final description = recommendation['description']?.toString() ?? '';
    final priority = recommendation['priority']?.toString() ?? '';
    
    Color color;
    IconData icon;
    
    switch (type) {
      case 'تحذير':
        color = Colors.red;
        icon = Icons.warning;
        break;
      case 'تحسين':
        color = Colors.orange;
        icon = Icons.lightbulb;
        break;
      default:
        color = Colors.blue;
        icon = Icons.info;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: AccountantThemeConfig.textSecondaryColor,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              priority,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }
}
