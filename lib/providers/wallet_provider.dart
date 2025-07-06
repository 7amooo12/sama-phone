import 'package:flutter/foundation.dart';
import '../models/wallet_model.dart';
import '../models/wallet_transaction_model.dart';
import '../services/wallet_service.dart';
import '../utils/app_logger.dart';

/// Provider for managing wallet state and operations
class WalletProvider with ChangeNotifier {
  // Lazy initialization to avoid accessing Supabase before it's initialized
  WalletService? _walletServiceInstance;
  WalletService get _walletService {
    _walletServiceInstance ??= WalletService();
    return _walletServiceInstance!;
  }

  // State variables
  List<WalletModel> _wallets = [];
  List<WalletModel> _clientWallets = [];
  List<WalletModel> _workerWallets = [];
  List<WalletTransactionModel> _transactions = [];
  WalletModel? _currentUserWallet;
  Map<String, dynamic> _statistics = {};
  
  bool _isLoading = false;
  bool _isLoadingTransactions = false;
  bool _isLoadingStatistics = false;
  String? _error;

  // Getters
  List<WalletModel> get wallets => _wallets;
  List<WalletModel> get clientWallets => _clientWallets;
  List<WalletModel> get workerWallets => _workerWallets;
  List<WalletTransactionModel> get transactions => _transactions;
  WalletModel? get currentUserWallet => _currentUserWallet;
  Map<String, dynamic> get statistics => _statistics;
  
  bool get isLoading => _isLoading;
  bool get isLoadingTransactions => _isLoadingTransactions;
  bool get isLoadingStatistics => _isLoadingStatistics;
  String? get error => _error;

  // Computed getters - Real-time calculations from current wallet data
  double get totalClientBalance {
    final total = _clientWallets.fold(0.0, (sum, wallet) => sum + wallet.balance);
    AppLogger.info('💰 Real-time client balance total: $total (from ${_clientWallets.length} wallets)');
    return total;
  }

  double get totalWorkerBalance {
    final total = _workerWallets.fold(0.0, (sum, wallet) => sum + wallet.balance);
    AppLogger.info('💰 Real-time worker balance total: $total (from ${_workerWallets.length} wallets)');
    return total;
  }

  int get activeClientCount => _clientWallets.where((w) => w.isActive).length;
  int get activeWorkerCount => _workerWallets.where((w) => w.isActive).length;

  /// Load all wallets (for admin/accountant/owner) with enhanced error handling
  Future<void> loadAllWallets() async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('🔄 Loading all wallets with enhanced error handling');

      // Clear existing data first
      _wallets.clear();
      _clientWallets.clear();
      _workerWallets.clear();

      _wallets = await _walletService.getAllWallets();

      if (_wallets.isEmpty) {
        AppLogger.warning('⚠️ No wallets loaded from database');
        _setError('لا توجد محافظ في النظام');
        return;
      }

