import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/models/purchase_invoice_models.dart';
import 'package:smartbiztracker_new/services/purchase_invoice_service.dart';
import 'package:smartbiztracker_new/services/purchase_invoice_pdf_service.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/screens/business_owner/purchase_invoice_details_screen.dart';
import 'package:smartbiztracker_new/screens/business_owner/excel_import_screen.dart';
import 'package:smartbiztracker_new/widgets/purchase_invoices/flippable_invoice_card.dart';
import 'package:smartbiztracker_new/utils/formatters.dart';


class PurchaseInvoicesScreen extends StatefulWidget {
  const PurchaseInvoicesScreen({super.key});

  @override
  State<PurchaseInvoicesScreen> createState() => _PurchaseInvoicesScreenState();
}

/// Data structure for individual product search results
class ProductSearchResult {
  final PurchaseInvoiceItem item;
  final PurchaseInvoice invoice;

  const ProductSearchResult({
    required this.item,
    required this.invoice,
  });
}

class _PurchaseInvoicesScreenState extends State<PurchaseInvoicesScreen> {
  final PurchaseInvoiceService _invoiceService = PurchaseInvoiceService();
  final PurchaseInvoicePdfService _pdfService = PurchaseInvoicePdfService();
  final TextEditingController _searchController = TextEditingController();

  List<PurchaseInvoice> _allInvoices = [];
  List<PurchaseInvoice> _filteredInvoices = [];
  List<ProductSearchResult> _productSearchResults = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedStatus = 'all';
  String _sortBy = 'created_at';
  bool _sortDesc = true;
  bool _isProductSearchMode = false;

  // Enhanced FAB system state
  bool _isFabExpanded = false;
  bool _showBackdrop = false;

  // Scroll controller for stats cards hiding
  final ScrollController _scrollController = ScrollController();
  bool _showStatsCards = true;



  @override
  void initState() {
    super.initState();
    _loadInvoices();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // Hide stats cards when scrolling down, show when scrolling up or at top
    final shouldShowStats = _scrollController.offset <= 50;
    if (shouldShowStats != _showStatsCards) {
      setState(() {
        _showStatsCards = shouldShowStats;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _applyFilters();
    });
  }

  void _applyFilters() {
    if (_searchQuery.isNotEmpty && _searchQuery.trim().length >= 2) {
      // Product search mode - search for individual products
      _isProductSearchMode = true;
      _searchProducts();
    } else {
      // Invoice search mode - search for invoices
      _isProductSearchMode = false;
      _productSearchResults.clear();

      _filteredInvoices = _allInvoices.where((invoice) {
        // Search filter
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final matchesId = invoice.id.toLowerCase().contains(query);
          final matchesSupplier = invoice.supplierName?.toLowerCase().contains(query) ?? false;
          final matchesProduct = invoice.items.any((item) =>
              item.productName.toLowerCase().contains(query));

          if (!matchesId && !matchesSupplier && !matchesProduct) {
            return false;
          }
        }

        // Status filter
        if (_selectedStatus != 'all' && invoice.status != _selectedStatus) {
          return false;
        }

        return true;
      }).toList();

      // Apply sorting
      _filteredInvoices.sort((a, b) {
        int comparison = 0;
        switch (_sortBy) {
          case 'created_at':
            comparison = a.createdAt.compareTo(b.createdAt);
            break;
          case 'total_amount':
            comparison = a.totalAmount.compareTo(b.totalAmount);
            break;
          case 'supplier_name':
            comparison = (a.supplierName ?? '').compareTo(b.supplierName ?? '');
            break;
          default:
            comparison = a.createdAt.compareTo(b.createdAt);
        }
        return _sortDesc ? -comparison : comparison;
      });
    }
  }

