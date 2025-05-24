import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';

class AppConstants {
  // App info
  static const String appName = 'SmartBizTracker';
  static const String appVersion = '1.0.0';

  // Collection names
  static const String usersCollection = 'users';
  static const String productsCollection = 'products';
  static const String ordersCollection = 'orders';
  static const String faultsCollection = 'faults';
  static const String wasteCollection = 'waste';
  static const String chatsCollection = 'chats';
  static const String notificationsCollection = 'notifications';
  static const String productivityCollection = 'productivity';
  static const String returnsCollection = 'returns';

  // Storage folders
  static const String profileImages = 'profile_images';
  static const String productImages = 'product_images';
  static const String chatAttachments = 'chat_attachments';
  static const String faultAttachments = 'fault_attachments';
  static const String wasteAttachments = 'waste_attachments';
  static const String returnAttachments = 'return_attachments';

  // API URLs
  static const String authLoginUrl =
      'https://api.smartbiztracker.com/auth/login';
  static const String productsApi = 'products';
  static const String secondaryUrl = 'https://admin.smartbiztracker.com';

  // Default credentials
  static const String adminUsername = 'admin';
  static const String adminPassword = 'admin123';

  // Page sizes
  static const int defaultPageSize = 20;
  static const double defaultPadding = 16.0;
  static const double defaultRadius = 8.0;

  // Animation durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 350);
  static const Duration longAnimation = Duration(milliseconds: 500);
  static const Duration slowAnimation = Duration(milliseconds: 800);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 500);

  // App messages
  static const String signupSuccess =
      'Sign up successful! Please wait for admin approval.';
  static const String waitingApproval =
      'Your account is pending approval by an administrator.';

  // Colors
  static const MaterialColor primarySwatch = Colors.blue;
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color secondaryColor = Color(0xFF03A9F4);
  static const Color accentColor = Color(0xFF00BCD4);
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFFA000);
  static const Color infoColor = Color(0xFF1976D2);

  // Text styles
  static const TextStyle headingStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle subheadingStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 16,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 14,
    color: Colors.grey,
  );

  // Border radius
  static final BorderRadius defaultBorderRadius = BorderRadius.circular(8);
  static final BorderRadius largeBorderRadius = BorderRadius.circular(16);
  static final BorderRadius roundBorderRadius = BorderRadius.circular(24);

  // Box shadows
  static final List<BoxShadow> defaultShadow = [
    BoxShadow(
      color: Colors.black.safeOpacity(0.1),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static final List<BoxShadow> largeShadow = [
    BoxShadow(
      color: Colors.black.safeOpacity(0.15),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  // Input decorations
  static InputDecoration defaultInputDecoration({
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: defaultBorderRadius,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: defaultBorderRadius,
        borderSide: BorderSide(
          color: Colors.grey.shade400,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: defaultBorderRadius,
        borderSide: const BorderSide(
          color: primaryColor,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: defaultBorderRadius,
        borderSide: const BorderSide(
          color: errorColor,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: defaultBorderRadius,
        borderSide: const BorderSide(
          color: errorColor,
          width: 2,
        ),
      ),
    );
  }

  // Button styles
  static final ButtonStyle defaultButtonStyle = ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 12,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: defaultBorderRadius,
    ),
  );

  static final ButtonStyle outlinedButtonStyle = OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 12,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: defaultBorderRadius,
    ),
    side: const BorderSide(color: primaryColor),
  );

  // Date formats
  static const String dateFormat = 'dd/MM/yyyy';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';

  // Validation patterns
  static final RegExp emailPattern = RegExp(
    r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
  );
  static final RegExp phonePattern = RegExp(
    r'^\+?[0-9]{10,}$',
  );
}
