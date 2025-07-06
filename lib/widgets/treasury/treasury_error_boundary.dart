import 'package:flutter/material.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';
import 'treasury_error_handler.dart';

/// Error boundary widget for treasury screens
class TreasuryErrorBoundary extends StatefulWidget {
  final Widget child;
  final String? errorTitle;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool logErrors;
  final Widget Function(Object error, StackTrace? stackTrace)? errorBuilder;

  const TreasuryErrorBoundary({
    super.key,
    required this.child,
    this.errorTitle,
    this.errorMessage,
    this.onRetry,
    this.logErrors = true,
    this.errorBuilder,
  });

  @override
  State<TreasuryErrorBoundary> createState() => _TreasuryErrorBoundaryState();
}

class _TreasuryErrorBoundaryState extends State<TreasuryErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(_error!, _stackTrace);
      }
      
      return _buildErrorWidget();
    }

    return ErrorBoundaryWrapper(
      onError: _handleError,
      child: widget.child,
    );
  }

  void _handleError(Object error, StackTrace? stackTrace) {
    if (widget.logErrors) {
      AppLogger.error('Treasury Error Boundary caught error: $error', stackTrace);
    }

    setState(() {
      _error = error;
      _stackTrace = stackTrace;
    });
  }

  Widget _buildErrorWidget() {
    final errorType = _categorizeError(_error!);
    
    switch (errorType) {
      case TreasuryErrorType.network:
        return TreasuryErrorHandler.networkError(
          onRetry: _retry,
          customMessage: widget.errorMessage,
        );
      case TreasuryErrorType.permission:
        return TreasuryErrorHandler.permissionError(
          onRetry: _retry,
          customMessage: widget.errorMessage,
        );
      case TreasuryErrorType.server:
        return TreasuryErrorHandler.serverError(
          onRetry: _retry,
          customMessage: widget.errorMessage,
        );
      case TreasuryErrorType.validation:
        return TreasuryErrorHandler.validationError(
          errors: [_error.toString()],
          onDismiss: _retry,
        );
      case TreasuryErrorType.general:
      default:
        return TreasuryErrorHandler.errorDisplay(
          title: widget.errorTitle ?? 'حدث خطأ غير متوقع',
          message: widget.errorMessage ?? _error.toString(),
          onRetry: _retry,
        );
    }
  }

  TreasuryErrorType _categorizeError(Object error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('network') || 
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('socket')) {
      return TreasuryErrorType.network;
    }
    
    if (errorString.contains('unauthorized') ||
        errorString.contains('forbidden') ||
        errorString.contains('permission') ||
        errorString.contains('access denied')) {
      return TreasuryErrorType.permission;
    }
    
    if (errorString.contains('server') ||
        errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503')) {
      return TreasuryErrorType.server;
    }
    
    if (errorString.contains('validation') ||
        errorString.contains('invalid') ||
        errorString.contains('required')) {
      return TreasuryErrorType.validation;
    }
    
    return TreasuryErrorType.general;
  }

  void _retry() {
    setState(() {
      _error = null;
      _stackTrace = null;
    });
    
    widget.onRetry?.call();
  }
}

/// Error boundary wrapper that catches Flutter errors
class ErrorBoundaryWrapper extends StatefulWidget {
  final Widget child;
  final void Function(Object error, StackTrace? stackTrace) onError;

  const ErrorBoundaryWrapper({
    super.key,
    required this.child,
    required this.onError,
  });

  @override
  State<ErrorBoundaryWrapper> createState() => _ErrorBoundaryWrapperState();
}

class _ErrorBoundaryWrapperState extends State<ErrorBoundaryWrapper> {
  @override
  void initState() {
    super.initState();
    
    // Catch Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      widget.onError(details.exception, details.stack);
    };
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Types of treasury errors
enum TreasuryErrorType {
  network,
  permission,
  server,
  validation,
  general,
}

/// Async error handler for treasury operations
class TreasuryAsyncErrorHandler {
  /// Handle async operations with comprehensive error handling
  static Future<T?> handleAsync<T>({
    required Future<T> Function() operation,
    required BuildContext context,
    String? loadingMessage,
    String? successMessage,
    bool showSuccessSnackBar = false,
    bool showErrorDialog = true,
    VoidCallback? onSuccess,
    VoidCallback? onError,
  }) async {
    try {
      // Show loading if message provided
      if (loadingMessage != null) {
        _showLoadingSnackBar(context, loadingMessage);
      }

      final result = await operation();

      // Hide loading
      if (loadingMessage != null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      // Show success message
      if (showSuccessSnackBar && successMessage != null) {
        _showSuccessSnackBar(context, successMessage);
      }

      onSuccess?.call();
      return result;
    } catch (error, stackTrace) {
      // Hide loading
      if (loadingMessage != null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      // Log error
      AppLogger.error('Async operation failed: $error', stackTrace);

      // Show error
      if (showErrorDialog) {
        _showErrorDialog(context, error);
      } else {
        _showErrorSnackBar(context, error.toString());
      }

      onError?.call();
      return null;
    }
  }

  static void _showLoadingSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              message,
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: AccountantThemeConfig.accentBlue,
        duration: const Duration(minutes: 1), // Long duration for loading
      ),
    );
  }

  static void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 12),
            Text(
              message,
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: AccountantThemeConfig.primaryGreen,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_rounded,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'إغلاق',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static void _showErrorDialog(BuildContext context, Object error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'حدث خطأ',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          error.toString(),
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: AccountantThemeConfig.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'موافق',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.accentBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
