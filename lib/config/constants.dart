class AppConstants {
  // General
  static const String appName = 'SmartBizTracker';
  static const String appVersion = '1.0.0';

  // API
  static const String baseUrl = 'https://samastock.pythonanywhere.com';
  static const String apiKey = 'lux2025FlutterAccess';
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;

  // Local Storage
  static const String token = 'token';
  static const String user = 'user';
  static const String theme = 'theme';

  // Messages
  static const String noOrders = 'No orders found';
  static const String noProducts = 'No products found';
  static const String noNotifications = 'No notifications found';
  static const String noChats = 'No chats available';
  static const String loginSuccess = 'Login successful';
  static const String loginError = 'Login failed. Please try again.';
  static const String registerSuccess = 'Registration successful';
  static const String registerError = 'Registration failed. Please try again.';
  static const String networkError =
      'Network error. Please check your connection.';
  static const String genericError = 'Something went wrong. Please try again.';
  static const String formError = 'Please fill all required fields correctly';
  static const String signupSuccess = 'Registration successful. Please login.';
  static const String waitingApproval = 'Your account is waiting for approval.';

  // Roles
  static const String roleAdmin = 'admin';
  static const String roleOwner = 'owner';
  static const String roleClient = 'client';
  static const String roleWorker = 'worker';

  // Status
  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';
  static const String statusCompleted = 'completed';
  static const String statusInProgress = 'in_progress';
  static const String statusCancelled = 'cancelled';

  // Screens
  static const String onboardingScreen = '/onboarding';
  static const String loginScreen = '/login';
  static const String registerScreen = '/register';
  static const String forgotPasswordScreen = '/forgot-password';
  static const String homeScreen = '/home';
  static const String profileScreen = '/profile';
  static const String settingsScreen = '/settings';
  static const String notificationsScreen = '/notifications';
  static const String chatListScreen = '/chats';
  static const String chatDetailScreen = '/chat';

  // App Info
  static const String appNameArabic = 'نظام إدارة الأعمال';
  static const String appVersionArabic = '1.0.0';

  // API Endpoints
  static const String apiVersion = 'v1';
  static const String productsApi = '/flutter/api/api/products';
  static const String ordersApi = 'orders';
  static const String authLoginUrl = 'https://auth.smartbiztracker.com/login';
  static const String secondaryUrl = 'https://app.smartbiztracker.com';
  static const String adminUsername = 'admin@smartbiztracker.com';
  static const String adminPassword = 'admin123';

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String productsCollection = 'products';
  static const String ordersCollection = 'orders';
  static const String faultsCollection = 'faults';
  static const String wasteCollection = 'waste';
  static const String chatsCollection = 'chats';
  static const String messagesCollection = 'messages';
  static const String notificationsCollection = 'notifications';
  static const String productivityCollection = 'productivity';

  // Shared Preferences Keys
  static const String onboardingCompletedKey = 'onboarding_completed';
  static const String languageCodeKey = 'language_code';
  static const String userIdKey = 'user_id';
  static const String userRoleKey = 'user_role';

  // Storage Paths
  static const String profileImagesPath = 'profile_images';
  static const String productImagesPath = 'product_images';
  static const String faultImagesPath = 'fault_images';
  static const String chatAttachmentsPath = 'chat_attachments';

  // Animation Durations
  static const Duration slowAnimation = Duration(milliseconds: 1000);
  static const Duration mediumAnimation = Duration(milliseconds: 600);
  static const Duration fastAnimation = Duration(milliseconds: 300);
  static const int splashDuration = 2000; // milliseconds
  static const int pageTransitionDuration = 300; // milliseconds
  static const int cardAnimationDuration = 400; // milliseconds
  static const int listAnimationDuration = 600; // milliseconds

  // Pagination
  static const int defaultPageSize = 10;

  // Validation Messages
  static const String validationRequiredField = 'هذا الحقل مطلوب';
  static const String validationInvalidEmail = 'بريد إلكتروني غير صالح';
  static const String validationPasswordLength =
      'يجب أن تكون كلمة المرور 6 أحرف على الأقل';
  static const String validationPasswordsDontMatch = 'كلمات المرور غير متطابقة';
  static const String validationInvalidPhone = 'رقم هاتف غير صالح';

  // Error Messages
  static const String errorSomethingWentWrong =
      'حدث خطأ ما، يرجى المحاولة مرة أخرى';
  static const String errorNoInternet = 'لا يوجد اتصال بالإنترنت';
  static const String errorTimeout =
      'انتهت مهلة الاتصال، يرجى المحاولة مرة أخرى';
  static const String errorServer = 'حدث خطأ في الخادم، يرجى المحاولة لاحقًا';
  static const String errorUnauthorized = 'غير مصرح لك بالوصول';
  static const String errorNotFound = 'لم يتم العثور على البيانات المطلوبة';

  // Success Messages
  static const String successProfileUpdated = 'تم تحديث الملف الشخصي بنجاح';
  static const String successPasswordReset =
      'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني';
  static const String successOrderCreated = 'تم إنشاء الطلب بنجاح';
  static const String successFaultReported = 'تم الإبلاغ عن الخطأ بنجاح';

  // Button Text
  static const String buttonLogin = 'تسجيل الدخول';
  static const String buttonRegister = 'إنشاء حساب';
  static const String buttonForgotPassword = 'نسيت كلمة المرور';
  static const String buttonResetPassword = 'إعادة تعيين كلمة المرور';
  static const String buttonSave = 'حفظ';
  static const String buttonCancel = 'إلغاء';
  static const String buttonUpdate = 'تحديث';
  static const String buttonDelete = 'حذف';
  static const String buttonApprove = 'موافقة';
  static const String buttonReject = 'رفض';
  static const String buttonSubmit = 'إرسال';
  static const String buttonNext = 'التالي';
  static const String buttonPrevious = 'السابق';
  static const String buttonSkip = 'تخطي';
  static const String buttonGetStarted = 'ابدأ الآن';

  // Date Formats
  static const String dateFormatDisplay = 'dd/MM/yyyy';
  static const String dateTimeFormatDisplay = 'dd/MM/yyyy HH:mm';
  static const String timeFormatDisplay = 'HH:mm';

  // Default Values
  static const String defaultAvatar = 'assets/images/default_avatar.png';
  static const String defaultProductImage = 'assets/images/default_product.png';

  // Image Assets
  static const String logoImage = 'assets/images/logo.png';
  static const String onboardingImage1 = 'assets/images/onboarding1.png';
  static const String onboardingImage2 = 'assets/images/onboarding2.png';
  static const String onboardingImage3 = 'assets/images/onboarding3.png';

  // Animation Assets
  static const String loadingAnimation = 'assets/animations/loading.json';
  static const String successAnimation = 'assets/animations/success.json';
  static const String errorAnimation = 'assets/animations/error.json';
  static const String emptyAnimation = 'assets/animations/empty.json';
}
