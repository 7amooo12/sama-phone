import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/electronic_wallet_model.dart';
import '../models/electronic_wallet_transaction_model.dart';
import '../utils/app_logger.dart';

/// Service for managing electronic wallets (Vodafone Cash & InstaPay)
class ElectronicWalletService {

  ElectronicWalletService() {
    _walletsTable = _supabase.from('electronic_wallets');
    _transactionsTable = _supabase.from('electronic_wallet_transactions');
  }
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Table references
  late final SupabaseQueryBuilder _walletsTable;
  late final SupabaseQueryBuilder _transactionsTable;

  /// Get all electronic wallets
  Future<List<ElectronicWalletModel>> getAllWallets() async {
    try {
      AppLogger.info('🔄 Fetching all electronic wallets');

      final response = await _walletsTable
          .select()
          .order('created_at', ascending: false);

      final wallets = (response as List)
          .map((data) => ElectronicWalletModel.fromDatabase(data))
          .toList();

      AppLogger.info('✅ Fetched ${wallets.length} electronic wallets');
      return wallets;
    } catch (e) {
      AppLogger.error('❌ Error fetching electronic wallets: $e');
      return [];
    }
  }

  /// Get wallets by type
  Future<List<ElectronicWalletModel>> getWalletsByType(ElectronicWalletType type) async {
    try {
      AppLogger.info('🔄 Fetching wallets by type: $type');

      final typeString = type == ElectronicWalletType.vodafoneCash ? 'vodafone_cash' : 'instapay';
      
      final response = await _walletsTable
          .select()
          .eq('wallet_type', typeString)
          .order('created_at', ascending: false);

      final wallets = (response as List)
          .map((data) => ElectronicWalletModel.fromDatabase(data))
          .toList();

      AppLogger.info('✅ Fetched ${wallets.length} $typeString wallets');
      return wallets;
    } catch (e) {
      AppLogger.error('❌ Error fetching wallets by type: $e');
      return [];
    }
  }

