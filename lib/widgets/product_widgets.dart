import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import '../providers/favorites_provider.dart';
import '../utils/style_system.dart';
import '../utils/animation_system.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final Function()? onTap;
  final Function(Product)? onAddToCart;
  final Function(Product)? onToggleFavorite;
  final bool isFavorite;
  final bool showFavoriteButton;
  final bool showCartButton;

  const ProductCard({
    Key? key,
    required this.product,
    this.onTap,
    this.onAddToCart,
    this.onToggleFavorite,
    this.isFavorite = false,
    this.showFavoriteButton = true,
    this.showCartButton = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StyleSystem.radiusLarge),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(StyleSystem.radiusLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Product Image
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(StyleSystem.radiusLarge),
                  topRight: Radius.circular(StyleSystem.radiusLarge),
                ),
                child: (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: product.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          child: Center(
                            child: Icon(
                              Icons.broken_image,
                              color: theme.colorScheme.primary.withOpacity(0.5),
                              size: 40,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        child: Center(
                          child: Icon(
                            Icons.image,
                            color: theme.colorScheme.primary.withOpacity(0.5),
                            size: 40,
                          ),
                        ),
                      ),
              ),
            ),
            
            // Product Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    // Category
                    if (product.category != null && product.category!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          product.category!,
                          style: TextStyle(
                            fontSize: 12.0,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    
                    const Spacer(),
                    
                    // Price and Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Price
                        Text(
                          '${product.price.toStringAsFixed(2)} جنيه',
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        
                        // Favorite Button
                        if (showFavoriteButton)
                          IconButton(
                            icon: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: isFavorite ? theme.colorScheme.error : null,
                            ),
                            onPressed: onToggleFavorite == null
                                ? null
                                : () => onToggleFavorite!(product),
                            tooltip: isFavorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
                            iconSize: 24,
                          ),
                      ],
                    ),
                    
                    // Add to Cart Button
                    if (showCartButton)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.shopping_cart, size: 18),
                            label: const Text('إضافة للسلة'),
                            onPressed: onAddToCart == null
                                ? null
                                : () => onAddToCart!(product),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(StyleSystem.radiusMedium),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
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

class ProductDetailDialog extends StatelessWidget {
  final Product product;

