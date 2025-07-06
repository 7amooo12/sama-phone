import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/electronic_payment_service.dart';
import 'app_logger.dart';

/// Validator class to check and fix electronic payment system issues
class ElectronicPaymentValidator {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ElectronicPaymentService _paymentService = ElectronicPaymentService();

  /// Validate that all required tables exist
  Future<Map<String, dynamic>> validateDatabaseTables() async {
    try {
      AppLogger.info('🔍 Validating electronic payment database tables...');
      
      final results = <String, dynamic>{
        'payment_accounts_exists': false,
        'electronic_payments_exists': false,
        'errors': <String>[],
        'warnings': <String>[],
      };

      // Test payment_accounts table
      try {
        await _supabase.from('payment_accounts').select('id').limit(1);
        results['payment_accounts_exists'] = true;
        AppLogger.info('✅ payment_accounts table exists');
      } catch (e) {
        results['errors'].add('payment_accounts table missing: $e');
        AppLogger.error('❌ payment_accounts table missing: $e');
      }

      // Test electronic_payments table
      try {
        await _supabase.from('electronic_payments').select('id').limit(1);
        results['electronic_payments_exists'] = true;
        AppLogger.info('✅ electronic_payments table exists');
      } catch (e) {
        results['errors'].add('electronic_payments table missing: $e');
        AppLogger.error('❌ electronic_payments table missing: $e');
      }

      results['is_valid'] = results['errors'].isEmpty;
      return results;
    } catch (e) {
      AppLogger.error('❌ Database validation failed: $e');
      return {
        'is_valid': false,
        'payment_accounts_exists': false,
        'electronic_payments_exists': false,
        'errors': ['Database validation failed: $e'],
        'warnings': [],
      };
    }
  }

  /// Validate service functionality
  Future<Map<String, dynamic>> validateServiceFunctionality() async {
    try {
      AppLogger.info('🔍 Validating electronic payment service functionality...');
      
      final results = <String, dynamic>{
        'can_fetch_accounts': false,
        'can_fetch_payments': false,
        'can_fetch_statistics': false,
        'errors': <String>[],
        'warnings': <String>[],
      };

      // Test fetching payment accounts
      try {
        await _paymentService.getActivePaymentAccounts();
        results['can_fetch_accounts'] = true;
        AppLogger.info('✅ Can fetch payment accounts');
      } catch (e) {
        results['errors'].add('Cannot fetch payment accounts: $e');
        AppLogger.error('❌ Cannot fetch payment accounts: $e');
      }

      // Test fetching all payments
      try {
        await _paymentService.getAllPayments();
        results['can_fetch_payments'] = true;
        AppLogger.info('✅ Can fetch payments');
      } catch (e) {
        results['errors'].add('Cannot fetch payments: $e');
        AppLogger.error('❌ Cannot fetch payments: $e');
      }

      // Test fetching statistics
      try {
        await _paymentService.getPaymentStatistics();
        results['can_fetch_statistics'] = true;
        AppLogger.info('✅ Can fetch payment statistics');
      } catch (e) {
        results['errors'].add('Cannot fetch payment statistics: $e');
        AppLogger.error('❌ Cannot fetch payment statistics: $e');
      }

      results['is_valid'] = results['errors'].isEmpty;
      return results;
    } catch (e) {
      AppLogger.error('❌ Service validation failed: $e');
      return {
        'is_valid': false,
        'can_fetch_accounts': false,
        'can_fetch_payments': false,
        'can_fetch_statistics': false,
        'errors': ['Service validation failed: $e'],
        'warnings': [],
      };
    }
  }

