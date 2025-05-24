import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/models/order_model.dart';
import 'package:smartbiztracker_new/services/stockwarehouse_api.dart';
import 'package:smartbiztracker_new/widgets/error_widget.dart';
import 'package:smartbiztracker_new/widgets/loading_widget.dart';
import 'package:smartbiztracker_new/utils/app_localizations.dart';
import 'package:smartbiztracker_new/utils/logger.dart';
import 'package:smartbiztracker_new/screens/orders/order_details_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  _OrdersScreenState createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<OrderModel>> _ordersFuture;
  final AppLogger logger = AppLogger();
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  List<OrderModel>? _filteredOrders;
  List<OrderModel> _allOrders = [];
  
  // Track which search field matched for highlighting
  Map<String, List<String>> _matchedProducts = {};
  
  // تتبع نوع البحث الحالي
  String _searchType = 'all'; // 'all', 'customer', 'product', 'order'
  bool _hasAttemptedReload = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    
    _searchController.addListener(() {
      _filterOrders();
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterOrders() {
    // لا يمكننا التحقق مباشرة مما إذا كان Future مكتملاً، لذلك نتعامل معه بشكل مختلف
    if (_isLoading || _allOrders.isEmpty) return;
    
    final searchText = _searchController.text.trim().toLowerCase();
    
    // إعادة تعيين لعرض جميع الطلبات إذا كان نص البحث فارغًا
    if (searchText.isEmpty) {
      setState(() {
        _filteredOrders = null; // إعادة تعيين لعرض جميع الطلبات
        _matchedProducts = {};
      });
      return;
    }
    
    Map<String, List<String>> matchedProducts = {};
    
    final filtered = _allOrders.where((order) {
      // البحث حسب النوع المحدد
      if (_searchType == 'customer') {
        return order.customerName.toLowerCase().contains(searchText) ||
               (order.customerPhone != null && order.customerPhone!.toLowerCase().contains(searchText));
      }
      else if (_searchType == 'product') {
        bool productMatch = false;
        List<String> matchingItems = [];
        
        for (var item in order.items) {
          if (item.productName.toLowerCase().contains(searchText)) {
            productMatch = true;
            matchingItems.add(item.productName);
          }
        }
        
        // تخزين المنتجات المطابقة لهذا الطلب
        if (matchingItems.isNotEmpty) {
          matchedProducts[order.id] = matchingItems;
        }
        
        return productMatch;
      }
      else if (_searchType == 'order') {
        return order.orderNumber.toLowerCase().contains(searchText);
      }
      else {
        // البحث في جميع الحقول
        // البحث حسب اسم العميل أو رقم الطلب
        bool basicMatch = order.customerName.toLowerCase().contains(searchText) ||
               order.orderNumber.toLowerCase().contains(searchText) ||
               (order.customerPhone != null && order.customerPhone!.toLowerCase().contains(searchText));
        
        // البحث حسب اسم المنتج
        bool productMatch = false;
        List<String> matchingItems = [];
        
        for (var item in order.items) {
          if (item.productName.toLowerCase().contains(searchText)) {
            productMatch = true;
            matchingItems.add(item.productName);
          }
        }
        
        // تخزين المنتجات المطابقة لهذا الطلب
        if (matchingItems.isNotEmpty) {
          matchedProducts[order.id] = matchingItems;
        }
        
        // البحث حسب اسم المستودع
        bool warehouseMatch = order.warehouse_name != null &&
            order.warehouse_name!.toLowerCase().contains(searchText);
        
        // البحث حسب رقم الهاتف
        bool phoneMatch = order.customerPhone != null && order.customerPhone!.toLowerCase().contains(searchText);
        
        return basicMatch || productMatch || warehouseMatch || phoneMatch;
      }
    }).toList();
    
    logger.i('نتائج البحث: تم العثور على ${filtered.length} طلب لـ "$searchText"');
    
    setState(() {
      _filteredOrders = filtered;
      _matchedProducts = matchedProducts;
    });
  }

  void _loadOrders() {
    final apiService = Provider.of<StockWarehouseApiService>(context, listen: false);
    
    // تعيين حالة التحميل
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _filteredOrders = null;
      _matchedProducts = {};
    });
    
    // تجربة استخدام بيانات وهمية إذا فشل الاتصال
    apiService.checkApiAvailability().then((isApiAvailable) {
      if (!isApiAvailable) {
        logger.w('API غير متاح، سيتم استخدام البيانات الوهمية مباشرة');
        _createAndDisplayMockData();
        return;
      }
      
      // محاولة تسجيل الدخول أولاً، ثم الحصول على الطلبات
      apiService.login('admin', 'admin123').then((loginSuccess) {
        if (loginSuccess) {
          logger.i('تم تسجيل الدخول بنجاح، جاري جلب الطلبات');
        } else {
          logger.w('فشل تسجيل الدخول، محاولة استخدام مفتاح API مباشرة');
        }
        
        // الحصول على الطلبات
        _ordersFuture = apiService.getOrders();
        
        // تحديث الحالة عند الاكتمال
        _ordersFuture.then((orders) {
          if (mounted) {
            if (orders.isNotEmpty || _hasAttemptedReload) {
              setState(() {
                _isLoading = false;
                _allOrders = orders;
                _hasAttemptedReload = true;
                
                if (orders.isEmpty) {
                  logger.w('لم يتم العثور على طلبات، سيتم استخدام بيانات وهمية');
                  _createAndDisplayMockData();
                } else {
                  // تطبيق التصفية إذا كان نص البحث موجودًا
                  if (_searchController.text.isNotEmpty) {
                    _filterOrders();
                  }
                }
              });
            } else {
              // If orders is empty on first load, attempt to reload once more
              logger.w('لم يتم العثور على طلبات في المحاولة الأولى. محاولة إعادة التحميل...');
              _hasAttemptedReload = true;
              
              // Short delay before trying again
              Future.delayed(Duration(seconds: 1), () {
                apiService.getOrders().then((orders) {
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                      _allOrders = orders;
                      
                      if (orders.isEmpty) {
                        logger.w('لم يتم العثور على طلبات بعد المحاولة الثانية، سيتم استخدام بيانات وهمية');
                        _createAndDisplayMockData();
                      } else {
                        // تطبيق التصفية إذا كان نص البحث موجودًا
                        if (_searchController.text.isNotEmpty) {
                          _filterOrders();
                        }
                      }
                    });
                  }
                }).catchError((error) {
                  if (mounted) {
                    logger.e('خطأ في جلب الطلبات: $error');
                    _createAndDisplayMockData();
                  }
                });
              });
            }
          }
        }).catchError((error) {
          if (mounted) {
            logger.e('خطأ في جلب الطلبات: $error');
            _createAndDisplayMockData();
          }
        });
      }).catchError((error) {
        logger.e('خطأ أثناء تسجيل الدخول', error);
        
        // محاولة الحصول على الطلبات على أي حال
        _ordersFuture = apiService.getOrders();
        
        // تحديث الحالة عند الاكتمال
        _ordersFuture.then((orders) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _allOrders = orders;
              if (orders.isEmpty) {
                logger.w('لم يتم العثور على طلبات بعد الخطأ، سيتم استخدام بيانات وهمية');
                _createAndDisplayMockData();
              } else {
                // تطبيق التصفية إذا كان نص البحث موجودًا
                if (_searchController.text.isNotEmpty) {
                  _filterOrders();
                }
              }
            });
          }
        }).catchError((error) {
          if (mounted) {
            logger.e('خطأ في جلب الطلبات بعد فشل تسجيل الدخول: $error');
            _createAndDisplayMockData();
          }
        });
      });
    }).catchError((error) {
      logger.e('خطأ في التحقق من توفر API: $error');
      _createAndDisplayMockData();
    });
  }
  
  // إنشاء بيانات وهمية للاختبار
  void _createAndDisplayMockData() {
    if (mounted) {
      logger.i('إنشاء بيانات وهمية للطلبات');
      
      List<OrderModel> mockOrders = [];
      
      for (int i = 1; i <= 15; i++) {
        // إنشاء عناصر وهمية للطلب
        List<OrderItem> mockItems = [];
        final itemsCount = i % 3 + 1; // 1-3 منتجات لكل طلب
        
        for (int j = 1; j <= itemsCount; j++) {
          mockItems.add(OrderItem(
            id: 'item_${i}_$j',
            productId: 'prod_$j',
            productName: 'منتج اختبار $j',
            price: 150.0 * j,
            quantity: j,
            subtotal: 150.0 * j * j,
            imageUrl: j % 2 == 0 ? 'https://via.placeholder.com/150' : null,
          ));
        }
        
        // حساب المبلغ الإجمالي للطلب
        final totalAmount = mockItems.fold(0.0, (sum, item) => sum + item.subtotal);
        
        // إنشاء طلب وهمي
        mockOrders.add(OrderModel(
          id: '$i',
          orderNumber: 'ORD-2023-$i',
          customerName: 'عميل اختبار $i',
          customerPhone: '0123${i}${i}${i}${i}${i}',
          status: i % 5 == 0 ? 'delivered' : 
                 i % 4 == 0 ? 'shipped' : 
                 i % 3 == 0 ? 'processing' : 
                 i % 2 == 0 ? 'cancelled' : 'pending',
          totalAmount: totalAmount,
          items: mockItems,
          createdAt: DateTime.now().subtract(Duration(days: i * 2)),
          warehouseName: 'مستودع اختبار ${i % 3 + 1}',
        ));
      }
      
      setState(() {
        _isLoading = false;
        _errorMessage = null;
        _allOrders = mockOrders;
        
        // تطبيق التصفية إذا كان نص البحث موجودًا
        if (_searchController.text.isNotEmpty) {
          _filterOrders();
        }
      });
    }
  }

  void _navigateToOrderDetails(OrderModel order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailsScreen(order: order),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'قيد الانتظار':
        return Colors.orange;
      case 'processing':
      case 'قيد المعالجة':
        return Colors.blue;
      case 'shipped':
      case 'تم الشحن':
        return Colors.purple;
      case 'delivered':
      case 'تم التسليم':
        return Colors.green;
      case 'cancelled':
      case 'canceled':
      case 'ملغي':
        return Colors.red;
      case 'in_production':
      case 'تحت التصنيع':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(appLocalizations.translate('orders') ?? 'الطلبات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadOrders();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث - مميز جدًا وواضح للمستخدم
          Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  spreadRadius: 2,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // عنوان البحث مع أيقونة واضحة
                Row(
                  children: [
                    Icon(Icons.search, color: Colors.indigo.shade800, size: 24),
                    SizedBox(width: 8),
                    Text(
                      appLocalizations.translate('search_orders') ?? 'البحث في الطلبيات:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.indigo.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // مربع البحث بتصميم واضح
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: appLocalizations.translate('search_orders_hint') ?? 'البحث بإسم العميل، رقم الطلب، أو إسم المنتج',
                    prefixIcon: const Icon(Icons.search, color: Colors.blue, size: 24),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.red, size: 22),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                  ),
                  style: const TextStyle(fontSize: 16),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _filterOrders(),
                ),
                
                // أزرار تصفية البحث
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('الكل', 'all'),
                        SizedBox(width: 8),
                        _buildFilterChip('العملاء', 'customer'),
                        SizedBox(width: 8),
                        _buildFilterChip('المنتجات', 'product'),
                        SizedBox(width: 8),
                        _buildFilterChip('رقم الطلب', 'order'),
                      ],
                    ),
                  ),
                ),
                
                // نص توضيحي لتحسين تجربة المستخدم
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, right: 4.0),
                  child: Text(
                    'يمكنك البحث بإسم العميل، رقم الطلب، أو إسم المنتج',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.indigo.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // قائمة الطلبات
          Expanded(
            child: _isLoading 
              ? const LoadingWidget()
              : _errorMessage != null
                ? AppErrorWidget(
                    message: _errorMessage!,
                    onRetry: () {
                      _loadOrders();
                    },
                  )
                : _buildOrdersList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(String label, String type) {
    final isSelected = _searchType == type;
    
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: Colors.blue.shade700,
      backgroundColor: Colors.blue.shade100,
      checkmarkColor: Colors.white,
      onSelected: (selected) {
        setState(() {
          _searchType = type;
          _filterOrders();
        });
      },
    );
  }
  
  Widget _buildOrdersList() {
    final appLocalizations = AppLocalizations.of(context);
    
    // استخدم الطلبات المصفاة إذا كانت متاحة، وإلا استخدم جميع الطلبات
    final orders = _filteredOrders ?? _allOrders;
    
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              _filteredOrders != null
                  ? appLocalizations.translate('no_search_results') ?? 'لا توجد نتائج للبحث'
                  : appLocalizations.translate('no_orders_found') ?? 'لم يتم العثور على طلبات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (_filteredOrders != null) ...[
              SizedBox(height: 8),
              ElevatedButton.icon(
                icon: Icon(Icons.clear),
                label: Text('مسح البحث'),
                onPressed: () {
                  _searchController.clear();
                },
              ),
            ],
            SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text('إعادة تحميل البيانات'),
              onPressed: _loadOrders,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        _loadOrders();
      },
      child: ListView.builder(
        itemCount: orders.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final order = orders[index];
          final statusColor = _getStatusColor(order.status);
          final hasMatchedProducts = _matchedProducts.containsKey(order.id);
          
          return Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 16),
            color: hasMatchedProducts ? Colors.yellow.shade50 : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: hasMatchedProducts
                  ? BorderSide(color: Colors.amber.shade700, width: 2)
                  : BorderSide.none,
            ),
            child: InkWell(
              onTap: () => _navigateToOrderDetails(order),
              borderRadius: BorderRadius.circular(12),
              child: ExpansionTile(
                initiallyExpanded: hasMatchedProducts,
                title: Text(
                  '${appLocalizations.translate('order') ?? 'الطلب'}: ${order.orderNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            order.customerName,
                            style: TextStyle(
                              fontWeight: hasMatchedProducts ? FontWeight.bold : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (order.warehouse_name != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.store, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              order.warehouse_name!,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            order.status,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${appLocalizations.translate('total') ?? 'الإجمالي'}: ${order.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    
                    // إظهار المنتجات المطابقة في ملخص البطاقة
                    if (hasMatchedProducts) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade400),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.shade200.withOpacity(0.5),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.search, size: 14, color: Colors.amber.shade800),
                                SizedBox(width: 4),
                                Text(
                                  'المنتجات المطابقة للبحث:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.amber.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ...(_matchedProducts[order.id] ?? []).map((productName) => 
                              Padding(
                                padding: const EdgeInsets.only(right: 4, top: 2, bottom: 2),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '•',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        productName,
                                        style: TextStyle(
                                          fontSize: 12, 
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            ).toList(),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${appLocalizations.translate('date') ?? 'التاريخ'}: ${_formatDate(order.createdAt)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        if (order.customerPhone != null && order.customerPhone!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${appLocalizations.translate('phone') ?? 'الهاتف'}: ${order.customerPhone!}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          appLocalizations.translate('order_items') ?? 'عناصر الطلب',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Divider(),
                        if (order.items.isEmpty) ...[
                          const Text(
                            'لا توجد عناصر في هذا الطلب',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        ] else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: order.items.length,
                          itemBuilder: (context, itemIndex) {
                            final item = order.items[itemIndex];
                            final isMatchedItem = hasMatchedProducts && 
                                _matchedProducts[order.id]!.contains(item.productName);
                            
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: item.imageUrl != null && item.imageUrl!.isNotEmpty
                                ? Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        item.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => 
                                          Image.network(
                                            'https://via.placeholder.com/150/0000FF/FFFFFF?text=${Uri.encodeComponent(item.productName.split(' ').first)}',
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => 
                                              Icon(Icons.image_not_supported, color: Colors.grey),
                                          ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.grey.shade300),
                                      color: Colors.grey.shade200,
                                    ),
                                    child: Image.network(
                                      'https://via.placeholder.com/150/0000FF/FFFFFF?text=${Uri.encodeComponent(item.productName.split(' ').first)}',
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => 
                                        Icon(Icons.image, color: Colors.grey),
                                    ),
                                  ),
                              title: Text(
                                item.productName,
                                style: TextStyle(
                                  fontWeight: isMatchedItem ? FontWeight.bold : FontWeight.normal,
                                  color: isMatchedItem ? Colors.amber.shade800 : null,
                                  decoration: isMatchedItem ? TextDecoration.underline : null,
                                ),
                              ),
                              subtitle: Text('${item.quantity} x ${item.price.toStringAsFixed(2)}'),
                              trailing: Text(
                                item.subtotal.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: Icon(Icons.visibility),
                          label: Text('عرض تفاصيل الطلب'),
                          onPressed: () => _navigateToOrderDetails(order),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            minimumSize: Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Helper widget for displaying information rows - improved
class InfoRow extends StatelessWidget {
  final String title;
  final String value;
  final TextStyle? valueStyle;

  const InfoRow({
    super.key, 
    required this.title, 
    required this.value, 
    this.valueStyle
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title: ', 
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            )
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle ?? const TextStyle(fontSize: 14),
            )
          ),
        ],
      ),
    );
  }
} 