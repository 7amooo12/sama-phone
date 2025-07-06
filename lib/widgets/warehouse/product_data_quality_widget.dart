import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/product_data_cleanup_service.dart';
import '../../utils/app_logger.dart';
import '../../config/accountant_theme_config.dart';

/// ويدجت لعرض جودة بيانات المنتجات وخيارات التنظيف
class ProductDataQualityWidget extends StatefulWidget {
  const ProductDataQualityWidget({super.key});

  @override
  State<ProductDataQualityWidget> createState() => _ProductDataQualityWidgetState();
}

class _ProductDataQualityWidgetState extends State<ProductDataQualityWidget> {
  final ProductDataCleanupService _cleanupService = ProductDataCleanupService();
  GenericProductStats? _stats;
  CleanupResult? _lastCleanupResult;
  bool _isLoading = false;
  bool _isCleaningUp = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stats = await _cleanupService.getGenericProductStats();
      setState(() {
        _stats = stats;
      });
    } catch (e) {
      AppLogger.error('خطأ في تحميل إحصائيات المنتجات: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل إحصائيات المنتجات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _performCleanup() async {
    setState(() {
      _isCleaningUp = true;
    });

    try {
      final result = await _cleanupService.cleanupGenericProducts();
      setState(() {
        _lastCleanupResult = result;
      });

      // إعادة تحميل الإحصائيات
      await _loadStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إصلاح ${result.fixedProducts} منتج من أصل ${result.genericProductsFound} منتج عام',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('خطأ في عملية التنظيف: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في عملية التنظيف: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isCleaningUp = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AccountantThemeConfig.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.data_usage,
                    color: AccountantThemeConfig.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'جودة بيانات المنتجات',
                    style: AccountantThemeConfig.headingStyle.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    onPressed: _loadStats,
                    icon: const Icon(Icons.refresh),
                    color: AccountantThemeConfig.primaryColor,
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // الإحصائيات
            if (_stats != null) ...[
              _buildStatsCard(),
              const SizedBox(height: 16),
            ],

            // نتائج آخر عملية تنظيف
            if (_lastCleanupResult != null) ...[
              _buildCleanupResultCard(),
              const SizedBox(height: 16),
            ],

            // أزرار الإجراءات
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isCleaningUp ? null : _performCleanup,
                    icon: _isCleaningUp
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cleaning_services),
                    label: Text(_isCleaningUp ? 'جاري التنظيف...' : 'إصلاح المنتجات العامة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AccountantThemeConfig.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إحصائيات المنتجات',
            style: AccountantThemeConfig.bodyStyle.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'إجمالي المنتجات',
                  _stats!.totalProducts.toString(),
                  Icons.inventory,
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'منتجات حقيقية',
                  _stats!.realProducts.toString(),
                  Icons.verified,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'منتجات عامة',
                  _stats!.genericProducts.toString(),
                  Icons.warning,
                  Colors.orange,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'نسبة المنتجات العامة',
                  '${_stats!.genericPercentage.toStringAsFixed(1)}%',
                  Icons.pie_chart,
                  _stats!.genericPercentage > 20 ? Colors.red : Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: AccountantThemeConfig.bodyStyle.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          Text(
            label,
            style: AccountantThemeConfig.bodyStyle.copyWith(
              fontSize: 12,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCleanupResultCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                'نتائج آخر عملية تنظيف',
                style: AccountantThemeConfig.bodyStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'تم إصلاح ${_lastCleanupResult!.fixedProducts} منتج من أصل ${_lastCleanupResult!.genericProductsFound} منتج عام',
            style: AccountantThemeConfig.bodyStyle.copyWith(fontSize: 14),
          ),
          Text(
            'معدل النجاح: ${_lastCleanupResult!.successRate.toStringAsFixed(1)}%',
            style: AccountantThemeConfig.bodyStyle.copyWith(
              fontSize: 14,
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
