import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/global_inventory_models.dart';
import '../../providers/global_inventory_provider.dart';
import '../../config/accountant_theme_config.dart';
import '../../utils/app_logger.dart';

/// واجهة البحث العالمي في المخزون
class GlobalInventorySearchWidget extends StatefulWidget {
  final String? initialProductId;
  final int? initialQuantity;
  final Function(GlobalInventorySearchResult)? onSearchResult;

  const GlobalInventorySearchWidget({
    super.key,
    this.initialProductId,
    this.initialQuantity,
    this.onSearchResult,
  });

  @override
  State<GlobalInventorySearchWidget> createState() => _GlobalInventorySearchWidgetState();
}

class _GlobalInventorySearchWidgetState extends State<GlobalInventorySearchWidget> {
  final _productIdController = TextEditingController();
  final _quantityController = TextEditingController();
  WarehouseSelectionStrategy _selectedStrategy = WarehouseSelectionStrategy.balanced;

  @override
  void initState() {
    super.initState();
    if (widget.initialProductId != null) {
      _productIdController.text = widget.initialProductId!;
    }
    if (widget.initialQuantity != null) {
      _quantityController.text = widget.initialQuantity.toString();
    }
  }

  @override
  void dispose() {
    _productIdController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildSearchForm(),
          _buildSearchResults(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.search,
              color: AccountantThemeConfig.primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'البحث العالمي في المخزون',
                  style: AccountantThemeConfig.headingStyle.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'البحث عن المنتجات في جميع المخازن',
                  style: AccountantThemeConfig.bodyStyle.copyWith(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchForm() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // معرف المنتج
          Text(
            'معرف المنتج',
            style: AccountantThemeConfig.bodyStyle.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _productIdController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'أدخل معرف المنتج',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.inventory, color: Colors.white54),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // الكمية المطلوبة
          Text(
            'الكمية المطلوبة',
            style: AccountantThemeConfig.bodyStyle.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'أدخل الكمية المطلوبة',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.numbers, color: Colors.white54),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // استراتيجية الاختيار
          Text(
            'استراتيجية الاختيار',
            style: AccountantThemeConfig.bodyStyle.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButton<WarehouseSelectionStrategy>(
              value: _selectedStrategy,
              isExpanded: true,
              dropdownColor: const Color(0xFF1A1A2E),
              style: const TextStyle(color: Colors.white),
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
              items: [
                DropdownMenuItem(
                  value: WarehouseSelectionStrategy.balanced,
                  child: Text('توزيع متوازن'),
                ),
                DropdownMenuItem(
                  value: WarehouseSelectionStrategy.priorityBased,
                  child: Text('حسب الأولوية'),
                ),
                DropdownMenuItem(
                  value: WarehouseSelectionStrategy.highestStock,
                  child: Text('أعلى مخزون أولاً'),
                ),
                DropdownMenuItem(
                  value: WarehouseSelectionStrategy.lowestStock,
                  child: Text('أقل مخزون أولاً'),
                ),
                DropdownMenuItem(
                  value: WarehouseSelectionStrategy.fifo,
                  child: Text('الأقدم أولاً'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedStrategy = value;
                  });
                }
              },
            ),
          ),
          
          const SizedBox(height: 20),
          
          // زر البحث
          SizedBox(
            width: double.infinity,
            child: Consumer<GlobalInventoryProvider>(
              builder: (context, provider, child) {
                return ElevatedButton.icon(
                  onPressed: provider.isSearching ? null : _performSearch,
                  icon: provider.isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.search),
                  label: Text(provider.isSearching ? 'جاري البحث...' : 'بحث عالمي'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AccountantThemeConfig.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  Widget _buildSearchResults() {
    return Consumer<GlobalInventoryProvider>(
      builder: (context, provider, child) {
        if (provider.searchError != null) {
          return _buildErrorWidget(provider.searchError!);
        }

        if (provider.lastSearchResult != null) {
          return _buildResultWidget(provider.lastSearchResult!);
        }

        return const SizedBox();
      },
    );
  }

  Widget _buildErrorWidget(String error) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultWidget(GlobalInventorySearchResult result) {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ملخص النتيجة
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: result.canFulfill 
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: result.canFulfill 
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.orange.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      result.canFulfill ? Icons.check_circle : Icons.warning,
                      color: result.canFulfill ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.summaryText,
                        style: AccountantThemeConfig.bodyStyle.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildResultStats(result),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // تفاصيل المخازن المتاحة
          if (result.availableWarehouses.isNotEmpty) ...[
            Text(
              'المخازن المتاحة (${result.availableWarehouses.length})',
              style: AccountantThemeConfig.bodyStyle.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ...result.availableWarehouses.map((warehouse) => 
              _buildWarehouseCard(warehouse)
            ),
          ],
          
          const SizedBox(height: 16),
          
          // خطة التخصيص
          if (result.allocationPlan.isNotEmpty) ...[
            Text(
              'خطة التخصيص (${result.allocationPlan.length} مخزن)',
              style: AccountantThemeConfig.bodyStyle.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ...result.allocationPlan.map((allocation) => 
              _buildAllocationCard(allocation)
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultStats(GlobalInventorySearchResult result) {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            'إجمالي المتاح',
            '${result.totalAvailableQuantity}',
            Icons.inventory,
          ),
        ),
        Expanded(
          child: _buildStatItem(
            'نسبة التلبية',
            '${result.fulfillmentPercentage.toStringAsFixed(1)}%',
            Icons.percent,
          ),
        ),
        Expanded(
          child: _buildStatItem(
            'المخازن المطلوبة',
            '${result.requiredWarehousesCount}',
            Icons.warehouse,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: AccountantThemeConfig.bodyStyle.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: AccountantThemeConfig.bodyStyle.copyWith(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildWarehouseCard(WarehouseInventoryAvailability warehouse) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Color(int.parse(warehouse.statusColor.substring(1), radix: 16) + 0xFF000000)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  warehouse.warehouseName,
                  style: AccountantThemeConfig.bodyStyle.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'المتاح: ${warehouse.availableQuantity} | الحد الأدنى: ${warehouse.minimumStock}',
                  style: AccountantThemeConfig.bodyStyle.copyWith(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Color(int.parse(warehouse.statusColor.substring(1), radix: 16) + 0xFF000000)
                  .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              warehouse.statusText,
              style: TextStyle(
                color: Color(int.parse(warehouse.statusColor.substring(1), radix: 16) + 0xFF000000),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllocationCard(InventoryAllocation allocation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AccountantThemeConfig.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AccountantThemeConfig.primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${allocation.allocationPriority}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allocation.warehouseName,
                  style: AccountantThemeConfig.bodyStyle.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'مخصص: ${allocation.allocatedQuantity} | ${allocation.allocationReason}',
                  style: AccountantThemeConfig.bodyStyle.copyWith(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          if (allocation.willCauseLowStock) ...[
            Icon(
              Icons.warning,
              color: Colors.orange,
              size: 20,
            ),
          ],
        ],
      ),
    );
  }

  void _performSearch() async {
    final productId = _productIdController.text.trim();
    final quantityText = _quantityController.text.trim();

    if (productId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال معرف المنتج'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (quantityText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال الكمية المطلوبة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final quantity = int.tryParse(quantityText);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال كمية صحيحة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final provider = context.read<GlobalInventoryProvider>();
      final result = await provider.searchProductGlobally(
        productId: productId,
        requestedQuantity: quantity,
        strategy: _selectedStrategy,
      );

      widget.onSearchResult?.call(result);

      if (result.canFulfill) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم العثور على المنتج: ${result.summaryText}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('المخزون غير كافي: ${result.summaryText}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('خطأ في البحث العالمي: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في البحث: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
