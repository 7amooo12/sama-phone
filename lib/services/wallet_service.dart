import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/wallet_model.dart';
import '../models/wallet_transaction_model.dart';
import '../utils/app_logger.dart';
import '../config/supabase_schema.dart';

/// Service for managing wallet operations
class WalletService {
  // Lazy initialization to avoid accessing Supabase.instance before initialization
  SupabaseClient get _supabase {
    try {
      return Supabase.instance.client;
    } catch (e) {
      AppLogger.error('❌ Supabase not initialized yet in WalletService: $e');
      throw Exception('Supabase must be initialized before using WalletService');
    }
  }

  // Table references with lazy initialization
  get _walletsTable => _supabase.from(SupabaseSchema.wallets);
  get _transactionsTable => _supabase.from(SupabaseSchema.walletTransactions);
  get _walletSummaryView => _supabase.from('wallet_summary');

  /// Get all wallets (admin/accountant/owner access) with enhanced error handling
  Future<List<WalletModel>> getAllWallets() async {
    try {
      AppLogger.info('🔄 Fetching all wallets with enhanced error handling');

      // First get wallets with basic validation
      final walletsResponse = await _walletsTable
          .select('*')
          .order('created_at', ascending: false);

      if (walletsResponse == null) {
        AppLogger.warning('⚠️ Wallets response is null');
        return [];
      }

      final walletsList = walletsResponse as List;
      if (walletsList.isEmpty) {
        AppLogger.info('ℹ️ No wallets found in database');
        return [];
      }

      AppLogger.info('📊 Found ${walletsList.length} wallet records');

      // Get user profiles separately with error handling
      Map<String, Map<String, dynamic>> userProfilesMap = {};
      try {
        final userProfilesResponse = await _supabase
            .from('user_profiles')
            .select('id, name, email, phone_number');

        if (userProfilesResponse != null) {
          for (final profile in userProfilesResponse as List) {
            final profileData = profile as Map<String, dynamic>;
            final profileId = profileData['id']?.toString();
            if (profileId != null && profileId.isNotEmpty) {
              userProfilesMap[profileId] = profileData;
            }
          }
          AppLogger.info('📋 Loaded ${userProfilesMap.length} user profiles');
        }
      } catch (profileError) {
        AppLogger.warning('⚠️ Failed to load user profiles: $profileError');
        // Continue without user profiles - wallets will still work
      }

      // Process wallets with enhanced error handling
      final wallets = <WalletModel>[];
      int successCount = 0;
      int errorCount = 0;

      for (int i = 0; i < walletsList.length; i++) {
        try {
          final data = walletsList[i] as Map<String, dynamic>;

          // Validate essential wallet data
          if (data['id'] == null || data['user_id'] == null || data['role'] == null) {
            AppLogger.warning('⚠️ Skipping wallet ${i + 1}: Missing essential fields. Data: $data');
            errorCount++;
            continue;
          }

          // Add joined data to the main data map
          final walletData = Map<String, dynamic>.from(data);
          final userId = data['user_id']?.toString();

          if (userId != null && userProfilesMap.containsKey(userId)) {
            final userProfile = userProfilesMap[userId]!;
            walletData['user_name'] = userProfile['name'];
            walletData['user_email'] = userProfile['email'];
            walletData['phone_number'] = userProfile['phone_number'];
          } else {
            // Set default values if user profile not found
            walletData['user_name'] = 'مستخدم غير معروف';
            walletData['user_email'] = null;
            walletData['phone_number'] = null;
          }

          final wallet = WalletModel.fromDatabase(walletData);
          wallets.add(wallet);
          successCount++;

        } catch (walletError) {
          AppLogger.error('❌ Error processing wallet ${i + 1}: $walletError');
          errorCount++;
          continue; // Skip this wallet and continue with others
        }
      }

      AppLogger.info('✅ Successfully processed $successCount wallets, $errorCount errors');

      if (wallets.isEmpty && walletsList.isNotEmpty) {
        throw Exception('Failed to process any wallets from ${walletsList.length} records');
      }

      return wallets;
    } catch (e) {
      AppLogger.error('❌ Critical error fetching wallets: $e');
      throw Exception('Failed to fetch wallets: $e');
    }
  }

