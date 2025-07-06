import 'package:flutter/foundation.dart';
import '../models/electronic_payment_model.dart';
import '../models/payment_account_model.dart';
import '../models/wallet_payment_option_model.dart';
import '../services/electronic_payment_service.dart';
import '../services/electronic_wallet_service.dart';
import '../providers/wallet_provider.dart';
import '../providers/electronic_wallet_provider.dart';
import '../utils/app_logger.dart';

/// Provider for managing electronic payment state and operations
class ElectronicPaymentProvider with ChangeNotifier {
  final ElectronicPaymentService _paymentService = ElectronicPaymentService();
  final ElectronicWalletService _walletService = ElectronicWalletService();

  // Import other providers for wallet balance synchronization
  static WalletProvider? _walletProvider;
  static ElectronicWalletProvider? _electronicWalletProvider;

  /// Set wallet providers for balance synchronization
  static void setWalletProviders({
    WalletProvider? walletProvider,
    ElectronicWalletProvider? electronicWalletProvider,
  }) {
    _walletProvider = walletProvider;
    _electronicWalletProvider = electronicWalletProvider;
  }

  // State variables
  List<ElectronicPaymentModel> _payments = [];
  List<ElectronicPaymentModel> _clientPayments = [];
  List<PaymentAccountModel> _paymentAccounts = [];
  List<PaymentAccountModel> _vodafoneAccounts = [];
  List<PaymentAccountModel> _instapayAccounts = [];

  // Wallet-based payment options (new system)
  List<WalletPaymentOptionModel> _walletPaymentOptions = [];
  List<WalletPaymentOptionModel> _vodafoneWalletOptions = [];
  List<WalletPaymentOptionModel> _instapayWalletOptions = [];

  Map<String, dynamic> _statistics = {};

  bool _isLoading = false;
  bool _isLoadingAccounts = false;
  bool _isLoadingStatistics = false;
  bool _isCreatingPayment = false;
  bool _isUpdatingPayment = false;
  String? _error;

  // Getters
  List<ElectronicPaymentModel> get payments => _payments;
  List<ElectronicPaymentModel> get clientPayments => _clientPayments;
  List<PaymentAccountModel> get paymentAccounts => _paymentAccounts;
  List<PaymentAccountModel> get vodafoneAccounts => _vodafoneAccounts;
  List<PaymentAccountModel> get instapayAccounts => _instapayAccounts;

  // Wallet-based payment options getters (new system)
  List<WalletPaymentOptionModel> get walletPaymentOptions => _walletPaymentOptions;
  List<WalletPaymentOptionModel> get vodafoneWalletOptions => _vodafoneWalletOptions;
  List<WalletPaymentOptionModel> get instapayWalletOptions => _instapayWalletOptions;

  Map<String, dynamic> get statistics => _statistics;

  bool get isLoading => _isLoading;
  bool get isLoadingAccounts => _isLoadingAccounts;
  bool get isLoadingStatistics => _isLoadingStatistics;
  bool get isCreatingPayment => _isCreatingPayment;
  bool get isUpdatingPayment => _isUpdatingPayment;
  String? get error => _error;

  // Statistics getters
  int get pendingPaymentsCount => (_statistics['pending_count'] as num?)?.toInt() ?? 0;
  int get approvedPaymentsCount => (_statistics['approved_count'] as num?)?.toInt() ?? 0;
  int get rejectedPaymentsCount => (_statistics['rejected_count'] as num?)?.toInt() ?? 0;
  double get totalApprovedAmount => (_statistics['total_approved_amount'] as num?)?.toDouble() ?? 0.0;

  /// Load payment accounts (legacy system)
  Future<void> loadPaymentAccounts() async {
    _setLoadingAccounts(true);
    _clearError();

    try {
      AppLogger.info('🔄 Loading payment accounts (legacy)');

      _paymentAccounts = await _paymentService.getActivePaymentAccounts();

      // Separate by type
      _vodafoneAccounts = _paymentAccounts
          .where((account) => account.accountType == 'vodafone_cash')
          .toList();
      _instapayAccounts = _paymentAccounts
          .where((account) => account.accountType == 'instapay')
          .toList();

      AppLogger.info('✅ Loaded ${_paymentAccounts.length} payment accounts (legacy)');
      AppLogger.info('📊 Vodafone: ${_vodafoneAccounts.length}, InstaPay: ${_instapayAccounts.length}');

    } catch (e) {
      _setError('فشل في تحميل حسابات الدفع: $e');
      AppLogger.error('❌ Error loading payment accounts: $e');
    } finally {
      _setLoadingAccounts(false);
    }
  }

