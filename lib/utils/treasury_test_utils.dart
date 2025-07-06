import 'package:flutter/material.dart';
import '../models/treasury_models.dart';
import '../models/wallet_model.dart';
import '../models/electronic_wallet_model.dart';
import '../utils/app_logger.dart';

/// Test utilities for treasury functionality
class TreasuryTestUtils {
  /// Generate mock treasury vault data for testing
  static List<TreasuryVault> generateMockTreasuryVaults({int count = 5}) {
    final vaults = <TreasuryVault>[];
    
    for (int i = 0; i < count; i++) {
      vaults.add(TreasuryVault(
        id: 'vault_${i + 1}',
        name: 'خزنة ${_getArabicNumber(i + 1)}',
        currency: i % 2 == 0 ? 'EGP' : 'USD',
        currentBalance: (1000 + (i * 500)).toDouble(),
        exchangeRate: i % 2 == 0 ? 1.0 : 30.5,
        vaultType: i % 3 == 0 ? TreasuryVaultType.cash : 
                   i % 3 == 1 ? TreasuryVaultType.bank : TreasuryVaultType.digital,
        status: i % 4 == 0 ? TreasuryVaultStatus.inactive : TreasuryVaultStatus.active,
        createdAt: DateTime.now().subtract(Duration(days: i * 10)),
        updatedAt: DateTime.now().subtract(Duration(days: i * 5)),
        bankName: i % 3 == 1 ? 'البنك الأهلي المصري' : null,
        accountNumber: i % 3 == 1 ? '123456789${i}' : null,
        accountHolderName: i % 3 == 1 ? 'شركة سمارت بيز تراكر' : null,
        description: 'خزنة اختبار رقم ${_getArabicNumber(i + 1)}',
      ));
    }
    
    return vaults;
  }

  /// Generate mock treasury connections for testing
  static List<TreasuryConnection> generateMockTreasuryConnections({
    required List<TreasuryVault> vaults,
    int count = 3,
  }) {
    final connections = <TreasuryConnection>[];
    
    for (int i = 0; i < count && i < vaults.length - 1; i++) {
      connections.add(TreasuryConnection(
        id: 'connection_${i + 1}',
        fromTreasuryId: vaults[i].id,
        toTreasuryId: vaults[i + 1].id,
        connectionType: i % 2 == 0 ? 
            TreasuryConnectionType.bidirectional : 
            TreasuryConnectionType.unidirectional,
        isActive: i % 3 != 0,
        createdAt: DateTime.now().subtract(Duration(days: i * 5)),
        description: 'اتصال اختبار ${_getArabicNumber(i + 1)}',
      ));
    }
    
    return connections;
  }

  /// Generate mock wallet data for testing
  static List<WalletModel> generateMockWallets({
    int clientCount = 3,
    int workerCount = 2,
  }) {
    final wallets = <WalletModel>[];
    
    // Generate client wallets
    for (int i = 0; i < clientCount; i++) {
      wallets.add(WalletModel(
        id: 'client_wallet_${i + 1}',
        userId: 'client_${i + 1}',
        balance: (500 + (i * 200)).toDouble(),
        role: 'client',
        status: i % 3 == 0 ? WalletStatus.suspended : WalletStatus.active,
        createdAt: DateTime.now().subtract(Duration(days: i * 15)),
        updatedAt: DateTime.now().subtract(Duration(days: i * 7)),
        userName: 'عميل ${_getArabicNumber(i + 1)}',
        userEmail: 'client${i + 1}@example.com',
        phoneNumber: '01${i + 1}12345678',
        transactionCount: 10 + (i * 5),
        lastTransactionDate: DateTime.now().subtract(Duration(days: i * 2)),
      ));
    }
    
    // Generate worker wallets
    for (int i = 0; i < workerCount; i++) {
      wallets.add(WalletModel(
        id: 'worker_wallet_${i + 1}',
        userId: 'worker_${i + 1}',
        balance: (300 + (i * 150)).toDouble(),
        role: 'worker',
        status: WalletStatus.active,
        createdAt: DateTime.now().subtract(Duration(days: i * 20)),
        updatedAt: DateTime.now().subtract(Duration(days: i * 10)),
        userName: 'عامل ${_getArabicNumber(i + 1)}',
        userEmail: 'worker${i + 1}@example.com',
        phoneNumber: '01${i + 5}12345678',
        transactionCount: 5 + (i * 3),
        lastTransactionDate: DateTime.now().subtract(Duration(days: i * 3)),
      ));
    }
    
    return wallets;
  }

