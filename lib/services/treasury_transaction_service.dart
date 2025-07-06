import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/treasury_models.dart';
import '../utils/app_logger.dart';

/// Service for managing treasury transactions
class TreasuryTransactionService {
  static final TreasuryTransactionService _instance = TreasuryTransactionService._internal();
  factory TreasuryTransactionService() => _instance;
  TreasuryTransactionService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create a deposit transaction
  Future<TreasuryTransaction> createDeposit({
    required String treasuryId,
    required double amount,
    required String description,
    String? referenceId,
  }) async {
    try {
      AppLogger.info('🔄 Creating deposit transaction: $amount for treasury $treasuryId');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // Get current treasury balance
      final treasuryResponse = await _supabase
          .from('treasury_vaults')
          .select('balance')
          .eq('id', treasuryId)
          .single();

      final currentBalance = (treasuryResponse['balance'] as num).toDouble();
      final newBalance = currentBalance + amount;

      // Use the existing update_treasury_balance function
      final transactionId = await _supabase.rpc('update_treasury_balance', params: {
        'treasury_uuid': treasuryId,
        'new_balance': newBalance,
        'transaction_type_param': 'credit',
        'description_param': description,
        'reference_uuid': referenceId,
        'user_uuid': currentUser.id,
      });

      // Fetch the created transaction
      final transactionResponse = await _supabase
          .from('treasury_transactions')
          .select()
          .eq('id', transactionId)
          .single();

      final transaction = TreasuryTransaction.fromJson(transactionResponse);
      AppLogger.info('✅ Created deposit transaction: ${transaction.id}');
      return transaction;
    } catch (e) {
      AppLogger.error('❌ Error creating deposit transaction: $e');
      throw Exception('فشل في إنشاء معاملة الإيداع: $e');
    }
  }

  /// Create a withdrawal transaction
  Future<TreasuryTransaction> createWithdrawal({
    required String treasuryId,
    required double amount,
    required String description,
    String? referenceId,
  }) async {
    try {
      AppLogger.info('🔄 Creating withdrawal transaction: $amount for treasury $treasuryId');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // Get current treasury balance
      final treasuryResponse = await _supabase
          .from('treasury_vaults')
          .select('balance')
          .eq('id', treasuryId)
          .single();

      final currentBalance = (treasuryResponse['balance'] as num).toDouble();
      
      // Validate sufficient balance
      if (currentBalance < amount) {
        throw Exception('الرصيد غير كافي. الرصيد الحالي: ${currentBalance.toStringAsFixed(2)}');
      }

      final newBalance = currentBalance - amount;

      // Use the existing update_treasury_balance function
      final transactionId = await _supabase.rpc('update_treasury_balance', params: {
        'treasury_uuid': treasuryId,
        'new_balance': newBalance,
        'transaction_type_param': 'debit',
        'description_param': description,
        'reference_uuid': referenceId,
        'user_uuid': currentUser.id,
      });

      // Fetch the created transaction
      final transactionResponse = await _supabase
          .from('treasury_transactions')
          .select()
          .eq('id', transactionId)
          .single();

      final transaction = TreasuryTransaction.fromJson(transactionResponse);
      AppLogger.info('✅ Created withdrawal transaction: ${transaction.id}');
      return transaction;
    } catch (e) {
      AppLogger.error('❌ Error creating withdrawal transaction: $e');
      throw Exception('فشل في إنشاء معاملة السحب: $e');
    }
  }