  void _searchProducts() {
    final query = _searchQuery.toLowerCase().trim();
    _productSearchResults.clear();

    for (final invoice in _allInvoices) {
      // Apply status filter to invoices
      if (_selectedStatus != 'all' && invoice.status != _selectedStatus) {
        continue;
      }

      for (final item in invoice.items) {
        if (item.productName.toLowerCase().contains(query)) {
          _productSearchResults.add(ProductSearchResult(
            item: item,
            invoice: invoice,
          ));
        }
      }
    }

    // Sort product results by relevance and date
    _productSearchResults.sort((a, b) {
      // First sort by how well the product name matches
      final aRelevance = _calculateRelevance(a.item.productName, query);
      final bRelevance = _calculateRelevance(b.item.productName, query);

      if (aRelevance != bRelevance) {
        return bRelevance.compareTo(aRelevance);
      }

      // Then sort by invoice date (newest first)
      return b.invoice.createdAt.compareTo(a.invoice.createdAt);
    });
  }

  int _calculateRelevance(String productName, String query) {
    final name = productName.toLowerCase();
    if (name == query) return 100;
    if (name.startsWith(query)) return 80;
    if (name.contains(' $query')) return 60;
    if (name.contains(query)) return 40;
    return 0;
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final invoices = await _invoiceService.getPurchaseInvoices(
        sortBy: _sortBy,
        desc: _sortDesc,
      );

      setState(() {
        _allInvoices = invoices;
        _applyFilters();
        _isLoading = false;
      });

      AppLogger.info('✅ تم تحميل ${invoices.length} فاتورة مشتريات');
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل فواتير المشتريات: $e');
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('فشل في تحميل فواتير المشتريات');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'فواتير المشتريات',
        showNotificationIcon: false,
      ),
      body: Stack(
        children: [
          // Main content
          Container(
            decoration: const BoxDecoration(
              gradient: AccountantThemeConfig.mainBackgroundGradient,
            ),
            child: Column(
              children: [
                _buildSearchAndFilters(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: _showStatsCards ? null : 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _showStatsCards ? 1.0 : 0.0,
                    child: _showStatsCards ? _buildCompactStatsCards() : const SizedBox.shrink(),
                  ),
                ),
                Expanded(child: _isProductSearchMode ? _buildProductSearchResults() : _buildInvoicesList()),
              ],
            ),
          ),

          // Backdrop overlay when FAB is expanded
          if (_showBackdrop)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  print('DEBUG: Full-screen backdrop tapped');
                  _collapseFab();
                },
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildEnhancedFab(),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        children: [
          // Search bar with professional styling
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'البحث في المنتجات والفواتير...',
                hintStyle: GoogleFonts.cairo(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AccountantThemeConfig.primaryGreen,
                ),
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 14,
              ),
              textDirection: ui.TextDirection.rtl,
            ),
          ),
          const SizedBox(height: 16),
          // Compact filters layout - optimized for better space usage
          Row(
            children: [
              // Status filter - more compact
              Expanded(
                flex: 2,
                child: _buildCompactFilterDropdown(
                  'الحالة',
                  _selectedStatus,
                  {
                    'all': 'الكل',
                    'pending': 'قيد الانتظار',
                    'completed': 'مكتملة',
                    'cancelled': 'ملغية',
                  },
                  (value) {
                    setState(() {
                      _selectedStatus = value!;
                      _applyFilters();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Sort direction button - compact
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.greenGradient,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                ),
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _sortDesc = !_sortDesc;
                      _applyFilters();
                    });
                  },
                  icon: Icon(
                    _sortDesc ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  tooltip: _sortDesc ? 'ترتيب تنازلي' : 'ترتيب تصاعدي',
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 8),
              // Sort by filter - compact
              Expanded(
                flex: 2,
                child: _buildCompactFilterDropdown(
                  'ترتيب حسب',
                  _sortBy,
                  {
                    'created_at': 'التاريخ',
                    'total_amount': 'المبلغ',
                    'supplier_name': 'المورد',
                  },
                  (value) {
                    setState(() {
                      _sortBy = value!;
                      _applyFilters();
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    ).slideY(
      begin: -0.2,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  /// Compact filter dropdown for optimized space usage
  Widget _buildCompactFilterDropdown(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          onChanged: onChanged,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white.withOpacity(0.7),
            size: 18,
          ),
          dropdownColor: AccountantThemeConfig.cardBackground1,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          items: options.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(
                entry.value,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textDirection: ui.TextDirection.rtl,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(
            label,
            style: GoogleFonts.cairo(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
          dropdownColor: AccountantThemeConfig.cardBackground1,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 13,
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white.withOpacity(0.7),
          ),
          items: options.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(
                entry.value,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildCompactStatsCards() {
    final totalInvoices = _allInvoices.length;
    final totalAmount = _allInvoices.fold<double>(
      0.0,
      (sum, invoice) => sum + invoice.totalAmount,
    );
    final pendingCount = _allInvoices.where((i) => i.status == 'pending').length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 500;

          if (isMobile) {
            // Mobile: Stack cards vertically in pairs
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactStatCard(
                        'إجمالي الفواتير',
                        totalInvoices.toString(),
                        Icons.receipt_long_rounded,
                        AccountantThemeConfig.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCompactStatCard(
                        'قيد الانتظار',
                        pendingCount.toString(),
                        Icons.pending_actions_rounded,
                        AccountantThemeConfig.warningOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildCompactStatCard(
                  'إجمالي المبلغ',
                  AccountantThemeConfig.formatCurrency(totalAmount),
                  Icons.payments_rounded,
                  AccountantThemeConfig.accentBlue,
                ),
              ],
            );
          } else {
            // Desktop/Tablet: Keep original row layout
            return Row(
              children: [
                Expanded(
                  child: _buildCompactStatCard(
                    'إجمالي الفواتير',
                    totalInvoices.toString(),
                    Icons.receipt_long_rounded,
                    AccountantThemeConfig.primaryGreen,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactStatCard(
                    'إجمالي المبلغ',
                    AccountantThemeConfig.formatCurrency(totalAmount),
                    Icons.payments_rounded,
                    AccountantThemeConfig.accentBlue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactStatCard(
                    'قيد الانتظار',
                    pendingCount.toString(),
                    Icons.pending_actions_rounded,
                    AccountantThemeConfig.warningOrange,
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildCompactStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
        boxShadow: AccountantThemeConfig.glowShadows(color),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildInvoicesList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF14B8A6),
        ),
      );
    }

    if (_filteredInvoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'لا توجد فواتير تطابق البحث'
                  : 'لا توجد فواتير مشتريات',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'اضغط على الزر أدناه لإنشاء فاتورة جديدة',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInvoices,
      color: const Color(0xFF14B8A6),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _filteredInvoices.length,
        itemBuilder: (context, index) {
          final invoice = _filteredInvoices[index];
          return FlippableInvoiceCard(
            invoice: invoice,
            onViewDetails: () => _viewInvoiceDetails(invoice),
            onShare: () => _shareInvoice(invoice),
            onDelete: () => _deleteInvoice(invoice),
            onStatusChanged: _onInvoiceStatusChanged,
            onEdit: _onEditInvoice,
          );
        },
      ),
    );
  }

  Widget _buildProductSearchResults() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF14B8A6),
        ),
      );
    }

    if (_productSearchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                ? 'ابدأ بكتابة اسم المنتج للبحث'
                : 'لم يتم العثور على منتجات تطابق البحث',
              style: GoogleFonts.cairo(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                ? 'يمكنك البحث عن المنتجات بالاسم'
                : 'جرب كلمات مختلفة أو تأكد من الإملاء',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInvoices,
      color: const Color(0xFF14B8A6),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _productSearchResults.length,
        itemBuilder: (context, index) {
          final result = _productSearchResults[index];
          return _buildProductCard(result, index);
        },
      ),
    );
  }

  Widget _buildProductCard(ProductSearchResult result, int index) {
    final item = result.item;
    final invoice = result.invoice;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
        child: InkWell(
          onTap: () => _viewInvoiceDetails(invoice),
          borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product header with image
                Row(
                  children: [
                    // Product image
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: item.productImage != null && item.productImage!.isNotEmpty
                            ? Image.network(
                                item.productImage!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
                              )
                            : _buildPlaceholderImage(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Product name and basic info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: AccountantThemeConfig.greenGradient,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'الكمية: ${item.quantity}',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
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
                // Pricing breakdown
                _buildPricingBreakdown(item),
                const SizedBox(height: 16),
                // Invoice reference
                _buildInvoiceReference(invoice),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(
      delay: Duration(milliseconds: index * 100),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    ).slideY(
      begin: 0.3,
      delay: Duration(milliseconds: index * 100),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.greenGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.inventory_2_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  Widget _buildPricingBreakdown(PurchaseInvoiceItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.monetization_on_rounded,
                color: AccountantThemeConfig.primaryGreen,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'تفاصيل التسعير',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPriceDetail('السعر الأصلي:', '¥${item.yuanPrice.toStringAsFixed(2)}'),
              _buildPriceDetail('سعر الصرف:', '${item.exchangeRate.toStringAsFixed(2)}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPriceDetail(
                'هامش الربح:',
                item.profitMarginPercent == 0.0
                  ? '0% (لا ربح)'
                  : '${item.profitMarginPercent.toStringAsFixed(1)}%'
              ),
              _buildPriceDetail('سعر الوحدة:', AccountantThemeConfig.formatCurrency(item.finalEgpPrice)),
            ],
          ),
          const Divider(color: Colors.white24, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'إجمالي السعر:',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.greenGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AccountantThemeConfig.formatCurrency(item.totalPrice),
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceReference(PurchaseInvoice invoice) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.receipt_long_rounded,
            color: AccountantThemeConfig.primaryGreen,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'من فاتورة #${invoice.id.split('-').last}',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (invoice.supplierName != null) ...[
                      Text(
                        'المورد: ${invoice.supplierName}',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      Formatters.formatDate(invoice.createdAt),
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: AccountantThemeConfig.primaryGreen,
            size: 14,
          ),
        ],
      ),
    );
  }





  void _viewInvoiceDetails(PurchaseInvoice invoice) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PurchaseInvoiceDetailsScreen(
          invoiceId: invoice.id,
        ),
      ),
    );
  }

  Future<void> _shareInvoice(PurchaseInvoice invoice) async {
    try {
      _showInfoSnackBar('جاري إنشاء وتحضير الفاتورة للمشاركة...');

      final success = await _pdfService.generateAndSharePurchaseInvoicePdf(invoice);

      if (success) {
        _showSuccessSnackBar('تم فتح نافذة المشاركة بنجاح');
      } else {
        _showErrorSnackBar('فشل في مشاركة الفاتورة');
      }
    } catch (e) {
      AppLogger.error('خطأ في مشاركة الفاتورة: $e');
      _showErrorSnackBar('فشل في مشاركة الفاتورة');
    }
  }

  Future<void> _deleteInvoice(PurchaseInvoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'تأكيد الحذف',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        content: Text(
          'هل أنت متأكد من حذف فاتورة المشتريات #${invoice.id.split('-').last}؟',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'إلغاء',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'حذف',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await _invoiceService.deletePurchaseInvoice(invoice.id);
        
        if (result['success'] == true) {
          _showSuccessSnackBar('تم حذف الفاتورة بنجاح');
          _loadInvoices();
        } else {
          _showErrorSnackBar((result['message'] as String?) ?? 'فشل في حذف الفاتورة');
        }
      } catch (e) {
        AppLogger.error('خطأ في حذف الفاتورة: $e');
        _showErrorSnackBar('حدث خطأ غير متوقع');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AccountantThemeConfig.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AccountantThemeConfig.dangerRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.info_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AccountantThemeConfig.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Handle invoice status change from flippable card
  void _onInvoiceStatusChanged(PurchaseInvoice updatedInvoice) {
    setState(() {
      // Find and update the invoice in the lists
      final index = _allInvoices.indexWhere((inv) => inv.id == updatedInvoice.id);
      if (index != -1) {
        _allInvoices[index] = updatedInvoice;
      }

      // Reapply filters to update the filtered list
      _applyFilters();
    });
  }

  /// Handle edit invoice request from flippable card
  void _onEditInvoice(PurchaseInvoice invoice) {
    // Navigate to create purchase invoice screen with edit mode
    Navigator.pushNamed(
      context,
      '/business-owner/create-purchase-invoice',
      arguments: {'editInvoice': invoice},
    ).then((_) {
      // Reload invoices after editing
      _loadInvoices();
    });
  }

  /// Enhanced FAB system with expandable options
  Widget _buildEnhancedFab() {
    print('DEBUG: Building FAB - expanded: $_isFabExpanded, backdrop: $_showBackdrop');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Sub-button (Excel Import) - Higher position
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.elasticOut,
          height: _isFabExpanded ? 60 : 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isFabExpanded ? 1.0 : 0.0,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              scale: _isFabExpanded ? 1.0 : 0.0,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2), // Debug color
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildSubButton(
                  icon: Icons.table_chart,
                  label: 'استيراد إكسل',
                  onPressed: () {
                    print('DEBUG: Excel import sub-button pressed');
                    _navigateToExcelImport();
                  },
                ),
              ),
            ),
          ),
        ),

        // Sub-button (Manual Creation) - Lower position
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.elasticOut,
          height: _isFabExpanded ? 60 : 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isFabExpanded ? 1.0 : 0.0,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 350),
              curve: Curves.elasticOut,
              scale: _isFabExpanded ? 1.0 : 0.0,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2), // Debug color
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildSubButton(
                  icon: Icons.edit_document,
                  label: 'إنشاء يدوي',
                  onPressed: () {
                    print('DEBUG: Manual creation sub-button pressed');
                    _navigateToManualCreation();
                  },
                ),
              ),
            ),
          ),
        ),

        // Main FAB button
        Container(
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.greenGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
          ),
          child: FloatingActionButton.extended(
            onPressed: () {
              print('DEBUG: Main FAB pressed');
              _toggleFab();
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            icon: AnimatedRotation(
              turns: _isFabExpanded ? 0.125 : 0.0, // 45 degrees when expanded
              duration: const Duration(milliseconds: 300),
              child: Icon(
                _isFabExpanded ? Icons.close_rounded : Icons.add_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            label: const Text(
              'فاتورة جديدة',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build sub-button for FAB expansion
  Widget _buildSubButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AccountantThemeConfig.cardBackground1,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
            ),
            boxShadow: AccountantThemeConfig.cardShadows,
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Button
        Container(
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.greenGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onPressed();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Toggle FAB expansion state
  void _toggleFab() {
    print('DEBUG: FAB toggle pressed. Current state: $_isFabExpanded');
    HapticFeedback.lightImpact();
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      _showBackdrop = _isFabExpanded;
    });
    print('DEBUG: FAB state after toggle: $_isFabExpanded, backdrop: $_showBackdrop');
  }

  /// Collapse FAB
  void _collapseFab() {
    setState(() {
      _isFabExpanded = false;
      _showBackdrop = false;
    });
  }

  /// Navigate to manual invoice creation
  void _navigateToManualCreation() {
    print('DEBUG: Manual creation button pressed');
    _collapseFab();
    Navigator.pushNamed(context, '/business-owner/create-purchase-invoice')
        .then((_) => _loadInvoices());
  }

  /// Navigate to Excel import screen
  void _navigateToExcelImport() {
    print('DEBUG: Excel import button pressed');
    _collapseFab();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ExcelImportScreen(),
      ),
    ).then((_) => _loadInvoices());
  }
}
