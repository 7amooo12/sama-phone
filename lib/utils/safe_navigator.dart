import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Safe navigation utility to prevent Navigator context errors during auth state transitions
class SafeNavigator {
  
  /// Safely push replacement route with context validation
  static Future<void> pushReplacementSafely(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) async {
    // Wait for current frame to complete to avoid navigation during rebuilds
    await WidgetsBinding.instance.endOfFrame;
    
    if (!context.mounted) {
      AppLogger.warning('⚠️ Context not mounted, skipping navigation to: $routeName');
      return;
    }
    
    try {
      AppLogger.info('🧭 Safe navigation: pushReplacement to $routeName');
      Navigator.of(context).pushReplacementNamed(routeName, arguments: arguments);
    } catch (e) {
      AppLogger.error('❌ Navigation error during pushReplacement to $routeName: $e');
    }
  }
  
  /// Safely push route with context validation
  static Future<void> pushSafely(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) async {
    await WidgetsBinding.instance.endOfFrame;
    
    if (!context.mounted) {
      AppLogger.warning('⚠️ Context not mounted, skipping navigation to: $routeName');
      return;
    }
    
    try {
      AppLogger.info('🧭 Safe navigation: push to $routeName');
      Navigator.of(context).pushNamed(routeName, arguments: arguments);
    } catch (e) {
      AppLogger.error('❌ Navigation error during push to $routeName: $e');
    }
  }
  
  /// Safely pop route with context validation
  static Future<void> popSafely(BuildContext context, [Object? result]) async {
    await WidgetsBinding.instance.endOfFrame;
    
    if (!context.mounted) {
      AppLogger.warning('⚠️ Context not mounted, skipping pop navigation');
      return;
    }
    
    try {
      if (Navigator.of(context).canPop()) {
        AppLogger.info('🧭 Safe navigation: pop');
        Navigator.of(context).pop(result);
      } else {
        AppLogger.warning('⚠️ Cannot pop, no routes in stack');
      }
    } catch (e) {
      AppLogger.error('❌ Navigation error during pop: $e');
    }
  }
  
  /// Safely push and remove until with context validation
  static Future<void> pushAndRemoveUntilSafely(
    BuildContext context,
    String routeName,
    bool Function(Route<dynamic>) predicate, {
    Object? arguments,
  }) async {
    await WidgetsBinding.instance.endOfFrame;
    
    if (!context.mounted) {
      AppLogger.warning('⚠️ Context not mounted, skipping navigation to: $routeName');
      return;
    }
    
    try {
      AppLogger.info('🧭 Safe navigation: pushAndRemoveUntil to $routeName');
      Navigator.of(context).pushNamedAndRemoveUntil(routeName, predicate, arguments: arguments);
    } catch (e) {
      AppLogger.error('❌ Navigation error during pushAndRemoveUntil to $routeName: $e');
    }
  }
  
  /// Check if context is safe for navigation
  static bool isContextSafeForNavigation(BuildContext context) {
    try {
      return context.mounted && Navigator.of(context, rootNavigator: false) != null;
    } catch (e) {
      AppLogger.warning('⚠️ Context not safe for navigation: $e');
      return false;
    }
  }
  
  /// Validate context and execute navigation callback safely
  static Future<void> executeWithSafeContext(
    BuildContext context,
    Future<void> Function() navigationCallback,
  ) async {
    await WidgetsBinding.instance.endOfFrame;
    
    if (!isContextSafeForNavigation(context)) {
      AppLogger.warning('⚠️ Context not safe for navigation, skipping callback');
      return;
    }
    
    try {
      await navigationCallback();
    } catch (e) {
      AppLogger.error('❌ Error executing navigation callback: $e');
    }
  }
}
