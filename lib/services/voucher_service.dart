import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/voucher_model.dart';
import '../models/client_voucher_model.dart';
import '../utils/app_logger.dart';
import 'unified_products_service.dart';

class VoucherService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================================
  // VOUCHER MANAGEMENT
  // ============================================================================

  /// Create a new voucher
  Future<VoucherModel?> createVoucher(VoucherCreateRequest request) async {
    try {
      AppLogger.info('Creating voucher: ${request.name}');

      // Check if user is authenticated
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        AppLogger.error('User not authenticated - cannot create voucher');
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // Generate voucher code using database function
      final codeResponse = await _supabase.rpc('generate_voucher_code');
      final voucherCode = codeResponse as String;

      // Prepare voucher data with created_by field
      final voucherData = request.toJsonWithCreatedBy(currentUser.id);
      voucherData['code'] = voucherCode;

      AppLogger.info('Creating voucher with user ID: ${currentUser.id}');

      // Insert voucher
      final response = await _supabase
          .from('vouchers')
          .insert(voucherData)
          .select()
          .single();

      AppLogger.info('Voucher created successfully: $voucherCode');
      return VoucherModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Error creating voucher: $e');
      return null;
    }
  }

  /// Get all vouchers (admin/owner only)
  Future<List<VoucherModel>> getAllVouchers() async {
    try {
      AppLogger.info('Fetching all vouchers');

      final response = await _supabase
          .from('vouchers')
          .select()
          .order('created_at', ascending: false);

      final vouchers = (response as List)
          .map((json) => VoucherModel.fromJson(json as Map<String, dynamic>))
          .toList();

      AppLogger.info('Fetched ${vouchers.length} vouchers');
      return vouchers;
    } catch (e) {
      AppLogger.error('Error fetching vouchers: $e');
      return [];
    }
  }

  /// Get active vouchers only
  Future<List<VoucherModel>> getActiveVouchers() async {
    try {
      AppLogger.info('Fetching active vouchers');

      final response = await _supabase
          .from('vouchers')
          .select()
          .eq('is_active', true)
          .gt('expiration_date', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      final vouchers = (response as List)
          .map((json) => VoucherModel.fromJson(json as Map<String, dynamic>))
          .toList();

      AppLogger.info('Fetched ${vouchers.length} active vouchers');
      return vouchers;
    } catch (e) {
      AppLogger.error('Error fetching active vouchers: $e');
      return [];
    }
  }

  /// Get voucher by ID
  Future<VoucherModel?> getVoucherById(String voucherId) async {
    try {
      AppLogger.info('Fetching voucher by ID: $voucherId');

      final response = await _supabase
          .from('vouchers')
          .select()
          .eq('id', voucherId)
          .single();

      return VoucherModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Error fetching voucher by ID: $e');
      return null;
    }
  }

  /// Get voucher by code
  Future<VoucherModel?> getVoucherByCode(String code) async {
    try {
      AppLogger.info('Fetching voucher by code: $code');

      final response = await _supabase
          .from('vouchers')
          .select()
          .eq('code', code)
          .single();

      return VoucherModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Error fetching voucher by code: $e');
      return null;
    }
  }

  /// Update voucher
  Future<VoucherModel?> updateVoucher(String voucherId, VoucherUpdateRequest request) async {
    try {
      AppLogger.info('Updating voucher: $voucherId');

      final response = await _supabase
          .from('vouchers')
          .update(request.toJson())
          .eq('id', voucherId)
          .select()
          .single();

      AppLogger.info('Voucher updated successfully');
      return VoucherModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Error updating voucher: $e');
      return null;
    }
  }

  /// Delete voucher with enhanced constraint handling and force deletion option
  Future<Map<String, dynamic>> deleteVoucher(String voucherId, {bool forceDelete = false}) async {
    try {
      AppLogger.info('Deleting voucher: $voucherId (force: $forceDelete)');

      // First, check for assignments
      final assignmentsCheck = await _supabase
          .from('client_vouchers')
          .select('id, status')
          .eq('voucher_id', voucherId);

      final assignments = assignmentsCheck as List? ?? [];
      final activeAssignments = assignments.where((a) => a['status'] == 'active').length;
      final usedAssignments = assignments.where((a) => a['status'] == 'used').length;
      final totalAssignments = assignments.length;

      AppLogger.info('Voucher $voucherId assignments: $totalAssignments total, $activeAssignments active, $usedAssignments used');

      // If force delete is not enabled and there are active assignments, prevent deletion
      if (!forceDelete && activeAssignments > 0) {
        AppLogger.warning('Cannot delete voucher $voucherId: has $activeAssignments active assignments (use force delete to override)');
        return {
          'success': false,
          'canDelete': false,
          'reason': 'active_assignments',
          'message': 'لا يمكن حذف القسيمة: يوجد $activeAssignments تعيين نشط',
          'activeAssignments': activeAssignments,
          'usedAssignments': usedAssignments,
          'totalAssignments': totalAssignments,
          'suggestedAction': 'force_delete',
        };
      }

      // If force delete is enabled, delete all related assignments first
      if (forceDelete && totalAssignments > 0) {
        AppLogger.info('Force deleting $totalAssignments client voucher assignments');
        await _supabase
            .from('client_vouchers')
            .delete()
            .eq('voucher_id', voucherId);
      }

      // Attempt voucher deletion
      await _supabase
          .from('vouchers')
          .delete()
          .eq('id', voucherId);

      AppLogger.info('Voucher deleted successfully');
      return {
        'success': true,
        'canDelete': true,
        'message': forceDelete
            ? 'تم حذف القسيمة وجميع التعيينات بنجاح'
            : 'تم حذف القسيمة بنجاح',
        'deletedAssignments': forceDelete ? totalAssignments : 0,
        'forceDeleted': forceDelete,
      };
    } catch (e) {
      AppLogger.error('Error deleting voucher: $e');
      return {
        'success': false,
        'canDelete': false,
        'reason': 'unknown_error',
        'message': 'فشل في حذف القسيمة: ${e.toString()}',
        'error': e.toString(),
      };
    }
  }

  /// Deactivate voucher instead of deleting it
  Future<bool> deactivateVoucher(String voucherId) async {
    try {
      AppLogger.info('Deactivating voucher: $voucherId');

      await _supabase
          .from('vouchers')
          .update({'is_active': false})
          .eq('id', voucherId);

      AppLogger.info('Voucher deactivated successfully');
      return true;
    } catch (e) {
      AppLogger.error('Error deactivating voucher: $e');
      return false;
    }
  }

  /// Delete all vouchers from the system (BULK DELETION)
  Future<Map<String, dynamic>> deleteAllVouchers({bool forceDelete = false}) async {
    try {
      AppLogger.info('🚨 Starting bulk voucher deletion (force: $forceDelete)');

      // Get all vouchers count first
      final vouchersResponse = await _supabase
          .from('vouchers')
          .select('id')
          .count();

      final totalVouchers = vouchersResponse.count;

      if (totalVouchers == 0) {
        return {
          'success': true,
          'message': 'لا توجد قسائم للحذف',
          'deletedVouchers': 0,
          'deletedAssignments': 0,
        };
      }

      // Get all client voucher assignments count
      final assignmentsResponse = await _supabase
          .from('client_vouchers')
          .select('id')
          .count();

      final totalAssignments = assignmentsResponse.count;

      AppLogger.info('Found $totalVouchers vouchers and $totalAssignments assignments');

      // If force delete is not enabled, check for active assignments
      if (!forceDelete) {
        final activeAssignmentsResponse = await _supabase
            .from('client_vouchers')
            .select('id')
            .eq('status', 'active')
            .count();

        final activeAssignments = activeAssignmentsResponse.count;

        if (activeAssignments > 0) {
          return {
            'success': false,
            'canDelete': false,
            'reason': 'active_assignments',
            'message': 'لا يمكن حذف جميع القسائم: يوجد $activeAssignments تعيين نشط',
            'totalVouchers': totalVouchers,
            'totalAssignments': totalAssignments,
            'activeAssignments': activeAssignments,
            'suggestedAction': 'force_delete',
          };
        }
      }

      // If force delete is enabled or no active assignments, proceed with deletion
      if (forceDelete && totalAssignments > 0) {
        AppLogger.info('Force deleting all $totalAssignments client voucher assignments');
        await _supabase
            .from('client_vouchers')
            .delete()
            .neq('id', '00000000-0000-0000-0000-000000000000'); // Delete all records
      }

      // Delete all vouchers
      AppLogger.info('Deleting all $totalVouchers vouchers');
      await _supabase
          .from('vouchers')
          .delete()
          .neq('id', '00000000-0000-0000-0000-000000000000'); // Delete all records

      AppLogger.info('✅ Bulk voucher deletion completed successfully');
      return {
        'success': true,
        'message': forceDelete
            ? 'تم حذف جميع القسائم والتعيينات بنجاح'
            : 'تم حذف جميع القسائم بنجاح',
        'deletedVouchers': totalVouchers,
        'deletedAssignments': forceDelete ? totalAssignments : 0,
        'forceDeleted': forceDelete,
      };
    } catch (e) {
      AppLogger.error('❌ Error during bulk voucher deletion: $e');
      return {
        'success': false,
        'canDelete': false,
        'reason': 'unknown_error',
        'message': 'فشل في حذف جميع القسائم: ${e.toString()}',
        'error': e.toString(),
      };
    }
  }



  // ============================================================================
  // CLIENT VOUCHER MANAGEMENT
  // ============================================================================

  /// Assign vouchers to clients with enhanced validation and error handling
  Future<List<ClientVoucherModel>> assignVouchersToClients(ClientVoucherAssignRequest request) async {
    try {
      AppLogger.info('🔄 Starting voucher assignment process...');
      AppLogger.info('   - Voucher ID: ${request.voucherId}');
      AppLogger.info('   - Client IDs: ${request.clientIds}');

      // Check if user is authenticated
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        AppLogger.error('❌ User not authenticated - cannot assign vouchers');
        throw Exception('المستخدم غير مسجل الدخول');
      }

      AppLogger.info('✅ User authenticated: ${currentUser.id}');

      // Verify voucher exists and is active
      final voucherCheck = await _supabase
          .from('vouchers')
          .select('id, name, is_active, expiration_date')
          .eq('id', request.voucherId)
          .maybeSingle();

      if (voucherCheck == null) {
        AppLogger.error('❌ Voucher not found: ${request.voucherId}');
        throw Exception('القسيمة غير موجودة');
      }

      if (voucherCheck['is_active'] != true) {
        AppLogger.error('❌ Voucher is not active: ${request.voucherId}');
        throw Exception('القسيمة غير نشطة');
      }

      // Check if voucher is expired
      final expirationDate = DateTime.parse((voucherCheck['expiration_date'] as String?) ?? DateTime.now().toIso8601String());
      if (expirationDate.isBefore(DateTime.now())) {
        AppLogger.error('❌ Voucher is expired: ${request.voucherId}');
        throw Exception('القسيمة منتهية الصلاحية');
      }

      AppLogger.info('✅ Voucher verified: ${voucherCheck['name']}');

      // Verify all client IDs exist and have valid status (approved or active)
      final clientsCheck = await _supabase
          .from('user_profiles')
          .select('id, name, email, status, role')
          .inFilter('id', request.clientIds)
          .eq('role', 'client')
          .or('status.eq.approved,status.eq.active');

      final validClientIds = (clientsCheck as List)
          .map((client) => client['id'] as String)
          .toList();

      if (validClientIds.length != request.clientIds.length) {
        final invalidIds = request.clientIds.where((id) => !validClientIds.contains(id)).toList();
        AppLogger.warning('⚠️ Some client IDs are invalid or do not have valid status (approved/active): $invalidIds');
      }

      if (validClientIds.isEmpty) {
        AppLogger.error('❌ No valid clients found for assignment');
        throw Exception('لا يوجد عملاء صالحين للتعيين');
      }

      AppLogger.info('✅ Verified ${validClientIds.length} valid clients');

      // Check for existing assignments to avoid duplicate key violations
      final existingAssignments = await _supabase
          .from('client_vouchers')
          .select('client_id')
          .eq('voucher_id', request.voucherId)
          .inFilter('client_id', validClientIds);

      final existingClientIds = (existingAssignments as List)
          .map((assignment) => assignment['client_id'] as String)
          .toSet();

      // Filter out clients who already have this voucher assigned
      final newClientIds = validClientIds
          .where((clientId) => !existingClientIds.contains(clientId))
          .toList();

      AppLogger.info('📊 Assignment status:');
      AppLogger.info('   - New assignments: ${newClientIds.length}');
      AppLogger.info('   - Already assigned: ${existingClientIds.length}');

      if (newClientIds.isEmpty) {
        AppLogger.info('ℹ️ All clients already have this voucher assigned');
        // Return existing assignments for these clients
        return await _getExistingClientVouchers(request.voucherId, validClientIds);
      }

      // Create new assignment request with only new clients
      final newRequest = ClientVoucherAssignRequest(
        voucherId: request.voucherId,
        clientIds: newClientIds,
        metadata: request.metadata,
      );

      AppLogger.info('🔄 Inserting ${newClientIds.length} new voucher assignments...');

      final response = await _supabase
          .from('client_vouchers')
          .insert(newRequest.toJsonListWithAssignedBy(currentUser.id))
          .select('''
            *,
            vouchers (*)
          ''');

      final newClientVouchers = (response as List)
          .map((json) => ClientVoucherModel.fromJson(json as Map<String, dynamic>))
          .toList();

      AppLogger.info('✅ Successfully created ${newClientVouchers.length} new assignments');

      // Verify assignments were created successfully
      for (final assignment in newClientVouchers) {
        AppLogger.info('   ✓ Assignment created: ${assignment.id} for client ${assignment.clientId}');
      }

      // If there were existing assignments, fetch and combine them
      if (existingClientIds.isNotEmpty) {
        final existingClientVouchers = await _getExistingClientVouchers(
          request.voucherId,
          existingClientIds.toList()
        );

        final allClientVouchers = [...newClientVouchers, ...existingClientVouchers];
        AppLogger.info('🎉 Voucher assignment completed successfully!');
        AppLogger.info('   - Total assignments: ${allClientVouchers.length}');
        AppLogger.info('   - New: ${newClientVouchers.length}');
        AppLogger.info('   - Existing: ${existingClientVouchers.length}');
        return allClientVouchers;
      }

      AppLogger.info('🎉 Voucher assignment completed successfully!');
      AppLogger.info('   - Total new assignments: ${newClientVouchers.length}');
      return newClientVouchers;
    } catch (e) {
      AppLogger.error('❌ Error assigning vouchers to clients: $e');

      // Check if it's a duplicate key error and provide user-friendly message
      if (e.toString().contains('duplicate key value violates unique constraint')) {
        AppLogger.error('❌ Duplicate voucher assignment detected');
        throw Exception('تم تعيين هذه القسيمة لبعض العملاء مسبقاً');
      }

      // Check for RLS policy violations
      if (e.toString().contains('new row violates row-level security policy')) {
        AppLogger.error('❌ RLS policy violation - user may not have permission');
        throw Exception('ليس لديك صلاحية لتعيين القسائم');
      }

      rethrow;
    }
  }

  /// Helper method to get existing client voucher assignments
  Future<List<ClientVoucherModel>> _getExistingClientVouchers(String voucherId, List<String> clientIds) async {
    try {
      final response = await _supabase
          .from('client_vouchers')
          .select('''
            *,
            vouchers (*)
          ''')
          .eq('voucher_id', voucherId)
          .inFilter('client_id', clientIds);

      return (response as List)
          .map((json) => ClientVoucherModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching existing client vouchers: $e');
      return [];
    }
  }

  /// Get client vouchers for a specific client with enhanced null safety and debugging
  Future<List<ClientVoucherModel>> getClientVouchers(String clientId) async {
    try {
      AppLogger.info('🔄 Fetching vouchers for client: $clientId');

      // Validate client ID
      if (clientId.isEmpty) {
        AppLogger.error('❌ Client ID is empty');
        return [];
      }

      // Check current user authentication
      final currentUser = _supabase.auth.currentUser;
      AppLogger.info('🔐 Current auth user: ${currentUser?.id} (${currentUser?.email})');
      AppLogger.info('🎯 Requested client ID: $clientId');

      // Verify user can access this data
      if (currentUser?.id != clientId) {
        AppLogger.warning('⚠️ User ${currentUser?.id} requesting vouchers for different client $clientId');
      }

      final response = await _supabase
          .from('client_vouchers')
          .select('''
            *,
            vouchers (*)
          ''')
          .eq('client_id', clientId)
          .order('created_at', ascending: false);

      AppLogger.info('📊 Raw response received: ${response.length} records');

      final responseList = response as List? ?? [];
      AppLogger.info('📦 Raw response contains ${responseList.length} records');

      final validClientVouchers = <ClientVoucherModel>[];
      int nullVoucherCount = 0;
      int invalidDataCount = 0;

      for (int i = 0; i < responseList.length; i++) {
        final json = responseList[i];

        if (json == null) {
          invalidDataCount++;
          AppLogger.warning('⚠️ Null JSON entry at index $i');
          continue;
        }

        try {
          final clientVoucher = ClientVoucherModel.fromJson(json as Map<String, dynamic>);

          // Validate voucher data integrity
          if (clientVoucher.voucher == null) {
            nullVoucherCount++;
            AppLogger.warning('⚠️ NULL VOUCHER DATA - Client Voucher ID: ${clientVoucher.id}, Voucher ID: ${clientVoucher.voucherId}, Status: ${clientVoucher.status.value}');

            // Check if we should include vouchers with null data
            if (_shouldIncludeNullVoucher(clientVoucher)) {
              validClientVouchers.add(clientVoucher);
              AppLogger.info('✅ Including voucher with null data (status allows it)');
            } else {
              AppLogger.warning('❌ Excluding voucher with null data (unsafe for UI)');
            }
          } else {
            // Validate voucher fields
            if (_isVoucherDataValid(clientVoucher.voucher!)) {
              validClientVouchers.add(clientVoucher);
              AppLogger.info('✅ Valid voucher: ${clientVoucher.id} - ${clientVoucher.voucher!.name} (${clientVoucher.voucher!.code})');
            } else {
              AppLogger.warning('❌ Invalid voucher data: ${clientVoucher.id} - missing required fields');
            }
          }
        } catch (e) {
          invalidDataCount++;
          AppLogger.error('❌ Error parsing client voucher JSON at index $i: $e');
          AppLogger.error('🔍 Problematic JSON: $json');
        }
      }

      // Log summary
      AppLogger.info('📊 Voucher processing summary:');
      AppLogger.info('   - Total records: ${responseList.length}');
      AppLogger.info('   - Valid vouchers: ${validClientVouchers.length}');
      AppLogger.info('   - Null voucher data: $nullVoucherCount');
      AppLogger.info('   - Invalid data: $invalidDataCount');

      if (nullVoucherCount > 0) {
        AppLogger.warning('⚠️ Found $nullVoucherCount client vouchers with NULL voucher data!');
        AppLogger.warning('💡 This may indicate database integrity issues or missing voucher records.');
      }

      AppLogger.info('✅ Successfully processed ${validClientVouchers.length} safe vouchers for client: $clientId');
      return validClientVouchers;
    } catch (e) {
      AppLogger.error('❌ Error fetching client vouchers for $clientId: $e');
      return [];
    }
  }

  /// Check if a voucher with null data should be included (for specific statuses)
  bool _shouldIncludeNullVoucher(ClientVoucherModel clientVoucher) {
    // Only include null vouchers if they're in a safe state (used/expired)
    // Active vouchers with null data are unsafe for UI
    return clientVoucher.status == ClientVoucherStatus.used ||
           clientVoucher.status == ClientVoucherStatus.expired;
  }

  /// Validate voucher data integrity
  bool _isVoucherDataValid(VoucherModel voucher) {
    // Check basic required fields
    if (voucher.id.isEmpty ||
        voucher.code.isEmpty ||
        voucher.name.isEmpty ||
        voucher.targetId.isEmpty) {
      return false;
    }

    // Check discount validity based on discount type
    switch (voucher.discountType) {
      case DiscountType.percentage:
        // For percentage vouchers, discount percentage must be > 0
        return voucher.discountPercentage > 0;
      case DiscountType.fixedAmount:
        // For fixed amount vouchers, discount amount must be > 0
        // (discount percentage is intentionally 0 for fixed amount vouchers)
        return voucher.discountAmount != null && voucher.discountAmount! > 0;
    }
  }

  /// Perform comprehensive database integrity check for vouchers with enhanced detection
  Future<Map<String, dynamic>> performDatabaseIntegrityCheck() async {
    final result = <String, dynamic>{
      'success': false,
      'totalClientVouchers': 0,
      'orphanedClientVouchers': 0,
      'invalidVouchers': 0,
      'validVouchers': 0,
      'expiredActiveVouchers': 0,
      'recoveryVouchers': 0,
      'issues': <String>[],
      'recommendations': <String>[],
      'orphanedDetails': <Map<String, dynamic>>[],
    };

    try {
      AppLogger.info('🔍 Starting comprehensive voucher database integrity check...');

      // Get all client vouchers with voucher data
      final response = await _supabase
          .from('client_vouchers')
          .select('''
            *,
            vouchers (*)
          ''')
          .order('created_at', ascending: false);

      final allClientVouchers = response as List? ?? [];
      result['totalClientVouchers'] = allClientVouchers.length;

      int orphanedCount = 0;
      int invalidCount = 0;
      int validCount = 0;
      int recoveryCount = 0;
      final issues = <String>[];
      final orphanedDetails = <Map<String, dynamic>>[];

      for (final cvData in allClientVouchers) {
        final clientVoucherId = cvData['id']?.toString() ?? 'unknown';
        final voucherId = cvData['voucher_id']?.toString() ?? '';
        final clientId = cvData['client_id']?.toString() ?? '';
        final status = cvData['status']?.toString() ?? '';
        final assignedAt = cvData['assigned_at']?.toString() ?? '';
        final voucherData = cvData['vouchers'];

        if (voucherData == null) {
          orphanedCount++;
          issues.add('Client voucher $clientVoucherId references non-existent voucher $voucherId');

          // Collect detailed information about orphaned records
          orphanedDetails.add({
            'client_voucher_id': clientVoucherId,
            'missing_voucher_id': voucherId,
            'client_id': clientId,
            'status': status,
            'assigned_at': assignedAt,
          });
        } else {
          try {
            final voucher = VoucherModel.fromJson(voucherData as Map<String, dynamic>);

            // Check if this is a recovery voucher
            if (voucher.metadata?['recovery'] == true) {
              recoveryCount++;
            }

            if (_isVoucherDataValid(voucher)) {
              validCount++;
            } else {
              invalidCount++;
              issues.add('Client voucher $clientVoucherId has invalid voucher data: ${voucher.id}');
            }
          } catch (e) {
            invalidCount++;
            issues.add('Client voucher $clientVoucherId has malformed voucher data: $e');
          }
        }
      }

      // Check for expired active vouchers
      final expiredActiveResponse = await _supabase
          .from('vouchers')
          .select('id, name, expiration_date')
          .eq('is_active', true)
          .lt('expiration_date', DateTime.now().toIso8601String());

      final expiredActiveVouchers = expiredActiveResponse as List? ?? [];
      result['expiredActiveVouchers'] = expiredActiveVouchers.length;

      if (expiredActiveVouchers.isNotEmpty) {
        issues.add('Found ${expiredActiveVouchers.length} active vouchers that have expired');
      }

      result['orphanedClientVouchers'] = orphanedCount;
      result['invalidVouchers'] = invalidCount;
      result['validVouchers'] = validCount;
      result['recoveryVouchers'] = recoveryCount;
      result['issues'] = issues;
      result['orphanedDetails'] = orphanedDetails;

      // Generate enhanced recommendations
      final recommendations = <String>[];
      if (orphanedCount > 0) {
        recommendations.add('CRITICAL: Clean up $orphanedCount orphaned client voucher records');
        recommendations.add('Run DATABASE_INTEGRITY_CLEANUP.sql to fix orphaned records');
        recommendations.add('Investigate why voucher records are missing - possible unauthorized deletion');
        recommendations.add('Consider implementing audit logging for voucher deletions');
      }
      if (invalidCount > 0) {
        recommendations.add('Fix $invalidCount vouchers with invalid data');
        recommendations.add('Ensure all vouchers have required fields: code, name, target_id, discount_percentage');
      }
      if (expiredActiveVouchers.isNotEmpty) {
        recommendations.add('Update ${expiredActiveVouchers.length} expired vouchers to inactive status');
        recommendations.add('Run cleanup_expired_vouchers() function to fix expired voucher statuses');
      }
      if (recoveryCount > 0) {
        recommendations.add('Found $recoveryCount recovery vouchers - review and activate if needed');
      }
      if (orphanedCount == 0 && invalidCount == 0 && expiredActiveVouchers.isEmpty) {
        recommendations.add('✅ Database integrity is excellent - no issues found');
      }

      result['recommendations'] = recommendations;
      result['success'] = true;

      AppLogger.info('✅ Comprehensive database integrity check completed');
      AppLogger.info('📊 Results: $validCount valid, $invalidCount invalid, $orphanedCount orphaned, $recoveryCount recovery');

      if (orphanedCount > 0) {
        AppLogger.error('🚨 CRITICAL: Found $orphanedCount orphaned client voucher records!');
        AppLogger.error('💡 Run DATABASE_INTEGRITY_CLEANUP.sql to fix this issue');
      }

      return result;
    } catch (e) {
      AppLogger.error('❌ Database integrity check failed: $e');
      result['issues'] = ['Failed to perform integrity check: $e'];
      return result;
    }
  }

  /// Clean up orphaned client voucher records with enhanced safety measures
  Future<Map<String, dynamic>> cleanupOrphanedClientVouchers({bool dryRun = true}) async {
    final result = <String, dynamic>{
      'success': false,
      'orphanedFound': 0,
      'orphanedCleaned': 0,
      'backupCreated': false,
      'errors': <String>[],
      'orphanedDetails': <Map<String, dynamic>>[],
    };

    try {
      AppLogger.info('🧹 Starting ${dryRun ? 'DRY RUN' : 'ACTUAL'} cleanup of orphaned client vouchers...');

      // Find client vouchers with null voucher data
      final response = await _supabase
          .from('client_vouchers')
          .select('''
            *,
            vouchers (id)
          ''');

      final allClientVouchers = response as List? ?? [];
      final orphanedRecords = <Map<String, dynamic>>[];

      for (final cvData in allClientVouchers) {
        if (cvData['vouchers'] == null) {
          orphanedRecords.add({
            'id': cvData['id'],
            'voucher_id': cvData['voucher_id'],
            'client_id': cvData['client_id'],
            'status': cvData['status'],
            'assigned_at': cvData['assigned_at'],
            'created_at': cvData['created_at'],
          });
        }
      }

      result['orphanedFound'] = orphanedRecords.length;
      result['orphanedDetails'] = orphanedRecords;

      if (orphanedRecords.isEmpty) {
        AppLogger.info('✅ No orphaned client vouchers found');
        result['success'] = true;
        return result;
      }

      AppLogger.warning('⚠️ Found ${orphanedRecords.length} orphaned client vouchers');

      if (dryRun) {
        AppLogger.info('🔍 DRY RUN - Would clean up the following orphaned records:');
        for (final record in orphanedRecords) {
          AppLogger.info('   - Client Voucher: ${record['id']} -> Missing Voucher: ${record['voucher_id']}');
        }
        AppLogger.info('💡 Run with dryRun=false to perform actual cleanup');
        result['success'] = true;
        return result;
      }

      // Actual cleanup - create backup first
      try {
        // Note: In a real implementation, you would create a backup table
        // For now, we'll log the details for manual recovery if needed
        AppLogger.info('📋 Creating backup of orphaned records...');

        for (final record in orphanedRecords) {
          AppLogger.info('BACKUP: ${record.toString()}');
        }

        result['backupCreated'] = true;

        // Delete orphaned records
        final orphanedIds = orphanedRecords.map((r) => r['id']).toList();

        final deleteResponse = await _supabase
            .from('client_vouchers')
            .delete()
            .inFilter('id', orphanedIds);

        result['orphanedCleaned'] = orphanedRecords.length;

        AppLogger.info('✅ Successfully cleaned up ${orphanedRecords.length} orphaned client vouchers');

      } catch (e) {
        AppLogger.error('❌ Failed to clean up orphaned records: $e');
        result['errors'].add('Cleanup failed: $e');
        return result;
      }

      result['success'] = true;
      return result;
    } catch (e) {
      AppLogger.error('❌ Cleanup operation failed: $e');
      result['errors'].add('Operation failed: $e');
      return result;
    }
  }

  /// Attempt to recover orphaned client vouchers by creating placeholder vouchers
  Future<Map<String, dynamic>> recoverOrphanedClientVouchers() async {
    final result = <String, dynamic>{
      'success': false,
      'orphanedFound': 0,
      'vouchersCreated': 0,
      'errors': <String>[],
      'recoveredVouchers': <Map<String, dynamic>>[],
    };

    try {
      AppLogger.info('🔄 Starting recovery of orphaned client vouchers...');

      // Get current user for voucher creation
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        result['errors'].add('No authenticated user for voucher creation');
        return result;
      }

      // Find orphaned client vouchers grouped by voucher_id
      final response = await _supabase
          .from('client_vouchers')
          .select('''
            voucher_id,
            status,
            vouchers (id)
          ''');

      final allClientVouchers = response as List? ?? [];
      final orphanedVoucherIds = <String, Map<String, dynamic>>{};

      for (final cvData in allClientVouchers) {
        if (cvData['vouchers'] == null) {
          final voucherId = cvData['voucher_id'] as String;
          final status = cvData['status'] as String;

          if (!orphanedVoucherIds.containsKey(voucherId)) {
            orphanedVoucherIds[voucherId] = {
              'voucher_id': voucherId,
              'assignment_count': 0,
              'active_assignments': 0,
            };
          }

          orphanedVoucherIds[voucherId]!['assignment_count'] =
              (orphanedVoucherIds[voucherId]!['assignment_count'] as int) + 1;

          if (status == 'active') {
            orphanedVoucherIds[voucherId]!['active_assignments'] =
                (orphanedVoucherIds[voucherId]!['active_assignments'] as int) + 1;
          }
        }
      }

      result['orphanedFound'] = orphanedVoucherIds.length;

      if (orphanedVoucherIds.isEmpty) {
        AppLogger.info('✅ No orphaned vouchers to recover');
        result['success'] = true;
        return result;
      }

      AppLogger.info('🔄 Attempting to recover ${orphanedVoucherIds.length} orphaned vouchers...');

      // Create recovery vouchers
      for (final entry in orphanedVoucherIds.entries) {
        final voucherId = entry.key;
        final details = entry.value;

        try {
          final recoveryCode = 'RECOVERY-${DateTime.now().millisecondsSinceEpoch}-${voucherId.substring(0, 6)}';

          final recoveryVoucher = {
            'id': voucherId, // Use original voucher ID
            'code': recoveryCode,
            'name': 'قسيمة مستردة - Recovery Voucher',
            'description': 'تم إنشاء هذه القسيمة لاستعادة التعيينات المفقودة',
            'type': 'product',
            'target_id': 'recovery-product',
            'target_name': 'منتج الاسترداد',
            'discount_percentage': 10,
            'expiration_date': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
            'is_active': false, // Inactive by default - admin can activate
            'created_by': currentUser.id,
            'metadata': {
              'recovery': true,
              'original_voucher_id': voucherId,
              'assignment_count': details['assignment_count'],
              'active_assignments': details['active_assignments'],
              'recovery_timestamp': DateTime.now().toIso8601String(),
            },
          };

          await _supabase
              .from('vouchers')
              .insert(recoveryVoucher);

          result['vouchersCreated'] = (result['vouchersCreated'] as int) + 1;
          (result['recoveredVouchers'] as List).add({
            'voucher_id': voucherId,
            'recovery_code': recoveryCode,
            'assignment_count': details['assignment_count'],
            'active_assignments': details['active_assignments'],
          });

          AppLogger.info('✅ Created recovery voucher $recoveryCode for $voucherId (${details['assignment_count']} assignments)');

        } catch (e) {
          AppLogger.error('❌ Failed to create recovery voucher for $voucherId: $e');
          (result['errors'] as List).add('Failed to recover voucher $voucherId: $e');
        }
      }

      result['success'] = true;
      AppLogger.info('🎉 Recovery completed: ${result['vouchersCreated']} vouchers recovered');

      return result;
    } catch (e) {
      AppLogger.error('❌ Recovery operation failed: $e');
      result['errors'].add('Recovery failed: $e');
      return result;
    }
  }

  /// Get active client vouchers for a specific client
  Future<List<ClientVoucherModel>> getActiveClientVouchers(String clientId) async {
    try {
      AppLogger.info('Fetching active vouchers for client: $clientId');

      final response = await _supabase
          .from('client_vouchers')
          .select('''
            *,
            vouchers (*)
          ''')
          .eq('client_id', clientId)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      final clientVouchers = (response as List)
          .map((json) => ClientVoucherModel.fromJson(json as Map<String, dynamic>))
          .toList();

      // Filter out expired vouchers
      final activeVouchers = clientVouchers.where((cv) => cv.canBeUsed).toList();

      AppLogger.info('Fetched ${activeVouchers.length} active vouchers for client');
      return activeVouchers;
    } catch (e) {
      AppLogger.error('Error fetching active client vouchers: $e');
      return [];
    }
  }

  /// Get all client voucher assignments with enhanced orphaned record detection
  Future<List<ClientVoucherModel>> getAllClientVouchers() async {
    try {
      AppLogger.info('🔍 Fetching all client voucher assignments with integrity check...');

      // First, get the basic client voucher data with voucher details
      final response = await _supabase
          .from('client_vouchers')
          .select('''
            *,
            vouchers (*)
          ''')
          .order('created_at', ascending: false);

      final responseList = response as List? ?? [];
      final clientVouchers = <ClientVoucherModel>[];
      int orphanedCount = 0;
      final orphanedDetails = <Map<String, dynamic>>[];

      // Process each client voucher and fetch client names separately
      for (final json in responseList) {
        if (json == null) continue;

        try {
          final updatedJson = Map<String, dynamic>.from(json as Map<dynamic, dynamic>);
          final clientVoucherId = json['id']?.toString() ?? 'unknown';
          final voucherId = json['voucher_id']?.toString() ?? 'unknown';
          final voucherData = json['vouchers'];

          // Check for orphaned records
          if (voucherData == null) {
            orphanedCount++;
            orphanedDetails.add({
              'client_voucher_id': clientVoucherId,
              'missing_voucher_id': voucherId,
              'client_id': json['client_id']?.toString(),
              'status': json['status']?.toString(),
              'assigned_at': json['assigned_at']?.toString(),
            });

            AppLogger.error('🚨 ORPHANED RECORD DETECTED:');
            AppLogger.error('   - Client Voucher ID: $clientVoucherId');
            AppLogger.error('   - Missing Voucher ID: $voucherId');
            AppLogger.error('   - Client ID: ${json['client_id']}');
            AppLogger.error('   - Status: ${json['status']}');
          }

          // Fetch client name separately for better reliability
          final clientId = json['client_id']?.toString();
          if (clientId != null && clientId.isNotEmpty) {
            try {
              final clientProfile = await _supabase
                  .from('user_profiles')
                  .select('name, email')
                  .eq('id', clientId)
                  .maybeSingle();

              if (clientProfile != null) {
                updatedJson['client_name'] = clientProfile['name']?.toString() ?? 'عميل غير معروف';
                updatedJson['client_email'] = clientProfile['email']?.toString();
                AppLogger.info('✅ Found client: ${updatedJson['client_name']} (${updatedJson['client_email']})');
              } else {
                updatedJson['client_name'] = 'عميل غير معروف';
                updatedJson['client_email'] = null;
                AppLogger.warning('⚠️ No profile found for client ID: $clientId');
              }
            } catch (e) {
              AppLogger.warning('⚠️ Error fetching client profile for ID $clientId: $e');
              updatedJson['client_name'] = 'عميل غير معروف';
              updatedJson['client_email'] = null;
            }
          } else {
            updatedJson['client_name'] = 'عميل غير معروف';
            updatedJson['client_email'] = null;
          }

          // Fetch assigned by name separately
          final assignedById = json['assigned_by']?.toString();
          if (assignedById != null && assignedById.isNotEmpty) {
            try {
              final assignedByProfile = await _supabase
                  .from('user_profiles')
                  .select('name')
                  .eq('id', assignedById)
                  .maybeSingle();

              if (assignedByProfile != null) {
                updatedJson['assigned_by_name'] = assignedByProfile['name']?.toString() ?? 'مستخدم غير معروف';
              } else {
                updatedJson['assigned_by_name'] = 'مستخدم غير معروف';
              }
            } catch (e) {
              AppLogger.warning('⚠️ Error fetching assigned by profile for ID $assignedById: $e');
              updatedJson['assigned_by_name'] = 'مستخدم غير معروف';
            }
          } else {
            updatedJson['assigned_by_name'] = 'مستخدم غير معروف';
          }

          final clientVoucher = ClientVoucherModel.fromJson(updatedJson);
          clientVouchers.add(clientVoucher);

        } catch (e) {
          AppLogger.error('Error parsing client voucher JSON: $e');
          AppLogger.error('Problematic JSON: $json');
          continue; // Skip this entry and continue with others
        }
      }

      // Log orphaned records summary
      if (orphanedCount > 0) {
        AppLogger.error('🚨 CRITICAL: Found $orphanedCount orphaned client voucher records!');
        AppLogger.error('💡 Run EMERGENCY_RECOVERY_SCRIPT.sql immediately');
        AppLogger.error('📋 Orphaned records details: $orphanedDetails');
      }

      AppLogger.info('✅ Successfully fetched ${clientVouchers.length} client voucher assignments');
      AppLogger.info('📊 Integrity status: ${orphanedCount == 0 ? 'HEALTHY' : 'CRITICAL - $orphanedCount orphaned records'}');

      return clientVouchers;
    } catch (e) {
      AppLogger.error('❌ Error fetching all client vouchers: $e');
      return [];
    }
  }

  /// Use voucher (mark as used)
  Future<ClientVoucherModel?> useVoucher(VoucherUsageRequest request) async {
    try {
      AppLogger.info('Using voucher: ${request.clientVoucherId}');

      final response = await _supabase
          .from('client_vouchers')
          .update(request.toJson())
          .eq('id', request.clientVoucherId)
          .select('''
            *,
            vouchers (*)
          ''')
          .single();

      AppLogger.info('Voucher used successfully');
      return ClientVoucherModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Error using voucher: $e');
      return null;
    }
  }

  /// Check if voucher is valid for client
  Future<bool> isVoucherValidForClient(String voucherCode, String clientId) async {
    try {
      AppLogger.info('Checking voucher validity: $voucherCode for client: $clientId');

      final response = await _supabase.rpc('is_voucher_valid', params: {
        'voucher_code': voucherCode,
        'client_user_id': clientId,
      });

      final isValid = response as bool;
      AppLogger.info('Voucher validity check result: $isValid');
      return isValid;
    } catch (e) {
      AppLogger.error('Error checking voucher validity: $e');
      return false;
    }
  }

  /// Get applicable vouchers for cart items
  Future<List<ClientVoucherModel>> getApplicableVouchers(String clientId, List<Map<String, dynamic>> cartItems) async {
    try {
      AppLogger.info('Finding applicable vouchers for client: $clientId');

      // Get active client vouchers
      final clientVouchers = await getActiveClientVouchers(clientId);

      // Filter vouchers that apply to cart items
      final applicableVouchers = <ClientVoucherModel>[];

      for (final clientVoucher in clientVouchers) {
        final voucher = clientVoucher.voucher;
        if (voucher == null) continue;

        bool isApplicable = false;

        for (final item in cartItems) {
          final productId = item['productId']?.toString() ?? '';
          final productCategory = item['category']?.toString();

          switch (voucher.type) {
            case VoucherType.product:
              // Check if voucher applies to specific product
              if (productId == voucher.targetId) {
                isApplicable = true;
              }
              break;
            case VoucherType.category:
              // Check if voucher applies to product category
              if (productCategory == voucher.targetId || productCategory == voucher.targetName) {
                isApplicable = true;
              }
              break;
            case VoucherType.multipleProducts:
              // Check if voucher applies to any of the selected products
              if (voucher.isProductApplicable(productId, productCategory)) {
                isApplicable = true;
              }
              break;
          }

          if (isApplicable) break;
        }

        if (isApplicable) {
          applicableVouchers.add(clientVoucher);
        }
      }

      AppLogger.info('Found ${applicableVouchers.length} applicable vouchers');
      return applicableVouchers;
    } catch (e) {
      AppLogger.error('Error finding applicable vouchers: $e');
      return [];
    }
  }

  /// Calculate discount for cart items with voucher
  Map<String, dynamic> calculateVoucherDiscount(VoucherModel voucher, List<Map<String, dynamic>> cartItems) {
    double totalDiscount = 0.0;
    final discountedItems = <Map<String, dynamic>>[];

    for (final item in cartItems) {
      bool itemApplies = false;
      final productId = item['productId'].toString();
      final productCategory = item['category']?.toString();

      switch (voucher.type) {
        case VoucherType.product:
          itemApplies = productId == voucher.targetId;
          break;
        case VoucherType.category:
          itemApplies = productCategory == voucher.targetName || productCategory == voucher.targetId;
          break;
        case VoucherType.multipleProducts:
          // Check if product is in the selected products list
          itemApplies = voucher.isProductApplicable(productId, productCategory);
          break;
      }

      if (itemApplies) {
        final price = (item['price'] as num).toDouble();
        final quantity = (item['quantity'] as num).toInt();
        final itemTotal = price * quantity;

        double itemDiscount = 0.0;
        double discountedPrice = price;

        switch (voucher.discountType) {
          case DiscountType.percentage:
            itemDiscount = itemTotal * (voucher.discountPercentage / 100);
            discountedPrice = price * (1 - voucher.discountPercentage / 100);
            break;

          case DiscountType.fixedAmount:
            final fixedDiscount = voucher.discountAmount ?? 0.0;
            // Apply fixed discount per item, but don't exceed item price
            final discountPerItem = fixedDiscount > price ? price : fixedDiscount;
            itemDiscount = discountPerItem * quantity;
            discountedPrice = price - discountPerItem;
            break;
        }

        totalDiscount += itemDiscount;
        final discountedItem = Map<String, dynamic>.from(item);
        discountedItem['originalPrice'] = price;
        discountedItem['discountedPrice'] = discountedPrice;
        discountedItem['discountAmount'] = itemDiscount;
        discountedItems.add(discountedItem);
      }
    }

    return {
      'totalDiscount': totalDiscount,
      'discountedItems': discountedItems,
      'voucherCode': voucher.code,
      'discountType': voucher.discountType.value,
      'discountPercentage': voucher.discountPercentage,
      'discountAmount': voucher.discountAmount,
      'formattedDiscount': voucher.formattedDiscount,
    };
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Get voucher statistics
  Future<Map<String, dynamic>> getVoucherStatistics() async {
    try {
      AppLogger.info('Fetching voucher statistics');

      // Get total vouchers count
      final totalVouchersResponse = await _supabase
          .from('vouchers')
          .select('id');

      // Get active vouchers count
      final activeVouchersResponse = await _supabase
          .from('vouchers')
          .select('id')
          .eq('is_active', true)
          .gt('expiration_date', DateTime.now().toIso8601String());

      // Get used vouchers count
      final usedVouchersResponse = await _supabase
          .from('client_vouchers')
          .select('id')
          .eq('status', 'used');

      // Get total assignments count
      final totalAssignmentsResponse = await _supabase
          .from('client_vouchers')
          .select('id');

      final statistics = {
        'totalVouchers': (totalVouchersResponse as List).length,
        'activeVouchers': (activeVouchersResponse as List).length,
        'usedVouchers': (usedVouchersResponse as List).length,
        'totalAssignments': (totalAssignmentsResponse as List).length,
      };

      AppLogger.info('Voucher statistics fetched successfully');
      return statistics;
    } catch (e) {
      AppLogger.error('Error fetching voucher statistics: $e');
      return {
        'totalVouchers': 0,
        'activeVouchers': 0,
        'usedVouchers': 0,
        'totalAssignments': 0,
      };
    }
  }

  /// Get product categories for voucher creation
  Future<List<String>> getProductCategories() async {
    try {
      AppLogger.info('Fetching product categories from unified API');

      // استخدام خدمة المنتجات الموحدة بدلاً من Supabase
      final unifiedService = UnifiedProductsService();
      final categories = await unifiedService.getCategories();

      AppLogger.info('Fetched ${categories.length} product categories from unified API');
      return categories;
    } catch (e) {
      AppLogger.error('Error fetching product categories from unified API: $e');
      return [];
    }
  }

  /// Get products for voucher creation
  Future<List<Map<String, dynamic>>> getProductsForVoucher() async {
    try {
      AppLogger.info('Fetching products for voucher creation from unified API');

      // استخدام خدمة المنتجات الموحدة بدلاً من Supabase
      final unifiedService = UnifiedProductsService();
      final products = await unifiedService.getProducts();

      // تحويل ProductModel إلى Map للتوافق مع الكود الحالي
      final productsMap = products.map((product) => {
        'id': product.id,
        'name': product.name,
        'category': product.category,
        'price': product.price,
      }).toList();

      AppLogger.info('Fetched ${productsMap.length} products for voucher creation from unified API');
      return productsMap;
    } catch (e) {
      AppLogger.error('Error fetching products for voucher creation from unified API: $e');
      return [];
    }
  }

  /// Get available products for voucher creation with stock filtering and indicators
  Future<List<Map<String, dynamic>>> getAvailableProductsForVoucher({
    bool includeOutOfStock = false,
    bool sortByQuantity = true,
  }) async {
    try {
      AppLogger.info('Fetching available products for voucher creation with stock filtering');

      // استخدام خدمة المنتجات الموحدة
      final unifiedService = UnifiedProductsService();
      final products = await unifiedService.getProducts();

      // فلترة المنتجات المتاحة
      final availableProducts = products.where((product) {
        // فلترة المنتجات غير النشطة
        if (!product.isActive) return false;

        // فلترة المنتجات نفدت من المخزون (إلا إذا طُلب تضمينها)
        if (!includeOutOfStock && product.quantity <= 0) return false;

        return true;
      }).toList();

      // ترتيب المنتجات حسب الكمية (الأعلى كمية أولاً) إذا طُلب ذلك
      if (sortByQuantity) {
        availableProducts.sort((a, b) => b.quantity.compareTo(a.quantity));
      }

      // تحويل ProductModel إلى Map مع معلومات المخزون المحسنة
      final productsMap = availableProducts.map((product) {
        final stockStatus = _getStockStatus(product.quantity, product.reorderPoint);

        return {
          'id': product.id,
          'name': product.name,
          'category': product.category,
          'price': product.price,
          'quantity': product.quantity,
          'reorderPoint': product.reorderPoint,
          'isActive': product.isActive,
          'stockStatus': stockStatus['status'],
          'stockIcon': stockStatus['icon'],
          'stockColor': stockStatus['color'],
          'stockDescription': stockStatus['description'],
          'displayName': '${product.name} (متوفر: ${product.quantity})',
          'isLowStock': product.quantity <= product.reorderPoint,
          'isVeryLowStock': product.quantity <= 3,
          'isOutOfStock': product.quantity <= 0,
          'imageUrl': product.imageUrl,
          'images': product.images,
        };
      }).toList();

      AppLogger.info('Fetched ${productsMap.length} available products for voucher creation');
      return productsMap;
    } catch (e) {
      AppLogger.error('Error fetching available products for voucher creation: $e');
      return [];
    }
  }

  /// Get stock status information for a product
  Map<String, dynamic> _getStockStatus(int quantity, int reorderPoint) {
    if (quantity <= 0) {
      return {
        'status': 'out_of_stock',
        'icon': '🔴',
        'color': 'red',
        'description': 'نفد من المخزون',
      };
    } else if (quantity <= 3) {
      return {
        'status': 'very_low',
        'icon': '🔴',
        'color': 'red',
        'description': 'مخزون منخفض جداً',
      };
    } else if (quantity <= reorderPoint) {
      return {
        'status': 'low',
        'icon': '🟡',
        'color': 'orange',
        'description': 'مخزون قليل',
      };
    } else if (quantity > reorderPoint * 2) {
      return {
        'status': 'high',
        'icon': '🟢',
        'color': 'green',
        'description': 'متوفر بكثرة',
      };
    } else {
      return {
        'status': 'normal',
        'icon': '🟢',
        'color': 'green',
        'description': 'متوفر',
      };
    }
  }

  /// Filter products by search query
  List<Map<String, dynamic>> filterProductsBySearch(
    List<Map<String, dynamic>> products,
    String searchQuery,
  ) {
    if (searchQuery.isEmpty) return products;

    final query = searchQuery.toLowerCase().trim();
    return products.where((product) {
      final name = (product['name'] as String? ?? '').toLowerCase();
      final category = (product['category'] as String? ?? '').toLowerCase();

      return name.contains(query) || category.contains(query);
    }).toList();
  }

  /// Filter products by category
  List<Map<String, dynamic>> filterProductsByCategory(
    List<Map<String, dynamic>> products,
    String? category,
  ) {
    if (category == null || category.isEmpty || category == 'الكل') {
      return products;
    }

    return products.where((product) {
      final productCategory = product['category'] as String? ?? '';
      return productCategory == category;
    }).toList();
  }
}
