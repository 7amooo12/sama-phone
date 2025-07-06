import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/warehouse_dispatch_provider.dart';
import 'package:smartbiztracker_new/providers/warehouse_products_provider.dart';
import 'package:smartbiztracker_new/providers/warehouse_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/models/warehouse_model.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/widgets/common/advanced_search_bar.dart';

/// حوار إضافة طلب صرف يدوي
class AddManualDispatchDialog extends StatefulWidget {
  final String userRole;
  final VoidCallback onDispatchAdded;

  const AddManualDispatchDialog({
    super.key,
    required this.userRole,
    required this.onDispatchAdded,
  });

  @override
  State<AddManualDispatchDialog> createState() => _AddManualDispatchDialogState();
}

class _AddManualDispatchDialogState extends State<AddManualDispatchDialog> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();

  ProductModel? _selectedProduct;
  WarehouseModel? _selectedWarehouse;
  bool _isLoading = false;
  bool _showProductSearch = false;

  @override
  void initState() {
    super.initState();
    // تحميل المنتجات والمخازن عند فتح الحوار
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productsProvider = Provider.of<WarehouseProductsProvider>(context, listen: false);
      final warehouseProvider = Provider.of<WarehouseProvider>(context, listen: false);

      productsProvider.loadProducts();
      warehouseProvider.loadWarehouses();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // تحديد أبعاد الحوار بناءً على حجم الشاشة
          final dialogWidth = constraints.maxWidth > 600
              ? 600.0
              : constraints.maxWidth * 0.9;
          final dialogHeight = constraints.maxHeight > 700
              ? 700.0
              : constraints.maxHeight * 0.9;

          return Container(
            width: dialogWidth,
            height: dialogHeight,
            decoration: AccountantThemeConfig.primaryCardDecoration,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // رأس الحوار
                _buildDialogHeader(),

                // محتوى الحوار
                Expanded(
                  child: _showProductSearch
                      ? _buildProductSelectionView()
                      : _buildFormView(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// بناء رأس الحوار
  Widget _buildDialogHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.greenGradient,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            const Icon(
              Icons.add_box_outlined,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'إضافة طلب صرف يدوي',
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'إنشاء طلب صرف منتجات من المخزن',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// بناء واجهة النموذج
  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // اختيار المخزن
            _buildWarehouseSelectionField(),
            const SizedBox(height: 20),

            // اختيار المنتج
            _buildProductSelectionField(),
            const SizedBox(height: 20),

            // الكمية المطلوبة
            _buildQuantityField(),
            const SizedBox(height: 20),

            // سبب الصرف
            _buildReasonField(),
            const SizedBox(height: 20),

            // ملاحظات إضافية
            _buildNotesField(),
            const SizedBox(height: 32),

            // أزرار الإجراءات
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  /// بناء حقل اختيار المخزن
  Widget _buildWarehouseSelectionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'المخزن المطلوب الصرف منه *',
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),

        Consumer<WarehouseProvider>(
          builder: (context, warehouseProvider, child) {
            if (warehouseProvider.isLoading) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AccountantThemeConfig.primaryGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'جاري تحميل المخازن...',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            color: Colors.white54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (warehouseProvider.warehouses.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AccountantThemeConfig.warningOrange.withOpacity(0.3),
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_outlined,
                        color: AccountantThemeConfig.warningOrange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'لا توجد مخازن متاحة',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            color: AccountantThemeConfig.warningOrange,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return DropdownButtonFormField<WarehouseModel>(
              value: _selectedWarehouse,
              decoration: InputDecoration(
                hintText: 'اختر المخزن',
                hintStyle: GoogleFonts.cairo(
                  color: Colors.white54,
                ),
                prefixIcon: Icon(
                  Icons.warehouse_outlined,
                  color: AccountantThemeConfig.primaryGreen,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                  ),
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
                  borderSide: BorderSide(
                    color: AccountantThemeConfig.warningOrange,
                  ),
                ),
              ),
              dropdownColor: const Color(0xFF1A1A2E),
              style: GoogleFonts.cairo(
                fontSize: 16,
                color: Colors.white,
              ),
              items: warehouseProvider.warehouses.map((warehouse) {
                return DropdownMenuItem<WarehouseModel>(
                  value: warehouse,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500), // تحديد عرض أقصى
                    child: Row(
                      mainAxisSize: MainAxisSize.min, // منع التوسع غير المحدود
                      children: [
                        Icon(
                          Icons.warehouse,
                          color: AccountantThemeConfig.primaryGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible( // استخدام Flexible بدلاً من Expanded
                          child: Text(
                            warehouse.name,
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (WarehouseModel? warehouse) {
                setState(() {
                  _selectedWarehouse = warehouse;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'يرجى اختيار المخزن المطلوب الصرف منه';
                }
                return null;
              },
            );
          },
        ),
      ],
    );
  }

  /// بناء حقل اختيار المنتج
  Widget _buildProductSelectionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'المنتج المطلوب',
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        
        if (_selectedProduct == null)
          // زر اختيار منتج
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _showProductSearch = true;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: AccountantThemeConfig.primaryGreen,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'اضغط لاختيار منتج من القائمة',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            color: Colors.white54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: AccountantThemeConfig.primaryGreen,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          // المنتج المحدد
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.cardGradient,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // صورة المنتج
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _selectedProduct!.imageUrl != null && _selectedProduct!.imageUrl!.isNotEmpty
                          ? Image.network(
                              _selectedProduct!.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.image_not_supported, color: Colors.white54),
                            )
                          : const Icon(Icons.inventory_2, color: Colors.white54),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // معلومات المنتج
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedProduct!.name,
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'الكمية المتاحة: ${_selectedProduct!.quantity}',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: AccountantThemeConfig.primaryGreen,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // زر تغيير المنتج
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedProduct = null;
                        _quantityController.clear();
                      });
                    },
                    icon: const Icon(
                      Icons.edit,
                      color: Colors.white70,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// بناء حقل الكمية
  Widget _buildQuantityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الكمية المطلوبة',
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _quantityController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          style: GoogleFonts.cairo(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: 'أدخل الكمية',
            hintStyle: GoogleFonts.cairo(
              color: Colors.white54,
            ),
            prefixIcon: Icon(
              Icons.numbers,
              color: AccountantThemeConfig.primaryGreen,
            ),
            suffixText: 'قطعة',
            suffixStyle: GoogleFonts.cairo(
              color: Colors.white70,
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.1),
              ),
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
              borderSide: BorderSide(
                color: AccountantThemeConfig.warningOrange,
              ),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'يرجى إدخال الكمية';
            }
            
            final quantity = int.tryParse(value.trim());
            if (quantity == null || quantity <= 0) {
              return 'يرجى إدخال كمية صحيحة';
            }
            
            if (_selectedProduct != null && quantity > _selectedProduct!.quantity) {
              return 'الكمية لا يمكن أن تتجاوز المتاح (${_selectedProduct!.quantity})';
            }
            
            return null;
          },
        ),
        if (_selectedProduct != null) ...[
          const SizedBox(height: 8),
          Text(
            'الحد الأقصى: ${_selectedProduct!.quantity} قطعة',
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ],
    );
  }

  /// بناء حقل سبب الصرف
  Widget _buildReasonField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'سبب الصرف',
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _reasonController,
          style: GoogleFonts.cairo(
            fontSize: 16,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: 'أدخل سبب الصرف (مثل: طلب عميل، صيانة، إلخ)',
            hintStyle: GoogleFonts.cairo(
              color: Colors.white54,
            ),
            prefixIcon: Icon(
              Icons.description_outlined,
              color: AccountantThemeConfig.primaryGreen,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.1),
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
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'يرجى إدخال سبب الصرف';
            }
            if (value.trim().length < 3) {
              return 'يجب أن يكون السبب 3 أحرف على الأقل';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// بناء حقل الملاحظات
  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ملاحظات إضافية (اختياري)',
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          style: GoogleFonts.cairo(
            fontSize: 16,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: 'أدخل أي ملاحظات إضافية...',
            hintStyle: GoogleFonts.cairo(
              color: Colors.white54,
            ),
            prefixIcon: Icon(
              Icons.note_outlined,
              color: AccountantThemeConfig.primaryGreen,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.1),
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
      ],
    );
  }

  /// بناء أزرار الإجراءات
  Widget _buildActionButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(0, 48),
                  ),
                  child: Text(
                    'إلغاء',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createManualDispatch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AccountantThemeConfig.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    minimumSize: const Size(0, 48),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'إنشاء طلب الصرف',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// بناء واجهة اختيار المنتج
  Widget _buildProductSelectionView() {
    return Consumer<WarehouseProductsProvider>(
      builder: (context, productsProvider, child) {
        return Column(
          children: [
            // شريط البحث
            Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return IntrinsicHeight(
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _showProductSearch = false;
                            });
                          },
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                        Expanded(
                          child: AdvancedSearchBar(
                            controller: _searchController,
                            hintText: 'البحث عن منتج...',
                            accentColor: AccountantThemeConfig.primaryGreen,
                            showSearchAnimation: true,
                            onChanged: (query) {
                              productsProvider.setSearchQuery(query);
                            },
                            onSubmitted: (query) {
                              productsProvider.setSearchQuery(query);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // قائمة المنتجات
            Expanded(
              child: _buildProductsList(productsProvider),
            ),
          ],
        );
      },
    );
  }

  /// بناء قائمة المنتجات
  Widget _buildProductsList(WarehouseProductsProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    if (provider.filteredProducts.isEmpty) {
      return Center(
        child: Text(
          'لا توجد منتجات',
          style: AccountantThemeConfig.bodyLarge,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: provider.filteredProducts.length,
      itemBuilder: (context, index) {
        final product = provider.filteredProducts[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.image_not_supported, color: Colors.white54, size: 20),
                      )
                    : const Icon(Icons.inventory_2, color: Colors.white54, size: 20),
              ),
            ),
            title: Text(
              product.name,
              style: AccountantThemeConfig.bodyLarge,
            ),
            subtitle: Text(
              'الكمية المتاحة: ${product.quantity}',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: AccountantThemeConfig.primaryGreen,
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white54,
              size: 16,
            ),
            onTap: () {
              setState(() {
                _selectedProduct = product;
                _showProductSearch = false;
              });
            },
          ),
        );
      },
    );
  }

  /// إنشاء طلب صرف يدوي
  Future<void> _createManualDispatch() async {
    if (!_formKey.currentState!.validate() || _selectedProduct == null || _selectedWarehouse == null) {
      if (_selectedWarehouse == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'يرجى اختيار المخزن المطلوب الصرف منه',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: AccountantThemeConfig.warningOrange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final dispatchProvider = Provider.of<WarehouseDispatchProvider>(context, listen: false);
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final currentUser = supabaseProvider.user;

      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final quantity = int.parse(_quantityController.text.trim());

      final success = await dispatchProvider.createManualDispatch(
        productName: _selectedProduct!.name,
        quantity: quantity,
        reason: _reasonController.text.trim(),
        requestedBy: currentUser.id,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        warehouseId: _selectedWarehouse?.id,
      );

      if (success && mounted) {
        Navigator.of(context).pop();
        
        // إشعار بالنجاح
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إنشاء طلب الصرف بنجاح',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: AccountantThemeConfig.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        // استدعاء callback
        widget.onDispatchAdded();
      } else if (mounted) {
        // إشعار بالفشل مع رسالة الخطأ من Provider
        final dispatchProvider = Provider.of<WarehouseDispatchProvider>(context, listen: false);
        final errorMessage = dispatchProvider.errorMessage ?? 'فشل في إنشاء طلب الصرف';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: AccountantThemeConfig.warningOrange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('خطأ في إنشاء طلب الصرف: $e');

      if (mounted) {
        // تحسين رسائل الخطأ للمستخدم
        String errorMessage = 'حدث خطأ غير متوقع';

        if (e.toString().contains('يجب اختيار المخزن')) {
          errorMessage = 'يجب اختيار المخزن المطلوب الصرف منه';
        } else if (e.toString().contains('null value in column "warehouse_id"')) {
          errorMessage = 'يجب اختيار المخزن المطلوب الصرف منه';
        } else if (e.toString().contains('المستخدم غير مسجل دخول')) {
          errorMessage = 'يجب تسجيل الدخول أولاً';
        } else if (e.toString().contains('ليس لديك صلاحية')) {
          errorMessage = 'ليس لديك صلاحية لإنشاء طلبات الصرف';
        } else {
          errorMessage = 'حدث خطأ: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
