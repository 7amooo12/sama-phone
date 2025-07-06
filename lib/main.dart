import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/config/supabase_config.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/providers/unified_auth_provider.dart';
import 'package:smartbiztracker_new/providers/app_settings_provider.dart';
import 'package:smartbiztracker_new/providers/pending_orders_provider.dart';
import 'package:smartbiztracker_new/providers/client_order_tracking_provider.dart';
import 'package:smartbiztracker_new/providers/home_provider.dart';
import 'package:smartbiztracker_new/providers/product_provider.dart';
import 'package:smartbiztracker_new/providers/simplified_product_provider.dart';
import 'package:smartbiztracker_new/providers/simplified_orders_provider.dart';
import 'package:smartbiztracker_new/providers/cart_provider.dart';
import 'package:smartbiztracker_new/providers/customer_cart_provider.dart';
import 'package:smartbiztracker_new/providers/favorites_provider.dart';
import 'package:smartbiztracker_new/providers/notification_provider.dart';
import 'package:smartbiztracker_new/providers/order_provider.dart';
import 'package:smartbiztracker_new/providers/client_orders_provider.dart';
import 'package:smartbiztracker_new/providers/worker_task_provider.dart';
import 'package:smartbiztracker_new/providers/worker_rewards_provider.dart';
import 'package:smartbiztracker_new/providers/attendance_provider.dart';
import 'package:smartbiztracker_new/providers/worker_attendance_provider.dart';
import 'package:smartbiztracker_new/providers/wallet_provider.dart';
import 'package:smartbiztracker_new/providers/electronic_payment_provider.dart';
import 'package:smartbiztracker_new/providers/electronic_wallet_provider.dart';
import 'package:smartbiztracker_new/providers/voucher_provider.dart';
import 'package:smartbiztracker_new/providers/voucher_cart_provider.dart';
import 'package:smartbiztracker_new/providers/distributors_provider.dart';
import 'package:smartbiztracker_new/providers/warehouse_provider.dart';
import 'package:smartbiztracker_new/providers/warehouse_products_provider.dart';
import 'package:smartbiztracker_new/providers/warehouse_dispatch_provider.dart';
import 'package:smartbiztracker_new/providers/pricing_approval_provider.dart';
import 'package:smartbiztracker_new/providers/treasury_provider.dart';
import 'package:smartbiztracker_new/providers/import_analysis_provider.dart';
import 'package:smartbiztracker_new/services/warehouse_cache_service.dart';
import 'package:smartbiztracker_new/services/warehouse_preloader_service.dart';
import 'package:smartbiztracker_new/screens/common/splash_screen.dart';
import 'package:smartbiztracker_new/utils/wallet_balance_sync.dart';
import 'package:smartbiztracker_new/services/connectivity_service.dart';
import 'package:smartbiztracker_new/services/local_storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/utils/theme_provider_new.dart';
import 'package:smartbiztracker_new/services/stockwarehouse_api.dart';
import 'package:smartbiztracker_new/services/samastock_api.dart';

