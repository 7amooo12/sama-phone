import 'package:flutter/material.dart';
import '../../utils/accountant_theme_config.dart';

/// Comprehensive error handling widgets for treasury screens
class TreasuryErrorHandler {
  /// Generic error display widget
  static Widget errorDisplay({
    required String title,
    required String message,
    IconData? icon,
    VoidCallback? onRetry,
    String? retryText,
    List<Widget>? additionalActions,
  }) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.error_outline_rounded,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AccountantThemeConfig.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(retryText ?? 'إعادة المحاولة'),
              ),
            if (additionalActions != null && additionalActions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: additionalActions,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Network error display
  static Widget networkError({
    VoidCallback? onRetry,
    String? customMessage,
  }) {
    return errorDisplay(
      title: 'خطأ في الاتصال',
      message: customMessage ?? 'تعذر الاتصال بالخادم. يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى.',
      icon: Icons.wifi_off_rounded,
      onRetry: onRetry,
      retryText: 'إعادة الاتصال',
    );
  }

  /// Permission error display
  static Widget permissionError({
    VoidCallback? onRetry,
    String? customMessage,
  }) {
    return errorDisplay(
      title: 'غير مصرح',
      message: customMessage ?? 'ليس لديك صلاحية للوصول إلى هذه البيانات. يرجى التواصل مع المدير.',
      icon: Icons.lock_outline_rounded,
      onRetry: onRetry,
      retryText: 'إعادة التحقق',
    );
  }

  /// Data not found error
  static Widget dataNotFound({
    required String dataType,
    VoidCallback? onRetry,
    VoidCallback? onCreate,
    String? customMessage,
  }) {
    return errorDisplay(
      title: 'لا توجد بيانات',
      message: customMessage ?? 'لم يتم العثور على $dataType في النظام.',
      icon: Icons.search_off_rounded,
      onRetry: onRetry,
      retryText: 'إعادة البحث',
      additionalActions: onCreate != null ? [
        OutlinedButton.icon(
          onPressed: onCreate,
          style: OutlinedButton.styleFrom(
            foregroundColor: AccountantThemeConfig.accentBlue,
            side: BorderSide(color: AccountantThemeConfig.accentBlue),
          ),
          icon: const Icon(Icons.add_rounded),
          label: Text('إنشاء $dataType'),
        ),
      ] : null,
    );
  }

  /// Server error display
  static Widget serverError({
    VoidCallback? onRetry,
    String? errorCode,
    String? customMessage,
  }) {
    return errorDisplay(
      title: 'خطأ في الخادم',
      message: customMessage ?? 'حدث خطأ في الخادم. يرجى المحاولة مرة أخرى لاحقاً.',
      icon: Icons.dns_rounded,
      onRetry: onRetry,
      retryText: 'إعادة المحاولة',
      additionalActions: errorCode != null ? [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'كود الخطأ: $errorCode',
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.red,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ] : null,
    );
  }

  /// Validation error display
  static Widget validationError({
    required List<String> errors,
    VoidCallback? onDismiss,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_rounded,
                color: Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'أخطاء في البيانات',
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...errors.map((error) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.circle,
                  color: Colors.red,
                  size: 8,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error,
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  /// Success message display
  static Widget successMessage({
    required String title,
    required String message,
    VoidCallback? onDismiss,
    VoidCallback? onAction,
    String? actionText,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AccountantThemeConfig.primaryGreen,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        color: AccountantThemeConfig.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      message,
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AccountantThemeConfig.primaryGreen,
                    size: 20,
                  ),
                ),
            ],
          ),
          if (onAction != null && actionText != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AccountantThemeConfig.primaryGreen,
                  foregroundColor: Colors.white,
                ),
                child: Text(actionText),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Warning message display
  static Widget warningMessage({
    required String title,
    required String message,
    VoidCallback? onDismiss,
    VoidCallback? onAction,
    String? actionText,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_rounded,
                color: Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      message,
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
            ],
          ),
          if (onAction != null && actionText != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: Text(actionText),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
