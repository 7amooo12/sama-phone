import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/providers/product_provider.dart';
import 'package:smartbiztracker_new/services/samastock_api.dart';
import 'package:smartbiztracker_new/utils/app_localizations.dart';
import 'package:smartbiztracker_new/utils/theme_config.dart';
import 'package:smartbiztracker_new/widgets/error_widget.dart';
import 'package:smartbiztracker_new/widgets/loading_widget.dart';
import 'package:smartbiztracker_new/widgets/products/product_stats_widget.dart';
import 'package:smartbiztracker_new/utils/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({Key? key}) : super(key: key);

  @override
  _ProductsScreenState createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final AppLogger logger = AppLogger();
  List<ProductModel> _products = [];
  bool _isLoading = true;
  String? _error;
  bool _showStats = false;
  
  @override
  void initState() {
    super.initState();
    
    // استخدام Future.microtask لضمان بناء الشاشة قبل طلب البيانات
    Future.microtask(() {
      _loadProducts();
    });
  }

  void _loadProducts() {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    
    // إذا كان لدينا منتجات بالفعل، لا نظهر علامة التحميل
    final bool alreadyHasProducts = _products.isNotEmpty;
    
    setState(() {
      _isLoading = !alreadyHasProducts; // نظهر علامة التحميل فقط إذا كانت القائمة فارغة
      _error = null;
    });
    
    // تأكد من أن ميزة SAMA Admin غير مفعلة قبل تحميل المنتجات
    if (productProvider.useSamaAdmin) {
      productProvider.setUseSamaAdmin(false);
    }
    
    // استخدام المزود لتحميل المنتجات
    logger.i('جاري طلب جلب المنتجات من المزود باستخدام API key فقط...');
    
    productProvider.fetchProductsWithApiKey().then((products) {
      if (mounted) {
        // إذا كانت القائمة غير فارغة، نستخدمها. وإلا نحتفظ بالقائمة الموجودة إذا كانت لدينا
        if (products.isNotEmpty || _products.isEmpty) {
          setState(() {
            _products = products;
            _isLoading = false;
          });
          logger.i('تم جلب وتخزين ${products.length} منتج في حالة الشاشة');
        } else {
          // احتفظ بالبيانات القديمة إذا كانت الجديدة فارغة
          setState(() {
            _isLoading = false;
          });
          logger.w('تم استلام قائمة فارغة من المزود. الاحتفاظ بالمنتجات الموجودة: ${_products.length}');
        }
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          // احتفظ بالبيانات القديمة في حالة وجود خطأ
          _isLoading = false;
          _error = alreadyHasProducts ? null : error.toString();
        });
        logger.e('خطأ في جلب المنتجات: $error');
        
        // عرض رسالة قصيرة إذا كانت هناك منتجات بالفعل
        if (alreadyHasProducts) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل تحديث البيانات. البيانات المعروضة قد لا تكون محدثة.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(appLocalizations.translate('products') ?? 'المنتجات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
          ),
        ],
      ),
      body: _isLoading 
          ? const LoadingWidget()
          : _error != null 
              ? AppErrorWidget(
                  error: _error!,
                  onRetry: _loadProducts,
                )
              : _products.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            appLocalizations.translate('no_products_found') ?? 'لا توجد منتجات',
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadProducts,
                            child: Text(appLocalizations.translate('refresh') ?? 'تحديث'),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // إحصائيات المنتجات
                        ProductStatsWidget(
                          products: _products,
                          isExpanded: _showStats,
                          onToggle: () {
                            setState(() {
                              _showStats = !_showStats;
                            });
                          },
                        ),
                        
                        // قائمة المنتجات
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: _products.length,
                            itemBuilder: (context, index) {
                              final product = _products[index];
                              
                              return Card(
                                elevation: 4,
                                clipBehavior: Clip.antiAlias,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    // Navigate to product details
                                    // TODO: Implement product details screen
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Product Image
                                      AspectRatio(
                                        aspectRatio: 1,
                                        child: product.imageUrl != null
                                            ? CachedNetworkImage(
                                                imageUrl: product.imageUrl!,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => const Center(
                                                  child: CircularProgressIndicator(),
                                                ),
                                                errorWidget: (context, url, error) => Container(
                                                  color: Colors.grey[300],
                                                  child: const Center(
                                                    child: Icon(Icons.image_not_supported, size: 40),
                                                  ),
                                                ),
                                              )
                                            : Container(
                                                color: Colors.grey[300],
                                                child: const Center(
                                                  child: Icon(Icons.image, size: 40),
                                                ),
                                              ),
                                      ),
                                      
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Product Name
                                              Text(
                                                product.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              
                                              // Price
                                              Text(
                                                '${product.price.toStringAsFixed(2)} جنيه',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  color: theme.colorScheme.primary,
                                                ),
                                              ),
                                              
                                              if (product.quantity > 0) ...[
                                                const SizedBox(height: 4),
                                                // Available quantity
                                                Text(
                                                  '${product.quantity} ${appLocalizations.translate('in_stock') ?? 'متوفر'}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.green[700],
                                                  ),
                                                ),
                                              ] else ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  appLocalizations.translate('out_of_stock') ?? 'غير متوفر',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.red[700],
                                                  ),
                                                ),
                                              ],
                                              
                                              if (product.category.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                // Category
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme.secondaryContainer,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    product.category,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: theme.colorScheme.onSecondaryContainer,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
} 