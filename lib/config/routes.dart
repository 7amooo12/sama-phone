import 'dart:io';
import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/order_model.dart';
import 'package:smartbiztracker_new/models/user_role.dart';
import 'package:smartbiztracker_new/screens/auth/auth_wrapper.dart';
import 'package:smartbiztracker_new/screens/auth/login_screen.dart';
import 'package:smartbiztracker_new/screens/auth/register_screen.dart';
import 'package:smartbiztracker_new/screens/auth/forgot_password_screen.dart';
import 'package:smartbiztracker_new/screens/auth/waiting_approval_screen.dart';
import 'package:smartbiztracker_new/screens/common/onboarding_screen.dart';
import 'package:smartbiztracker_new/screens/common/splash_screen.dart';
import 'package:smartbiztracker_new/screens/common/sama_splash_screen.dart';
import 'package:smartbiztracker_new/screens/common/app_initialization_wrapper.dart';
import 'package:smartbiztracker_new/screens/common/error_screen.dart';
import 'package:smartbiztracker_new/screens/admin/admin_dashboard.dart';
import 'package:smartbiztracker_new/screens/client/client_dashboard.dart';
import 'package:smartbiztracker_new/screens/worker/worker_dashboard_screen.dart';
import 'package:smartbiztracker_new/screens/worker/worker_assigned_tasks_screen.dart';
import 'package:smartbiztracker_new/screens/worker/worker_completed_tasks_screen.dart';
import 'package:smartbiztracker_new/screens/worker/worker_rewards_screen.dart';
import 'package:smartbiztracker_new/screens/worker/worker_check_in_screen.dart';
import 'package:smartbiztracker_new/screens/worker/worker_check_out_screen.dart';
import 'package:smartbiztracker_new/screens/worker/worker_attendance_summary_screen.dart';
import 'package:smartbiztracker_new/screens/owner/owner_dashboard.dart';
import 'package:smartbiztracker_new/screens/common/notifications_screen.dart';
import 'package:smartbiztracker_new/screens/common/profile_screen.dart';
import 'package:smartbiztracker_new/screens/common/settings_screen.dart';
import 'package:smartbiztracker_new/screens/common/chat_list_screen.dart';
import 'package:smartbiztracker_new/screens/common/chat_detail_screen.dart';
import 'package:smartbiztracker_new/screens/common/favorites_screen.dart';
import 'package:smartbiztracker_new/screens/admin/product_management_screen.dart';
import 'package:smartbiztracker_new/screens/admin/waste_screen.dart';
import 'package:smartbiztracker_new/screens/admin/productivity_screen.dart';
import 'package:smartbiztracker_new/screens/admin/user_management_screen.dart';
import 'package:smartbiztracker_new/screens/admin/analytics_screen.dart';
import 'package:smartbiztracker_new/screens/admin/new_users_screen.dart';
import 'package:smartbiztracker_new/screens/admin/app_settings_screen.dart';
import 'package:smartbiztracker_new/screens/shared/pending_orders_screen.dart';
import 'package:smartbiztracker_new/screens/admin/admin_rewards_management_screen.dart';
import 'package:smartbiztracker_new/screens/admin/admin_task_review_screen.dart';
import 'package:smartbiztracker_new/screens/attendance/worker_attendance_reports_wrapper.dart';
import 'package:smartbiztracker_new/screens/orders/orders_screen.dart' as admin_orders;
import 'package:smartbiztracker_new/screens/orders/order_details_screen.dart' as admin_order_details;
import 'package:smartbiztracker_new/screens/client/orders_screen.dart'
    as client;
import 'package:smartbiztracker_new/screens/client/returns_screen.dart'
    as client;
import 'package:smartbiztracker_new/screens/client/faults_screen.dart'
    as client;
import 'package:smartbiztracker_new/screens/client/products_screen.dart' as client;
// import 'package:smartbiztracker_new/screens/worker/orders_screen.dart' as worker;
// import 'package:smartbiztracker_new/screens/worker/faults_screen.dart' as worker;
import 'package:smartbiztracker_new/screens/owner/products_screen.dart' as owner;
import 'package:smartbiztracker_new/screens/owner/orders_screen.dart' as owner;
import 'package:smartbiztracker_new/screens/placeholders.dart';
import 'package:smartbiztracker_new/utils/page_transitions.dart';
import 'package:smartbiztracker_new/utils/animation_system.dart';
// Removed unused import: sama_store_home_screen.dart (legacy file removed)
import 'package:smartbiztracker_new/screens/sama_store_rebuilt_screen.dart';
import 'package:smartbiztracker_new/screens/about_us_screen.dart';
import 'package:smartbiztracker_new/screens/welcome_screen.dart';
import 'package:smartbiztracker_new/screens/menu_screen.dart';
import 'package:smartbiztracker_new/screens/admin_products_page.dart';

