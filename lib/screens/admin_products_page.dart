import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/flask_product_model.dart';
import 'package:smartbiztracker_new/services/flask_api_service.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({super.key});

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  late Future<List<FlaskProductModel>> _productsFuture;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() {
    final apiService = FlaskApiService();
    _productsFuture = apiService.getAllProducts();
  }

  void _toggleView() {
    setState(() {
      _isGridView = !_isGridView;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة المنتجات'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
              onPressed: _toggleView,
              tooltip: _isGridView ? 'عرض قائمة' : 'عرض شبكة',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _loadProducts();
                });
              },
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: FutureBuilder<List<FlaskProductModel>>(
          future: _productsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'حدث خطأ أثناء تحميل المنتجات',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Text('${snapshot.error}'),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _loadProducts();
                        });
                      },
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text('لا توجد منتجات متاحة'),
              );
            }

            final products = snapshot.data!;
            
            if (_isGridView) {
              return _buildProductsGrid(products);
            } else {
              return _buildProductsList(products);
            }
          },
        ),
      ),
    );
  }

  Widget _buildProductsGrid(List<FlaskProductModel> products) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: MasonryGridView.count(
        crossAxisCount: MediaQuery.of(context).size.width > 1000 ? 4 : 
                      MediaQuery.of(context).size.width > 600 ? 3 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return _buildProductCard(product);
        },
      ),
    );
  }

  Widget _buildProductsList(List<FlaskProductModel> products) {
    return ListView.separated(
      itemCount: products.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductListTile(product);
      },
    );
  }

  Widget _buildProductCard(FlaskProductModel product) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: product.isVisible ? Colors.transparent : Colors.red.shade200,
          width: product.isVisible ? 0 : 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Product Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: product.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey.shade200,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image_not_supported, size: 50),
                    ),
                  )
                : Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image, size: 50),
                  ),
            ),
          ),
          
          // Product Details
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and Status
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (product.featured)
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Icon(
                      product.isVisible ? Icons.visibility : Icons.visibility_off,
                      color: product.isVisible ? Colors.green : Colors.red,
                      size: 20,
                    ),
                  ],
                ),
                
                const SizedBox(height: 6),
                
                // Category
                if (product.categoryName != null && product.categoryName!.isNotEmpty)
                  Text(
                    product.categoryName!,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                
                const SizedBox(height: 8),
                
                // Description
                Text(
                  product.description,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 12),
                
                // Prices
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (product.isOnSale)
                          Text(
                            product.displayOriginalPrice,
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        Text(
                          product.displayPrice,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: product.isOnSale ? 18 : 16,
                            color: product.isOnSale ? Colors.red : null,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (product.stockQuantity > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'متوفر: ${product.stockQuantity}',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'غير متوفر',
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                
                if (product.isOnSale)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'تخفيض: ${product.displayDiscount}',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                
                const SizedBox(height: 8),
                
                // Purchase Price and Selling Price (Admin Only)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'سعر الشراء: ${product.purchasePrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'سعر البيع: ${product.sellingPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductListTile(FlaskProductModel product) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: SizedBox(
        width: 60,
        height: 60,
        child: product.imageUrl != null && product.imageUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: product.imageUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey.shade200,
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey.shade200,
                child: const Icon(Icons.image_not_supported),
              ),
            )
          : Container(
              color: Colors.grey.shade200,
              child: const Icon(Icons.image),
            ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          if (product.featured)
            const Icon(Icons.star, color: Colors.amber, size: 18),
          const SizedBox(width: 4),
          Icon(
            product.isVisible ? Icons.visibility : Icons.visibility_off,
            color: product.isVisible ? Colors.green : Colors.red,
            size: 18,
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'الفئة: ${product.categoryName ?? 'غير مصنف'}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const Spacer(),
              Text(
                'المخزون: ${product.stockQuantity}',
                style: TextStyle(
                  color: product.stockQuantity > 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (product.isOnSale)
                Text(
                  '${product.displayOriginalPrice} → ${product.displayPrice}',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                )
              else
                Text(
                  product.displayPrice,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              const SizedBox(width: 8),
              if (product.isOnSale)
                Text(
                  'خصم: ${product.displayDiscount}',
                  style: const TextStyle(color: Colors.red),
                ),
              const Spacer(),
              Text(
                'الشراء: ${product.purchasePrice.toStringAsFixed(2)}',
                style: TextStyle(color: Colors.blue.shade700),
              ),
              const SizedBox(width: 8),
              Text(
                'البيع: ${product.sellingPrice.toStringAsFixed(2)}',
                style: TextStyle(color: Colors.green.shade700),
              ),
            ],
          ),
        ],
      ),
      onTap: () {
        // Product detail view could be implemented here
      },
    );
  }
} 