import 'package:flutter/material.dart';
import '../models/product_model.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:smartbiztracker_new/widgets/common/flex_safe.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smartbiztracker_new/utils/logger.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.showActions = true,
  });
  final ProductModel product;
  final VoidCallback? onTap;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        child: SafeColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.imageUrl != null && product.imageUrl!.isNotEmpty)
              SizedBox(
                height: 120,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: product.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: theme.colorScheme.primary.safeOpacity(0.1),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) {
                    // سجل الخطأ للتصحيح
                    AppLogger.warning('فشل تحميل صورة المنتج: $url - $error');
                    return Container(
                      color: theme.colorScheme.primary.safeOpacity(0.1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            color: theme.colorScheme.primary,
                          ),
                          Text(
                            'خطأ تحميل',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 120,
                color: theme.colorScheme.primary.safeOpacity(0.1),
                child: Icon(
                  Icons.inventory_2,
                  color: theme.colorScheme.primary,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SafeColumn(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SafeText(
                    product.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 4),
                  SafeText(
                    product.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.textTheme.bodyMedium?.color?.safeOpacity(0.7),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  SafeRow(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SafeText(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SafeText(
                        'Stock: ${product.quantity}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: product.quantity > 0
                              ? Colors.green
                              : theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                  if (showActions) ...[
                    const SizedBox(height: 8),
                    SafeRow(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            // TODO: Implement edit functionality
                          },
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            // TODO: Implement delete functionality
                          },
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
