import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/providers/product_provider.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';
import 'package:smartbiztracker_new/widgets/client/product_card.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:smartbiztracker_new/utils/responsive_builder.dart';
import 'package:smartbiztracker_new/widgets/common/responsive_grid_view.dart';
import 'package:smartbiztracker_new/widgets/common/cached_image.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load products on init
      Provider.of<ProductProvider>(context, listen: false).loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, _) {
        // Filter products based on search query
        final filteredProducts = _searchQuery.isEmpty
            ? productProvider.products
            : productProvider.searchProducts(_searchQuery);

        return Stack(
          children: [
            Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'بحث عن منتج...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),

                // Products grid
                Expanded(
                  child: productProvider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : productProvider.error != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 80,
                                    color: Colors.red.withOpacity(0.7),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'حدث خطأ أثناء تحميل المنتجات',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    productProvider.error!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => productProvider.loadProducts(),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('إعادة المحاولة'),
                                  ),
                                ],
                              ),
                            )
                          : filteredProducts.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.shopping_bag_outlined,
                                        size: 80,
                                        color: Colors.grey.withOpacity(0.5),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _searchQuery.isEmpty
                                            ? 'لا توجد منتجات متاحة'
                                            : 'لا توجد نتائج للبحث',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                          : RefreshIndicator(
                              onRefresh: () => productProvider.loadProducts(),
                              child: AnimationLimiter(
                                child: ResponsiveBuilder(
                                  builder: (context, sizeInfo) {
                                    // Determine number of columns based on screen size
                                    int columnCount;
                                    double aspectRatio;

                                    if (sizeInfo.isMobile) {
                                      columnCount = sizeInfo.isPortrait ? 2 : 3;
                                      aspectRatio = 0.75;
                                    } else if (sizeInfo.isTablet) {
                                      columnCount = sizeInfo.isPortrait ? 3 : 4;
                                      aspectRatio = 0.8;
                                    } else {
                                      columnCount = 5;
                                      aspectRatio = 0.85;
                                    }

                                    return GridView.builder(
                                      padding: const EdgeInsets.all(16),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: columnCount,
                                        childAspectRatio: aspectRatio,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                      ),
                                      itemCount: filteredProducts.length,
                                      itemBuilder: (context, index) {
                                        final product = filteredProducts[index];

                                        return AnimationConfiguration.staggeredGrid(
                                          position: index,
                                          duration: const Duration(milliseconds: 375),
                                          columnCount: columnCount,
                                          child: ScaleAnimation(
                                            child: FadeInAnimation(
                                              child: ProductCard(
                                                product: product,
                                                onTap: () => _showProductDetails(product),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                ),
              ],
            ),

            // Loading indicator
            if (productProvider.isLoading) const CustomLoader(),
          ],
        );
      },
    );
  }

  // Show product details dialog
  void _showProductDetails(ProductModel product) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => ResponsiveBuilder(
        builder: (context, sizeInfo) {
          // Adjust dialog size based on screen size
          double maxWidth;
          double maxHeight;

          if (sizeInfo.isMobile) {
            maxWidth = sizeInfo.screenSize.width * 0.9;
            maxHeight = sizeInfo.screenSize.height * 0.8;
          } else if (sizeInfo.isTablet) {
            maxWidth = 500;
            maxHeight = 700;
          } else {
            maxWidth = 600;
            maxHeight = 800;
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Product image
                    SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                          ? Hero(
                              tag: 'product-${product.id}',
                              child: CachedImage(
                                imageUrl: product.imageUrl!,
                                fit: BoxFit.cover,
                                backgroundColor: theme.primaryColor.safeOpacity(0.1),
                                errorWidget: Container(
                                  color: theme.primaryColor.safeOpacity(0.1),
                                  child: Icon(
                                    Icons.shopping_bag,
                                    size: 80,
                                    color: theme.primaryColor,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: theme.primaryColor.safeOpacity(0.1),
                              child: Icon(
                                Icons.shopping_bag,
                                size: 80,
                                color: theme.primaryColor,
                              ),
                            ),
                    ),

                    // Product details
                    Flexible(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      '${product.price} جنيه',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Description
                              const Text(
                                'الوصف:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(product.description.isEmpty
                                  ? 'لا يوجد وصف متاح'
                                  : product.description),
                              const SizedBox(height: 16),

                              // Quantity
                              Row(
                                children: [
                                  const Text(
                                    'الكمية المتاحة:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: product.quantity > 0 ? Colors.green : Colors.red,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      product.quantity.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Actions
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('إغلاق'),
                          ),
                          if (product.quantity > 0)
                            ElevatedButton(
                              onPressed: () {
                                // Add to cart functionality
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('تمت إضافة ${product.name} إلى السلة'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: const Text('إضافة للسلة'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
