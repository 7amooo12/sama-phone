import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/models/order_model.dart';
import 'package:smartbiztracker_new/models/user_role.dart';
import 'package:smartbiztracker_new/screens/auth/auth_wrapper.dart';
import 'package:smartbiztracker_new/screens/auth/login_screen.dart';
import 'package:smartbiztracker_new/screens/auth/register_screen.dart';
import 'package:smartbiztracker_new/screens/auth/forgot_password_screen.dart';
import 'package:smartbiztracker_new/screens/auth/waiting_approval_screen.dart';
import 'package:smartbiztracker_new/screens/common/onboarding_screen.dart';
import 'package:smartbiztracker_new/screens/common/splash_screen.dart';
import 'package:smartbiztracker_new/screens/common/error_screen.dart';
import 'package:smartbiztracker_new/screens/admin/admin_dashboard.dart';
import 'package:smartbiztracker_new/screens/client/client_dashboard.dart';
import 'package:smartbiztracker_new/screens/worker/worker_dashboard.dart';
import 'package:smartbiztracker_new/screens/owner/owner_dashboard.dart';
import 'package:smartbiztracker_new/screens/common/notifications_screen.dart';
import 'package:smartbiztracker_new/screens/common/profile_screen.dart';
import 'package:smartbiztracker_new/screens/common/settings_screen.dart';
import 'package:smartbiztracker_new/screens/common/chat_list_screen.dart';
import 'package:smartbiztracker_new/screens/common/chat_detail_screen.dart';
import 'package:smartbiztracker_new/screens/common/cart_screen.dart';
import 'package:smartbiztracker_new/screens/common/favorites_screen.dart';
import 'package:smartbiztracker_new/screens/products_screen.dart';
import 'package:smartbiztracker_new/screens/admin/product_management_screen.dart';
import 'package:smartbiztracker_new/screens/admin/waste_screen.dart';
import 'package:smartbiztracker_new/screens/admin/productivity_screen.dart';
import 'package:smartbiztracker_new/screens/admin/user_management_screen.dart';
import 'package:smartbiztracker_new/screens/admin/analytics_screen.dart';
import 'package:smartbiztracker_new/screens/admin/new_users_screen.dart';
import 'package:smartbiztracker_new/screens/orders/orders_screen.dart' as admin_orders;
import 'package:smartbiztracker_new/screens/orders/order_details_screen.dart' as admin_order_details;
import 'package:smartbiztracker_new/screens/client/orders_screen.dart'
    as client;
import 'package:smartbiztracker_new/screens/client/returns_screen.dart'
    as client;
import 'package:smartbiztracker_new/screens/client/faults_screen.dart'
    as client;
import 'package:smartbiztracker_new/screens/client/products_screen.dart' as client;
import 'package:smartbiztracker_new/screens/worker/orders_screen.dart' as worker;
import 'package:smartbiztracker_new/screens/worker/faults_screen.dart' as worker;
import 'package:smartbiztracker_new/screens/owner/products_screen.dart' as owner;
import 'package:smartbiztracker_new/screens/owner/orders_screen.dart' as owner;
import 'package:smartbiztracker_new/screens/placeholders.dart';
import 'package:smartbiztracker_new/utils/page_transitions.dart';
import 'package:smartbiztracker_new/utils/animation_system.dart';
import 'package:smartbiztracker_new/screens/sama_store_home_screen.dart';
import 'package:smartbiztracker_new/screens/about_us_screen.dart';
import 'package:smartbiztracker_new/screens/welcome_screen.dart';
import 'package:smartbiztracker_new/screens/menu_screen.dart';
import 'package:smartbiztracker_new/screens/admin_products_page.dart';
import '../screens/products/client_product_screen.dart';
import '../screens/store/product_details_with_cart.dart';
import '../screens/client/client_orders_screen.dart';
import 'package:smartbiztracker_new/screens/feedback/customer_service_screen.dart';
import 'package:smartbiztracker_new/screens/accountant/accountant_dashboard.dart';
import 'package:smartbiztracker_new/screens/accountant/accountant_invoices_screen.dart';
import 'package:smartbiztracker_new/models/flask_invoice_model.dart';
import 'package:smartbiztracker_new/screens/admin/assign_tasks_screen.dart';
import '../screens/testing/todo_test_screen.dart';

// Add a global navigator key
final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

class AppRoutes {
  // Global navigator key for navigation without context
  static final GlobalKey<NavigatorState> navigatorKey = _navigatorKey;