import 'package:smartbiztracker_new/services/sama_analytics_service.dart';
import 'package:smartbiztracker_new/services/sama_store_service.dart';
import 'package:smartbiztracker_new/utils/app_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smartbiztracker_new/utils/global_ui_fixes.dart';
import 'package:smartbiztracker_new/services/supabase_service.dart';
import 'package:smartbiztracker_new/services/supabase_storage_service.dart';
import 'package:smartbiztracker_new/utils/tab_optimization_service.dart';
import 'package:smartbiztracker_new/services/auth_service.dart';
import 'package:smartbiztracker_new/services/database_service.dart';
import 'package:smartbiztracker_new/services/flask_api_service.dart';
import 'package:smartbiztracker_new/utils/migration_helper.dart';
import 'package:smartbiztracker_new/utils/admin_setup.dart';
import 'package:smartbiztracker_new/services/performance_monitor.dart';
import 'package:smartbiztracker_new/services/ui_overflow_prevention.dart';
import 'package:smartbiztracker_new/services/session_recovery_service.dart';
import 'package:smartbiztracker_new/services/auth_sync_service.dart';
import 'package:smartbiztracker_new/services/provider_initialization_service.dart';
import 'package:smartbiztracker_new/services/ui_performance_optimizer.dart';
import 'package:smartbiztracker_new/services/memory_optimizer.dart';
import 'package:smartbiztracker_new/services/database_performance_optimizer.dart';
import 'package:smartbiztracker_new/services/arabic_rtl_optimizer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // CRITICAL FIX: Initialize Supabase BEFORE creating providers to prevent hot reload crashes
  try {
    AppLogger.info('🔄 Initializing Supabase before provider creation...');
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      debug: kDebugMode,
    );
    AppLogger.info('✅ Supabase initialized successfully before providers');

    // Initialize enhanced warehouse cache service for better performance
    AppLogger.info('🚀 Initializing enhanced warehouse cache service...');
    await WarehouseCacheService.initialize();
    AppLogger.info('✅ Enhanced warehouse cache service initialized');

    // Start background preloading of warehouse data for better performance
    AppLogger.info('🚀 Starting background warehouse data preloading...');
    WarehousePreloaderService().startBackgroundPreloading();
    AppLogger.info('✅ Background warehouse preloading started');
  } catch (e) {
    AppLogger.error('❌ Failed to initialize Supabase or cache service: $e');
    // Continue anyway to prevent app crash, but providers may fail
  }

  // Set up enhanced global error handling for UI overflow
  UIOverflowPrevention.applyGlobalFixes();

  // Initialize performance monitoring and optimizations
  PerformanceMonitor();

  // Initialize comprehensive performance optimizations
  UIPerformanceOptimizer.applyGlobalOptimizations();
  MemoryOptimizer.initialize();
  DatabasePerformanceOptimizer.initialize();
  await ArabicRTLOptimizer.initialize();

  AppLogger.info('🚀 All performance optimizations initialized');

  // تعيين توجيه الشاشة للوضع الرأسي فقط
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // إعداد شريط الحالة بنمط شفاف
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: StyleSystem.backgroundDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  AppLogger.info('🚀 Starting app with pre-initialized Supabase...');

  // تشغيل التطبيق مع إعداد مزودي الحالة
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SupabaseProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider(
          authService: AuthService(),
          databaseService: DatabaseService(),
        )),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => SimplifiedProductProvider()),
        ChangeNotifierProvider(create: (_) => SimplifiedOrdersProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProxyProvider<SupabaseProvider, CustomerCartProvider>(
          create: (_) => CustomerCartProvider(),
          update: (_, supabaseProvider, cartProvider) {
            if (cartProvider != null) {
              // Update cart provider when user changes
              final currentUserId = supabaseProvider.user?.id;
              cartProvider.updateUser(currentUserId);
            }
            return cartProvider ?? CustomerCartProvider();
          },
        ),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (context) => NotificationProvider(Provider.of<SupabaseProvider>(context, listen: false))),
        ChangeNotifierProvider(create: (_) => OrderProvider(DatabaseService())),
        ChangeNotifierProvider(create: (_) => ClientOrdersProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProviderNew()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        // Add the missing providers for API services
        Provider<StockWarehouseApiService>(create: (_) => StockWarehouseApiService()),
        Provider<SamaStoreService>(create: (_) => SamaStoreService()),
        Provider<SamaAnalyticsService>(create: (_) => SamaAnalyticsService()),
        Provider<SamaStockApiService>(create: (_) => SamaStockApiService()),
        Provider<SupabaseService>(create: (_) => SupabaseService()),
        Provider<FlaskApiService>(create: (_) => FlaskApiService()),
        // Temporarily remove UnifiedAuthProvider to fix Provider exceptions
        // Will be re-added after fixing the Provider setup issues
        // Add app settings provider
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProvider(create: (_) => PendingOrdersProvider()),
        ChangeNotifierProvider(create: (_) => ClientOrderTrackingProvider()),
        // Worker system providers
        ChangeNotifierProvider(create: (_) => WorkerTaskProvider()),
        ChangeNotifierProvider(create: (_) => WorkerRewardsProvider()),
        // Attendance system providers
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => WorkerAttendanceProvider()),
        // Wallet system provider
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        // Treasury system provider
        ChangeNotifierProvider(create: (_) => TreasuryProvider()),
        // Electronic payment provider
        ChangeNotifierProvider(create: (_) => ElectronicPaymentProvider()),
        // Electronic wallet provider
        ChangeNotifierProvider(create: (_) => ElectronicWalletProvider()),
        // Voucher provider
        ChangeNotifierProvider(create: (_) => VoucherProvider()),
        // Voucher cart provider
        ChangeNotifierProvider(create: (_) => VoucherCartProvider()),
        // Distributors provider
        ChangeNotifierProvider(create: (_) => DistributorsProvider()),
        // Warehouse provider
        ChangeNotifierProvider(create: (_) => WarehouseProvider()),
        // Warehouse products provider
        ChangeNotifierProvider(create: (_) => WarehouseProductsProvider()),
        // Warehouse dispatch provider
        ChangeNotifierProvider(create: (_) => WarehouseDispatchProvider()),
        // Pricing approval provider
        ChangeNotifierProvider(create: (_) => PricingApprovalProvider()),
        // Import Analysis provider using ProxyProvider for proper dependency injection
        ChangeNotifierProxyProvider<SupabaseService, ImportAnalysisProvider>(
          create: (_) => ImportAnalysisProvider(supabaseService: SupabaseService()),
          update: (_, supabaseService, previous) {
            AppLogger.info('🔄 Updating ImportAnalysisProvider with SupabaseService');
            if (previous != null) {
              // Update existing provider with new service
              return previous;
            }
            // Create new provider with proper service
            AppLogger.info('✅ Creating new ImportAnalysisProvider with SupabaseService');
            return ImportAnalysisProvider(supabaseService: supabaseService);
          },
        ),
      ],
      child: const SAMAApp(),
    ),
  );
}