  /// Validate data integrity
  Future<Map<String, dynamic>> validateDataIntegrity() async {
    try {
      AppLogger.info('🔍 Validating electronic payment data integrity...');
      
      final results = <String, dynamic>{
        'account_count': 0,
        'payment_count': 0,
        'orphaned_payments': 0,
        'errors': <String>[],
        'warnings': <String>[],
      };

      // Count payment accounts
      try {
        final accounts = await _paymentService.getAllPaymentAccounts();
        results['account_count'] = accounts.length;
        AppLogger.info('📊 Found ${accounts.length} payment accounts');
        
        if (accounts.isEmpty) {
          results['warnings'].add('No payment accounts found - consider adding default accounts');
        }
      } catch (e) {
        results['errors'].add('Cannot count payment accounts: $e');
      }

      // Count payments
      try {
        final payments = await _paymentService.getAllPayments();
        results['payment_count'] = payments.length;
        AppLogger.info('📊 Found ${payments.length} electronic payments');
      } catch (e) {
        results['errors'].add('Cannot count payments: $e');
      }

      // Check for orphaned payments (payments without valid recipient accounts)
      try {
        final orphanedQuery = await _supabase
            .from('electronic_payments')
            .select('id')
            .not('recipient_account_id', 'in', 
                 '(SELECT id FROM payment_accounts)');
        
        final orphanedCount = (orphanedQuery as List).length;
        results['orphaned_payments'] = orphanedCount;

        if (orphanedCount > 0) {
          results['warnings'].add('Found $orphanedCount orphaned payments');
        }
      } catch (e) {
        results['warnings'].add('Cannot check for orphaned payments: $e');
      }

      results['is_valid'] = results['errors'].isEmpty;
      return results;
    } catch (e) {
      AppLogger.error('❌ Data integrity validation failed: $e');
      return {
        'is_valid': false,
        'account_count': 0,
        'payment_count': 0,
        'orphaned_payments': 0,
        'errors': ['Data integrity validation failed: $e'],
        'warnings': [],
      };
    }
  }

  /// Run complete validation
  Future<Map<String, dynamic>> runCompleteValidation() async {
    AppLogger.info('🚀 Starting complete electronic payment system validation...');
    
    final results = <String, dynamic>{
      'overall_status': 'unknown',
      'database_validation': {},
      'service_validation': {},
      'data_validation': {},
      'recommendations': <String>[],
    };

    // Run all validations
    results['database_validation'] = await validateDatabaseTables();
    results['service_validation'] = await validateServiceFunctionality();
    results['data_validation'] = await validateDataIntegrity();

    // Determine overall status
    final dbValid = (results['database_validation']['is_valid'] as bool?) ?? false;
    final serviceValid = (results['service_validation']['is_valid'] as bool?) ?? false;
    final dataValid = (results['data_validation']['is_valid'] as bool?) ?? false;

    if (dbValid && serviceValid && dataValid) {
      results['overall_status'] = 'healthy';
      results['recommendations'].add('✅ Electronic payment system is fully functional');
    } else if (dbValid && serviceValid) {
      results['overall_status'] = 'functional_with_warnings';
      results['recommendations'].add('⚠️ System is functional but has data integrity issues');
    } else if (dbValid) {
      results['overall_status'] = 'database_only';
      results['recommendations'].add('🔧 Database exists but service has issues');
    } else {
      results['overall_status'] = 'broken';
      results['recommendations'].add('❌ Database tables are missing - run the migration script');
    }

    // Add specific recommendations
    if (!dbValid) {
      results['recommendations'].add('1. Run ELECTRONIC_PAYMENT_DATABASE_FIX.sql in Supabase SQL Editor');
      results['recommendations'].add('2. Verify RLS policies are correctly configured');
    }

    if (dbValid && !serviceValid) {
      results['recommendations'].add('1. Check user authentication and permissions');
      results['recommendations'].add('2. Verify RLS policies allow proper access');
    }

    final accountCount = (results['data_validation']['account_count'] as int?) ?? 0;
    if (accountCount == 0) {
      results['recommendations'].add('3. Add default payment accounts for Vodafone Cash and InstaPay');
    }

    AppLogger.info('🏁 Validation complete. Status: ${results['overall_status']}');
    return results;
  }

