import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';

/// Utility class for showing consistent snackbars throughout the app
class ShowSnackbar {
  /// Show a snackbar with consistent styling
  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    bool isSuccess = false,
    bool isWarning = false,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    VoidCallback? onVisible,
  }) {
    // Determine colors based on type
    Color backgroundColor;
    Color textColor = Colors.white;
    IconData icon;

    if (isError) {
      backgroundColor = AccountantThemeConfig.dangerRed;
      icon = Icons.error_outline_rounded;
    } else if (isSuccess) {
      backgroundColor = AccountantThemeConfig.primaryGreen;
      icon = Icons.check_circle_outline_rounded;
    } else if (isWarning) {
      backgroundColor = AccountantThemeConfig.warningOrange;
      icon = Icons.warning_amber_rounded;
    } else {
      backgroundColor = AccountantThemeConfig.accentBlue;
      icon = Icons.info_outline_rounded;
    }

    // Hide any existing snackbar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // Show new snackbar
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            icon,
            color: textColor,
            size: 20,
          ),
          const SizedBox(width: AccountantThemeConfig.smallPadding),
          Expanded(
            child: Text(
              message,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
      ),
      margin: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      elevation: 8,
      action: action,
      onVisible: onVisible,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Show a success snackbar
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    show(
      context,
      message,
      isSuccess: true,
      duration: duration,
      action: action,
    );
  }

  /// Show an error snackbar
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    show(
      context,
      message,
      isError: true,
      duration: duration,
      action: action,
    );
  }

  /// Show a warning snackbar
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    show(
      context,
      message,
      isWarning: true,
      duration: duration,
      action: action,
    );
  }

  /// Show an info snackbar
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    show(
      context,
      message,
      duration: duration,
      action: action,
    );
  }

  /// Show a loading snackbar that can be dismissed programmatically
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showLoading(
    BuildContext context,
    String message, {
    Duration duration = const Duration(minutes: 5), // Long duration for loading
  }) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: AccountantThemeConfig.defaultPadding),
          Expanded(
            child: Text(
              message,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AccountantThemeConfig.accentBlue,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
      ),
      margin: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      elevation: 8,
    );

    return ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Show a snackbar with custom action
  static void showWithAction(
    BuildContext context,
    String message,
    String actionLabel,
    VoidCallback onActionPressed, {
    bool isError = false,
    bool isSuccess = false,
    bool isWarning = false,
    Duration duration = const Duration(seconds: 5),
  }) {
    show(
      context,
      message,
      isError: isError,
      isSuccess: isSuccess,
      isWarning: isWarning,
      duration: duration,
      action: SnackBarAction(
        label: actionLabel,
        textColor: Colors.white,
        onPressed: onActionPressed,
      ),
    );
  }

  /// Show a snackbar for network errors with retry option
  static void showNetworkError(
    BuildContext context, {
    String message = 'خطأ في الاتصال بالشبكة',
    VoidCallback? onRetry,
  }) {
    showWithAction(
      context,
      message,
      'إعادة المحاولة',
      onRetry ?? () {},
      isError: true,
      duration: const Duration(seconds: 6),
    );
  }

  /// Show a snackbar for validation errors
  static void showValidationError(
    BuildContext context,
    String message,
  ) {
    showError(
      context,
      message,
      duration: const Duration(seconds: 4),
    );
  }

  /// Show a snackbar for operation success
  static void showOperationSuccess(
    BuildContext context,
    String operation,
  ) {
    showSuccess(
      context,
      'تم $operation بنجاح',
      duration: const Duration(seconds: 2),
    );
  }
}
