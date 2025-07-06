import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/client_orders_provider.dart';
import '../utils/app_logger.dart';

/// Service to initialize and connect providers for proper workflow integration
class ProviderInitializationService {
  static bool _isInitialized = false;

  /// Initialize provider connections for pricing approval workflow
  static void initializeProviders(BuildContext context) {
    if (_isInitialized) {
      AppLogger.info('🔗 Providers already initialized');
      return;
    }

    try {
      AppLogger.info('🔗 Initializing provider connections for pricing approval workflow...');

      // Get providers
      final appSettingsProvider = Provider.of<AppSettingsProvider>(context, listen: false);
      final clientOrdersProvider = Provider.of<ClientOrdersProvider>(context, listen: false);

      // Connect AppSettingsProvider to ClientOrdersProvider
      clientOrdersProvider.setAppSettingsProvider(appSettingsProvider);

      _isInitialized = true;
      AppLogger.info('✅ Provider connections initialized successfully');
    } catch (e) {
      AppLogger.error('❌ Failed to initialize provider connections: $e');
    }
  }

  /// Reset initialization state (for testing or app restart)
  static void reset() {
    _isInitialized = false;
    AppLogger.info('🔄 Provider initialization state reset');
  }

  /// Check if providers are initialized
  static bool get isInitialized => _isInitialized;
}