  /// Get wallets by role with enhanced validation and role consistency checks
  Future<List<WalletModel>> getWalletsByRole(String role) async {
    try {
      AppLogger.info('🔄 Fetching wallets for role: $role with enhanced validation');

      // Enhanced query that joins wallets with user_profiles using the new relationship
      final walletsResponse = await _supabase
          .from('wallets')
          .select('''
            *,
            user_profiles!user_profile_id(
              id,
              name,
              email,
              phone_number,
              role,
              status
            )
          ''')
          .eq('role', role)
          .or(role == 'client' ? 'user_profiles.role.eq.client,user_profiles.role.eq.عميل' : 'user_profiles.role.eq.$role') // Support Arabic role names for clients
          .or('user_profiles.status.eq.approved,user_profiles.status.eq.active') // FIXED: Apply status filter to user_profiles table
          .order('created_at', ascending: false);

      if (walletsResponse == null || walletsResponse.isEmpty) {
        AppLogger.info('ℹ️ No wallets found for role: $role');
        return [];
      }

      AppLogger.info('📊 Found ${walletsResponse.length} wallets for role: $role');

      // Validate role consistency and filter out any inconsistent data
      final validWallets = <Map<String, dynamic>>[];
      int inconsistentCount = 0;

      for (final walletData in walletsResponse) {
        final walletRole = walletData['role'] as String?;
        final userProfile = walletData['user_profiles'] as Map<String, dynamic>?;
        final userRole = userProfile?['role'] as String?;
        final userStatus = userProfile?['status'] as String?;

        // Validate role consistency - FIXED: Accept both 'approved' and 'active' statuses
        // Support Arabic role names for clients
        final roleMatches = walletRole == role &&
            (userRole == role || (role == 'client' && userRole == 'عميل'));
        final statusValid = userStatus == 'approved' || userStatus == 'active';

        if (roleMatches && statusValid && userProfile != null) {
          validWallets.add(walletData);
        } else {
          inconsistentCount++;
          AppLogger.warning('⚠️ Role inconsistency detected: wallet_role=$walletRole, user_role=$userRole, user_status=$userStatus');
        }
      }

      if (inconsistentCount > 0) {
        AppLogger.warning('⚠️ Found $inconsistentCount wallets with role inconsistencies for role: $role');
        AppLogger.warning('💡 Consider running the wallet role consistency fix script');
      }

      // Convert to WalletModel objects
      final wallets = <WalletModel>[];
      for (final walletData in validWallets) {
        try {
          final userProfile = walletData['user_profiles'] as Map<String, dynamic>;

          // Create wallet model with user profile data
          final wallet = WalletModel.fromDatabase({
            ...walletData,
            'user_name': userProfile['name'],
            'user_email': userProfile['email'],
            'phone_number': userProfile['phone_number'],
          });

          wallets.add(wallet);
        } catch (e) {
          AppLogger.error('❌ Error parsing wallet data: $e');
          continue; // Skip invalid wallet data
        }
      }

      AppLogger.info('✅ Successfully fetched ${wallets.length} valid wallets for role: $role');

      // Log detailed information about found wallets
      for (final wallet in wallets) {
        AppLogger.info('   💰 Wallet: ${wallet.userName} (${wallet.userEmail}) - Balance: ${wallet.balance} ${wallet.currency}');
      }

      return wallets;
    } catch (e) {
      AppLogger.error('❌ Error fetching wallets by role: $e');

      // Fallback: Try alternative approach with separate queries
      AppLogger.info('🔄 Attempting fallback approach with separate queries...');
      try {
        return await _getWalletsByRoleFallback(role);
      } catch (fallbackError) {
        AppLogger.error('❌ Fallback approach also failed: $fallbackError');
        throw Exception('Failed to fetch wallets by role: $e');
      }
    }
  }

