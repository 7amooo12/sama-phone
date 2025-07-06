import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/product_model.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../models/task_model.dart';
import '../../providers/supabase_provider.dart';
import '../../services/stock_warehouse_api_service.dart';
import '../../services/task_service.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';
import '../../widgets/shared/custom_loader.dart';
import '../../widgets/shared/show_snackbar.dart';

/// Accountant Task Assignment Screen
/// Clones all functionality from Admin AssignTasksScreen with AccountantThemeConfig styling
class AccountantTaskAssignmentScreen extends StatefulWidget {
  const AccountantTaskAssignmentScreen({super.key});

  @override
  State<AccountantTaskAssignmentScreen> createState() => _AccountantTaskAssignmentScreenState();
}

class _AccountantTaskAssignmentScreenState extends State<AccountantTaskAssignmentScreen> 
    with SingleTickerProviderStateMixin {
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
  DateTime? _deadline;

  // Map to track selected products and their quantities
  final Map<String, Map<String, dynamic>> _selectedProducts = {};

  // Map to track selected orders
  final Map<String, OrderModel> _selectedOrders = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _deadline = DateTime.now().add(const Duration(days: 7)); // Default deadline
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load data in parallel
      final futures = await Future.wait([
        _loadProducts(),
        _loadOrders(),
        _loadWorkers(),
      ]);

      AppLogger.info('✅ All data loaded successfully');
    } catch (e) {
      AppLogger.error('❌ Error loading data: $e');
      if (mounted) {
        ShowSnackbar.show(context, 'حدث خطأ أثناء تحميل البيانات: $e', isError: true);
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _apiService.getProducts();
      setState(() {
        _products = products;
      });
      AppLogger.info('📦 Loaded ${products.length} products');
    } catch (e) {
      AppLogger.error('❌ Error loading products: $e');
      throw Exception('فشل في تحميل المنتجات');
    }
  }

  Future<void> _loadOrders() async {
    try {
      final orders = await _apiService.getOrders();
      setState(() {
        _orders = orders.where((order) => 
          order.status == 'pending' || order.status == 'confirmed'
        ).toList();
      });
      AppLogger.info('📋 Loaded ${_orders.length} pending orders');
    } catch (e) {
      AppLogger.error('❌ Error loading orders: $e');
      throw Exception('فشل في تحميل الطلبات');
    }
  }

  Future<void> _loadWorkers() async {
    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final workers = await supabaseProvider.getUsersByRole(UserRole.worker.value);
      
      // Filter approved workers
      final approvedWorkers = workers.where((worker) =>
        worker.isApproved ||
        worker.status == 'approved' ||
        worker.status == 'active'
      ).toList();

      setState(() {
        _workers = approvedWorkers;
      });
      AppLogger.info('👷 Loaded ${approvedWorkers.length} approved workers');
    } catch (e) {
      AppLogger.error('❌ Error loading workers: $e');
      throw Exception('فشل في تحميل العمال');
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
      AppLogger.info('🚀 Starting product task assignment process...');

      // Get current accountant info
      final accountant = Provider.of<SupabaseProvider>(context, listen: false).user;

      if (accountant == null) {
        throw Exception('لم يتم العثور على بيانات المحاسب');
      }

      // Create task for each selected product
      final List<TaskModel> tasks = [];

      for (final entry in _selectedProducts.entries) {
        final productId = entry.key;
        final productData = entry.value;
        final quantity = productData['quantity'] as int;

        final product = _products.firstWhere((p) => p.id == productId);

        // Format image URL
        String? formattedImageUrl;
        if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
          formattedImageUrl = product.imageUrl!.startsWith('http')
              ? product.imageUrl
              : 'https://your-supabase-url.supabase.co/storage/v1/object/public/product-images/${product.imageUrl}';
        }

        final task = TaskModel(
          id: _uuid.v4(),
          title: 'تصنيع ${product.name}',
          description: 'مطلوب تصنيع ${product.name} بكمية $quantity',
          status: 'pending',
          priority: 'medium',
          assignedTo: _selectedWorker!.id,
          dueDate: _deadline!,
          createdAt: DateTime.now(),
          attachments: [],
          category: 'production',
          quantity: quantity,
          completedQuantity: 0,
          adminName: accountant.name, // Using accountant name instead of admin
          productName: product.name,
          progress: 0.0,
          deadline: _deadline!,
          workerId: _selectedWorker!.id,
          workerName: _selectedWorker!.name,
          adminId: accountant.id,
          productId: product.id,
          productImage: formattedImageUrl,
          orderId: null,
        );

        tasks.add(task);
        AppLogger.info('📋 Created task: ${task.title} for product: ${product.name}');
      }

      AppLogger.info('💾 Sending ${tasks.length} tasks to database...');

      // Send tasks to Supabase
      final success = await _taskService.createMultipleTasks(tasks);

      if (!success) {
        throw Exception('فشل في إنشاء المهام في قاعدة البيانات');
      }

      AppLogger.info('✅ Tasks assigned successfully!');

      if (mounted) {
        ShowSnackbar.show(context, 'تم إسناد المهام بنجاح', isError: false);

        // Clear selections
        setState(() {
          _selectedProducts.clear();
        });
      }
    } catch (e) {
      AppLogger.error('❌ Error assigning product tasks: $e');
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
      // Get current accountant info
      final accountant = Provider.of<SupabaseProvider>(context, listen: false).user;

      if (accountant == null) {
        throw Exception('لم يتم العثور على بيانات المحاسب');
      }

      // Create task for each order
      final List<TaskModel> tasks = [];

      for (final order in _selectedOrders.values) {
        final itemCount = order.items.length ?? 0;

        final task = TaskModel(
          id: _uuid.v4(),
          title: 'معالجة الطلب #${order.orderNumber}',
          description: 'مطلوب معالجة طلب من العميل ${order.customerName} يحتوي على $itemCount عنصر',
          status: 'pending',
          priority: 'medium',
          assignedTo: _selectedWorker!.id,
          dueDate: _deadline!,
          createdAt: DateTime.now(),
          attachments: [],
          category: 'order_processing',
          quantity: itemCount,
          completedQuantity: 0,
          adminName: accountant.name, // Using accountant name
          productName: 'طلب متعدد المنتجات',
          progress: 0.0,
          deadline: _deadline!,
          workerId: _selectedWorker!.id,
          workerName: _selectedWorker!.name,
          adminId: accountant.id,
          productId: '', // No specific product
          productImage: null,
          orderId: order.id.toString(),
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

  void _showDeadlineDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardBackground1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        ),
        title: Text(
          'تحديد موعد التسليم',
          style: AccountantThemeConfig.headlineMedium,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'اختر الموعد النهائي لإنجاز المهام',
              style: AccountantThemeConfig.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.cardGradient,
                borderRadius: BorderRadius.circular(12),
                border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
              ),
              child: CalendarDatePicker(
                initialDate: _deadline ?? DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                onDateChanged: (date) {
                  setState(() {
                    _deadline = date;
                  });
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: AccountantThemeConfig.labelLarge.copyWith(
                color: AccountantThemeConfig.neutralColor,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: AccountantThemeConfig.primaryButtonStyle,
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  void _showAssignmentConfirmationDialog() {
    if (_selectedWorker == null) {
      ShowSnackbar.show(context, 'يرجى اختيار عامل أولاً', isError: true);
      return;
    }

    final isProductTab = _tabController.index == 0;
    final selectedCount = isProductTab ? _selectedProducts.length : _selectedOrders.length;

    if (selectedCount == 0) {
      ShowSnackbar.show(context,
        isProductTab ? 'يرجى اختيار منتج واحد على الأقل' : 'يرجى اختيار طلب واحد على الأقل',
        isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardBackground1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.greenGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.assignment_turned_in,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'تأكيد إسناد المهام',
                style: AccountantThemeConfig.headlineMedium,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.cardGradient,
                borderRadius: BorderRadius.circular(12),
                border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: AccountantThemeConfig.primaryGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'العامل المختار:',
                        style: AccountantThemeConfig.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedWorker!.name,
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      color: AccountantThemeConfig.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        isProductTab ? Icons.inventory_2 : Icons.assignment,
                        color: AccountantThemeConfig.accentBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isProductTab ? 'المنتجات المختارة:' : 'الطلبات المختارة:',
                        style: AccountantThemeConfig.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$selectedCount ${isProductTab ? "منتج" : "طلب"}',
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      color: AccountantThemeConfig.accentBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: AccountantThemeConfig.warningOrange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'موعد التسليم:',
                        style: AccountantThemeConfig.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AccountantThemeConfig.formatDate(_deadline ?? DateTime.now()),
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      color: AccountantThemeConfig.warningOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: AccountantThemeConfig.labelLarge.copyWith(
                color: AccountantThemeConfig.neutralColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.greenGradient,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    _tabController.index == 0
                        ? _assignProductTasks()
                        : _assignOrderTasks();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: Text(
                      'تأكيد الإسناد',
                      style: AccountantThemeConfig.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.greenGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
              ),
              child: const Icon(
                Icons.engineering,
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
                    'إسناد المهام',
                    style: AccountantThemeConfig.headlineMedium,
                  ),
                  Text(
                    'تكليف العمال بمهام الإنتاج والطلبيات',
                    style: AccountantThemeConfig.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.cardGradient,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              labelStyle: AccountantThemeConfig.labelLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              unselectedLabelStyle: AccountantThemeConfig.labelLarge.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.inventory_2_rounded, size: 22),
                  text: 'إسناد منتجات',
                ),
                Tab(
                  icon: Icon(Icons.assignment_rounded, size: 22),
                  text: 'إسناد طلبيات',
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: _isLoading
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
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildProductsTab() {
    return Column(
      children: [
        // Worker selection, deadline, and search
        _buildSelectionHeader(),

        // Products list
        Expanded(
          child: _buildProductsList(),
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
          child: _buildOrdersList(),
        ),
      ],
    );
  }

  Widget _buildSelectionHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Worker selection
          Text(
            'اختيار العامل',
            style: AccountantThemeConfig.headlineSmall,
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<UserModel>(
                value: _selectedWorker,
                hint: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'اختر عامل',
                    style: AccountantThemeConfig.bodyMedium,
                  ),
                ),
                isExpanded: true,
                dropdownColor: AccountantThemeConfig.cardBackground1,
                style: AccountantThemeConfig.bodyLarge,
                items: _workers.map((worker) {
                  return DropdownMenuItem<UserModel>(
                    value: worker,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AccountantThemeConfig.primaryGreen,
                            child: Text(
                              worker.name.isNotEmpty ? worker.name[0].toUpperCase() : 'ع',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              worker.name,
                              style: AccountantThemeConfig.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (UserModel? worker) {
                  setState(() {
                    _selectedWorker = worker;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Deadline and search row
          Row(
            children: [
              // Deadline button
              Expanded(
                child: GestureDetector(
                  onTap: _showDeadlineDialog,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AccountantThemeConfig.orangeGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.warningOrange),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'موعد التسليم',
                                style: AccountantThemeConfig.labelMedium.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                AccountantThemeConfig.formatDate(_deadline ?? DateTime.now()),
                                style: AccountantThemeConfig.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Search field
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    onChanged: _onSearchChanged,
                    style: AccountantThemeConfig.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'البحث...',
                      hintStyle: AccountantThemeConfig.bodySmall,
                      prefixIcon: Icon(
                        Icons.search,
                        color: AccountantThemeConfig.accentBlue,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    final filteredProducts = _products.where((product) {
      return _searchQuery.isEmpty ||
          product.name.toLowerCase().contains(_searchQuery) ||
          product.description.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'لا توجد منتجات متاحة' : 'لا توجد منتجات تطابق البحث',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        final isSelected = _selectedProducts.containsKey(product.id);
        final selectedQuantity = _selectedProducts[product.id]?['quantity'] ?? 1;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: isSelected
                ? AccountantThemeConfig.greenGradient
                : AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
            border: AccountantThemeConfig.glowBorder(
              isSelected ? AccountantThemeConfig.primaryGreen : AccountantThemeConfig.accentBlue
            ),
            boxShadow: isSelected
                ? AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen)
                : AccountantThemeConfig.cardShadows,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
            child: InkWell(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedProducts.remove(product.id);
                  } else {
                    _selectedProducts[product.id] = {
                      'quantity': 1,
                      'product': product,
                    };
                  }
                });
              },
              borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Product image
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                product.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.inventory_2,
                                    color: Colors.white.withValues(alpha: 0.7),
                                    size: 30,
                                  );
                                },
                              ),
                            )
                          : Icon(
                              Icons.inventory_2,
                              color: Colors.white.withValues(alpha: 0.7),
                              size: 30,
                            ),
                    ),

                    const SizedBox(width: 16),

                    // Product details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: AccountantThemeConfig.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.description,
                            style: AccountantThemeConfig.bodySmall.copyWith(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : Colors.white.withValues(alpha: 0.7),
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
                                  color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'السعر: ${AccountantThemeConfig.formatCurrency(product.price)}',
                                  style: AccountantThemeConfig.labelSmall.copyWith(
                                    color: isSelected ? Colors.white : AccountantThemeConfig.accentBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AccountantThemeConfig.warningOrange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'المخزون: ${product.stockQuantity}',
                                  style: AccountantThemeConfig.labelSmall.copyWith(
                                    color: isSelected ? Colors.white : AccountantThemeConfig.warningOrange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Selection indicator and quantity
                    Column(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AccountantThemeConfig.primaryGreen
                                  : Colors.white.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            isSelected ? Icons.check : Icons.add,
                            color: isSelected
                                ? AccountantThemeConfig.primaryGreen
                                : Colors.white.withValues(alpha: 0.7),
                            size: 20,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'الكمية: $selectedQuantity',
                              style: AccountantThemeConfig.labelSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrdersList() {
    final filteredOrders = _orders.where((order) {
      return _searchQuery.isEmpty ||
          order.orderNumber.toLowerCase().contains(_searchQuery) ||
          order.customerName.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 80,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'لا توجد طلبات متاحة' : 'لا توجد طلبات تطابق البحث',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
        final isSelected = _selectedOrders.containsKey(order.id.toString());
        final itemCount = order.items.length ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: isSelected
                ? AccountantThemeConfig.greenGradient
                : AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
            border: AccountantThemeConfig.glowBorder(
              isSelected ? AccountantThemeConfig.primaryGreen : AccountantThemeConfig.accentBlue
            ),
            boxShadow: isSelected
                ? AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen)
                : AccountantThemeConfig.cardShadows,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
            child: InkWell(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedOrders.remove(order.id.toString());
                  } else {
                    _selectedOrders[order.id.toString()] = order;
                  }
                });
              },
              borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Order icon
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [Colors.white.withValues(alpha: 0.3), Colors.white.withValues(alpha: 0.1)]
                              )
                            : AccountantThemeConfig.blueGradient,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.assignment,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Order details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'طلب #${order.orderNumber}',
                            style: AccountantThemeConfig.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'العميل: ${order.customerName}',
                            style: AccountantThemeConfig.bodyMedium.copyWith(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'العناصر: $itemCount',
                                  style: AccountantThemeConfig.labelSmall.copyWith(
                                    color: isSelected ? Colors.white : AccountantThemeConfig.accentBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AccountantThemeConfig.warningOrange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'المجموع: ${AccountantThemeConfig.formatCurrency(order.totalAmount)}',
                                  style: AccountantThemeConfig.labelSmall.copyWith(
                                    color: isSelected ? Colors.white : AccountantThemeConfig.warningOrange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(order.status).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getStatusText(order.status),
                              style: AccountantThemeConfig.labelSmall.copyWith(
                                color: isSelected ? Colors.white : _getStatusColor(order.status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Selection indicator
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AccountantThemeConfig.primaryGreen
                              : Colors.white.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        isSelected ? Icons.check : Icons.add,
                        color: isSelected
                            ? AccountantThemeConfig.primaryGreen
                            : Colors.white.withValues(alpha: 0.7),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AccountantThemeConfig.warningOrange;
      case 'confirmed':
        return AccountantThemeConfig.accentBlue;
      case 'completed':
        return AccountantThemeConfig.primaryGreen;
      case 'cancelled':
        return AccountantThemeConfig.dangerRed;
      default:
        return AccountantThemeConfig.neutralColor;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'معلق';
      case 'confirmed':
        return 'مؤكد';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  Widget _buildBottomBar() {
    final isProductTab = _tabController.index == 0;
    final selectedCount = isProductTab ? _selectedProducts.length : _selectedOrders.length;
    final hasSelection = selectedCount > 0;
    final hasWorker = _selectedWorker != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        border: Border(
          top: BorderSide(
            color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Selection info
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasWorker ? 'العامل: ${_selectedWorker!.name}' : 'لم يتم اختيار عامل',
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: hasWorker ? AccountantThemeConfig.primaryGreen : AccountantThemeConfig.neutralColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasSelection
                        ? 'تم اختيار $selectedCount ${isProductTab ? "منتج" : "طلب"}'
                        : 'لم يتم اختيار ${isProductTab ? "منتجات" : "طلبات"}',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: hasSelection ? AccountantThemeConfig.accentBlue : AccountantThemeConfig.neutralColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Assign button
            Container(
              height: 50,
              width: 120,
              decoration: BoxDecoration(
                gradient: hasSelection && hasWorker
                    ? AccountantThemeConfig.greenGradient
                    : LinearGradient(
                        colors: [
                          AccountantThemeConfig.neutralColor.withValues(alpha: 0.3),
                          AccountantThemeConfig.neutralColor.withValues(alpha: 0.5),
                        ],
                      ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasSelection && hasWorker
                      ? AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3)
                      : AccountantThemeConfig.neutralColor.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: hasSelection && hasWorker
                    ? AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen)
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: hasSelection && hasWorker ? _showAssignmentConfirmationDialog : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: Text(
                      'إسناد المهام',
                      style: AccountantThemeConfig.labelLarge.copyWith(
                        color: hasSelection && hasWorker ? Colors.white : AccountantThemeConfig.neutralColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
