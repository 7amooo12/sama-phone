import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/invoice_models.dart';
import '../../services/product_search_service.dart';
import '../../services/invoice_creation_service.dart';
import '../../services/invoice_pdf_service.dart';
import '../../services/whatsapp_service.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/invoice/edit_item_dialog.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _notesController = TextEditingController();
  final _discountController = TextEditingController(text: '0');

  final ProductSearchService _productSearchService = ProductSearchService();
  final InvoiceCreationService _invoiceService = InvoiceCreationService();
  final InvoicePdfService _pdfService = InvoicePdfService();
  final WhatsAppService _whatsappService = WhatsAppService();

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'ar_EG',
    symbol: 'جنيه',
    decimalDigits: 2,
  );

  List<ProductSearchResult> _searchResults = [];
  final List<InvoiceItem> _invoiceItems = [];
  ProductSearchResult? _selectedProduct;
  bool _isSearching = false;
  bool _isLoading = false;
  bool _showProductForm = false;

  // Product form fields
  final _productNameController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  int _availableQuantity = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    _customerAddressController.dispose();
    _notesController.dispose();
    _discountController.dispose();
    _productNameController.dispose();
    _unitPriceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _searchResults.clear();
        _showProductForm = false;
      });
      return;
    }

    _performSearch(_searchController.text);
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 2) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _productSearchService.searchProducts(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      _showErrorSnackBar('خطأ في البحث: ${e.toString()}');
    }
  }

  void _selectProduct(ProductSearchResult product) {
    setState(() {
      _selectedProduct = product;
      _showProductForm = true;
      _searchResults.clear();
      _searchController.text = product.name;
      
      // Fill product form
      _productNameController.text = product.name;
      _unitPriceController.text = product.price.toString();
      _availableQuantity = product.availableQuantity;
      _quantityController.text = '1';
    });
  }

  void _addProductToInvoice() {
    if (_selectedProduct == null) return;

    final quantity = int.tryParse(_quantityController.text) ?? 1;
    final unitPrice = double.tryParse(_unitPriceController.text) ?? 0;

    if (quantity <= 0) {
      _showErrorSnackBar('الكمية يجب أن تكون أكبر من صفر');
      return;
    }

    if (quantity > _availableQuantity) {
      _showErrorSnackBar('الكمية المطلوبة أكبر من المتوفر في المخزون');
      return;
    }

    if (unitPrice <= 0) {
      _showErrorSnackBar('السعر يجب أن يكون أكبر من صفر');
      return;
    }

    final item = InvoiceItem.fromProduct(
      productId: _selectedProduct!.id,
      productName: _productNameController.text,
      productImage: _selectedProduct!.imageUrl,
      category: _selectedProduct!.category,
      unitPrice: unitPrice,
      quantity: quantity,
    );

    setState(() {
      _invoiceItems.add(item);
      _clearProductForm();
    });

    _showSuccessSnackBar('تم إضافة المنتج للفاتورة');
  }

  void _clearProductForm() {
    _selectedProduct = null;
    _showProductForm = false;
    _searchController.clear();
    _productNameController.clear();
    _unitPriceController.clear();
    _quantityController.text = '1';
    _availableQuantity = 0;
  }

  void _removeItem(int index) {
    setState(() {
      _invoiceItems.removeAt(index);
    });
    _showSuccessSnackBar('تم حذف المنتج من الفاتورة');
  }

  void _editItem(int index) {
    final item = _invoiceItems[index];
    
    showDialog(
      context: context,
      builder: (context) => EditItemDialog(
        item: item,
        onSave: (updatedItem) {
          setState(() {
            _invoiceItems[index] = updatedItem;
          });
          _showSuccessSnackBar('تم تحديث المنتج');
        },
      ),
    );
  }

  double get _subtotal {
    return _invoiceItems.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  double get _discount {
    return double.tryParse(_discountController.text) ?? 0.0;
  }

  double get _total {
    return _subtotal - _discount; // No tax calculation
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) return;
    if (_invoiceItems.isEmpty) {
      _showErrorSnackBar('يجب إضافة منتج واحد على الأقل');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final invoice = Invoice.create(
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim().isEmpty 
            ? null : _customerPhoneController.text.trim(),
        customerEmail: _customerEmailController.text.trim().isEmpty 
            ? null : _customerEmailController.text.trim(),
        customerAddress: _customerAddressController.text.trim().isEmpty 
            ? null : _customerAddressController.text.trim(),
        items: _invoiceItems,
        discount: _discount,
        notes: _notesController.text.trim().isEmpty 
            ? null : _notesController.text.trim(),
      );

      // Validate invoice
      final validation = _invoiceService.validateInvoice(invoice);
      if (validation['isValid'] != true) {
        _showErrorSnackBar(validation['errors']?.toString() ?? 'خطأ في التحقق من الفاتورة');
        return;
      }

      // Create invoice
      final result = await _invoiceService.createInvoice(invoice);

      if (result['success'] == true) {
        _showSuccessSnackBar('تم إنشاء الفاتورة بنجاح');
        
        // Show options dialog
        _showInvoiceOptionsDialog(invoice);
      } else {
        _showErrorSnackBar(result['message']?.toString() ?? 'خطأ في إنشاء الفاتورة');
      }
    } catch (e) {
      _showErrorSnackBar('خطأ في إنشاء الفاتورة: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showInvoiceOptionsDialog(Invoice invoice) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('تم إنشاء الفاتورة بنجاح'),
        content: const Text('ماذا تريد أن تفعل الآن؟'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to dashboard
            },
            child: const Text('العودة للوحة التحكم'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _generateAndSharePdf(invoice);
            },
            child: const Text('إنشاء PDF'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _shareViaWhatsApp(invoice);
            },
            child: const Text('مشاركة عبر واتساب'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndSharePdf(Invoice invoice) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final pdfBytes = await _pdfService.generateInvoicePdf(invoice);
      final fileName = 'invoice_${invoice.id}.pdf';
      final filePath = await _pdfService.savePdfToDevice(pdfBytes, fileName);

      if (filePath != null) {
        _showSuccessSnackBar('تم حفظ PDF في: $filePath');
      } else {
        _showErrorSnackBar('فشل في حفظ PDF');
      }
    } catch (e) {
      _showErrorSnackBar('خطأ في إنشاء PDF: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _shareViaWhatsApp(Invoice invoice) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final success = await _whatsappService.shareInvoiceViaWhatsApp(
        invoice: invoice,
        phoneNumber: invoice.customerPhone,
      );

      if (success) {
        _showSuccessSnackBar('تم فتح واتساب للمشاركة');
      } else {
        _showErrorSnackBar('فشل في فتح واتساب');
      }
    } catch (e) {
      _showErrorSnackBar('خطأ في مشاركة واتساب: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Fix and validate image URL
  String? _fixImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty || imageUrl == 'null') {
      return null;
    }

    // إذا كان URL كاملاً، استخدمه كما هو
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }

    // إذا كان مسار نسبي، أضف المسار الكامل
    if (imageUrl.startsWith('/')) {
      return 'https://samastock.pythonanywhere.com$imageUrl';
    }

    // إذا كان اسم ملف فقط، أضف المسار الكامل
    return 'https://samastock.pythonanywhere.com/static/uploads/$imageUrl';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const CustomAppBar(
        title: 'إنشاء فاتورة جديدة',
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        showBackButton: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProductSearchSection(),
                  if (_showProductForm) ...[
                    const SizedBox(height: 24),
                    _buildProductFormSection(),
                  ],
                  if (_invoiceItems.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildInvoiceItemsSection(),
                    const SizedBox(height: 24),
                    _buildTotalsSection(),
                  ],
                  const SizedBox(height: 24),
                  _buildCustomerInfoSection(),
                  const SizedBox(height: 24),
                  _buildNotesSection(),
                ],
              ),
            ),
          ),
          _buildBottomSection(),
        ],
      ),
    );
  }

  Widget _buildProductSearchSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade900,
            Colors.black,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.search, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'البحث عن المنتجات',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'ابحث عن المنتج بالاسم أو الفئة...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
              suffixIcon: _isSearching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF10B981),
                      ),
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade800,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
              ),
            ),
          ),
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade600),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final product = _searchResults[index];
                  return _buildProductSearchItem(product);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductSearchItem(ProductSearchResult product) {
    return ListTile(
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.shade700,
        ),
        child: _fixImageUrl(product.imageUrl) != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _fixImageUrl(product.imageUrl)!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                        color: const Color(0xFF10B981),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.image, color: Colors.grey.shade500);
                  },
                ),
              )
            : Icon(Icons.inventory, color: Colors.grey.shade500),
      ),
      title: Text(
        product.name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontFamily: 'Cairo',
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'السعر: ${_currencyFormat.format(product.price)}',
            style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
          ),
          Text(
            'المتوفر: ${product.availableQuantity}',
            style: TextStyle(
              color: product.inStock ? Colors.green : Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      trailing: Icon(
        product.inStock ? Icons.add_circle : Icons.remove_circle,
        color: product.inStock ? const Color(0xFF10B981) : Colors.red,
      ),
      onTap: product.inStock ? () => _selectProduct(product) : null,
    );
  }

  Widget _buildProductFormSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade900,
            Colors.black,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'تفاصيل المنتج',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _clearProductForm,
                icon: const Icon(Icons.close, color: Colors.red),
                tooltip: 'إلغاء',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Product image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade800,
                  border: Border.all(color: Colors.grey.shade600),
                ),
                child: _selectedProduct?.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _selectedProduct!.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.image, color: Colors.grey.shade500, size: 40);
                          },
                        ),
                      )
                    : Icon(Icons.inventory, color: Colors.grey.shade500, size: 40),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    // Product name
                    TextFormField(
                      controller: _productNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'اسم المنتج',
                        labelStyle: TextStyle(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.grey.shade800,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF10B981)),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'اسم المنتج مطلوب';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _unitPriceController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            decoration: InputDecoration(
                              labelText: 'السعر',
                              labelStyle: TextStyle(color: Colors.grey.shade400),
                              suffixText: 'جنيه',
                              suffixStyle: TextStyle(color: Colors.grey.shade400),
                              filled: true,
                              fillColor: Colors.grey.shade800,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFF10B981)),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'السعر مطلوب';
                              }
                              final price = double.tryParse(value);
                              if (price == null || price <= 0) {
                                return 'السعر غير صحيح';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade600),
                          ),
                          child: Text(
                            'متوفر: $_availableQuantity',
                            style: TextStyle(
                              color: _availableQuantity > 0 ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _quantityController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'الكمية المطلوبة',
                    labelStyle: TextStyle(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.grey.shade800,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF10B981)),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الكمية مطلوبة';
                    }
                    final quantity = int.tryParse(value);
                    if (quantity == null || quantity <= 0) {
                      return 'الكمية غير صحيحة';
                    }
                    if (quantity > _availableQuantity) {
                      return 'الكمية أكبر من المتوفر';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _addProductToInvoice,
                icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                label: const Text(
                  'إضافة للفاتورة',
                  style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceItemsSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade900,
            Colors.black,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shopping_cart, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'منتجات الفاتورة (${_invoiceItems.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _invoiceItems.length,
            itemBuilder: (context, index) {
              final item = _invoiceItems[index];
              return _buildInvoiceItemCard(item, index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceItemCard(InvoiceItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade600),
      ),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade700,
          ),
          child: _fixImageUrl(item.productImage) != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _fixImageUrl(item.productImage)!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          strokeWidth: 2,
                          color: const Color(0xFF10B981),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.image, color: Colors.grey.shade500);
                    },
                  ),
                )
              : Icon(Icons.inventory, color: Colors.grey.shade500),
        ),
        title: Text(
          item.productName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontFamily: 'Cairo',
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الكمية: ${item.quantity} × ${_currencyFormat.format(item.unitPrice)}',
              style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
            ),
            Text(
              'الإجمالي: ${_currencyFormat.format(item.subtotal)}',
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _editItem(index),
              icon: const Icon(Icons.edit, color: Color(0xFF10B981)),
              tooltip: 'تعديل',
            ),
            IconButton(
              onPressed: () => _removeItem(index),
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'حذف',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalsSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade900,
            Colors.black,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calculate, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'ملخص الفاتورة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTotalRow('المجموع الفرعي:', _subtotal),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _discountController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'الخصم',
                    labelStyle: TextStyle(color: Colors.grey.shade400),
                    suffixText: 'جنيه',
                    suffixStyle: TextStyle(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.grey.shade800,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF10B981)),
                    ),
                  ),
                  onChanged: (value) => setState(() {}),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.grey),
          _buildTotalRow('الإجمالي النهائي:', _total, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Cairo',
            ),
          ),
          Text(
            _currencyFormat.format(amount),
            style: TextStyle(
              color: isTotal ? const Color(0xFF10B981) : Colors.white,
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfoSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade900,
            Colors.black,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'بيانات العميل',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _customerNameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'اسم العميل *',
              labelStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.person_outline, color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.grey.shade800,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF10B981)),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'اسم العميل مطلوب';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerPhoneController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'رقم الهاتف',
              labelStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.phone_outlined, color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.grey.shade800,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF10B981)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _customerEmailController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    labelStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: Icon(Icons.email_outlined, color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.grey.shade800,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF10B981)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerAddressController,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'العنوان',
              labelStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.location_on_outlined, color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.grey.shade800,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF10B981)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade900,
            Colors.black,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.note_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'ملاحظات إضافية',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'أضف أي ملاحظات إضافية للفاتورة...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.grey.shade800,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF10B981)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        border: Border(
          top: BorderSide(color: Colors.grey.shade700),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
              label: const Text(
                'إلغاء',
                style: TextStyle(color: Colors.red, fontFamily: 'Cairo'),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveInvoice,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(
                _isLoading ? 'جاري الحفظ...' : 'حفظ الفاتورة',
                style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
