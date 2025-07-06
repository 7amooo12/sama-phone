import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/electronic_wallet_provider.dart';
import '../providers/electronic_payment_provider.dart';
import '../utils/app_logger.dart';

/// Utility class for synchronizing wallet balances across the app
class WalletBalanceSync {
  static bool _isInitialized = false;

  /// Initialize wallet balance synchronization
  static void initialize(BuildContext context) {
    if (_isInitialized) return;

    try {
      // Get provider instances with safe access
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final electronicWalletProvider = Provider.of<ElectronicWalletProvider>(context, listen: false);

      // Set providers in ElectronicPaymentProvider for synchronization
      ElectronicPaymentProvider.setWalletProviders(
        walletProvider: walletProvider,
        electronicWalletProvider: electronicWalletProvider,
      );

      _isInitialized = true;
      AppLogger.info('✅ Wallet balance synchronization initialized');

    } catch (e) {
      AppLogger.error('❌ Failed to initialize wallet balance synchronization: $e');
      // Don't mark as initialized if it failed, so it can retry later
    }
  }

  /// Manually refresh all wallet balances
  static Future<void> refreshAllWalletBalances(BuildContext context) async {
    try {
      AppLogger.info('🔄 Manually refreshing all wallet balances...');

      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final electronicWalletProvider = Provider.of<ElectronicWalletProvider>(context, listen: false);

      // Refresh main wallets
      await walletProvider.refreshAll();
      AppLogger.info('✅ Main wallet balances refreshed');

      // Refresh electronic wallets
      await electronicWalletProvider.loadWallets();
      await electronicWalletProvider.loadAllTransactions();
      AppLogger.info('✅ Electronic wallet balances refreshed');

      AppLogger.info('🎉 All wallet balances refreshed successfully');
      
    } catch (e) {
      AppLogger.error('❌ Error refreshing wallet balances: $e');
      rethrow;
    }
  }

  /// Refresh wallet balances after a specific payment approval
  static Future<void> refreshAfterPaymentApproval({
    required BuildContext context,
    required String paymentId,
    required double amount,
    required String clientId,
  }) async {
    try {
      AppLogger.info('🔄 Refreshing wallet balances after payment approval: $paymentId');

      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final electronicWalletProvider = Provider.of<ElectronicWalletProvider>(context, listen: false);

      // Refresh specific client wallet
      await walletProvider.loadUserWallet(clientId);
      AppLogger.info('✅ Client wallet refreshed for user: $clientId');

      // Refresh all wallets (including business wallets)
      await walletProvider.refreshAll();
      AppLogger.info('✅ All wallets refreshed');

      // Refresh electronic wallet data
      await electronicWalletProvider.loadWallets();
      await electronicWalletProvider.loadAllTransactions();
      AppLogger.info('✅ Electronic wallet data refreshed');

      AppLogger.info('🎉 Wallet balance refresh completed for payment: $paymentId (amount: $amount EGP)');
      
    } catch (e) {
      AppLogger.error('❌ Error refreshing wallet balances after payment approval: $e');
      // Don't rethrow as payment was successful, just log the sync issue
    }
  }

  /// Check if wallet balance synchronization is properly initialized
  static bool get isInitialized => _isInitialized;

  /// Reset initialization state (for testing)
  @visibleForTesting
  static void reset() {
    _isInitialized = false;
  }
}

/// Extension to add wallet balance refresh capabilities to BuildContext
extension WalletBalanceSyncExtension on BuildContext {
  /// Refresh all wallet balances from this context
  Future<void> refreshWalletBalances() async {
    await WalletBalanceSync.refreshAllWalletBalances(this);
  }

  /// Refresh wallet balances after payment approval
  Future<void> refreshWalletBalancesAfterPayment({
    required String paymentId,
    required double amount,
    required String clientId,
  }) async {
    await WalletBalanceSync.refreshAfterPaymentApproval(
      context: this,
      paymentId: paymentId,
      amount: amount,
      clientId: clientId,
    );
  }

  /// Initialize wallet balance synchronization from this context
  void initializeWalletSync() {
    WalletBalanceSync.initialize(this);
  }
}
