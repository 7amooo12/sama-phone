import 'package:flutter/foundation.dart';
import '../models/electronic_wallet_model.dart';
import '../models/electronic_wallet_transaction_model.dart';
import '../services/electronic_wallet_service.dart';
import '../utils/app_logger.dart';

/// Provider for managing electronic wallets state
class ElectronicWalletProvider with ChangeNotifier {
  final ElectronicWalletService _walletService = ElectronicWalletService();

  // State variables
  List<ElectronicWalletModel> _wallets = [];
  List<ElectronicWalletTransactionModel> _transactions = [];
  Map<String, dynamic> _statistics = {};
  
  bool _isLoading = false;
  bool _isCreatingWallet = false;
  bool _isUpdatingWallet = false;
  String? _error;

  // Getters
  List<ElectronicWalletModel> get wallets => _wallets;
  List<ElectronicWalletTransactionModel> get transactions => _transactions;
  Map<String, dynamic> get statistics => _statistics;
  
  bool get isLoading => _isLoading;
  bool get isCreatingWallet => _isCreatingWallet;
  bool get isUpdatingWallet => _isUpdatingWallet;
  String? get error => _error;

  // Filtered getters
  List<ElectronicWalletModel> get vodafoneWallets => 
      _wallets.where((w) => w.walletType == ElectronicWalletType.vodafoneCash).toList();
  
  List<ElectronicWalletModel> get instapayWallets => 
      _wallets.where((w) => w.walletType == ElectronicWalletType.instaPay).toList();
  
  List<ElectronicWalletModel> get activeWallets => 
      _wallets.where((w) => w.isActive).toList();

  // Statistics getters
  int get totalWallets => (_statistics['total_wallets'] as num?)?.toInt() ?? 0;
  int get activeWalletsCount => (_statistics['active_wallets'] as num?)?.toInt() ?? 0;
  int get vodafoneWalletsCount => (_statistics['vodafone_wallets'] as num?)?.toInt() ?? 0;
  int get instapayWalletsCount => (_statistics['instapay_wallets'] as num?)?.toInt() ?? 0;
  double get totalBalance => (_statistics['total_balance'] as num?)?.toDouble() ?? 0.0;
  double get vodafoneBalance => (_statistics['vodafone_balance'] as num?)?.toDouble() ?? 0.0;
  double get instapayBalance => (_statistics['instapay_balance'] as num?)?.toDouble() ?? 0.0;
  int get totalTransactions => (_statistics['total_transactions'] as num?)?.toInt() ?? 0;
  int get completedTransactions => (_statistics['completed_transactions'] as num?)?.toInt() ?? 0;
  int get pendingTransactions => (_statistics['pending_transactions'] as num?)?.toInt() ?? 0;

