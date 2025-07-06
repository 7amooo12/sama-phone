import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/voucher_provider.dart';
import '../../models/voucher_model.dart';
import '../../utils/accountant_theme_config.dart';
import 'multiple_products_selector.dart';

class VoucherCreationForm extends StatefulWidget {

  const VoucherCreationForm({
    super.key,
    this.voucher,
    required this.onVoucherCreated,
  });
  final VoucherModel? voucher; // For editing existing voucher
  final Function(VoucherModel) onVoucherCreated;

  @override
  State<VoucherCreationForm> createState() => _VoucherCreationFormState();
}

class _VoucherCreationFormState extends State<VoucherCreationForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _discountController = TextEditingController();
  final _productSearchController = TextEditingController();

  VoucherType _selectedType = VoucherType.category;
  String? _selectedTargetId;
  String? _selectedTargetName;
  DateTime _expirationDate = DateTime.now().add(const Duration(days: 30));
  DiscountType _discountType = DiscountType.percentage;
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _showProductSearch = false;

  // Multiple products support
  List<Map<String, dynamic>> _selectedProducts = [];
  bool _showMultipleProductsSelector = false;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _discountController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    if (widget.voucher != null) {
      final voucher = widget.voucher!;
      _nameController.text = voucher.name;
      _descriptionController.text = voucher.description ?? '';
      _discountType = voucher.discountType;
      if (_discountType == DiscountType.percentage) {
        _discountController.text = voucher.discountPercentage.toString();
      } else {
        _discountController.text = voucher.discountAmount?.toString() ?? '0';
      }
      _selectedType = voucher.type;
      _selectedTargetId = voucher.targetId;
      _selectedTargetName = voucher.targetName;
      _expirationDate = voucher.expirationDate;
    }
  }

  Future<void> _loadData() async {
    final voucherProvider = Provider.of<VoucherProvider>(context, listen: false);
    await Future.wait([
      voucherProvider.loadProductCategories(),
      voucherProvider.loadProducts(),
    ]);
    _updateFilteredProducts();
  }

  void _updateFilteredProducts() {
    final voucherProvider = Provider.of<VoucherProvider>(context, listen: false);
    final searchQuery = _productSearchController.text.toLowerCase();

    if (searchQuery.isEmpty) {
      _filteredProducts = List.from(voucherProvider.products);
    } else {
      _filteredProducts = voucherProvider.products.where((product) {
        final productName = product['name'].toString().toLowerCase();
        return productName.contains(searchQuery);
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AccountantThemeConfig.primaryGreen.withOpacity(0.8),
                      AccountantThemeConfig.accentBlue.withOpacity(0.6),
                    ],
                  ),
                ),
                child: _buildHeader(),
              ),

              // Content area
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildNameField(),
                          const SizedBox(height: 20),
                          _buildDescriptionField(),
                          const SizedBox(height: 20),
                          _buildTypeSelection(),
                          const SizedBox(height: 20),
                          _buildTargetSelection(),
                          const SizedBox(height: 20),
                          _buildDiscountField(),
                          const SizedBox(height: 20),
                          _buildExpirationDateField(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Action buttons
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: _buildActionButtons(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.local_offer,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            widget.voucher != null ? 'تعديل القسيمة' : 'إنشاء قسيمة جديدة',
            style: AccountantThemeConfig.headlineMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'إغلاق',
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.label,
              color: AccountantThemeConfig.primaryGreen,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'اسم القسيمة *',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.05),
                Colors.white.withOpacity(0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: TextFormField(
            controller: _nameController,
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: 'مثال: خصم الجمعة البيضاء',
              hintStyle: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white60,
              ),
              prefixIcon: Icon(
                Icons.local_offer,
                color: AccountantThemeConfig.primaryGreen.withOpacity(0.7),
              ),
              filled: true,
              fillColor: Colors.transparent,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AccountantThemeConfig.primaryGreen,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.red,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال اسم القسيمة';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.description,
              color: AccountantThemeConfig.accentBlue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'الوصف',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.05),
                Colors.white.withOpacity(0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: TextFormField(
            controller: _descriptionController,
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white,
            ),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'وصف اختياري للقسيمة',
              hintStyle: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white60,
              ),
              prefixIcon: Icon(
                Icons.notes,
                color: AccountantThemeConfig.accentBlue.withOpacity(0.7),
              ),
              filled: true,
              fillColor: Colors.transparent,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AccountantThemeConfig.accentBlue,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.category,
              color: AccountantThemeConfig.primaryGreen,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'نوع القسيمة *',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildTypeOption(
                    type: VoucherType.category,
                    icon: Icons.category,
                    title: VoucherType.category.displayName,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTypeOption(
                    type: VoucherType.product,
                    icon: Icons.inventory,
                    title: VoucherType.product.displayName,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTypeOption(
              type: VoucherType.multipleProducts,
              icon: Icons.inventory_2,
              title: VoucherType.multipleProducts.displayName,
              isFullWidth: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeOption({
    required VoucherType type,
    required IconData icon,
    required String title,
    bool isFullWidth = false,
  }) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
          _selectedTargetId = null;
          _selectedTargetName = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                    AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                  ],
                )
              : LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.05),
                    Colors.white.withOpacity(0.02),
                  ],
                ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AccountantThemeConfig.primaryGreen
                : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AccountantThemeConfig.primaryGreen
                  : Colors.grey.shade400,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: isSelected ? Colors.white : Colors.white60,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _selectedType == VoucherType.category ? Icons.category : Icons.inventory,
              color: AccountantThemeConfig.accentBlue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _selectedType == VoucherType.category ? 'فئة المنتجات *' : 'المنتج *',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_selectedType == VoucherType.product) ...[
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                      AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _showProductSearch = !_showProductSearch;
                    });
                  },
                  icon: Icon(
                    _showProductSearch ? Icons.list : Icons.search,
                    color: AccountantThemeConfig.primaryGreen,
                    size: 20,
                  ),
                  tooltip: _showProductSearch ? 'عرض القائمة' : 'البحث',
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (_selectedType == VoucherType.category)
          _buildCategoryDropdown()
        else if (_selectedType == VoucherType.multipleProducts)
          _buildMultipleProductsSection()
        else if (_showProductSearch)
          _buildProductSearchField()
        else
          _buildProductDropdown(),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Consumer<VoucherProvider>(
      builder: (context, voucherProvider, child) {
        final categories = voucherProvider.productCategories;

        if (categories.isEmpty) {
          return _buildEmptyStateWidget('لا توجد فئات متاحة');
        }

        return _buildDropdownContainer(
          child: DropdownButtonFormField<String>(
            value: _selectedTargetId,
            style: AccountantThemeConfig.bodyLarge.copyWith(color: Colors.white),
            dropdownColor: AccountantThemeConfig.luxuryBlack,
            decoration: _buildDropdownDecoration('اختر فئة المنتجات', Icons.category),
            items: categories.map<DropdownMenuItem<String>>((category) {
              return DropdownMenuItem<String>(
                value: category.toString(),
                child: Text(
                  category.toString(),
                  style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedTargetId = value;
                _selectedTargetName = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى اختيار فئة المنتجات';
              }
              return null;
            },
          ),
        );
      },
    );
  }

  Widget _buildProductDropdown() {
    return Consumer<VoucherProvider>(
      builder: (context, voucherProvider, child) {
        final products = voucherProvider.products;

        if (products.isEmpty) {
          return _buildEmptyStateWidget('لا توجد منتجات متاحة');
        }

        return _buildDropdownContainer(
          child: DropdownButtonFormField<String>(
            value: _selectedTargetId,
            style: AccountantThemeConfig.bodyLarge.copyWith(color: Colors.white),
            dropdownColor: AccountantThemeConfig.luxuryBlack,
            decoration: _buildDropdownDecoration('اختر المنتج', Icons.inventory),
            items: products.map<DropdownMenuItem<String>>((product) {
              return DropdownMenuItem<String>(
                value: product['id'].toString(),
                child: Text(
                  product['name'].toString(),
                  style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedTargetId = value;
                final product = products.firstWhere((p) => p['id'].toString() == value);
                _selectedTargetName = product['name'].toString();
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى اختيار المنتج';
              }
              return null;
            },
          ),
        );
      },
    );
  }

  Widget _buildProductSearchField() {
    return Consumer<VoucherProvider>(
      builder: (context, voucherProvider, child) {
        return Column(
          children: [
            // Search input field
            _buildDropdownContainer(
              child: TextFormField(
                controller: _productSearchController,
                style: AccountantThemeConfig.bodyLarge.copyWith(color: Colors.white),
                decoration: _buildDropdownDecoration('ابحث عن المنتج...', Icons.search),
                onChanged: (value) {
                  setState(() {
                    _updateFilteredProducts();
                  });
                },
                validator: (value) {
                  if (_selectedTargetId == null || _selectedTargetId!.isEmpty) {
                    return 'يرجى اختيار المنتج';
                  }
                  return null;
                },
              ),
            ),

            // Search results
            if (_productSearchController.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.05),
                      Colors.white.withOpacity(0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: _filteredProducts.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'لا توجد منتجات مطابقة للبحث',
                          style: AccountantThemeConfig.bodyMedium.copyWith(
                            color: Colors.white60,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          final isSelected = _selectedTargetId == product['id'].toString();

                          return ListTile(
                            title: Text(
                              product['name'].toString(),
                              style: AccountantThemeConfig.bodyMedium.copyWith(
                                color: isSelected ? AccountantThemeConfig.primaryGreen : Colors.white,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            leading: Icon(
                              Icons.inventory,
                              color: isSelected ? AccountantThemeConfig.primaryGreen : Colors.grey.shade400,
                              size: 20,
                            ),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle,
                                    color: AccountantThemeConfig.primaryGreen,
                                    size: 20,
                                  )
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedTargetId = product['id'].toString();
                                _selectedTargetName = product['name'].toString();
                                _productSearchController.text = product['name'].toString();
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildEmptyStateWidget(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withOpacity(0.1),
            Colors.orange.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Text(
            message,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.warningOrange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: child,
    );
  }

  InputDecoration _buildDropdownDecoration(String hintText, IconData icon) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AccountantThemeConfig.bodyMedium.copyWith(
        color: Colors.white60,
      ),
      prefixIcon: Icon(
        icon,
        color: AccountantThemeConfig.accentBlue.withOpacity(0.7),
      ),
      filled: true,
      fillColor: Colors.transparent,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AccountantThemeConfig.accentBlue,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildDiscountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.discount,
              color: AccountantThemeConfig.primaryGreen,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'نوع الخصم *',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Discount type selection
        Row(
          children: [
            Expanded(
              child: _buildDiscountTypeOption(
                type: DiscountType.percentage,
                icon: Icons.percent,
                title: DiscountType.percentage.displayName,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDiscountTypeOption(
                type: DiscountType.fixedAmount,
                icon: Icons.attach_money,
                title: DiscountType.fixedAmount.displayName,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Discount value input
        Row(
          children: [
            Icon(
              _discountType == DiscountType.percentage ? Icons.percent : Icons.attach_money,
              color: AccountantThemeConfig.primaryGreen,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _discountType == DiscountType.percentage ? 'نسبة الخصم (%) *' : 'مبلغ الخصم (جنيه) *',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.05),
                Colors.white.withOpacity(0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: TextFormField(
            controller: _discountController,
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: _discountType == DiscountType.percentage ? 'مثال: 20' : 'مثال: 50.00',
              hintStyle: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white60,
              ),
              prefixIcon: Icon(
                Icons.discount,
                color: AccountantThemeConfig.primaryGreen.withOpacity(0.7),
              ),
              suffixIcon: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AccountantThemeConfig.primaryGreen,
                      AccountantThemeConfig.primaryGreen.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _discountType.symbol,
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              filled: true,
              fillColor: Colors.transparent,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AccountantThemeConfig.primaryGreen,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.red,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return _discountType == DiscountType.percentage
                    ? 'يرجى إدخال نسبة الخصم'
                    : 'يرجى إدخال مبلغ الخصم';
              }

              final discount = double.tryParse(value.trim());
              if (discount == null || discount <= 0) {
                return 'يجب أن تكون قيمة الخصم أكبر من صفر';
              }

              if (_discountType == DiscountType.percentage && discount > 100) {
                return 'يجب أن تكون نسبة الخصم أقل من أو تساوي 100%';
              }

              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDiscountTypeOption({
    required DiscountType type,
    required IconData icon,
    required String title,
  }) {
    final isSelected = _discountType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _discountType = type;
          _discountController.clear(); // Clear the input when switching types
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                    AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                  ],
                )
              : LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.05),
                    Colors.white.withOpacity(0.02),
                  ],
                ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AccountantThemeConfig.primaryGreen
                : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AccountantThemeConfig.primaryGreen
                  : Colors.grey.shade400,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: isSelected ? Colors.white : Colors.white60,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpirationDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_today,
              color: AccountantThemeConfig.accentBlue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'تاريخ الانتهاء *',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _selectExpirationDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.05),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AccountantThemeConfig.accentBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    color: AccountantThemeConfig.accentBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '${_expirationDate.day}/${_expirationDate.month}/${_expirationDate.year}',
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: AccountantThemeConfig.accentBlue,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.grey.withOpacity(0.1),
                  Colors.grey.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, size: 18),
              label: Text(
                'إلغاء',
                style: AccountantThemeConfig.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade300,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: _isLoading
                  ? LinearGradient(
                      colors: [
                        Colors.grey.withOpacity(0.3),
                        Colors.grey.withOpacity(0.2),
                      ],
                    )
                  : AccountantThemeConfig.blueGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: _isLoading ? null : [
                BoxShadow(
                  color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _submitForm,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      widget.voucher != null ? Icons.update : Icons.add,
                      size: 18,
                    ),
              label: Text(
                widget.voucher != null ? 'تحديث' : 'إنشاء',
                style: AccountantThemeConfig.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectExpirationDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _expirationDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.green,
              onPrimary: Colors.white,
              surface: Colors.grey,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      setState(() {
        _expirationDate = selectedDate;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validation for different voucher types
    if (_selectedType == VoucherType.multipleProducts) {
      if (_selectedProducts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى اختيار منتج واحد على الأقل'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else if (_selectedTargetId == null || _selectedTargetName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selectedType == VoucherType.category
              ? 'يرجى اختيار فئة المنتجات'
              : 'يرجى اختيار المنتج'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final voucherProvider = Provider.of<VoucherProvider>(context, listen: false);

      final discountValue = double.parse(_discountController.text.trim());

      if (widget.voucher != null) {
        // Update existing voucher
        final updateRequest = VoucherUpdateRequest(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          discountType: _discountType,
          discountPercentage: _discountType == DiscountType.percentage
              ? discountValue.toInt()
              : widget.voucher!.discountPercentage, // Keep existing percentage if switching to fixed amount
          discountAmount: _discountType == DiscountType.fixedAmount
              ? discountValue
              : null,
          expirationDate: _expirationDate,
        );

        final success = await voucherProvider.updateVoucher(widget.voucher!.id, updateRequest);
        if (success) {
          final updatedVoucher = voucherProvider.vouchers
              .firstWhere((v) => v.id == widget.voucher!.id);
          widget.onVoucherCreated(updatedVoucher);
        } else {
          throw Exception(voucherProvider.error ?? 'فشل في تحديث القسيمة');
        }
      } else {
        // Create new voucher
        VoucherCreateRequest createRequest;

        if (_selectedType == VoucherType.multipleProducts) {
          // Create voucher for multiple products
          createRequest = VoucherCreateRequest.forMultipleProducts(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            selectedProducts: _selectedProducts,
            discountPercentage: _discountType == DiscountType.percentage
                ? discountValue.toInt()
                : 0,
            discountType: _discountType,
            discountAmount: _discountType == DiscountType.fixedAmount
                ? discountValue
                : null,
            expirationDate: _expirationDate,
          );
        } else {
          // Create voucher for single product or category
          createRequest = VoucherCreateRequest(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            type: _selectedType,
            targetId: _selectedTargetId!,
            targetName: _selectedTargetName!,
            discountType: _discountType,
            // For fixed amount vouchers, set discountPercentage to 0 (will be converted to null in toJson)
            // For percentage vouchers, use the actual percentage value
            discountPercentage: _discountType == DiscountType.percentage
                ? discountValue.toInt()
                : 0, // This will be converted to null in toJson() for fixed_amount type
            discountAmount: _discountType == DiscountType.fixedAmount
                ? discountValue
                : null,
            expirationDate: _expirationDate,
          );
        }

        final voucher = await voucherProvider.createVoucher(createRequest);
        if (voucher != null) {
          widget.onVoucherCreated(voucher);
        } else {
          throw Exception(voucherProvider.error ?? 'فشل في إنشاء القسيمة');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Build multiple products selection section
  Widget _buildMultipleProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with selection info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                AccountantThemeConfig.accentBlue.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المنتجات المختارة',
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_selectedProducts.isNotEmpty)
                      Text(
                        'تم اختيار ${_selectedProducts.length} منتج',
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: AccountantThemeConfig.primaryGreen,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                      AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _showMultipleProductsSelector = !_showMultipleProductsSelector;
                    });
                  },
                  icon: Icon(
                    _showMultipleProductsSelector ? Icons.expand_less : Icons.expand_more,
                    color: AccountantThemeConfig.primaryGreen,
                    size: 20,
                  ),
                  tooltip: _showMultipleProductsSelector ? 'إخفاء الاختيار' : 'عرض الاختيار',
                ),
              ),
            ],
          ),
        ),

        // Selected products preview
        if (_selectedProducts.isNotEmpty && !_showMultipleProductsSelector) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.luxuryBlack.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المنتجات المختارة:',
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _selectedProducts.take(5).map((product) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AccountantThemeConfig.primaryGreen.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        product['name'] as String? ?? '',
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: AccountantThemeConfig.primaryGreen,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (_selectedProducts.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'و ${_selectedProducts.length - 5} منتجات أخرى...',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],

        // Multiple products selector
        if (_showMultipleProductsSelector) ...[
          const SizedBox(height: 12),
          Container(
            height: 400,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
              ),
            ),
            child: MultipleProductsSelector(
              selectedProducts: _selectedProducts,
              onSelectionChanged: (selectedProducts) {
                setState(() {
                  _selectedProducts = selectedProducts;
                  if (selectedProducts.isNotEmpty) {
                    _selectedTargetId = 'multiple_products';
                    _selectedTargetName = '${selectedProducts.length} منتجات مختارة';
                  } else {
                    _selectedTargetId = null;
                    _selectedTargetName = null;
                  }
                });
              },
              maxSelections: 50,
              showStockIndicators: true,
              allowOutOfStock: false,
            ),
          ),
        ],

        // Validation message
        if (_selectedType == VoucherType.multipleProducts && _selectedProducts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'يرجى اختيار منتج واحد على الأقل',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.red,
              ),
            ),
          ),
      ],
    );
  }
}
