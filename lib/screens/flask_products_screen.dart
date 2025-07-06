import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/models/flask_models.dart';
import 'package:smartbiztracker_new/providers/flask_providers.dart';

class FlaskProductsScreen extends StatefulWidget {
  const FlaskProductsScreen({super.key});

  @override
  _FlaskProductsScreenState createState() => _FlaskProductsScreenState();
}

class _FlaskProductsScreenState extends State<FlaskProductsScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FlaskProductsProvider>(context, listen: false).loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterSheet() {
    final productsProvider = Provider.of<FlaskProductsProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تصفية المنتجات',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // In stock only
                  CheckboxListTile(
                    title: const Text('المنتجات المتوفرة فقط'),
                    value: productsProvider.showInStockOnly,
                    onChanged: (value) {
                      setState(() {
                        productsProvider.toggleInStock(value ?? false);
                      });
                    },
                  ),
                  
                  // Has discount only
                  CheckboxListTile(
                    title: const Text('المنتجات ذات الخصم فقط'),
                    value: productsProvider.showDiscountedOnly,
                    onChanged: (value) {
                      setState(() {
                        productsProvider.toggleDiscounted(value ?? false);
                      });
                    },
                  ),
                  
                  // Sort by
                  const Text(
                    'ترتيب حسب:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Sort options
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('الاسم'),
                        selected: productsProvider.sortBy == 'name',
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              productsProvider.sortProducts('name', productsProvider.sortOrder);
                            });
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text('السعر'),
                        selected: productsProvider.sortBy == 'price',
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              productsProvider.sortProducts('price', productsProvider.sortOrder);
                            });
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text('التاريخ'),
                        selected: productsProvider.sortBy == 'date',
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              productsProvider.sortProducts('date', productsProvider.sortOrder);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Sort order
                  const Text(
                    'اتجاه الترتيب:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Sort order options
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('تصاعدي'),
                        selected: productsProvider.sortOrder == 'asc',
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              productsProvider.sortProducts(productsProvider.sortBy, 'asc');
                            });
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text('تنازلي'),
                        selected: productsProvider.sortOrder == 'desc',
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              productsProvider.sortProducts(productsProvider.sortBy, 'desc');
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          productsProvider.resetFilters();
                          Navigator.pop(context);
                        },
                        child: const Text('إعادة تعيين'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text('تم'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'بحث...',
                  border: InputBorder.none,
                ),
                onChanged: (query) {
                  Provider.of<FlaskProductsProvider>(context, listen: false)
                      .updateSearchQuery(query);
                },
                autofocus: true,
              )
            : const Text('المنتجات'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                  Provider.of<FlaskProductsProvider>(context, listen: false)
                      .updateSearchQuery('');
                }
                _isSearching = !_isSearching;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      drawer: Drawer(
        child: Consumer<FlaskAuthProvider>(
          builder: (context, authProvider, child) {
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'متجر SAMA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (authProvider.currentUser != null)
                        Text(
                          authProvider.currentUser!.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.shopping_bag),
                  title: const Text('المنتجات'),
                  selected: true,
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.receipt),
                  title: const Text('الفواتير'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/invoices');
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.exit_to_app),
                  title: const Text('تسجيل الخروج'),
                  onTap: () async {
                    await authProvider.logout();
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                ),
              ],
            );
          },
        ),
      ),
      body: Consumer<FlaskProductsProvider>(
        builder: (context, productsProvider, child) {
          if (productsProvider.status == ProductLoadingStatus.loading && 
              productsProvider.products.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (productsProvider.status == ProductLoadingStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'حدث خطأ أثناء تحميل المنتجات',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(productsProvider.errorMessage ?? 'حاول مرة أخرى'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      productsProvider.loadProducts(forceRefresh: true);
                    },
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }
          
          if (productsProvider.products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.shopping_bag_outlined,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد منتجات متاحة',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('جرب تغيير معايير البحث أو التصفية'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      productsProvider.resetFilters();
                    },
                    child: const Text('إعادة تعيين التصفية'),
                  ),
                ],
              ),
            );
          }
          
          return RefreshIndicator(
            onRefresh: () => productsProvider.loadProducts(forceRefresh: true),
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: productsProvider.products.length,
              itemBuilder: (context, index) {
                final product = productsProvider.products[index];
                return _buildProductCard(context, product);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, FlaskProductModel product) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/product_details',
            arguments: product.id,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(
                              Icons.photo,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                ),
                if (product.isOnSale)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(8),
                        ),
                      ),
                      child: Text(
                        'خصم ${product.discountPercent.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                if (!product.isInStock)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(
                        child: Text(
                          'غير متوفر',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            
            // Product Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Text(
                          '\$${product.displayPrice}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (product.isOnSale)
                          Text(
                            '\$${product.displayOriginalPrice}',
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 