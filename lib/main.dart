import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/config/supabase_config.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/providers/unified_auth_provider.dart';
import 'package:smartbiztracker_new/providers/home_provider.dart';
import 'package:smartbiztracker_new/providers/product_provider.dart';
import 'package:smartbiztracker_new/providers/cart_provider.dart';
import 'package:smartbiztracker_new/providers/favorites_provider.dart';
import 'package:smartbiztracker_new/providers/notification_provider.dart';
import 'package:smartbiztracker_new/providers/order_provider.dart';
import 'package:smartbiztracker_new/screens/auth/auth_wrapper.dart';
import 'package:smartbiztracker_new/screens/common/splash_screen.dart';
import 'package:smartbiztracker_new/services/connectivity_service.dart';
import 'package:smartbiztracker_new/services/local_storage_service.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/utils/logger.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/utils/animation_system.dart';
import 'package:smartbiztracker_new/utils/theme_provider_new.dart';
import 'package:smartbiztracker_new/widgets/offline_indicator.dart';
import 'package:smartbiztracker_new/screens/auth/waiting_approval_screen.dart';
import 'package:smartbiztracker_new/screens/admin/new_users_screen.dart';
import 'package:smartbiztracker_new/screens/welcome_screen.dart';
import 'package:smartbiztracker_new/services/stockwarehouse_api.dart';
import 'package:smartbiztracker_new/services/samastock_api.dart';
import 'package:smartbiztracker_new/services/sama_analytics_service.dart';
import 'package:smartbiztracker_new/utils/app_localizations.dart';
import 'package:smartbiztracker_new/services/analytics_service.dart';
import 'package:smartbiztracker_new/screens/transition_screen.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'utils/scroll_behavior.dart';
import 'package:smartbiztracker_new/models/user_role.dart';
import 'package:smartbiztracker_new/services/supabase_service.dart';
import 'package:smartbiztracker_new/screens/menu_screen.dart';
import 'package:smartbiztracker_new/utils/tab_optimization_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/database_service.dart';
import 'services/auth_service.dart';
import 'providers/task_provider.dart';
import 'services/notification_service.dart';
import 'screens/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    ),
  );
  
  // Apply memory and performance optimizations
  TabOptimizationService.applyMemoryOptimizations();
  
  // تهيئة Hive للتخزين المحلي
  final appDocumentDirectory = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDirectory.path);
  await Hive.openBox('app_settings');
  AppLogger.info('Hive initialized successfully');
  
  // تهيئة الخدمات
  final localStorageService = LocalStorageService();
  await localStorageService.init();
  
  // إعداد التخزين المؤقت للصور - enhanced for better performance
  PaintingBinding.instance.imageCache.maximumSizeBytes = 1024 * 1024 * 150; // 150 MB cache
  CachedNetworkImage.logLevel = CacheManagerLogLevel.warning; // تقليل مستوى السجلات
  
  // Enhanced image cache settings for better performance
  await _configureImageCache();

  try {
    // Load environment variables
    await dotenv.load(fileName: '.env');

    // Initialize Supabase
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
    AppLogger.info('Supabase initialized successfully');
    
    // Initialize notifications
    final notificationService = NotificationService();
    await notificationService.initialize();
    
    // Create test user only in debug mode
    if (kDebugMode) {
      try {
        final supabaseService = SupabaseService();
        // Try logging in with test account first
        try {
          final testUser = await supabaseService.signIn('test@example.com', 'password123');
          if (testUser != null) {
            AppLogger.info('Test admin user already exists');
          }
        } catch (e) {
          // If login failed, create the test user
          try {
            await supabaseService.signUp(
              email: 'test@example.com',
              password: 'password123',
              name: 'Test Admin',
              phone: '123456789',
              role: 'admin',
            );
            AppLogger.info('Test admin user created successfully');
            
            // Update the user's role and status directly
            final adminId = (await supabaseService.getUserData('test@example.com'))?.id;
            if (adminId != null) {
              await supabaseService.updateUserRoleAndStatus(
                adminId,
                'admin',
                'approved'
              );
              AppLogger.info('Test admin user approved');
            }
          } catch (signupError) {
            AppLogger.error('Error creating test user: $signupError');
          }
        }
      } catch (e) {
        AppLogger.error('Error in test user setup: $e');
      }
    }
  } catch (e) {
    AppLogger.error('Failed to initialize Supabase: $e');
    // Show error dialog after ensuring the widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: AppRoutes.navigatorKey.currentContext!,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          title: const Text('خطأ في الاتصال'),
          content: Text('فشل الاتصال بالخادم: ${e.toString()}'),
          actions: <Widget>[
            TextButton(
              child: const Text('حسناً'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    });
  }

  // تشغيل التطبيق مع إعداد مزودي الحالة
  runApp(
    MultiProvider(
      providers: [
        // Core services first
        Provider<StockWarehouseApiService>(
          create: (_) {
            final service = StockWarehouseApiService();
            service.initialize(); // Initialize the service
            return service;
          },
        ),
        Provider<SamaStockApiService>(create: (_) => SamaStockApiService()),
        Provider<SamaAnalyticsService>(create: (_) => SamaAnalyticsService()),
        
        // Database service
        Provider<DatabaseService>(
          create: (_) => DatabaseService(),
        ),
        
        // Auth providers
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        
        Provider<LocalStorageService>(
          create: (_) => localStorageService,
        ),
        
        // Auth provider
        ChangeNotifierProvider(
          create: (context) => AuthProvider(
            authService: context.read<AuthService>(),
            databaseService: context.read<DatabaseService>(),
          ),
        ),
        
        // Feature providers
        ChangeNotifierProvider(
          create: (context) => ProductProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => CartProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => FavoritesProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => NotificationProvider(
            databaseService: context.read<DatabaseService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => OrderProvider(
            databaseService: context.read<DatabaseService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => TaskProvider(
            databaseService: context.read<DatabaseService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => HomeProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProviderNew(),
        ),
        ChangeNotifierProvider(
          create: (_) => ConnectivityService(),
        ),
      ],
      child: const SAMAApp(),
    ),
  );
}

// Configure image cache to avoid white images and optimize memory
Future<void> _configureImageCache() async {
  // Increase cache capacity
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSizeBytes = 150 * 1024 * 1024; // 150 MB
  
  // Set image cache parameters for CachedNetworkImage
  CachedNetworkImage.logLevel = CacheManagerLogLevel.warning;
  
  // Configure HttpClient for better image loading
  HttpClient.enableTimelineLogging = false;
  
  if (!kIsWeb && Platform.isAndroid) {
    // Optimize Android image cache
    try {
      await MethodChannel('smartbiztracker/performance').invokeMethod('optimizeImageCache');
    } catch (e) {
      // Ignore if not available
    }
  }
}

class CustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

class SAMAApp extends StatelessWidget {
  const SAMAApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AppRoutes.navigatorKey,
      title: 'SAMA Store',
      debugShowCheckedModeBanner: false,
      theme: StyleSystem.lightTheme,
      darkTheme: StyleSystem.darkTheme,
      themeMode: Provider.of<ThemeProviderNew>(context).themeMode,
      scrollBehavior: CustomScrollBehavior(),
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
        // Add error boundary
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return Material(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.\n${details.exception}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        };

        // Add Directionality wrapper
        return Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
            child: ScrollConfiguration(
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
      initialRoute: AppRoutes.welcome,
      routes: AppRoutes.routes,
    );
  }
}

// صفحة البداية للتطوير والاختبار
class StartScreen extends StatelessWidget {
  const StartScreen({Key? key}) : super(key: key);

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
                      color: Colors.black.withOpacity(0.1),
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
                  color: const Color(0xFF2563EB).withOpacity(0.1),
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
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.3),
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
                    color: color.withOpacity(0.1),
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
            color: Colors.black.withOpacity(0.05),
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
              color: color.withOpacity(0.1),
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