  /// Get transaction history with pagination and filtering
  Future<List<TreasuryTransaction>> getTransactionHistory({
    required String treasuryId,
    int page = 1,
    int limit = 20,
    TreasuryTransactionType? transactionType,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    try {
      AppLogger.info('🔄 Fetching transaction history for treasury $treasuryId');

      // Start with select to get PostgrestFilterBuilder, then apply filters
      var filterQuery = _supabase
          .from('treasury_transactions')
          .select()
          .eq('treasury_id', treasuryId);

      // Apply additional filters
      if (transactionType != null) {
        filterQuery = filterQuery.eq('transaction_type', transactionType.code);
      }

      if (startDate != null) {
        filterQuery = filterQuery.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        filterQuery = filterQuery.lte('created_at', endDate.toIso8601String());
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        filterQuery = filterQuery.ilike('description', '%$searchQuery%');
      }

      // Apply transformation methods and execute
      final offset = (page - 1) * limit;
      final response = await filterQuery
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      final transactions = (response as List)
          .map((json) => TreasuryTransaction.fromJson(json as Map<String, dynamic>))
          .toList();

      AppLogger.info('✅ Fetched ${transactions.length} transactions');
      return transactions;
    } catch (e) {
      AppLogger.error('❌ Error fetching transaction history: $e');
      throw Exception('فشل في جلب تاريخ المعاملات: $e');
    }
  }

  /// Get transaction count for pagination
  Future<int> getTransactionCount({
    required String treasuryId,
    TreasuryTransactionType? transactionType,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    try {
      // Start with select to get PostgrestFilterBuilder, then apply filters
      var query = _supabase
          .from('treasury_transactions')
          .select('id')
          .eq('treasury_id', treasuryId);

      // Apply same filters as getTransactionHistory
      if (transactionType != null) {
        query = query.eq('transaction_type', transactionType.code);
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.ilike('description', '%$searchQuery%');
      }

      final response = await query.count();
      return response.count ?? 0;
    } catch (e) {
      AppLogger.error('❌ Error getting transaction count: $e');
      return 0;
    }
  }

  /// Get recent transactions (last 10)
  Future<List<TreasuryTransaction>> getRecentTransactions({
    required String treasuryId,
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .from('treasury_transactions')
          .select()
          .eq('treasury_id', treasuryId)
          .order('created_at', ascending: false)
          .limit(limit);

      final transactions = (response as List)
          .map((json) => TreasuryTransaction.fromJson(json as Map<String, dynamic>))
          .toList();

      return transactions;
    } catch (e) {
      AppLogger.error('❌ Error fetching recent transactions: $e');
      return [];
    }
  }

  /// Get transaction statistics for a treasury
  Future<Map<String, dynamic>> getTransactionStatistics({
    required String treasuryId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Start with select to get PostgrestFilterBuilder, then apply filters
      var query = _supabase
          .from('treasury_transactions')
          .select('transaction_type, amount')
          .eq('treasury_id', treasuryId);

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query;
      final transactions = response as List;

      double totalCredits = 0;
      double totalDebits = 0;
      int creditCount = 0;
      int debitCount = 0;

      for (final transaction in transactions) {
        final type = transaction['transaction_type'] as String;
        final amount = (transaction['amount'] as num).toDouble();

        if (type == 'credit' || type == 'transfer_in') {
          totalCredits += amount;
          creditCount++;
        } else if (type == 'debit' || type == 'transfer_out') {
          totalDebits += amount;
          debitCount++;
        }
      }

      return {
        'total_credits': totalCredits,
        'total_debits': totalDebits,
        'credit_count': creditCount,
        'debit_count': debitCount,
        'net_amount': totalCredits - totalDebits,
        'total_transactions': transactions.length,
      };
    } catch (e) {
      AppLogger.error('❌ Error getting transaction statistics: $e');
      return {
        'total_credits': 0.0,
        'total_debits': 0.0,
        'credit_count': 0,
        'debit_count': 0,
        'net_amount': 0.0,
        'total_transactions': 0,
      };
    }
  }

  /// Delete a transaction (admin only)
  Future<void> deleteTransaction(String transactionId) async {
    try {
      AppLogger.info('🔄 Deleting transaction: $transactionId');

      await _supabase
          .from('treasury_transactions')
          .delete()
          .eq('id', transactionId);

      AppLogger.info('✅ Deleted transaction: $transactionId');
    } catch (e) {
      AppLogger.error('❌ Error deleting transaction: $e');
      throw Exception('فشل في حذف المعاملة: $e');
    }
  }

  /// Clear all transactions for a treasury while preserving the current balance
  Future<void> clearAllTransactions(String treasuryId) async {
    try {
      AppLogger.info('🔄 Clearing all transactions for treasury: $treasuryId');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // Get current treasury info for logging purposes
      final treasuryResponse = await _supabase
          .from('treasury_vaults')
          .select('balance, name')
          .eq('id', treasuryId)
          .single();

      final currentBalance = (treasuryResponse['balance'] as num).toDouble();
      final treasuryName = treasuryResponse['name'] as String;

      AppLogger.info('🔄 Treasury "$treasuryName" current balance: $currentBalance (will be preserved)');

      // Delete all transactions for this treasury
      final deleteResult = await _supabase
          .from('treasury_transactions')
          .delete()
          .eq('treasury_id', treasuryId);

      AppLogger.info('🗑️ Deleted all transactions for treasury: $treasuryId');

      // Update the treasury's updated_at timestamp to trigger UI refresh
      // but preserve the current balance
      await _supabase
          .from('treasury_vaults')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', treasuryId);

      AppLogger.info('💰 Preserved balance $currentBalance for treasury: $treasuryName');

      // Note: We do NOT create any transaction records and do NOT reset the balance
      // The purpose of "Clear All Transactions" is to clear transaction history
      // while preserving the current treasury balance for record-keeping purposes

      AppLogger.info('✅ Successfully cleared all transactions while preserving balance for treasury: $treasuryName');
    } catch (e) {
      AppLogger.error('❌ Error clearing all transactions: $e');
      throw Exception('فشل في مسح المعاملات: $e');
    }
  }
}
