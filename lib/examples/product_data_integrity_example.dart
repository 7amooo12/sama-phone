import 'package:flutter/material.dart';
import '../services/product_data_cleanup_service.dart';
import '../utils/api_integration_test_helper.dart';
import '../utils/app_logger.dart';
import '../widgets/warehouse/product_data_quality_widget.dart';

/// مثال على كيفية استخدام ميزات تحسين جودة بيانات المنتجات
class ProductDataIntegrityExample extends StatefulWidget {
  const ProductDataIntegrityExample({super.key});

  @override
  State<ProductDataIntegrityExample> createState() => _ProductDataIntegrityExampleState();
}

class _ProductDataIntegrityExampleState extends State<ProductDataIntegrityExample> {
  final ProductDataCleanupService _cleanupService = ProductDataCleanupService();
  bool _isLoading = false;
  String _statusMessage = 'جاهز للبدء';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مثال على تحسين جودة بيانات المنتجات'),
        backgroundColor: Colors.blue.shade800,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // عنوان القسم
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'أدوات تحسين جودة بيانات المنتجات',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'استخدم هذه الأدوات لتحسين جودة بيانات المنتجات وإصلاح المنتجات العامة',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // حالة النظام
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isLoading ? Icons.hourglass_empty : Icons.info,
                          color: _isLoading ? Colors.orange : Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'حالة النظام',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // أزرار الإجراءات
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الإجراءات المتاحة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // اختبار تكامل APIs
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _runApiIntegrationTest,
                        icon: const Icon(Icons.api),
                        label: const Text('اختبار تكامل APIs'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // فحص جودة البيانات
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _checkDataQuality,
                        icon: const Icon(Icons.assessment),
                        label: const Text('فحص جودة البيانات'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // إصلاح المنتجات العامة
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _cleanupGenericProducts,
                        icon: const Icon(Icons.cleaning_services),
                        label: const Text('إصلاح المنتجات العامة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ويدجت جودة البيانات
            const ProductDataQualityWidget(),
          ],
        ),
      ),
    );
  }

  /// اختبار تكامل APIs
  Future<void> _runApiIntegrationTest() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري اختبار تكامل APIs...';
    });

    try {
      AppLogger.info('🧪 بدء اختبار تكامل APIs...');
      
      final result = await ApiIntegrationTestHelper.runComprehensiveTest();
      
      setState(() {
        _statusMessage = result.overallSuccess 
            ? 'نجح اختبار تكامل APIs ✅'
            : 'فشل اختبار تكامل APIs ❌';
      });

      // عرض النتائج التفصيلية
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('نتائج اختبار تكامل APIs'),
            content: SingleChildScrollView(
              child: Text(
                result.detailedReport,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'خطأ في اختبار APIs: $e';
      });
      AppLogger.error('خطأ في اختبار تكامل APIs: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// فحص جودة البيانات
  Future<void> _checkDataQuality() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري فحص جودة البيانات...';
    });

    try {
      final stats = await _cleanupService.getGenericProductStats();
      
      setState(() {
        _statusMessage = 'تم فحص ${stats.totalProducts} منتج. '
            'المنتجات العامة: ${stats.genericProducts} '
            '(${stats.genericPercentage.toStringAsFixed(1)}%)';
      });

      // عرض الإحصائيات التفصيلية
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('إحصائيات جودة البيانات'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إجمالي المنتجات: ${stats.totalProducts}'),
                Text('المنتجات الحقيقية: ${stats.realProducts}'),
                Text('المنتجات العامة: ${stats.genericProducts}'),
                Text('نسبة المنتجات العامة: ${stats.genericPercentage.toStringAsFixed(1)}%'),
                Text('نسبة المنتجات الحقيقية: ${stats.realPercentage.toStringAsFixed(1)}%'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'خطأ في فحص جودة البيانات: $e';
      });
      AppLogger.error('خطأ في فحص جودة البيانات: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// إصلاح المنتجات العامة
  Future<void> _cleanupGenericProducts() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري إصلاح المنتجات العامة...';
    });

    try {
      final result = await _cleanupService.cleanupGenericProducts();
      
      setState(() {
        _statusMessage = 'تم إصلاح ${result.fixedProducts} منتج من أصل ${result.genericProductsFound} منتج عام. '
            'معدل النجاح: ${result.successRate.toStringAsFixed(1)}%';
      });

      // عرض النتائج التفصيلية
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('نتائج عملية الإصلاح'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('إجمالي المنتجات: ${result.totalProducts}'),
                  Text('المنتجات العامة: ${result.genericProductsFound}'),
                  Text('تم إصلاحها: ${result.fixedProducts}'),
                  Text('فشل في إصلاحها: ${result.failedProducts}'),
                  Text('معدل النجاح: ${result.successRate.toStringAsFixed(1)}%'),
                  if (result.fixedProductsList.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('المنتجات التي تم إصلاحها:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...result.fixedProductsList.take(5).map((product) => Text('• $product')),
                    if (result.fixedProductsList.length > 5)
                      Text('... و ${result.fixedProductsList.length - 5} منتج آخر'),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'خطأ في إصلاح المنتجات: $e';
      });
      AppLogger.error('خطأ في إصلاح المنتجات العامة: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
