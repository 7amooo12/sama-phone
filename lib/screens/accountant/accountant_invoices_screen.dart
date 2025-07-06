import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:smartbiztracker_new/models/flask_invoice_model.dart';
import 'package:smartbiztracker_new/services/invoice_service.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/widgets/accountant/modern_widgets.dart';

class AccountantInvoicesScreen extends StatefulWidget {
  const AccountantInvoicesScreen({super.key});

  @override
  State<AccountantInvoicesScreen> createState() => _AccountantInvoicesScreenState();
}

class _AccountantInvoicesScreenState extends State<AccountantInvoicesScreen> {
  final InvoiceService _invoiceService = InvoiceService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  List<FlaskInvoiceModel> _invoices = [];
  FlaskInvoiceModel? _selectedInvoice;
  String? _error;

  // Date formatters
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _shortDateFormat = DateFormat('MM/dd');
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'ar_EG',
    symbol: 'ج.م',
    decimalDigits: 2,
  );

  // Track matching products for highlighting
  List<int> _matchingProductsInInvoices = [];
  Map<int, List<int>> _matchingProductIndicesMap = {};

  // نضيف متغيرات لتحسين العرض والوظائف
  final bool _isGridView = false; // لتغيير طريقة العرض
  String? _selectedStatus; // لتصفية الفواتير حسب الحالة
  double _totalAmount = 0.0; // إجمالي المبالغ

  // للتعامل مع زر العودة في الشاشات الحوارية
  bool _isDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // منطق التعامل مع زر العودة في الشاشة الفرعية
  Future<bool> _onWillPop() async {
    // إذا كان هناك حوار مفتوح، أغلقه بدلاً من الخروج من الشاشة الحالية
    if (_isDialogOpen) {
      Navigator.of(context).pop();
      _isDialogOpen = false;
      return false;
    }

    // إذا كانت كلمة البحث غير فارغة ولم تكن هناك شاشة حوارية مفتوحة، إعادة ضبط البحث
    if (_searchQuery.isNotEmpty || _selectedStatus != null) {
      setState(() {
        _searchController.clear();
        _searchQuery = '';
        _selectedStatus = null;
      });
      _loadInvoices();
      return false;
    }

    // اترك الانتقال إلى الشاشة السابقة لـ WillPopScope الأساسي في AccountantDashboard
    return true;
  }



  // Load all invoices
  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _matchingProductsInInvoices = [];
      _matchingProductIndicesMap = {};
    });

    try {
      final invoices = await _invoiceService.getInvoices();

      // حساب المجموع الكلي
      double total = 0;
      for (var invoice in invoices) {
        total += invoice.finalAmount;
      }

      if (mounted) {
        setState(() {
          _invoices = invoices;
          _totalAmount = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
      debugPrint('❌ Error loading invoices: $e');
    }
  }

  // Search invoices
  Future<void> _searchInvoices() async {
    if (_searchQuery.isEmpty) {
      _loadInvoices();
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _matchingProductsInInvoices = [];
      _matchingProductIndicesMap = {};
    });

    try {
      // This will search by both customer name and product name using the API
      final invoices = await _invoiceService.searchInvoices(_searchQuery);

      // Process matching products from API response
      final Map<int, List<int>> matchingIndicesMap = {};
      final List<int> invoicesWithMatchingProducts = [];

      for (var invoice in invoices) {
        // Check if the invoice has matching products from the API
        if (invoice.matchingProducts != null && invoice.matchingProducts!.isNotEmpty) {
          invoicesWithMatchingProducts.add(invoice.id);

          // Create matching indices for UI highlighting
          final List<int> matchingIndices = [];
          if (invoice.items != null) {
            for (var matchingProduct in invoice.matchingProducts!) {
          for (int i = 0; i < invoice.items!.length; i++) {
                if (invoice.items![i].productId == matchingProduct.productId) {
              matchingIndices.add(i);
            }
          }
            }
            matchingIndicesMap[invoice.id] = matchingIndices;
          }
        }
      }

      setState(() {
        _invoices = invoices;
        _matchingProductsInInvoices = invoicesWithMatchingProducts;
        _matchingProductIndicesMap = matchingIndicesMap;
        _isLoading = false;
      });

      // If no results and search term is short, try to do local filtering too
      if (invoices.isEmpty && _searchQuery.length >= 2) {
        // Try to load all invoices and then filter locally
        try {
          final allInvoices = await _invoiceService.getInvoices();
          // Filter locally for products
          final filteredInvoices = allInvoices.where((invoice) {
            // Check if any product name contains the search query
            if (invoice.items != null) {
              return invoice.items!.any((item) =>
                item.productName.toLowerCase().contains(_searchQuery.toLowerCase())
              );
            }
            return false;
          }).toList();

          if (filteredInvoices.isNotEmpty) {
            // Identify invoices with matching products and their indices for the local results
            final Map<int, List<int>> localMatchingIndicesMap = {};
            final List<int> localInvoicesWithMatchingProducts = [];

            for (var invoice in filteredInvoices) {
              if (invoice.items != null && invoice.items!.isNotEmpty) {
                final List<int> matchingIndices = [];

                for (int i = 0; i < invoice.items!.length; i++) {
                  if (invoice.items![i].productName.toLowerCase().contains(_searchQuery.toLowerCase())) {
                    matchingIndices.add(i);
                  }
                }

                if (matchingIndices.isNotEmpty) {
                  localInvoicesWithMatchingProducts.add(invoice.id);
                  localMatchingIndicesMap[invoice.id] = matchingIndices;
                }
              }
            }

            setState(() {
              _invoices = filteredInvoices;
              _matchingProductsInInvoices = localInvoicesWithMatchingProducts;
              _matchingProductIndicesMap = localMatchingIndicesMap;
            });
          }
        } catch (e) {
          // Silently fail on this fallback
          debugPrint('❌ Error in local product search fallback: $e');
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;

        // Show a more user-friendly error message
        if (e.toString().contains('Invalid or missing API key')) {
          _error = 'خطأ في المصادقة: الرجاء التحقق من مفتاح API';
        } else if (e.toString().contains('Failed to search invoices')) {
          _error = 'تعذر البحث عن الفواتير: يرجى التحقق من اتصالك';
        }
      });
      debugPrint('❌ Error searching invoices: $e');
    }
  }

  // View invoice details
  void _viewInvoiceDetails(FlaskInvoiceModel invoice) {
    setState(() {
      _selectedInvoice = invoice;
      _isDialogOpen = true;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تفاصيل الفاتورة #${invoice.invoiceNumber}'),
        content: SingleChildScrollView(
              child: Column(
            mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              _buildInfoRow('التاريخ', _dateFormat.format(invoice.date)),
              _buildInfoRow('العميل', invoice.customerName ?? 'غير معروف'),
              _buildInfoRow('الإجمالي', _currencyFormat.format(invoice.finalAmount)),
              _buildInfoRow('الحالة', invoice.status ?? 'قيد الانتظار'),

              const Divider(),

                          const Text(
                'المنتجات:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 8),

              // Handle missing items case
              if (invoice.items != null && invoice.items!.isNotEmpty)
                ...invoice.items!.map((item) => _buildProductItem(item, invoice.id))
              else if (invoice.items == null || invoice.items!.isEmpty)
                _buildMissingItemsWidget(invoice),
                        ],
                      ),
                    ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _isDialogOpen = false;
              });
              Navigator.of(context).pop();
            },
            child: const Text('إغلاق'),
          ),
        ],
      ),
    ).then((_) {
      setState(() {
        _isDialogOpen = false;
      });
    });
  }

  // Widget to handle missing items case
  Widget _buildMissingItemsWidget(FlaskInvoiceModel invoice) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade900.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade600),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.orange.shade400, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'لم يتم تحميل تفاصيل المنتجات',
                  style: TextStyle(
                    color: Colors.orange.shade200,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _reloadInvoiceDetails(invoice),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('إعادة تحميل التفاصيل'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  // Reload invoice details from API
  Future<void> _reloadInvoiceDetails(FlaskInvoiceModel invoice) async {
    try {
      print('🔄 Reloading details for invoice ${invoice.id}');
      final detailedInvoice = await _invoiceService.getInvoice(invoice.id);

      // Update the invoice in the list
      final index = _invoices.indexWhere((inv) => inv.id == invoice.id);
      if (index != -1) {
        setState(() {
          _invoices[index] = detailedInvoice;
          _selectedInvoice = detailedInvoice;
        });

        // Close and reopen dialog with updated data
        Navigator.of(context).pop();
        _viewInvoiceDetails(detailedInvoice);
      }
    } catch (e) {
      print('❌ Error reloading invoice details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إعادة تحميل التفاصيل: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Build product item for dialog
  Widget _buildProductItem(FlaskInvoiceItemModel item, int invoiceId) {
    final bool isHighlighted = _matchingProductIndicesMap[invoiceId]?.contains(item.productId) ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlighted
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).dividerColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // صورة المنتج
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[200],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildProductImage(item),
            ),
          ),
          const SizedBox(width: 12),
          // تفاصيل المنتج
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.productName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isHighlighted
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                    ),
                    if (item.category != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item.category!,
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الكمية: ${item.quantity}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    Text(
                      'السعر: ${_currencyFormat.format(item.price)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الإجمالي:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    Text(
                      _currencyFormat.format(item.total),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper for dialog info rows
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // استخدام SupabaseProvider بدلاً من UnifiedAuthProvider لتجنب المشاكل
    final supabaseProvider = Provider.of<SupabaseProvider>(context);

    // 过滤发票基于搜索查询（如果不是通过API搜索）
    List<FlaskInvoiceModel> filteredInvoices;
    if (_searchQuery.isEmpty) {
      filteredInvoices = _invoices;
    } else {
      // 创建过滤列表并识别匹配的产品索引
      filteredInvoices = [];
      _matchingProductsInInvoices = [];
      _matchingProductIndicesMap = {};

      for (var invoice in _invoices) {
        final bool customerMatch = invoice.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               (invoice.customerPhone != null && invoice.customerPhone!.toLowerCase().contains(_searchQuery.toLowerCase()));

        // 如果有项目可用，则按产品名称搜索
        bool productMatch = false;
        final List<int> matchingIndices = [];

        if (invoice.items != null && invoice.items!.isNotEmpty) {
          for (int i = 0; i < invoice.items!.length; i++) {
            if (invoice.items![i].productName.toLowerCase().contains(_searchQuery.toLowerCase())) {
              productMatch = true;
              matchingIndices.add(i);
            }
          }

          if (productMatch) {
            _matchingProductsInInvoices.add(invoice.id);
            _matchingProductIndicesMap[invoice.id] = matchingIndices;
          }
        }

        // 如果有任何匹配，添加到过滤列表
        if (customerMatch || productMatch) {
          filteredInvoices.add(invoice);
        }
      }
    }

    // فرز الفواتير حسب الحالة إذا تم تحديدها
    if (_selectedStatus != null) {
      filteredInvoices = filteredInvoices.where(
        (invoice) => invoice.status == _selectedStatus
      ).toList();
    }

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: WillPopScope(
        onWillPop: _onWillPop,
        child: Container(
          decoration: const BoxDecoration(
            gradient: AccountantThemeConfig.mainBackgroundGradient,
          ),
          child: Column(
            children: [
              // Modern Search and Statistics Section
              Container(
                padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.cardGradient,
                  border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
                  boxShadow: AccountantThemeConfig.cardShadows,
                ),
                child: Column(
                  children: [
                    // Modern Search Bar with Invoice Count Indicator
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.1),
                            Colors.white.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                        border: Border.all(color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          // Search TextField
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: AccountantThemeConfig.bodyMedium,
                              decoration: InputDecoration(
                                hintText: 'البحث في الفواتير...',
                                hintStyle: AccountantThemeConfig.bodyMedium.copyWith(
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: AccountantThemeConfig.accentBlue,
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.clear_rounded,
                                          color: AccountantThemeConfig.neutralColor,
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _searchQuery = '';
                                          });
                                          _loadInvoices();
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AccountantThemeConfig.defaultPadding,
                                  vertical: 14,
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                                if (value.isEmpty) {
                                  _loadInvoices();
                                } else {
                                  _searchInvoices();
                                }
                              },
                            ),
                          ),

                          // Professional Invoice Count Badge
                          Container(
                            margin: const EdgeInsets.only(left: AccountantThemeConfig.defaultPadding),
                            child: AnimatedContainer(
                              duration: AccountantThemeConfig.animationDuration,
                              curve: Curves.easeInOut,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: AccountantThemeConfig.greenGradient,
                                borderRadius: BorderRadius.circular(20),
                                border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
                                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.receipt_long_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${filteredInvoices.length}',
                                    style: AccountantThemeConfig.labelMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Modern Invoice List
              Expanded(
                child: _isLoading
                    ? ModernAccountantWidgets.buildModernLoader(
                        message: 'جاري تحميل الفواتير...',
                        color: AccountantThemeConfig.primaryGreen,
                      )
                    : _error != null
                        ? ModernAccountantWidgets.buildEmptyState(
                            icon: Icons.error_outline_rounded,
                            title: 'حدث خطأ',
                            subtitle: _error!,
                            actionText: 'إعادة المحاولة',
                            onActionPressed: _loadInvoices,
                          )
                        : filteredInvoices.isEmpty
                            ? ModernAccountantWidgets.buildEmptyState(
                                icon: Icons.receipt_long_outlined,
                                title: 'لا توجد فواتير',
                                subtitle: _searchQuery.isNotEmpty
                                    ? 'لم يتم العثور على فواتير تطابق البحث'
                                    : 'لم يتم إنشاء أي فواتير بعد',
                              )
                            : RefreshIndicator(
                                onRefresh: _loadInvoices,
                                color: AccountantThemeConfig.primaryGreen,
                                backgroundColor: AccountantThemeConfig.cardBackground1,
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
                                  itemCount: filteredInvoices.length,
                                  itemBuilder: (context, index) {
                                    final invoice = filteredInvoices[index];
                                    return AnimatedContainer(
                                      duration: Duration(milliseconds: 800 + (index * 100)),
                                      curve: Curves.easeInOut,
                                      child: _buildModernInvoiceCard(invoice, index),
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernInvoiceCard(FlaskInvoiceModel invoice, int index) {
    final bool hasMatchingProducts = _matchingProductsInInvoices.contains(invoice.id);

    return Container(
      margin: const EdgeInsets.only(bottom: AccountantThemeConfig.defaultPadding),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
        border: hasMatchingProducts
            ? AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen)
            : AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
        boxShadow: hasMatchingProducts
            ? AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen)
            : AccountantThemeConfig.cardShadows,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
        child: InkWell(
          onTap: () => _viewInvoiceDetails(invoice),
          borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
          child: Padding(
            padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modern Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'فاتورة #${invoice.invoiceNumber}',
                      style: AccountantThemeConfig.headlineSmall.copyWith(
                        color: hasMatchingProducts ? AccountantThemeConfig.primaryGreen : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _buildModernStatusChip(invoice.status ?? 'قيد الانتظار'),
                  ],
                ),


                const SizedBox(height: AccountantThemeConfig.defaultPadding),

                // Modern Customer and Date Info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AccountantThemeConfig.accentBlue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        size: 16,
                        color: AccountantThemeConfig.accentBlue,
                      ),
                    ),
                    const SizedBox(width: AccountantThemeConfig.smallPadding),
                    Expanded(
                      child: Text(
                        invoice.customerName ?? 'غير معروف',
                        style: AccountantThemeConfig.bodyMedium,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AccountantThemeConfig.smallPadding),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AccountantThemeConfig.neutralColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: AccountantThemeConfig.neutralColor,
                      ),
                    ),
                    const SizedBox(width: AccountantThemeConfig.smallPadding),
                    Text(
                      _dateFormat.format(invoice.date),
                      style: AccountantThemeConfig.bodyMedium,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                            AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        AccountantThemeConfig.formatCurrency(invoice.finalAmount),
                        style: AccountantThemeConfig.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AccountantThemeConfig.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),

                // Modern Products Section
                if (invoice.items != null && invoice.items!.isNotEmpty) ...[
                  const SizedBox(height: AccountantThemeConfig.defaultPadding),

                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AccountantThemeConfig.accentBlue.withOpacity(0.3),
                          Colors.transparent,
                          AccountantThemeConfig.accentBlue.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AccountantThemeConfig.defaultPadding),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AccountantThemeConfig.warningOrange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.inventory_2_rounded,
                          size: 16,
                          color: AccountantThemeConfig.warningOrange,
                        ),
                      ),
                      const SizedBox(width: AccountantThemeConfig.smallPadding),
                      Text(
                        'المنتجات (${invoice.items!.length}):',
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AccountantThemeConfig.smallPadding),

                  // Modern Product Items
                  ...invoice.items!.take(3).map((item) => Container(
                    margin: const EdgeInsets.only(bottom: AccountantThemeConfig.smallPadding),
                    padding: const EdgeInsets.all(AccountantThemeConfig.smallPadding),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        // Modern Product Image
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
                            border: Border.all(
                              color: AccountantThemeConfig.accentBlue.withOpacity(0.3),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
                            child: _buildSmallProductImage(item),
                          ),
                        ),
                        const SizedBox(width: AccountantThemeConfig.smallPadding),
                        Expanded(
                          child: Text(
                            item.productName,
                            style: AccountantThemeConfig.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AccountantThemeConfig.accentBlue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'الكمية: ${item.quantity}',
                            style: AccountantThemeConfig.labelSmall.copyWith(
                              color: AccountantThemeConfig.accentBlue,
                            ),
                          ),
                        ),
                        const SizedBox(width: AccountantThemeConfig.smallPadding),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            AccountantThemeConfig.formatCurrency(item.total),
                            style: AccountantThemeConfig.labelSmall.copyWith(
                              color: AccountantThemeConfig.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),

                  // Show remaining products count
                  if (invoice.items!.length > 3) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AccountantThemeConfig.accentBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '... و ${invoice.items!.length - 3} منتجات أخرى',
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: AccountantThemeConfig.accentBlue,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],

                // Modern Matching Products Indicator
                if (hasMatchingProducts) ...[
                  const SizedBox(height: AccountantThemeConfig.smallPadding),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                          AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 16,
                          color: AccountantThemeConfig.primaryGreen,
                        ),
                        const SizedBox(width: AccountantThemeConfig.smallPadding),
                        Text(
                          'يحتوي على منتجات مطابقة للبحث',
                          style: AccountantThemeConfig.labelMedium.copyWith(
                            color: AccountantThemeConfig.primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernStatusChip(String status) {
    Color chipColor;
    String displayStatus;

    switch (status.toLowerCase()) {
      case 'completed':
        chipColor = AccountantThemeConfig.completedColor;
        displayStatus = 'مكتملة';
        break;
      case 'pending':
        chipColor = AccountantThemeConfig.pendingColor;
        displayStatus = 'قيد الانتظار';
        break;
      case 'cancelled':
        chipColor = AccountantThemeConfig.canceledColor;
        displayStatus = 'ملغية';
        break;
      default:
        chipColor = AccountantThemeConfig.neutralColor;
        displayStatus = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [chipColor.withOpacity(0.2), chipColor.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor.withOpacity(0.4)),
        boxShadow: AccountantThemeConfig.glowShadows(chipColor),
      ),
      child: Text(
        displayStatus,
        style: AccountantThemeConfig.labelMedium.copyWith(
          color: chipColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProductImage(FlaskInvoiceItemModel item) {
    // بناء URL الصورة من imageUrl إذا كان متوفراً
    String? imageUrl = _fixImageUrl(item.imageUrl);

    if (imageUrl != null) {
      return Image.network(
        imageUrl,
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
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackIcon();
        },
      );
    } else {
      return _buildFallbackIcon();
    }
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

  Widget _buildFallbackIcon() {
    return Container(
      color: Colors.grey[200],
      child: Icon(
        Icons.inventory_2,
        color: Colors.grey[400],
        size: 24,
      ),
    );
  }

  Widget _buildSmallProductImage(FlaskInvoiceItemModel item) {
    // بناء URL الصورة من imageUrl إذا كان متوفراً
    String? imageUrl = _fixImageUrl(item.imageUrl);

    if (imageUrl != null) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 1.5,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildSmallFallbackIcon();
        },
      );
    } else {
      return _buildSmallFallbackIcon();
    }
  }

  Widget _buildSmallFallbackIcon() {
    return Container(
      color: Colors.grey[200],
      child: Icon(
        Icons.inventory_2,
        color: Colors.grey[400],
        size: 16,
      ),
    );
  }
}