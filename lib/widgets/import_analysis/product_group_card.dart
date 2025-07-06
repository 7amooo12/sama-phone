import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/import_analysis_models.dart';
import 'package:smartbiztracker_new/config/theme/accountant_theme_config.dart';

/// بطاقة عرض مجموعة المنتجات مع المواد المجمعة
class ProductGroupCard extends StatelessWidget {
  final ProductGroup productGroup;
  final VoidCallback? onTap;
  final bool showMaterials;
  final bool isExpanded;

  const ProductGroupCard({
    Key? key,
    required this.productGroup,
    this.onTap,
    this.showMaterials = true,
    this.isExpanded = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AccountantThemeConfig.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              AccountantThemeConfig.cardBackgroundColor,
              AccountantThemeConfig.cardBackgroundColor.withOpacity(0.95),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AccountantThemeConfig.primaryColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 12),
                _buildQuantityInfo(),
                if (showMaterials && productGroup.materials.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildMaterialsSection(),
                ],
                const SizedBox(height: 8),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // أيقونة المنتج
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AccountantThemeConfig.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AccountantThemeConfig.primaryColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.inventory_2_outlined,
            color: AccountantThemeConfig.primaryColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        
        // معلومات المنتج
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                productGroup.itemNumber,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AccountantThemeConfig.textPrimaryColor,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.science_outlined,
                    size: 14,
                    color: AccountantThemeConfig.textSecondaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${productGroup.materials.length} مادة',
                    style: TextStyle(
                      fontSize: 12,
                      color: AccountantThemeConfig.textSecondaryColor,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // مؤشر الثقة
        _buildConfidenceIndicator(),
      ],
    );
  }

  Widget _buildConfidenceIndicator() {
    final confidence = productGroup.groupingConfidence;
    Color color;
    IconData icon;
    
    if (confidence >= 0.8) {
      color = Colors.green;
      icon = Icons.verified;
    } else if (confidence >= 0.6) {
      color = Colors.orange;
      icon = Icons.warning_amber;
    } else {
      color = Colors.red;
      icon = Icons.error_outline;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '${(confidence * 100).toInt()}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AccountantThemeConfig.primaryColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          _buildQuantityItem(
            'الكمية الإجمالية',
            productGroup.totalQuantity.toString(),
            Icons.inventory,
          ),
          const SizedBox(width: 16),
          _buildQuantityItem(
            'عدد الكراتين',
            productGroup.totalCartonCount.toString(),
            Icons.all_inbox,
          ),
          const Spacer(),
          _buildQuantityItem(
            'المصادر',
            productGroup.sourceRowReferences.length.toString(),
            Icons.source,
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityItem(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: AccountantThemeConfig.primaryColor,
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AccountantThemeConfig.textPrimaryColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: AccountantThemeConfig.textSecondaryColor,
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMaterialsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.category_outlined,
              size: 16,
              color: AccountantThemeConfig.primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              'المواد المجمعة',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AccountantThemeConfig.textPrimaryColor,
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // عرض المواد
        if (isExpanded) 
          _buildExpandedMaterials()
        else 
          _buildCompactMaterials(),
      ],
    );
  }

  Widget _buildCompactMaterials() {
    final topMaterials = productGroup.getTopMaterials(3);
    
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        ...topMaterials.map((material) => _buildMaterialChip(material)),
        if (productGroup.materials.length > 3)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.textSecondaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '+${productGroup.materials.length - 3} أخرى',
              style: TextStyle(
                fontSize: 11,
                color: AccountantThemeConfig.textSecondaryColor,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
      ],
    );
  }

  Widget _buildExpandedMaterials() {
    return Column(
      children: productGroup.materials.map((material) => 
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  material.materialName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AccountantThemeConfig.textPrimaryColor,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  material.quantity.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AccountantThemeConfig.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ).toList(),
    );
  }

  Widget _buildMaterialChip(MaterialEntry material) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.primaryColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            material.materialName.length > 15 
                ? '${material.materialName.substring(0, 15)}...'
                : material.materialName,
            style: TextStyle(
              fontSize: 11,
              color: AccountantThemeConfig.primaryColor,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.primaryColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              material.quantity.toString(),
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        // تاريخ الإنشاء
        Icon(
          Icons.access_time,
          size: 12,
          color: AccountantThemeConfig.textSecondaryColor,
        ),
        const SizedBox(width: 4),
        Text(
          _formatDate(productGroup.createdAt),
          style: TextStyle(
            fontSize: 10,
            color: AccountantThemeConfig.textSecondaryColor,
          ),
          textDirection: TextDirection.rtl,
        ),
        
        const Spacer(),
        
        // إجمالي كمية المواد
        if (productGroup.materials.isNotEmpty) ...[
          Text(
            'إجمالي المواد: ${productGroup.totalMaterialsQuantity}',
            style: TextStyle(
              fontSize: 10,
              color: AccountantThemeConfig.textSecondaryColor,
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
