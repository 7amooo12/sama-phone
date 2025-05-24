import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/providers/product_provider.dart';
import 'package:smartbiztracker_new/widgets/common/advanced_search_bar.dart';
import 'package:smartbiztracker_new/widgets/unified_product_card.dart';

class AccountantProductsScreen extends StatefulWidget {
  const AccountantProductsScreen({Key? key}) : super(key: key);

  @override
  State<AccountantProductsScreen> createState() => _AccountantProductsScreenState();
}

class _AccountantProductsScreenState extends State<AccountantProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isGridView = false;
  bool _isLoading = true;
  List<ProductModel> _products = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // Use products from ProductProvider with SAMA API
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      productProvider.setUseSamaAdmin(true);
      await productProvider.loadSamaAdminProductsWithToJSON();
      
      setState(() {
        _products = productProvider.samaAdminProducts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      debugPrint('❌ Error loading products: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Filter products based on search query
    final filteredProducts = _searchQuery.isEmpty
        ? _products
        : _products.where((product) =>
            product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            product.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            product.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            product.sku.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: AdvancedSearchBar(
            controller: _searchController,
            hintText: 'بحث عن منتج...',
            accentColor: theme.colorScheme.primary,
            showSearchAnimation: true,
            onChanged: (query) {
              setState(() {
                _searchQuery = query;
              });
            },
            onSubmitted: (query) {
              setState(() {
                _searchQuery = query;
              });
            },
          ),
        ),
        
        // Summary card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem(
                    'إجمالي المنتجات',
                    '${_products.length}',
                    Icons.inventory_2,
                    theme.colorScheme.primary,
                  ),
                  _buildSummaryItem(
                    'متوفر',
                    '${_products.where((p) => p.quantity > 0).length}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                  _buildSummaryItem(
                    'غير متوفر',
                    '${_products.where((p) => p.quantity == 0).length}',
                    Icons.cancel,
                    Colors.red,
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Products
        Expanded(
          child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 60, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'حدث خطأ أثناء تحميل المنتجات\n${_error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProducts,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : filteredProducts.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد منتجات مطابقة لمعايير البحث',
                      style: TextStyle(fontSize: 18),
                    ),
                  )
                : _isGridView
                    ? _buildGridView(filteredProducts)
                    : _buildListView(filteredProducts),
        ),
      ],
    );
  }

  // Grid view for products
  Widget _buildGridView(List<ProductModel> products) {
    return AnimationLimiter(
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredGrid(
            position: index,
            columnCount: 2,
            duration: const Duration(milliseconds: 375),
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: UnifiedProductCard(
                  product: products[index],
                  showActions: false,
                  onTap: () {
                    // View product details
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // List view for products
  Widget _buildListView(List<ProductModel> products) {
    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: products.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: UnifiedProductCard(
                  product: products[index],
                  showActions: false,
                  onTap: () {
                    // View product details
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Build summary item
  Widget _buildSummaryItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
} 