  // Common Routes
  static const String initial = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String notifications = '/notifications';
  static const String chatList = '/chat';
  static const String chatDetail = '/chat/detail';
  static const String splash = '/splash';
  static const String welcome = '/welcome';
  static const String menu = '/menu';
  static const String onboarding = '/onboarding';
  static const String forgotPassword = '/forgot-password';
  static const String waitingApproval = '/waiting-approval';
  static const String cart = '/cart';
  static const String favorites = '/favorites';
  static const String samaStore = '/sama-store';
  static const String aboutUs = '/about-us';
  static const String customerService = '/customer-service';

  // Home routes based on role
  static const String home = '/home';
  static const String chat = '/chat';
  static const String products = '/products';
  static const String productDetails = '/product/details';
  static const String addProduct = '/product/add';
  static const String editProduct = '/product/edit';
  static const String orders = '/orders';
  static const String orderDetails = '/order/details';
  static const String createOrder = '/order/create';
  static const String faults = '/faults';
  static const String faultDetails = '/fault/details';
  static const String reportFault = '/fault/report';
  static const String waste = '/waste';
  static const String wasteDetails = '/waste/details';
  static const String reportWaste = '/waste/report';
  static const String returns = '/returns';
  static const String returnDetails = '/return/details';
  static const String createReturn = '/return/create';
  static const String productivity = '/productivity';
  static const String productivityDetails = '/productivity/details';
  static const String addProductivity = '/productivity/add';
  static const String approvalRequests = '/admin/approval-requests';

  // Admin Routes
  static const String adminDashboard = '/admin';
  static const String userManagement = '/admin/users';
  static const String analytics = '/admin/analytics';
  static const String productManagement = '/admin/products';
  static const String adminProductsView = '/admin/products-view';

  // Accountant Routes
  static const String accountantDashboard = '/accountant';
  static const String accountantOrders = '/accountant/orders';
  static const String accountantProducts = '/accountant/products';
  static const String accountantInvoices = '/accountant/invoices';
  static const String invoiceDetails = '/accountant/invoice/details';
  static const String createInvoice = '/accountant/invoice/create';
  static const String salesReports = '/accountant/sales-reports';
  static const String taxManagement = '/accountant/tax-management';

  // Client Routes
  static const String clientDashboard = '/client';
  static const String clientProducts = '/client/products';
  static const String clientOrders = '/client/orders';
  static const String clientReturns = '/client/returns';
  static const String clientFaults = '/client/faults';

  // Worker Routes
  static const String workerDashboard = '/worker';
  static const String workerOrders = '/worker/orders';
  static const String workerFaults = '/worker/faults';
  static const String workerProductivity = '/worker/productivity';

  // Owner Routes
  static const String ownerDashboard = '/owner';
  static const String ownerProducts = '/owner/products';
  static const String ownerWorkers = '/owner/workers';

  // Helper function to get dashboard route based on user role
  static String getDashboardRouteForRole(String role) {
    switch (role) {
      case 'admin':
        return '/admin/dashboard';
      case 'client':
        return '/client/dashboard';
      case 'worker':
        return '/worker/dashboard';
      case 'owner':
        return '/owner/dashboard';
      case 'accountant':
        return '/accountant/dashboard';
      default:
        return login;
    }
  }

