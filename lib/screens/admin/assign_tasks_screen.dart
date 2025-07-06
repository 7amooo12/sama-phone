import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/models/task_model.dart';
import 'package:smartbiztracker_new/models/order_model.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/providers/product_provider.dart';
import 'package:smartbiztracker_new/services/stockwarehouse_api.dart';
import 'package:smartbiztracker_new/services/task_service.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/material_wrapper.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';
import 'package:smartbiztracker_new/utils/show_snackbar.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/utils/worker_rewards_debug.dart';
import 'package:smartbiztracker_new/models/user_role.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

class AssignTasksScreen extends StatefulWidget {
  const AssignTasksScreen({super.key});

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
      // Get products from ProductProvider (already loaded)
      final productProvider = Provider.of<ProductProvider>(context, listen: false);

      // Enable SAMA Admin API usage
      productProvider.setUseSamaAdmin(true);

      // If products not loaded yet, load them
      if (productProvider.samaAdminProducts.isEmpty) {
        await productProvider.loadSamaAdminProductsWithToJSON();
      }

      final products = productProvider.samaAdminProducts;

      // Load orders from API with error handling
      List<OrderModel> orders = [];
      try {
        orders = await _apiService.getOrders();
      } catch (orderError) {
        // Continue with empty orders list rather than failing completely
        orders = [];
      }

      // Load workers from Supabase (only approved users with worker role)
      List<UserModel> workers = [];
      try {
        final allWorkers = await Provider.of<SupabaseProvider>(context, listen: false)
            .getUsersByRole(UserRole.worker.value);
        // Filter only approved workers with more flexible status checking
        workers = allWorkers.where((worker) =>
          worker.isApproved ||
          worker.status == 'approved' ||
          worker.status == 'active'
        ).toList();
      } catch (workerError) {
        // Continue with empty workers list
        workers = [];
      }

      setState(() {
        _products = products;
        _orders = orders;
        _workers = workers;
        _isLoading = false;
      });

      // Data loading completed

    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      // Error handling without debug prints

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
      AppLogger.info('🚀 Starting product task assignment process...');

      // Get current admin info
      final admin = Provider.of<SupabaseProvider>(context, listen: false).user;

      if (admin == null) {
        throw Exception('لم يتم العثور على بيانات المدير');
      }

      AppLogger.info('👤 Admin info: ${admin.name} (${admin.id})');
      AppLogger.info('👷 Selected worker: ${_selectedWorker!.name} (${_selectedWorker!.id})');
      AppLogger.info('📦 Selected products: ${_selectedProducts.length}');

      // Create task for each product
      final List<TaskModel> tasks = [];