// Image cache configuration moved to InitializationService for better performance

class CustomScrollBehavior extends MaterialScrollBehavior {
  const CustomScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

class SAMAApp extends StatefulWidget {
  const SAMAApp({super.key});

  @override
  State<SAMAApp> createState() => _SAMAAppState();
}

class _SAMAAppState extends State<SAMAApp> {
  @override
  void initState() {
    super.initState();
    // Initialize wallet balance synchronization and provider connections after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Initialize wallet balance synchronization
        context.initializeWalletSync();

        // ===== PRICING APPROVAL WORKFLOW INITIALIZATION =====
        // Initialize provider connections for pricing approval workflow
        AppLogger.info('🔗 Initializing provider connections for pricing approval workflow...');
        try {
          ProviderInitializationService.initializeProviders(context);
          AppLogger.info('✅ Provider connections initialized successfully');
        } catch (e) {
          AppLogger.error('❌ Failed to initialize provider connections: $e');
        }

        // ===== IMPORT ANALYSIS PROVIDER VERIFICATION =====
        // Verify ImportAnalysisProvider is accessible
        AppLogger.info('🔍 Verifying ImportAnalysisProvider accessibility...');
        try {
          final importProvider = Provider.of<ImportAnalysisProvider>(context, listen: false);
          AppLogger.info('✅ ImportAnalysisProvider accessible in SAMAApp: ${importProvider.runtimeType}');
          AppLogger.info('   - Loading: ${importProvider.isLoading}');
          AppLogger.info('   - Processing: ${importProvider.isProcessing}');
          AppLogger.info('   - Status: ${importProvider.currentStatus}');
        } catch (e) {
          AppLogger.error('❌ ImportAnalysisProvider NOT accessible in SAMAApp: $e');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AppRoutes.navigatorKey,
      title: 'SAMA Store',
      debugShowCheckedModeBanner: false,
      theme: GlobalUIFixes.applyGlobalThemeFixes(StyleSystem.darkTheme), // Force dark theme
      darkTheme: GlobalUIFixes.applyGlobalThemeFixes(StyleSystem.darkTheme),
      themeMode: ThemeMode.dark, // Force dark mode permanently
      scrollBehavior: const CustomScrollBehavior(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', ''),
        Locale('en', ''),
      ],
      locale: const Locale('ar', ''),
      builder: (context, child) {
        // Add enhanced error boundary
        ErrorWidget.builder = UIOverflowPrevention.errorWidgetBuilder;

        // Add Directionality wrapper with UI fixes
        return Directionality(
          textDirection: TextDirection.rtl,
          child: GlobalUIFixes.fixOverflowIssues(
            ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                physics: const BouncingScrollPhysics(),
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                },
              ),
              child: child ?? const SizedBox(),
            ),
          ),
        );
      },
      initialRoute: AppRoutes.appInitialization,
      routes: AppRoutes.routes,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}

