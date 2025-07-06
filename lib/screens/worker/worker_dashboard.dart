import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import '../../utils/ui_optimizations.dart';
import 'package:smartbiztracker_new/models/task_model.dart';
import 'package:smartbiztracker_new/services/database_service.dart';
import 'package:smartbiztracker_new/screens/worker/worker_tasks_screen.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;
  DateTime? _lastBackPressTime; // لتتبع آخر ضغطة على زر العودة

  // Track which tabs have been loaded
  final List<bool> _tabsLoaded = [true, false, false];

  final DatabaseService _databaseService = DatabaseService();
  List<TaskModel> _tasks = [];
  bool _isTasksLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = UIOptimizations.createOptimizedTabController(
      length: 3,
      vsync: this,
    );

    // Listen for tab changes to optimize lazy loading
    _tabController.addListener(_handleTabChange);

    // استدعاء البيانات الأولية
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only load data for the initial tab
      _loadTabData(_tabController.index);
      _loadTasks();
    });
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      final tabIndex = _tabController.index;
      if (!_tabsLoaded[tabIndex]) {
        // Mark this tab as loaded
        setState(() {
          _tabsLoaded[tabIndex] = true;
        });
        // Load data for this tab if needed
        _loadTabData(tabIndex);
      }
    }
  }

  void _loadTabData(int tabIndex) {
    // Implement specific data loading for each tab
    switch (tabIndex) {
      case 0:
        // Load overview data if needed
        break;
      case 1:
        // Load tasks data if needed
        break;
      case 2:
        // Load reports data if needed
        break;
    }
  }

  // Load tasks for the current worker
  Future<void> _loadTasks() async {
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final user = supabaseProvider.user;

    if (user != null) {
      _databaseService.getWorkerTasks(user.id).listen((tasks) {
        if (mounted) {
          setState(() {
            _tasks = tasks;
            _isTasksLoading = false;
          });
        }
      });
    }
  }

  // Update task progress
  Future<void> _updateTaskProgress(TaskModel task, double progress) async {
    try {
      final updatedTask = task.copyWith(
        progress: progress,
        status: progress >= 1.0 ? 'مكتملة' : 'قيد التنفيذ',
      );

      await _databaseService.updateTask(updatedTask);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث حالة المهمة بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحديث المهمة: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    // Cancel any ongoing operations to prevent "deactivated widget's ancestor" errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _tabController.removeListener(_handleTabChange);
        _tabController.dispose();
      }
    });
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    // Cache any inherited widgets to prevent unsafe lookups in dispose
    final theme = Theme.of(context);
    final supabaseProvider = Provider.of<SupabaseProvider>(context);
    super.didChangeDependencies();
  }

  // منطق التعامل مع زر العودة
  Future<bool> _onWillPop() async {
    // إذا كان مفتوح الدرج الجانبي، أغلقه عند الضغط على العودة بدلاً من إغلاق التطبيق
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
      return false;
    }

    // إذا كنا في شاشة غير الشاشة الرئيسية، عد إلى الشاشة الرئيسية بدلاً من إغلاق التطبيق
    if (_tabController.index != 0) {
      _tabController.animateTo(0);
      return false;
    }

    // في الشاشة الرئيسية، يتطلب ضغطتين متتاليتين خلال ثانيتين للخروج من التطبيق
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اضغط مرة أخرى للخروج من التطبيق'),
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supabaseProvider = Provider.of<SupabaseProvider>(context);
    final userModel = supabaseProvider.user;

    if (userModel == null) {
      // معالجة حالة عدم تسجيل الدخول
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: StyleSystem.scaffoldBackgroundColor,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: CustomAppBar(
            title: 'لوحة تحكم العامل',
            backgroundColor: StyleSystem.surfaceDark,
            leading: IconButton(
              icon: const Icon(Icons.menu, color: StyleSystem.textPrimary),
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
            ),
          ),
        ),
        drawer: MainDrawer(
          onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
          currentRoute: AppRoutes.workerDashboard,
        ),
        body: Column(
          children: [
            // شريط التبويب المحسن
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: StyleSystem.headerGradient,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: StyleSystem.primaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              child: UIOptimizations.createOptimizedTabBar(
                controller: _tabController,
                labelColor: StyleSystem.textPrimary,
                unselectedLabelColor: StyleSystem.textSecondary,
                indicatorColor: StyleSystem.primaryColor,
                indicatorWeight: 3,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.dashboard_outlined),
                    text: 'الرئيسية',
                  ),
                  Tab(
                    icon: Icon(Icons.task_alt),
                    text: 'مهامي',
                  ),
                  Tab(
                    icon: Icon(Icons.analytics_outlined),
                    text: 'التقارير',
                  ),
                ],
              ),
            ),
            // محتوى التبويب - use lazy loading for better performance
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const ClampingScrollPhysics(),
                children: [
                  // الشاشة الرئيسية
                  _buildOverviewTab(theme, userModel.name),

                  // شاشة المهام - using the dedicated tasks screen
                  _tabsLoaded[1]
                      ? const WorkerTasksScreen()
                      : const Center(child: CircularProgressIndicator()),

                  // شاشة التقارير - only build it when tab is selected
                  _tabsLoaded[2]
                      ? _buildReportsTab(theme)
                      : const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(ThemeData theme, String workerName) {
    // Implementation of the overview tab with worker's name
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: StyleSystem.backgroundGradient,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AnimationLimiter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 600),
              childAnimationBuilder: (widget) => SlideAnimation(
                horizontalOffset: 50.0,
                child: FadeInAnimation(
                  child: widget,
                ),
              ),
              children: [
                // Welcome card محسن
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: StyleSystem.headerGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: StyleSystem.elevatedCardShadow,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.person,
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
                                    'مرحباً، $workerName',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'نتمنى لك يوم عمل رائع!',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ملخص اليوم',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'التاريخ: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 12),
                              LinearPercentIndicator(
                                lineHeight: 12,
                                percent: 0.65,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                progressColor: Colors.white,
                                animation: true,
                                animationDuration: 1000,
                                barRadius: const Radius.circular(10),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'إنتاجية اليوم: 65%',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Today's tasks
                Text(
                  'مهام اليوم',
                  style: StyleSystem.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: StyleSystem.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTasksList(true),

                const SizedBox(height: 24),

                // Statistics
                Text(
                  'إحصائيات',
                  style: StyleSystem.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: StyleSystem.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'الإنتاجية الأسبوعية',
                        '78%',
                        Icons.trending_up,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'نسبة الأخطاء',
                        '5%',
                        Icons.error_outline,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'المهام المكتملة',
                        '23',
                        Icons.task_alt,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'العناصر المنتجة',
                        '156',
                        Icons.inventory_2,
                        Colors.purple,
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

  Widget _buildTasksTab(ThemeData theme) {
    // Implementation of tasks tab showing real tasks
    return _isTasksLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Task filter section
                Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تصفية المهام',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildFilterChip('الكل', true),
                            const SizedBox(width: 8),
                            _buildFilterChip('قيد التنفيذ', false),
                            const SizedBox(width: 8),
                            _buildFilterChip('مكتملة', false),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Tasks list heading
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'المهام المسندة إليك (${_tasks.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadTasks,
                      tooltip: 'تحديث',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Tasks list
                _tasks.isEmpty
                    ? _buildEmptyTasksPlaceholder()
                    : _buildProductTasksList(),
              ],
            ),
          );
  }

  Widget _buildEmptyTasksPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.engineering_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'لا توجد مهام مسندة إليك حالياً',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر هنا المهام التي يتم تكليفك بها',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTasksList() {
    return AnimationLimiter(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 500),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: _buildProductTaskCard(task),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductTaskCard(TaskModel task) {
    final theme = Theme.of(context);
    final progress = task.progress;
    final isCompleted = progress >= 1.0;

    // Format deadline to show day and time
    final deadlineDay = '${task.deadline.day}/${task.deadline.month}';
    final deadlineTime = '${task.deadline.hour}:${task.deadline.minute.toString().padLeft(2, '0')}';

    return Material(
      color: Colors.transparent,
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isCompleted
                ? Colors.green.withOpacity(0.5)
                : theme.primaryColor.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            // Header with product image
            Stack(
              children: [
                // Product image
                if (task.productImage != null && task.productImage!.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: Image.network(
                      task.productImage!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 150,
                          width: double.infinity,
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 50,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Icon(
                      Icons.inventory_2,
                      size: 50,
                      color: theme.primaryColor.withOpacity(0.5),
                    ),
                  ),

                // Status indicator overlay
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green
                          : task.status == 'قيد التنفيذ'
                              ? theme.primaryColor
                              : Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      task.status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

                // Quantity badge
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.production_quantity_limits,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${task.quantity}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Task details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task title
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Product name and deadline
                  Row(
                    children: [
                      const Icon(
                        Icons.inventory_2,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'المنتج: ${task.productName}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.schedule,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'الموعد: $deadlineDay - $deadlineTime',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Description
                  Text(
                    task.description,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Progress bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'التقدم: ${(progress * 100).toInt()}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isCompleted ? Colors.green : theme.primaryColor,
                            ),
                          ),
                          Text(
                            'تم الإنشاء: ${task.createdAt.day}/${task.createdAt.month}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearPercentIndicator(
                        lineHeight: 10,
                        percent: progress,
                        backgroundColor: Colors.grey.shade200,
                        progressColor: isCompleted ? Colors.green : theme.primaryColor,
                        animation: true,
                        animationDuration: 1000,
                        barRadius: const Radius.circular(10),
                      ),
                    ],
                  ),

                  // Button to update progress (only if not completed)
                  if (!isCompleted) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Start button (if pending)
                        if (task.status == 'قيد الانتظار')
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _updateTaskProgress(task, 0.1),
                              icon: const Icon(Icons.play_arrow, size: 18),
                              label: const Text('بدء المهمة'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),

                        // Progress update buttons (if in progress)
                        if (task.status == 'قيد التنفيذ') ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // Add 25% to current progress, cap at 1.0
                                final newProgress = (task.progress + 0.25).clamp(0.0, 1.0);
                                _updateTaskProgress(task, newProgress);
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('تقدم 25%'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _updateTaskProgress(task, 1.0),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('إكمال'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsTab(ThemeData theme) {
    // Implementation of reports tab
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period selector
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPeriodButton('اليوم', true),
                  _buildPeriodButton('الأسبوع', false),
                  _buildPeriodButton('الشهر', false),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Productivity chart
          const Text(
            'تقرير الإنتاجية',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'مخطط الإنتاجية',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Errors report
          const Text(
            'تقرير الأخطاء',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إجمالي الأخطاء',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                      const Text(
                        '3',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'نسبة الأخطاء',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                      const Text(
                        '5%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksList(bool isOverviewTab) {
    // If on overview tab, just show first 2 tasks from real data
    final tasksToShow = isOverviewTab
        ? _tasks.take(2).toList()
        : _tasks;

    if (_isTasksLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tasksToShow.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Icon(
              Icons.engineering_outlined,
              size: 40,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'لا توجد مهام ${isOverviewTab ? "لليوم" : "مسندة إليك"}',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return AnimationLimiter(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tasksToShow.length,
        itemBuilder: (context, index) {
          final task = tasksToShow[index];

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 500),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: isOverviewTab
                    ? _buildSimpleTaskCard(task)
                    : _buildProductTaskCard(task),
              ),
            ),
          );
        },
      ),
    );
  }

  // Simple card for overview tab
  Widget _buildSimpleTaskCard(TaskModel task) {
    final progress = task.progress;
    final isCompleted = progress >= 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: StyleSystem.cardGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? StyleSystem.completedColor.withOpacity(0.3)
              : StyleSystem.primaryColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: StyleSystem.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? Colors.green
                        : progress > 0
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  'الموعد النهائي: ${task.deadline.day}/${task.deadline.month} - ${task.deadline.hour}:${task.deadline.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  'الحالة: ${task.status}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearPercentIndicator(
              lineHeight: 8,
              percent: progress,
              backgroundColor: Colors.grey[300],
              progressColor: isCompleted ? Colors.green : Theme.of(context).primaryColor,
              animation: true,
              animationDuration: 1000,
              barRadius: const Radius.circular(10),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'التقدم: ${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: isCompleted ? Colors.green : Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!isCompleted)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // Navigate to tasks tab for details
                        _tabController.animateTo(1);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.visibility,
                              size: 16,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'عرض',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: StyleSystem.cardGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Implement filter
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
            border: Border.all(
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String label, bool isSelected) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Implement period selection
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveOrdersTab() {
    final theme = Theme.of(context);
    const hasOrders = false; // Set to false to show empty state until real data is available

    if (!hasOrders) {
      return _buildEmptyState(
        theme,
        'لا توجد طلبات نشطة',
        'ستظهر الطلبات المسندة إليك هنا',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: AnimationLimiter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 600),
            childAnimationBuilder: (widget) => SlideAnimation(
              horizontalOffset: 50.0,
              child: FadeInAnimation(
                child: widget,
              ),
            ),
            children: [
              // Section title
              Text(
                'الطلبات المسندة إليك',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Empty list - will be populated with real data
              ],
            ),
        ),
      ),
    );
  }

  Widget _buildCompletedOrdersTab() {
    final theme = Theme.of(context);
    const hasCompletedOrders = false; // Set to false to show empty state until real data is available

    if (!hasCompletedOrders) {
      return _buildEmptyState(
        theme,
        'لا توجد طلبات مكتملة',
        'ستظهر الطلبات المكتملة هنا',
      );
    }

    // Will be populated with real data
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 0,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.safeOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                ),
              ),
              title: Text(
                '',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    '',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // Show completed order details
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildPerformanceReportsTab() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Performance overview card
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'أداء العمل',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPerformanceMetric(
                        icon: Icons.check_circle,
                        title: 'المكتملة',
                        value: '0',
                        color: Colors.white,
                      ),
                      _buildPerformanceMetric(
                        icon: Icons.access_time,
                        title: 'المتوسط',
                        value: '0 ساعة',
                        color: Colors.white,
                      ),
                      _buildPerformanceMetric(
                        icon: Icons.star,
                        title: 'التقييم',
                        value: '0/5',
                        color: Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Monthly performance chart
          Text(
            'أداء الشهر الحالي',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // This would be replaced with the actual chart widget
                  Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.grey.safeOpacity(0.1),
                    child: const Center(
                      child: Text('رسم بياني للأداء الشهري'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatColumn(
                        title: 'إجمالي الطلبات',
                        value: '0',
                        color: theme.colorScheme.primary,
                      ),
                      _buildStatColumn(
                        title: 'معدل الإنتاج',
                        value: '0/اليوم',
                        color: theme.colorScheme.secondary,
                      ),
                      _buildStatColumn(
                        title: 'كفاءة الوقت',
                        value: '0%',
                        color: Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Improvement suggestions
          Text(
            'اقتراحات للتحسين',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSuggestionItem(
                    title: 'تحسين وقت الإنتاج',
                    description:
                        'يمكنك تقليل وقت الإنتاج بنسبة 15% من خلال تحسين عملية التجميع',
                    icon: Icons.speed,
                    iconColor: Colors.orange,
                    theme: theme,
                  ),
                  const Divider(),
                  _buildSuggestionItem(
                    title: 'تقليل الهدر',
                    description:
                        'حاول تقليل نسبة الهدر في المواد الخام من خلال تحسين استخدامها',
                    icon: Icons.eco,
                    iconColor: Colors.green,
                    theme: theme,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetric({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.safeOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color.safeOpacity(0.9),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: color.safeOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildStatColumn({
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color.safeOpacity(0.9),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.safeOpacity(0.4),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionItem({
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.safeOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.safeOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/empty_state.json',
              width: 150,
              height: 150,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.inbox,
                  size: 80,
                  color: theme.colorScheme.onSurface.safeOpacity(0.4),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.safeOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}