  /// Load all wallets
  Future<void> loadWallets() async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('🔄 Loading electronic wallets');
      _wallets = await _walletService.getAllWallets();
      AppLogger.info('✅ Loaded ${_wallets.length} electronic wallets');
    } catch (e) {
      AppLogger.error('❌ Error loading wallets: $e');
      _setError('خطأ في تحميل المحافظ: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load wallets by type
  Future<void> loadWalletsByType(ElectronicWalletType type) async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('🔄 Loading wallets by type: $type');
      _wallets = await _walletService.getWalletsByType(type);
      AppLogger.info('✅ Loaded ${_wallets.length} wallets of type: $type');
    } catch (e) {
      AppLogger.error('❌ Error loading wallets by type: $e');
      _setError('خطأ في تحميل المحافظ: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load active wallets only
  Future<void> loadActiveWallets() async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('🔄 Loading active wallets');
      _wallets = await _walletService.getActiveWallets();
      AppLogger.info('✅ Loaded ${_wallets.length} active wallets');
    } catch (e) {
      AppLogger.error('❌ Error loading active wallets: $e');
      _setError('خطأ في تحميل المحافظ النشطة: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load active wallets for client payments
  Future<void> loadActiveWalletsForPayments() async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('🔄 Loading active wallets for client payments');
      _wallets = await _walletService.getActiveWalletsForPayments();
      AppLogger.info('✅ Loaded ${_wallets.length} active wallets for payments');
    } catch (e) {
      AppLogger.error('❌ Error loading wallets for payments: $e');
      _setError('خطأ في تحميل المحافظ للدفع: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Get active wallets by type for payments
  Future<List<ElectronicWalletModel>> getActiveWalletsByTypeForPayments(ElectronicWalletType walletType) async {
    try {
      AppLogger.info('🔄 Getting active wallets for type: $walletType');
      final wallets = await _walletService.getActiveWalletsByTypeForPayments(walletType);
      AppLogger.info('✅ Got ${wallets.length} active wallets for type: $walletType');
      return wallets;
    } catch (e) {
      AppLogger.error('❌ Error getting wallets by type for payments: $e');
      _setError('خطأ في تحميل المحافظ: $e');
      return [];
    }
  }

  /// Get Vodafone Cash wallets for payments
  List<ElectronicWalletModel> get vodafoneWalletsForPayments {
    return _wallets.where((wallet) =>
      wallet.walletType == ElectronicWalletType.vodafoneCash &&
      wallet.isActive
    ).toList();
  }

  /// Get InstaPay wallets for payments
  List<ElectronicWalletModel> get instapayWalletsForPayments {
    return _wallets.where((wallet) =>
      wallet.walletType == ElectronicWalletType.instaPay &&
      wallet.isActive
    ).toList();
  }

  /// Create a new wallet
  Future<ElectronicWalletModel?> createWallet({
    required ElectronicWalletType walletType,
    required String phoneNumber,
    required String walletName,
    double initialBalance = 0.0,
    ElectronicWalletStatus status = ElectronicWalletStatus.active,
    String? description,
    String? createdBy,
  }) async {
    _setCreatingWallet(true);
    _clearError();

    try {
      AppLogger.info('🔄 Creating wallet: $walletName');

      final wallet = await _walletService.createWallet(
        walletType: walletType,
        phoneNumber: phoneNumber,
        walletName: walletName,
        initialBalance: initialBalance,
        status: status,
        description: description,
        createdBy: createdBy,
      );

      if (wallet != null) {
        _wallets.insert(0, wallet);
        AppLogger.info('✅ Created wallet: ${wallet.id}');
        notifyListeners();
        return wallet;
      } else {
        _setError('فشل في إنشاء المحفظة');
        return null;
      }
    } catch (e) {
      AppLogger.error('❌ Error creating wallet: $e');
      _setError('خطأ في إنشاء المحفظة: $e');
      return null;
    } finally {
      _setCreatingWallet(false);
    }
  }

  /// Update wallet
  Future<ElectronicWalletModel?> updateWallet({
    required String walletId,
    String? walletName,
    ElectronicWalletStatus? status,
    String? description,
  }) async {
    _setUpdatingWallet(true);
    _clearError();

    try {
      AppLogger.info('🔄 Updating wallet: $walletId');

      final updatedWallet = await _walletService.updateWallet(
        walletId: walletId,
        walletName: walletName,
        status: status,
        description: description,
      );

      if (updatedWallet != null) {
        final index = _wallets.indexWhere((w) => w.id == walletId);
        if (index != -1) {
          _wallets[index] = updatedWallet;
          AppLogger.info('✅ Updated wallet: ${updatedWallet.id}');
          notifyListeners();
          return updatedWallet;
        }
      } else {
        _setError('فشل في تحديث المحفظة');
      }
      return null;
    } catch (e) {
      AppLogger.error('❌ Error updating wallet: $e');
      _setError('خطأ في تحديث المحفظة: $e');
      return null;
    } finally {
      _setUpdatingWallet(false);
    }
  }

  /// Delete wallet
  Future<bool> deleteWallet(String walletId) async {
    _clearError();

    try {
      AppLogger.info('🔄 Deleting wallet: $walletId');

      final success = await _walletService.deleteWallet(walletId);

      if (success) {
        _wallets.removeWhere((w) => w.id == walletId);
        AppLogger.info('✅ Deleted wallet: $walletId');
        notifyListeners();
        return true;
      } else {
        _setError('فشل في حذف المحفظة');
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ Error deleting wallet: $e');
      _setError('خطأ في حذف المحفظة: $e');
      return false;
    }
  }

  /// Load wallet transactions
  Future<void> loadWalletTransactions(String walletId) async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('🔄 Loading transactions for wallet: $walletId');
      _transactions = await _walletService.getWalletTransactions(walletId);
      AppLogger.info('✅ Loaded ${_transactions.length} transactions');
    } catch (e) {
      AppLogger.error('❌ Error loading wallet transactions: $e');
      _setError('خطأ في تحميل معاملات المحفظة: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load all transactions
  Future<void> loadAllTransactions() async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('🔄 Loading all transactions');
      _transactions = await _walletService.getAllTransactions();
      AppLogger.info('✅ Loaded ${_transactions.length} transactions');
    } catch (e) {
      AppLogger.error('❌ Error loading all transactions: $e');
      _setError('خطأ في تحميل المعاملات: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Update wallet balance
  Future<String?> updateWalletBalance({
    required String walletId,
    required double amount,
    required ElectronicWalletTransactionType transactionType,
    String? description,
    String? referenceId,
    String? paymentId,
    String? processedBy,
  }) async {
    _clearError();

    try {
      AppLogger.info('🔄 Updating wallet balance: $walletId');

      final transactionId = await _walletService.updateWalletBalance(
        walletId: walletId,
        amount: amount,
        transactionType: transactionType,
        description: description,
        referenceId: referenceId,
        paymentId: paymentId,
        processedBy: processedBy,
      );

      if (transactionId != null) {
        // Refresh wallet data
        await loadWallets();
        AppLogger.info('✅ Updated wallet balance, transaction: $transactionId');
        return transactionId;
      } else {
        _setError('فشل في تحديث رصيد المحفظة');
        return null;
      }
    } catch (e) {
      AppLogger.error('❌ Error updating wallet balance: $e');
      _setError('خطأ في تحديث رصيد المحفظة: $e');
      return null;
    }
  }

  /// Load statistics
  Future<void> loadStatistics() async {
    _clearError();

    try {
      AppLogger.info('🔄 Loading wallet statistics');
      _statistics = await _walletService.getWalletStatistics();
      AppLogger.info('✅ Loaded wallet statistics');
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Error loading statistics: $e');
      _setError('خطأ في تحميل الإحصائيات: $e');
    }
  }

  /// Get wallet by ID
  ElectronicWalletModel? getWalletById(String walletId) {
    try {
      return _wallets.firstWhere((w) => w.id == walletId);
    } catch (e) {
      return null;
    }
  }

  /// Get transactions by wallet ID
  List<ElectronicWalletTransactionModel> getTransactionsByWalletId(String walletId) {
    return _transactions.where((t) => t.walletId == walletId).toList();
  }

  /// Clear all data
  void clearData() {
    _wallets.clear();
    _transactions.clear();
    _statistics.clear();
    _clearError();
    notifyListeners();
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setCreatingWallet(bool creating) {
    _isCreatingWallet = creating;
    notifyListeners();
  }

  void _setUpdatingWallet(bool updating) {
    _isUpdatingWallet = updating;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