  /// Fallback method to get wallets by role using separate queries
  Future<List<WalletModel>> _getWalletsByRoleFallback(String role) async {
    AppLogger.info('🔄 Using fallback approach for role: $role');

    // Step 1: Get approved and active user profiles with the specified role
    // FIXED: Use proper filtering for both role and status conditions
    // Support both English and Arabic role names for clients
    final userProfilesResponse = await _supabase
        .from('user_profiles')
        .select('id, name, email, phone_number, role, status')
        .or(role == 'client' ? 'role.eq.client,role.eq.عميل' : 'role.eq.$role') // Support Arabic role names for clients
        .or('status.eq.approved,status.eq.active'); // Support both status values

    if (userProfilesResponse.isEmpty) {
      AppLogger.warning('⚠️ No approved or active users found for role: $role');
      AppLogger.info('💡 Trying alternative approach to find users...');

      // Try alternative query without role filtering to debug
      final allUsersResponse = await _supabase
          .from('user_profiles')
          .select('id, name, email, phone_number, role, status')
          .or('status.eq.approved,status.eq.active');

      AppLogger.info('📊 Found ${allUsersResponse.length} total approved/active users');
      final roleUsers = allUsersResponse.where((user) =>
          user['role'] == role ||
          (role == 'client' && user['role'] == 'عميل')).toList();
      AppLogger.info('📊 Found ${roleUsers.length} users with role: $role');

      if (roleUsers.isEmpty) {
        return [];
      }
    }

    // Step 2: Get user IDs
    final userIds = userProfilesResponse
        .map((profile) => profile['id'] as String)
        .toList();

    // Step 3: Get wallets for these users
    // Use filter with 'in' operator for PostgREST 2.4.2 compatibility
    final walletsResponse = await _supabase
        .from('wallets')
        .select('*')
        .eq('role', role)
        .filter('user_id', 'in', '(${userIds.join(',')})')
        .order('created_at', ascending: false);

    // Step 4: Create a map of user profiles for quick lookup
    final userProfilesMap = <String, Map<String, dynamic>>{};
    for (final profile in userProfilesResponse) {
      userProfilesMap[profile['id'] as String] = profile;
    }

    // Step 5: Combine wallet data with user profile data
    final wallets = <WalletModel>[];
    for (final walletData in walletsResponse) {
      try {
        final userId = walletData['user_id'] as String;
        final userProfile = userProfilesMap[userId];

        if (userProfile != null) {
          // Validate role consistency for fallback method too
          final walletRole = walletData['role'] as String?;
          final userRole = userProfile['role'] as String?;
          final userStatus = userProfile['status'] as String?;

          final roleMatches = walletRole == role &&
              (userRole == role || (role == 'client' && userRole == 'عميل'));
          final statusValid = userStatus == 'approved' || userStatus == 'active';

          if (roleMatches && statusValid) {
            // Create wallet model with user profile data
            final wallet = WalletModel.fromDatabase({
              ...walletData,
              'user_name': userProfile['name'],
              'user_email': userProfile['email'],
              'phone_number': userProfile['phone_number'],
            });

            wallets.add(wallet);
          } else {
            AppLogger.warning('⚠️ Fallback: Role/status mismatch for wallet ${walletData['id']}: wallet_role=$walletRole, user_role=$userRole, user_status=$userStatus');
          }
        } else {
          AppLogger.warning('⚠️ No user profile found for wallet ${walletData['id']}');
        }
      } catch (e) {
        AppLogger.error('❌ Error parsing wallet data in fallback: $e');
        continue;
      }
    }

    AppLogger.info('✅ Fallback approach successful: ${wallets.length} wallets for role: $role');

    // Log detailed information about found wallets
    for (final wallet in wallets) {
      AppLogger.info('   💰 Wallet: ${wallet.userName} (${wallet.userEmail}) - Balance: ${wallet.balance} ${wallet.currency}');
    }

    return wallets;
  }

