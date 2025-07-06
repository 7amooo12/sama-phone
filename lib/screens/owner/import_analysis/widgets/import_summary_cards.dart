import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/models/import_analysis_models.dart';
import 'package:smartbiztracker_new/services/import_analysis/packing_analyzer_service.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';

/// بطاقات ملخص الاستيراد مع الإحصائيات والتحليلات المالية
/// تعرض البيانات الرئيسية بتصميم احترافي مع دعم RTL العربية
class ImportSummaryCards extends StatelessWidget {
  final PackingListStatistics statistics;
  final ImportBatch batch;

  const ImportSummaryCards({
    super.key,
    required this.statistics,
    required this.batch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان القسم
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'ملخص الاستيراد',
              style: AccountantThemeConfig.headlineMedium.copyWith(
                fontSize: 18,
              ),
            ),
          ),
          
          // الصف الأول - الإحصائيات الأساسية
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'إجمالي العناصر',
                  value: statistics.totalItems.toString(),
                  subtitle: '${statistics.validItems} صحيح',
                  icon: Icons.inventory_2,
                  color: AccountantThemeConfig.primaryGreen,
                  gradient: AccountantThemeConfig.mainBackgroundGradient,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'إجمالي الكمية',
                  value: _formatNumber(statistics.quantityStatistics.sum),
                  subtitle: 'قطعة',
                  icon: Icons.widgets,
                  color: AccountantThemeConfig.accentBlue,
                  gradient: AccountantThemeConfig.blueGradient,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // الصف الثاني - البيانات المالية
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'القيمة الإجمالية',
                  value: _formatCurrency(statistics.priceStatistics?.sum ?? 0.0),
                  subtitle: 'يوان صيني',
                  icon: Icons.monetization_on,
                  color: AccountantThemeConfig.warningOrange,
                  gradient: AccountantThemeConfig.orangeGradient,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'متوسط السعر',
                  value: _formatCurrency(statistics.priceStatistics?.average ?? 0.0),
                  subtitle: 'لكل قطعة',
                  icon: Icons.trending_up,
                  color: AccountantThemeConfig.successGreen,
                  gradient: LinearGradient(
                    colors: [
                      AccountantThemeConfig.successGreen,
                      AccountantThemeConfig.primaryGreen,
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // الصف الثالث - جودة البيانات والتصنيفات
          Row(
            children: [
              Expanded(
                child: _buildQualityCard(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCategoriesCard(),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // بطاقة تفاصيل الملف
          _buildFileDetailsCard(),
        ],
      ),
    );
  }

  /// بناء بطاقة إحصائية
  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الأيقونة والعنوان
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: AccountantThemeConfig.glowShadows(color),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // القيمة
          Text(
            value,
            style: AccountantThemeConfig.headlineMedium.copyWith(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),

          // النص الفرعي
          Text(
            subtitle,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              fontSize: 11,
              color: AccountantThemeConfig.white70,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.3);
  }

  /// بناء بطاقة جودة البيانات
  Widget _buildQualityCard() {
    final quality = statistics.qualityAnalysis;
    final score = quality.completenessScore;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(
          Color(int.parse(quality.qualityColor.replaceAll('#', '0xFF'))).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان والنتيجة
          Row(
            children: [
              Icon(
                Icons.verified,
                color: Color(int.parse(quality.qualityColor.replaceAll('#', '0xFF'))),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'جودة البيانات',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  fontSize: 12,
                  color: AccountantThemeConfig.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // النتيجة
          Text(
            '${score.toInt()}%',
            style: AccountantThemeConfig.headlineMedium.copyWith(
              fontSize: 24,
              color: Color(int.parse(quality.qualityColor.replaceAll('#', '0xFF'))),
              fontWeight: FontWeight.bold,
            ),
          ),
          
          // التقييم
          Text(
            quality.qualityGrade,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              fontSize: 11,
              color: AccountantThemeConfig.white70,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // شريط التقدم
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                Color(int.parse(quality.qualityColor.replaceAll('#', '0xFF'))),
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideX(begin: 0.3);
  }

  /// بناء بطاقة التصنيفات
  Widget _buildCategoriesCard() {
    final categoriesCount = statistics.categoryBreakdown.length;
    final topCategory = statistics.categoryBreakdown.entries
        .reduce((a, b) => a.value.itemCount > b.value.itemCount ? a : b);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(
          AccountantThemeConfig.accentBlue.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان
          Row(
            children: [
              Icon(
                Icons.category,
                color: AccountantThemeConfig.accentBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'التصنيفات',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // عدد التصنيفات
          Text(
            categoriesCount.toString(),
            style: AccountantThemeConfig.headlineMedium.copyWith(
              fontSize: 24,
              color: AccountantThemeConfig.accentBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          // التصنيف الأكثر
          Text(
            'تصنيف مختلف',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // التصنيف الأعلى
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.accentBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              topCategory.key,
              style: TextStyle(
                fontSize: 10,
                color: AccountantThemeConfig.accentBlue,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideX(begin: 0.3);
  }

  /// بناء بطاقة تفاصيل الملف
  Widget _buildFileDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(
          AccountantThemeConfig.primaryGreen.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان
          Row(
            children: [
              Icon(
                Icons.description,
                color: AccountantThemeConfig.primaryGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'تفاصيل الملف',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // تفاصيل الملف
          Row(
            children: [
              Expanded(
                child: _buildFileDetail('اسم الملف', batch.originalFilename),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFileDetail('حجم الملف', batch.formattedFileSize),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Row(
            children: [
              Expanded(
                child: _buildFileDetail('نوع الملف', batch.fileType.toUpperCase()),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFileDetail(
                  'تاريخ الرفع',
                  AccountantThemeConfig.formatDate(batch.createdAt),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 700.ms).slideY(begin: 0.3);
  }

  /// بناء تفصيل الملف
  Widget _buildFileDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AccountantThemeConfig.bodyMedium.copyWith(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AccountantThemeConfig.bodyMedium.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// تنسيق الأرقام
  String _formatNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}م';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}ك';
    } else {
      return number.toInt().toString();
    }
  }

  /// تنسيق العملة
  String _formatCurrency(double amount) {
    return AccountantThemeConfig.formatCurrency(amount);
  }
}