  /// Get active wallets only
  Future<List<ElectronicWalletModel>> getActiveWallets() async {
    try {
      AppLogger.info('🔄 Fetching active electronic wallets');

      final response = await _walletsTable
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false);

      final wallets = (response as List)
          .map((data) => ElectronicWalletModel.fromDatabase(data))
          .toList();

      AppLogger.info('✅ Fetched ${wallets.length} active electronic wallets');
      return wallets;
    } catch (e) {
      AppLogger.error('❌ Error fetching active electronic wallets: $e');
      return [];
    }
  }

  /// Get active wallets for client payment options
  /// This method provides wallets that clients can use for payments
  Future<List<ElectronicWalletModel>> getActiveWalletsForPayments() async {
    try {
      AppLogger.info('🔄 Fetching active electronic wallets for client payments');

      final response = await _walletsTable
          .select()
          .eq('status', 'active')
          .order('wallet_type')
          .order('wallet_name');

      final wallets = (response as List)
          .map((data) => ElectronicWalletModel.fromDatabase(data))
          .toList();

      AppLogger.info('✅ Fetched ${wallets.length} active wallets for payments');
      AppLogger.info('📊 Vodafone Cash: ${wallets.where((w) => w.walletType == ElectronicWalletType.vodafoneCash).length}, InstaPay: ${wallets.where((w) => w.walletType == ElectronicWalletType.instaPay).length}');

      return wallets;
    } catch (e) {
      AppLogger.error('❌ Error fetching wallets for payments: $e');
      throw Exception('Failed to fetch wallets for payments: $e');
    }
  }

  /// Get active wallets by type for client payments
  Future<List<ElectronicWalletModel>> getActiveWalletsByTypeForPayments(ElectronicWalletType walletType) async {
    try {
      AppLogger.info('🔄 Fetching active wallets for type: $walletType');

      final typeString = walletType == ElectronicWalletType.vodafoneCash ? 'vodafone_cash' : 'instapay';

      final response = await _walletsTable
          .select()
          .eq('status', 'active')
          .eq('wallet_type', typeString)
          .order('wallet_name');

      final wallets = (response as List)
          .map((data) => ElectronicWalletModel.fromDatabase(data))
          .toList();

      AppLogger.info('✅ Fetched ${wallets.length} active wallets for type: $walletType');
      return wallets;
    } catch (e) {
      AppLogger.error('❌ Error fetching wallets by type for payments: $e');
      throw Exception('Failed to fetch wallets by type for payments: $e');
    }
  }

  /// Create a new electronic wallet
  Future<ElectronicWalletModel?> createWallet({
    required ElectronicWalletType walletType,
    required String phoneNumber,
    required String walletName,
    double initialBalance = 0.0,
    ElectronicWalletStatus status = ElectronicWalletStatus.active,
    String? description,
    String? createdBy,
  }) async {
    try {
      AppLogger.info('🔄 Creating new electronic wallet: $walletName');

      // Validate phone number
      if (!ElectronicWalletModel.isValidEgyptianPhoneNumber(phoneNumber)) {
        throw Exception('رقم الهاتف غير صالح. يجب أن يكون رقم مصري صحيح');
      }

      final accountType = walletType == ElectronicWalletType.vodafoneCash ? 'vodafone_cash' : 'instapay';

      // Check for existing payment account with same type and number
      await _cleanupOrphanedPaymentAccount(accountType, phoneNumber);

      final walletData = {
        'wallet_type': accountType,
        'phone_number': phoneNumber,
        'wallet_name': walletName,
        'current_balance': initialBalance,
        'status': _statusToString(status),
        'description': description,
        'created_by': createdBy,
      };

      final response = await _walletsTable
          .insert(walletData)
          .select()
          .single();

      final wallet = ElectronicWalletModel.fromDatabase(response);

      // Automatically create corresponding payment account
      await _createPaymentAccountForWallet(wallet);

      AppLogger.info('✅ Created electronic wallet with payment account: ${wallet.id}');
      return wallet;
    } catch (e) {
      AppLogger.error('❌ Error creating electronic wallet: $e');
      return null;
    }
  }

  /// Create payment account for electronic wallet
  Future<void> _createPaymentAccountForWallet(ElectronicWalletModel wallet) async {
    try {
      AppLogger.info('🔄 Creating payment account for wallet: ${wallet.id}');

      // Check if payment account already exists
      final existingAccount = await _supabase
          .from('payment_accounts')
          .select('id')
          .eq('id', wallet.id)
          .maybeSingle();

      if (existingAccount != null) {
        AppLogger.info('ℹ️ Payment account already exists for wallet: ${wallet.id}');
        return;
      }

      final accountData = {
        'id': wallet.id, // Use same ID as wallet
        'account_type': wallet.walletType == ElectronicWalletType.vodafoneCash ? 'vodafone_cash' : 'instapay',
        'account_number': wallet.phoneNumber,
        'account_holder_name': wallet.walletName,
        'is_active': wallet.status == ElectronicWalletStatus.active,
        'created_at': wallet.createdAt.toIso8601String(),
        'updated_at': wallet.updatedAt.toIso8601String(),
      };

      await _supabase
          .from('payment_accounts')
          .insert(accountData);

      AppLogger.info('✅ Created payment account for wallet: ${wallet.id}');
    } catch (e) {
      AppLogger.error('❌ Error creating payment account for wallet: $e');
      // Don't throw here as the wallet was already created successfully
    }
  }

  /// Update electronic wallet
  Future<ElectronicWalletModel?> updateWallet({
    required String walletId,
    String? walletName,
    ElectronicWalletStatus? status,
    String? description,
  }) async {
    try {
      AppLogger.info('🔄 Updating electronic wallet: $walletId');

      final updateData = <String, dynamic>{};
      
      if (walletName != null) updateData['wallet_name'] = walletName;
      if (status != null) updateData['status'] = _statusToString(status);
      if (description != null) updateData['description'] = description;

      if (updateData.isEmpty) {
        throw Exception('لا توجد بيانات للتحديث');
      }

      final response = await _walletsTable
          .update(updateData)
          .eq('id', walletId)
          .select()
          .single();

      final wallet = ElectronicWalletModel.fromDatabase(response);

      // Sync payment account with updated wallet data
      await _syncPaymentAccountWithWallet(wallet);

      AppLogger.info('✅ Updated electronic wallet and synced payment account: ${wallet.id}');
      return wallet;
    } catch (e) {
      AppLogger.error('❌ Error updating electronic wallet: $e');
      return null;
    }
  }

  /// Sync payment account with wallet data
  Future<void> _syncPaymentAccountWithWallet(ElectronicWalletModel wallet) async {
    try {
      AppLogger.info('🔄 Syncing payment account with wallet: ${wallet.id}');

      final accountData = {
        'account_type': wallet.walletType == ElectronicWalletType.vodafoneCash ? 'vodafone_cash' : 'instapay',
        'account_number': wallet.phoneNumber,
        'account_holder_name': wallet.walletName,
        'is_active': wallet.status == ElectronicWalletStatus.active,
        'updated_at': wallet.updatedAt.toIso8601String(),
      };

      await _supabase
          .from('payment_accounts')
          .upsert({
            'id': wallet.id,
            ...accountData,
            'created_at': wallet.createdAt.toIso8601String(),
          });

      AppLogger.info('✅ Synced payment account with wallet: ${wallet.id}');
    } catch (e) {
      AppLogger.error('❌ Error syncing payment account with wallet: $e');
      // Don't throw here as the wallet update was successful
    }
  }

  /// Delete electronic wallet and its associated payment account
  Future<bool> deleteWallet(String walletId) async {
    try {
      AppLogger.info('🔄 Deleting electronic wallet: $walletId');

      // First, check if wallet exists and get its details for logging
      final walletResponse = await _walletsTable
          .select('wallet_name, phone_number, wallet_type')
          .eq('id', walletId)
          .maybeSingle();

      if (walletResponse == null) {
        AppLogger.warning('⚠️ Wallet not found: $walletId');
        return false;
      }

      final walletName = walletResponse['wallet_name'] as String;
      final phoneNumber = walletResponse['phone_number'] as String;
      final walletType = walletResponse['wallet_type'] as String;

      AppLogger.info('🔄 Deleting wallet "$walletName" ($walletType: $phoneNumber)');

      // Delete from payment_accounts table first (to handle foreign key constraints)
      try {
        await _supabase
            .from('payment_accounts')
            .delete()
            .eq('id', walletId);
        AppLogger.info('✅ Deleted payment account for wallet: $walletId');
      } catch (e) {
        AppLogger.warning('⚠️ Payment account deletion failed (may not exist): $e');
        // Continue with wallet deletion even if payment account deletion fails
      }

      // Delete from electronic_wallets table
      await _walletsTable
          .delete()
          .eq('id', walletId);

      AppLogger.info('✅ Deleted electronic wallet: $walletId');
      return true;
    } catch (e) {
      AppLogger.error('❌ Error deleting electronic wallet: $e');
      return false;
    }
  }

  /// Clean up orphaned payment account that might exist without a corresponding wallet
  Future<void> _cleanupOrphanedPaymentAccount(String accountType, String phoneNumber) async {
    try {
      AppLogger.info('🔄 Checking for orphaned payment account: $accountType - $phoneNumber');

      // Check if there's a payment account with this type and number
      final existingAccount = await _supabase
          .from('payment_accounts')
          .select('id')
          .eq('account_type', accountType)
          .eq('account_number', phoneNumber)
          .maybeSingle();

      if (existingAccount != null) {
        final accountId = existingAccount['id'] as String;

        // Check if there's a corresponding electronic wallet
        final correspondingWallet = await _walletsTable
            .select('id')
            .eq('id', accountId)
            .maybeSingle();

        if (correspondingWallet == null) {
          // This is an orphaned payment account - delete it
          AppLogger.warning('⚠️ Found orphaned payment account, cleaning up: $accountId');

          await _supabase
              .from('payment_accounts')
              .delete()
              .eq('id', accountId);

          AppLogger.info('✅ Cleaned up orphaned payment account: $accountId');
        } else {
          // There's a corresponding wallet, this is a legitimate duplicate
          throw Exception('محفظة بنفس النوع ورقم الهاتف موجودة بالفعل');
        }
      }
    } catch (e) {
      if (e.toString().contains('محفظة بنفس النوع ورقم الهاتف موجودة بالفعل')) {
        rethrow; // Re-throw legitimate duplicate errors
      }
      AppLogger.error('❌ Error during payment account cleanup: $e');
      // Don't throw here - continue with wallet creation
    }
  }

  /// Clean up all orphaned payment accounts (utility function for maintenance)
  Future<int> cleanupAllOrphanedPaymentAccounts() async {
    try {
      AppLogger.info('🔄 Starting cleanup of all orphaned payment accounts');

      // Get all payment accounts
      final allAccounts = await _supabase
          .from('payment_accounts')
          .select('id, account_type, account_number');

      int cleanedCount = 0;

      for (final account in allAccounts) {
        final accountId = account['id'] as String;

        // Check if there's a corresponding electronic wallet
        final correspondingWallet = await _walletsTable
            .select('id')
            .eq('id', accountId)
            .maybeSingle();

        if (correspondingWallet == null) {
          // This is an orphaned payment account - delete it
          AppLogger.info('🗑️ Removing orphaned payment account: $accountId (${account['account_type']} - ${account['account_number']})');

          await _supabase
              .from('payment_accounts')
              .delete()
              .eq('id', accountId);

          cleanedCount++;
        }
      }

      AppLogger.info('✅ Cleanup completed. Removed $cleanedCount orphaned payment accounts');
      return cleanedCount;
    } catch (e) {
      AppLogger.error('❌ Error during orphaned payment accounts cleanup: $e');
      return 0;
    }
  }

  /// Get wallet transactions
  Future<List<ElectronicWalletTransactionModel>> getWalletTransactions(String walletId) async {
    try {
      AppLogger.info('🔄 Fetching transactions for wallet: $walletId');

      final response = await _transactionsTable
          .select('''
            *,
            electronic_wallets!inner(wallet_name, phone_number)
          ''')
          .eq('wallet_id', walletId)
          .order('created_at', ascending: false);

      final transactions = (response as List)
          .map((data) => ElectronicWalletTransactionModel.fromDatabase({
            ...data,
            'wallet_name': data['electronic_wallets']['wallet_name'],
            'wallet_phone_number': data['electronic_wallets']['phone_number'],
          }))
          .toList();

      AppLogger.info('✅ Fetched ${transactions.length} transactions for wallet: $walletId');
      return transactions;
    } catch (e) {
      AppLogger.error('❌ Error fetching wallet transactions: $e');
      return [];
    }
  }

  /// Get all transactions with enhanced client information
  Future<List<ElectronicWalletTransactionModel>> getAllTransactions() async {
    try {
      AppLogger.info('🔄 Fetching all electronic wallet transactions with client info');

      // Try to get transactions with client information
      try {
        final response = await _transactionsTable
            .select('''
              *,
              electronic_wallets!inner(wallet_name, phone_number),
              client:users!electronic_wallet_transactions_user_id_fkey(
                id,
                name,
                email
              )
            ''')
            .order('created_at', ascending: false);

        final transactions = (response as List)
            .map((data) => ElectronicWalletTransactionModel.fromDatabaseWithClientInfo({
              ...data,
              'wallet_name': data['electronic_wallets']['wallet_name'],
              'wallet_phone_number': data['electronic_wallets']['phone_number'],
              'client_name': data['client']?['name'],
              'client_email': data['client']?['email'],
            }))
            .toList();

        AppLogger.info('✅ Fetched ${transactions.length} electronic wallet transactions with client info');
        return transactions;

      } catch (clientInfoError) {
        AppLogger.warning('⚠️ Failed to fetch client info, falling back to basic query: $clientInfoError');

        // Fallback to original query without client info
        final response = await _transactionsTable
            .select('''
              *,
              electronic_wallets!inner(wallet_name, phone_number)
            ''')
            .order('created_at', ascending: false);

        final transactions = (response as List)
            .map((data) => ElectronicWalletTransactionModel.fromDatabase({
              ...data,
              'wallet_name': data['electronic_wallets']['wallet_name'],
              'wallet_phone_number': data['electronic_wallets']['phone_number'],
            }))
            .toList();

        AppLogger.info('✅ Fetched ${transactions.length} electronic wallet transactions (basic)');
        return transactions;
      }

    } catch (e) {
      AppLogger.error('❌ Error fetching all transactions: $e');
      return [];
    }
  }

  /// Update wallet balance using database function
  Future<String?> updateWalletBalance({
    required String walletId,
    required double amount,
    required ElectronicWalletTransactionType transactionType,
    String? description,
    String? referenceId,
    String? paymentId,
    String? processedBy,
  }) async {
    try {
      AppLogger.info('🔄 Updating wallet balance: $walletId, amount: $amount, type: $transactionType');

      final typeString = _transactionTypeToString(transactionType);
      
      final response = await _supabase.rpc('update_wallet_balance', params: {
        'wallet_uuid': walletId,
        'transaction_amount': amount,
        'transaction_type_param': typeString,
        'description_param': description,
        'reference_id_param': referenceId,
        'payment_id_param': paymentId,
        'processed_by_param': processedBy,
      });

      final transactionId = response as String;
      
      AppLogger.info('✅ Updated wallet balance, transaction ID: $transactionId');
      return transactionId;
    } catch (e) {
      AppLogger.error('❌ Error updating wallet balance: $e');
      return null;
    }
  }

  /// Get wallet balance
  Future<double> getWalletBalance(String walletId) async {
    try {
      AppLogger.info('🔄 Getting wallet balance: $walletId');

      final response = await _supabase.rpc('get_wallet_balance', params: {
        'wallet_uuid': walletId,
      });

      final balance = (response as num).toDouble();
      
      AppLogger.info('✅ Wallet balance: $balance');
      return balance;
    } catch (e) {
      AppLogger.error('❌ Error getting wallet balance: $e');
      return 0.0;
    }
  }

  /// Get wallet statistics
  Future<Map<String, dynamic>> getWalletStatistics() async {
    try {
      AppLogger.info('🔄 Fetching wallet statistics');

      final wallets = await getAllWallets();
      final transactions = await getAllTransactions();

      final vodafoneWallets = wallets.where((w) => w.walletType == ElectronicWalletType.vodafoneCash).toList();
      final instapayWallets = wallets.where((w) => w.walletType == ElectronicWalletType.instaPay).toList();

      final totalBalance = wallets.fold<double>(0.0, (sum, wallet) => sum + wallet.currentBalance);
      final vodafoneBalance = vodafoneWallets.fold<double>(0.0, (sum, wallet) => sum + wallet.currentBalance);
      final instapayBalance = instapayWallets.fold<double>(0.0, (sum, wallet) => sum + wallet.currentBalance);

      final completedTransactions = transactions.where((t) => t.isCompleted).toList();
      final pendingTransactions = transactions.where((t) => t.isPending).toList();

      final statistics = {
        'total_wallets': wallets.length,
        'active_wallets': wallets.where((w) => w.isActive).length,
        'vodafone_wallets': vodafoneWallets.length,
        'instapay_wallets': instapayWallets.length,
        'total_balance': totalBalance,
        'vodafone_balance': vodafoneBalance,
        'instapay_balance': instapayBalance,
        'total_transactions': transactions.length,
        'completed_transactions': completedTransactions.length,
        'pending_transactions': pendingTransactions.length,
      };

      AppLogger.info('✅ Fetched wallet statistics');
      return statistics;
    } catch (e) {
      AppLogger.error('❌ Error fetching wallet statistics: $e');
      return {};
    }
  }

  /// Helper method to convert status to string
  String _statusToString(ElectronicWalletStatus status) {
    switch (status) {
      case ElectronicWalletStatus.active:
        return 'active';
      case ElectronicWalletStatus.inactive:
        return 'inactive';
      case ElectronicWalletStatus.suspended:
        return 'suspended';
    }
  }

  /// Helper method to convert transaction type to string
  String _transactionTypeToString(ElectronicWalletTransactionType type) {
    switch (type) {
      case ElectronicWalletTransactionType.deposit:
        return 'deposit';
      case ElectronicWalletTransactionType.withdrawal:
        return 'withdrawal';
      case ElectronicWalletTransactionType.transfer:
        return 'transfer';
      case ElectronicWalletTransactionType.payment:
        return 'payment';
      case ElectronicWalletTransactionType.refund:
        return 'refund';
    }
  }
}
