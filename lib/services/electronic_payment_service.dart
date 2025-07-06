import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/electronic_payment_model.dart';
import '../models/payment_account_model.dart';
import '../models/electronic_wallet_model.dart';
import '../models/electronic_wallet_transaction_model.dart';
import '../utils/app_logger.dart';
import 'electronic_wallet_service.dart';

/// Service for managing electronic payments
class ElectronicPaymentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Table references
  SupabaseQueryBuilder get _paymentsTable => _supabase.from('electronic_payments');
  SupabaseQueryBuilder get _accountsTable => _supabase.from('payment_accounts');

  /// Get all active payment accounts
  Future<List<PaymentAccountModel>> getActivePaymentAccounts() async {
    try {
      AppLogger.info('🔄 Fetching active payment accounts');

      // First check if table exists
      try {
        await _accountsTable.select('id').limit(1);
      } catch (e) {
        if (e.toString().contains('42P01') || e.toString().contains('does not exist')) {
          throw Exception('Payment accounts table does not exist. Please run the database migration script.');
        }
        rethrow;
      }

      final response = await _accountsTable
          .select()
          .eq('is_active', true)
          .order('account_type');

      final accounts = (response as List)
          .map((json) => PaymentAccountModel.fromDatabase(json))
          .toList();

      AppLogger.info('✅ Fetched ${accounts.length} active payment accounts');
      return accounts;
    } catch (e) {
      AppLogger.error('❌ Error fetching payment accounts: $e');

      // Provide more specific error messages
      if (e.toString().contains('42P01')) {
        throw Exception('Database table "payment_accounts" does not exist. Please run the migration script.');
      } else if (e.toString().contains('permission denied')) {
        throw Exception('Permission denied. Please check your user role and RLS policies.');
      }

      throw Exception('Failed to fetch payment accounts: $e');
    }
  }

  /// Get payment accounts by type
  Future<List<PaymentAccountModel>> getPaymentAccountsByType(String accountType) async {
    try {
      AppLogger.info('🔄 Fetching payment accounts for type: $accountType');

      final response = await _accountsTable
          .select()
          .eq('account_type', accountType)
          .eq('is_active', true)
          .order('account_holder_name');

      final accounts = (response as List)
          .map((json) => PaymentAccountModel.fromDatabase(json))
          .toList();

      AppLogger.info('✅ Fetched ${accounts.length} accounts for type: $accountType');
      return accounts;
    } catch (e) {
      AppLogger.error('❌ Error fetching payment accounts by type: $e');
      throw Exception('Failed to fetch payment accounts: $e');
    }
  }

  /// Ensure payment account exists for electronic wallet
  Future<String> ensurePaymentAccountForWallet(String walletId) async {
    try {
      AppLogger.info('🔄 Ensuring payment account exists for wallet: $walletId');

      // First, try to find existing payment account for this wallet
      final existingResponse = await _accountsTable
          .select('id')
          .eq('id', walletId)
          .maybeSingle();

      if (existingResponse != null) {
        AppLogger.info('✅ Payment account already exists for wallet: $walletId');
        return existingResponse['id'] as String;
      }

      // If not found, get wallet details and create payment account
      final walletResponse = await _supabase
          .from('electronic_wallets')
          .select('id, wallet_type, wallet_name, phone_number')
          .eq('id', walletId)
          .single();

      final accountData = {
        'id': walletId, // Use same ID as wallet
        'account_type': walletResponse['wallet_type'],
        'account_number': walletResponse['phone_number'],
        'account_holder_name': walletResponse['wallet_name'],
        'is_active': true,
      };

      final response = await _accountsTable
          .insert(accountData)
          .select('id')
          .single();

      AppLogger.info('✅ Created payment account for wallet: $walletId');
      return response['id'] as String;
    } catch (e) {
      AppLogger.error('❌ Error ensuring payment account for wallet: $e');
      throw Exception('Failed to ensure payment account: $e');
    }
  }

  /// Create a new electronic payment
  Future<ElectronicPaymentModel> createPayment({
    required String clientId,
    required ElectronicPaymentMethod paymentMethod,
    required double amount,
    required String recipientAccountId,
    String? proofImageUrl,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      AppLogger.info('🔄 Creating electronic payment for client: $clientId');

      // Ensure the payment account exists for the wallet
      final validAccountId = await ensurePaymentAccountForWallet(recipientAccountId);

      final paymentData = {
        'client_id': clientId,
        'payment_method': _paymentMethodToString(paymentMethod),
        'amount': amount,
        'recipient_account_id': validAccountId,
        'proof_image_url': proofImageUrl,
        'status': 'pending',
        'metadata': metadata ?? {},
      };

      final response = await _paymentsTable
          .insert(paymentData)
          .select()
          .single();

      final payment = ElectronicPaymentModel.fromDatabase(response);
      AppLogger.info('✅ Created electronic payment: ${payment.id}');
      return payment;
    } catch (e) {
      AppLogger.error('❌ Error creating electronic payment: $e');
      throw Exception('Failed to create payment: $e');
    }
  }

  /// Get payments for a specific client
  Future<List<ElectronicPaymentModel>> getClientPayments(String clientId) async {
    try {
      AppLogger.info('🔄 Fetching payments for client: $clientId');

      final response = await _paymentsTable
          .select('''
            *,
            payment_accounts!recipient_account_id (
              account_number,
              account_holder_name
            )
          ''')
          .eq('client_id', clientId)
          .order('created_at', ascending: false);

      final payments = (response as List).map((json) {
        // Flatten the joined data
        final flattenedJson = Map<String, dynamic>.from(json);
        if (json['payment_accounts'] != null) {
          final accountData = json['payment_accounts'] as Map<String, dynamic>;
          flattenedJson['recipient_account_number'] = accountData['account_number'];
          flattenedJson['recipient_account_holder_name'] = accountData['account_holder_name'];
        }
        flattenedJson.remove('payment_accounts');
        
        return ElectronicPaymentModel.fromDatabase(flattenedJson);
      }).toList();

      AppLogger.info('✅ Fetched ${payments.length} payments for client: $clientId');
      return payments;
    } catch (e) {
      AppLogger.error('❌ Error fetching client payments: $e');
      throw Exception('Failed to fetch payments: $e');
    }
  }

  /// Get approved electronic payments for a specific wallet
  Future<List<ElectronicPaymentModel>> getApprovedPaymentsForWallet(String walletId) async {
    try {
      AppLogger.info('🔄 Fetching approved payments for wallet: $walletId');

      // Use basic query to avoid relationship errors
      final response = await _paymentsTable
          .select('*')
          .eq('status', 'approved')
          .eq('recipient_account_id', walletId)
          .order('approved_at', ascending: false);

      final payments = (response as List).map((json) {
        return ElectronicPaymentModel.fromDatabase(json);
      }).toList();

      // Enrich with related data separately
      await _enrichPaymentsWithRelatedData(payments);

      AppLogger.info('✅ Fetched ${payments.length} approved payments for wallet: $walletId');
      return payments;
    } catch (e) {
      AppLogger.error('❌ Error fetching approved payments for wallet: $e');
      throw Exception('Failed to fetch approved payments: $e');
    }
  }

  /// Get all payments for admin/accountant management
  Future<List<ElectronicPaymentModel>> getAllPayments({
    ElectronicPaymentStatus? statusFilter,
    ElectronicPaymentMethod? methodFilter,
    int? limit,
    int? offset,
  }) async {
    try {
      AppLogger.info('🔄 Fetching all payments for management');

      // First check if table exists
      try {
        await _paymentsTable.select('id').limit(1);
      } catch (e) {
        if (e.toString().contains('42P01') || e.toString().contains('does not exist')) {
          throw Exception('Electronic payments table does not exist. Please run the database migration script.');
        }
        rethrow;
      }

      // Use basic query without foreign key relationships to avoid PGRST200 errors
      var query = _paymentsTable.select('*');

      // Apply filters
      if (statusFilter != null) {
        query = query.eq('status', _statusToString(statusFilter));
      }
      if (methodFilter != null) {
        query = query.eq('payment_method', _paymentMethodToString(methodFilter));
      }

      // Apply ordering and pagination
      final finalQuery = query.order('created_at', ascending: false);

      final paginatedQuery = (limit != null && offset != null)
          ? finalQuery.range(offset, offset + limit - 1)
          : (limit != null)
              ? finalQuery.limit(limit)
              : finalQuery;

      final response = await paginatedQuery;

      // Convert response to list and create payment models
      final payments = (response as List).map((json) {
        // Create a copy of the JSON data
        final paymentData = Map<String, dynamic>.from(json);

        // For now, we'll create payments without joined data
        // The UI can handle missing client names gracefully
        return ElectronicPaymentModel.fromDatabase(paymentData);
      }).toList();

      // Optionally fetch related data separately (if needed for UI)
      await _enrichPaymentsWithRelatedData(payments);

      AppLogger.info('✅ Fetched ${payments.length} payments for management');
      return payments;
    } catch (e) {
      AppLogger.error('❌ Error fetching all payments: $e');

      // Provide more specific error messages
      if (e.toString().contains('42P01')) {
        throw Exception('Database table "electronic_payments" does not exist. Please run the migration script.');
      } else if (e.toString().contains('PGRST200') || e.toString().contains('relationship')) {
        throw Exception('Database relationship error. Using basic query without joins.');
      } else if (e.toString().contains('permission denied')) {
        throw Exception('Permission denied. Please check your user role and RLS policies.');
      }

      throw Exception('Failed to fetch payments: $e');
    }
  }

  /// Update payment status (approve/reject)
  Future<ElectronicPaymentModel> updatePaymentStatus({
    required String paymentId,
    required ElectronicPaymentStatus status,
    required String approvedBy,
    String? adminNotes,
  }) async {
    try {
      AppLogger.info('🔄 Updating payment status: $paymentId to ${status.name}');

      if (status == ElectronicPaymentStatus.approved) {
        // For approval, use the dual wallet transaction function
        return await _processPaymentApproval(
          paymentId: paymentId,
          approvedBy: approvedBy,
          adminNotes: adminNotes,
        );
      } else {
        // For rejection or other status updates, use simple update
        final updateData = {
          'status': _statusToString(status),
          'approved_by': approvedBy,
          'approved_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        if (adminNotes != null) {
          updateData['admin_notes'] = adminNotes;
        }

        final response = await _paymentsTable
            .update(updateData)
            .eq('id', paymentId)
            .select()
            .single();

        final payment = ElectronicPaymentModel.fromDatabase(response);
        AppLogger.info('✅ Updated payment status: ${payment.id}');
        return payment;
      }
    } catch (e) {
      AppLogger.error('❌ Error updating payment status: $e');

      // Provide more specific error messages
      if (e.toString().contains('does not exist')) {
        throw Exception(
          'Database function missing. Please ensure the dual wallet transaction function is installed. Error: $e'
        );
      } else if (e.toString().contains('Insufficient balance')) {
        throw Exception('Client has insufficient wallet balance for this payment');
      } else if (e.toString().contains('not found')) {
        throw Exception('Payment or wallet not found');
      } else {
        throw Exception('Failed to update payment status: $e');
      }
    }
  }

  /// Process payment approval using dual wallet transaction with enhanced error handling
  Future<ElectronicPaymentModel> _processPaymentApproval({
    required String paymentId,
    required String approvedBy,
    String? adminNotes,
  }) async {
    try {
      AppLogger.info('🔄 Processing payment approval with dual wallet transaction - paymentId: $paymentId, approvedBy: $approvedBy');

      // Get payment details first with better error handling
      final paymentResponse = await _paymentsTable
          .select('*, client_id, amount')
          .eq('id', paymentId)
          .maybeSingle();

      if (paymentResponse == null) {
        throw Exception('Payment not found: $paymentId');
      }

      final payment = ElectronicPaymentModel.fromDatabase(paymentResponse);

      // Validate payment status before processing
      if (payment.status != ElectronicPaymentStatus.pending) {
        throw Exception('Payment is not in pending status. Current status: ${payment.status.name}');
      }

      // Get client wallet ID using the new helper function
      final clientWalletId = await getClientWalletId(payment.clientId);

      if (clientWalletId == null) {
        // Try to create wallet for client if it doesn't exist
        AppLogger.info('📝 Creating wallet for client: ${payment.clientId}');
        await _createClientWalletIfNeeded(payment.clientId);

        // Retry getting wallet ID
        final retryWalletId = await getClientWalletId(payment.clientId);
        if (retryWalletId == null) {
          throw Exception('Failed to create or find wallet for client: ${payment.clientId}');
        }

        return await _processDualWalletTransaction(
          paymentId: paymentId,
          clientWalletId: retryWalletId,
          payment: payment,
          approvedBy: approvedBy,
          adminNotes: adminNotes,
        );
      }

      // Get wallet details for validation
      final walletResponse = await _supabase
          .from('wallets')
          .select('id, balance, status, is_active')
          .eq('id', clientWalletId)
          .single();

      final walletId = walletResponse['id'] as String;
      final clientBalance = walletResponse['balance'] as double;
      final walletStatus = walletResponse['status'] as String;

      AppLogger.info('🔍 Payment approval details - paymentId: $paymentId, clientId: ${payment.clientId}, clientWalletId: $clientWalletId, amount: ${payment.amount}, clientBalance: $clientBalance, walletStatus: $walletStatus');

      // Validate wallet status
      if (walletStatus != 'active') {
        throw Exception('Client wallet is not active. Status: $walletStatus');
      }

      return await _processDualWalletTransaction(
        paymentId: paymentId,
        clientWalletId: clientWalletId,
        payment: payment,
        approvedBy: approvedBy,
        adminNotes: adminNotes,
      );

    } catch (e) {
      AppLogger.error('❌ Failed to process payment approval - paymentId: $paymentId, approvedBy: $approvedBy', e);

      // Provide user-friendly error messages in Arabic
      final String userFriendlyMessage = _getUserFriendlyErrorMessage(e.toString());
      throw Exception(userFriendlyMessage);
    }
  }

  /// Create client wallet if it doesn't exist with constraint violation handling
  Future<void> _createClientWalletIfNeeded(String clientId) async {
    try {
      AppLogger.info('📝 Creating/retrieving wallet for client: $clientId');

      // Enhanced check for existing wallets (handles multiple scenarios)
      final existingWallets = await _supabase
          .from('wallets')
          .select('id, wallet_type, is_active, status, balance')
          .eq('user_id', clientId);

      if (existingWallets.isNotEmpty) {
        AppLogger.info('📊 Found ${existingWallets.length} existing wallet(s) for client: $clientId');

        // Log details of existing wallets for debugging
        for (int i = 0; i < existingWallets.length; i++) {
          final wallet = existingWallets[i];
          AppLogger.info('  Wallet ${i + 1}: ID=${wallet['id']}, Type=${wallet['wallet_type']}, Active=${wallet['is_active']}, Status=${wallet['status']}');
        }

        // Check if we have at least one active wallet
        final activeWallets = existingWallets.where((w) =>
          (w['is_active'] == true || w['is_active'] == null) &&
          (w['status'] == 'active' || w['status'] == null)
        ).toList();

        if (activeWallets.isNotEmpty) {
          AppLogger.info('✅ Client has ${activeWallets.length} active wallet(s), no creation needed');
          return;
        } else {
          AppLogger.warning('⚠️ Client has ${existingWallets.length} wallet(s) but none are active');
        }
      }

      // Try to use the new get_or_create_client_wallet function
      try {
        final result = await _supabase.rpc(
          'get_or_create_client_wallet',
          params: {'p_user_id': clientId},
        );

        AppLogger.info('✅ Successfully created/retrieved wallet for client: $clientId, wallet ID: $result');
        return;
      } catch (rpcError) {
        AppLogger.warning('⚠️ RPC function not available, using fallback method: $rpcError');
      }

      // Fallback: Get client profile to determine role
      final profileResponse = await _supabase
          .from('user_profiles')
          .select('role')
          .eq('id', clientId)
          .single();

      final role = profileResponse['role'] as String? ?? 'client'; // Default to 'client' if null

      // Use upsert to handle constraint violations gracefully
      await _supabase.from('wallets').upsert({
        'user_id': clientId,
        'role': role,
        'wallet_type': 'personal',
        'balance': 0.0,
        'currency': 'EGP',
        'status': 'active',
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'metadata': {
          'type': 'client_personal_wallet',
          'description': 'محفظة العميل الشخصية',
          'created_by_service': true,
        }
      }, onConflict: 'user_id,wallet_type');

      AppLogger.info('✅ Successfully upserted wallet for client: $clientId');
    } catch (e) {
      AppLogger.error('❌ Failed to create wallet for client: $clientId', e);

      // Check if it's a constraint violation and provide specific error message
      if (e.toString().contains('duplicate key value violates unique constraint')) {
        AppLogger.info('ℹ️ Wallet already exists for client: $clientId, continuing...');
        return; // Wallet already exists, which is fine
      }

      throw Exception('فشل في إنشاء محفظة العميل: ${_getUserFriendlyErrorMessage(e.toString())}');
    }
  }

  /// Process the actual dual wallet transaction
  Future<ElectronicPaymentModel> _processDualWalletTransaction({
    required String paymentId,
    required String clientWalletId,
    required ElectronicPaymentModel payment,
    required String approvedBy,
    String? adminNotes,
  }) async {
    try {
      AppLogger.info('🔄 Starting dual wallet transaction - paymentId: $paymentId, clientWalletId: $clientWalletId, amount: ${payment.amount}, approvedBy: $approvedBy');

      // Validate parameters before calling function
      if (paymentId.isEmpty || clientWalletId.isEmpty || payment.amount <= 0 || approvedBy.isEmpty) {
        throw Exception('Invalid parameters for dual wallet transaction');
      }

      // Validate approver role before processing
      await _validateApproverRole(approvedBy);

      // Ensure client wallet exists and has proper role before transaction
      try {
        await _createClientWalletIfNeeded(payment.clientId);
      } catch (walletError) {
        AppLogger.warning('⚠️ Wallet creation/validation failed, continuing with transaction: $walletError');
      }

      // Process the dual wallet transaction with timeout
      final result = await _supabase.rpc(
        'process_dual_wallet_transaction',
        params: {
          'p_payment_id': paymentId,
          'p_client_wallet_id': clientWalletId,
          'p_amount': payment.amount,
          'p_approved_by': approvedBy,
          'p_admin_notes': adminNotes ?? 'تم اعتماد الدفعة',
          'p_business_wallet_id': null, // Let function create/find business wallet
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('انتهت مهلة معالجة الدفعة. يرجى المحاولة مرة أخرى.'),
      );

      AppLogger.info('✅ Dual wallet transaction completed successfully: $result');

      // Fetch the updated payment
      final updatedPaymentResponse = await _paymentsTable
          .select()
          .eq('id', paymentId)
          .single();

      final updatedPayment = ElectronicPaymentModel.fromDatabase(updatedPaymentResponse);

      // Automatically update electronic wallet balance after successful payment approval
      if (updatedPayment.status == ElectronicPaymentStatus.approved) {
        await _updateElectronicWalletBalance(updatedPayment, approvedBy);
      }

      AppLogger.info('🎉 Payment approved successfully - paymentId: $paymentId, clientId: ${payment.clientId}, amount: ${payment.amount}, approvedBy: $approvedBy, newStatus: ${updatedPayment.status.name}');

      return updatedPayment;

    } catch (e) {
      AppLogger.error('❌ Dual wallet transaction failed - paymentId: $paymentId, error: $e');

      // Log additional context for constraint violations
      if (e.toString().contains('wallet_transactions_reference_type_valid')) {
        AppLogger.error('🚨 Database constraint violation detected - this indicates the database constraint needs to be updated to include electronic_payment as a valid reference_type');
      } else if (e.toString().contains('null value in column "role"')) {
        AppLogger.error('🚨 Role constraint violation detected - wallet creation is missing role assignment');
        AppLogger.error('💡 This indicates the database functions need to be updated to properly assign role values');
      }

      throw Exception('فشل في معالجة الدفعة: ${_getUserFriendlyErrorMessage(e.toString())}');
    }
  }

  /// Automatically update electronic wallet balance after payment approval
  Future<void> _updateElectronicWalletBalance(ElectronicPaymentModel payment, String approvedBy) async {
    try {
      AppLogger.info('🔄 Updating electronic wallet balance for payment: ${payment.id}, account: ${payment.paymentAccountId}, amount: ${payment.amount}');

      // Import the electronic wallet service
      final electronicWalletService = ElectronicWalletService();

      // Find the electronic wallet that matches the payment account
      final wallets = await electronicWalletService.getAllWallets();

      // Find wallet by matching phone number with payment account
      ElectronicWalletModel? targetWallet;

      // Get payment account details to match with wallet
      final accountResponse = await _supabase
          .from('payment_accounts')
          .select('account_number, account_type')
          .eq('id', payment.paymentAccountId)
          .single();

      final accountNumber = accountResponse['account_number'] as String;
      final accountType = accountResponse['account_type'] as String;

      // Find matching electronic wallet
      for (final wallet in wallets) {
        if (wallet.phoneNumber == accountNumber &&
            ((accountType == 'vodafone_cash' && wallet.walletType == ElectronicWalletType.vodafoneCash) ||
             (accountType == 'instapay' && wallet.walletType == ElectronicWalletType.instaPay))) {
          targetWallet = wallet;
          break;
        }
      }

      if (targetWallet == null) {
        AppLogger.warning('⚠️ No matching electronic wallet found for payment account: $accountNumber ($accountType)');
        return;
      }

      // Update the electronic wallet balance
      final transactionId = await electronicWalletService.updateWalletBalance(
        walletId: targetWallet.id,
        amount: payment.amount,
        transactionType: ElectronicWalletTransactionType.payment,
        description: 'دفعة إلكترونية مُعتمدة - ${payment.description ?? 'دفعة من عميل'}',
        referenceId: payment.id,
        paymentId: payment.id,
        processedBy: approvedBy,
      );

      if (transactionId != null) {
        AppLogger.info('✅ Electronic wallet balance updated successfully: ${targetWallet.id}, transaction: $transactionId');
      } else {
        AppLogger.error('❌ Failed to update electronic wallet balance for wallet: ${targetWallet.id}');
      }

    } catch (e) {
      AppLogger.error('❌ Error updating electronic wallet balance: $e');
      // Don't throw error to avoid breaking the payment approval process
      // The payment is already approved, wallet balance update is supplementary
    }
  }

  /// Validate that the approver has the necessary role to approve payments
  Future<void> _validateApproverRole(String approvedBy) async {
    try {
      AppLogger.info('🔍 Validating approver role for: $approvedBy');

      // Enhanced query with better error handling for PGRST116
      final profileResponse = await _supabase
          .from('user_profiles')
          .select('role, status, name, email')
          .eq('id', approvedBy)
          .maybeSingle(); // Use maybeSingle() instead of single() to handle 0 rows

      // Handle case where no user profile is found
      if (profileResponse == null) {
        AppLogger.error('❌ No user profile found for approver: $approvedBy');
        throw Exception('Approver profile not found: $approvedBy');
      }

      final role = profileResponse['role'] as String?;
      final status = profileResponse['status'] as String?;
      final name = profileResponse['name'] as String?;
      final email = profileResponse['email'] as String?;

      AppLogger.info('👤 Approver details: $name ($email) - Role: $role, Status: $status');

      if (role == null || role.isEmpty) {
        AppLogger.error('❌ Approver has no role assigned: $approvedBy');
        throw Exception('Approver has no role assigned: $approvedBy');
      }

      // Enhanced status validation - Accept both 'active' and 'approved' status values
      // The system uses both 'active' and 'approved' for valid/activated users
      final validStatuses = ['active', 'approved'];
      if (status == null || !validStatuses.contains(status)) {
        AppLogger.error('❌ Approver account is not active: $approvedBy (status: $status)');
        throw Exception('Approver account is not active: $approvedBy (status: $status)');
      }

      // Enhanced role validation
      final allowedRoles = ['admin', 'owner', 'accountant'];
      if (!allowedRoles.contains(role)) {
        AppLogger.error('❌ Approver does not have permission: $approvedBy (role: $role)');
        throw Exception('Approver does not have permission to approve payments: $approvedBy (role: $role)');
      }

      AppLogger.info('✅ Approver validation successful: $approvedBy (role: $role, status: $status)');
    } catch (e) {
      AppLogger.error('❌ Approver validation failed: $e');

      // Enhanced error handling for specific PostgreSQL errors
      if (e.toString().contains('PGRST116')) {
        AppLogger.error('🚨 PGRST116 Error: Multiple or no rows returned for approver: $approvedBy');
        AppLogger.error('💡 This indicates duplicate user profiles or missing profile data');
        throw Exception('خطأ في بيانات المعتمد: يوجد تضارب في بيانات المستخدم أو بيانات مفقودة');
      } else if (e.toString().contains('JSON object requested')) {
        AppLogger.error('🚨 Database query returned unexpected result format');
        throw Exception('خطأ في قاعدة البيانات: تنسيق البيانات غير متوقع');
      }

      throw Exception('فشل في التحقق من صلاحيات المعتمد: ${_getUserFriendlyErrorMessage(e.toString())}');
    }
  }

  /// Get user-friendly error message in Arabic
  String _getUserFriendlyErrorMessage(String error) {
    if (error.contains('duplicate key value violates unique constraint')) {
      if (error.contains('wallets_user_id_key')) {
        return 'المحفظة موجودة بالفعل لهذا المستخدم.';
      }
      return 'البيانات موجودة بالفعل في النظام.';
    } else if (error.contains('null value in column "role"')) {
      return 'خطأ في إعداد الأدوار. يرجى الاتصال بالدعم الفني لإصلاح قاعدة البيانات.';
    } else if (error.contains('null value in column "user_id"')) {
      return 'خطأ في إعداد النظام. يرجى الاتصال بالدعم الفني.';
    } else if (error.contains('violates not-null constraint')) {
      if (error.contains('role')) {
        return 'خطأ في تعيين الأدوار. يرجى الاتصال بالدعم الفني.';
      }
      return 'خطأ في قاعدة البيانات. يرجى المحاولة مرة أخرى.';
    } else if (error.contains('violates check constraint') && error.contains('wallet_transactions_reference_type_valid')) {
      return 'خطأ في قاعدة البيانات: نوع المرجع غير صالح. يرجى الاتصال بالدعم الفني لتحديث قاعدة البيانات.';
    } else if (error.contains('check constraint') && error.contains('reference_type')) {
      return 'خطأ في نوع المرجع للمعاملة. يرجى الاتصال بالدعم الفني.';
    } else if (error.contains('Approver has no role assigned')) {
      return 'المعتمد ليس له دور محدد في النظام. يرجى الاتصال بالدعم الفني.';
    } else if (error.contains('Approver account is not active')) {
      return 'حساب المعتمد غير مفعل. يرجى التأكد من تفعيل الحساب أو الموافقة عليه.';
    } else if (error.contains('does not have permission to approve')) {
      return 'المعتمد ليس له صلاحية اعتماد المدفوعات. يرجى استخدام حساب مدير أو محاسب.';
    } else if (error.contains('Payment not found')) {
      return 'الدفعة غير موجودة أو تم حذفها.';
    } else if (error.contains('not in pending status')) {
      return 'لا يمكن معالجة هذه الدفعة. الحالة الحالية غير صالحة.';
    } else if (error.contains('Wallet not found')) {
      return 'محفظة العميل غير موجودة. يرجى الاتصال بالدعم الفني.';
    } else if (error.contains('Insufficient balance')) {
      return 'رصيد غير كافي في محفظة العميل.';
    } else if (error.contains('Insufficient business wallet balance')) {
      return 'رصيد غير كافي في محفظة الشركة.';
    } else if (error.contains('timeout')) {
      return 'انتهت مهلة المعالجة. يرجى المحاولة مرة أخرى.';
    } else if (error.contains('Failed to get/create business wallet')) {
      return 'خطأ في إنشاء محفظة الشركة. يرجى الاتصال بالدعم الفني.';
    } else {
      return 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى أو الاتصال بالدعم الفني.';
    }
  }

  /// Update payment proof image
  Future<ElectronicPaymentModel> updatePaymentProof({
    required String paymentId,
    required String proofImageUrl,
  }) async {
    try {
      AppLogger.info('🔄 Updating payment proof: $paymentId');

      final response = await _paymentsTable
          .update({
            'proof_image_url': proofImageUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', paymentId)
          .select()
          .single();

      final payment = ElectronicPaymentModel.fromDatabase(response);
      AppLogger.info('✅ Updated payment proof: ${payment.id}');
      return payment;
    } catch (e) {
      AppLogger.error('❌ Error updating payment proof: $e');
      throw Exception('Failed to update payment proof: $e');
    }
  }

  /// Get client wallet balance for validation
  Future<double> getClientWalletBalance(String clientId) async {
    try {
      AppLogger.info('🔄 Getting client wallet balance for: $clientId');

      // Enhanced query to handle multiple wallet scenarios
      final response = await _supabase
          .from('wallets')
          .select('id, balance, wallet_type, status, is_active, created_at, role')
          .eq('user_id', clientId)
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        AppLogger.warning('⚠️ No wallets found for client: $clientId');
        return 0.0;
      }

      // Log all found wallets for debugging
      AppLogger.info('📊 Found ${response.length} wallet(s) for client: $clientId');
      for (int i = 0; i < response.length; i++) {
        final wallet = response[i];
        AppLogger.info('  Wallet ${i + 1}: ID=${wallet['id']}, Type=${wallet['wallet_type']}, Active=${wallet['is_active']}, Balance=${wallet['balance']}, Status=${wallet['status']}');
      }

      // Filter and prioritize wallets
      List<Map<String, dynamic>> activeWallets = response
          .where((wallet) =>
              (wallet['is_active'] == true || wallet['is_active'] == null) &&
              (wallet['status'] == 'active' || wallet['status'] == null))
          .toList();

      if (activeWallets.isEmpty) {
        AppLogger.warning('⚠️ No active wallets found for client: $clientId');
        return 0.0;
      }

      // Prioritize wallet selection:
      // 1. Personal wallet type (if exists)
      // 2. Most recent wallet
      // 3. Wallet with highest balance
      Map<String, dynamic>? selectedWallet;

      // Try to find personal wallet first
      for (var wallet in activeWallets) {
        if (wallet['wallet_type'] == 'personal') {
          selectedWallet = wallet;
          break;
        }
      }

      // If no personal wallet, select the most recent active wallet
      if (selectedWallet == null) {
        selectedWallet = activeWallets.first; // Already ordered by created_at desc
      }

      final balance = (selectedWallet['balance'] as num).toDouble();
      final walletType = selectedWallet['wallet_type'] ?? 'unknown';
      final walletId = selectedWallet['id'] as String;

      AppLogger.info('✅ Selected wallet for client $clientId: ID=$walletId, Type=$walletType, Balance=$balance EGP');

      // Log warning if multiple active wallets found
      if (activeWallets.length > 1) {
        AppLogger.warning('⚠️ Multiple active wallets found for client $clientId (${activeWallets.length} wallets). Using wallet: $walletId');
      }

      return balance;
    } catch (e) {
      AppLogger.error('❌ Error getting client wallet balance: $e');

      // Enhanced error logging for PGRST116 errors
      if (e.toString().contains('PGRST116')) {
        AppLogger.error('🚨 PGRST116 Error detected - Multiple wallet records found for client: $clientId');
        AppLogger.error('💡 This indicates duplicate wallet records in the database that need cleanup');
      }

      throw Exception('Failed to get client wallet balance: $e');
    }
  }

  /// Get client wallet ID for transactions (handles multiple wallets)
  Future<String?> getClientWalletId(String clientId) async {
    try {
      AppLogger.info('🔄 Getting client wallet ID for: $clientId');

      // Enhanced query to handle multiple wallet scenarios
      final response = await _supabase
          .from('wallets')
          .select('id, wallet_type, status, is_active, created_at, role')
          .eq('user_id', clientId)
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        AppLogger.warning('⚠️ No wallets found for client: $clientId');
        return null;
      }

      // Log all found wallets for debugging
      AppLogger.info('📊 Found ${response.length} wallet(s) for client: $clientId');

      // Filter and prioritize wallets
      List<Map<String, dynamic>> activeWallets = response
          .where((wallet) =>
              (wallet['is_active'] == true || wallet['is_active'] == null) &&
              (wallet['status'] == 'active' || wallet['status'] == null))
          .toList();

      if (activeWallets.isEmpty) {
        AppLogger.warning('⚠️ No active wallets found for client: $clientId');
        return null;
      }

      // Prioritize wallet selection: Personal wallet first, then most recent
      Map<String, dynamic>? selectedWallet;

      // Try to find personal wallet first
      for (var wallet in activeWallets) {
        if (wallet['wallet_type'] == 'personal') {
          selectedWallet = wallet;
          break;
        }
      }

      // If no personal wallet, select the most recent active wallet
      if (selectedWallet == null) {
        selectedWallet = activeWallets.first; // Already ordered by created_at desc
      }

      final walletId = selectedWallet['id'] as String;
      final walletType = selectedWallet['wallet_type'] ?? 'unknown';

      AppLogger.info('✅ Selected wallet ID for client $clientId: $walletId (Type: $walletType)');

      // Log warning if multiple active wallets found
      if (activeWallets.length > 1) {
        AppLogger.warning('⚠️ Multiple active wallets found for client $clientId (${activeWallets.length} wallets). Using wallet: $walletId');
      }

      return walletId;
    } catch (e) {
      AppLogger.error('❌ Error getting client wallet ID: $e');

      // Enhanced error logging for PGRST116 errors
      if (e.toString().contains('PGRST116')) {
        AppLogger.error('🚨 PGRST116 Error detected - Multiple wallet records found for client: $clientId');
      }

      return null;
    }
  }

  /// Validate client wallet balance before payment approval
  Future<Map<String, dynamic>> validateClientWalletBalance(String clientId, double paymentAmount) async {
    try {
      AppLogger.info('🔄 Validating client wallet balance: $clientId, amount: $paymentAmount');

      final balance = await getClientWalletBalance(clientId);
      final isValid = balance >= paymentAmount;

      final result = {
        'isValid': isValid,
        'currentBalance': balance,
        'requiredAmount': paymentAmount,
        'remainingBalance': balance - paymentAmount,
        'message': isValid
            ? 'رصيد العميل كافي لإتمام العملية'
            : 'رصيد العميل غير كافي لإتمام العملية. الرصيد الحالي: ${balance.toStringAsFixed(2)} ج.م، المطلوب: ${paymentAmount.toStringAsFixed(2)} ج.م'
      };

      AppLogger.info('✅ Balance validation result: $result');
      return result;
    } catch (e) {
      AppLogger.error('❌ Error validating client wallet balance: $e');
      throw Exception('Failed to validate client wallet balance: $e');
    }
  }

  /// Sync all electronic wallets with payment accounts
  Future<int> syncAllElectronicWalletsWithPaymentAccounts() async {
    try {
      AppLogger.info('🔄 Syncing all electronic wallets with payment accounts');

      final response = await _supabase.rpc('sync_all_electronic_wallets_with_payment_accounts');
      final syncedCount = response as int;

      AppLogger.info('✅ Synced $syncedCount electronic wallets with payment accounts');
      return syncedCount;
    } catch (e) {
      AppLogger.error('❌ Error syncing electronic wallets with payment accounts: $e');
      throw Exception('Failed to sync wallets with payment accounts: $e');
    }
  }

  /// Get payment statistics
  Future<Map<String, dynamic>> getPaymentStatistics() async {
    try {
      AppLogger.info('🔄 Fetching payment statistics');

      // First check if table exists
      try {
        await _paymentsTable.select('id').limit(1);
      } catch (e) {
        if (e.toString().contains('42P01') || e.toString().contains('does not exist')) {
          throw Exception('Electronic payments table does not exist. Please run the database migration script.');
        }
        rethrow;
      }

      // Get total counts by status
      final pendingResponse = await _paymentsTable
          .select('id')
          .eq('status', 'pending');
      final pendingCount = (pendingResponse as List).length;

      final approvedResponse = await _paymentsTable
          .select('id')
          .eq('status', 'approved');
      final approvedCount = (approvedResponse as List).length;

      final rejectedResponse = await _paymentsTable
          .select('id')
          .eq('status', 'rejected');
      final rejectedCount = (rejectedResponse as List).length;

      // Get total amounts
      final totalAmountResponse = await _paymentsTable
          .select('amount')
          .eq('status', 'approved');

      double totalApprovedAmount = 0.0;
      totalApprovedAmount = totalAmountResponse
          .map((item) => (item['amount'] as num).toDouble())
          .fold(0.0, (sum, amount) => sum + amount);
    
      final statistics = {
        'pending_count': pendingCount,
        'approved_count': approvedCount,
        'rejected_count': rejectedCount,
        'total_approved_amount': totalApprovedAmount,
      };

      AppLogger.info('✅ Fetched payment statistics');
      return statistics;
    } catch (e) {
      AppLogger.error('❌ Error fetching payment statistics: $e');

      // Provide more specific error messages
      if (e.toString().contains('42P01')) {
        throw Exception('Database table "electronic_payments" does not exist. Please run the migration script.');
      } else if (e.toString().contains('permission denied')) {
        throw Exception('Permission denied. Please check your user role and RLS policies.');
      }

      throw Exception('Failed to fetch payment statistics: $e');
    }
  }

  /// Admin functions for managing payment accounts

  /// Create a new payment account (admin only)
  Future<PaymentAccountModel> createPaymentAccount({
    required String accountType,
    required String accountNumber,
    required String accountHolderName,
    bool isActive = true,
  }) async {
    try {
      AppLogger.info('🔄 Creating payment account: $accountType - $accountNumber');

      final accountData = {
        'account_type': accountType,
        'account_number': accountNumber,
        'account_holder_name': accountHolderName,
        'is_active': isActive,
      };

      final response = await _accountsTable
          .insert(accountData)
          .select()
          .single();

      final account = PaymentAccountModel.fromDatabase(response);
      AppLogger.info('✅ Created payment account: ${account.id}');
      return account;
    } catch (e) {
      AppLogger.error('❌ Error creating payment account: $e');
      throw Exception('Failed to create payment account: $e');
    }
  }

  /// Update payment account (admin only)
  Future<PaymentAccountModel> updatePaymentAccount({
    required String accountId,
    String? accountNumber,
    String? accountHolderName,
    bool? isActive,
  }) async {
    try {
      AppLogger.info('🔄 Updating payment account: $accountId');

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (accountNumber != null) updateData['account_number'] = accountNumber;
      if (accountHolderName != null) updateData['account_holder_name'] = accountHolderName;
      if (isActive != null) updateData['is_active'] = isActive;

      final response = await _accountsTable
          .update(updateData)
          .eq('id', accountId)
          .select()
          .single();

      final account = PaymentAccountModel.fromDatabase(response);
      AppLogger.info('✅ Updated payment account: ${account.id}');
      return account;
    } catch (e) {
      AppLogger.error('❌ Error updating payment account: $e');
      throw Exception('Failed to update payment account: $e');
    }
  }

  /// Get all payment accounts (admin only)
  Future<List<PaymentAccountModel>> getAllPaymentAccounts() async {
    try {
      AppLogger.info('🔄 Fetching all payment accounts');

      final response = await _accountsTable
          .select()
          .order('account_type')
          .order('account_holder_name');

      final accounts = (response as List)
          .map((json) => PaymentAccountModel.fromDatabase(json))
          .toList();

      AppLogger.info('✅ Fetched ${accounts.length} payment accounts');
      return accounts;
    } catch (e) {
      AppLogger.error('❌ Error fetching all payment accounts: $e');
      throw Exception('Failed to fetch payment accounts: $e');
    }
  }

  /// Delete payment account (admin only)
  Future<void> deletePaymentAccount(String accountId) async {
    try {
      AppLogger.info('🔄 Deleting payment account: $accountId');

      await _accountsTable
          .delete()
          .eq('id', accountId);

      AppLogger.info('✅ Deleted payment account: $accountId');
    } catch (e) {
      AppLogger.error('❌ Error deleting payment account: $e');
      throw Exception('Failed to delete payment account: $e');
    }
  }

  /// Helper method to convert payment method enum to string
  static String _paymentMethodToString(ElectronicPaymentMethod method) {
    switch (method) {
      case ElectronicPaymentMethod.vodafoneCash:
        return 'vodafone_cash';
      case ElectronicPaymentMethod.instaPay:
        return 'instapay';
    }
  }

  /// Helper method to convert status enum to string
  static String _statusToString(ElectronicPaymentStatus status) {
    switch (status) {
      case ElectronicPaymentStatus.pending:
        return 'pending';
      case ElectronicPaymentStatus.approved:
        return 'approved';
      case ElectronicPaymentStatus.rejected:
        return 'rejected';
    }
  }

  /// Helper method to enrich payments with related data (fetched separately)
  Future<void> _enrichPaymentsWithRelatedData(List<ElectronicPaymentModel> payments) async {
    try {
      if (payments.isEmpty) return;

      AppLogger.info('🔄 Enriching ${payments.length} payments with related data...');

      // Fetch payment accounts data
      Map<String, Map<String, dynamic>> accountsMap = {};
      try {
        final accountsResponse = await _accountsTable.select('id, account_number, account_holder_name');

        for (final account in accountsResponse as List) {
          accountsMap[account['id']] = account;
        }

        AppLogger.info('✅ Fetched ${accountsMap.length} payment accounts for enrichment');
      } catch (e) {
        AppLogger.info('⚠️ Could not fetch payment accounts for enrichment: $e');
      }

      // Fetch user profiles data
      Map<String, Map<String, dynamic>> profilesMap = {};
      try {
        // Get all unique client IDs from payments
        final clientIds = payments.map((p) => p.clientId).toSet().toList();

        if (clientIds.isNotEmpty) {
          final userProfilesResponse = await _supabase
              .from('user_profiles')
              .select('id, name, email, phone_number')
              .inFilter('id', clientIds);

          for (final profile in userProfilesResponse as List) {
            profilesMap[profile['id']] = profile;
          }

          AppLogger.info('✅ Fetched ${profilesMap.length} user profiles for enrichment');
        }
      } catch (e) {
        if (e.toString().contains('42P01') || e.toString().contains('does not exist')) {
          AppLogger.info('ℹ️ user_profiles table does not exist, skipping user data enrichment');
        } else {
          AppLogger.info('⚠️ Could not access user_profiles for enrichment: $e');
        }
      }

      // Apply enriched data to payments
      for (int i = 0; i < payments.length; i++) {
        final payment = payments[i];

        // Get client name from user profiles
        final clientProfile = profilesMap[payment.clientId];
        final clientName = clientProfile?['name'] as String?;
        final clientEmail = clientProfile?['email'] as String?;
        final clientPhone = clientProfile?['phone_number'] as String?;

        // Get recipient account info
        final recipientAccount = accountsMap[payment.recipientAccountId];
        final recipientAccountNumber = recipientAccount?['account_number'] as String?;
        final recipientAccountHolderName = recipientAccount?['account_holder_name'] as String?;

        // Create enriched payment model
        payments[i] = payment.copyWith(
          clientName: clientName ?? 'عميل غير معروف',
          clientEmail: clientEmail,
          clientPhone: clientPhone,
          recipientAccountNumber: recipientAccountNumber ?? 'غير محدد',
          recipientAccountHolderName: recipientAccountHolderName ?? 'غير محدد',
        );
      }

      AppLogger.info('✅ Payment enrichment process completed - enriched ${payments.length} payments');
    } catch (e) {
      AppLogger.error('❌ Error during payment enrichment: $e');
      // Don't throw error as this is enrichment, not critical functionality
    }
  }
}
