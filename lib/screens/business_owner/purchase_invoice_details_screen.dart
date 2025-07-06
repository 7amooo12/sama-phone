import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:ui' as ui;

import '../../models/purchase_invoice_models.dart';
import '../../services/purchase_invoice_service.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';
import '../../widgets/common/custom_app_bar.dart';

/// Purchase Invoice Details Screen
/// Displays comprehensive details of a purchase invoice with professional UI/UX
class PurchaseInvoiceDetailsScreen extends StatefulWidget {
  final String invoiceId;

  const PurchaseInvoiceDetailsScreen({
    super.key,
    required this.invoiceId,
  });

  @override
  State<PurchaseInvoiceDetailsScreen> createState() => _PurchaseInvoiceDetailsScreenState();
}

class _PurchaseInvoiceDetailsScreenState extends State<PurchaseInvoiceDetailsScreen> {
  final PurchaseInvoiceService _invoiceService = PurchaseInvoiceService();

  PurchaseInvoice? _invoice;
  bool _isLoading = true;
  String? _errorMessage;

  // Expansion states for sections
  bool _isCurrencyConversionExpanded = false;
  bool _isProductsExpanded = true;

  // Individual product expansion states
  Map<String, bool> _productExpansionStates = {};

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<PurchaseInvoiceItem> _filteredItems = [];
  Timer? _debounceTimer;

