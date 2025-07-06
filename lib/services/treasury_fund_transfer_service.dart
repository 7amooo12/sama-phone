import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/treasury_models.dart';
import '../utils/app_logger.dart';

/// Service for handling fund transfers between treasuries
class TreasuryFundTransferService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Validate a transfer before execution
  Future<TransferValidationResult> validateTransfer({
    required String sourceTreasuryId,
    required String targetTreasuryId,
    required double transferAmount,
  }) async {
    try {
      AppLogger.info('🔄 Validating transfer: $transferAmount from $sourceTreasuryId to $targetTreasuryId');

      final response = await _supabase.rpc('validate_treasury_transfer', params: {
        'source_treasury_uuid': sourceTreasuryId,
        'target_treasury_uuid': targetTreasuryId,
        'transfer_amount': transferAmount,
      });

      final result = TransferValidationResult.fromJson(response as Map<String, dynamic>);
      
      AppLogger.info('✅ Transfer validation completed: ${result.isValid ? 'Valid' : 'Invalid'}');
      return result;
    } catch (e) {
      AppLogger.error('❌ Error validating transfer: $e');
      return TransferValidationResult(
        isValid: false,
        errors: ['خطأ في التحقق من صحة التحويل: $e'],
        warnings: [],
        transferDetails: null,
      );
    }
  }

  /// Execute a fund transfer between treasuries
  Future<String> executeTransfer({
    required String sourceTreasuryId,
    required String targetTreasuryId,
    required double transferAmount,
    String description = 'تحويل بين الخزائن',
  }) async {
    try {
      AppLogger.info('🔄 Executing transfer: $transferAmount from $sourceTreasuryId to $targetTreasuryId');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // First validate the transfer
      final validation = await validateTransfer(
        sourceTreasuryId: sourceTreasuryId,
        targetTreasuryId: targetTreasuryId,
        transferAmount: transferAmount,
      );

      if (!validation.isValid) {
        throw Exception(validation.errors.join(', '));
      }

      // Execute the transfer
      final transferId = await _supabase.rpc('transfer_between_treasuries', params: {
        'source_treasury_uuid': sourceTreasuryId,
        'target_treasury_uuid': targetTreasuryId,
        'transfer_amount': transferAmount,
        'transfer_description': description,
        'user_uuid': currentUser.id,
      });

      AppLogger.info('✅ Transfer executed successfully: $transferId');
      return transferId as String;
    } catch (e) {
      AppLogger.error('❌ Error executing transfer: $e');
      
      // Provide user-friendly error messages
      String errorMessage = 'فشل في تنفيذ التحويل';
      
      if (e.toString().contains('الرصيد غير كافي')) {
        errorMessage = 'الرصيد غير كافي في الخزنة المصدر';
      } else if (e.toString().contains('لا يمكن التحويل إلى نفس الخزنة')) {
        errorMessage = 'لا يمكن التحويل إلى نفس الخزنة';
      } else if (e.toString().contains('غير موجود')) {
        errorMessage = 'إحدى الخزائن غير موجودة';
      } else {
        errorMessage = 'فشل في تنفيذ التحويل: ${e.toString()}';
      }
      
      throw Exception(errorMessage);
    }
  }

  /// Get transfer details by reference ID
  Future<TransferDetails?> getTransferDetails(String transferId) async {
    try {
      AppLogger.info('🔄 Getting transfer details: $transferId');

      final response = await _supabase.rpc('get_transfer_details', params: {
        'transfer_reference_id': transferId,
      });

      if (response == null || (response as List).isEmpty) {
        AppLogger.info('ℹ️ No transfer details found for: $transferId');
        return null;
      }

      final transferData = (response as List).first as Map<String, dynamic>;
      final details = TransferDetails.fromJson(transferData);
      
      AppLogger.info('✅ Transfer details retrieved: ${details.transferId}');
      return details;
    } catch (e) {
      AppLogger.error('❌ Error getting transfer details: $e');
      throw Exception('فشل في جلب تفاصيل التحويل: $e');
    }
  }

  /// Get transfer history for a treasury
  Future<List<TransferDetails>> getTransferHistory({
    required String treasuryId,
    int page = 1,
    int limit = 20,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      AppLogger.info('🔄 Getting transfer history for treasury: $treasuryId');

      var query = _supabase
          .from('treasury_transactions')
          .select('''
            reference_id,
            created_at,
            created_by
          ''')
          .eq('treasury_id', treasuryId)
          .inFilter('transaction_type', ['transfer_in', 'transfer_out'])
          .order('created_at', ascending: false)
          .range((page - 1) * limit, page * limit - 1);

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query;
      final transactions = response as List;

      // Get unique transfer IDs
      final transferIds = transactions
          .map((t) => t['reference_id'] as String?)
          .where((id) => id != null)
          .toSet()
          .toList();

      // Get details for each transfer
      final List<TransferDetails> transfers = [];
      for (final transferId in transferIds) {
        try {
          final details = await getTransferDetails(transferId!);
          if (details != null) {
            transfers.add(details);
          }
        } catch (e) {
          AppLogger.error('❌ Error getting details for transfer $transferId: $e');
          // Continue with other transfers
        }
      }

      // Sort by creation date
      transfers.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      AppLogger.info('✅ Retrieved ${transfers.length} transfer records');
      return transfers;
    } catch (e) {
      AppLogger.error('❌ Error getting transfer history: $e');
      throw Exception('فشل في جلب سجل التحويلات: $e');
    }
  }

  /// Get transfer statistics for a treasury
  Future<TransferStatistics> getTransferStatistics({
    required String treasuryId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      AppLogger.info('🔄 Getting transfer statistics for treasury: $treasuryId');

      var query = _supabase
          .from('treasury_transactions')
          .select('transaction_type, amount')
          .eq('treasury_id', treasuryId)
          .inFilter('transaction_type', ['transfer_in', 'transfer_out']);

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query;
      final transactions = response as List;

      double totalTransfersIn = 0;
      double totalTransfersOut = 0;
      int transfersInCount = 0;
      int transfersOutCount = 0;

      for (final transaction in transactions) {
        final type = transaction['transaction_type'] as String;
        final amount = (transaction['amount'] as num).toDouble();

        if (type == 'transfer_in') {
          totalTransfersIn += amount;
          transfersInCount++;
        } else if (type == 'transfer_out') {
          totalTransfersOut += amount;
          transfersOutCount++;
        }
      }

      final statistics = TransferStatistics(
        totalTransfersIn: totalTransfersIn,
        totalTransfersOut: totalTransfersOut,
        transfersInCount: transfersInCount,
        transfersOutCount: transfersOutCount,
        netTransferAmount: totalTransfersIn - totalTransfersOut,
        totalTransfers: transfersInCount + transfersOutCount,
      );

      AppLogger.info('✅ Transfer statistics calculated');
      return statistics;
    } catch (e) {
      AppLogger.error('❌ Error getting transfer statistics: $e');
      throw Exception('فشل في جلب إحصائيات التحويلات: $e');
    }
  }
}