  /// Generate mock electronic wallets for testing
  static List<ElectronicWalletModel> generateMockElectronicWallets({
    int vodafoneCount = 2,
    int instapayCount = 2,
  }) {
    final wallets = <ElectronicWalletModel>[];
    
    // Generate Vodafone Cash wallets
    for (int i = 0; i < vodafoneCount; i++) {
      wallets.add(ElectronicWalletModel(
        id: 'vodafone_wallet_${i + 1}',
        walletType: ElectronicWalletType.vodafoneCash,
        phoneNumber: '01${i + 1}12345678',
        walletName: 'فودافون كاش ${_getArabicNumber(i + 1)}',
        currentBalance: (1000 + (i * 300)).toDouble(),
        status: i % 3 == 0 ? ElectronicWalletStatus.inactive : ElectronicWalletStatus.active,
        description: 'محفظة فودافون كاش اختبار ${_getArabicNumber(i + 1)}',
        createdAt: DateTime.now().subtract(Duration(days: i * 12)),
        updatedAt: DateTime.now().subtract(Duration(days: i * 6)),
        createdBy: 'admin_user',
      ));
    }
    
    // Generate InstaPay wallets
    for (int i = 0; i < instapayCount; i++) {
      wallets.add(ElectronicWalletModel(
        id: 'instapay_wallet_${i + 1}',
        walletType: ElectronicWalletType.instaPay,
        phoneNumber: '01${i + 5}12345678',
        walletName: 'إنستاباي ${_getArabicNumber(i + 1)}',
        currentBalance: (800 + (i * 250)).toDouble(),
        status: ElectronicWalletStatus.active,
        description: 'محفظة إنستاباي اختبار ${_getArabicNumber(i + 1)}',
        createdAt: DateTime.now().subtract(Duration(days: i * 8)),
        updatedAt: DateTime.now().subtract(Duration(days: i * 4)),
        createdBy: 'admin_user',
      ));
    }
    
    return wallets;
  }

  /// Generate mock audit logs for testing
  static List<TreasuryAuditLog> generateMockAuditLogs({int count = 10}) {
    final logs = <TreasuryAuditLog>[];
    
    final actionTypes = [
      TreasuryAuditActionType.create,
      TreasuryAuditActionType.update,
      TreasuryAuditActionType.delete,
      TreasuryAuditActionType.view,
    ];
    
    final entityTypes = [
      TreasuryAuditEntityType.treasury,
      TreasuryAuditEntityType.transaction,
      TreasuryAuditEntityType.connection,
      TreasuryAuditEntityType.backup,
    ];
    
    final severities = [
      TreasuryAuditSeverity.info,
      TreasuryAuditSeverity.warning,
      TreasuryAuditSeverity.error,
      TreasuryAuditSeverity.critical,
    ];
    
    for (int i = 0; i < count; i++) {
      final actionType = actionTypes[i % actionTypes.length];
      final entityType = entityTypes[i % entityTypes.length];
      final severity = severities[i % severities.length];
      
      logs.add(TreasuryAuditLog(
        id: 'audit_log_${i + 1}',
        entityType: entityType,
        entityId: 'entity_${i + 1}',
        actionType: actionType,
        actionDescription: _generateActionDescription(actionType, entityType),
        severity: severity,
        timestamp: DateTime.now().subtract(Duration(hours: i * 2)),
        userId: 'user_${(i % 3) + 1}',
        userEmail: 'user${(i % 3) + 1}@example.com',
        ipAddress: '192.168.1.${100 + i}',
        userAgent: 'SmartBizTracker Mobile App',
        metadata: {
          'test_data': true,
          'index': i,
          'entity_name': 'اختبار ${_getArabicNumber(i + 1)}',
        },
      ));
    }
    
    return logs;
  }

  /// Test treasury provider functionality
  static Future<bool> testTreasuryProvider({
    required Future<void> Function() loadVaults,
    required Future<void> Function() loadConnections,
    required Future<void> Function() loadStatistics,
  }) async {
    try {
      AppLogger.info('🧪 Starting treasury provider tests...');
      
      // Test loading vaults
      AppLogger.info('Testing vault loading...');
      await loadVaults();
      AppLogger.info('✅ Vault loading test passed');
      
      // Test loading connections
      AppLogger.info('Testing connection loading...');
      await loadConnections();
      AppLogger.info('✅ Connection loading test passed');
      
      // Test loading statistics
      AppLogger.info('Testing statistics loading...');
      await loadStatistics();
      AppLogger.info('✅ Statistics loading test passed');
      
      AppLogger.info('🎉 All treasury provider tests passed!');
      return true;
    } catch (e) {
      AppLogger.error('❌ Treasury provider test failed: $e');
      return false;
    }
  }

