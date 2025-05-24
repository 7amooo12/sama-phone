import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/models/task_model.dart';
import 'package:smartbiztracker_new/models/order_model.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/services/stockwarehouse_api.dart';
import 'package:smartbiztracker_new/services/task_service.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/material_wrapper.dart';
import 'package:smartbiztracker_new/widgets/custom_button.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';
import 'package:smartbiztracker_new/utils/show_snackbar.dart';
import 'package:smartbiztracker_new/models/user_role.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class AssignTasksScreen extends StatefulWidget {
  const AssignTasksScreen({Key? key}) : super(key: key);

  @override
  _AssignTasksScreenState createState() => _AssignTasksScreenState();
}

class _AssignTasksScreenState extends State<AssignTasksScreen> with SingleTickerProviderStateMixin {
  final StockWarehouseApiService _apiService = StockWarehouseApiService();
  final TaskService _taskService = TaskService();
  final Uuid _uuid = const Uuid();
  
  late TabController _tabController;
  
  List<ProductModel> _products = [];
  List<OrderModel> _orders = [];
  List<UserModel> _workers = [];
  UserModel? _selectedWorker;
  bool _isLoading = true;
  bool _isSending = false;
  String _searchQuery = '';
  
  // Map to track selected products and their quantities
  final Map<String, Map<String, dynamic>> _selectedProducts = {};
  
  // Map to track selected orders
  final Map<String, OrderModel> _selectedOrders = {};
  
  // Deadline controller
  final TextEditingController _deadlineController = TextEditingController();
  DateTime _deadline = DateTime.now().add(const Duration(days: 3));

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _deadlineController.text = DateFormat('yyyy-MM-dd').format(_deadline);
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _deadlineController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load products from API
      final products = await _apiService.getProducts();
      
      // Load orders from API
      final orders = await _apiService.getOrders();
      
      // Load workers from Supabase (only users with worker role)
      final workers = await Provider.of<SupabaseProvider>(context, listen: false)
          .getUsersByRole(UserRole.worker.value);
      