  const ProductDetailDialog({
    Key? key,
    required this.product,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Product image at the top
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: CachedNetworkImage(
              imageUrl: product.imageUrl ?? '',
              fit: BoxFit.cover,
              width: double.infinity,
              height: 200,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(),
              ),
              errorWidget: (context, url, error) => Container(
                height: 200,
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
                ),
              ),
            ),
          ),

          // Product details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product name
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 12),

                // Price
                Row(
                  children: [
                    const Icon(Icons.attach_money, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      '${product.price.toStringAsFixed(2)} جنيه',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Stock
                Row(
                  children: [
                    Icon(
                      Icons.inventory,
                      color: product.stock > 0 ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'المخزون: ${product.stock}',
                      style: TextStyle(
                        fontSize: 16,
                        color: product.stock > 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Category
                if (product.category != null)
                  Row(
                    children: [
                      const Icon(Icons.category, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'الفئة: ${product.category}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),

                // Brand (if available)
                if (product.brand.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.business, color: Colors.purple),
                      const SizedBox(width: 8),
                      Text(
                        'المصنع: ${product.brand}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Description
                const Text(
                  'الوصف:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.description != null && product.description!.isNotEmpty
                      ? product.description!
                      : 'لا يوجد وصف متاح لهذا المنتج.',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),

          // Bottom action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إغلاق'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProductGridView extends StatelessWidget {
  final List<Product> products;
  final Function(Product) onProductTap;
  final Future<void> Function() onRefresh;
  final Function(Product)? onAddToCart;
  final Function(Product)? onToggleFavorite;
  final Function(int) isFavorite;

  const ProductGridView({
    Key? key,
    required this.products,
    required this.onProductTap,
    required this.onRefresh,
    this.onAddToCart,
    this.onToggleFavorite,
    required this.isFavorite,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return ProductCard(
            product: product,
            onTap: () => onProductTap(product),
            showFavoriteButton: onToggleFavorite != null,
            showCartButton: onAddToCart != null && product.stock > 0,
            onAddToCart: onAddToCart,
            onToggleFavorite: onToggleFavorite,
            isFavorite: isFavorite(product.id),
          );
        },
      ),
    );
  }
}

class CategoryFilterBar extends StatelessWidget {
  final List<String> categories;
  final String? selectedCategory;
  final Function(String?) onCategorySelected;

  const CategoryFilterBar({
    Key? key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + 1, // +1 for "All" option
        itemBuilder: (context, index) {
          // First item is "All"
          if (index == 0) {
            return _buildCategoryChip(
              context,
              null,
              'الكل',
              selectedCategory == null,
            );
          }
          
          final category = categories[index - 1];
          return _buildCategoryChip(
            context,
            category,
            category,
            category == selectedCategory,
          );
        },
      ),
    );
  }

  Widget _buildCategoryChip(
    BuildContext context,
    String? category,
    String label,
    bool isSelected,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onCategorySelected(category),
        backgroundColor: Colors.grey[200],
        selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        labelStyle: TextStyle(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

/// عرض المنتج على شكل بطاقة قائمة
class ProductListCard extends StatelessWidget {
  final Product product;
  final Function()? onTap;
  final Function(Product)? onAddToCart;
  final Function(Product)? onToggleFavorite;

  const ProductListCard({
    Key? key,
    required this.product,
    this.onTap,
    this.onAddToCart,
    this.onToggleFavorite,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final isFavorite = favoritesProvider.isFavorite(product.id);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StyleSystem.radiusLarge),
      ),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(StyleSystem.radiusLarge),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(StyleSystem.radiusLarge),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // صورة المنتج
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(StyleSystem.radiusLarge),
                  bottomRight: Radius.circular(StyleSystem.radiusLarge),
                ),
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                  ),
                  child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.broken_image_outlined,
                            size: 40,
                            color: theme.colorScheme.primary.withOpacity(0.5),
                          ),
                          memCacheWidth: 220,
                          maxWidthDiskCache: 440,
                        )
                      : Icon(
                          Icons.image_outlined,
                          size: 40,
                          color: theme.colorScheme.primary.withOpacity(0.5),
                        ),
                ),
              ),
              
              // معلومات المنتج
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // اسم المنتج والسعر
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // اسم المنتج
                          Expanded(
                            child: Text(
                              product.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          
                          // السعر
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(StyleSystem.radiusMedium),
                            ),
                            child: Text(
                              '${product.price.toStringAsFixed(2)} جنيه',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // الوصف المختصر
                      if (product.description != null && product.description!.isNotEmpty)
                        Text(
                          product.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                      const SizedBox(height: 8),
                      
                      // الأزرار
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // التوفر
                          if (product.availableQuantity != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: product.availableQuantity! > 0
                                    ? theme.colorScheme.primary.withOpacity(0.1)
                                    : theme.colorScheme.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(StyleSystem.radiusSmall),
                              ),
                              child: Text(
                                product.availableQuantity! > 0
                                    ? 'متوفر: ${product.availableQuantity}'
                                    : 'غير متوفر',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: product.availableQuantity! > 0
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          
                          // زر الإضافة للسلة
                          if (product.availableQuantity == null || product.availableQuantity! > 0)
                            Row(
                              children: [
                                // زر المفضلة
                                IconButton(
                                  icon: Icon(
                                    isFavorite ? Icons.favorite : Icons.favorite_border,
                                    color: isFavorite
                                        ? theme.colorScheme.error
                                        : theme.colorScheme.onSurface.withOpacity(0.5),
                                    size: 20,
                                  ),
                                  onPressed: onToggleFavorite == null
                                      ? null
                                      : () => onToggleFavorite!(product),
                                  splashRadius: 20,
                                  tooltip: isFavorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
                                ),
                                
                                // زر الإضافة للسلة
                                IconButton(
                                  icon: Icon(
                                    Icons.add_shopping_cart,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                  onPressed: onAddToCart == null
                                      ? null
                                      : () => onAddToCart!(product),
                                  splashRadius: 20,
                                  tooltip: 'إضافة إلى السلة',
                                ),
                              ],
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
      ),
    );
  }
}

/// Widget para mostrar una tarjeta de producto para el modelo Product
class ProductCardWidget extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final bool showActions;

  const ProductCardWidget({
    Key? key,
    required this.product,
    this.onTap,
    this.showActions = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StyleSystem.radiusMedium),
      ),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Hero(
              tag: 'product_image_${product.id}',
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                ),
                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: product.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Icon(
                            Icons.broken_image,
                            color: theme.colorScheme.primary.withOpacity(0.7),
                            size: 40,
                          ),
                        ),
                        memCacheWidth: 240,
                        maxWidthDiskCache: 480,
                      )
                    : Center(
                        child: Icon(
                          Icons.inventory_2,
                          color: theme.colorScheme.primary.withOpacity(0.7),
                          size: 40,
                        ),
                      ),
              ),
            ),
            
            // Product Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    Text(
                      product.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    if (product.description != null && product.description!.isNotEmpty) ...[
                      Text(
                        product.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                    ],
                    
                    // Category Tag
                    if (product.category != null && product.category!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          product.category!,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    
                    const Spacer(),
                    
                    // Price and Stock
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${product.price.toStringAsFixed(2)} جنيه',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: product.stock > 0
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(StyleSystem.radiusSmall),
                          ),
                          child: Text(
                            product.stock > 0 ? '${product.stock}' : 'نفذ',
                            style: TextStyle(
                              fontSize: 12,
                              color: product.stock > 0 ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Actions (Edit, Delete buttons)
                    if (showActions) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () {
                              // TODO: Implement edit functionality
                            },
                            tooltip: 'تعديل',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () {
                              // TODO: Implement delete functionality
                            },
                            tooltip: 'حذف',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
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
  }
}

class LuxuryProductCard extends StatelessWidget {
  final Product product;
  final Function()? onTap;

  const LuxuryProductCard({
    Key? key,
    required this.product,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPrice = product.price > 0;
    final hasStock = product.stock > 0;
    
    return Card(
      elevation: 5,
      shadowColor: theme.colorScheme.primary.withOpacity(0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StyleSystem.radiusLarge),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(StyleSystem.radiusLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Product Image
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  // Image with rounded top corners
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(StyleSystem.radiusLarge),
                      topRight: Radius.circular(StyleSystem.radiusLarge),
                    ),
                    child: (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: product.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: theme.colorScheme.primary.withOpacity(0.05),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: theme.colorScheme.primary.withOpacity(0.05),
                              child: Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: theme.colorScheme.primary.withOpacity(0.3),
                                  size: 40,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: theme.colorScheme.primary.withOpacity(0.05),
                            child: Center(
                              child: Icon(
                                Icons.image,
                                color: theme.colorScheme.primary.withOpacity(0.3),
                                size: 40,
                              ),
                            ),
                          ),
                  ),
                  
                  // Subtle gradient overlay for better text visibility
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(StyleSystem.radiusLarge),
                      topRight: Radius.circular(StyleSystem.radiusLarge),
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: 60,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Product Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    Text(
                      product.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    // Category
                    if (product.category != null && product.category!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            product.category!,
                            style: TextStyle(
                              fontSize: 10.0,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    
                    const Spacer(),
                    
                    // Only show price and stock if both are available
                    if (hasPrice && hasStock) ...[
                      // Price
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${product.price.toStringAsFixed(2)} جنيه',
                              style: TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Stock indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'متوفر',
                              style: TextStyle(
                                fontSize: 10.0,
                                fontWeight: FontWeight.w500,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
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
  }
}