import '../screens/client/client_orders_screen.dart';
import 'package:smartbiztracker_new/screens/feedback/customer_service_screen.dart';
import 'package:smartbiztracker_new/screens/customer/customer_requests_screen.dart';
import 'package:smartbiztracker_new/screens/accountant/accountant_dashboard.dart';
import 'package:smartbiztracker_new/screens/accountant/accountant_invoices_screen.dart';
import 'package:smartbiztracker_new/screens/accountant/accountant_order_details_screen.dart';
import 'package:smartbiztracker_new/screens/accountant/standalone_accountant_products_screen.dart';
import 'package:smartbiztracker_new/screens/accountant/standalone_accountant_invoices_screen.dart';
import 'package:smartbiztracker_new/screens/warehouse/warehouse_manager_dashboard.dart';
import 'package:smartbiztracker_new/screens/warehouse/warehouse_orders_screen.dart';
import 'package:smartbiztracker_new/screens/shared/warehouse_release_orders_screen.dart';
import 'package:smartbiztracker_new/screens/treasury/treasury_management_screen.dart';
import 'package:smartbiztracker_new/screens/manufacturing/manufacturing_tools_screen.dart';
import 'package:smartbiztracker_new/screens/manufacturing/add_tool_screen.dart';
import 'package:smartbiztracker_new/screens/manufacturing/tool_detail_screen.dart';
import 'package:smartbiztracker_new/screens/manufacturing/production_screen.dart';
import 'package:smartbiztracker_new/screens/manufacturing/start_production_screen.dart';
import 'package:smartbiztracker_new/screens/accountant/create_invoice_screen.dart';
import 'package:smartbiztracker_new/screens/admin/pending_invoices_screen.dart';
import '../screens/shared/store_invoices_screen.dart';
import 'package:smartbiztracker_new/models/flask_invoice_model.dart';
import 'package:smartbiztracker_new/models/client_order_model.dart';
import 'package:smartbiztracker_new/screens/admin/assign_tasks_screen.dart';
import 'package:smartbiztracker_new/screens/business_owner/create_purchase_invoice_screen.dart';
import 'package:smartbiztracker_new/screens/business_owner/purchase_invoices_screen.dart';
import 'package:smartbiztracker_new/screens/business_owner/business_owner_store_invoices_screen.dart';
import 'package:smartbiztracker_new/screens/admin/distributors_screen.dart';

import 'package:smartbiztracker_new/screens/client/customer_products_screen.dart';
import 'package:smartbiztracker_new/screens/client/customer_cart_screen.dart';
import 'package:smartbiztracker_new/screens/client/cart_screen.dart' as client_cart;
import 'package:smartbiztracker_new/screens/client/shopping_cart_screen.dart';
import 'package:smartbiztracker_new/screens/client/checkout_screen.dart';
import 'package:smartbiztracker_new/screens/client/order_success_screen.dart';
import 'package:smartbiztracker_new/screens/client/order_tracking_screen.dart';
import 'package:smartbiztracker_new/screens/client/track_latest_order_screen.dart';
import 'package:smartbiztracker_new/screens/admin/admin_orders_screen.dart';
import 'package:smartbiztracker_new/screens/client/ar_screen.dart';
import 'package:smartbiztracker_new/screens/client/ar_product_selection_screen.dart';
import 'package:smartbiztracker_new/screens/shared/product_movement_screen.dart';
import 'package:smartbiztracker_new/screens/shared/advanced_product_movement_screen.dart';
import 'package:smartbiztracker_new/screens/shared/qr_scanner_screen.dart';
import 'package:smartbiztracker_new/screens/shared/quick_access_screen.dart';
import 'package:smartbiztracker_new/screens/debug/user_loading_debug_screen.dart';
import 'package:smartbiztracker_new/screens/debug/wallet_payment_integration_debug_screen.dart';
import 'package:smartbiztracker_new/screens/debug/voucher_null_safety_debug_screen.dart';
import 'package:smartbiztracker_new/screens/debug/voucher_assignment_debug_screen.dart';
import 'package:smartbiztracker_new/screens/debug/order_workflow_debug_screen.dart';

