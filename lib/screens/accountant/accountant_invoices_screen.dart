import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import 'package:smartbiztracker_new/models/flask_invoice_model.dart';
import 'package:smartbiztracker_new/services/invoice_service.dart';
import 'package:smartbiztracker_new/widgets/common/advanced_search_bar.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/providers/unified_auth_provider.dart';

class AccountantInvoicesScreen extends StatefulWidget {
  const AccountantInvoicesScreen({Key? key}) : super(key: key);

  // Factory method to create the screen with necessary providers
  static Widget withProviders() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider.forTest()),
        ChangeNotifierProvider(create: (_) => SupabaseProvider()),
        ProxyProvider2<SupabaseProvider, AuthProvider, UnifiedAuthProvider>(
          update: (_, supabaseProvider, authProvider, __) => 
              UnifiedAuthProvider(
                supabaseProvider: supabaseProvider,
                authProvider: authProvider,
              ),
        ),
      ],
      child: const AccountantInvoicesScreen(),
    );
  }

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
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  
  // Track matching products for highlighting
  List<int> _matchingProductsInInvoices = [];
  Map<int, List<int>> _matchingProductIndicesMap = {};

  // نضيف متغيرات لتحسين العرض والوظائف
  bool _isGridView = false; // لتغيير طريقة العرض
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

  // Get welcome message based on time of day
  String _getWelcomeMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'صباح الخير،';
    } else if (hour < 18) {
      return 'مساء الخير،';
    } else {
      return 'مساء الخير،';
    }
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
      Map<int, List<int>> matchingIndicesMap = {};
      List<int> invoicesWithMatchingProducts = [];
      
      for (var invoice in invoices) {
        // Check if the invoice has matching products from the API
        if (invoice.matchingProducts != null && invoice.matchingProducts!.isNotEmpty) {
          invoicesWithMatchingProducts.add(invoice.id);
          
          // Create matching indices for UI highlighting
          List<int> matchingIndices = [];
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
            Map<int, List<int>> localMatchingIndicesMap = {};
            List<int> localInvoicesWithMatchingProducts = [];
            
            for (var invoice in filteredInvoices) {
              if (invoice.items != null && invoice.items!.isNotEmpty) {
                List<int> matchingIndices = [];
                
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
              
              if (invoice.items != null) 
                ...invoice.items!.map((item) => _buildProductItem(item, invoice.id)).toList(),
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
  
  // Build product item for dialog
  Widget _buildProductItem(FlaskInvoiceItemModel item, int invoiceId) {
    final bool isHighlighted = _matchingProductIndicesMap[invoiceId]?.contains(item.productId) ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isHighlighted 
            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlighted
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).dividerColor,
        ),
      ),
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
                    color: isHighlighted ? Theme.of(context).colorScheme.primary : null,
                                          ),
                                        ),
                                      ),
              if (item.category != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  child: Text(
                    item.category!,
                                style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                                ),
                              ),
                            ],
                          ),
          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                '${item.quantity} × ${_currencyFormat.format(item.price)}',
                                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                                ),
                              ),
                              Text(
                _currencyFormat.format(item.total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
    
    // 使用统一的认证提供者
    final unifiedAuthProvider = Provider.of<UnifiedAuthProvider>(context);
    final accountant = unifiedAuthProvider.user;
    
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
        bool customerMatch = invoice.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               (invoice.customerPhone != null && invoice.customerPhone!.toLowerCase().contains(_searchQuery.toLowerCase()));
        
        // 如果有项目可用，则按产品名称搜索
        bool productMatch = false;
        List<int> matchingIndices = [];
        
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
    
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Column(
      children: [
          // قسم الإحصائيات
        Container(
          width: double.infinity,
            padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withOpacity(0.8),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                // عنوان وترحيب
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getWelcomeMessage()} ${accountant?.name ?? "المحاسب"}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                          'قسم إدارة الفواتير',
                        style: TextStyle(
                          fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                  Container(
                      padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                      child: const Icon(
                      Icons.receipt_long,
                      color: Colors.white,
                        size: 24,
                    ),
                  ),
                ],
              ),
                
                const SizedBox(height: 16),
                
                // ملخص الفواتير
              Row(
                children: [
                    _buildStatCard(
                      'إجمالي الفواتير',
                      _invoices.length.toString(),
                      Icons.receipt,
                      Colors.white,
                      Colors.white.withOpacity(0.2),
                  ),
                  const SizedBox(width: 12),
                    _buildStatCard(
                      'القيمة الإجمالية',
                      _currencyFormat.format(_totalAmount),
                      Icons.paid,
                      Colors.white,
                      Colors.white.withOpacity(0.2),
                  ),
                  const SizedBox(width: 12),
                    _buildStatCard(
                      'قيد الانتظار',
                      _invoices.where((invoice) => invoice.status == 'pending').length.toString(),
                      Icons.pending_actions,
                      Colors.white,
                      Colors.white.withOpacity(0.2),
                  ),
                ],
              ),
            ],
          ),
        ),
        
          // شريط البحث وأدوات التصفية
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // أداة البحث
                Expanded(
          child: AdvancedSearchBar(
            controller: _searchController,
            hintText: 'بحث باسم المنتج، رقم الفاتورة، أو العميل...',
            accentColor: theme.colorScheme.primary,
            showSearchAnimation: true,
            onChanged: (query) {
              setState(() {
                _searchQuery = query;
              });
            },
            onSubmitted: (query) {
              setState(() {
                _searchQuery = query;
              });
              _searchInvoices();
            },
            trailing: _searchQuery.isNotEmpty 
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _matchingProductsInInvoices = [];
                    _matchingProductIndicesMap = {};
                  });
                  _loadInvoices();
                },
              )
            : null,
          ),
        ),
        
                const SizedBox(width: 8),
                
                // أداة تغيير طريقة العرض
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                  onPressed: () {
                    setState(() {
                      _isGridView = !_isGridView;
                    });
                  },
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
          
          // شريط تصفية الحالة
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildStatusFilter(null, 'الكل'),
                _buildStatusFilter('completed', 'مكتمل'),
                _buildStatusFilter('pending', 'قيد الانتظار'),
                _buildStatusFilter('cancelled', 'ملغي'),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // قائمة الفواتير
        Expanded(
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      const Text('جاري تحميل الفواتير...'),
                    ],
                  ),
                )
              : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'حدث خطأ أثناء تحميل الفواتير',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadInvoices,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  )
              : filteredInvoices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 60,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد فواتير مطابقة لمعايير البحث',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'جرب تغيير معايير البحث',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                                  _selectedStatus = null;
                            });
                            _loadInvoices();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة ضبط البحث'),
                        ),
                      ],
                    ),
                  )
                    : _isGridView
                      ? _buildInvoicesGrid(filteredInvoices)
                : _buildInvoicesList(filteredInvoices),
        ),
      ],
      ),
    );
  }

  Widget _buildInvoicesList(List<FlaskInvoiceModel> invoices) {
    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: invoices.length,
        itemBuilder: (context, index) {
          final invoice = invoices[index];
          final hasMatchingProducts = _matchingProductsInInvoices.contains(invoice.id);
          
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: _buildInvoiceCard(invoice, hasMatchingProducts),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildInvoiceCard(FlaskInvoiceModel invoice, bool hasMatchingProducts) {
    // Format date for display
    final dateStr = _dateFormat.format(invoice.date);
    final statusColor = _getStatusColor(invoice.status);
    final cardElevation = hasMatchingProducts ? 4.0 : 2.0;
    
    return Card(
      elevation: cardElevation,
      margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
        side: hasMatchingProducts 
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5)
            : BorderSide.none,
                  ),
                  child: InkWell(
                    onTap: () => _viewInvoiceDetails(invoice),
                    borderRadius: BorderRadius.circular(12),
                      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
            // Header with order number and date
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                  Expanded(
                    child: Text(
                                'فاتورة #${invoice.invoiceNumber}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    dateStr,
                                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                                    fontSize: 12,
                                ),
                              ),
                            ],
                          ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                  // Customer info
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                          invoice.customerName ?? 'عميل غير معروف',
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                  const SizedBox(height: 8),
                          
                  // Amount
                          Row(
                            children: [
                      const Icon(Icons.payments_outlined, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                  _currencyFormat.format(invoice.finalAmount),
                        style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                          color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                  const SizedBox(height: 8),
                  
                  // Status
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                      invoice.status ?? 'قيد الانتظار',
                                      style: TextStyle(
                        color: statusColor,
                                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                  
                  // Products if matching search
                  if (hasMatchingProducts && invoice.matchingProducts != null) 
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                          ),
                                        ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.search,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'المنتجات المطابقة:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: invoice.matchingProducts!.map((product) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  product.productName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
            
            // View details button
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.visibility,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'عرض التفاصيل',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // عرض البطاقات بشكل شبكي
  Widget _buildInvoicesGrid(List<FlaskInvoiceModel> invoices) {
    return AnimationLimiter(
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: invoices.length,
        itemBuilder: (context, index) {
          final invoice = invoices[index];
          final hasMatchingProducts = _matchingProductsInInvoices.contains(invoice.id);
          
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 375),
            columnCount: 2,
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: _buildInvoiceCard(invoice, hasMatchingProducts),
              ),
            ),
          );
        },
      ),
    );
  }
  
  // بطاقة إحصائية
  Widget _buildStatCard(String title, String value, IconData iconData, Color textColor, Color backgroundColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(iconData, color: textColor, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: textColor.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  // زر تصفية الحالة
  Widget _buildStatusFilter(String? status, String label) {
    final isSelected = _selectedStatus == status;
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedStatus = selected ? status : null;
          });
        },
        backgroundColor: theme.cardColor,
        selectedColor: theme.colorScheme.primary.withOpacity(0.2),
        labelStyle: TextStyle(
          color: isSelected ? theme.colorScheme.primary : theme.textTheme.bodyLarge?.color,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
      ),
    );
  }

  // Helper to get status color
  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    
    switch (status.toLowerCase()) {
      case 'مكتملة':
      case 'تم الدفع':
      case 'completed':
      case 'paid':
        return Colors.green;
      case 'قيد الانتظار':
      case 'pending':
      case 'في الانتظار':
        return Colors.orange;
      case 'ملغاة':
      case 'cancelled':
      case 'canceled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
} 