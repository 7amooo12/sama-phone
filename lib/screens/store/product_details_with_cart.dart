import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart' as carousel;
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../utils/app_localizations.dart';
import '../../utils/accountant_theme_config.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/common/optimized_image.dart';

class ProductDetailsWithCart extends StatefulWidget {

  const ProductDetailsWithCart({
    super.key,
    required this.product,
  });
  final Product product;

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
      final product = await productProvider.getSamaProductDetails(widget.product.id.toString());

      if (product != null) {
        setState(() {
          _fullProduct = Product.fromProductModel(product);
          // Update images list with the new product data
          _updateImagesList();
        });
      } else {
        setState(() {
          _fullProduct = widget.product;
        });
      }
    } catch (e) {
      print('Error loading product details: $e');
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

  void _updateImagesList() {
    _dummyImages.clear();

    // Add main image if available
    if (_fullProduct?.imageUrl != null && _fullProduct!.imageUrl!.isNotEmpty) {
      _dummyImages.add(_fullProduct!.imageUrl!);
    }

    // If we still don't have images, add a placeholder
    if (_dummyImages.isEmpty) {
      // Use a default placeholder or the original product image
      if (widget.product.imageUrl != null && widget.product.imageUrl!.isNotEmpty) {
        _dummyImages.add(widget.product.imageUrl!);
      }
    }

    // Add duplicate images for carousel effect if we only have one image
    while (_dummyImages.length < 3 && _dummyImages.isNotEmpty) {
      _dummyImages.add(_dummyImages.first);
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
      backgroundColor: AccountantThemeConfig.luxuryBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.cardGradient,
              borderRadius: BorderRadius.circular(12),
              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              color: AccountantThemeConfig.primaryGreen,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.product.name,
          style: AccountantThemeConfig.headlineMedium.copyWith(
            color: AccountantThemeConfig.primaryGreen,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.cardGradient,
                  borderRadius: BorderRadius.circular(12),
                  border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
                ),
                child: Icon(
                  Icons.shopping_cart_outlined,
                  color: AccountantThemeConfig.accentBlue,
                  size: 20,
                ),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/cart');
              },
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Container(
              decoration: const BoxDecoration(
                gradient: AccountantThemeConfig.mainBackgroundGradient,
              ),
              child: const LoadingWidget(),
            )
          : Container(
              decoration: const BoxDecoration(
                gradient: AccountantThemeConfig.mainBackgroundGradient,
              ),
              child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Carousel
            _dummyImages.isNotEmpty
                ? carousel.CarouselSlider(
                    items: _dummyImages.map((imageUrl) {
                      return Container(
                        width: double.infinity,
                        color: Colors.white,
                        child: OptimizedImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: 300,
                          placeholder: Container(
                            decoration: BoxDecoration(
                              gradient: AccountantThemeConfig.cardGradient,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: AccountantThemeConfig.primaryGreen,
                                    strokeWidth: 3,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'جاري تحميل الصورة...',
                                    style: AccountantThemeConfig.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          errorWidget: Container(
                            decoration: BoxDecoration(
                              gradient: AccountantThemeConfig.cardGradient,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image_outlined,
                                    size: 80,
                                    color: AccountantThemeConfig.dangerRed,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'فشل في تحميل الصورة',
                                    style: AccountantThemeConfig.bodyMedium.copyWith(
                                      color: AccountantThemeConfig.dangerRed,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    options: carousel.CarouselOptions(
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

            // Product Info with Professional Styling
            Container(
              margin: const EdgeInsets.all(16),
              decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
                border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name with SAMA Styling
                    Text(
                      widget.product.name,
                      style: AccountantThemeConfig.headlineLarge.copyWith(
                        color: AccountantThemeConfig.primaryGreen,
                        fontSize: 28,
                      ),
                    ).animate()
                      .fadeIn(duration: const Duration(milliseconds: 600))
                      .slideX(begin: -0.2, end: 0),

                    const SizedBox(height: 16),

                    // Category Badge
                    if (widget.product.category != null && widget.product.category!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: AccountantThemeConfig.blueGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
                        ),
                        child: Text(
                          widget.product.category!,
                          style: AccountantThemeConfig.labelMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ).animate()
                        .fadeIn(delay: const Duration(milliseconds: 200))
                        .scale(begin: const Offset(0.8, 0.8)),

                    const SizedBox(height: 24),

                    // Availability Status with Professional Styling
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: widget.product.inStock
                            ? AccountantThemeConfig.greenGradient
                            : LinearGradient(
                                colors: [AccountantThemeConfig.dangerRed, AccountantThemeConfig.dangerRed.withValues(alpha: 0.8)],
                              ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AccountantThemeConfig.glowShadows(
                          widget.product.inStock
                              ? AccountantThemeConfig.primaryGreen
                              : AccountantThemeConfig.dangerRed
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            widget.product.inStock ? Icons.check_circle : Icons.cancel,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.product.inStock
                                  ? 'متوفر للطلب'
                                  : 'غير متوفر حالياً',
                              style: AccountantThemeConfig.bodyLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Description Section
                    Text(
                      'وصف المنتج',
                      style: AccountantThemeConfig.headlineMedium.copyWith(
                        color: AccountantThemeConfig.accentBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AccountantThemeConfig.transparentCardDecoration,
                      child: Text(
                        _fullProduct?.description ?? widget.product.description ?? 'لا يوجد وصف متاح لهذا المنتج.',
                        style: AccountantThemeConfig.bodyLarge.copyWith(
                          height: 1.6,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Quantity Selector with Professional Styling
                    Row(
                      children: [
                        Text(
                          'الكمية:',
                          style: AccountantThemeConfig.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          decoration: BoxDecoration(
                            gradient: AccountantThemeConfig.cardGradient,
                            borderRadius: BorderRadius.circular(12),
                            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, color: Colors.white),
                                onPressed: widget.product.inStock ? _decrementQuantity : null,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  '$_quantity',
                                  style: AccountantThemeConfig.bodyLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AccountantThemeConfig.primaryGreen,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, color: Colors.white),
                                onPressed: widget.product.inStock ? _incrementQuantity : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Action Buttons with Professional Styling
                    if (widget.product.inStock) ...[
                      // Add to Cart Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _addToCart,
                          icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                          label: Text(
                            'إضافة إلى السلة',
                            style: AccountantThemeConfig.bodyLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: AccountantThemeConfig.primaryButtonStyle.copyWith(
                            backgroundColor: WidgetStateProperty.all(AccountantThemeConfig.primaryGreen),
                            shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Buy Now Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _addToCart();
                            Navigator.pushNamed(context, '/cart');
                          },
                          icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                          label: Text(
                            'شراء الآن',
                            style: AccountantThemeConfig.bodyLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: AccountantThemeConfig.secondaryButtonStyle.copyWith(
                            backgroundColor: WidgetStateProperty.all(AccountantThemeConfig.accentBlue),
                            shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Out of Stock Message
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AccountantThemeConfig.dangerRed, AccountantThemeConfig.dangerRed.withValues(alpha: 0.8)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.info_outline, color: Colors.white),
                            const SizedBox(width: 12),
                            Text(
                              'المنتج غير متوفر حالياً',
                              style: AccountantThemeConfig.bodyLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
              ),
            ),
    );
  }
}