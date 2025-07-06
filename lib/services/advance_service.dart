import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/models/advance_model.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/utils/uuid_validator.dart';

/// خدمة إدارة السلف
class AdvanceService {
  final SupabaseClient _supabase = Supabase.instance.client;

  SupabaseQueryBuilder get _advancesTable => _supabase.from('advances');
  SupabaseQueryBuilder get _userProfilesTable => _supabase.from('user_profiles');

  // Cache to prevent excessive API calls
  List<AdvanceModel>? _cachedAdvances;
  DateTime? _lastFetchTime;
  Future<List<AdvanceModel>>? _ongoingRequest;
  static const Duration _cacheTimeout = Duration(minutes: 3);

  /// إنشاء سلفة جديدة باسم العميل (نص عادي)
  Future<AdvanceModel> createAdvanceWithClientName({
    required String advanceName,
    required String clientName,
    required double amount,
    String? description,
    required String createdBy,
  }) async {
    try {
      AppLogger.info('🔄 Creating new advance with client name: $advanceName for client: $clientName');

      final advanceData = {
        'advance_name': advanceName,
        'client_name': clientName,
        'amount': amount,
        'description': description ?? '',
        'status': 'pending',
        'created_by': createdBy,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _advancesTable
          .insert(advanceData)
          .select()
          .single();

      final advance = AdvanceModel.fromDatabase(response);
      AppLogger.info('✅ Created advance with client name: ${advance.id}');
      return advance;
    } catch (e) {
      AppLogger.error('❌ Error creating advance with client name: $e');
      throw Exception('فشل في إنشاء السلفة: $e');
    }
  }

  /// إنشاء سلفة جديدة (الطريقة الأصلية بمعرف العميل)
  Future<AdvanceModel> createAdvance({
    required String advanceName,
    required String clientId,
    required double amount,
    required String description,
    required String createdBy,
  }) async {
    try {
      AppLogger.info('🔄 Creating new advance: $advanceName for client: $clientId');

      // الحصول على اسم العميل
      final clientProfile = await _userProfilesTable
          .select('name')
          .eq('id', clientId)
          .single();

      final advanceData = {
        'advance_name': advanceName,
        'client_id': clientId,
        'amount': amount,
        'description': description,
        'status': 'pending',
        'created_by': createdBy,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _advancesTable
          .insert(advanceData)
          .select()
          .single();

      // إضافة اسم العميل للاستجابة
      response['client_name'] = clientProfile['name'];

      final advance = AdvanceModel.fromDatabase(response);
      AppLogger.info('✅ Created advance: ${advance.id}');
      return advance;
    } catch (e) {
      AppLogger.error('❌ Error creating advance: $e');
      throw Exception('فشل في إنشاء السلفة: $e');
    }
  }

  /// الحصول على جميع السلف مع التخزين المؤقت لمنع الاستدعاءات المفرطة
  Future<List<AdvanceModel>> getAllAdvances() async {
    try {
      // Check if we have cached data that's still valid
      if (_cachedAdvances != null && _lastFetchTime != null) {
        final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);
        if (timeSinceLastFetch < _cacheTimeout) {
          AppLogger.info('📋 Using cached advances data (${_cachedAdvances!.length} advances)');
          return _cachedAdvances!;
        }
      }

      // Check if there's already an ongoing request
      if (_ongoingRequest != null) {
        AppLogger.info('⏳ Advance request already in progress, waiting...');
        return await _ongoingRequest!;
      }

      // Start new request
      AppLogger.info('🔄 Fetching all advances from database');

      _ongoingRequest = _fetchAdvancesFromDatabase();

      try {
        final advances = await _ongoingRequest!;

        // Cache the results
        _cachedAdvances = advances;
        _lastFetchTime = DateTime.now();

        AppLogger.info('✅ Fetched and cached ${advances.length} advances');
        return advances;
      } finally {
        _ongoingRequest = null;
      }
    } catch (e) {
      _ongoingRequest = null;
      AppLogger.error('❌ Error fetching advances: $e');
      throw Exception('فشل في جلب السلف: $e');
    }
  }

  /// Helper method to fetch advances from database
  Future<List<AdvanceModel>> _fetchAdvancesFromDatabase() async {
    // الحصول على السلف
    final advancesResponse = await _advancesTable
        .select('*')
        .order('created_at', ascending: false);

    // الحصول على أسماء العملاء
    final userProfilesResponse = await _userProfilesTable
        .select('id, name');

    // إنشاء خريطة للعملاء
    final userProfilesMap = <String, String>{};
    for (final profile in userProfilesResponse) {
      userProfilesMap[(profile['id'] as String?) ?? ''] = (profile['name'] as String?) ?? 'عميل غير معروف';
    }

    final advances = (advancesResponse as List).map((data) {
      try {
        final advanceData = Map<String, dynamic>.from((data as Map<String, dynamic>?) ?? {});

        // Handle both cases: advances with client_id and advances with client_name only
        final clientId = (data as Map<String, dynamic>?)?['client_id'] as String?;

        if (clientId != null && clientId.isNotEmpty) {
          // Advance has client_id, get name from user profiles
          advanceData['client_name'] = userProfilesMap[clientId] ?? 'عميل غير معروف';
        } else {
          // Advance was created with client_name only, use existing client_name
          advanceData['client_name'] = (data as Map<String, dynamic>?)?['client_name'] ?? 'عميل غير معروف';
        }

        return AdvanceModel.fromDatabase(advanceData);
      } catch (e) {
        AppLogger.error('❌ Error parsing advance data: $e, Data: $data');
        // Return null for invalid data, will be filtered out
        return null;
      }
    }).where((advance) => advance != null).cast<AdvanceModel>().toList();

    return advances;
  }

  /// Clear cache and force refresh
  void clearCache() {
    _cachedAdvances = null;
    _lastFetchTime = null;
    _ongoingRequest = null;
    AppLogger.info('🗑️ Cleared advances cache');
  }

  /// الحصول على السلف حسب الحالة
  Future<List<AdvanceModel>> getAdvancesByStatus(String status) async {
    try {
      AppLogger.info('🔄 Fetching advances by status: $status');

      final advancesResponse = await _advancesTable
          .select('*')
          .eq('status', status)
          .order('created_at', ascending: false);

      // الحصول على أسماء العملاء
      final userProfilesResponse = await _userProfilesTable
          .select('id, name');

      final userProfilesMap = <String, String>{};
      for (final profile in userProfilesResponse) {
        userProfilesMap[(profile['id'] as String?) ?? ''] = (profile['name'] as String?) ?? 'عميل غير معروف';
      }

      final advances = (advancesResponse as List).map((data) {
        try {
          final advanceData = Map<String, dynamic>.from((data as Map<String, dynamic>?) ?? {});

          // Handle both cases: advances with client_id and advances with client_name only
          final clientId = (data as Map<String, dynamic>?)?['client_id'] as String?;

          if (clientId != null && clientId.isNotEmpty) {
            // Advance has client_id, get name from user profiles
            advanceData['client_name'] = userProfilesMap[clientId] ?? 'عميل غير معروف';
          } else {
            // Advance was created with client_name only, use existing client_name
            advanceData['client_name'] = (data as Map<String, dynamic>?)?['client_name'] ?? 'عميل غير معروف';
          }

          return AdvanceModel.fromDatabase(advanceData);
        } catch (e) {
          AppLogger.error('❌ Error parsing advance data by status: $e, Data: $data');
          return null;
        }
      }).where((advance) => advance != null).cast<AdvanceModel>().toList();

      AppLogger.info('✅ Fetched ${advances.length} advances with status: $status');
      return advances;
    } catch (e) {
      AppLogger.error('❌ Error fetching advances by status: $e');
      throw Exception('فشل في جلب السلف حسب الحالة: $e');
    }
  }

  /// الحصول على السلف الخاصة بعميل معين
  Future<List<AdvanceModel>> getAdvancesByClient(String clientId) async {
    try {
      AppLogger.info('🔄 Fetching advances for client: $clientId');

      final advancesResponse = await _advancesTable
          .select('*')
          .eq('client_id', clientId)
          .order('created_at', ascending: false);

      // الحصول على اسم العميل
      final clientProfile = await _userProfilesTable
          .select('name')
          .eq('id', clientId)
          .single();

      final clientName = clientProfile['name'] ?? 'عميل غير معروف';

      final advances = (advancesResponse as List).map((data) {
        try {
          final advanceData = Map<String, dynamic>.from((data as Map<String, dynamic>?) ?? {});
          advanceData['client_name'] = clientName;
          return AdvanceModel.fromDatabase(advanceData);
        } catch (e) {
          AppLogger.error('❌ Error parsing advance data by client: $e, Data: $data');
          return null;
        }
      }).where((advance) => advance != null).cast<AdvanceModel>().toList();

      AppLogger.info('✅ Fetched ${advances.length} advances for client: $clientId');
      return advances;
    } catch (e) {
      AppLogger.error('❌ Error fetching advances by client: $e');
      throw Exception('فشل في جلب سلف العميل: $e');
    }
  }

  /// اعتماد سلفة
  Future<AdvanceModel> approveAdvance(String advanceId, String approvedBy) async {
    try {
      AppLogger.info('🔄 Approving advance: $advanceId');

      final updateData = {
        'status': 'approved',
        'approved_by': approvedBy,
        'approved_at': DateTime.now().toIso8601String(),
      };

      final response = await _advancesTable
          .update(updateData)
          .eq('id', advanceId)
          .select()
          .single();

      // الحصول على اسم العميل (إذا كان متوفراً)
      final clientId = response['client_id'] as String?;
      if (clientId != null && clientId.isNotEmpty) {
        try {
          final clientProfile = await _userProfilesTable
              .select('name')
              .eq('id', clientId)
              .single();
          response['client_name'] = clientProfile['name'] ?? 'عميل غير معروف';
        } catch (e) {
          AppLogger.warning('Could not fetch client name for ID: $clientId');
          response['client_name'] = 'عميل غير معروف';
        }
      } else {
        // Use existing client_name if no client_id
        response['client_name'] = response['client_name'] ?? 'عميل غير معروف';
      }

      final advance = AdvanceModel.fromDatabase(response);
      AppLogger.info('✅ Approved advance: $advanceId');
      return advance;
    } catch (e) {
      AppLogger.error('❌ Error approving advance: $e');
      throw Exception('فشل في اعتماد السلفة: $e');
    }
  }

  /// رفض سلفة
  Future<AdvanceModel> rejectAdvance(String advanceId, String rejectedReason) async {
    try {
      AppLogger.info('🔄 Rejecting advance: $advanceId');

      final updateData = {
        'status': 'rejected',
        'rejected_reason': rejectedReason,
      };

      final response = await _advancesTable
          .update(updateData)
          .eq('id', advanceId)
          .select()
          .single();

      // الحصول على اسم العميل (إذا كان متوفراً)
      final clientId = response['client_id'] as String?;
      if (clientId != null && clientId.isNotEmpty) {
        try {
          final clientProfile = await _userProfilesTable
              .select('name')
              .eq('id', clientId)
              .single();
          response['client_name'] = clientProfile['name'] ?? 'عميل غير معروف';
        } catch (e) {
          AppLogger.warning('Could not fetch client name for ID: $clientId');
          response['client_name'] = 'عميل غير معروف';
        }
      } else {
        // Use existing client_name if no client_id
        response['client_name'] = response['client_name'] ?? 'عميل غير معروف';
      }

      final advance = AdvanceModel.fromDatabase(response);
      AppLogger.info('✅ Rejected advance: $advanceId');
      return advance;
    } catch (e) {
      AppLogger.error('❌ Error rejecting advance: $e');
      throw Exception('فشل في رفض السلفة: $e');
    }
  }

  /// تسديد سلفة
  Future<AdvanceModel> payAdvance(String advanceId) async {
    try {
      AppLogger.info('🔄 Paying advance: $advanceId');

      final updateData = {
        'status': 'paid',
        'paid_at': DateTime.now().toIso8601String(),
      };

      final response = await _advancesTable
          .update(updateData)
          .eq('id', advanceId)
          .select()
          .single();

      // الحصول على اسم العميل (إذا كان متوفراً)
      final clientId = response['client_id'] as String?;
      if (clientId != null && clientId.isNotEmpty) {
        try {
          final clientProfile = await _userProfilesTable
              .select('name')
              .eq('id', clientId)
              .single();
          response['client_name'] = clientProfile['name'] ?? 'عميل غير معروف';
        } catch (e) {
          AppLogger.warning('Could not fetch client name for ID: $clientId');
          response['client_name'] = 'عميل غير معروف';
        }
      } else {
        // Use existing client_name if no client_id
        response['client_name'] = response['client_name'] ?? 'عميل غير معروف';
      }

      final advance = AdvanceModel.fromDatabase(response);
      AppLogger.info('✅ Paid advance: $advanceId');
      return advance;
    } catch (e) {
      AppLogger.error('❌ Error paying advance: $e');
      throw Exception('فشل في تسديد السلفة: $e');
    }
  }

  /// تحديث سلفة
  Future<bool> updateAdvance(AdvanceModel advance) async {
    try {
      AppLogger.info('🔄 Updating advance: ${advance.id}');

      // Validate advance ID before database operation
      if (advance.id.isEmpty) {
        AppLogger.error('❌ Advance ID is empty');
        throw Exception('معرف السلفة مطلوب');
      }



      // Validate UUID format
      if (!UuidValidator.isValidUuid(advance.id)) {
        AppLogger.error('❌ Invalid advance ID UUID format: ${advance.id}');
        throw Exception('معرف السلفة غير صحيح');
      }

      // Validate client_id if not empty
      if (advance.clientId.isNotEmpty && !UuidValidator.isValidUuid(advance.clientId)) {
        AppLogger.error('❌ Invalid client ID UUID format: ${advance.clientId}');
        throw Exception('معرف العميل غير صحيح');
      }

      // Validate created_by UUID
      if (!UuidValidator.isValidUuid(advance.createdBy)) {
        AppLogger.error('❌ Invalid created_by UUID format: ${advance.createdBy}');
        throw Exception('معرف منشئ السلفة غير صحيح');
      }

      // Validate approved_by UUID if not null/empty
      if (advance.approvedBy != null && advance.approvedBy!.isNotEmpty &&
          !UuidValidator.isValidUuid(advance.approvedBy!)) {
        AppLogger.error('❌ Invalid approved_by UUID format: ${advance.approvedBy}');
        throw Exception('معرف معتمد السلفة غير صحيح');
      }

      final updateData = advance.toDatabase();
      // Remove id from update data as it's used in the where clause
      updateData.remove('id');

      await _advancesTable
          .update(updateData)
          .eq('id', advance.id);

      // Clear cache to force refresh
      clearCache();

      AppLogger.info('✅ Updated advance: ${advance.id}');
      return true;
    } catch (e) {
      AppLogger.error('❌ Error updating advance: $e');
      return false;
    }
  }

  /// تحديث مبلغ السلفة
  Future<AdvanceModel> updateAdvanceAmount(String advanceId, double newAmount) async {
    try {
      AppLogger.info('🔄 Updating advance amount: $advanceId to $newAmount');

      final updateData = {
        'amount': newAmount,
      };

      final response = await _advancesTable
          .update(updateData)
          .eq('id', advanceId)
          .select()
          .single();

      // الحصول على اسم العميل
      final clientId = response['client_id'] as String?;
      String clientName = 'عميل غير معروف';

      if (clientId != null && clientId.isNotEmpty) {
        try {
          final clientProfile = await _userProfilesTable
              .select('name')
              .eq('id', clientId)
              .single();
          clientName = (clientProfile['name'] as String?) ?? 'عميل غير معروف';
        } catch (e) {
          AppLogger.warning('Could not fetch client name for advance: $advanceId');
        }
      }

      final advanceData = Map<String, dynamic>.from(response);
      advanceData['client_name'] = clientName;

      final advance = AdvanceModel.fromDatabase(advanceData);
      AppLogger.info('✅ Updated advance amount: $advanceId');
      return advance;
    } catch (e) {
      AppLogger.error('❌ Error updating advance amount: $e');
      throw Exception('فشل في تحديث مبلغ السلفة: $e');
    }
  }

  /// حذف سلفة
  Future<bool> deleteAdvance(String advanceId) async {
    try {
      AppLogger.info('🔄 Deleting advance: $advanceId');

      await _advancesTable
          .delete()
          .eq('id', advanceId);

      // Clear cache to force refresh
      clearCache();

      AppLogger.info('✅ Deleted advance: $advanceId');
      return true;
    } catch (e) {
      AppLogger.error('❌ Error deleting advance: $e');
      return false;
    }
  }

  /// الحصول على إحصائيات السلف
  Future<AdvanceStatistics> getAdvanceStatistics() async {
    try {
      AppLogger.info('🔄 Fetching advance statistics');

      final advances = await getAllAdvances();
      final statistics = AdvanceStatistics.fromAdvances(advances);

      AppLogger.info('✅ Fetched advance statistics');
      return statistics;
    } catch (e) {
      AppLogger.error('❌ Error fetching advance statistics: $e');
      throw Exception('فشل في جلب إحصائيات السلف: $e');
    }
  }

  /// الحصول على العملاء المتاحين للسلف
  Future<List<UserModel>> getAvailableClients() async {
    try {
      AppLogger.info('🔄 Fetching available clients for advances');

      final response = await _userProfilesTable
          .select('*')
          .or('role.eq.client,role.eq.عميل') // Support both English and Arabic role names
          .or('status.eq.approved,status.eq.active') // Support both status values
          .order('name');

      final clients = (response as List).map((data) {
        return UserModel.fromMap((data as Map<String, dynamic>?) ?? {});
      }).toList();

      AppLogger.info('✅ Fetched ${clients.length} available clients');
      return clients;
    } catch (e) {
      AppLogger.error('❌ Error fetching available clients: $e');
      throw Exception('فشل في جلب العملاء المتاحين: $e');
    }
  }
}
