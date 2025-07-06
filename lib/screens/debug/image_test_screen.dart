import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../providers/simplified_product_provider.dart';
import '../../utils/image_test_utility.dart';
import '../../utils/app_logger.dart';
import '../../utils/accountant_theme_config.dart';
import '../../widgets/common/enhanced_product_image.dart';

/// Debug screen for testing image loading functionality
class ImageTestScreen extends StatefulWidget {
  const ImageTestScreen({super.key});

  @override
  State<ImageTestScreen> createState() => _ImageTestScreenState();
}

class _ImageTestScreenState extends State<ImageTestScreen> {
  bool _isLoading = false;
  List<ProductImageTestResult> _testResults = [];
  String _testReport = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Loading Test'),
        backgroundColor: AccountantThemeConfig.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.backgroundGradient,
        ),
        child: Column(
          children: [
            // Test Controls
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: _isLoading ? null : _runImageTest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AccountantThemeConfig.primaryGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: _isLoading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Testing Images...'),
                            ],
                          )
                        : const Text('Test Product Images'),
                  ),
                  if (_testReport.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _testReport,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Test Results
            Expanded(
              child: _testResults.isEmpty
                  ? const Center(
                      child: Text(
                        'Click "Test Product Images" to start testing',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _testResults.length,
                      itemBuilder: (context, index) {
                        final result = _testResults[index];
                        return _buildProductTestCard(result);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductTestCard(ProductImageTestResult result) {
    final hasImages = result.hasAccessibleImages;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
        border: AccountantThemeConfig.glowBorder(
          hasImages ? AccountantThemeConfig.primaryGreen : Colors.red,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Info
            Row(
              children: [
                // Product Image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: EnhancedProductImage(
                      product: result.product,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Product Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.product.name,
                        style: AccountantThemeConfig.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${result.product.id}',
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Status Icon
                Icon(
                  hasImages ? Icons.check_circle : Icons.error,
                  color: hasImages ? AccountantThemeConfig.primaryGreen : Colors.red,
                  size: 24,
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Image Test Results
            Text(
              'Images: ${result.accessibleImageCount}/${result.totalImageCount} accessible',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: hasImages ? AccountantThemeConfig.primaryGreen : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            if (result.imageTests.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...result.imageTests.map((imageTest) => Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      imageTest.isAccessible ? Icons.check : Icons.close,
                      size: 16,
                      color: imageTest.isAccessible ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        imageTest.url,
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!imageTest.isAccessible && imageTest.error != null)
                      Text(
                        imageTest.error!,
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: Colors.red,
                        ),
                      ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _runImageTest() async {
    setState(() {
      _isLoading = true;
      _testResults = [];
      _testReport = '';
    });

    try {
      final productProvider = Provider.of<SimplifiedProductProvider>(context, listen: false);
      
      // Load products if not already loaded
      if (productProvider.products.isEmpty) {
        await productProvider.loadProducts();
      }

      final products = productProvider.products;
      AppLogger.info('🧪 Starting image test for ${products.length} products');

      // Test images for first 10 products
      final results = await ImageTestUtility.testMultipleProducts(products, maxProducts: 10);
      
      // Generate report
      final report = ImageTestUtility.generateTestReport(results);

      setState(() {
        _testResults = results;
        _testReport = report;
      });

      AppLogger.info('✅ Image test completed');
    } catch (e) {
      AppLogger.error('❌ Image test failed: $e');
      setState(() {
        _testReport = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