import 'package:smartbiztracker_new/screens/client/enhanced_products_browser.dart';
import 'package:smartbiztracker_new/screens/client/enhanced_voucher_products_screen.dart';
import 'package:smartbiztracker_new/screens/client/voucher_cart_screen.dart';
import 'package:smartbiztracker_new/screens/client/voucher_checkout_screen.dart';
import 'package:smartbiztracker_new/models/voucher_model.dart';
import 'package:smartbiztracker_new/models/client_voucher_model.dart';
import 'package:smartbiztracker_new/screens/admin/wallet_management_screen.dart';
import 'package:smartbiztracker_new/screens/common/wallet_view_screen.dart';
import 'package:smartbiztracker_new/screens/client/payment_method_selection_screen.dart';
import 'package:smartbiztracker_new/screens/client/payment_account_selection_screen.dart';
import 'package:smartbiztracker_new/screens/client/payment_form_screen.dart';
import 'package:smartbiztracker_new/screens/client/enhanced_payment_workflow_screen.dart';
import 'package:smartbiztracker_new/screens/admin/electronic_payment_management_screen.dart';
import 'package:smartbiztracker_new/models/electronic_payment_model.dart';
import 'package:smartbiztracker_new/models/payment_account_model.dart';
import 'package:smartbiztracker_new/screens/accountant/wallet_transactions_screen.dart';
import 'package:smartbiztracker_new/screens/admin/wallet_sync_utility_screen.dart';

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
  static const String samaSplash = '/sama-splash';
  static const String appInitialization = '/app-initialization';
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
  static const String userLoadingDebug = '/debug/user-loading';
  static const String walletPaymentIntegrationDebug = '/debug/wallet-payment-integration';
  static const String voucherNullSafetyDebug = '/debug/voucher-null-safety';
  static const String voucherAssignmentDebug = '/debug/voucher-assignment';
  static const String orderWorkflowDebug = '/debug/order-workflow';
  static const String invoiceDetailsTest = '/debug/invoice-details-test';

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
  static const String appSettings = '/admin/app-settings';
  static const String pendingOrders = '/admin/pending-orders';
  static const String adminRewardsManagement = '/admin/rewards';
  static const String adminTaskReview = '/admin/task-review';
  static const String assignTasks = '/admin/assign-tasks';
  static const String distributors = '/admin/distributors';

  // Accountant Routes
  static const String accountantDashboard = '/accountant';
  static const String accountantOrders = '/accountant/orders';
  static const String accountantPendingOrders = '/accountant/pending-orders';
  static const String accountantOrderDetails = '/accountant/orders/details';
  static const String accountantProducts = '/accountant/products';
  static const String accountantInvoices = '/accountant/invoices';
  static const String invoiceDetails = '/accountant/invoice/details';
  static const String createInvoice = '/accountant/invoice/create';
  static const String pendingInvoices = '/admin/pending-invoices';
  static const String storeInvoices = '/shared/store-invoices';
  static const String salesReports = '/accountant/sales-reports';
  static const String taxManagement = '/accountant/tax-management';

  // Client Routes
  static const String clientDashboard = '/client';
  static const String clientProducts = '/client/products';
  static const String clientProductsShop = '/client/products/shop';
  static const String clientProductsBrowser = '/client/products/browser';
  static const String clientCart = '/client/cart';
  static const String customerCart = '/customer/cart';
  static const String clientCheckout = '/client/checkout';
  static const String clientOrderSuccess = '/client/order/success';
  static const String clientOrderTracking = '/client/order/tracking';
  static const String clientTracking = '/client/tracking';
  static const String clientTrackLatestOrder = '/client/track-latest-order';
  static const String clientOrders = '/client/orders';
  static const String clientReturns = '/client/returns';
  static const String clientFaults = '/client/faults';
  static const String customerRequests = '/customer/requests';
  static const String clientAR = '/client/ar';
  static const String clientARProductSelection = '/client/ar/products';

  // Voucher Cart Routes
  static const String voucherCart = '/voucher-cart';
  static const String voucherCheckout = '/voucher-checkout';
  static const String enhancedVoucherProducts = '/enhanced-voucher-products';

  // Shared Routes
  static const String productMovement = '/shared/product-movement';
  static const String advancedProductMovement = '/shared/advanced-product-movement';
  static const String qrScanner = '/shared/qr-scanner';
  static const String quickAccess = '/shared/quick-access';

  // Wallet System Routes
  static const String walletManagement = '/admin/wallet-management';
  static const String accountantWalletManagement = '/accountant/wallet-management';
  static const String walletView = '/wallet/view';
  static const String userWallet = '/user/wallet';

  // Electronic Payment Routes
  static const String paymentMethodSelection = '/payment/method-selection';
  static const String paymentAccountSelection = '/payment/account-selection';
  static const String paymentForm = '/payment/form';
  static const String enhancedPaymentWorkflow = '/payment/enhanced-workflow';
  static const String electronicPaymentManagement = '/admin/electronic-payments';
  static const String accountantElectronicPaymentManagement = '/accountant/electronic-payments';
  static const String paymentSettings = '/admin/payment-settings';
  static const String walletTransactions = '/accountant/wallet-transactions';
  static const String walletSyncUtility = '/admin/wallet-sync-utility';

  // Admin Order Management
  static const String adminOrders = '/admin/orders';
  static const String adminOrderDetails = '/admin/order/details';

  // Worker Routes
  static const String workerDashboard = '/worker';
  static const String workerTasks = '/worker/tasks';
  static const String workerRewards = '/worker/rewards';
  static const String workerOrders = '/worker/orders';
  static const String workerFaults = '/worker/faults';
  static const String workerProductivity = '/worker/productivity';
  static const String workerAssignedTasks = '/worker/assigned-tasks';
  static const String workerCompletedTasks = '/worker/completed-tasks';
  static const String workerCheckIn = '/worker/check-in';
  static const String workerCheckOut = '/worker/check-out';
  static const String workerAttendanceSummary = '/worker/attendance-summary';

  // Owner Routes
  static const String ownerDashboard = '/owner';
  static const String ownerProducts = '/owner/products';
  static const String ownerWorkers = '/owner/workers';

  // Business Owner Purchase Invoice Routes
  static const String createPurchaseInvoice = '/business-owner/create-purchase-invoice';
  static const String purchaseInvoices = '/business-owner/purchase-invoices';
  static const String businessOwnerStoreInvoices = '/business-owner/store-invoices';

  // Warehouse Manager Routes
  static const String warehouseManagerDashboard = '/warehouse-manager';
  static const String warehouseDashboard = '/warehouse/dashboard';
  static const String warehouseReleaseOrders = '/warehouse/release-orders';
  static const String accountantWarehouseReleaseOrders = '/accountant/warehouse-release-orders';
  static const String warehouseManagement = '/warehouse/management';
  static const String warehouseProducts = '/warehouse/products';
  static const String warehouseOrders = '/warehouse/orders';

  // Worker Attendance Routes
  static const String workerAttendanceReports = '/worker-attendance-reports';

  // Treasury Management Routes
  static const String treasuryManagement = '/treasury-management';
  static const String accountantTreasuryManagement = '/accountant/treasury-management';

  // Manufacturing Tools Routes
  static const String manufacturingTools = '/manufacturing-tools';
  static const String addManufacturingTool = '/manufacturing-tools/add';
  static const String manufacturingToolDetail = '/manufacturing-tools/detail';
  static const String productionScreen = '/production';
  static const String startProduction = '/production/start';

  // Helper function to get dashboard route based on user role
  static String getDashboardRouteForRole(String role) {
    switch (role) {
      case 'admin':
        return adminDashboard;
      case 'client':
        return clientDashboard;
      case 'worker':
        return workerDashboard;
      case 'owner':
        return ownerDashboard;
      case 'accountant':
        return accountantDashboard;
      case 'warehouseManager':
      case 'warehouse_manager':
        return warehouseManagerDashboard; // SECURITY FIX: Use correct route constant
      default:
        return login;
    }
  }

  // Define routes map for MaterialApp
  static final Map<String, WidgetBuilder> routes = {
    initial: (_) => const SamaSplashScreen(),
    splash: (_) => const SplashScreen(),
    samaSplash: (_) => const SamaSplashScreen(),
    appInitialization: (_) => const AppInitializationWrapper(),
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
    workerDashboard: (_) => const WorkerDashboardScreen(),
    '/worker/dashboard': (_) => const WorkerDashboardScreen(),
    ownerDashboard: (_) => const OwnerDashboard(),
    '/owner/dashboard': (_) => const OwnerDashboard(),
    accountantDashboard: (_) => const AccountantDashboard(),
    '/accountant/dashboard': (_) => const AccountantDashboard(),
    warehouseManagerDashboard: (_) => const WarehouseManagerDashboard(),
    warehouseDashboard: (_) => const WarehouseManagerDashboard(),
    warehouseReleaseOrders: (_) => const WarehouseReleaseOrdersScreen(userRole: 'warehouseManager'),
    accountantWarehouseReleaseOrders: (_) => const WarehouseReleaseOrdersScreen(userRole: 'accountant'),
    warehouseManagement: (_) => const WarehouseManagerDashboard(),
    warehouseProducts: (_) => const WarehouseManagerDashboard(),
    warehouseOrders: (_) => const WarehouseOrdersScreen(),
    onboarding: (_) => const OnboardingScreen(),
    waitingApproval: (_) => const WaitingApprovalScreen(),
    forgotPassword: (_) => const ForgotPasswordScreen(),
    cart: (_) => const ShoppingCartScreen(),
    customerCart: (_) => const CustomerCartScreen(),
    favorites: (_) => const FavoritesScreen(),
    samaStore: (_) => const SamaStoreRebuiltScreen(),
    aboutUs: (_) => const AboutUsScreen(),
    clientProducts: (context) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      return CustomerProductsScreen(voucherContext: args);
    },
    clientProductsShop: (context) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      return CustomerProductsScreen(voucherContext: args);
    },
    clientProductsBrowser: (_) => const EnhancedProductsBrowser(),
    clientTrackLatestOrder: (_) => const TrackLatestOrderScreen(),
    clientOrders: (_) => const ClientOrdersScreen(),
    adminOrders: (_) => const AdminOrdersScreen(),
    orders: (_) => const admin_orders.OrdersScreen(),
    customerService: (_) => const CustomerServiceScreen(),
    customerRequests: (_) => const CustomerRequestsScreen(),
    productManagement: (_) => const ProductManagementScreen(),
    userManagement: (_) => const UserManagementScreen(),
    analytics: (_) => const AnalyticsScreen(),
    approvalRequests: (_) => const NewUsersScreen(),
    appSettings: (_) => const AppSettingsScreen(),
    pendingOrders: (_) => const PendingOrdersScreen(),
    adminRewardsManagement: (_) => const AdminRewardsManagementScreen(),
    adminTaskReview: (_) => const AdminTaskReviewScreen(),
    waste: (_) => const WasteScreen(),
    accountantOrders: (_) => const admin_orders.OrdersScreen(),
    accountantPendingOrders: (_) => const PendingOrdersScreen(),
    accountantProducts: (_) => const StandaloneAccountantProductsScreen(),
    accountantInvoices: (_) => const StandaloneAccountantInvoicesScreen(),
    storeInvoices: (context) => const StoreInvoicesScreen(),
    // Placeholder screens for new routes
    salesReports: (_) => const PlaceholderScreen(title: 'تقارير المبيعات'),
    taxManagement: (_) => const PlaceholderScreen(title: 'إدارة الضرائب'),
    '/admin/assign-tasks': (context) => const AssignTasksScreen(),
    distributors: (_) => const DistributorsScreen(),
    workerAttendanceReports: (context) => const WorkerAttendanceReportsWrapper(userRole: 'admin'),
    clientAR: (_) => const ARScreen(),

    // Treasury Management Routes
    treasuryManagement: (_) => const TreasuryManagementScreen(),
    accountantTreasuryManagement: (_) => const TreasuryManagementScreen(),

    // Manufacturing Tools Routes
    manufacturingTools: (_) => const ManufacturingToolsScreen(),
    addManufacturingTool: (_) => const AddToolScreen(),
    productionScreen: (_) => const ProductionScreen(),
    // clientARProductSelection handled in generateRoute due to required arguments
    voucherCart: (_) => const VoucherCartScreen(),
    // voucherCheckout handled in generateRoute due to required arguments
    // enhancedVoucherProducts handled in generateRoute due to required arguments
    productMovement: (_) => const ProductMovementScreen(),
    advancedProductMovement: (_) => const AdvancedProductMovementScreen(),
    qrScanner: (_) => const QRScannerScreen(),
    userLoadingDebug: (_) => const UserLoadingDebugScreen(),
    walletPaymentIntegrationDebug: (_) => const WalletPaymentIntegrationDebugScreen(),
    voucherNullSafetyDebug: (_) => const VoucherNullSafetyDebugScreen(),
    voucherAssignmentDebug: (_) => const VoucherAssignmentDebugScreen(),
    orderWorkflowDebug: (_) => const OrderWorkflowDebugScreen(),


    // Wallet System Routes
    walletManagement: (_) => const WalletManagementScreen(),
    accountantWalletManagement: (_) => const WalletManagementScreen(),
    walletView: (_) => const WalletViewScreen(),
    userWallet: (_) => const WalletViewScreen(),

    // Electronic Payment Routes
    paymentMethodSelection: (_) => const PaymentMethodSelectionScreen(),
    paymentAccountSelection: (_) => const PaymentAccountSelectionScreen(),
    paymentForm: (_) => const PaymentFormScreen(),
    electronicPaymentManagement: (_) => const ElectronicPaymentManagementScreen(),
    accountantElectronicPaymentManagement: (_) => const ElectronicPaymentManagementScreen(),

    // Business Owner Purchase Invoice Routes
    createPurchaseInvoice: (_) => const CreatePurchaseInvoiceScreen(),
    purchaseInvoices: (_) => const PurchaseInvoicesScreen(),
    businessOwnerStoreInvoices: (_) => const BusinessOwnerStoreInvoicesScreen(),

    // Worker Attendance Routes
    workerCheckIn: (_) => const WorkerCheckInScreen(),
    workerCheckOut: (_) => const WorkerCheckOutScreen(),
    workerAttendanceSummary: (_) => const WorkerAttendanceSummaryScreen(),
  };

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case initial:
      case samaSplash:
        return PageTransitions.fadeTransition(
          page: const SamaSplashScreen(),
          settings: settings,
          duration: AnimationSystem.slow,
        );
      case appInitialization:
        return PageTransitions.fadeTransition(
          page: const AppInitializationWrapper(),
          settings: settings,
          duration: AnimationSystem.slow,
        );
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
      case AppRoutes.settings:
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
      case workerTasks:
        return PageTransitions.fadeSlideTransition(
          page: const WorkerAssignedTasksScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );
      case workerRewards:
        return PageTransitions.fadeSlideTransition(
          page: const WorkerRewardsScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );
      case workerAssignedTasks:
        return PageTransitions.fadeSlideTransition(
          page: const WorkerAssignedTasksScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );
      case workerCompletedTasks:
        return PageTransitions.fadeSlideTransition(
          page: const WorkerCompletedTasksScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );
      case workerOrders:
        return PageTransitions.fadeSlideTransition(
          page: const admin_orders.OrdersScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );
      case workerFaults:
        return PageTransitions.fadeSlideTransition(
          page: const PlaceholderScreen(title: 'أعطال العامل'),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );
      case workerCheckIn:
        return PageTransitions.fadeSlideTransition(
          page: const WorkerCheckInScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );
      case workerCheckOut:
        return PageTransitions.fadeSlideTransition(
          page: const WorkerCheckOutScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      // Admin specific routes
      case userManagement:
        return PageTransitions.fadeSlideTransition(
          page: const UserManagementScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );
      case analytics:
        return PageTransitions.fadeSlideTransition(
          page: const AnalyticsScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );
      case approvalRequests:
        return PageTransitions.fadeSlideTransition(
          page: const NewUsersScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );
      case appSettings:
        return PageTransitions.fadeSlideTransition(
          page: const AppSettingsScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );
      case pendingOrders:
        return PageTransitions.fadeSlideTransition(
          page: const PendingOrdersScreen(),
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

      // Business Owner Purchase Invoice Routes
      case createPurchaseInvoice:
        return PageTransitions.slideBottomToTopTransition(
          page: const CreatePurchaseInvoiceScreen(),
          settings: settings,
        );

      case purchaseInvoices:
        return PageTransitions.fadeSlideTransition(
          page: const PurchaseInvoicesScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );

      case businessOwnerStoreInvoices:
        return PageTransitions.fadeSlideTransition(
          page: const BusinessOwnerStoreInvoicesScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );
      case samaStore:
        return PageTransitions.fadeScaleTransition(
          page: const SamaStoreRebuiltScreen(),
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

      case clientProductsShop:
        final Map<String, dynamic>? args = settings.arguments as Map<String, dynamic>?;
        return PageTransitions.fadeSlideTransition(
          page: CustomerProductsScreen(voucherContext: args),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );

      case clientProductsBrowser:
        return PageTransitions.fadeSlideTransition(
          page: const EnhancedProductsBrowser(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );

      case clientCart:
        return PageTransitions.slideBottomToTopTransition(
          page: const client_cart.CartScreen(),
          settings: settings,
        );

      case clientCheckout:
        return PageTransitions.slideBottomToTopTransition(
          page: const CheckoutScreen(),
          settings: settings,
        );

      case clientOrderSuccess:
        final String orderId = settings.arguments as String;
        return PageTransitions.fadeScaleTransition(
          page: OrderSuccessScreen(orderId: orderId),
          settings: settings,
        );

      case clientOrderTracking:
        final String? orderId = settings.arguments as String?;
        return PageTransitions.fadeSlideTransition(
          page: OrderTrackingScreen(orderId: orderId),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );

      case clientTracking:
        return PageTransitions.fadeSlideTransition(
          page: const OrderTrackingScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );

      case clientTrackLatestOrder:
        return PageTransitions.fadeSlideTransition(
          page: const TrackLatestOrderScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );

      case adminOrders:
        return PageTransitions.fadeSlideTransition(
          page: const AdminOrdersScreen(),
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

      case customerRequests:
        return PageTransitions.fadeSlideTransition(
          page: const CustomerRequestsScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      // Dashboard routes
      case adminDashboard:
      case '/admin/dashboard':
        return PageTransitions.fadeSlideTransition(
          page: const AdminDashboard(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case clientDashboard:
      case '/client/dashboard':
        return PageTransitions.fadeSlideTransition(
          page: const ClientDashboard(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case workerDashboard:
      case '/worker/dashboard':
        return PageTransitions.fadeSlideTransition(
          page: const WorkerDashboardScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case ownerDashboard:
      case '/owner/dashboard':
        return PageTransitions.fadeSlideTransition(
          page: const OwnerDashboard(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case accountantDashboard:
        return MaterialPageRoute(builder: (_) => const AccountantDashboard());

      case accountantOrders:
        return PageTransitions.fadeSlideTransition(
          page: const admin_orders.OrdersScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );

      case accountantPendingOrders:
        return PageTransitions.fadeSlideTransition(
          page: const PendingOrdersScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case accountantProducts:
        return PageTransitions.fadeSlideTransition(
          page: const StandaloneAccountantProductsScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );

      case warehouseManagerDashboard:
        return PageTransitions.fadeSlideTransition(
          page: const WarehouseManagerDashboard(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case warehouseDashboard:
        return PageTransitions.fadeSlideTransition(
          page: const WarehouseManagerDashboard(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case warehouseOrders:
        return PageTransitions.fadeSlideTransition(
          page: const WarehouseOrdersScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case warehouseReleaseOrders:
        return PageTransitions.fadeSlideTransition(
          page: const WarehouseReleaseOrdersScreen(userRole: 'warehouseManager'),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case accountantWarehouseReleaseOrders:
        return PageTransitions.fadeSlideTransition(
          page: const WarehouseReleaseOrdersScreen(userRole: 'accountant'),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case warehouseManagement:
        return PageTransitions.fadeSlideTransition(
          page: const WarehouseManagerDashboard(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case warehouseProducts:
        return PageTransitions.fadeSlideTransition(
          page: const WarehouseManagerDashboard(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case treasuryManagement:
      case accountantTreasuryManagement:
        return PageTransitions.fadeSlideTransition(
          page: const TreasuryManagementScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );

      case manufacturingTools:
        return PageTransitions.fadeSlideTransition(
          page: const ManufacturingToolsScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );

      case addManufacturingTool:
        return PageTransitions.fadeSlideTransition(
          page: const AddToolScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );

      case manufacturingToolDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        if (args != null && args['tool'] != null) {
          return PageTransitions.fadeSlideTransition(
            page: ToolDetailScreen(tool: args['tool']),
            settings: settings,
            beginOffset: const Offset(0.1, 0),
          );
        }
        return PageTransitions.fadeTransition(
          page: const ErrorScreen(message: 'معاملات غير صحيحة لتفاصيل الأداة'),
          settings: settings,
        );

      case productionScreen:
        return PageTransitions.fadeSlideTransition(
          page: const ProductionScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );

      case startProduction:
        return PageTransitions.fadeSlideTransition(
          page: const StartProductionScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );

      case accountantInvoices:
        return PageTransitions.fadeSlideTransition(
          page: const StandaloneAccountantInvoicesScreen(),
          settings: settings,
          beginOffset: const Offset(0.1, 0),
        );

      case accountantOrderDetails:
        final order = settings.arguments as ClientOrder;
        return PageTransitions.fadeSlideTransition(
          page: AccountantOrderDetailsScreen(order: order),
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
          page: const CreateInvoiceScreen(),
          settings: settings,
        );

      case pendingInvoices:
        return PageTransitions.slideBottomToTopTransition(
          page: const PendingInvoicesScreen(),
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

      // Additional missing routes
      case '/admin/assign-tasks':
        return PageTransitions.fadeSlideTransition(
          page: const AssignTasksScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );



      // Wallet System Routes
      case walletManagement:
        return PageTransitions.fadeSlideTransition(
          page: const WalletManagementScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case accountantWalletManagement:
        return PageTransitions.fadeSlideTransition(
          page: const WalletManagementScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case walletView:
      case userWallet:
        return PageTransitions.fadeSlideTransition(
          page: const WalletViewScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      // Electronic Payment Routes
      case paymentMethodSelection:
        return PageTransitions.fadeSlideTransition(
          page: const PaymentMethodSelectionScreen(),
          settings: settings,
          beginOffset: const Offset(1, 0),
        );

      case paymentAccountSelection:
        return PageTransitions.fadeSlideTransition(
          page: const PaymentAccountSelectionScreen(),
          settings: settings,
          beginOffset: const Offset(1, 0),
        );

      case paymentForm:
        return PageTransitions.fadeSlideTransition(
          page: const PaymentFormScreen(),
          settings: settings,
          beginOffset: const Offset(1, 0),
        );

      case enhancedPaymentWorkflow:
        final Map<String, dynamic> args = settings.arguments as Map<String, dynamic>;
        return PageTransitions.fadeSlideTransition(
          page: EnhancedPaymentWorkflowScreen(
            paymentMethod: args['paymentMethod'] as ElectronicPaymentMethod,
            selectedAccount: args['selectedAccount'] as PaymentAccountModel,
          ),
          settings: settings,
          beginOffset: const Offset(1, 0),
        );

      case electronicPaymentManagement:
      case accountantElectronicPaymentManagement:
        return PageTransitions.fadeSlideTransition(
          page: const ElectronicPaymentManagementScreen(),
          settings: settings,
          beginOffset: const Offset(1, 0),
        );

      case walletTransactions:
        return PageTransitions.fadeSlideTransition(
          page: const WalletTransactionsScreen(),
          settings: settings,
          beginOffset: const Offset(1, 0),
        );

      case walletSyncUtility:
        return PageTransitions.fadeSlideTransition(
          page: const WalletSyncUtilityScreen(),
          settings: settings,
          beginOffset: const Offset(1, 0),
        );

      case advancedProductMovement:
        return PageTransitions.fadeSlideTransition(
          page: const AdvancedProductMovementScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case cart:
        return PageTransitions.fadeSlideTransition(
          page: const client_cart.CartScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case favorites:
        return PageTransitions.fadeSlideTransition(
          page: const FavoritesScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case onboarding:
        return PageTransitions.fadeSlideTransition(
          page: const OnboardingScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case waitingApproval:
        return PageTransitions.fadeSlideTransition(
          page: const WaitingApprovalScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case forgotPassword:
        return PageTransitions.fadeSlideTransition(
          page: const ForgotPasswordScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case menu:
        return PageTransitions.fadeSlideTransition(
          page: const MenuScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case clientAR:
        return PageTransitions.fadeSlideTransition(
          page: const ARScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case clientARProductSelection:
        if (settings.arguments != null && settings.arguments is Map<String, dynamic>) {
          final Map<String, dynamic> args = settings.arguments as Map<String, dynamic>;
          final File roomImage = args['roomImage'] as File;
          return PageTransitions.slideRightToLeftTransition(
            page: ARProductSelectionScreen(roomImage: roomImage),
            settings: settings,
          );
        } else {
          // Handle case where arguments are missing or invalid
          return PageTransitions.fadeTransition(
            page: ErrorScreen(
              message: 'خطأ: لم يتم تمرير صورة الغرفة بشكل صحيح',
              actionText: 'العودة إلى AR',
              onActionPressed: () => Navigator.of(AppRoutes.navigatorKey.currentContext!).pop(),
            ),
            settings: settings,
          );
        }

      case productMovement:
        return PageTransitions.fadeSlideTransition(
          page: const ProductMovementScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case qrScanner:
        return PageTransitions.fadeSlideTransition(
          page: const QRScannerScreen(),
          settings: settings,
          beginOffset: const Offset(0, 0.1),
        );

      case quickAccess:
        if (settings.arguments != null && settings.arguments is Map<String, dynamic>) {
          final Map<String, dynamic> args = settings.arguments as Map<String, dynamic>;
          final String productId = args['productId'] as String;
          final String productName = args['productName'] as String;
          return PageTransitions.fadeSlideTransition(
            page: QuickAccessScreen(
              productId: productId,
              productName: productName,
            ),
            settings: settings,
            beginOffset: const Offset(0, 0.1),
          );
        } else {
          // Handle case where arguments are missing or invalid
          return PageTransitions.fadeTransition(
            page: ErrorScreen(
              message: 'خطأ: لم يتم تمرير معلومات المنتج بشكل صحيح',
              actionText: 'العودة إلى الصفحة الرئيسية',
              onActionPressed: () => Navigator.of(AppRoutes.navigatorKey.currentContext!).pop(),
            ),
            settings: settings,
          );
        }

      case enhancedVoucherProducts:
        if (settings.arguments != null && settings.arguments is Map<String, dynamic>) {
          final Map<String, dynamic> args = settings.arguments as Map<String, dynamic>;
          final voucher = args['voucher'] as VoucherModel?;
          final clientVoucher = args['clientVoucher'] as ClientVoucherModel?;
          final clientVoucherId = args['clientVoucherId'] as String?;
          final highlightEligible = args['highlightEligible'] as bool? ?? true;
          final filterByEligibility = args['filterByEligibility'] as bool? ?? false;
          return PageTransitions.slideRightToLeftTransition(
            page: EnhancedVoucherProductsScreen(
              voucher: voucher,
              clientVoucher: clientVoucher,
              clientVoucherId: clientVoucherId,
              highlightEligible: highlightEligible,
              filterByEligibility: filterByEligibility,
            ),
            settings: settings,
          );
        } else {
          return PageTransitions.fadeTransition(
            page: ErrorScreen(
              message: 'خطأ: لم يتم تمرير معلومات القسيمة بشكل صحيح',
              actionText: 'العودة إلى القسائم',
              onActionPressed: () => Navigator.of(AppRoutes.navigatorKey.currentContext!).pop(),
            ),
            settings: settings,
          );
        }

      case voucherCheckout:
        if (settings.arguments != null && settings.arguments is Map<String, dynamic>) {
          final Map<String, dynamic> args = settings.arguments as Map<String, dynamic>;
          final voucherCartSummary = args['voucherCartSummary'] as Map<String, dynamic>;
          return PageTransitions.slideRightToLeftTransition(
            page: VoucherCheckoutScreen(voucherCartSummary: voucherCartSummary),
            settings: settings,
          );
        } else {
          return PageTransitions.fadeTransition(
            page: ErrorScreen(
              message: 'خطأ: لم يتم تمرير معلومات سلة القسائم بشكل صحيح',
              actionText: 'العودة إلى سلة القسائم',
              onActionPressed: () => Navigator.of(AppRoutes.navigatorKey.currentContext!).pushReplacementNamed(voucherCart),
            ),
            settings: settings,
          );
        }

      case workerAttendanceReports:
        // Determine user role from arguments or use default
        String userRole = 'admin';
        if (settings.arguments != null && settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          userRole = args['userRole'] as String? ?? 'admin';
        }
        return PageTransitions.fadeTransition(
          page: WorkerAttendanceReportsWrapper(userRole: userRole),
          settings: settings,
        );

      default:
        // Handle dynamic warehouse release order routes
        if (settings.name != null && settings.name!.startsWith('/accountant/warehouse-release-orders/')) {
          return PageTransitions.fadeSlideTransition(
            page: const WarehouseReleaseOrdersScreen(userRole: 'accountant'),
            settings: settings,
            beginOffset: const Offset(0, 0.1),
          );
        }

        // Handle dynamic warehouse manager release order routes
        if (settings.name != null && settings.name!.startsWith('/warehouse/release-orders/')) {
          return PageTransitions.fadeSlideTransition(
            page: const WarehouseReleaseOrdersScreen(userRole: 'warehouseManager'),
            settings: settings,
            beginOffset: const Offset(0, 0.1),
          );
        }
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
