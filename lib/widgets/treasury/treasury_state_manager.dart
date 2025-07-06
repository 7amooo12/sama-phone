import 'package:flutter/material.dart';
import '../../utils/accountant_theme_config.dart';
import 'treasury_loading_manager.dart';
import 'treasury_error_handler.dart';
import 'treasury_error_boundary.dart';

/// Comprehensive state manager for treasury screens
class TreasuryStateManager extends StatelessWidget {
  final TreasuryState state;
  final Widget child;
  final String? loadingMessage;
  final TreasuryLoadingType loadingType;
  final int skeletonItemCount;
  final String? errorTitle;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final String? successTitle;
  final String? successMessage;
  final VoidCallback? onSuccessAction;
  final String? successActionText;
  final bool showSuccessOverlay;

  const TreasuryStateManager({
    super.key,
    required this.state,
    required this.child,
    this.loadingMessage,
    this.loadingType = TreasuryLoadingType.general,
    this.skeletonItemCount = 3,
    this.errorTitle,
    this.errorMessage,
    this.onRetry,
    this.successTitle,
    this.successMessage,
    this.onSuccessAction,
    this.successActionText,
    this.showSuccessOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    return TreasuryErrorBoundary(
      errorTitle: errorTitle,
      errorMessage: errorMessage,
      onRetry: onRetry,
      child: Stack(
        children: [
          _buildMainContent(),
          if (showSuccessOverlay && state == TreasuryState.success)
            _buildSuccessOverlay(),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (state) {
      case TreasuryState.initial:
        return _buildInitialState();
      case TreasuryState.loading:
        return TreasuryLoadingManager(
          isLoading: true,
          loadingType: loadingType,
          itemCount: skeletonItemCount,
          loadingMessage: loadingMessage,
          child: child,
        );
      case TreasuryState.success:
        return child;
      case TreasuryState.error:
        return _buildErrorState();
      case TreasuryState.empty:
        return _buildEmptyState();
    }
  }

  Widget _buildInitialState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_rounded,
              size: 64,
              color: AccountantThemeConfig.white60,
            ),
            const SizedBox(height: 16),
            Text(
              'إدارة الخزينة',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ابدأ بتحميل البيانات',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return TreasuryErrorHandler.errorDisplay(
      title: errorTitle ?? 'حدث خطأ',
      message: errorMessage ?? 'فشل في تحميل البيانات',
      onRetry: onRetry,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 64,
              color: AccountantThemeConfig.white60,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد بيانات',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لم يتم العثور على أي بيانات لعرضها',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.white70,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AccountantThemeConfig.primaryGreen,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة التحميل'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessOverlay() {
    if (successTitle == null || successMessage == null) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: TreasuryErrorHandler.successMessage(
          title: successTitle!,
          message: successMessage!,
          onAction: onSuccessAction,
          actionText: successActionText,
          onDismiss: () {
            // This would need to be handled by parent widget
          },
        ),
      ),
    );
  }
}

/// Treasury state enum
enum TreasuryState {
  initial,
  loading,
  success,
  error,
  empty,
}

/// State manager with built-in async operation handling
class TreasuryAsyncStateManager<T> extends StatefulWidget {
  final Future<T> Function() operation;
  final Widget Function(T data) builder;
  final String? loadingMessage;
  final TreasuryLoadingType loadingType;
  final int skeletonItemCount;
  final String? errorTitle;
  final String? errorMessage;
  final bool Function(T data)? isEmpty;
  final Widget? emptyWidget;
  final bool autoRetry;
  final Duration? retryDelay;
  final int maxRetries;

  const TreasuryAsyncStateManager({
    super.key,
    required this.operation,
    required this.builder,
    this.loadingMessage,
    this.loadingType = TreasuryLoadingType.general,
    this.skeletonItemCount = 3,
    this.errorTitle,
    this.errorMessage,
    this.isEmpty,
    this.emptyWidget,
    this.autoRetry = false,
    this.retryDelay,
    this.maxRetries = 3,
  });

  @override
  State<TreasuryAsyncStateManager<T>> createState() => _TreasuryAsyncStateManagerState<T>();
}

class _TreasuryAsyncStateManagerState<T> extends State<TreasuryAsyncStateManager<T>> {
  TreasuryState _state = TreasuryState.initial;
  T? _data;
  String? _error;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _state = TreasuryState.loading;
      _error = null;
    });

    try {
      final data = await widget.operation();
      
      setState(() {
        _data = data;
        
        if (widget.isEmpty?.call(data) == true) {
          _state = TreasuryState.empty;
        } else {
          _state = TreasuryState.success;
        }
      });
      
      _retryCount = 0; // Reset retry count on success
    } catch (error) {
      setState(() {
        _error = error.toString();
        _state = TreasuryState.error;
      });

      // Auto retry if enabled
      if (widget.autoRetry && _retryCount < widget.maxRetries) {
        _retryCount++;
        await Future.delayed(widget.retryDelay ?? const Duration(seconds: 2));
        if (mounted) {
          _loadData();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TreasuryStateManager(
      state: _state,
      loadingMessage: widget.loadingMessage,
      loadingType: widget.loadingType,
      skeletonItemCount: widget.skeletonItemCount,
      errorTitle: widget.errorTitle,
      errorMessage: widget.errorMessage ?? _error,
      onRetry: _loadData,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_state == TreasuryState.success && _data != null) {
      return widget.builder(_data!);
    }
    
    if (_state == TreasuryState.empty && widget.emptyWidget != null) {
      return widget.emptyWidget!;
    }
    
    return const SizedBox.shrink();
  }
}

/// Mixin for treasury screens to handle common state management
mixin TreasuryStateMixin<T extends StatefulWidget> on State<T> {
  TreasuryState _treasuryState = TreasuryState.initial;
  String? _treasuryError;

  TreasuryState get treasuryState => _treasuryState;
  String? get treasuryError => _treasuryError;

  void setTreasuryLoading() {
    setState(() {
      _treasuryState = TreasuryState.loading;
      _treasuryError = null;
    });
  }

  void setTreasurySuccess() {
    setState(() {
      _treasuryState = TreasuryState.success;
      _treasuryError = null;
    });
  }

  void setTreasuryError(String error) {
    setState(() {
      _treasuryState = TreasuryState.error;
      _treasuryError = error;
    });
  }

  void setTreasuryEmpty() {
    setState(() {
      _treasuryState = TreasuryState.empty;
      _treasuryError = null;
    });
  }

  Future<void> handleTreasuryOperation(Future<void> Function() operation) async {
    setTreasuryLoading();
    
    try {
      await operation();
      setTreasurySuccess();
    } catch (error) {
      setTreasuryError(error.toString());
    }
  }
}