  /// Test wallet provider functionality
  static Future<bool> testWalletProvider({
    required Future<void> Function() loadWallets,
    required Future<void> Function() loadTransactions,
  }) async {
    try {
      AppLogger.info('🧪 Starting wallet provider tests...');
      
      // Test loading wallets
      AppLogger.info('Testing wallet loading...');
      await loadWallets();
      AppLogger.info('✅ Wallet loading test passed');
      
      // Test loading transactions
      AppLogger.info('Testing transaction loading...');
      await loadTransactions();
      AppLogger.info('✅ Transaction loading test passed');
      
      AppLogger.info('🎉 All wallet provider tests passed!');
      return true;
    } catch (e) {
      AppLogger.error('❌ Wallet provider test failed: $e');
      return false;
    }
  }

  /// Test electronic wallet provider functionality
  static Future<bool> testElectronicWalletProvider({
    required Future<void> Function() loadWallets,
    required Future<void> Function() loadTransactions,
  }) async {
    try {
      AppLogger.info('🧪 Starting electronic wallet provider tests...');
      
      // Test loading wallets
      AppLogger.info('Testing electronic wallet loading...');
      await loadWallets();
      AppLogger.info('✅ Electronic wallet loading test passed');
      
      // Test loading transactions
      AppLogger.info('Testing electronic wallet transaction loading...');
      await loadTransactions();
      AppLogger.info('✅ Electronic wallet transaction loading test passed');
      
      AppLogger.info('🎉 All electronic wallet provider tests passed!');
      return true;
    } catch (e) {
      AppLogger.error('❌ Electronic wallet provider test failed: $e');
      return false;
    }
  }

  /// Validate Arabic RTL support
  static bool validateArabicRTLSupport(BuildContext context) {
    try {
      final textDirection = Directionality.of(context);
      final isRTL = textDirection == TextDirection.rtl;
      
      AppLogger.info('🔤 Text direction: $textDirection');
      AppLogger.info('🔤 Is RTL: $isRTL');
      
      return isRTL;
    } catch (e) {
      AppLogger.error('❌ Arabic RTL validation failed: $e');
      return false;
    }
  }

  /// Performance test for large data sets
  static Future<bool> performanceTest({
    required Future<void> Function() operation,
    required String operationName,
    int maxDurationMs = 5000,
  }) async {
    try {
      AppLogger.info('⏱️ Starting performance test for: $operationName');
      
      final stopwatch = Stopwatch()..start();
      await operation();
      stopwatch.stop();
      
      final durationMs = stopwatch.elapsedMilliseconds;
      AppLogger.info('⏱️ $operationName completed in ${durationMs}ms');
      
      if (durationMs <= maxDurationMs) {
        AppLogger.info('✅ Performance test passed for $operationName');
        return true;
      } else {
        AppLogger.warning('⚠️ Performance test failed for $operationName: ${durationMs}ms > ${maxDurationMs}ms');
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ Performance test failed for $operationName: $e');
      return false;
    }
  }

  // Helper methods
  static String _getArabicNumber(int number) {
    const arabicNumbers = ['صفر', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة', 'عشرة'];
    return number < arabicNumbers.length ? arabicNumbers[number] : number.toString();
  }

  static String _generateActionDescription(TreasuryAuditActionType actionType, TreasuryAuditEntityType entityType) {
    final actionMap = {
      TreasuryAuditActionType.create: 'إنشاء',
      TreasuryAuditActionType.update: 'تحديث',
      TreasuryAuditActionType.delete: 'حذف',
      TreasuryAuditActionType.view: 'عرض',
    };
    
    final entityMap = {
      TreasuryAuditEntityType.treasury: 'خزنة',
      TreasuryAuditEntityType.transaction: 'معاملة',
      TreasuryAuditEntityType.connection: 'اتصال',
      TreasuryAuditEntityType.backup: 'نسخة احتياطية',
    };
    
    return '${actionMap[actionType]} ${entityMap[entityType]}';
  }
}