      setState(() {
        _products = products;
        _orders = orders;
        _workers = workers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ShowSnackbar.show(context, 'حدث خطأ أثناء تحميل البيانات: $e', isError: true);
      }
    }
  }
  
  void _toggleProductSelection(ProductModel product) {
    setState(() {
      if (_selectedProducts.containsKey(product.id)) {
        _selectedProducts.remove(product.id);
      } else {
        _selectedProducts[product.id] = {
          'product': product,
          'quantity': 1,
        };
      }
    });
  }
  
  void _toggleOrderSelection(OrderModel order) {
    setState(() {
      if (_selectedOrders.containsKey(order.id)) {
        _selectedOrders.remove(order.id);
      } else {
        _selectedOrders[order.id] = order;
      }
    });
  }
  
  void _updateQuantity(String productId, int quantity) {
    if (quantity < 1) return;
    
    setState(() {
      if (_selectedProducts.containsKey(productId)) {
        _selectedProducts[productId]?['quantity'] = quantity;
      }
    });
  }
  
  Future<void> _selectDeadline() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    
    if (pickedDate != null) {
      setState(() {
        _deadline = pickedDate;
        _deadlineController.text = DateFormat('yyyy-MM-dd').format(_deadline);
      });
    }
  }
  
  Future<void> _assignProductTasks() async {
    if (_selectedWorker == null) {
      ShowSnackbar.show(context, 'يرجى اختيار عامل', isError: true);
      return;
    }
    
    if (_selectedProducts.isEmpty) {
      ShowSnackbar.show(context, 'يرجى اختيار منتج واحد على الأقل', isError: true);
      return;
    }
    
    setState(() {
      _isSending = true;
    });
    
    try {
      // Get current admin info
      final admin = Provider.of<SupabaseProvider>(context, listen: false).user;
      
      if (admin == null) {
        throw Exception('لم يتم العثور على بيانات المدير');
      }
      
      // Create task for each product
      final List<TaskModel> tasks = [];
      
      for (final entry in _selectedProducts.entries) {
        final product = entry.value['product'] as ProductModel;
        final quantity = entry.value['quantity'] as int;
        
        final task = TaskModel(
          id: _uuid.v4(),
          title: 'تصنيع ${product.name}',
          description: 'مطلوب تصنيع ${product.name} بكمية $quantity',
          workerId: _selectedWorker!.id,
          workerName: _selectedWorker!.name,
          adminId: admin.id,
          adminName: admin.name,
          productId: product.id,
          productName: product.name,
          productImage: product.imageUrl,
          quantity: quantity,
          createdAt: DateTime.now(),
          deadline: _deadline,
          status: 'pending',
          progress: 0.0,
          category: 'product',
        );
        
        tasks.add(task);
      }
      
      // Send tasks to Supabase
      final success = await _taskService.createMultipleTasks(tasks);
      
      if (!success) {
        throw Exception('فشل في إنشاء المهام');
      }
      
      if (mounted) {
        ShowSnackbar.show(context, 'تم إسناد المهام بنجاح', isError: false);
        
        // Clear selections
        setState(() {
          _selectedProducts.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ShowSnackbar.show(context, 'حدث خطأ أثناء إسناد المهام: $e', isError: true);
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }
  
  Future<void> _assignOrderTasks() async {
    if (_selectedWorker == null) {
      ShowSnackbar.show(context, 'يرجى اختيار عامل', isError: true);
      return;
    }
    
    if (_selectedOrders.isEmpty) {
      ShowSnackbar.show(context, 'يرجى اختيار طلب واحد على الأقل', isError: true);
      return;
    }
    
    setState(() {
      _isSending = true;
    });
    
    try {
      // Get current admin info
      final admin = Provider.of<SupabaseProvider>(context, listen: false).user;
      
      if (admin == null) {
        throw Exception('لم يتم العثور على بيانات المدير');
      }
      
      // Create task for each order
      final List<TaskModel> tasks = [];
      
      for (final order in _selectedOrders.values) {
        final itemCount = order.items?.length ?? 0;
        
        final task = TaskModel(
          id: _uuid.v4(),
          title: 'معالجة الطلب #${order.orderNumber}',
          description: 'مطلوب معالجة طلب من العميل ${order.customerName} يحتوي على $itemCount عنصر',
          workerId: _selectedWorker!.id,
          workerName: _selectedWorker!.name,
          adminId: admin.id,
          adminName: admin.name,
          productId: '', // No specific product
          productName: 'طلب متعدد المنتجات',
          orderId: order.id.toString(),
          quantity: itemCount,
          createdAt: DateTime.now(),
          deadline: _deadline,
          status: 'pending',
          progress: 0.0,
          category: 'order',
          metadata: {
            'customer_name': order.customerName,
            'total_amount': order.totalAmount,
            'order_date': order.date.toIso8601String(),
          },
        );
        
        tasks.add(task);
      }
      
      // Send tasks to Supabase
      final success = await _taskService.createMultipleTasks(tasks);
      
      if (!success) {
        throw Exception('فشل في إنشاء المهام');
      }
      
      if (mounted) {
        ShowSnackbar.show(context, 'تم إسناد المهام بنجاح', isError: false);
        
        // Clear selections
        setState(() {
          _selectedOrders.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ShowSnackbar.show(context, 'حدث خطأ أثناء إسناد المهام: $e', isError: true);
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }
  
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }
  
  List<ProductModel> get _filteredProducts {
    if (_searchQuery.isEmpty) {
      return _products;
    }
    
    return _products.where((product) {
      return product.name.toLowerCase().contains(_searchQuery) ||
             (product.description?.toLowerCase().contains(_searchQuery) ?? false) ||
             (product.sku?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();
  }
  
  List<OrderModel> get _filteredOrders {
    if (_searchQuery.isEmpty) {
      return _orders;
    }
    
    return _orders.where((order) {
      return order.customerName.toLowerCase().contains(_searchQuery) ||
             order.id.toString().contains(_searchQuery) ||
             order.orderNumber.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialWrapper(
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'إسناد مهام للعمال',
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Container(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).primaryColor,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.category),
                    text: 'إسناد منتجات',
                  ),
                  Tab(
                    icon: Icon(Icons.shopping_cart),
                    text: 'إسناد طلبيات',
                  ),
                ],
              ),
            ),
          ),
        ),
        body: _isLoading 
          ? const CustomLoader(message: 'جاري تحميل البيانات...')
          : Stack(
              children: [
                TabBarView(
                  controller: _tabController,
                  children: [
                    // Products tab
                    _buildProductsTab(),
                    
                    // Orders tab
                    _buildOrdersTab(),
                  ],
                ),
                if (_isSending) const CustomLoader(message: 'جاري إسناد المهام...'),
              ],
            ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }
  
  Widget _buildProductsTab() {
    return Column(
      children: [
        // Worker selection, deadline, and search
        _buildSelectionHeader(),
        
        // Products grid
        Expanded(
          child: _filteredProducts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      const Text('لا توجد منتجات متاحة'),
                      if (_searchQuery.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('لا توجد نتائج لـ "$_searchQuery"'),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                          icon: const Icon(Icons.clear),
                          label: const Text('مسح البحث'),
                        ),
                      ]
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = _filteredProducts[index];
                    final isSelected = _selectedProducts.containsKey(product.id);
                    
                    return _buildProductCard(product, isSelected);
                  },
                ),
        ),
      ],
    );
  }
  
  Widget _buildOrdersTab() {
    return Column(
      children: [
        // Worker selection, deadline, and search
        _buildSelectionHeader(),
        
        // Orders list
        Expanded(
          child: _filteredOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      const Text('لا توجد طلبيات متاحة'),
                      if (_searchQuery.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('لا توجد نتائج لـ "$_searchQuery"'),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                          icon: const Icon(Icons.clear),
                          label: const Text('مسح البحث'),
                        ),
                      ]
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = _filteredOrders[index];
                    final isSelected = _selectedOrders.containsKey(order.id);
                    
                    return _buildOrderCard(order, isSelected);
                  },
                ),
        ),
      ],
    );
  }
  
  Widget _buildSelectionHeader() {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Worker selection
            const Text(
              'اختيار العامل:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<UserModel>(
              value: _selectedWorker,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                prefixIcon: const Icon(Icons.person),
              ),
              hint: const Text('اختر العامل'),
              isExpanded: true,
              items: _workers.map((worker) {
                return DropdownMenuItem<UserModel>(
                  value: worker,
                  child: Text(worker.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedWorker = value;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // Deadline selection
            const Text(
              'الموعد النهائي:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _deadlineController,
              readOnly: true,
              onTap: _selectDeadline,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                prefixIcon: const Icon(Icons.calendar_today),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.edit_calendar),
                  onPressed: _selectDeadline,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Search box
            TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'بحث...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Selection summary
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16),
                const SizedBox(width: 8),
                Text(
                  _tabController.index == 0
                      ? 'تم اختيار ${_selectedProducts.length} منتج'
                      : 'تم اختيار ${_selectedOrders.length} طلب',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProductCard(ProductModel product, bool isSelected) {
    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(
                color: Theme.of(context).primaryColor,
                width: 2,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _toggleProductSelection(product),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image
              Expanded(
                child: Center(
                  child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 40,
                                ),
                              );
                            },
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.inventory_2,
                            size: 40,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Product name
              Text(
                product.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 4),
              
              // Product code
              Text(
                'كود: ${product.sku}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
              
              // Quantity selector (only show when selected)
              if (isSelected) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'الكمية:',
                      style: TextStyle(fontSize: 12),
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          // Decrease button
                          InkWell(
                            onTap: () {
                              int currentQty = _selectedProducts[product.id]?['quantity'] ?? 1;
                              _updateQuantity(product.id, currentQty - 1);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.remove, size: 16),
                            ),
                          ),
                          
                          // Quantity display
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '${_selectedProducts[product.id]?['quantity'] ?? 1}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          
                          // Increase button
                          InkWell(
                            onTap: () {
                              int currentQty = _selectedProducts[product.id]?['quantity'] ?? 1;
                              _updateQuantity(product.id, currentQty + 1);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.add, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              
              // Selection indicator
              Align(
                alignment: Alignment.bottomRight,
                child: Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade400,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildOrderCard(OrderModel order, bool isSelected) {
    final itemCount = order.items?.length ?? 0;
    final formattedDate = DateFormat('yyyy-MM-dd').format(order.date);
    
    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(
                color: Theme.of(context).primaryColor,
                width: 2,
              )
            : BorderSide.none,
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _toggleOrderSelection(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order number and date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'طلب #${order.orderNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              
              // Customer info
              Row(
                children: [
                  const Icon(Icons.person, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'العميل: ${order.customerName}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 4),
              
              // Order details
              Row(
                children: [
                  const Icon(Icons.shopping_basket, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'عدد العناصر: $itemCount',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              
              const SizedBox(height: 4),
              
              // Total amount
              Row(
                children: [
                  const Icon(Icons.attach_money, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'المبلغ الإجمالي: ${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Order status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(order.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'الحالة: ${order.status}',
                  style: TextStyle(
                    color: _getStatusColor(order.status),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              // Selection indicator
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade400,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
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
      case 'ملغي':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'العامل:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedWorker?.name ?? 'لم يتم الاختيار',
                    style: TextStyle(
                      color: _selectedWorker == null ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'الموعد النهائي:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text(_deadlineController.text),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _tabController.index == 0 ? 'المنتجات:' : 'الطلبات:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text(
                  _tabController.index == 0
                      ? '${_selectedProducts.length}'
                      : '${_selectedOrders.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'إسناد المهام',
              icon: Icons.send,
              onPressed: _tabController.index == 0 ? _assignProductTasks : _assignOrderTasks,
              isLoading: _isSending,
              disabled: _selectedWorker == null || 
                       (_tabController.index == 0 ? _selectedProducts.isEmpty : _selectedOrders.isEmpty),
            ),
          ],
        ),
      ),
    );
  }
} 