  /// Create default payment accounts if missing
  Future<bool> createDefaultPaymentAccounts() async {
    try {
      AppLogger.info('🔧 Creating default payment accounts...');

      // Check if accounts already exist
      final existingAccounts = await _paymentService.getAllPaymentAccounts();
      if (existingAccounts.isNotEmpty) {
        AppLogger.info('ℹ️ Payment accounts already exist, skipping creation');
        return true;
      }

      // Create Vodafone Cash account
      await _paymentService.createPaymentAccount(
        accountType: 'vodafone_cash',
        accountNumber: '01000000000',
        accountHolderName: 'SAMA Store - Vodafone Cash',
        isActive: true,
      );

      // Create InstaPay account
      await _paymentService.createPaymentAccount(
        accountType: 'instapay',
        accountNumber: 'SAMA@instapay',
        accountHolderName: 'SAMA Store - InstaPay',
        isActive: true,
      );

      AppLogger.info('✅ Default payment accounts created successfully');
      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to create default payment accounts: $e');
      return false;
    }
  }

  /// Generate validation report
  String generateValidationReport(Map<String, dynamic> validationResults) {
    final buffer = StringBuffer();
    
    buffer.writeln('📋 ELECTRONIC PAYMENT SYSTEM VALIDATION REPORT');
    buffer.writeln('=' * 50);
    buffer.writeln();
    
    // Overall status
    final status = validationResults['overall_status'] ?? 'unknown';
    buffer.writeln('🎯 Overall Status: ${status.toUpperCase()}');
    buffer.writeln();
    
    // Database validation
    final dbValidation = validationResults['database_validation'] as Map<String, dynamic>;
    buffer.writeln('🗄️ Database Validation:');
    buffer.writeln('  - payment_accounts table: ${(dbValidation['payment_accounts_exists'] as bool?) == true ? '✅' : '❌'}');
    buffer.writeln('  - electronic_payments table: ${(dbValidation['electronic_payments_exists'] as bool?) == true ? '✅' : '❌'}');
    buffer.writeln();

    // Service validation
    final serviceValidation = validationResults['service_validation'] as Map<String, dynamic>;
    buffer.writeln('🔧 Service Validation:');
    buffer.writeln('  - Can fetch accounts: ${(serviceValidation['can_fetch_accounts'] as bool?) == true ? '✅' : '❌'}');
    buffer.writeln('  - Can fetch payments: ${(serviceValidation['can_fetch_payments'] as bool?) == true ? '✅' : '❌'}');
    buffer.writeln('  - Can fetch statistics: ${(serviceValidation['can_fetch_statistics'] as bool?) == true ? '✅' : '❌'}');
    buffer.writeln();
    
    // Data validation
    final dataValidation = validationResults['data_validation'] as Map<String, dynamic>;
    buffer.writeln('📊 Data Validation:');
    buffer.writeln('  - Payment accounts: ${dataValidation['account_count']}');
    buffer.writeln('  - Electronic payments: ${dataValidation['payment_count']}');
    buffer.writeln('  - Orphaned payments: ${dataValidation['orphaned_payments']}');
    buffer.writeln();
    
    // Recommendations
    final recommendations = validationResults['recommendations'] as List<String>;
    if (recommendations.isNotEmpty) {
      buffer.writeln('💡 Recommendations:');
      for (final recommendation in recommendations) {
        buffer.writeln('  $recommendation');
      }
      buffer.writeln();
    }
    
    // Errors
    final allErrors = <String>[];
    allErrors.addAll(dbValidation['errors'] as List<String>);
    allErrors.addAll(serviceValidation['errors'] as List<String>);
    allErrors.addAll(dataValidation['errors'] as List<String>);
    
    if (allErrors.isNotEmpty) {
      buffer.writeln('❌ Errors Found:');
      for (final error in allErrors) {
        buffer.writeln('  - $error');
      }
      buffer.writeln();
    }
    
    buffer.writeln('=' * 50);
    buffer.writeln('Report generated at: ${DateTime.now()}');
    
    return buffer.toString();
  }
}
