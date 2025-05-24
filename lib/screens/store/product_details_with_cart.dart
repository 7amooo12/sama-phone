import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../utils/app_localizations.dart';
import '../../widgets/loading_widget.dart';

class ProductDetailsWithCart extends StatefulWidget {
  final Product product;

  const ProductDetailsWithCart({
    Key? key,
    required this.product,
  }) : super(key: key);

  @override
  _ProductDetailsWithCartState createState() => _ProductDetailsWithCartState();
}

class _ProductDetailsWithCartState extends State<ProductDetailsWithCart> {
  int _quantity = 1;
  bool _isLoading = false;
  Product? _fullProduct;
  late CarouselController _carouselController;
  final List<String> _dummyImages = [];

  @override
  void initState() {
    super.initState();
    _carouselController = CarouselController();
    _loadFullProductDetails();

    // Add product image to carousel if available
    if (widget.product.imageUrl != null && widget.product.imageUrl!.isNotEmpty) {
      _dummyImages.add(widget.product.imageUrl!);
      
      // Add placeholder images for the carousel to display multiple views
      if (_dummyImages.length < 3) {
        // Use different angles or views of the same product if available
        _dummyImages.add(widget.product.imageUrl!);
        _dummyImages.add(widget.product.imageUrl!);
      }
    }
  }

  Future<void> _loadFullProductDetails() async {
    if (widget.product.description != null && widget.product.description!.isNotEmpty) {
      setState(() {
        _fullProduct = widget.product;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final product = await productProvider.getSamaProductDetails(widget.product.id);
      
      if (product != null) {
        setState(() {
          _fullProduct = product;
        });
      } else {
        setState(() {
          _fullProduct = widget.product;
        });
      }
    } catch (e) {
      // If error, use what we have
      setState(() {
        _fullProduct = widget.product;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _incrementQuantity() {
    final maxQuantity = widget.product.stock;
    if (_quantity < maxQuantity) {
      setState(() {
        _quantity++;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لا يمكن إضافة المزيد. المتاح: $maxQuantity'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() {
        _quantity--;
      });
    }
  }

  void _addToCart() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    cartProvider.addItem(widget.product, quantity: _quantity);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تمت إضافة $_quantity من ${widget.product.name} إلى السلة'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'عرض السلة',
          onPressed: () {
            Navigator.pushNamed(context, '/cart');
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appLocalizations = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.pushNamed(context, '/cart');
            },
          ),
        ],
      ),
      body: _isLoading ? const LoadingWidget() : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Carousel
            _dummyImages.isNotEmpty
                ? CarouselSlider(
                    items: _dummyImages.map((imageUrl) {
                      return Container(
                        width: double.infinity,
                        color: Colors.white,
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.image_not_supported, size: 100),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    options: CarouselOptions(
                      height: 300,
                      viewportFraction: 1.0,
                      enlargeCenterPage: false,
                      autoPlay: _dummyImages.length > 1,
                      autoPlayInterval: const Duration(seconds: 3),
                      onPageChanged: (index, reason) {
                        // You can track the current image index here
                      },
                    ),
                  )
                : Container(
                    height: 300,
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.image_not_supported, size: 100),
                    ),
                  ),

            // Product Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and Category
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.product.name,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (widget.product.category != null && widget.product.category!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    widget.product.category!,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSecondaryContainer,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Price Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${widget.product.price.toStringAsFixed(2)} جنيه',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            if (widget.product.originalPrice != null && 
                                widget.product.originalPrice! > widget.product.price)
                              Text(
                                '${widget.product.originalPrice!.toStringAsFixed(2)} جنيه',
                                style: const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Availability
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        color: widget.product.inStock ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.product.inStock
                            ? '${appLocalizations.translate('in_stock') ?? 'متوفر'} (${widget.product.stock})'
                            : appLocalizations.translate('out_of_stock') ?? 'غير متوفر',
                        style: TextStyle(
                          color: widget.product.inStock ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  
                  const Divider(height: 32),
                  
                  // Description
                  Text(
                    appLocalizations.translate('description') ?? 'الوصف',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _fullProduct?.description ?? widget.product.description ?? 'لا يوجد وصف متاح لهذا المنتج.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Quantity Selector
                  Row(
                    children: [
                      Text(
                        appLocalizations.translate('quantity') ?? 'الكمية:',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: widget.product.inStock ? _decrementQuantity : null,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                '$_quantity',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: widget.product.inStock ? _incrementQuantity : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Add to Cart Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: widget.product.inStock ? _addToCart : null,
                      icon: const Icon(Icons.shopping_cart),
                      label: Text(
                        appLocalizations.translate('add_to_cart') ?? 'إضافة إلى السلة',
                        style: const TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Buy Now Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: widget.product.inStock ? () {
                        _addToCart();
                        Navigator.pushNamed(context, '/cart');
                      } : null,
                      icon: const Icon(Icons.shopping_bag),
                      label: Text(
                        appLocalizations.translate('buy_now') ?? 'شراء الآن',
                        style: const TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 