  // Define routes map for MaterialApp
  static final Map<String, WidgetBuilder> routes = {
    initial: (_) => const WelcomeScreen(),
    splash: (_) => const SplashScreen(),
    welcome: (_) => const WelcomeScreen(),
    menu: (_) => const MenuScreen(),
    login: (_) => const LoginScreen(),
    register: (_) => const RegisterScreen(),
    profile: (_) => const ProfileScreen(),
    settings: (_) => const SettingsScreen(),
    notifications: (_) => const NotificationsScreen(),
    chatList: (_) => const ChatListScreen(),
    adminDashboard: (_) => const AdminDashboard(),
    '/admin/dashboard': (_) => const AdminDashboard(),
    clientDashboard: (_) => const ClientDashboard(),
    '/client/dashboard': (_) => const ClientDashboard(),
    workerDashboard: (_) => const WorkerDashboard(),
    '/worker/dashboard': (_) => const WorkerDashboard(),
    ownerDashboard: (_) => const OwnerDashboard(),
    '/owner/dashboard': (_) => const OwnerDashboard(),
    accountantDashboard: (_) => const AccountantDashboard(),
    '/accountant/dashboard': (_) => const AccountantDashboard(),
    onboarding: (_) => const OnboardingScreen(),
    waitingApproval: (_) => const WaitingApprovalScreen(),
    forgotPassword: (_) => const ForgotPasswordScreen(),
    cart: (_) => const CartScreen(),
    favorites: (_) => const FavoritesScreen(),
    samaStore: (_) => const SamaStoreHomeScreen(),
    aboutUs: (_) => const AboutUsScreen(),
    clientProducts: (_) => const ClientProductScreen(),
    clientOrders: (_) => const ClientOrdersScreen(),
    orders: (_) => const admin_orders.OrdersScreen(),
    customerService: (_) => const CustomerServiceScreen(),
    productManagement: (_) => const ProductManagementScreen(),
    accountantInvoices: (context) => AccountantInvoicesScreen.withProviders(),
    // Placeholder screens for new routes
    createInvoice: (_) => const PlaceholderScreen(title: 'إنشاء فاتورة جديدة'),
    salesReports: (_) => const PlaceholderScreen(title: 'تقارير المبيعات'),
    taxManagement: (_) => const PlaceholderScreen(title: 'إدارة الضرائب'),
    '/admin/assign-tasks': (context) => const AssignTasksScreen(),
    '/testing/supabase-todos': (context) => const TodoTestScreen(),
  };

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case initial:
      case welcome:
        return PageTransitions.fadeTransition(
          page: const WelcomeScreen(),
          settings: settings,
          duration: AnimationSystem.slow,
        );
      case splash:
        return PageTransitions.fadeTransition(
          page: const SplashScreen(),
          settings: settings,
          duration: AnimationSystem.slow,
        );
      case login:
        return PageTransitions.fadeScaleTransition(
          page: const LoginScreen(),
          settings: settings,
          duration: AnimationSystem.medium,
        );
      case register:
        return PageTransitions.slideRightToLeftTransition(
          page: const RegisterScreen(),
          settings: settings,
        );
      case home:
        // استخدام AuthWrapper بدلاً من SplashScreen للتوجيه الصحيح بناءً على حالة المستخدم
        return PageTransitions.fadeTransition(
          page: const AuthWrapper(),
          settings: settings,
        );
      case profile:
        return PageTransitions.fadeSlideTransition(
          page: const ProfileScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );
      case '/settings':
        return PageTransitions.fadeSlideTransition(
          page: const SettingsScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );
      case notifications:
        return PageTransitions.slideScaleTransition(
          page: const NotificationsScreen(),
          settings: settings,
          beginOffset: const Offset(0, -0.2),
        );
      case chatList:
        return PageTransitions.fadeSlideTransition(
          page: const ChatListScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );
      case chatDetail:
        final Map<String, dynamic> args = settings.arguments as Map<String, dynamic>;
        return PageTransitions.slideRightToLeftTransition(
          page: ChatDetailScreen(
            chatId: args['chatId'] as String,
            name: args['name'] as String,
            role: UserRole.fromString(args['role'] as String),
          ),
          settings: settings,
        );