  /// Load wallet payment options (new integrated system)
  Future<void> loadWalletPaymentOptions() async {
    _setLoadingAccounts(true);
    _clearError();

    try {
      AppLogger.info('🔄 Loading wallet payment options from electronic wallet system');

      // Get active wallets from the accountant-managed system
      final activeWallets = await _walletService.getActiveWalletsForPayments();

      // Convert to payment options
      _walletPaymentOptions = activeWallets
          .map((wallet) => WalletPaymentOptionModel.fromElectronicWallet(wallet))
          .toList();

      // Separate by type
      _vodafoneWalletOptions = _walletPaymentOptions
          .where((option) => option.accountType == 'vodafone_cash')
          .toList();
      _instapayWalletOptions = _walletPaymentOptions
          .where((option) => option.accountType == 'instapay')
          .toList();

      AppLogger.info('✅ Loaded ${_walletPaymentOptions.length} wallet payment options');
      AppLogger.info('📊 Vodafone Wallets: ${_vodafoneWalletOptions.length}, InstaPay Wallets: ${_instapayWalletOptions.length}');

      // Also update legacy accounts for backward compatibility
      _paymentAccounts = _walletPaymentOptions
          .map((option) => PaymentAccountModel.fromDatabase(option.toPaymentAccountFormat()))
          .toList();
      _vodafoneAccounts = _vodafoneWalletOptions
          .map((option) => PaymentAccountModel.fromDatabase(option.toPaymentAccountFormat()))
          .toList();
      _instapayAccounts = _instapayWalletOptions
          .map((option) => PaymentAccountModel.fromDatabase(option.toPaymentAccountFormat()))
          .toList();

    } catch (e) {
      AppLogger.error('❌ Error loading wallet payment options: $e');
      _setError('خطأ في تحميل خيارات الدفع: $e');

      // Fallback to legacy system
      AppLogger.info('🔄 Falling back to legacy payment accounts system');
      await loadPaymentAccounts();
    } finally {
      _setLoadingAccounts(false);
    }
  }

  /// Load client payments
  Future<void> loadClientPayments(String clientId) async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('🔄 Loading payments for client: $clientId');

      _clientPayments = await _paymentService.getClientPayments(clientId);

