import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smartbiztracker_new/models/purchase_invoice_models.dart';
import 'package:smartbiztracker_new/services/purchase_invoice_service.dart';
import 'package:smartbiztracker_new/services/purchase_invoice_pdf_service.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:intl/intl.dart';
import 'dart:io';

class CreatePurchaseInvoiceScreen extends StatefulWidget {
  const CreatePurchaseInvoiceScreen({super.key});

  @override
  State<CreatePurchaseInvoiceScreen> createState() => _CreatePurchaseInvoiceScreenState();
}

class _CreatePurchaseInvoiceScreenState extends State<CreatePurchaseInvoiceScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final PurchaseInvoiceService _invoiceService = PurchaseInvoiceService();
  final PurchaseInvoicePdfService _pdfService = PurchaseInvoicePdfService();

  // Form controllers
  final TextEditingController _supplierNameController = TextEditingController();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _yuanPriceController = TextEditingController();
  final TextEditingController _exchangeRateController = TextEditingController();
  final TextEditingController _profitMarginController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // State variables
  bool _isLoading = false;
  File? _selectedImage;
  double _profitMarginSlider = 0.0; // Default to 0% profit margin
  List<PurchaseInvoiceItem> _invoiceItems = [];

  // Edit mode support
  bool _isEditMode = false;
  PurchaseInvoice? _editingInvoice;

  // Persistent profit margin state (session-level)
  double? _lastUsedProfitMargin; // Remembers last used profit margin
  bool _isProfitMarginRemembered = false; // Visual indicator flag

  // Currency formatters
  final NumberFormat _egpFormat = NumberFormat.currency(
    locale: 'ar_EG',
    symbol: 'جنيه ',
    decimalDigits: 2,
  );

  final NumberFormat _yuanFormat = NumberFormat.currency(
    locale: 'zh_CN',
    symbol: '¥',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _exchangeRateController.text = '2.45'; // Current approximate rate
    _profitMarginController.text = _profitMarginSlider.toString(); // Default 0%
    _quantityController.text = '1'; // Default quantity

    // Add listeners for real-time calculation
    _yuanPriceController.addListener(_updateCalculations);
    _exchangeRateController.addListener(_updateCalculations);
    _profitMarginController.addListener(_updateCalculations);
    _quantityController.addListener(_updateCalculations);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check for edit mode arguments
    final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (arguments != null && arguments.containsKey('editInvoice')) {
      final invoice = arguments['editInvoice'] as PurchaseInvoice;
      _initializeEditMode(invoice);
    }
  }

  void _initializeEditMode(PurchaseInvoice invoice) {
    if (!_isEditMode) {
      setState(() {
        _isEditMode = true;
        _editingInvoice = invoice;

        // Populate form fields with invoice data
        _supplierNameController.text = invoice.supplierName ?? '';
        _notesController.text = invoice.notes ?? '';

        // Populate invoice items
        _invoiceItems = List.from(invoice.items);
      });
    }
  }

  @override
  void dispose() {
    _supplierNameController.dispose();
    _productNameController.dispose();
    _yuanPriceController.dispose();
    _exchangeRateController.dispose();
    _profitMarginController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateCalculations() {
    setState(() {}); // Trigger rebuild to update calculated values
  }

  /// Save current profit margin for persistence within session
  void _saveProfitMarginToSession() {
    final currentMargin = double.tryParse(_profitMarginController.text) ?? 0.0;
    if (currentMargin >= 0) {
      _lastUsedProfitMargin = currentMargin;
      setState(() {
        _isProfitMarginRemembered = true;
      });
    }
  }

  /// Apply last used profit margin if available
  void _applyLastUsedProfitMargin() {
    if (_lastUsedProfitMargin != null) {
      setState(() {
        // Clamp the value to ensure it's within the Slider's range (0-300)
        _profitMarginSlider = _lastUsedProfitMargin!.clamp(0.0, 300.0);
        _profitMarginController.text = _lastUsedProfitMargin!.toStringAsFixed(1);
        _isProfitMarginRemembered = true;
      });
    }
  }

  /// Reset profit margin to 0%
  void _resetProfitMarginToZero() {
    setState(() {
      _profitMarginSlider = 0.0;
      _profitMarginController.text = '0.0';
      _isProfitMarginRemembered = false;
    });
  }

  int get _quantity {
    return int.tryParse(_quantityController.text) ?? 1;
  }

  double get _calculatedFinalPrice {
    final yuanPrice = double.tryParse(_yuanPriceController.text) ?? 0.0;
    final exchangeRate = double.tryParse(_exchangeRateController.text) ?? 0.0;
    final profitMargin = double.tryParse(_profitMarginController.text) ?? 0.0;

    final baseEgpPrice = yuanPrice * exchangeRate;
    final profitAmount = baseEgpPrice * (profitMargin / 100);
    return baseEgpPrice + profitAmount;
  }

  double get _totalPrice {
    return _calculatedFinalPrice * _quantity;
  }

  double get _baseEgpPrice {
    final yuanPrice = double.tryParse(_yuanPriceController.text) ?? 0.0;
    final exchangeRate = double.tryParse(_exchangeRateController.text) ?? 0.0;
    return yuanPrice * exchangeRate;
  }

  double get _profitAmount {
    return _baseEgpPrice * (_profitMarginSlider / 100);
  }

  double get _totalProfitAmount {
    return _profitAmount * _quantity;
  }

  /// Build styled TextFormField with AccountantThemeConfig styling
  Widget _buildStyledTextFormField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    ui.TextDirection? textDirection,
    void Function(String)? onChanged,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        textDirection: textDirection,
        onChanged: onChanged,
        style: GoogleFonts.cairo(
          color: Colors.white,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          labelStyle: GoogleFonts.cairo(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
          ),
          hintStyle: GoogleFonts.cairo(
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            prefixIcon,
            color: AccountantThemeConfig.primaryGreen,
          ),
          suffix: suffix,
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
            borderSide: BorderSide(
              color: AccountantThemeConfig.primaryGreen,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
            borderSide: BorderSide(
              color: AccountantThemeConfig.dangerRed,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: _isEditMode ? 'تعديل فاتورة مشتريات' : 'إنشاء فاتورة مشتريات',
        showNotificationIcon: false,
        actions: [
          // QR Code Scanner Button (moved from notifications position)
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.greenGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.qr_code_scanner_rounded,
                color: Colors.white,
                size: 22,
              ),
              onPressed: () {
                // TODO: Implement QR scanner functionality
                _showInfoSnackBar('ماسح QR قيد التطوير');
              },
              tooltip: 'ماسح الرمز المربع',
              splashRadius: 20,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: _buildBody(),
      ),
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
                  _buildSupplierSection(),
                  const SizedBox(height: 24),
                  _buildProductSection(),
                  const SizedBox(height: 24),
                  _buildPricingSection(),
                  const SizedBox(height: 24),
                  _buildCalculationDisplay(),
                  if (_invoiceItems.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildInvoiceItemsSection(),
                  ],
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

  Widget _buildSupplierSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.greenGradient,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                ),
                child: const Icon(Icons.business_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'معلومات المورد',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStyledTextFormField(
            controller: _supplierNameController,
            labelText: 'اسم المورد (اختياري)',
            hintText: 'أدخل اسم المورد',
            prefixIcon: Icons.person_outline_rounded,
            textDirection: ui.TextDirection.rtl,
          ),
        ],
      ),
    ).animate().fadeIn(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    ).slideY(
      begin: 0.2,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildProductSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.blueGradient,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
                ),
                child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'تفاصيل المنتج',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStyledTextFormField(
            controller: _productNameController,
            labelText: 'اسم المنتج *',
            hintText: 'أدخل اسم المنتج',
            prefixIcon: Icons.shopping_bag_outlined,
            textDirection: ui.TextDirection.rtl,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'اسم المنتج مطلوب';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildStyledTextFormField(
            controller: _quantityController,
            labelText: 'الكمية *',
            hintText: '1',
            prefixIcon: Icons.numbers_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'الكمية مطلوبة';
              }
              final quantity = int.tryParse(value);
              if (quantity == null || quantity <= 0) {
                return 'الكمية يجب أن تكون أكبر من صفر';
              }
              if (quantity > 9999) {
                return 'الكمية يجب أن تكون أقل من 10000';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildImagePicker(),
        ],
      ),
    ).animate().fadeIn(
      delay: const Duration(milliseconds: 200),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    ).slideY(
      begin: 0.2,
      delay: const Duration(milliseconds: 200),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'صورة المنتج',
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
              boxShadow: AccountantThemeConfig.cardShadows,
            ),
            child: _selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: AccountantThemeConfig.greenGradient,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Icon(
                          Icons.add_a_photo_rounded,
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'اضغط لإضافة صورة',
                        style: GoogleFonts.cairo(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPricingSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.orangeGradient,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.warningOrange),
                ),
                child: const Icon(Icons.payments_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'التسعير والحسابات',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStyledTextFormField(
                  controller: _yuanPriceController,
                  labelText: 'السعر باليوان *',
                  hintText: '0.00',
                  prefixIcon: Icons.currency_yuan_rounded,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'السعر مطلوب';
                    }
                    final price = double.tryParse(value);
                    if (price == null || price <= 0) {
                      return 'السعر يجب أن يكون أكبر من صفر';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStyledTextFormField(
                  controller: _exchangeRateController,
                  labelText: 'سعر الصرف *',
                  hintText: '2.45',
                  prefixIcon: Icons.currency_exchange_rounded,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,4}')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'سعر الصرف مطلوب';
                    }
                    final rate = double.tryParse(value);
                    if (rate == null || rate <= 0) {
                      return 'سعر الصرف يجب أن يكون أكبر من صفر';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'هامش الربح (%)',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              if (_isProfitMarginRemembered)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.greenGradient,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.memory_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'محفوظ',
                        style: GoogleFonts.cairo(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextButton.icon(
                  onPressed: _resetProfitMarginToZero,
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  label: Text(
                    'إعادة تعيين لـ 0%',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'اتركه عند 0% لعدم إضافة هامش ربح',
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AccountantThemeConfig.primaryGreen,
                    inactiveTrackColor: Colors.white.withOpacity(0.3),
                    thumbColor: AccountantThemeConfig.primaryGreen,
                    overlayColor: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                    valueIndicatorColor: AccountantThemeConfig.primaryGreen,
                  ),
                  child: Slider(
                    value: _profitMarginSlider.clamp(0.0, 300.0),
                    min: 0,
                    max: 300,
                    divisions: 300,
                    onChanged: (value) {
                      setState(() {
                        _profitMarginSlider = value;
                        _profitMarginController.text = value.toStringAsFixed(1);
                        // Update remembered state when user changes value
                        if (value > 0) {
                          _isProfitMarginRemembered = false; // User is actively changing
                        }
                      });
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: _buildStyledTextFormField(
                  controller: _profitMarginController,
                  labelText: '',
                  hintText: '0%',
                  prefixIcon: Icons.percent_rounded,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  suffix: Text(
                    '%',
                    style: GoogleFonts.cairo(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  onChanged: (value) {
                    final margin = double.tryParse(value);
                    if (margin != null && margin >= 0 && margin <= 300) {
                      setState(() {
                        _profitMarginSlider = margin.clamp(0.0, 300.0);
                        // Update remembered state when user changes value
                        if (margin > 0) {
                          _isProfitMarginRemembered = false; // User is actively changing
                        }
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(
      delay: const Duration(milliseconds: 400),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    ).slideY(
      begin: 0.2,
      delay: const Duration(milliseconds: 400),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildCalculationDisplay() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.greenGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calculate_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'تفصيل الحسابات',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCalculationRow('السعر الأساسي للوحدة:', AccountantThemeConfig.formatCurrency(_baseEgpPrice)),
          _buildCalculationRow(
            'مبلغ الربح للوحدة:',
            _profitMarginSlider == 0.0
                ? 'لا يوجد هامش ربح'
                : AccountantThemeConfig.formatCurrency(_profitAmount)
          ),
          _buildCalculationRow('السعر النهائي للوحدة:', AccountantThemeConfig.formatCurrency(_calculatedFinalPrice)),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.3),
                  Colors.white,
                  Colors.white.withOpacity(0.3),
                ],
              ),
            ),
          ),
          _buildCalculationRow('الكمية:', '${_quantity} قطعة'),
          _buildCalculationRow(
            'إجمالي مبلغ الربح:',
            _profitMarginSlider == 0.0
                ? 'لا يوجد هامش ربح'
                : AccountantThemeConfig.formatCurrency(_totalProfitAmount)
          ),
          _buildCalculationRow(
            'إجمالي السعر النهائي:',
            AccountantThemeConfig.formatCurrency(_totalPrice),
            isTotal: true,
          ),
          if (_profitMarginSlider == 0.0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'لم يتم تطبيق هامش ربح - السعر النهائي = السعر الأساسي',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(
      delay: const Duration(milliseconds: 600),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    ).slideY(
      begin: 0.2,
      delay: const Duration(milliseconds: 600),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildCalculationRow(String label, String value, {bool isTotal = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: isTotal ? BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
        ),
      ) : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: isTotal ? 18 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceItemsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'عناصر الفاتورة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'العدد: ${_invoiceItems.length}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  Text(
                    'إجمالي الكمية: ${_invoiceItems.fold<int>(0, (sum, item) => sum + item.quantity)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
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
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    item.productName,
                    style: const TextStyle(fontFamily: 'Cairo'),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الكمية: ${item.quantity} | السعر للوحدة: ${_egpFormat.format(item.finalEgpPrice)}',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                      ),
                      Text(
                        'إجمالي السعر: ${_egpFormat.format(item.totalPrice)}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF14B8A6),
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeItem(index),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF14B8A6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'إجمالي الفاتورة:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                Text(
                  _egpFormat.format(_invoiceItems.fold<double>(
                    0.0,
                    (sum, item) => sum + item.finalEgpPrice,
                  )),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF14B8A6),
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ملاحظات إضافية',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              hintText: 'أضف أي ملاحظات إضافية...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLines: 3,
            textDirection: ui.TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _addItemToInvoice,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14B8A6),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'إضافة للفاتورة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Cairo',
                      ),
                    ),
            ),
          ),
          if (_invoiceItems.isNotEmpty) ...[
            const SizedBox(width: 16),
            // Icon-only Create Invoice Button
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AccountantThemeConfig.primaryGreen,
                    AccountantThemeConfig.primaryGreen.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : () {
                  print('DEBUG: Create Invoice button tapped');
                  _createInvoice();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(60, 60),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        _isEditMode ? Icons.save_rounded : Icons.add_task,
                        color: Colors.white,
                        size: 28,
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      AppLogger.error('خطأ في اختيار الصورة: $e');
      _showErrorSnackBar('فشل في اختيار الصورة');
    }
  }

  void _addItemToInvoice() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_calculatedFinalPrice <= 0) {
      _showErrorSnackBar('يجب أن يكون السعر النهائي أكبر من صفر');
      return;
    }

    final item = PurchaseInvoiceItem.create(
      productName: _productNameController.text.trim(),
      productImage: _selectedImage?.path,
      yuanPrice: double.parse(_yuanPriceController.text),
      exchangeRate: double.parse(_exchangeRateController.text),
      profitMarginPercent: _profitMarginSlider,
      quantity: _quantity,
    );

    // Save current profit margin to session before clearing form
    _saveProfitMarginToSession();

    setState(() {
      _invoiceItems.add(item);
      _clearForm();
    });

    _showSuccessSnackBar('تم إضافة المنتج للفاتورة');
  }

  void _clearForm() {
    // Clear only product-specific fields, preserve profit margin and exchange rate
    _productNameController.clear();
    _yuanPriceController.clear();
    _quantityController.text = '1'; // Reset quantity to 1
    _selectedImage = null;

    // Apply last used profit margin if available, otherwise keep current value
    if (_lastUsedProfitMargin != null && _lastUsedProfitMargin != _profitMarginSlider) {
      _applyLastUsedProfitMargin();
    }

    // Exchange rate is preserved (not cleared)
  }

  void _removeItem(int index) {
    setState(() {
      _invoiceItems.removeAt(index);
    });
    _showSuccessSnackBar('تم حذف المنتج من الفاتورة');
  }

  Future<void> _createInvoice() async {
    print('DEBUG: _createInvoice() method called');
    AppLogger.info('${_isEditMode ? 'Update' : 'Create'} invoice button pressed - starting invoice ${_isEditMode ? 'update' : 'creation'}');

    if (_invoiceItems.isEmpty) {
      print('DEBUG: No invoice items found');
      AppLogger.warning('Invoice ${_isEditMode ? 'update' : 'creation'} failed - no items in invoice');
      _showErrorSnackBar('يجب إضافة منتج واحد على الأقل');
      return;
    }

    print('DEBUG: Setting loading state to true');
    setState(() {
      _isLoading = true;
    });

    try {
      if (_isEditMode && _editingInvoice != null) {
        // Update existing invoice
        print('DEBUG: Updating existing invoice with ${_invoiceItems.length} items');
        final updatedInvoice = _editingInvoice!.copyWith(
          supplierName: _supplierNameController.text.trim().isEmpty
              ? null : _supplierNameController.text.trim(),
          items: _invoiceItems,
          notes: _notesController.text.trim().isEmpty
              ? null : _notesController.text.trim(),
          updatedAt: DateTime.now(),
        );

        print('DEBUG: Calling invoice service to update purchase invoice');
        AppLogger.info('Calling PurchaseInvoiceService.updatePurchaseInvoice()');
        final result = await _invoiceService.updatePurchaseInvoice(updatedInvoice);

        print('DEBUG: Invoice service result: $result');
        if (result['success'] as bool) {
          print('DEBUG: Invoice updated successfully');
          AppLogger.info('Purchase invoice updated successfully');
          _showSuccessSnackBar('تم تحديث فاتورة المشتريات بنجاح');

          // Navigate back
          print('DEBUG: Navigating back');
          Navigator.of(context).pop();
        } else {
          print('DEBUG: Invoice update failed: ${result['message']}');
          AppLogger.error('Invoice update failed: ${result['message']}');
          _showErrorSnackBar((result['message'] as String?) ?? 'فشل في تحديث الفاتورة');
        }
      } else {
        // Create new invoice
        print('DEBUG: Creating invoice object with ${_invoiceItems.length} items');
        final invoice = PurchaseInvoice.create(
          supplierName: _supplierNameController.text.trim().isEmpty
              ? null : _supplierNameController.text.trim(),
          items: _invoiceItems,
          notes: _notesController.text.trim().isEmpty
              ? null : _notesController.text.trim(),
        );

        print('DEBUG: Calling invoice service to create purchase invoice');
        AppLogger.info('Calling PurchaseInvoiceService.createPurchaseInvoice()');
        final result = await _invoiceService.createPurchaseInvoice(invoice);

        print('DEBUG: Invoice service result: $result');
        if (result['success'] as bool) {
          print('DEBUG: Invoice created successfully');
          AppLogger.info('Purchase invoice created successfully');
          _showSuccessSnackBar('تم إنشاء فاتورة المشتريات بنجاح');

          // Generate PDF
          print('DEBUG: Generating PDF');
          await _generatePdf(invoice);

          // Show WhatsApp sharing dialog
          print('DEBUG: Showing WhatsApp sharing dialog');
          await _showWhatsAppSharingDialog(invoice);

          // Navigate back
          print('DEBUG: Navigating back');
          Navigator.of(context).pop();
        } else {
          print('DEBUG: Invoice creation failed: ${result['message']}');
          AppLogger.error('Invoice creation failed: ${result['message']}');
          _showErrorSnackBar((result['message'] as String?) ?? 'فشل في إنشاء الفاتورة');
        }
      }
    } catch (e) {
      print('DEBUG: Exception in _createInvoice: $e');
      AppLogger.error('خطأ في ${_isEditMode ? 'تحديث' : 'إنشاء'} فاتورة المشتريات: $e');
      _showErrorSnackBar('حدث خطأ غير متوقع: ${e.toString()}');
    } finally {
      print('DEBUG: Setting loading state to false');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generatePdf(PurchaseInvoice invoice) async {
    try {
      final pdfBytes = await _pdfService.generatePurchaseInvoicePdf(invoice);
      final fileName = 'purchase_invoice_${invoice.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = await _pdfService.savePdfToDevice(pdfBytes, fileName);

      if (filePath != null) {
        _showSuccessSnackBar('تم حفظ PDF في: $filePath');
      }
    } catch (e) {
      AppLogger.error('خطأ في إنشاء PDF: $e');
      _showErrorSnackBar('فشل في إنشاء PDF');
    }
  }

  /// Show WhatsApp sharing dialog after successful invoice creation
  Future<void> _showWhatsAppSharingDialog(PurchaseInvoice invoice) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: AccountantThemeConfig.primaryCardDecoration,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with WhatsApp icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.greenGradient,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                  ),
                  child: const Icon(
                    Icons.share_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),

                const SizedBox(height: 20),

                // Title
                Text(
                  'مشاركة الفاتورة',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Subtitle
                Text(
                  'هل تريد مشاركة تفاصيل الفاتورة مع المورد عبر واتساب؟',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Invoice preview
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildPreviewRow('رقم الفاتورة:', '#${invoice.id.split('-').last}'),
                      if (invoice.supplierName != null && invoice.supplierName!.isNotEmpty)
                        _buildPreviewRow('المورد:', invoice.supplierName!),
                      _buildPreviewRow('المبلغ الإجمالي:', AccountantThemeConfig.formatCurrency(invoice.totalAmount)),
                      _buildPreviewRow('التاريخ:', DateFormat('dd/MM/yyyy', 'ar').format(invoice.createdAt)),
                      _buildPreviewRow('عدد المنتجات:', '${invoice.itemsCount} منتج'),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildDialogButton(
                        'تخطي',
                        Icons.close_rounded,
                        Colors.grey,
                        () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDialogButton(
                        'مشاركة',
                        Icons.send_rounded,
                        AccountantThemeConfig.primaryGreen,
                        () {
                          Navigator.of(context).pop();
                          _shareViaWhatsApp(invoice);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build preview row for invoice details
  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Build dialog action button
  Widget _buildDialogButton(String text, IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: AccountantThemeConfig.glowShadows(color),
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 18),
        label: Text(
          text,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  /// Share invoice details via WhatsApp
  Future<void> _shareViaWhatsApp(PurchaseInvoice invoice) async {
    try {
      final message = _buildWhatsAppMessage(invoice);
      final encodedMessage = Uri.encodeComponent(message);
      final whatsappUrl = 'https://wa.me/?text=$encodedMessage';

      final uri = Uri.parse(whatsappUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _showSuccessSnackBar('تم فتح واتساب بنجاح');
      } else {
        _showErrorSnackBar('لا يمكن فتح واتساب. تأكد من تثبيت التطبيق');
      }
    } catch (e) {
      AppLogger.error('خطأ في مشاركة الفاتورة عبر واتساب: $e');
      _showErrorSnackBar('حدث خطأ أثناء مشاركة الفاتورة');
    }
  }

  /// Build WhatsApp message content
  String _buildWhatsAppMessage(PurchaseInvoice invoice) {
    final dateFormat = DateFormat('dd/MM/yyyy', 'ar');
    final supplierText = invoice.supplierName != null && invoice.supplierName!.isNotEmpty
        ? 'المورد: ${invoice.supplierName}\n'
        : '';

    return '''
🧾 *فاتورة مشتريات جديدة - شركة سما*

📋 رقم الفاتورة: #${invoice.id.split('-').last}
${supplierText}💰 المبلغ الإجمالي: ${AccountantThemeConfig.formatCurrency(invoice.totalAmount)}
📅 تاريخ الإنشاء: ${dateFormat.format(invoice.createdAt)}
📦 عدد المنتجات: ${invoice.itemsCount} منتج

---
تم إنشاء هذه الفاتورة من خلال نظام سما لإدارة الأعمال

شكراً لتعاونكم معنا 🙏
''';
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

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