  // Clean formatters
  final NumberFormat _numberFormat = NumberFormat('#,##0.00', 'en_US');
  final NumberFormat _yuanFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: '¥',
    decimalDigits: 2,
  );
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy - hh:mm a', 'ar');

  /// Format EGP currency with clean display
  String _formatEgp(double amount) {
    return '${_numberFormat.format(amount)} جنيه';
  }

  @override
  void initState() {
    super.initState();
    _loadInvoiceDetails();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
        _filterItems();
      });
    });
  }

  void _filterItems() {
    if (_invoice == null) return;

    if (_searchQuery.isEmpty) {
      _filteredItems = _invoice!.items;
    } else {
      _filteredItems = _invoice!.items.where((item) {
        return item.productName.toLowerCase().contains(_searchQuery) ||
               item.id.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  Future<void> _loadInvoiceDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      AppLogger.info('Loading purchase invoice details: ${widget.invoiceId}');
      final invoice = await _invoiceService.getPurchaseInvoice(widget.invoiceId);
      
      if (invoice != null) {
        setState(() {
          _invoice = invoice;
          _filteredItems = invoice.items;
          _isLoading = false;
        });
        AppLogger.info('Successfully loaded invoice details');
      } else {
        setState(() {
          _errorMessage = 'لم يتم العثور على الفاتورة';
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('Error loading invoice details: $e');
      setState(() {
        _errorMessage = 'حدث خطأ في تحميل تفاصيل الفاتورة';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        title: 'تفاصيل فاتورة المشتريات',
        showNotificationIcon: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: SafeArea(
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }
    
    if (_errorMessage != null) {
      return _buildErrorState();
    }
    
    if (_invoice == null) {
      return _buildNotFoundState();
    }
    
    return _buildInvoiceDetails();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.cardBackground1.withOpacity(0.9),
              borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
              boxShadow: AccountantThemeConfig.cardShadows,
            ),
            child: Column(
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AccountantThemeConfig.primaryGreen),
                ),
                const SizedBox(height: 16),
                Text(
                  'جاري تحميل تفاصيل الفاتورة...',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.8, 0.8)),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AccountantThemeConfig.cardBackground1.withOpacity(0.9),
          borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
          boxShadow: AccountantThemeConfig.cardShadows,
          border: Border.all(
            color: AccountantThemeConfig.dangerRed.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: AccountantThemeConfig.dangerRed,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadInvoiceDetails,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'إعادة المحاولة',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
              ),
              style: AccountantThemeConfig.primaryButtonStyle,
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.3),
    );
  }

  Widget _buildNotFoundState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AccountantThemeConfig.cardBackground1.withOpacity(0.9),
          borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
          boxShadow: AccountantThemeConfig.cardShadows,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 64,
              color: AccountantThemeConfig.neutralColor,
            ),
            const SizedBox(height: 16),
            Text(
              'لم يتم العثور على الفاتورة',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'قد تكون الفاتورة محذوفة أو غير متاحة',
              style: GoogleFonts.cairo(
                color: AccountantThemeConfig.neutralColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text(
                'العودة',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
              ),
              style: AccountantThemeConfig.secondaryButtonStyle,
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.3),
    );
  }

  Widget _buildInvoiceDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInvoiceHeader(),
          const SizedBox(height: 20),
          _buildCurrencyConversionSection(),
          const SizedBox(height: 20),
          _buildProductItemsList(),
          const SizedBox(height: 20),
          _buildTotalsSection(),
          if (_invoice!.notes != null && _invoice!.notes!.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildNotesSection(),
          ],
          const SizedBox(height: 100), // Extra space for floating action button
        ],
      ),
    );
  }

  // Invoice header section with professional styling
  Widget _buildInvoiceHeader() {
    return Container(
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        children: [
          // Header with gradient background
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.greenGradient,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AccountantThemeConfig.largeBorderRadius),
                topRight: Radius.circular(AccountantThemeConfig.largeBorderRadius),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'فاتورة مشتريات',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '#${_invoice!.id.split('-').last}',
                        style: GoogleFonts.cairo(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(_invoice!.status),
              ],
            ),
          ),

          // Invoice details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildInfoRow(
                  'رقم الفاتورة',
                  _invoice!.id,
                  Icons.tag_rounded,
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  'تاريخ الإنشاء',
                  _dateFormat.format(_invoice!.createdAt),
                  Icons.calendar_today_rounded,
                ),
                if (_invoice!.supplierName != null) ...[
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    'اسم المورد',
                    _invoice!.supplierName!,
                    Icons.business_rounded,
                  ),
                ],
                const SizedBox(height: 16),
                _buildInfoRow(
                  'عدد المنتجات',
                  '${_invoice!.items.length} منتج',
                  Icons.inventory_2_rounded,
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  'إجمالي الكمية',
                  '${_invoice!.items.fold<int>(0, (sum, item) => sum + item.quantity)} قطعة',
                  Icons.shopping_cart_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.3);
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    String statusText;
    IconData statusIcon;

    switch (status.toLowerCase()) {
      case 'completed':
        backgroundColor = AccountantThemeConfig.completedColor;
        textColor = Colors.white;
        statusText = 'مكتملة';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'pending':
        backgroundColor = AccountantThemeConfig.pendingColor;
        textColor = Colors.white;
        statusText = 'قيد الانتظار';
        statusIcon = Icons.schedule_rounded;
        break;
      case 'cancelled':
        backgroundColor = AccountantThemeConfig.canceledColor;
        textColor = Colors.white;
        statusText = 'ملغية';
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        backgroundColor = AccountantThemeConfig.neutralColor;
        textColor = Colors.white;
        statusText = status;
        statusIcon = Icons.info_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AccountantThemeConfig.glowShadows(backgroundColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            color: textColor,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: GoogleFonts.cairo(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AccountantThemeConfig.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AccountantThemeConfig.primaryGreen,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: AccountantThemeConfig.neutralColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencyConversionSection() {
    // Calculate average exchange rate from all items
    final totalExchangeRateSum = _invoice!.items.fold<double>(
      0.0,
      (sum, item) => sum + (item.exchangeRate * item.quantity)
    );
    final totalQuantity = _invoice!.items.fold<int>(0, (sum, item) => sum + item.quantity);
    final averageExchangeRate = totalQuantity > 0 ? totalExchangeRateSum / totalQuantity : 0.0;

    // Calculate totals
    final totalYuanAmount = _invoice!.items.fold<double>(
      0.0,
      (sum, item) => sum + (item.yuanPrice * item.quantity)
    );
    final totalEgpAmount = _invoice!.totalAmount;

    return Container(
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        children: [
          // Expandable Header
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _isCurrencyConversionExpanded = !_isCurrencyConversionExpanded;
                });
              },
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AccountantThemeConfig.largeBorderRadius),
                topRight: Radius.circular(AccountantThemeConfig.largeBorderRadius),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.blueGradient,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(AccountantThemeConfig.largeBorderRadius),
                    topRight: const Radius.circular(AccountantThemeConfig.largeBorderRadius),
                    bottomLeft: _isCurrencyConversionExpanded ? Radius.zero : const Radius.circular(AccountantThemeConfig.largeBorderRadius),
                    bottomRight: _isCurrencyConversionExpanded ? Radius.zero : const Radius.circular(AccountantThemeConfig.largeBorderRadius),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.currency_exchange_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'تفاصيل تحويل العملة',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isCurrencyConversionExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Expandable Conversion details
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _isCurrencyConversionExpanded ? null : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _isCurrencyConversionExpanded ? 1.0 : 0.0,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Exchange rate info
                    _buildConversionRow(
                      'متوسط سعر الصرف',
                      '${averageExchangeRate.toStringAsFixed(4)} جنيه لكل يوان',
                      Icons.trending_up_rounded,
                      AccountantThemeConfig.primaryGreen,
                    ),
                    const SizedBox(height: 16),

                    // Yuan total
                    _buildConversionRow(
                      'إجمالي المبلغ باليوان',
                      _yuanFormat.format(totalYuanAmount),
                      Icons.attach_money_rounded,
                      AccountantThemeConfig.warningOrange,
                    ),
                    const SizedBox(height: 16),

                    // EGP total
                    _buildConversionRow(
                      'إجمالي المبلغ بالجنيه المصري',
                      _formatEgp(totalEgpAmount),
                      Icons.payments_rounded,
                      AccountantThemeConfig.accentBlue,
                    ),
                    const SizedBox(height: 20),

                    // Conversion formula
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AccountantThemeConfig.cardBackground2.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calculate_rounded,
                                color: AccountantThemeConfig.primaryGreen,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'معادلة التحويل',
                                style: GoogleFonts.cairo(
                                  color: AccountantThemeConfig.primaryGreen,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'السعر النهائي = (سعر اليوان × سعر الصرف × (1 + هامش الربح%)) × الكمية',
                            style: GoogleFonts.cairo(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 800), delay: const Duration(milliseconds: 200)).slideX(begin: 0.3);
  }

  Widget _buildConversionRow(String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardBackground1.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: iconColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    color: AccountantThemeConfig.neutralColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItemsList() {
    return Container(
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        children: [
          // Expandable Header
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _isProductsExpanded = !_isProductsExpanded;
                });
              },
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AccountantThemeConfig.largeBorderRadius),
                topRight: Radius.circular(AccountantThemeConfig.largeBorderRadius),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.orangeGradient,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(AccountantThemeConfig.largeBorderRadius),
                    topRight: const Radius.circular(AccountantThemeConfig.largeBorderRadius),
                    bottomLeft: _isProductsExpanded ? Radius.zero : const Radius.circular(AccountantThemeConfig.largeBorderRadius),
                    bottomRight: _isProductsExpanded ? Radius.zero : const Radius.circular(AccountantThemeConfig.largeBorderRadius),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.inventory_2_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'منتجات الفاتورة (${_invoice!.items.length})',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_invoice!.items.fold<int>(0, (sum, item) => sum + item.quantity)} قطعة',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _isProductsExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Expandable Products list with search
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _isProductsExpanded ? null : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _isProductsExpanded ? 1.0 : 0.0,
              child: Column(
                children: [
                  // Search bar for products
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AccountantThemeConfig.cardBackground1.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'البحث في منتجات الفاتورة...',
                        hintStyle: GoogleFonts.cairo(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: AccountantThemeConfig.primaryGreen,
                          size: 20,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _filterItems();
                                  });
                                },
                                icon: Icon(
                                  Icons.clear_rounded,
                                  color: AccountantThemeConfig.neutralColor,
                                  size: 18,
                                ),
                              )
                            : null,
                        filled: false,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      textDirection: ui.TextDirection.rtl,
                    ),
                  ),

                  // Search results info
                  if (_searchQuery.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: AccountantThemeConfig.primaryGreen,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'تم العثور على ${_filteredItems.length} من ${_invoice!.items.length} منتج',
                            style: GoogleFonts.cairo(
                              color: AccountantThemeConfig.primaryGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Products list
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _filteredItems.isEmpty && _searchQuery.isNotEmpty
                        ? _buildNoResultsFound()
                        : Column(
                            children: _filteredItems.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;
                              return _buildEnhancedProductItem(item, index);
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 1000), delay: const Duration(milliseconds: 400)).slideY(begin: 0.3);
  }

  /// Build no results found widget
  Widget _buildNoResultsFound() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.neutralColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.search_off_rounded,
              color: AccountantThemeConfig.neutralColor,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد نتائج',
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'لم يتم العثور على منتجات تطابق البحث "$_searchQuery"',
            style: GoogleFonts.cairo(
              color: AccountantThemeConfig.neutralColor,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Enhanced product item with progressive disclosure
  Widget _buildEnhancedProductItem(PurchaseInvoiceItem item, int index) {
    final isExpanded = _productExpansionStates[item.id] ?? false;

    return Container(
      margin: EdgeInsets.only(bottom: index < _filteredItems.length - 1 ? 16 : 0),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardBackground1.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            setState(() {
              _productExpansionStates[item.id] = !isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Collapsed view: Image, Name, Quantity, Total with Profit
                Row(
                  children: [
                    // Product image
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AccountantThemeConfig.cardBackground2.withOpacity(0.5),
                      ),
                      child: item.productImage != null && item.productImage!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: item.productImage!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  decoration: BoxDecoration(
                                    color: AccountantThemeConfig.cardBackground2.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.image_rounded,
                                    color: AccountantThemeConfig.neutralColor,
                                    size: 24,
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  decoration: BoxDecoration(
                                    color: AccountantThemeConfig.cardBackground2.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.broken_image_rounded,
                                    color: AccountantThemeConfig.neutralColor,
                                    size: 24,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: AccountantThemeConfig.cardBackground2.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.inventory_2_rounded,
                                color: AccountantThemeConfig.neutralColor,
                                size: 24,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),

                    // Product name and quantity
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'الكمية: ${item.quantity}',
                              style: GoogleFonts.cairo(
                                color: AccountantThemeConfig.primaryGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Total with Profit and expansion indicator
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: AccountantThemeConfig.greenGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'الإجمالي مع الربح',
                                style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _formatEgp(item.totalPrice),
                                style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AccountantThemeConfig.primaryGreen,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Expandable detailed pricing information
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: isExpanded ? null : 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: isExpanded ? 1.0 : 0.0,
                    child: isExpanded ? Column(
                      children: [
                        const SizedBox(height: 16),
                        _buildDetailedPricingGrid(item),
                      ],
                    ) : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate(delay: Duration(milliseconds: 100 * index))
        .fadeIn(duration: const Duration(milliseconds: 600))
        .slideX(begin: 0.3);
  }

  Widget _buildProductItem(PurchaseInvoiceItem item, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: index < _invoice!.items.length - 1 ? 16 : 0),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardBackground1.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product header with image and name
            Row(
              children: [
                // Product image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AccountantThemeConfig.cardBackground2.withOpacity(0.5),
                  ),
                  child: item.productImage != null && item.productImage!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: item.productImage!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              decoration: BoxDecoration(
                                color: AccountantThemeConfig.cardBackground2.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.image_rounded,
                                color: AccountantThemeConfig.neutralColor,
                                size: 24,
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              decoration: BoxDecoration(
                                color: AccountantThemeConfig.cardBackground2.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.broken_image_rounded,
                                color: AccountantThemeConfig.neutralColor,
                                size: 24,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: AccountantThemeConfig.cardBackground2.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.inventory_2_rounded,
                            color: AccountantThemeConfig.neutralColor,
                            size: 24,
                          ),
                        ),
                ),
                const SizedBox(width: 12),

                // Product name and quantity
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'الكمية: ${item.quantity}',
                              style: GoogleFonts.cairo(
                                color: AccountantThemeConfig.primaryGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AccountantThemeConfig.warningOrange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'ربح: ${item.profitMarginPercent.toStringAsFixed(1)}%',
                              style: GoogleFonts.cairo(
                                color: AccountantThemeConfig.warningOrange,
                                fontSize: 12,
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

            // Pricing details
            _buildPricingGrid(item),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: 100 * index))
        .fadeIn(duration: 600.ms)
        .slideX(begin: 0.3);
  }

  /// Detailed pricing grid for expanded product view
  Widget _buildDetailedPricingGrid(PurchaseInvoiceItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardBackground2.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.accentBlue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Row(
            children: [
              Icon(
                Icons.analytics_rounded,
                color: AccountantThemeConfig.accentBlue,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'تفاصيل التسعير',
                style: GoogleFonts.cairo(
                  color: AccountantThemeConfig.accentBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Pricing breakdown
          Column(
            children: [
              // Yuan price and exchange rate row
              Row(
                children: [
                  Expanded(
                    child: _buildDetailedPriceCard(
                      'سعر الوحدة (يوان)',
                      _yuanFormat.format(item.yuanPrice),
                      Icons.attach_money_rounded,
                      AccountantThemeConfig.warningOrange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDetailedPriceCard(
                      'سعر الصرف',
                      '${item.exchangeRate.toStringAsFixed(4)}',
                      Icons.currency_exchange_rounded,
                      AccountantThemeConfig.accentBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Profit margin and unit price row
              Row(
                children: [
                  Expanded(
                    child: _buildDetailedPriceCard(
                      'هامش الربح',
                      '${item.profitMarginPercent.toStringAsFixed(1)}%',
                      Icons.trending_up_rounded,
                      AccountantThemeConfig.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDetailedPriceCard(
                      'السعر النهائي (وحدة)',
                      _formatEgp(item.unitPrice),
                      Icons.payments_rounded,
                      AccountantThemeConfig.successGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedPriceCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 16,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.cairo(
              color: AccountantThemeConfig.neutralColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.cairo(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPricingGrid(PurchaseInvoiceItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardBackground2.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.accentBlue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Unit prices row
          Row(
            children: [
              Expanded(
                child: _buildPriceCard(
                  'سعر الوحدة (يوان)',
                  _yuanFormat.format(item.yuanPrice),
                  Icons.attach_money_rounded,
                  AccountantThemeConfig.warningOrange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPriceCard(
                  'سعر الصرف',
                  '${item.exchangeRate.toStringAsFixed(4)}',
                  Icons.currency_exchange_rounded,
                  AccountantThemeConfig.accentBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Final prices row
          Row(
            children: [
              Expanded(
                child: _buildPriceCard(
                  'السعر النهائي (وحدة)',
                  _formatEgp(item.unitPrice),
                  Icons.payments_rounded,
                  AccountantThemeConfig.primaryGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPriceCard(
                  'الإجمالي',
                  _formatEgp(item.totalPrice),
                  Icons.calculate_rounded,
                  AccountantThemeConfig.successGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 16,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.cairo(
              color: AccountantThemeConfig.neutralColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.cairo(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsSection() {
    // Calculate totals
    final totalYuanAmount = _invoice!.items.fold<double>(
      0.0,
      (sum, item) => sum + (item.yuanPrice * item.quantity)
    );
    final totalBaseEgpAmount = _invoice!.items.fold<double>(
      0.0,
      (sum, item) => sum + item.totalBaseEgpPrice
    );
    final totalProfitAmount = _invoice!.items.fold<double>(
      0.0,
      (sum, item) => sum + item.totalProfitAmount
    );
    final totalFinalAmount = _invoice!.totalAmount;

    return Container(
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AccountantThemeConfig.successGreen,
                  AccountantThemeConfig.primaryGreen,
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AccountantThemeConfig.largeBorderRadius),
                topRight: Radius.circular(AccountantThemeConfig.largeBorderRadius),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calculate_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'ملخص الفاتورة',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Totals content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Yuan totals
                _buildTotalRow(
                  'إجمالي المبلغ باليوان',
                  _yuanFormat.format(totalYuanAmount),
                  Icons.attach_money_rounded,
                  AccountantThemeConfig.warningOrange,
                  isSubtotal: true,
                ),
                const SizedBox(height: 12),

                // Base EGP amount (before profit)
                _buildTotalRow(
                  'المبلغ الأساسي (بعد التحويل)',
                  _formatEgp(totalBaseEgpAmount),
                  Icons.currency_exchange_rounded,
                  AccountantThemeConfig.accentBlue,
                  isSubtotal: true,
                ),
                const SizedBox(height: 12),

                // Profit amount
                _buildTotalRow(
                  'إجمالي هامش الربح',
                  _formatEgp(totalProfitAmount),
                  Icons.trending_up_rounded,
                  AccountantThemeConfig.primaryGreen,
                  isSubtotal: true,
                ),

                const SizedBox(height: 16),

                // Divider
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AccountantThemeConfig.primaryGreen.withOpacity(0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Final total
                _buildTotalRow(
                  'المبلغ الإجمالي النهائي',
                  _formatEgp(totalFinalAmount),
                  Icons.payments_rounded,
                  AccountantThemeConfig.successGreen,
                  isTotal: true,
                ),

                const SizedBox(height: 16),

                // Profit percentage
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                        AccountantThemeConfig.successGreen.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.percent_rounded,
                        color: AccountantThemeConfig.primaryGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'نسبة الربح الإجمالية: ${totalBaseEgpAmount > 0 ? ((totalProfitAmount / totalBaseEgpAmount) * 100).toStringAsFixed(1) : '0.0'}%',
                        style: GoogleFonts.cairo(
                          color: AccountantThemeConfig.primaryGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 1200), delay: const Duration(milliseconds: 600)).slideY(begin: 0.3);
  }

  Widget _buildTotalRow(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isSubtotal = false,
    bool isTotal = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isTotal ? 16 : 12),
      decoration: BoxDecoration(
        color: isTotal
            ? color.withOpacity(0.15)
            : AccountantThemeConfig.cardBackground1.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(isTotal ? 0.5 : 0.2),
          width: isTotal ? 2 : 1,
        ),
        boxShadow: isTotal ? AccountantThemeConfig.glowShadows(color) : null,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isTotal ? 10 : 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(isTotal ? 10 : 8),
            ),
            child: Icon(
              icon,
              color: color,
              size: isTotal ? 24 : 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.cairo(
                color: isTotal ? Colors.white : AccountantThemeConfig.neutralColor,
                fontSize: isTotal ? 16 : 14,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.cairo(
              color: color,
              fontSize: isTotal ? 18 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AccountantThemeConfig.neutralColor,
                  AccountantThemeConfig.neutralColor.withOpacity(0.8),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AccountantThemeConfig.largeBorderRadius),
                topRight: Radius.circular(AccountantThemeConfig.largeBorderRadius),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.note_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'ملاحظات الفاتورة',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Notes content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AccountantThemeConfig.cardBackground1.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AccountantThemeConfig.neutralColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Text(
                _invoice!.notes!,
                style: GoogleFonts.cairo(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 1400.ms, delay: 800.ms).slideY(begin: 0.3);
  }
}
