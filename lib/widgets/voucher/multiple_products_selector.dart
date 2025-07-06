import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/voucher_provider.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';

/// Widget for selecting multiple products for vouchers with advanced filtering and stock indicators
class MultipleProductsSelector extends StatefulWidget {
  final List<Map<String, dynamic>> selectedProducts;
  final Function(List<Map<String, dynamic>>) onSelectionChanged;
  final int maxSelections;
  final bool showStockIndicators;
  final bool allowOutOfStock;

  const MultipleProductsSelector({
    Key? key,
    required this.selectedProducts,
    required this.onSelectionChanged,
    this.maxSelections = 50,
    this.showStockIndicators = true,
    this.allowOutOfStock = false,
  }) : super(key: key);

  @override
  State<MultipleProductsSelector> createState() => _MultipleProductsSelectorState();
}

class _MultipleProductsSelectorState extends State<MultipleProductsSelector> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  List<Map<String, dynamic>> _selectedProducts = [];
  String _selectedCategory = 'الكل';
  List<String> _categories = ['الكل'];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedProducts = List.from(widget.selectedProducts);
    _loadProducts();
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final voucherProvider = Provider.of<VoucherProvider>(context, listen: false);
      final products = await voucherProvider.getAvailableProductsForVoucher(
        includeOutOfStock: widget.allowOutOfStock,
        sortByQuantity: true,
      );

      if (mounted) {
        setState(() {
          _allProducts = products;
          _filteredProducts = products;
          _categories = ['الكل', ...products.map((p) => p['category'] as String? ?? '').toSet()];
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('Error loading products for voucher selection: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'فشل في تحميل المنتجات: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase().trim();
    
    setState(() {
      _filteredProducts = _allProducts.where((product) {
        // Filter by category
        if (_selectedCategory != 'الكل') {
          final category = product['category'] as String? ?? '';
          if (category != _selectedCategory) return false;
        }

        // Filter by search query
        if (query.isNotEmpty) {
          final name = (product['name'] as String? ?? '').toLowerCase();
          final category = (product['category'] as String? ?? '').toLowerCase();
          if (!name.contains(query) && !category.contains(query)) return false;
        }

        return true;
      }).toList();
    });
  }

  void _toggleProductSelection(Map<String, dynamic> product) {
    final productId = product['id'] as String;
    final isSelected = _selectedProducts.any((p) => p['id'] == productId);

    setState(() {
      if (isSelected) {
        _selectedProducts.removeWhere((p) => p['id'] == productId);
      } else {
        if (_selectedProducts.length >= widget.maxSelections) {
          _showMaxSelectionDialog();
          return;
        }
        _selectedProducts.add(product);
      }
    });

    widget.onSelectionChanged(_selectedProducts);
  }

  void _selectAll() {
    final availableProducts = _filteredProducts.where((product) {
      return !_selectedProducts.any((selected) => selected['id'] == product['id']);
    }).toList();

    final remainingSlots = widget.maxSelections - _selectedProducts.length;
    final productsToAdd = availableProducts.take(remainingSlots).toList();

    if (productsToAdd.isNotEmpty) {
      setState(() {
        _selectedProducts.addAll(productsToAdd);
      });
      widget.onSelectionChanged(_selectedProducts);

      if (availableProducts.length > remainingSlots) {
        _showPartialSelectionDialog(productsToAdd.length, availableProducts.length - remainingSlots);
      }
    }
  }

  void _clearAll() {
    setState(() {
      _selectedProducts.clear();
    });
    widget.onSelectionChanged(_selectedProducts);
  }

  void _showMaxSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.luxuryBlack,
        title: Text(
          'الحد الأقصى للاختيار',
          style: AccountantThemeConfig.headlineSmall.copyWith(color: Colors.white),
        ),
        content: Text(
          'يمكنك اختيار ${widget.maxSelections} منتج كحد أقصى للقسيمة الواحدة.',
          style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'حسناً',
              style: TextStyle(color: AccountantThemeConfig.primaryGreen),
            ),
          ),
        ],
      ),
    );
  }

  void _showPartialSelectionDialog(int selected, int remaining) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.luxuryBlack,
        title: Text(
          'اختيار جزئي',
          style: AccountantThemeConfig.headlineSmall.copyWith(color: Colors.white),
        ),
        content: Text(
          'تم اختيار $selected منتج. لا يمكن اختيار $remaining منتج إضافي بسبب الحد الأقصى.',
          style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'حسناً',
              style: TextStyle(color: AccountantThemeConfig.primaryGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockIndicator(Map<String, dynamic> product) {
    if (!widget.showStockIndicators) return const SizedBox.shrink();

    final stockIcon = product['stockIcon'] as String? ?? '🟢';
    final stockDescription = product['stockDescription'] as String? ?? 'متوفر';
    final quantity = product['quantity'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getStockColor(product).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _getStockColor(product).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            stockIcon,
            style: const TextStyle(fontSize: 10),
          ),
          const SizedBox(width: 2),
          Text(
            '$quantity',
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: _getStockColor(product),
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStockColor(Map<String, dynamic> product) {
    final stockStatus = product['stockStatus'] as String? ?? 'normal';
    switch (stockStatus) {
      case 'out_of_stock':
      case 'very_low':
        return Colors.red;
      case 'low':
        return Colors.orange;
      case 'high':
      case 'normal':
      default:
        return AccountantThemeConfig.primaryGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AccountantThemeConfig.luxuryBlack,
            AccountantThemeConfig.luxuryBlack.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with selection count
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                  AccountantThemeConfig.accentBlue.withOpacity(0.1),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2,
                  color: AccountantThemeConfig.primaryGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'اختيار المنتجات',
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AccountantThemeConfig.primaryGreen.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    'تم اختيار ${_selectedProducts.length}',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: AccountantThemeConfig.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search and filter section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search field
                TextFormField(
                  controller: _searchController,
                  style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن المنتجات...',
                    hintStyle: AccountantThemeConfig.bodyMedium.copyWith(
                      color: Colors.white54,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AccountantThemeConfig.primaryGreen,
                    ),
                    filled: true,
                    fillColor: AccountantThemeConfig.luxuryBlack.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AccountantThemeConfig.primaryGreen,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Category filter and action buttons
                Row(
                  children: [
                    // Category dropdown
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AccountantThemeConfig.luxuryBlack.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            dropdownColor: AccountantThemeConfig.luxuryBlack,
                            style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: AccountantThemeConfig.primaryGreen,
                            ),
                            items: _categories.map((category) {
                              return DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCategory = value ?? 'الكل';
                              });
                              _filterProducts();
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Select all button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _filteredProducts.isEmpty ? null : _selectAll,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                          foregroundColor: AccountantThemeConfig.primaryGreen,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: AccountantThemeConfig.primaryGreen.withOpacity(0.5),
                            ),
                          ),
                        ),
                        child: Text(
                          'اختيار الكل',
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Clear all button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _selectedProducts.isEmpty ? null : _clearAll,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.2),
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.red.withOpacity(0.5),
                            ),
                          ),
                        ),
                        child: Text(
                          'إلغاء الكل',
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Products list
          Expanded(
            child: _buildProductsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AccountantThemeConfig.primaryGreen),
            ),
            const SizedBox(height: 16),
            Text(
              'جاري تحميل المنتجات...',
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProducts,
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (_filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              color: Colors.white54,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _allProducts.isEmpty 
                  ? 'لا توجد منتجات متاحة للاختيار'
                  : 'لا توجد منتجات تطابق البحث',
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        final productId = product['id'] as String;
        final isSelected = _selectedProducts.any((p) => p['id'] == productId);
        final isLowStock = product['isLowStock'] as bool? ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected 
                ? AccountantThemeConfig.primaryGreen.withOpacity(0.1)
                : AccountantThemeConfig.luxuryBlack.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? AccountantThemeConfig.primaryGreen.withOpacity(0.5)
                  : Colors.white.withOpacity(0.1),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: ListTile(
            leading: Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleProductSelection(product),
              activeColor: AccountantThemeConfig.primaryGreen,
              checkColor: Colors.white,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    product['displayName'] as String? ?? product['name'] as String? ?? '',
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: isSelected ? AccountantThemeConfig.primaryGreen : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                _buildStockIndicator(product),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product['category'] != null)
                  Text(
                    'الفئة: ${product['category']}',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white54,
                    ),
                  ),
                if (isLowStock)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '⚠️ مخزون قليل',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: Colors.orange,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: isSelected
                ? Icon(
                    Icons.check_circle,
                    color: AccountantThemeConfig.primaryGreen,
                    size: 20,
                  )
                : null,
            onTap: () => _toggleProductSelection(product),
          ),
        );
      },
    );
  }
}
