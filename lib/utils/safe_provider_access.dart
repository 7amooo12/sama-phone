import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Extension for safe Provider access with proper error handling
extension SafeProviderAccess on BuildContext {
  
  /// Safely get Provider without listening, returns null if not found
  T? tryProvider<T>() {
    try {
      return Provider.of<T>(this, listen: false);
    } catch (e) {
      AppLogger.warning('⚠️ Provider<$T> not found: $e');
      return null;
    }
  }
  
  /// Safely get Provider with listening, returns null if not found
  T? tryProviderWithListen<T>() {
    try {
      return Provider.of<T>(this, listen: true);
    } catch (e) {
      AppLogger.warning('⚠️ Provider<$T> not found: $e');
      return null;
    }
  }
  
  /// Get Provider with error handling and fallback
  T getProviderSafely<T>({
    bool listen = false,
    T? fallback,
    String? errorMessage,
  }) {
    try {
      return Provider.of<T>(this, listen: listen);
    } catch (e) {
      final message = errorMessage ?? 'Provider<$T> not found';
      AppLogger.error('❌ $message: $e');
      
      if (fallback != null) {
        AppLogger.info('🔄 Using fallback for Provider<$T>');
        return fallback;
      }
      
      rethrow;
    }
  }
  
  /// Check if Provider is available in the widget tree
  bool hasProvider<T>() {
    try {
      Provider.of<T>(this, listen: false);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Execute callback only if Provider is available
  void withProvider<T>(
    void Function(T provider) callback, {
    bool listen = false,
    VoidCallback? onProviderNotFound,
  }) {
    try {
      final provider = Provider.of<T>(this, listen: listen);
      callback(provider);
    } catch (e) {
      AppLogger.warning('⚠️ Provider<$T> not available for callback: $e');
      onProviderNotFound?.call();
    }
  }
  
  /// Execute async callback only if Provider is available
  Future<void> withProviderAsync<T>(
    Future<void> Function(T provider) callback, {
    bool listen = false,
    Future<void> Function()? onProviderNotFound,
  }) async {
    try {
      final provider = Provider.of<T>(this, listen: listen);
      await callback(provider);
    } catch (e) {
      AppLogger.warning('⚠️ Provider<$T> not available for async callback: $e');
      if (onProviderNotFound != null) {
        await onProviderNotFound();
      }
    }
  }
}

/// Mixin for safe state management with Provider access
mixin SafeProviderStateMixin<T extends StatefulWidget> on State<T> {
  bool _disposed = false;
  

  
  /// Safe setState that checks if widget is still mounted and not disposed
  void safeSetState(VoidCallback fn) {
    if (!_disposed && mounted) {
      setState(fn);
    } else {
      AppLogger.warning('⚠️ Attempted setState on disposed/unmounted widget');
    }
  }
  
  /// Safe Provider access in didChangeDependencies
  P? getProviderInDidChangeDependencies<P>() {
    try {
      return context.tryProvider<P>();
    } catch (e) {
      AppLogger.error('❌ Error accessing Provider<$P> in didChangeDependencies: $e');
      return null;
    }
  }
  
  /// Execute async operation safely with error handling
  Future<void> safeAsyncOperation(
    Future<void> Function() operation, {
    String? operationName,
    bool showErrorSnackBar = true,
  }) async {
    if (_disposed) {
      AppLogger.warning('⚠️ Attempted async operation on disposed widget');
      return;
    }
    
    try {
      await operation();
    } catch (e) {
      final name = operationName ?? 'Async operation';
      AppLogger.error('❌ $name failed: $e');
      
      if (!_disposed && mounted && showErrorSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Safe Provider listener setup with automatic disposal
  void setupProviderListener<P extends ChangeNotifier>(
    void Function(P provider) listener, {
    bool immediate = false,
  }) {
    P? provider;
    VoidCallback? removeListener;
    
    void setupListener() {
      if (_disposed) return;
      
      provider = context.tryProvider<P>();
      if (provider != null) {
        void wrappedListener() {
          if (!_disposed && mounted) {
            listener(provider!);
          }
        }
        
        provider!.addListener(wrappedListener);
        removeListener = () => provider?.removeListener(wrappedListener);
        
        if (immediate) {
          wrappedListener();
        }
      }
    }
    
    // Setup listener in next frame to ensure Provider is available
    WidgetsBinding.instance.addPostFrameCallback((_) => setupListener());
    
    // Store cleanup function for disposal
    _cleanupCallbacks.add(() => removeListener?.call());
  }
  
  final List<VoidCallback> _cleanupCallbacks = [];
  
  @override
  void dispose() {
    // Execute all cleanup callbacks
    for (final cleanup in _cleanupCallbacks) {
      try {
        cleanup();
      } catch (e) {
        AppLogger.warning('⚠️ Error during cleanup: $e');
      }
    }
    _cleanupCallbacks.clear();

    _disposed = true;
    super.dispose();
  }
}