  /// Get user's wallet (create if doesn't exist)
  Future<WalletModel?> getUserWallet(String userId) async {
    try {
      AppLogger.info('🔄 Fetching wallet for user: $userId');

      final response = await _walletsTable
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        final wallet = WalletModel.fromDatabase(response as Map<String, dynamic>);
        AppLogger.info('✅ Fetched existing wallet for user: $userId');
        return wallet;
      }

      // If no wallet exists, create one
      AppLogger.info('📝 Creating new wallet for user: $userId');
      return await _createWalletForUser(userId);
    } catch (e) {
      AppLogger.error('❌ Error fetching user wallet: $e');
      return null; // Return null instead of throwing to prevent app crashes
    }
  }

  /// Create wallet for user automatically with enhanced validation
  Future<WalletModel?> _createWalletForUser(String userId) async {
    try {
      // Get user profile to determine role and validate user status
      final userProfile = await _supabase
          .from('user_profiles')
          .select('role, status, name, email')
          .eq('id', userId)
          .single();

      final role = userProfile['role'] as String;
      final status = userProfile['status'] as String;
      final userName = userProfile['name'] as String?;
      final userEmail = userProfile['email'] as String?;

      // Validate user status before creating wallet
      if (status != 'approved') {
        AppLogger.warning('⚠️ Cannot create wallet for non-approved user: $userId (status: $status)');
        return null;
      }

      // Validate role
      if (!['admin', 'accountant', 'owner', 'client', 'worker', 'warehouseManager'].contains(role)) {
        AppLogger.error('❌ Invalid user role for wallet creation: $role');
        return null;
      }

      final initialBalance = _getInitialBalance(role);

      AppLogger.info('🔄 Creating wallet for approved user: $userName ($userEmail) with role: $role');

      // Create wallet with validated role
      final wallet = await createWallet(
        userId: userId,
        role: role,
        initialBalance: initialBalance,
      );

      // Add initial transaction if balance > 0
      if (initialBalance > 0) {
        await createTransaction(
          walletId: wallet.id,
          userId: userId,
          transactionType: TransactionType.credit,
          amount: initialBalance,
          description: 'رصيد ابتدائي',
          createdBy: userId,
        );
      }

      AppLogger.info('✅ Created new wallet for user: $userName ($userId) with role: $role');
      return wallet;
    } catch (e) {
      AppLogger.error('❌ Error creating wallet for user: $e');
      return null;
    }
  }

  /// Get initial balance based on role
  double _getInitialBalance(String role) {
    switch (role) {
      case 'client':
        return 1000.0;
      case 'worker':
        return 500.0;
      default:
        return 0.0;
    }
  }

  /// Create wallet for user
  Future<WalletModel> createWallet({
    required String userId,
    required String role,
    double initialBalance = 0.0,
    String currency = 'EGP',
  }) async {
    try {
      AppLogger.info('🔄 Creating wallet for user: $userId, role: $role');

      final walletData = {
        'user_id': userId,
        'role': role,
        'balance': initialBalance,
        'currency': currency,
        'status': 'active',
      };

      final response = await _walletsTable
          .insert(walletData)
          .select()
          .single();

      final wallet = WalletModel.fromDatabase(response as Map<String, dynamic>);
      AppLogger.info('✅ Created wallet for user: $userId');
      return wallet;
    } catch (e) {
      AppLogger.error('❌ Error creating wallet: $e');
      throw Exception('Failed to create wallet: $e');
    }
  }

  /// Get wallet by user ID (throws exception if not found)
  Future<WalletModel> getWalletByUserId(String userId) async {
    try {
      AppLogger.info('🔄 Getting wallet for user: $userId');

      final response = await _walletsTable
          .select()
          .eq('user_id', userId)
          .single();

      final wallet = WalletModel.fromDatabase(response as Map<String, dynamic>);
      AppLogger.info('✅ Retrieved wallet for user: $userId');
      return wallet;
    } catch (e) {
      AppLogger.error('❌ Error getting wallet for user: $e');
      throw Exception('فشل في جلب المحفظة: $e');
    }
  }

  /// Update wallet status
  Future<bool> updateWalletStatus(String walletId, WalletStatus status) async {
    try {
      AppLogger.info('🔄 Updating wallet status: $walletId to $status');

      await _walletsTable
          .update({
            'status': status.toString().split('.').last,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', walletId);

      AppLogger.info('✅ Updated wallet status');
      return true;
    } catch (e) {
      AppLogger.error('❌ Error updating wallet status: $e');
      return false;
    }
  }

  /// تحديث رصيد المحفظة مباشرة
  Future<WalletModel> updateWalletBalance({
    required String walletId,
    required double newBalance,
    String? description,
  }) async {
    try {
      AppLogger.info('🔄 Updating wallet balance: $walletId to $newBalance');

      final updateData = {
        'balance': newBalance,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _walletsTable
          .update(updateData)
          .eq('id', walletId)
          .select()
          .single();

      // إضافة معاملة للتوثيق
      if (description != null) {
        await _transactionsTable.insert({
          'wallet_id': walletId,
          'transaction_type': newBalance >= 0 ? 'credit' : 'debit',
          'amount': newBalance.abs(),
          'description': description,
          'created_at': DateTime.now().toIso8601String(),
          'status': 'completed',
        });
      }

      final wallet = WalletModel.fromDatabase(response as Map<String, dynamic>);
      AppLogger.info('✅ Updated wallet balance: $walletId');
      return wallet;
    } catch (e) {
      AppLogger.error('❌ Error updating wallet balance: $e');
      throw Exception('فشل في تحديث رصيد المحفظة: $e');
    }
  }

  /// Get wallet transactions with enhanced error handling
  Future<List<WalletTransactionModel>> getWalletTransactions(
    String walletId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      AppLogger.info('🔄 Fetching transactions for wallet: $walletId (limit: $limit, offset: $offset)');

      // Validate input parameters
      if (walletId.isEmpty) {
        throw Exception('Wallet ID cannot be empty');
      }

      final response = await _transactionsTable
          .select('*')
          .eq('wallet_id', walletId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (response == null) {
        AppLogger.warning('⚠️ Transactions response is null for wallet: $walletId');
        return [];
      }

      final transactionsList = response as List;
      if (transactionsList.isEmpty) {
        AppLogger.info('ℹ️ No transactions found for wallet: $walletId');
        return [];
      }

      AppLogger.info('📊 Found ${transactionsList.length} transaction records for wallet: $walletId');

      // Process transactions with enhanced error handling
      final transactions = <WalletTransactionModel>[];
      int successCount = 0;
      int errorCount = 0;

      for (int i = 0; i < transactionsList.length; i++) {
        try {
          final data = transactionsList[i] as Map<String, dynamic>;

          // Validate essential transaction data
          if (data['id'] == null || data['wallet_id'] == null || data['user_id'] == null) {
            AppLogger.warning('⚠️ Skipping transaction ${i + 1}: Missing essential fields. Data: $data');
            errorCount++;
            continue;
          }

          final transaction = WalletTransactionModel.fromDatabase(data);
          transactions.add(transaction);
          successCount++;

        } catch (transactionError) {
          AppLogger.error('❌ Error processing transaction ${i + 1} for wallet $walletId: $transactionError');
          errorCount++;
          continue; // Skip this transaction and continue with others
        }
      }

      AppLogger.info('✅ Successfully processed $successCount transactions for wallet $walletId, $errorCount errors');

      if (transactions.isEmpty && transactionsList.isNotEmpty) {
        AppLogger.warning('⚠️ Failed to process any transactions from ${transactionsList.length} records for wallet $walletId');
        // Return empty list instead of throwing error to prevent app crash
        return [];
      }

      return transactions;
    } catch (e) {
      AppLogger.error('❌ Critical error fetching wallet transactions for $walletId: $e');
      // Return empty list instead of throwing error to prevent app crash
      return [];
    }
  }

  /// Get user transactions with enhanced error handling
  Future<List<WalletTransactionModel>> getUserTransactions(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      AppLogger.info('🔄 Fetching transactions for user: $userId (limit: $limit, offset: $offset)');

      // Validate input parameters
      if (userId.isEmpty) {
        throw Exception('User ID cannot be empty');
      }

      final response = await _transactionsTable
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (response == null) {
        AppLogger.warning('⚠️ Transactions response is null for user: $userId');
        return [];
      }

      final transactionsList = response as List;
      if (transactionsList.isEmpty) {
        AppLogger.info('ℹ️ No transactions found for user: $userId');
        return [];
      }

      AppLogger.info('📊 Found ${transactionsList.length} transaction records for user: $userId');

      // Process transactions with enhanced error handling
      final transactions = <WalletTransactionModel>[];
      int successCount = 0;
      int errorCount = 0;

      for (int i = 0; i < transactionsList.length; i++) {
        try {
          final data = transactionsList[i] as Map<String, dynamic>;

          // Validate essential transaction data
          if (data['id'] == null || data['wallet_id'] == null || data['user_id'] == null) {
            AppLogger.warning('⚠️ Skipping transaction ${i + 1}: Missing essential fields. Data: $data');
            errorCount++;
            continue;
          }

          final transaction = WalletTransactionModel.fromDatabase(data);
          transactions.add(transaction);
          successCount++;

        } catch (transactionError) {
          AppLogger.error('❌ Error processing transaction ${i + 1} for user $userId: $transactionError');
          errorCount++;
          continue; // Skip this transaction and continue with others
        }
      }

      AppLogger.info('✅ Successfully processed $successCount transactions for user $userId, $errorCount errors');

      if (transactions.isEmpty && transactionsList.isNotEmpty) {
        AppLogger.warning('⚠️ Failed to process any transactions from ${transactionsList.length} records for user $userId');
        // Return empty list instead of throwing error to prevent app crash
        return [];
      }

      return transactions;
    } catch (e) {
      AppLogger.error('❌ Critical error fetching user transactions for $userId: $e');
      // Return empty list instead of throwing error to prevent app crash
      return [];
    }
  }

  /// Create transaction
  Future<WalletTransactionModel> createTransaction({
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
    try {
      AppLogger.info('🔄 Creating transaction: $transactionType, amount: $amount');

      // Get current wallet balance
      final walletResponse = await _walletsTable
          .select('balance')
          .eq('id', walletId)
          .single();

      final currentBalance = (walletResponse['balance'] as num).toDouble();

      // Calculate new balance
      final isCredit = [
        TransactionType.credit,
        TransactionType.reward,
        TransactionType.salary,
        TransactionType.bonus,
        TransactionType.refund,
      ].contains(transactionType);

      final newBalance = isCredit ? currentBalance + amount : currentBalance - amount;

      final transactionData = {
        'wallet_id': walletId,
        'user_id': userId,
        'transaction_type': transactionType.toString().split('.').last,
        'amount': amount,
        'balance_before': currentBalance,
        'balance_after': newBalance,
        'description': description,
        'created_by': createdBy,
        'reference_id': referenceId,
        'reference_type': referenceType?.toString().split('.').last,
        'metadata': metadata,
        'status': 'completed',
      };

      final response = await _transactionsTable
          .insert(transactionData)
          .select()
          .single();

      // Update wallet balance
      await _walletsTable
          .update({'balance': newBalance, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', walletId);

      final transaction = WalletTransactionModel.fromDatabase(response as Map<String, dynamic>);
      AppLogger.info('✅ Created transaction: ${transaction.id}');
      return transaction;
    } catch (e) {
      AppLogger.error('❌ Error creating transaction: $e');
      throw Exception('Failed to create transaction: $e');
    }
  }

  /// Get wallet statistics
  Future<Map<String, dynamic>> getWalletStatistics() async {
    try {
      AppLogger.info('🔄 Fetching wallet statistics');

      // Get total balances by role
      final walletStats = await _walletsTable
          .select('role, balance')
          .eq('status', 'active');

      // Calculate statistics
      double totalClientBalance = 0;
      double totalWorkerBalance = 0;
      int clientCount = 0;
      int workerCount = 0;

      for (final wallet in walletStats as List) {
        final walletData = wallet as Map<String, dynamic>;
        final role = walletData['role'] as String;
        final balance = (walletData['balance'] as num).toDouble();

        if (role == 'client') {
          totalClientBalance += balance;
          clientCount++;
        } else if (role == 'worker') {
          totalWorkerBalance += balance;
          workerCount++;
        }
      }

      // Get transaction count for current month
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      final monthlyTransactions = await _transactionsTable
          .select('id')
          .filter('created_at', 'gte', startOfMonth.toIso8601String())
          .count();

      final stats = {
        'total_client_balance': totalClientBalance,
        'total_worker_balance': totalWorkerBalance,
        'client_count': clientCount,
        'worker_count': workerCount,
        'monthly_transaction_count': monthlyTransactions.count,
        'total_balance': totalClientBalance + totalWorkerBalance,
      };

      AppLogger.info('✅ Fetched wallet statistics');
      return stats;
    } catch (e) {
      AppLogger.error('❌ Error fetching wallet statistics: $e');
      throw Exception('Failed to fetch wallet statistics: $e');
    }
  }

  /// Validate wallet role consistency across the system
  Future<Map<String, dynamic>> validateWalletRoleConsistency() async {
    try {
      AppLogger.info('🔍 Validating wallet role consistency...');

      // Query to find role mismatches between user_profiles and wallets
      final inconsistentData = await _supabase
          .from('wallets')
          .select('''
            id,
            user_id,
            role as wallet_role,
            user_profiles!inner(
              id,
              name,
              email,
              role as user_role,
              status
            )
          ''')
          .neq('role', 'user_profiles.role');

      // Query to find approved and active users without wallets
      final usersWithoutWallets = await _supabase
          .from('user_profiles')
          .select('id, name, email, role, status')
          .or('status.eq.approved,status.eq.active') // Support both status values
          .not('id', 'in', '(SELECT user_id FROM wallets)');

      final inconsistentCount = (inconsistentData as List).length;
      final missingWalletsCount = (usersWithoutWallets as List).length;

      final validationResult = {
        'is_consistent': inconsistentCount == 0 && missingWalletsCount == 0,
        'inconsistent_wallets': inconsistentCount,
        'missing_wallets': missingWalletsCount,
        'total_issues': inconsistentCount + missingWalletsCount,
        'inconsistent_data': inconsistentData,
        'users_without_wallets': usersWithoutWallets,
        'validation_timestamp': DateTime.now().toIso8601String(),
      };

      if (validationResult['total_issues'] == 0) {
        AppLogger.info('✅ Wallet role consistency validation passed - no issues found');
      } else {
        AppLogger.warning('⚠️ Wallet role consistency validation found ${validationResult['total_issues']} issues');
        AppLogger.warning('   - Inconsistent wallets: $inconsistentCount');
        AppLogger.warning('   - Missing wallets: $missingWalletsCount');
      }

      return validationResult;
    } catch (e) {
      AppLogger.error('❌ Error validating wallet role consistency: $e');
      throw Exception('Failed to validate wallet role consistency: $e');
    }
  }

  /// Fix wallet role inconsistencies automatically
  Future<Map<String, dynamic>> fixWalletRoleInconsistencies() async {
    try {
      AppLogger.info('🔧 Starting automatic wallet role consistency fix...');

      // First, validate current state
      final validationResult = await validateWalletRoleConsistency();

      if (validationResult['is_consistent'] == true) {
        AppLogger.info('✅ No wallet role inconsistencies found - nothing to fix');
        return {
          'success': true,
          'message': 'No inconsistencies found',
          'fixed_wallets': 0,
          'created_wallets': 0,
        };
      }

      int fixedWallets = 0;
      int createdWallets = 0;

      // Fix inconsistent wallet roles
      final inconsistentData = validationResult['inconsistent_data'] as List;
      for (final walletData in inconsistentData) {
        final wallet = walletData as Map<String, dynamic>;
        final userProfile = wallet['user_profiles'] as Map<String, dynamic>;
        final walletId = wallet['id'] as String;
        final correctRole = userProfile['user_role'] as String;

        await _walletsTable
            .update({'role': correctRole, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', walletId);

        fixedWallets++;
        AppLogger.info('🔧 Fixed wallet role for user: ${userProfile['name']} (${userProfile['email']})');
      }

      // Create missing wallets
      final usersWithoutWallets = validationResult['users_without_wallets'] as List;
      for (final userData in usersWithoutWallets) {
        final user = userData as Map<String, dynamic>;
        final userId = user['id'] as String;
        final role = user['role'] as String;
        final initialBalance = _getInitialBalance(role);

        await createWallet(
          userId: userId,
          role: role,
          initialBalance: initialBalance,
        );

        createdWallets++;
        AppLogger.info('🔧 Created missing wallet for user: ${user['name']} (${user['email']})');
      }

      final result = {
        'success': true,
        'message': 'Wallet role inconsistencies fixed successfully',
        'fixed_wallets': fixedWallets,
        'created_wallets': createdWallets,
        'total_fixes': fixedWallets + createdWallets,
      };

      AppLogger.info('✅ Wallet role consistency fix completed:');
      AppLogger.info('   - Fixed wallet roles: $fixedWallets');
      AppLogger.info('   - Created missing wallets: $createdWallets');
      AppLogger.info('   - Total fixes: ${result['total_fixes']}');

      return result;
    } catch (e) {
      AppLogger.error('❌ Error fixing wallet role inconsistencies: $e');
      throw Exception('Failed to fix wallet role inconsistencies: $e');
    }
  }
}
