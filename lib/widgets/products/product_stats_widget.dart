import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';

class ProductStatsWidget extends StatelessWidget {
  final List<ProductModel> products;
  final bool isExpanded;
  final VoidCallback onToggle;

  const ProductStatsWidget({
    Key? key,
    required this.products,
    required this.isExpanded,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // حساب الإحصائيات
    final totalProducts = products.length;
    final availableProducts = products.where((p) => p.quantity > 0).length;
    final lowStockProducts = products.where((p) => p.quantity > 0 && p.quantity <= 10).length;
    final outOfStockProducts = products.where((p) => p.quantity == 0).length;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // زر التوسيع/الطي
          ListTile(
            title: const Text('إحصائيات المنتجات'),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: onToggle,
          ),
          
          if (isExpanded) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildStatRow(
                    context,
                    'إجمالي المنتجات',
                    totalProducts.toString(),
                    Icons.inventory_2,
                    theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  _buildStatRow(
                    context,
                    'متوفر في المخزون',
                    availableProducts.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildStatRow(
                    context,
                    'قليل المخزون',
                    lowStockProducts.toString(),
                    Icons.warning,
                    Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _buildStatRow(
                    context,
                    'غير متوفر',
                    outOfStockProducts.toString(),
                    Icons.remove_circle,
                    Colors.red,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: StyleSystem.bodyMedium.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: StyleSystem.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 