      // Enhanced role-based separation with validation
      try {
        // Use enhanced filtering to ensure role consistency
        _clientWallets = await _walletService.getWalletsByRole('client');
        _workerWallets = await _walletService.getWalletsByRole('worker');

        AppLogger.info('✅ Successfully loaded wallets with enhanced role validation');
        AppLogger.info('📊 Breakdown - Clients: ${_clientWallets.length}, Workers: ${_workerWallets.length}');

        // Validate data integrity and check for role mismatches
        final totalValidatedWallets = _clientWallets.length + _workerWallets.length;
        final potentialMismatches = _wallets.length - totalValidatedWallets;

        if (potentialMismatches > 0) {
          AppLogger.warning('⚠️ Found $potentialMismatches wallets with potential role mismatches');
          AppLogger.warning('💡 These wallets may have inconsistent roles between user_profiles and wallets tables');
          AppLogger.warning('🔧 Consider running the wallet role consistency fix script');
        }

        // Update the main wallets list with validated data
        _wallets.clear();
        _wallets.addAll(_clientWallets);
        _wallets.addAll(_workerWallets);

      } catch (roleError) {
        AppLogger.error('❌ Error loading wallets with role validation: $roleError');

        // Provide more specific error handling for relationship issues
        String errorMessage = 'خطأ في تحميل المحافظ مع التحقق من الأدوار';
        if (roleError.toString().contains('PGRST200') ||
            roleError.toString().contains('relationship')) {
          errorMessage = 'خطأ في العلاقات بين جداول قاعدة البيانات - يرجى تشغيل migration';
          AppLogger.error('💡 Hint: Run the wallet relationship migration to fix this issue');
        }

        // Set empty lists to prevent null reference errors
        _clientWallets = [];
        _workerWallets = [];
        _setError(errorMessage);
      }

    } catch (e) {
      AppLogger.error('❌ Critical error loading wallets: $e');

      // Provide user-friendly error messages
      String userMessage = 'فشل في تحميل المحافظ';
      if (e.toString().contains('Failed to parse wallet data')) {
        userMessage = 'خطأ في بيانات المحافظ - يرجى التحقق من قاعدة البيانات';
      } else if (e.toString().contains('network')) {
        userMessage = 'خطأ في الاتصال - يرجى التحقق من الإنترنت';
      } else if (e.toString().contains('permission')) {
        userMessage = 'ليس لديك صلاحية للوصول إلى المحافظ';
      }

      _setError(userMessage);

      // Ensure lists are empty to prevent UI errors
      _wallets.clear();
      _clientWallets.clear();
      _workerWallets.clear();

    } finally {
      _setLoading(false);
    }
  }

  /// Load wallets by role with enhanced validation
  Future<void> loadWalletsByRole(String role) async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('🔄 Loading wallets for role: $role with enhanced validation');

      // Use enhanced role-based filtering
      final wallets = await _walletService.getWalletsByRole(role);

      if (role == 'client') {
        _clientWallets = wallets;
        AppLogger.info('✅ Loaded ${wallets.length} client wallets with role validation');
      } else if (role == 'worker') {
        _workerWallets = wallets;
        AppLogger.info('✅ Loaded ${wallets.length} worker wallets with role validation');
      }

      // Validate that all loaded wallets have the correct role
      final invalidWallets = wallets.where((w) => w.role != role).toList();
      if (invalidWallets.isNotEmpty) {
        AppLogger.warning('⚠️ Found ${invalidWallets.length} wallets with incorrect role for $role');
        AppLogger.warning('🔧 Consider running the wallet role consistency fix script');
      }

    } catch (e) {
      _setError('فشل في تحميل محافظ $role: $e');
      AppLogger.error('❌ Error loading wallets by role: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load current user's wallet
  Future<void> loadUserWallet(String userId) async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('🔄 Loading wallet for user: $userId');
      
      _currentUserWallet = await _walletService.getUserWallet(userId);
      
      if (_currentUserWallet != null) {
        AppLogger.info('✅ Loaded user wallet: ${_currentUserWallet!.id}');
      } else {
        AppLogger.info('ℹ️ No wallet found for user: $userId');
      }
      
    } catch (e) {
      _setError('فشل في تحميل محفظة المستخدم: $e');
      AppLogger.error('❌ Error loading user wallet: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Create wallet for user
  Future<bool> createWallet({
    required String userId,
    required String role,
    double initialBalance = 0.0,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('🔄 Creating wallet for user: $userId, role: $role');
      
      final wallet = await _walletService.createWallet(
        userId: userId,
        role: role,
        initialBalance: initialBalance,
      );
      
      // Add to appropriate list
      if (role == 'client') {
        _clientWallets.add(wallet);
      } else if (role == 'worker') {
        _workerWallets.add(wallet);
      }
      _wallets.add(wallet);
      
      AppLogger.info('✅ Created wallet: ${wallet.id}');
      return true;
      
    } catch (e) {
      _setError('فشل في إنشاء المحفظة: $e');
      AppLogger.error('❌ Error creating wallet: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update wallet status
  Future<bool> updateWalletStatus(String walletId, WalletStatus status) async {
    _clearError();

    try {
      AppLogger.info('🔄 Updating wallet status: $walletId to $status');
      
      final success = await _walletService.updateWalletStatus(walletId, status);
      
      if (success) {
        // Update local state
        _updateWalletInLists(walletId, (wallet) => wallet.copyWith(status: status));
        AppLogger.info('✅ Updated wallet status');
      }
      
      return success;
      
    } catch (e) {
      _setError('فشل في تحديث حالة المحفظة: $e');
      AppLogger.error('❌ Error updating wallet status: $e');
      return false;
    }
  }

  /// Load wallet transactions
  Future<void> loadWalletTransactions(String walletId, {bool refresh = false}) async {
    if (!refresh) _setLoadingTransactions(true);
    _clearError();

    try {
      AppLogger.info('🔄 Loading transactions for wallet: $walletId');
      
      _transactions = await _walletService.getWalletTransactions(walletId);
      
      AppLogger.info('✅ Loaded ${_transactions.length} transactions');
      
    } catch (e) {
      _setError('فشل في تحميل المعاملات: $e');
      AppLogger.error('❌ Error loading transactions: $e');
    } finally {
      if (!refresh) _setLoadingTransactions(false);
    }
  }

  /// Load user transactions with enhanced error handling
  Future<void> loadUserTransactions(String userId, {bool refresh = false}) async {
    if (!refresh) _setLoadingTransactions(true);
    _clearError();

    try {
      AppLogger.info('🔄 Loading transactions for user: $userId (refresh: $refresh)');

      // Validate user ID
      if (userId.isEmpty) {
        throw Exception('User ID cannot be empty');
      }

      // Clear existing transactions if not refreshing
      if (!refresh) {
        _transactions.clear();
      }

      _transactions = await _walletService.getUserTransactions(userId);

      AppLogger.info('✅ Successfully loaded ${_transactions.length} user transactions');

      if (_transactions.isEmpty) {
        AppLogger.info('ℹ️ No transactions found for user: $userId');
      } else {
        // Log transaction summary
        final creditCount = _transactions.where((t) => t.isCredit).length;
        final debitCount = _transactions.where((t) => t.isDebit).length;
        AppLogger.info('📊 Transaction breakdown - Credits: $creditCount, Debits: $debitCount');
      }

    } catch (e) {
      AppLogger.error('❌ Error loading user transactions for $userId: $e');

      // Provide user-friendly error messages
      String userMessage = 'فشل في تحميل معاملات المستخدم';
      if (e.toString().contains('Failed to parse transaction data')) {
        userMessage = 'خطأ في بيانات المعاملات - يرجى التحقق من قاعدة البيانات';
      } else if (e.toString().contains('User ID cannot be empty')) {
        userMessage = 'معرف المستخدم غير صحيح';
      } else if (e.toString().contains('network')) {
        userMessage = 'خطأ في الاتصال - يرجى التحقق من الإنترنت';
      }

      _setError(userMessage);

      // Ensure transactions list is empty to prevent UI errors
      _transactions.clear();

    } finally {
      if (!refresh) _setLoadingTransactions(false);
    }
  }

  /// Create transaction
  Future<bool> createTransaction({
    required String walletId,
    required String userId,
    required TransactionType transactionType,
    required double amount,
    required String description,
    required String createdBy,
    String? referenceId,
    ReferenceType? referenceType,
    Map<String, dynamic>? metadata,
  }) async {
    _clearError();

    try {
      AppLogger.info('🔄 Creating transaction: $transactionType, amount: $amount');
      
      final transaction = await _walletService.createTransaction(
        walletId: walletId,
        userId: userId,
        transactionType: transactionType,
        amount: amount,
        description: description,
        createdBy: createdBy,
        referenceId: referenceId,
        referenceType: referenceType,
        metadata: metadata,
      );
      
      // Add to transactions list
      _transactions.insert(0, transaction);
      
      // Update wallet balance in local state
      final oldBalance = _getWalletBalance(walletId);
      _updateWalletInLists(walletId, (wallet) => wallet.copyWith(
        balance: transaction.balanceAfter,
        updatedAt: DateTime.now(),
      ));

      AppLogger.info('✅ Created transaction: ${transaction.id}');
      AppLogger.info('💰 Balance updated: $oldBalance → ${transaction.balanceAfter}');
      AppLogger.info('📊 New totals - Clients: $totalClientBalance, Workers: $totalWorkerBalance');

      return true;
      
    } catch (e) {
      _setError('فشل في إنشاء المعاملة: $e');
      AppLogger.error('❌ Error creating transaction: $e');
      return false;
    }
  }

  /// Load wallet statistics
  Future<void> loadStatistics() async {
    _setLoadingStatistics(true);
    _clearError();

    try {
      AppLogger.info('🔄 Loading wallet statistics');
      
      _statistics = await _walletService.getWalletStatistics();
      
      AppLogger.info('✅ Loaded wallet statistics');
      
    } catch (e) {
      _setError('فشل في تحميل الإحصائيات: $e');
      AppLogger.error('❌ Error loading statistics: $e');
    } finally {
      _setLoadingStatistics(false);
    }
  }

  /// Refresh all data
  Future<void> refreshAll() async {
    AppLogger.info('🔄 Refreshing all wallet data...');
    await Future.wait([
      loadAllWallets(),
      loadStatistics(),
    ]);
    AppLogger.info('✅ All wallet data refreshed');
    AppLogger.info('📊 Updated totals - Clients: $totalClientBalance, Workers: $totalWorkerBalance');
  }

  /// Force UI update (useful after balance changes)
  void forceUpdate() {
    AppLogger.info('🔄 Forcing UI update...');
    notifyListeners();
  }

  /// Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setLoadingTransactions(bool loading) {
    _isLoadingTransactions = loading;
    notifyListeners();
  }

  void _setLoadingStatistics(bool loading) {
    _isLoadingStatistics = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  double _getWalletBalance(String walletId) {
    // Find wallet in any list and return its current balance
    final wallet = _wallets.firstWhere(
      (w) => w.id == walletId,
      orElse: () => _clientWallets.firstWhere(
        (w) => w.id == walletId,
        orElse: () => _workerWallets.firstWhere(
          (w) => w.id == walletId,
          orElse: () => WalletModel(
            id: '',
            userId: '',
            balance: 0.0,
            role: '',
            status: WalletStatus.active,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ),
      ),
    );
    return wallet.balance;
  }

  void _updateWalletInLists(String walletId, WalletModel Function(WalletModel) updater) {
    // Update in main list
    final mainIndex = _wallets.indexWhere((w) => w.id == walletId);
    if (mainIndex != -1) {
      _wallets[mainIndex] = updater(_wallets[mainIndex]);
    }

    // Update in client list
    final clientIndex = _clientWallets.indexWhere((w) => w.id == walletId);
    if (clientIndex != -1) {
      _clientWallets[clientIndex] = updater(_clientWallets[clientIndex]);
    }

    // Update in worker list
    final workerIndex = _workerWallets.indexWhere((w) => w.id == walletId);
    if (workerIndex != -1) {
      _workerWallets[workerIndex] = updater(_workerWallets[workerIndex]);
    }
  }

  /// Validate wallet role consistency
  Future<Map<String, dynamic>> validateWalletRoleConsistency() async {
    try {
      AppLogger.info('🔍 Validating wallet role consistency from provider...');
      return await _walletService.validateWalletRoleConsistency();
    } catch (e) {
      AppLogger.error('❌ Error validating wallet role consistency: $e');
      _setError('فشل في التحقق من تطابق أدوار المحافظ: $e');
      rethrow;
    }
  }

  /// Fix wallet role inconsistencies and reload data
  Future<bool> fixWalletRoleInconsistencies() async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('🔧 Fixing wallet role inconsistencies...');

      final result = await _walletService.fixWalletRoleInconsistencies();

      if (result['success'] == true) {
        AppLogger.info('✅ Fixed ${result['total_fixes']} wallet role inconsistencies');

        // Reload all wallet data after fixing
        await loadAllWallets();

        return true;
      } else {
        _setError('فشل في إصلاح تطابق أدوار المحافظ');
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ Error fixing wallet role inconsistencies: $e');
      _setError('فشل في إصلاح تطابق أدوار المحافظ: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Clear all data
  void clear() {
    _wallets.clear();
    _clientWallets.clear();
    _workerWallets.clear();
    _transactions.clear();
    _currentUserWallet = null;
    _statistics.clear();
    _error = null;
    _isLoading = false;
    _isLoadingTransactions = false;
    _isLoadingStatistics = false;
    notifyListeners();
  }
}