      case products:
      case productManagement:
        return PageTransitions.fadeSlideTransition(
          page: const ProductManagementScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );
      case adminProductsView:
        return PageTransitions.fadeSlideTransition(
          page: const AdminProductsPage(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );
      case clientProducts:
        return PageTransitions.fadeSlideTransition(
          page: const client.ProductsScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );
      case productDetails:
        final int productId = settings.arguments as int;
        return PageTransitions.fadeScaleTransition(
          page: ProductDetailsScreen(productId: productId.toString()),
          settings: settings,
        );
      case addProduct:
        return PageTransitions.slideBottomToTopTransition(
          page: const AddProductScreen(),
          settings: settings,
        );
      case editProduct:
        final String productId = settings.arguments as String;
        return PageTransitions.slideBottomToTopTransition(
          page: EditProductScreen(productId: productId),
          settings: settings,
        );
      case orders:
        return PageTransitions.fadeSlideTransition(
          page: const admin_orders.OrdersScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );
      case orderDetails:
        final OrderModel order = settings.arguments as OrderModel;
        return PageTransitions.fadeScaleTransition(
          page: admin_order_details.OrderDetailsScreen(order: order),
          settings: settings,
        );
      case createOrder:
        return PageTransitions.slideBottomToTopTransition(
          page: const CreateOrderScreen(),
          settings: settings,
        );
      case faults:
      case clientFaults:
        return PageTransitions.fadeSlideTransition(
          page: const client.FaultsScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );
      case faultDetails:
        final String faultId = settings.arguments as String;
        return PageTransitions.fadeScaleTransition(
          page: FaultDetailsScreen(faultId: faultId),
          settings: settings,
        );
      case reportFault:
        return PageTransitions.slideBottomToTopTransition(
          page: const ReportFaultScreen(),
          settings: settings,
        );
      case waste:
        return PageTransitions.fadeSlideTransition(
          page: const WasteScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );
      case wasteDetails:
        final String wasteId = settings.arguments as String;
        return PageTransitions.fadeScaleTransition(
          page: WasteDetailsScreen(wasteId: wasteId),
          settings: settings,
        );
      case reportWaste:
        return PageTransitions.slideBottomToTopTransition(
          page: const ReportWasteScreen(),
          settings: settings,
        );
      case returns:
      case clientReturns:
        return PageTransitions.fadeSlideTransition(
          page: const client.ReturnsScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );
      case returnDetails:
        final String returnId = settings.arguments as String;
        return PageTransitions.fadeScaleTransition(
          page: ReturnDetailsScreen(returnId: returnId),
          settings: settings,
        );
      case createReturn:
        return PageTransitions.slideBottomToTopTransition(
          page: const CreateReturnScreen(),
          settings: settings,
        );
      case productivity:
      case workerProductivity:
        return PageTransitions.fadeSlideTransition(
          page: const ProductivityScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );
      case productivityDetails:
        final String productivityId = settings.arguments as String;
        return PageTransitions.fadeScaleTransition(
          page: ProductivityDetailsScreen(productivityId: productivityId),
          settings: settings,
        );
      case addProductivity:
        return PageTransitions.slideBottomToTopTransition(
          page: const AddProductivityScreen(),
          settings: settings,
        );

      // Worker specific routes
      case workerOrders:
        return PageTransitions.fadeSlideTransition(
          page: const worker.OrdersScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );
      case workerFaults:
        return PageTransitions.fadeSlideTransition(
          page: const worker.FaultsScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );

      // Admin specific routes
      case userManagement:
        return PageTransitions.fadeSlideTransition(
          page: const UserManagementScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );
      case analytics:
        return PageTransitions.fadeScaleTransition(
          page: const AnalyticsScreen(),
          settings: settings,
        );
      case approvalRequests:
        return PageTransitions.fadeSlideTransition(
          page: const NewUsersScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );
      case productManagement:
        return PageTransitions.fadeSlideTransition(
          page: const ProductManagementScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      // Owner specific routes
      case ownerProducts:
        return PageTransitions.fadeSlideTransition(
          page: const owner.ProductsScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );
      case ownerWorkers:
        return PageTransitions.fadeSlideTransition(
          page: const owner.OrdersScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );
      case samaStore:
        return PageTransitions.fadeScaleTransition(
          page: const SamaStoreHomeScreen(),
          settings: settings,
          duration: AnimationSystem.medium,
        );

      case aboutUs:
        return PageTransitions.fadeScaleTransition(
          page: const AboutUsScreen(),
          settings: settings,
          duration: AnimationSystem.medium,
        );

      case clientOrders:
        return PageTransitions.fadeSlideTransition(
          page: const client.OrdersScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );

      case customerService:
        final int initialTabIndex = settings.arguments != null ? (settings.arguments as Map<String, dynamic>)['initialTabIndex'] as int? ?? 0 : 0;
        return PageTransitions.fadeSlideTransition(
          page: CustomerServiceScreen(initialTabIndex: initialTabIndex),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case accountantDashboard:
        return MaterialPageRoute(builder: (_) => const AccountantDashboard());

      case accountantInvoices:
        return PageTransitions.fadeSlideTransition(
          page: AccountantInvoicesScreen.withProviders(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );
        
      case invoiceDetails:
        final FlaskInvoiceModel invoice = settings.arguments as FlaskInvoiceModel;
        return PageTransitions.fadeScaleTransition(
          page: PlaceholderScreen(title: 'تفاصيل الفاتورة #${invoice.id}'),
          settings: settings,
        );
        
      case createInvoice:
        return PageTransitions.slideBottomToTopTransition(
          page: const PlaceholderScreen(title: 'إنشاء فاتورة جديدة'),
          settings: settings,
        );
        
      case salesReports:
        return PageTransitions.fadeScaleTransition(
          page: const PlaceholderScreen(title: 'تقارير المبيعات'),
          settings: settings,
        );
        
      case taxManagement:
        return PageTransitions.fadeScaleTransition(
          page: const PlaceholderScreen(title: 'إدارة الضرائب'),
          settings: settings,
        );

      default:
        return PageTransitions.fadeTransition(
          page: ErrorScreen(
            message: 'Page not found: ${settings.name}',
            actionText: 'العودة إلى الصفحة الرئيسية',
          ),
          settings: settings,
        );
    }
  }
}