      AppLogger.info('✅ Loaded ${_clientPayments.length} client payments');

    } catch (e) {
      _setError('فشل في تحميل المدفوعات: $e');
      AppLogger.error('❌ Error loading client payments: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Get approved payments for a specific wallet
  Future<List<ElectronicPaymentModel>> getApprovedPaymentsForWallet(String walletId) async {
    _clearError();

    try {
      AppLogger.info('🔄 Getting approved payments for wallet: $walletId');
      final payments = await _paymentService.getApprovedPaymentsForWallet(walletId);
      AppLogger.info('✅ Retrieved ${payments.length} approved payments for wallet');
      return payments;
    } catch (e) {
      AppLogger.error('❌ Error getting approved payments for wallet: $e');
      _setError('خطأ في تحميل معاملات المحفظة: $e');
      return [];
    }
  }

  /// Get client wallet balance
  Future<double> getClientWalletBalance(String clientId) async {
    _clearError();

    try {
      AppLogger.info('🔄 Getting client wallet balance: $clientId');
      final balance = await _paymentService.getClientWalletBalance(clientId);
      AppLogger.info('✅ Retrieved client wallet balance: $balance EGP');
      return balance;
    } catch (e) {
      AppLogger.error('❌ Error getting client wallet balance: $e');
      _setError('خطأ في تحميل رصيد العميل: $e');
      return 0.0;
    }
  }

  /// Validate client wallet balance before payment approval
  Future<Map<String, dynamic>> validateClientWalletBalance(String clientId, double paymentAmount) async {
    _clearError();

    try {
      AppLogger.info('🔄 Validating client wallet balance: $clientId, amount: $paymentAmount');
      final validation = await _paymentService.validateClientWalletBalance(clientId, paymentAmount);
      AppLogger.info('✅ Balance validation completed: ${validation['isValid']}');
      return validation;
    } catch (e) {
      AppLogger.error('❌ Error validating client wallet balance: $e');
      _setError('خطأ في التحقق من رصيد العميل: $e');
      return {
        'isValid': false,
        'currentBalance': 0.0,
        'requiredAmount': paymentAmount,
        'remainingBalance': -paymentAmount,
        'message': 'خطأ في التحقق من رصيد العميل: $e'
      };
    }
  }

  /// Sync all electronic wallets with payment accounts
  Future<void> syncAllElectronicWalletsWithPaymentAccounts() async {
    _clearError();

    try {
      AppLogger.info('🔄 Syncing all electronic wallets with payment accounts');
      final syncedCount = await _paymentService.syncAllElectronicWalletsWithPaymentAccounts();
      AppLogger.info('✅ Synced $syncedCount electronic wallets with payment accounts');

      // Reload payment accounts to reflect changes
      await loadWalletPaymentOptions();
    } catch (e) {
      AppLogger.error('❌ Error syncing electronic wallets with payment accounts: $e');
      _setError('خطأ في مزامنة المحافظ الإلكترونية: $e');
    }
  }

  /// Load all payments for admin/accountant
  Future<void> loadAllPayments({
    ElectronicPaymentStatus? statusFilter,
    ElectronicPaymentMethod? methodFilter,
    int? limit,
    int? offset,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('🔄 Loading all payments for management');

      _payments = await _paymentService.getAllPayments(
        statusFilter: statusFilter,
        methodFilter: methodFilter,
        limit: limit,
        offset: offset,
      );

      AppLogger.info('✅ Loaded ${_payments.length} payments');

    } catch (e) {
      _setError('فشل في تحميل المدفوعات: $e');
      AppLogger.error('❌ Error loading all payments: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Create a new payment
  Future<ElectronicPaymentModel?> createPayment({
    required String clientId,
    required ElectronicPaymentMethod paymentMethod,
    required double amount,
    required String recipientAccountId,
    String? proofImageUrl,
    Map<String, dynamic>? metadata,
  }) async {
    _setCreatingPayment(true);
    _clearError();

    try {
      AppLogger.info('🔄 Creating payment for client: $clientId');

      final payment = await _paymentService.createPayment(
        clientId: clientId,
        paymentMethod: paymentMethod,
        amount: amount,
        recipientAccountId: recipientAccountId,
        proofImageUrl: proofImageUrl,
        metadata: metadata,
      );

      // Add to client payments list
      _clientPayments.insert(0, payment);

      AppLogger.info('✅ Created payment: ${payment.id}');
      return payment;

    } catch (e) {
      _setError('فشل في إنشاء الدفعة: $e');
      AppLogger.error('❌ Error creating payment: $e');
      return null;
    } finally {
      _setCreatingPayment(false);
    }
  }

  /// Update payment status (approve/reject)
  Future<bool> updatePaymentStatus({
    required String paymentId,
    required ElectronicPaymentStatus status,
    required String approvedBy,
    String? adminNotes,
  }) async {
    _setUpdatingPayment(true);
    _clearError();

    try {
      AppLogger.info('🔄 Updating payment status: $paymentId');

      final updatedPayment = await _paymentService.updatePaymentStatus(
        paymentId: paymentId,
        status: status,
        approvedBy: approvedBy,
        adminNotes: adminNotes,
      );

      // Update in payments list
      final index = _payments.indexWhere((p) => p.id == paymentId);
      if (index != -1) {
        _payments[index] = updatedPayment;
      }

      // Update in client payments list
      final clientIndex = _clientPayments.indexWhere((p) => p.id == paymentId);
      if (clientIndex != -1) {
        _clientPayments[clientIndex] = updatedPayment;
      }

      // 🔥 NEW: Trigger wallet balance refresh after successful payment approval
      if (status == ElectronicPaymentStatus.approved) {
        await _refreshWalletBalancesAfterPaymentApproval(updatedPayment);
      }

      AppLogger.info('✅ Updated payment status: ${updatedPayment.id}');
      return true;

    } catch (e) {
      _setError('فشل في تحديث حالة الدفعة: $e');
      AppLogger.error('❌ Error updating payment status: $e');
      return false;
    } finally {
      _setUpdatingPayment(false);
    }
  }

  /// Refresh wallet balances after payment approval
  Future<void> _refreshWalletBalancesAfterPaymentApproval(ElectronicPaymentModel payment) async {
    try {
      AppLogger.info('🔄 Refreshing wallet balances after payment approval: ${payment.id}');

      // Refresh main wallet provider (for client and business wallets)
      if (_walletProvider != null) {
        AppLogger.info('🔄 Refreshing main wallet provider...');
        await _walletProvider!.refreshAll();
        AppLogger.info('✅ Main wallet provider refreshed');
      }

      // Refresh electronic wallet provider
      if (_electronicWalletProvider != null) {
        AppLogger.info('🔄 Refreshing electronic wallet provider...');
        await _electronicWalletProvider!.loadWallets();
        await _electronicWalletProvider!.loadAllTransactions();
        AppLogger.info('✅ Electronic wallet provider refreshed');
      }

      // Force UI update by notifying listeners
      notifyListeners();

      AppLogger.info('✅ Wallet balance synchronization completed for payment: ${payment.id}');
      AppLogger.info('💰 Client should now see updated balance after ${payment.amount} EGP deduction');

    } catch (e) {
      AppLogger.error('❌ Error refreshing wallet balances after payment approval: $e');
      // Don't throw error as payment was successful, just log the sync issue
    }
  }

  /// Update payment proof
  Future<ElectronicPaymentModel?> updatePaymentProof({
    required String paymentId,
    required String proofImageUrl,
  }) async {
    _setUpdatingPayment(true);
    _clearError();

    try {
      AppLogger.info('🔄 Updating payment proof: $paymentId');

      final updatedPayment = await _paymentService.updatePaymentProof(
        paymentId: paymentId,
        proofImageUrl: proofImageUrl,
      );

      // Update in client payments list
      final clientIndex = _clientPayments.indexWhere((p) => p.id == paymentId);
      if (clientIndex != -1) {
        _clientPayments[clientIndex] = updatedPayment;
      }

      // Update in all payments list
      final allIndex = _payments.indexWhere((p) => p.id == paymentId);
      if (allIndex != -1) {
        _payments[allIndex] = updatedPayment;
      }

      AppLogger.info('✅ Updated payment proof: ${updatedPayment.id}');
      return updatedPayment;

    } catch (e) {
      _setError('فشل في تحديث إثبات الدفع: $e');
      AppLogger.error('❌ Error updating payment proof: $e');
      return null;
    } finally {
      _setUpdatingPayment(false);
    }
  }

  /// Load payment statistics
  Future<void> loadStatistics() async {
    _setLoadingStatistics(true);
    _clearError();

    try {
      AppLogger.info('🔄 Loading payment statistics');

      _statistics = await _paymentService.getPaymentStatistics();

      AppLogger.info('✅ Loaded payment statistics');

    } catch (e) {
      _setError('فشل في تحميل الإحصائيات: $e');
      AppLogger.error('❌ Error loading statistics: $e');
    } finally {
      _setLoadingStatistics(false);
    }
  }

  /// Get payments by status
  List<ElectronicPaymentModel> getPaymentsByStatus(ElectronicPaymentStatus status) {
    return _payments.where((payment) => payment.status == status).toList();
  }

  /// Get payments by method
  List<ElectronicPaymentModel> getPaymentsByMethod(ElectronicPaymentMethod method) {
    return _payments.where((payment) => payment.paymentMethod == method).toList();
  }

  /// Admin functions for managing payment accounts

  /// Load all payment accounts (admin only)
  Future<void> loadAllPaymentAccounts() async {
    _setLoadingAccounts(true);
    _clearError();

    try {
      AppLogger.info('🔄 Loading all payment accounts for admin');

      _paymentAccounts = await _paymentService.getAllPaymentAccounts();

      AppLogger.info('✅ Loaded ${_paymentAccounts.length} payment accounts');

    } catch (e) {
      _setError('فشل في تحميل حسابات الدفع: $e');
      AppLogger.error('❌ Error loading all payment accounts: $e');
    } finally {
      _setLoadingAccounts(false);
    }
  }

  /// Create payment account (admin only)
  Future<bool> createPaymentAccount({
    required String accountType,
    required String accountNumber,
    required String accountHolderName,
    bool isActive = true,
  }) async {
    _setLoadingAccounts(true);
    _clearError();

    try {
      AppLogger.info('🔄 Creating payment account');

      final account = await _paymentService.createPaymentAccount(
        accountType: accountType,
        accountNumber: accountNumber,
        accountHolderName: accountHolderName,
        isActive: isActive,
      );

      _paymentAccounts.add(account);

      AppLogger.info('✅ Created payment account: ${account.id}');
      return true;

    } catch (e) {
      _setError('فشل في إنشاء حساب الدفع: $e');
      AppLogger.error('❌ Error creating payment account: $e');
      return false;
    } finally {
      _setLoadingAccounts(false);
    }
  }

  /// Update payment account (admin only)
  Future<bool> updatePaymentAccount({
    required String accountId,
    String? accountNumber,
    String? accountHolderName,
    bool? isActive,
  }) async {
    _setLoadingAccounts(true);
    _clearError();

    try {
      AppLogger.info('🔄 Updating payment account: $accountId');

      final updatedAccount = await _paymentService.updatePaymentAccount(
        accountId: accountId,
        accountNumber: accountNumber,
        accountHolderName: accountHolderName,
        isActive: isActive,
      );

      final index = _paymentAccounts.indexWhere((a) => a.id == accountId);
      if (index != -1) {
        _paymentAccounts[index] = updatedAccount;
      }

      AppLogger.info('✅ Updated payment account: ${updatedAccount.id}');
      return true;

    } catch (e) {
      _setError('فشل في تحديث حساب الدفع: $e');
      AppLogger.error('❌ Error updating payment account: $e');
      return false;
    } finally {
      _setLoadingAccounts(false);
    }
  }

  /// Delete payment account (admin only)
  Future<bool> deletePaymentAccount(String accountId) async {
    _setLoadingAccounts(true);
    _clearError();

    try {
      AppLogger.info('🔄 Deleting payment account: $accountId');

      await _paymentService.deletePaymentAccount(accountId);

      _paymentAccounts.removeWhere((a) => a.id == accountId);

      AppLogger.info('✅ Deleted payment account: $accountId');
      return true;

    } catch (e) {
      _setError('فشل في حذف حساب الدفع: $e');
      AppLogger.error('❌ Error deleting payment account: $e');
      return false;
    } finally {
      _setLoadingAccounts(false);
    }
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setLoadingAccounts(bool loading) {
    _isLoadingAccounts = loading;
    notifyListeners();
  }

  void _setLoadingStatistics(bool loading) {
    _isLoadingStatistics = loading;
    notifyListeners();
  }

  void _setCreatingPayment(bool creating) {
    _isCreatingPayment = creating;
    notifyListeners();
  }

  void _setUpdatingPayment(bool updating) {
    _isUpdatingPayment = updating;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  /// Clear all data
  void clear() {
    _payments.clear();
    _clientPayments.clear();
    _paymentAccounts.clear();
    _vodafoneAccounts.clear();
    _instapayAccounts.clear();

    // Clear wallet payment options
    _walletPaymentOptions.clear();
    _vodafoneWalletOptions.clear();
    _instapayWalletOptions.clear();

    _statistics.clear();
    _error = null;
    _isLoading = false;
    _isLoadingAccounts = false;
    _isLoadingStatistics = false;
    _isCreatingPayment = false;
    _isUpdatingPayment = false;
    notifyListeners();
  }
}
