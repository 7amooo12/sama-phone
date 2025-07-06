import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/treasury_models.dart';
import '../utils/app_logger.dart';

class TreasuryProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // State variables
  List<TreasuryVault> _treasuryVaults = [];
  List<TreasuryConnection> _connections = [];
  List<TreasuryTransaction> _transactions = [];
  TreasuryStatistics? _statistics;
  bool _isLoading = false;
  String? _error;
  
  // Realtime subscription
  RealtimeChannel? _treasuryChannel;
  Timer? _periodicRefreshTimer;
  
  // Getters
  List<TreasuryVault> get treasuryVaults => _treasuryVaults;
  List<TreasuryConnection> get connections => _connections;
  List<TreasuryTransaction> get transactions => _transactions;
  TreasuryStatistics? get statistics => _statistics;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  TreasuryVault? get mainTreasury => 
      _treasuryVaults.where((vault) => vault.isMainTreasury).firstOrNull;
  
  List<TreasuryVault> get subTreasuries => 
      _treasuryVaults.where((vault) => !vault.isMainTreasury).toList();

  /// Initialize provider and load data
  Future<void> initialize() async {
    try {
      _setLoading(true);
      _setError(null);

      // Ensure main treasury exists first
      await _ensureMainTreasuryExists();

      await Future.wait([
        loadTreasuryVaults(),
        loadConnections(),
        loadStatistics(),
      ]);

      _setupRealtimeSubscription();

    } catch (e) {
      AppLogger.error('Failed to initialize treasury provider: $e');
      _setError('فشل في تحميل بيانات الخزنة: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Ensure main treasury exists, create if needed
  Future<void> _ensureMainTreasuryExists() async {
    try {
      AppLogger.info('Ensuring main treasury exists...');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        AppLogger.warning('No authenticated user, skipping main treasury creation');
        return;
      }

      // Use the safe function to create main treasury if needed
      await _supabase.rpc('create_main_treasury_if_needed');

      AppLogger.info('Main treasury check completed');

    } catch (e) {
      AppLogger.warning('Could not ensure main treasury exists: $e');
      // Don't throw here as this is not critical for initialization
    }
  }

  /// Load all treasury vaults
  Future<void> loadTreasuryVaults() async {
    try {
      AppLogger.info('Loading treasury vaults...');

      final response = await _supabase
          .from('treasury_vaults')
          .select()
          .order('created_at', ascending: false);

      _treasuryVaults = (response as List)
          .map((json) => TreasuryVault.fromJson(json as Map<String, dynamic>))
          .toList();

      AppLogger.info('Loaded ${_treasuryVaults.length} treasury vaults');
      notifyListeners();

    } catch (e) {
      AppLogger.error('Failed to load treasury vaults: $e');
      throw Exception('فشل في تحميل الخزائن: $e');
    }
  }

  /// Force refresh all treasury data (for manual refresh)
  Future<void> refreshAllData() async {
    try {
      _setLoading(true);
      _setError(null);

      AppLogger.info('Force refreshing all treasury data...');

      await Future.wait([
        loadTreasuryVaults(),
        loadConnections(),
        loadStatistics(),
      ]);

      AppLogger.info('All treasury data refreshed successfully');

    } catch (e) {
      AppLogger.error('Failed to refresh all treasury data: $e');
      _setError('فشل في تحديث البيانات: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Load all connections
  Future<void> loadConnections() async {
    try {
      AppLogger.info('Loading treasury connections...');
      
      final response = await _supabase
          .from('treasury_connections')
          .select()
          .order('created_at', ascending: false);
      
      _connections = (response as List)
          .map((json) => TreasuryConnection.fromJson(json as Map<String, dynamic>))
          .toList();
      
      AppLogger.info('Loaded ${_connections.length} treasury connections');
      notifyListeners();
      
    } catch (e) {
      AppLogger.error('Failed to load treasury connections: $e');
      throw Exception('فشل في تحميل الاتصالات: $e');
    }
  }

  /// Load treasury statistics
  Future<void> loadStatistics() async {
    try {
      AppLogger.info('Loading treasury statistics...');
      
      final response = await _supabase.rpc('get_treasury_statistics');
      
      if (response != null) {
        _statistics = TreasuryStatistics.fromJson(response);
        AppLogger.info('Loaded treasury statistics');
        notifyListeners();
      }
      
    } catch (e) {
      AppLogger.error('Failed to load treasury statistics: $e');
      // Don't throw here as statistics are not critical
    }
  }

  /// Create new treasury vault
  Future<TreasuryVault> createTreasuryVault({
    required String name,
    required String currency,
    required double exchangeRate,
    double initialBalance = 0,
    double positionX = 0,
    double positionY = 0,
    bool isMainTreasury = false, // Allow explicit main treasury creation
    TreasuryType treasuryType = TreasuryType.cash,
    String? bankName,
    String? accountNumber,
    String? accountHolderName,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      AppLogger.info('Creating treasury vault: $name ($currency) - Main: $isMainTreasury');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // Validate main treasury creation
      if (isMainTreasury) {
        final existingMainTreasury = _treasuryVaults.where((vault) => vault.isMainTreasury).firstOrNull;
        if (existingMainTreasury != null) {
          throw Exception('يوجد خزنة رئيسية بالفعل. لا يمكن إنشاء أكثر من خزنة رئيسية واحدة.');
        }
      }

      final vaultData = {
        'name': name,
        'currency': currency,
        'balance': initialBalance,
        'exchange_rate_to_egp': exchangeRate,
        'is_main_treasury': isMainTreasury,
        'position_x': positionX,
        'position_y': positionY,
        'created_by': currentUser.id,
        'treasury_type': treasuryType.code,
        'bank_name': bankName,
        'account_number': accountNumber,
        'account_holder_name': accountHolderName,
      };
      
      final response = await _supabase
          .from('treasury_vaults')
          .insert(vaultData)
          .select()
          .single();
      
      final newVault = TreasuryVault.fromJson(response);
      _treasuryVaults.add(newVault);
      
      AppLogger.info('Created treasury vault: ${newVault.id}');
      
      // Reload statistics
      await loadStatistics();
      
      notifyListeners();
      return newVault;
      
    } catch (e) {
      AppLogger.error('Failed to create treasury vault: $e');

      // Provide user-friendly error messages for common constraint violations
      String errorMessage = 'فشل في إنشاء الخزنة';

      if (e.toString().contains('unique_main_treasury') ||
          e.toString().contains('idx_unique_main_treasury')) {
        errorMessage = 'لا يمكن إنشاء أكثر من خزنة رئيسية واحدة';
      } else if (e.toString().contains('23505')) {
        // PostgreSQL unique constraint violation
        errorMessage = 'يوجد خزنة بنفس المواصفات بالفعل';
      } else if (e.toString().contains('42501')) {
        // PostgreSQL permission denied
        errorMessage = 'ليس لديك صلاحية لإنشاء الخزائن';
      } else {
        errorMessage = 'فشل في إنشاء الخزنة: ${e.toString()}';
      }

      _setError(errorMessage);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Update treasury vault balance
  Future<void> updateTreasuryBalance({
    required String treasuryId,
    required double newBalance,
    required String transactionType,
    String? description,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      AppLogger.info('Updating treasury balance: $treasuryId to $newBalance');

      final currentUser = _supabase.auth.currentUser;

      await _supabase.rpc('update_treasury_balance', params: {
        'treasury_uuid': treasuryId,
        'new_balance': newBalance,
        'transaction_type_param': transactionType,
        'description_param': description,
        'user_uuid': currentUser?.id,
      });

      // Reload data
      await Future.wait([
        loadTreasuryVaults(),
        loadStatistics(),
      ]);

      AppLogger.info('Updated treasury balance successfully');

    } catch (e) {
      AppLogger.error('Failed to update treasury balance: $e');
      _setError('فشل في تحديث رصيد الخزنة: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete treasury vault
  Future<void> deleteTreasuryVault(String treasuryId) async {
    try {
      _setLoading(true);
      _setError(null);

      AppLogger.info('Deleting treasury vault: $treasuryId');

      // Check if it's the main treasury
      final treasury = _treasuryVaults.firstWhere(
        (vault) => vault.id == treasuryId,
        orElse: () => throw Exception('الخزنة غير موجودة'),
      );

      if (treasury.isMainTreasury) {
        throw Exception('لا يمكن حذف الخزنة الرئيسية');
      }

      // Check if treasury has connections
      final hasConnections = _connections.any(
        (connection) =>
          connection.sourceTreasuryId == treasuryId ||
          connection.targetTreasuryId == treasuryId
      );

      if (hasConnections) {
        throw Exception('لا يمكن حذف الخزنة لأنها مرتبطة بخزائن أخرى. يرجى إزالة الاتصالات أولاً');
      }

      // Check if treasury has balance
      if (treasury.balance > 0) {
        throw Exception('لا يمكن حذف الخزنة لأنها تحتوي على رصيد. يرجى تفريغ الرصيد أولاً');
      }

      // Delete the treasury
      await _supabase
          .from('treasury_vaults')
          .delete()
          .eq('id', treasuryId);

      // Remove from local state
      _treasuryVaults.removeWhere((vault) => vault.id == treasuryId);

      // Reload data to ensure consistency
      await Future.wait([
        loadTreasuryVaults(),
        loadConnections(),
        loadStatistics(),
      ]);

      AppLogger.info('Deleted treasury vault successfully');

    } catch (e) {
      AppLogger.error('Failed to delete treasury vault: $e');
      _setError('فشل في حذف الخزنة: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Create treasury connection
  Future<TreasuryConnection> createConnection({
    required String sourceTreasuryId,
    required String targetTreasuryId,
    required double connectionAmount,
    ConnectionPoint sourceConnectionPoint = ConnectionPoint.center,
    ConnectionPoint targetConnectionPoint = ConnectionPoint.center,
  }) async {
    try {
      _setLoading(true);
      _setError(null);
      
      AppLogger.info('Creating treasury connection: $sourceTreasuryId -> $targetTreasuryId');
      
      // Validate connection first
      final isValid = await _supabase.rpc('validate_treasury_connection', params: {
        'source_uuid': sourceTreasuryId,
        'target_uuid': targetTreasuryId,
      });
      
      if (!isValid) {
        throw Exception('لا يمكن إنشاء هذا الاتصال');
      }
      
      final currentUser = _supabase.auth.currentUser;
      
      final connectionId = await _supabase.rpc('create_treasury_connection', params: {
        'source_uuid': sourceTreasuryId,
        'target_uuid': targetTreasuryId,
        'connection_amount_param': connectionAmount,
        'user_uuid': currentUser?.id,
        'source_point': sourceConnectionPoint.name,
        'target_point': targetConnectionPoint.name,
      });
      
      // Reload data
      await Future.wait([
        loadTreasuryVaults(),
        loadConnections(),
        loadStatistics(),
      ]);
      
      final newConnection = _connections.firstWhere((c) => c.id == connectionId);
      
      AppLogger.info('Created treasury connection: $connectionId');
      return newConnection;
      
    } catch (e) {
      AppLogger.error('Failed to create treasury connection: $e');
      _setError('فشل في إنشاء الاتصال: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Remove treasury connection
  Future<void> removeConnection(String connectionId) async {
    try {
      _setLoading(true);
      _setError(null);
      
      AppLogger.info('Removing treasury connection: $connectionId');
      
      final currentUser = _supabase.auth.currentUser;
      
      await _supabase.rpc('remove_treasury_connection', params: {
        'connection_uuid': connectionId,
        'user_uuid': currentUser?.id,
      });
      
      // Reload data
      await Future.wait([
        loadTreasuryVaults(),
        loadConnections(),
        loadStatistics(),
      ]);
      
      AppLogger.info('Removed treasury connection successfully');
      
    } catch (e) {
      AppLogger.error('Failed to remove treasury connection: $e');
      _setError('فشل في إزالة الاتصال: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Update treasury position
  Future<void> updateTreasuryPosition({
    required String treasuryId,
    required double positionX,
    required double positionY,
  }) async {
    try {
      await _supabase
          .from('treasury_vaults')
          .update({
            'position_x': positionX,
            'position_y': positionY,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', treasuryId);

      // Update local state
      final index = _treasuryVaults.indexWhere((v) => v.id == treasuryId);
      if (index != -1) {
        _treasuryVaults[index] = _treasuryVaults[index].copyWith(
          positionX: positionX,
          positionY: positionY,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }

    } catch (e) {
      AppLogger.error('Failed to update treasury position: $e');
      // Don't throw for position updates as they're not critical
    }
  }

  /// Transfer funds between treasuries
  Future<String> transferFunds({
    required String sourceTreasuryId,
    required String targetTreasuryId,
    required double amount,
    String description = 'تحويل بين الخزائن',
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      AppLogger.info('Transferring funds: $amount from $sourceTreasuryId to $targetTreasuryId');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final transferId = await _supabase.rpc('transfer_between_treasuries', params: {
        'source_treasury_uuid': sourceTreasuryId,
        'target_treasury_uuid': targetTreasuryId,
        'transfer_amount': amount,
        'transfer_description': description,
        'user_uuid': currentUser.id,
      });

      // Reload data
      await Future.wait([
        loadTreasuryVaults(),
        loadStatistics(),
      ]);

      AppLogger.info('Fund transfer completed successfully: $transferId');
      return transferId as String;

    } catch (e) {
      AppLogger.error('Failed to transfer funds: $e');

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

      _setError(errorMessage);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Update exchange rate for a single treasury
  Future<void> updateExchangeRate(String treasuryId, double newRate) async {
    try {
      _setLoading(true);
      _setError(null);

      AppLogger.info('Updating exchange rate for treasury: $treasuryId to $newRate');

      final currentUser = _supabase.auth.currentUser;

      await _supabase.rpc('update_treasury_exchange_rate', params: {
        'treasury_uuid': treasuryId,
        'new_rate': newRate,
        'user_uuid': currentUser?.id,
      });

      // Reload data
      await Future.wait([
        loadTreasuryVaults(),
        loadStatistics(),
      ]);

      AppLogger.info('Updated exchange rate successfully');

    } catch (e) {
      AppLogger.error('Failed to update exchange rate: $e');
      _setError('فشل في تحديث سعر الصرف: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Update exchange rates for multiple treasuries (bulk update)
  Future<void> updateExchangeRatesBulk(Map<String, double> updates) async {
    try {
      _setLoading(true);
      _setError(null);

      AppLogger.info('Bulk updating exchange rates for ${updates.length} treasuries');

      final currentUser = _supabase.auth.currentUser;

      await _supabase.rpc('update_treasury_exchange_rates_bulk', params: {
        'rate_updates': updates.map((key, value) => MapEntry(key, value)),
        'user_uuid': currentUser?.id,
      });

      // Reload data
      await Future.wait([
        loadTreasuryVaults(),
        loadStatistics(),
      ]);

      AppLogger.info('Bulk updated exchange rates successfully');

    } catch (e) {
      AppLogger.error('Failed to bulk update exchange rates: $e');
      _setError('فشل في تحديث أسعار الصرف: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Archive treasury vault
  Future<void> archiveTreasury(String treasuryId) async {
    try {
      _setLoading(true);
      _setError(null);

      AppLogger.info('Archiving treasury: $treasuryId');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // Check if treasury exists and is not main treasury
      final treasury = _treasuryVaults.where((t) => t.id == treasuryId).firstOrNull;
      if (treasury == null) {
        throw Exception('الخزنة غير موجودة');
      }

      if (treasury.isMainTreasury) {
        throw Exception('لا يمكن أرشفة الخزنة الرئيسية');
      }

      // Archive treasury by adding archived flag
      await _supabase
          .from('treasury_vaults')
          .update({
            'is_archived': true,
            'archived_at': DateTime.now().toIso8601String(),
            'archived_by': currentUser.id,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', treasuryId);

      // Reload data to reflect changes
      await Future.wait([
        loadTreasuryVaults(),
        loadStatistics(),
      ]);

      AppLogger.info('Archived treasury successfully');

    } catch (e) {
      AppLogger.error('Failed to archive treasury: $e');
      _setError('فشل في أرشفة الخزنة: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete treasury vault permanently
  Future<void> deleteTreasury(String treasuryId) async {
    try {
      _setLoading(true);
      _setError(null);

      AppLogger.info('Deleting treasury permanently: $treasuryId');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // Check if treasury exists and is not main treasury
      final treasury = _treasuryVaults.where((t) => t.id == treasuryId).firstOrNull;
      if (treasury == null) {
        throw Exception('الخزنة غير موجودة');
      }

      if (treasury.isMainTreasury) {
        throw Exception('لا يمكن حذف الخزنة الرئيسية');
      }

      if (treasury.balance != 0) {
        throw Exception('لا يمكن حذف خزنة تحتوي على رصيد. يرجى تفريغ الخزنة أولاً');
      }

      // Check for existing connections
      final connections = _connections.where((c) =>
          c.sourceTreasuryId == treasuryId || c.targetTreasuryId == treasuryId).toList();

      if (connections.isNotEmpty) {
        // Remove all connections first
        for (final connection in connections) {
          await removeConnection(connection.id);
        }
      }

      // Delete all transactions for this treasury
      await _supabase
          .from('treasury_transactions')
          .delete()
          .eq('treasury_id', treasuryId);

      // Delete the treasury vault
      await _supabase
          .from('treasury_vaults')
          .delete()
          .eq('id', treasuryId);

      // Reload data to reflect changes
      await Future.wait([
        loadTreasuryVaults(),
        loadConnections(),
        loadStatistics(),
      ]);

      AppLogger.info('Deleted treasury successfully');

    } catch (e) {
      AppLogger.error('Failed to delete treasury: $e');
      _setError('فشل في حذف الخزنة: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Update treasury information
  Future<void> updateTreasuryInfo({
    required String treasuryId,
    required String name,
    String? bankName,
    String? accountNumber,
    String? accountHolderName,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      AppLogger.info('Updating treasury info: $treasuryId');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // Check if treasury exists
      final treasury = _treasuryVaults.where((t) => t.id == treasuryId).firstOrNull;
      if (treasury == null) {
        throw Exception('الخزنة غير موجودة');
      }

      // Update treasury information
      await _supabase
          .from('treasury_vaults')
          .update({
            'name': name,
            'bank_name': bankName,
            'account_number': accountNumber,
            'account_holder_name': accountHolderName,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', treasuryId);

      // Reload data to reflect changes
      await loadTreasuryVaults();

      AppLogger.info('Updated treasury info successfully');

    } catch (e) {
      AppLogger.error('Failed to update treasury info: $e');
      _setError('فشل في تحديث معلومات الخزنة: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Setup realtime subscription
  void _setupRealtimeSubscription() {
    try {
      AppLogger.info('Setting up treasury realtime subscription...');

      _treasuryChannel = _supabase
          .channel('treasury_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'treasury_vaults',
            callback: (payload) {
              AppLogger.info('Treasury vault change detected: ${payload.eventType}');
              // Refresh treasury data when changes occur
              _refreshTreasuryData();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'treasury_transactions',
            callback: (payload) {
              AppLogger.info('Treasury transaction change detected: ${payload.eventType}');
              // Refresh treasury data when transactions occur
              _refreshTreasuryData();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'treasury_connections',
            callback: (payload) {
              AppLogger.info('Treasury connection change detected: ${payload.eventType}');
              loadConnections();
            },
          )
          .subscribe();

      AppLogger.info('Treasury realtime subscription setup complete');

    } catch (e) {
      AppLogger.error('Failed to setup treasury realtime subscription: $e');
      // Fallback to periodic refresh if realtime fails
      _setupPeriodicRefresh();
    }
  }

  /// Refresh treasury data (used by realtime subscription)
  Future<void> _refreshTreasuryData() async {
    try {
      await Future.wait([
        loadTreasuryVaults(),
        loadStatistics(),
      ]);
      AppLogger.info('Treasury data refreshed successfully');
    } catch (e) {
      AppLogger.error('Failed to refresh treasury data: $e');
    }
  }

  /// Setup periodic refresh as fallback
  void _setupPeriodicRefresh() {
    _periodicRefreshTimer?.cancel(); // Cancel existing timer
    _periodicRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!_isLoading) {
        _refreshTreasuryData();
      }
    });
    AppLogger.info('Periodic treasury refresh setup complete (30s interval)');
  }

  /// Cleanup resources and subscriptions
  @override
  void dispose() {
    _treasuryChannel?.unsubscribe();
    _periodicRefreshTimer?.cancel();
    super.dispose();
  }

  /// Helper methods
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String? error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }

  /// Get connections for a specific treasury
  List<TreasuryConnection> getConnectionsForTreasury(String treasuryId) {
    return _connections.where((connection) =>
        connection.sourceTreasuryId == treasuryId ||
        connection.targetTreasuryId == treasuryId).toList();
  }

  /// Check if two treasuries are connected
  bool areConnected(String treasury1Id, String treasury2Id) {
    return _connections.any((connection) =>
        (connection.sourceTreasuryId == treasury1Id && connection.targetTreasuryId == treasury2Id) ||
        (connection.sourceTreasuryId == treasury2Id && connection.targetTreasuryId == treasury1Id));
  }

}