      for (final entry in _selectedProducts.entries) {
        final product = entry.value['product'] as ProductModel;
        final quantity = entry.value['quantity'] as int;

        // Get properly formatted image URL
        final formattedImageUrl = _getFormattedImageUrl(product);

        final task = TaskModel(
          id: _uuid.v4(),
          title: 'تصنيع ${product.name}',
          description: 'مطلوب تصنيع ${product.name} بكمية $quantity',
          status: 'pending',
          priority: 'medium',
          assignedTo: _selectedWorker!.id,
          dueDate: _deadline,
          createdAt: DateTime.now(),
          attachments: [],
          category: 'production',
          quantity: quantity,
          completedQuantity: 0,
          adminName: admin.name,
          productName: product.name,
          progress: 0.0,
          deadline: _deadline,
          workerId: _selectedWorker!.id,
          workerName: _selectedWorker!.name,
          adminId: admin.id,
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
      // Get current admin info
      final admin = Provider.of<SupabaseProvider>(context, listen: false).user;

      if (admin == null) {
        throw Exception('لم يتم العثور على بيانات المدير');
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
          dueDate: _deadline,
          createdAt: DateTime.now(),
          attachments: [],
          category: 'order_processing',
          quantity: itemCount,
          completedQuantity: 0,
          adminName: admin.name,
          productName: 'طلب متعدد المنتجات',
          progress: 0.0,
          deadline: _deadline,
          workerId: _selectedWorker!.id,
          workerName: _selectedWorker!.name,
          adminId: admin.id,
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

  // Helper method to get properly formatted image URL
  String? _getFormattedImageUrl(ProductModel product) {
    try {
      // First try the main imageUrl
      if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
        final imageUrl = product.imageUrl!;

        // If it's already a complete URL, return it
        if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
          AppLogger.info('Using complete image URL: $imageUrl');
          return imageUrl;
        }

        // If it's a relative path, construct the full URL
        if (imageUrl.isNotEmpty) {
          final fullUrl = 'https://samastock.pythonanywhere.com/static/uploads/$imageUrl';
          AppLogger.info('Constructed image URL: $fullUrl');
          return fullUrl;
        }
      }

      // Try the images array
      if (product.images.isNotEmpty) {
        final firstImage = product.images.first;
        if (firstImage.isNotEmpty) {
          if (firstImage.startsWith('http://') || firstImage.startsWith('https://')) {
            AppLogger.info('Using image from array: $firstImage');
            return firstImage;
          } else {
            final fullUrl = 'https://samastock.pythonanywhere.com/static/uploads/$firstImage';
            AppLogger.info('Constructed image URL from array: $fullUrl');
            return fullUrl;
          }
        }
      }

      AppLogger.warning('No valid image URL found for product: ${product.name}');
      return null;
    } catch (e) {
      AppLogger.error('Error formatting image URL for product ${product.name}: $e');
      return null;
    }
  }

  // Build product image with proper caching and error handling
  Widget _buildProductImage(ProductModel product) {
    final imageUrl = _getFormattedImageUrl(product);

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                StyleSystem.primaryColor.withValues(alpha: 0.1),
                StyleSystem.accentColor.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(StyleSystem.primaryColor),
                ),
              ),
              const SizedBox(height: 8),
              Icon(
                Icons.image_rounded,
                size: 32,
                color: StyleSystem.primaryColor.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
        errorWidget: (context, url, error) {
          AppLogger.error('Failed to load product image: $url - Error: $error');
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  StyleSystem.neutralLight,
                  StyleSystem.neutralMedium.withValues(alpha: 0.3),
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.image_not_supported_rounded,
                  size: 32,
                  color: StyleSystem.textSecondary,
                ),
                const SizedBox(height: 4),
                Text(
                  'فشل تحميل الصورة',
                  style: StyleSystem.labelSmall.copyWith(
                    color: StyleSystem.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              StyleSystem.primaryColor.withValues(alpha: 0.1),
              StyleSystem.accentColor.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_rounded,
              size: 48,
              color: StyleSystem.primaryColor,
            ),
            const SizedBox(height: 8),
            Text(
              'لا توجد صورة',
              style: StyleSystem.labelSmall.copyWith(
                color: StyleSystem.primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  StyleSystem.primaryColor.withValues(alpha: 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: StyleSystem.primaryColor.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: StyleSystem.elegantGradient,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.assignment_turned_in_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'تأكيد إسناد المهام',
                          style: StyleSystem.headlineSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Summary content
                      _buildSummaryContent(),

                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    StyleSystem.errorColor.withValues(alpha: 0.8),
                                    StyleSystem.errorColor,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: StyleSystem.errorColor.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  onTap: () => Navigator.of(context).pop(),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Center(
                                    child: Text(
                                      'إلغاء',
                                      style: StyleSystem.titleMedium.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: StyleSystem.headerGradient,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: StyleSystem.primaryColor.withValues(alpha: 0.3),
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
                                      style: StyleSystem.titleMedium.copyWith(
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryContent() {
    return Column(
      children: [
        // Worker info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                StyleSystem.primaryColor.withValues(alpha: 0.05),
                StyleSystem.accentColor.withValues(alpha: 0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: StyleSystem.primaryColor.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: StyleSystem.infoGradient,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'العامل:',
                style: StyleSystem.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: StyleSystem.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: StyleSystem.profitGradient),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _selectedWorker?.name ?? 'لم يتم الاختيار',
                    style: StyleSystem.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Deadline info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                StyleSystem.infoColor.withValues(alpha: 0.05),
                StyleSystem.infoColor.withValues(alpha: 0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: StyleSystem.infoColor.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: StyleSystem.warningGradient,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'الموعد النهائي:',
                style: StyleSystem.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: StyleSystem.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: StyleSystem.profitGradient),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _deadlineController.text,
                    style: StyleSystem.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Items count
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                StyleSystem.accentColor.withValues(alpha: 0.05),
                StyleSystem.primaryColor.withValues(alpha: 0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: StyleSystem.accentColor.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: StyleSystem.elegantGradient,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _tabController.index == 0 ? Icons.inventory_2_rounded : Icons.assignment_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _tabController.index == 0 ? 'المنتجات:' : 'الطلبات:',
                style: StyleSystem.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: StyleSystem.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: StyleSystem.profitGradient,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: StyleSystem.profitColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  _tabController.index == 0
                      ? '${_selectedProducts.length}'
                      : '${_selectedOrders.length}',
                  style: StyleSystem.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<ProductModel> get _filteredProducts {
    if (_searchQuery.isEmpty) {
      return _products;
    }

    return _products.where((product) {
      return product.name.toLowerCase().contains(_searchQuery) ||
             (product.description.toLowerCase().contains(_searchQuery) ?? false) ||
             (product.sku.toLowerCase().contains(_searchQuery) ?? false);
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
    final theme = Theme.of(context);

    return MaterialWrapper(
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: CustomAppBar(
          title: 'إسناد مهام للعمال',
          backgroundColor: StyleSystem.primaryColor,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.bug_report_rounded, color: Colors.white),
              onPressed: () async {
                _showDiagnosisDialog();
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: StyleSystem.headerGradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: StyleSystem.shadowSmall,
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
                labelStyle: StyleSystem.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                unselectedLabelStyle: StyleSystem.titleSmall.copyWith(
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
        body: _isLoading
          ? const CustomLoader(message: 'جاري تحميل البيانات...')
          : Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                  ),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Products tab
                      _buildProductsTab(),

                      // Orders tab
                      _buildOrdersTab(),
                    ],
                  ),
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
                      const Text(
                        'لا توجد منتجات متاحة',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      if (_searchQuery.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'لا توجد نتائج لـ "$_searchQuery"',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                          icon: const Icon(Icons.clear, color: Colors.white),
                          label: const Text('مسح البحث', style: TextStyle(color: Colors.white)),
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
                      const Text(
                        'لا توجد طلبيات متاحة',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      if (_searchQuery.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'لا توجد نتائج لـ "$_searchQuery"',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                          icon: const Icon(Icons.clear, color: Colors.white),
                          label: const Text('مسح البحث', style: TextStyle(color: Colors.white)),
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
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Collapsible Header with modern design
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 20),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: StyleSystem.elegantGradient,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: StyleSystem.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.settings_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              title: Text(
                'إعدادات المهمة',
                style: StyleSystem.headlineSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              iconColor: Colors.white,
              collapsedIconColor: Colors.white,
              children: [

                // Worker selection with modern design
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'اختيار العامل:',
                      style: StyleSystem.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: StyleSystem.shadowSmall,
                      ),
                      child: DropdownButtonFormField<UserModel>(
                        value: _selectedWorker,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.5)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.5)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: StyleSystem.primaryColor, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: StyleSystem.elegantGradient,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey[900],
                        ),
                        hint: Text(
                          'اختر العامل',
                          style: StyleSystem.bodyMedium.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        dropdownColor: Colors.grey[900],
                        style: const TextStyle(color: Colors.white),
                        isExpanded: true,
                        items: _workers.map((worker) {
                          return DropdownMenuItem<UserModel>(
                            value: worker,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        StyleSystem.primaryColor.withValues(alpha: 0.3),
                                        StyleSystem.primaryColor.withValues(alpha: 0.5),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    worker.name.isNotEmpty ? worker.name[0].toUpperCase() : 'ع',
                                    style: StyleSystem.labelMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    worker.name,
                                    style: StyleSystem.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedWorker = value;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Deadline selection with modern design
                    Text(
                      'الموعد النهائي:',
                      style: StyleSystem.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: StyleSystem.shadowSmall,
                      ),
                      child: TextField(
                        controller: _deadlineController,
                        readOnly: true,
                        onTap: _selectDeadline,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.5)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.5)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: StyleSystem.primaryColor, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: StyleSystem.infoGradient,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.calendar_today_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          suffixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: _selectDeadline,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: StyleSystem.primaryColor.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.edit_calendar_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey[900],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Search box with modern design
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: StyleSystem.shadowSmall,
                      ),
                      child: TextField(
                        onChanged: _onSearchChanged,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'بحث في المنتجات والطلبات...',
                          hintStyle: StyleSystem.bodyMedium.copyWith(
                            color: Colors.white70,
                          ),
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: StyleSystem.infoGradient,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.search_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.5)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.5)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: StyleSystem.primaryColor, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          filled: true,
                          fillColor: Colors.grey[900],
                          suffixIcon: _searchQuery.isNotEmpty
                              ? Container(
                                  margin: const EdgeInsets.all(8),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _searchQuery = '';
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: StyleSystem.errorColor.withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.clear_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Selection summary with modern design
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            StyleSystem.primaryColor.withValues(alpha: 0.2),
                            StyleSystem.accentColor.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: StyleSystem.primaryColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: StyleSystem.primaryColor.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: StyleSystem.infoGradient,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.info_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _tabController.index == 0
                                  ? 'تم اختيار ${_selectedProducts.length} منتج'
                                  : 'تم اختيار ${_selectedOrders.length} طلب',
                              style: StyleSystem.titleSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if ((_tabController.index == 0 && _selectedProducts.isNotEmpty) ||
                              (_tabController.index == 1 && _selectedOrders.isNotEmpty))
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: StyleSystem.profitGradient,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'جاهز للإسناد',
                                style: StyleSystem.labelSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(ProductModel product, bool isSelected) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.grey[800]
            : Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isSelected
              ? StyleSystem.primaryColor.withValues(alpha: 0.7)
              : Colors.grey.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _toggleProductSelection(product),
          borderRadius: BorderRadius.circular(20),
          splashColor: StyleSystem.primaryColor.withValues(alpha: 0.1),
          highlightColor: StyleSystem.primaryColor.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product image with modern design
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: StyleSystem.shadowSmall,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _buildProductImage(product),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Product name with modern typography
                Text(
                  product.name,
                  style: StyleSystem.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 6),

                // Product code with modern styling
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: StyleSystem.primaryColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'كود: ${product.sku ?? 'غير محدد'}',
                    style: StyleSystem.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // Quantity selector with modern design (only show when selected)
                if (isSelected) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          StyleSystem.primaryColor.withValues(alpha: 0.05),
                          StyleSystem.accentColor.withValues(alpha: 0.02),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: StyleSystem.primaryColor.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'الكمية:',
                          style: StyleSystem.labelMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: StyleSystem.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: StyleSystem.cardGradient,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: StyleSystem.primaryColor.withValues(alpha: 0.3),
                              width: 1,
                            ),
                            boxShadow: StyleSystem.shadowSmall,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Decrease button
                              Material(
                                color: Colors.transparent,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  bottomLeft: Radius.circular(12),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    final int currentQty = (_selectedProducts[product.id]?['quantity'] as int?) ?? 1;
                                    _updateQuantity(product.id, currentQty - 1);
                                  },
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.remove_rounded,
                                      size: 18,
                                      color: StyleSystem.primaryColor,
                                    ),
                                  ),
                                ),
                              ),

                              // Quantity display
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: StyleSystem.primaryColor.withValues(alpha: 0.1),
                                ),
                                child: Text(
                                  '${(_selectedProducts[product.id]?['quantity'] as int?) ?? 1}',
                                  style: StyleSystem.titleSmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: StyleSystem.primaryColor,
                                  ),
                                ),
                              ),

                              // Increase button
                              Material(
                                color: Colors.transparent,
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    final int currentQty = (_selectedProducts[product.id]?['quantity'] as int?) ?? 1;
                                    _updateQuantity(product.id, currentQty + 1);
                                  },
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                      color: StyleSystem.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // Selection indicator with modern design
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: StyleSystem.profitGradient,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'محدد',
                          style: StyleSystem.labelSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(colors: StyleSystem.profitGradient)
                            : LinearGradient(
                                colors: [
                                  StyleSystem.neutralMedium.withValues(alpha: 0.3),
                                  StyleSystem.neutralMedium.withValues(alpha: 0.1),
                                ],
                              ),
                        shape: BoxShape.circle,
                        boxShadow: isSelected ? StyleSystem.shadowSmall : null,
                      ),
                      child: Icon(
                        isSelected ? Icons.check_rounded : Icons.add_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order, bool isSelected) {
    final itemCount = order.items.length ?? 0;
    final formattedDate = DateFormat('yyyy-MM-dd').format(order.date);

    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Colors.grey[800] : Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(
                color: StyleSystem.primaryColor,
                width: 2,
              )
            : BorderSide(
                color: Colors.grey.withValues(alpha: 0.3),
                width: 1,
              ),
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
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      color: Colors.white70,
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
                  const Icon(Icons.person, size: 16, color: Colors.white70),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'العميل: ${order.customerName}',
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Order details
              Row(
                children: [
                  const Icon(Icons.shopping_basket, size: 16, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(
                    'عدد العناصر: $itemCount',
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Total amount
              Row(
                children: [
                  const Icon(Icons.attach_money, size: 16, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(
                    'المبلغ الإجمالي: ${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Order status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(order.status).withValues(alpha: 0.1),
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
                  color: isSelected ? StyleSystem.primaryColor : Colors.grey.shade400,
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
    final isValid = _selectedWorker != null &&
                   (_tabController.index == 0 ? _selectedProducts.isNotEmpty : _selectedOrders.isNotEmpty);

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: Colors.grey.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            height: 64,
            decoration: BoxDecoration(
              gradient: isValid
                  ? LinearGradient(
                      colors: StyleSystem.headerGradient,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : LinearGradient(
                      colors: [
                        StyleSystem.neutralMedium.withValues(alpha: 0.3),
                        StyleSystem.neutralMedium.withValues(alpha: 0.5),
                      ],
                    ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: isValid ? StyleSystem.elevatedCardShadow : null,
              border: Border.all(
                color: isValid
                    ? StyleSystem.primaryColor.withValues(alpha: 0.3)
                    : StyleSystem.neutralMedium.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: isValid && !_isSending
                    ? _showConfirmationDialog
                    : null,
                borderRadius: BorderRadius.circular(20),
                splashColor: Colors.white.withValues(alpha: 0.2),
                highlightColor: Colors.white.withValues(alpha: 0.1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Center(
                    child: _isSending
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'جاري الإسناد...',
                                style: StyleSystem.titleMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.send_rounded,
                                  color: isValid ? Colors.white : StyleSystem.neutralMedium,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'إسناد المهام',
                                style: StyleSystem.headlineSmall.copyWith(
                                  color: isValid ? Colors.white : StyleSystem.neutralMedium,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// عرض نافذة التشخيص
  Future<void> _showDiagnosisDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('جاري التشخيص...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('يتم فحص نظام المهام والمكافآت...'),
          ],
        ),
      ),
    );

    try {
      final diagnosis = await WorkerRewardsDebug.diagnoseRewardsSystem();

      if (!mounted) return;
      Navigator.of(context).pop(); // إغلاق نافذة التحميل

      // عرض نتائج التشخيص
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('نتائج التشخيص'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDiagnosisSection('الجداول', diagnosis['tables']),
                const SizedBox(height: 16),
                _buildDiagnosisSection('البيانات', diagnosis['data']),
                const SizedBox(height: 16),
                _buildDiagnosisSection('المستخدم الحالي', diagnosis['currentUser']),
                const SizedBox(height: 16),
                _buildDiagnosisSection('الاستعلامات', diagnosis['queries']),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final contextToUse = context;
                Navigator.of(contextToUse).pop();
                final success = await WorkerRewardsDebug.createTestData();
                if (mounted && contextToUse.mounted) {
                  ShowSnackbar.show(
                    contextToUse,
                    success ? 'تم إنشاء البيانات التجريبية' : 'فشل في إنشاء البيانات التجريبية',
                    isError: !success,
                  );
                  if (success) {
                    _loadData();
                  }
                }
              },
              child: const Text('إنشاء بيانات تجريبية'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // إغلاق نافذة التحميل

      ShowSnackbar.show(context, 'خطأ في التشخيص: $e', isError: true);
    }
  }

  Widget _buildDiagnosisSection(String title, dynamic data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            data.toString(),
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}