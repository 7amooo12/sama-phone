import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/models/warehouse_model.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/providers/warehouse_provider.dart';
import 'package:smartbiztracker_new/providers/warehouse_products_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/widgets/common/advanced_search_bar.dart';
import 'package:smartbiztracker_new/widgets/common/enhanced_product_image.dart';

/// حوار إضافة منتج إلى المخزن مع البحث المتقدم
class AddProductToWarehouseDialog extends StatefulWidget {
  final WarehouseModel warehouse;
  final VoidCallback onProductAdded;

  const AddProductToWarehouseDialog({
    super.key,
    required this.warehouse,
    required this.onProductAdded,
  });

  @override
  State<AddProductToWarehouseDialog> createState() => _AddProductToWarehouseDialogState();
}

class _AddProductToWarehouseDialogState extends State<AddProductToWarehouseDialog> {
  final _searchController = TextEditingController();
  final _quantityController = TextEditingController();
  final _quantityPerCartonController = TextEditingController(text: '1');
  final _formKey = GlobalKey<FormState>();
  
  ProductModel? _selectedProduct;
  bool _isLoading = false;
  bool _isAddingProduct = false;

  @override
  void initState() {
    super.initState();
    // تحميل المنتجات عند فتح الحوار
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productsProvider = Provider.of<WarehouseProductsProvider>(context, listen: false);
      productsProvider.loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    _quantityPerCartonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        decoration: AccountantThemeConfig.primaryCardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // رأس الحوار
            _buildDialogHeader(),
            
            // محتوى الحوار
            Expanded(
              child: _selectedProduct == null
                  ? _buildProductSelectionView()
                  : _buildProductDetailsView(),
            ),
          ],
        ),
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
              children: [
                Text(
                  'إضافة منتج إلى المخزن',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  widget.warehouse.name,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
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
              child: AdvancedSearchBar(
                controller: _searchController,
                hintText: 'البحث عن منتج (اسم، فئة، SKU)...',
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
      return _buildLoadingState();
    }

    if (provider.hasError) {
      return _buildErrorState(provider.errorMessage, provider);
    }

    if (provider.filteredProducts.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: provider.filteredProducts.length,
      itemBuilder: (context, index) {
        final product = provider.filteredProducts[index];
        return _buildProductListItem(product);
      },
    );
  }

  /// بناء عنصر منتج في القائمة
  Widget _buildProductListItem(ProductModel product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectProduct(product),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // صورة المنتج
                SimpleProductImage(
                  product: product,
                  size: 60,
                ),
                const SizedBox(width: 16),
                
                // معلومات المنتج
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (product.category.isNotEmpty)
                        Text(
                          product.category,
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'الكمية الإجمالية: ${product.quantity}',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AccountantThemeConfig.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // أيقونة الاختيار
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
    );
  }

  /// بناء واجهة تفاصيل المنتج وإدخال الكمية
  Widget _buildProductDetailsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // معلومات المنتج المحدد
            _buildSelectedProductCard(),
            const SizedBox(height: 24),
            
            // حقل إدخال الكمية
            _buildQuantityField(),
            const SizedBox(height: 20),

            // حقل إدخال الكمية في الكرتونة
            _buildQuantityPerCartonField(),
            const SizedBox(height: 32),

            // أزرار الإجراءات
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  /// بناء بطاقة المنتج المحدد
  Widget _buildSelectedProductCard() {
    if (_selectedProduct == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // صورة المنتج
              SimpleProductImage(
                product: _selectedProduct!,
                size: 80,
              ),
              const SizedBox(width: 16),
              
              // معلومات المنتج
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedProduct!.name,
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_selectedProduct!.category.isNotEmpty)
                      Text(
                        _selectedProduct!.category,
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: AccountantThemeConfig.greenGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'الكمية الإجمالية: ${_selectedProduct!.quantity}',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // زر تغيير المنتج
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedProduct = null;
                  _quantityController.clear();
                  _quantityPerCartonController.clear();
                });
              },
              icon: const Icon(Icons.swap_horiz, size: 20),
              label: Text(
                'اختيار منتج آخر',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AccountantThemeConfig.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء حقل إدخال الكمية
  Widget _buildQuantityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الكمية في هذا المخزن',
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
              return 'الكمية لا يمكن أن تتجاوز الكمية الإجمالية (${_selectedProduct!.quantity})';
            }
            
            return null;
          },
        ),
        const SizedBox(height: 8),
        Text(
          'الحد الأقصى: ${_selectedProduct?.quantity ?? 0} قطعة',
          style: GoogleFonts.cairo(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  /// بناء حقل إدخال الكمية في الكرتونة
  Widget _buildQuantityPerCartonField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.inventory_outlined,
              size: 20,
              color: AccountantThemeConfig.primaryGreen,
            ),
            const SizedBox(width: 8),
            Text(
              'الكمية في الكرتونة',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              ' *',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _quantityPerCartonController,
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
            hintText: 'مثال: 12 قطعة في الكرتونة',
            hintStyle: GoogleFonts.cairo(
              color: Colors.white54,
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.all_inbox_outlined,
              color: AccountantThemeConfig.primaryGreen,
            ),
            suffixText: 'قطعة/كرتونة',
            suffixStyle: GoogleFonts.cairo(
              color: Colors.white70,
              fontSize: 12,
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
              return 'يرجى إدخال الكمية في الكرتونة';
            }

            final quantityPerCarton = int.tryParse(value.trim());
            if (quantityPerCarton == null || quantityPerCarton <= 0) {
              return 'يرجى إدخال كمية صحيحة أكبر من صفر';
            }

            if (quantityPerCarton > 1000) {
              return 'الكمية في الكرتونة لا يمكن أن تتجاوز 1000 قطعة';
            }

            return null;
          },
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AccountantThemeConfig.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: AccountantThemeConfig.primaryGreen,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'هذا الرقم يحدد كم قطعة توجد في الكرتونة الواحدة لحساب عدد الكراتين المطلوبة',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AccountantThemeConfig.primaryGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// بناء أزرار الإجراءات
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _isAddingProduct ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isAddingProduct ? null : _addProductToWarehouse,
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isAddingProduct
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'إضافة إلى المخزن',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// بناء حالة التحميل
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AccountantThemeConfig.primaryGreen,
          ),
          const SizedBox(height: 16),
          Text(
            'جاري تحميل المنتجات...',
            style: AccountantThemeConfig.bodyLarge,
          ),
        ],
      ),
    );
  }

  /// بناء حالة الخطأ
  Widget _buildErrorState(String? errorMessage, WarehouseProductsProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AccountantThemeConfig.warningOrange,
          ),
          const SizedBox(height: 16),
          Text(
            'خطأ في تحميل المنتجات',
            style: AccountantThemeConfig.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage ?? 'حدث خطأ غير متوقع',
            style: AccountantThemeConfig.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => provider.loadProducts(),
            icon: const Icon(Icons.refresh),
            label: Text(
              'إعادة المحاولة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء حالة عدم وجود منتجات
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد منتجات',
            style: AccountantThemeConfig.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'لم يتم العثور على منتجات مطابقة للبحث',
            style: AccountantThemeConfig.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// اختيار منتج
  void _selectProduct(ProductModel product) {
    setState(() {
      _selectedProduct = product;
    });
  }

  /// إضافة منتج إلى المخزن
  Future<void> _addProductToWarehouse() async {
    if (!_formKey.currentState!.validate() || _selectedProduct == null) {
      return;
    }

    setState(() {
      _isAddingProduct = true;
    });

    try {
      final warehouseProvider = Provider.of<WarehouseProvider>(context, listen: false);
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final currentUser = supabaseProvider.user;

      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final quantity = int.parse(_quantityController.text.trim());
      final quantityPerCarton = int.parse(_quantityPerCartonController.text.trim());

      // إضافة تسجيل للتحقق من القيم
      AppLogger.info('🔍 قيم الإدخال - الكمية: $quantity، الكمية في الكرتونة: $quantityPerCarton');

      final success = await warehouseProvider.addProductToWarehouse(
        warehouseId: widget.warehouse.id,
        productId: _selectedProduct!.id,
        quantity: quantity,
        addedBy: currentUser.id,
        quantityPerCarton: quantityPerCarton,
      );

      if (success && mounted) {
        Navigator.of(context).pop();

        // إشعار بالنجاح
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إضافة/تحديث المنتج في المخزن بنجاح',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: AccountantThemeConfig.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        // فرض تحديث البيانات للتأكد من عرض القيم الصحيحة
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          await warehouseProvider.loadWarehouseInventory(widget.warehouse.id, forceRefresh: true);
        }

        // استدعاء callback
        widget.onProductAdded();
      } else if (mounted) {
        // إشعار بالفشل مع رسالة الخطأ من Provider
        final warehouseProvider = Provider.of<WarehouseProvider>(context, listen: false);
        final errorMessage = warehouseProvider.error ?? 'فشل في إضافة المنتج إلى المخزن';

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
      AppLogger.error('خطأ في إضافة المنتج إلى المخزن: $e');

      if (mounted) {
        // تحسين رسائل الخطأ للمستخدم
        String errorMessage = 'حدث خطأ غير متوقع';

        if (e.toString().contains('المنتج موجود بالفعل')) {
          errorMessage = 'المنتج موجود بالفعل في هذا المخزن';
        } else if (e.toString().contains('ليس لديك صلاحية')) {
          errorMessage = 'ليس لديك صلاحية لإضافة منتجات إلى هذا المخزن';
        } else if (e.toString().contains('duplicate key')) {
          errorMessage = 'المنتج موجود بالفعل في المخزن';
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
          _isAddingProduct = false;
        });
      }
    }
  }
}
