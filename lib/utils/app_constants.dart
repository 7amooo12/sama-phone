class AppConstants {
  // Animation durations
  static const slowAnimation = Duration(milliseconds: 800);
  static const mediumAnimation = Duration(milliseconds: 500);
  static const fastAnimation = Duration(milliseconds: 300);
  static const loadingAnimation = Duration(milliseconds: 700);

  // Using uppercase constants for backward compatibility with existing code
  @Deprecated('Use lowercase slowAnimation instead')
  static const SLOW_ANIMATION = Duration(milliseconds: 800);
  @Deprecated('Use lowercase mediumAnimation instead')
  static const MEDIUM_ANIMATION = Duration(milliseconds: 500);
  @Deprecated('Use lowercase fastAnimation instead')
  static const FAST_ANIMATION = Duration(milliseconds: 300);

  // Validation messages
  static const validationRequiredField = 'هذا الحقل مطلوب';
  static const validationInvalidEmail = 'البريد الإلكتروني غير صالح';
  static const validationPasswordLength =
      'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
  static const validationPasswordsDontMatch = 'كلمات المرور غير متطابقة';

  // Validation messages in uppercase for backward compatibility
  @Deprecated('Use lowercase validationRequiredField instead')
  static const VALIDATION_REQUIRED_FIELD = 'هذا الحقل مطلوب';
  @Deprecated('Use lowercase validationInvalidEmail instead')
  static const VALIDATION_INVALID_EMAIL = 'البريد الإلكتروني غير صالح';
  @Deprecated('Use lowercase validationPasswordLength instead')
  static const VALIDATION_PASSWORD_LENGTH =
      'كلمة المرور يجب أن تكون 6 أحرف على الأقل';

  // Success messages
  static const signupSuccess = 'تم التسجيل بنجاح';
  @Deprecated('Use lowercase signupSuccess instead')
  static const SIGNUP_SUCCESS = 'تم التسجيل بنجاح';

  // Error messages
  static const errorSomethingWentWrong = 'حدث خطأ ما، يرجى المحاولة مرة أخرى';

  // Info messages
  static const waitingApproval = 'طلبك قيد المراجعة، سيتم إخطارك عند الموافقة';
  @Deprecated('Use lowercase waitingApproval instead')
  static const WAITING_APPROVAL = 'طلبك قيد المراجعة، سيتم إخطارك عند الموافقة';
  static const noOrders = 'لا توجد طلبات حالية';

  // Application constants
  static const appName = 'SAMA';
  static const appNameArabic = 'نظام إدارة الأعمال';
  static const appVersion = '1.0.0';
  static const buttonRegister = 'تسجيل';
  static const buttonLogin = 'تسجيل الدخول';
  static const buttonSave = 'حفظ';
  static const buttonCancel = 'إلغاء';
  static const buttonNext = 'التالي';
  static const buttonPrevious = 'السابق';
  static const buttonFinish = 'إنهاء';
  @Deprecated('Use lowercase buttonRegister instead')
  static const BUTTON_REGISTER = 'تسجيل';

  // Animation paths
  static const errorAnimation = 'assets/animations/error.json';
  static const loadingAnimationPath = 'assets/animations/loading.json';

  // API Constants
  static const baseUrl = 'https://api.sama-app.com';
  static const secondaryUrl = 'https://dashboard.sama-app.com';
  static const connectTimeout = 30000; // 30 seconds
  static const productsApi = '/api/products';
  static const authLoginUrl = '/api/auth/login';

  // Default credentials (only for development)
  static const adminUsername = 'admin';
  static const adminPassword = 'admin123';
  @Deprecated('Use lowercase adminUsername instead')
  static const ADMIN_USERNAME = 'admin';
  @Deprecated('Use lowercase adminPassword instead')
  static const ADMIN_PASSWORD = 'admin123';

  // Notification types
  static const order = 'order';

  // Used in external links
  static const adminLoginUrl = '/admin/login';
}