// صفحة البداية للتطوير والاختبار
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: StyleSystem.darkModeGradient,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: StyleSystem.glassDecoration(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'اختر الشاشة',
                        style: StyleSystem.headlineLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 30),

                      // SplashScreen
                      _buildScreenButton(
                        context,
                        title: 'شاشة البداية',
                        route: '/',
                        icon: Icons.home,
                        color: StyleSystem.primaryColor,
                      ),

                      const SizedBox(height: 16),

                      // SAMA Store Home Screen
                      _buildScreenButton(
                        context,
                        title: 'متجر SAMA',
                        route: '/sama-store',
                        icon: Icons.store,
                        color: Colors.deepPurple,
                      ),

                      const SizedBox(height: 16),

                      // WaitingApprovalScreen
                      _buildScreenButton(
                        context,
                        title: 'شاشة انتظار الموافقة',
                        route: '/dev/waiting-approval',
                        icon: Icons.hourglass_top,
                        color: StyleSystem.warningColor,
                      ),

                      const SizedBox(height: 16),

                      // AdminApprovalScreen
                      _buildScreenButton(
                        context,
                        title: 'شاشة موافقة المدير',
                        route: '/dev/admin-approval',
                        icon: Icons.admin_panel_settings,
                        color: StyleSystem.successColor,
                      ),

                      const SizedBox(height: 16),

                      // Register Screen
                      _buildScreenButton(
                        context,
                        title: 'شاشة التسجيل',
                        route: '/register',
                        icon: Icons.person_add,
                        color: StyleSystem.accentColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScreenButton(
    BuildContext context, {
    required String title,
    required String route,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () {
          if (route == '/') {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const SplashScreen()),
            );
          } else {
            Navigator.of(context).pushNamed(route);
          }
        },
      ),
    );
  }
}

class SimpleHomeScreen extends StatefulWidget {
  const SimpleHomeScreen({super.key});

  @override
  State<SimpleHomeScreen> createState() => _SimpleHomeScreenState();
}

class _SimpleHomeScreenState extends State<SimpleHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startAnimation() {
    _animationController.forward();
  }

  void _stopAnimation() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'نظام إدارة الأعمال',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(10),
                child: Image.asset(
                  'assets/icons/app_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),

              // App Name
              const Text(
                'تطبيق متعدد الأدوار',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 10),

              // App Description
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'نظام متكامل لإدارة الأعمال مع دعم لأدوار متعددة: المدير، العميل، العامل، وصاحب العمل',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF334155),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Message Model Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'تم إنشاء نموذج الرسائل بنجاح في lib/models/message_model.dart',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Role Cards
              const Text(
                'الأدوار المتاحة في النظام',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 20),

              _buildRoleCard(
                context,
                'المدير',
                'إدارة المستخدمين والتحليلات',
                Icons.admin_panel_settings,
                Colors.purple,
              ),
              const SizedBox(height: 16),

              _buildRoleCard(
                context,
                'العميل',
                'متابعة المنتجات والطلبات',
                Icons.person,
                Colors.blue,
              ),
              const SizedBox(height: 16),

              _buildRoleCard(
                context,
                'العامل',
                'إدارة الإنتاج والأخطاء',
                Icons.engineering,
                Colors.orange,
              ),
              const SizedBox(height: 16),

              _buildRoleCard(
                context,
                'صاحب العمل',
                'إدارة المنتجات والطلبات',
                Icons.business_center,
                Colors.green,
              ),
              const SizedBox(height: 40),

              // Features Section
              const Text(
                'ميزات التطبيق',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 20),

              // Features grid
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildFeatureItem(
                    'واجهة سهلة',
                    Icons.touch_app,
                    const Color(0xFF2563EB),
                  ),
                  _buildFeatureItem(
                    'رسوم متحركة جميلة',
                    Icons.animation,
                    const Color(0xFF6366F1),
                  ),
                  _buildFeatureItem(
                    'أدوار متعددة',
                    Icons.people,
                    const Color(0xFF0EA5E9),
                  ),
                  _buildFeatureItem(
                    'تقارير شاملة',
                    Icons.bar_chart,
                    const Color(0xFF16A34A),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return GestureDetector(
      onTapDown: (_) => _startAnimation(),
      onTapUp: (_) => _stopAnimation(),
      onTapCancel: () => _stopAnimation(),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم اختيار دور $title'),
            backgroundColor: color,
          ),
        );
      },
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 32,
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String title, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Removed test user creation functions for production



