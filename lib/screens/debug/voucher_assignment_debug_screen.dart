import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/voucher_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../services/voucher_service.dart';
import '../../models/client_voucher_model.dart';
import '../../utils/app_logger.dart';

/// Debug screen to diagnose voucher assignment issues
class VoucherAssignmentDebugScreen extends StatefulWidget {
  const VoucherAssignmentDebugScreen({super.key});

  @override
  State<VoucherAssignmentDebugScreen> createState() => _VoucherAssignmentDebugScreenState();
}

class _VoucherAssignmentDebugScreenState extends State<VoucherAssignmentDebugScreen> {
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic> _debugInfo = {};
  List<ClientVoucherModel> _allAssignments = [];
  List<ClientVoucherModel> _clientVouchers = [];
  String? _currentUserId;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _debugInfo = {};
    });

    try {
      AppLogger.info('🔍 Starting voucher assignment diagnostics...');
      
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final voucherProvider = Provider.of<VoucherProvider>(context, listen: false);
      final voucherService = VoucherService();

      // Get current user info
      final currentUser = supabaseProvider.user;
      _currentUserId = currentUser?.id;
      _currentUserRole = currentUser?.role.value;

      _debugInfo['current_user_id'] = _currentUserId;
      _debugInfo['current_user_role'] = _currentUserRole;
      _debugInfo['current_user_email'] = currentUser?.email;
      _debugInfo['current_user_name'] = currentUser?.name;

      AppLogger.info('👤 Current User: ${currentUser?.email} (${currentUser?.role.value})');

      if (_currentUserId != null) {
        // Test 1: Check direct database query for client vouchers
        AppLogger.info('🔍 Test 1: Direct database query for client vouchers...');
        try {
          _clientVouchers = await voucherService.getClientVouchers(_currentUserId!);
          _debugInfo['direct_client_vouchers_count'] = _clientVouchers.length;
          _debugInfo['direct_client_vouchers'] = _clientVouchers.map((cv) => {
            'id': cv.id,
            'voucher_id': cv.voucherId,
            'client_id': cv.clientId,
            'status': cv.status.value,
            'voucher_code': cv.voucher?.code ?? 'NULL',
            'voucher_name': cv.voucher?.name ?? 'NULL',
            'assigned_at': cv.assignedAt.toIso8601String(),
          }).toList();
        } catch (e) {
          _debugInfo['direct_query_error'] = e.toString();
          AppLogger.error('❌ Direct query failed: $e');
        }

        // Test 2: Check provider-based voucher loading
        AppLogger.info('🔍 Test 2: Provider-based voucher loading...');
        try {
          await voucherProvider.loadClientVouchers(_currentUserId!);
          final providerVouchers = voucherProvider.clientVouchers;
          _debugInfo['provider_client_vouchers_count'] = providerVouchers.length;
          _debugInfo['provider_client_vouchers'] = providerVouchers.map((cv) => {
            'id': cv.id,
            'voucher_id': cv.voucherId,
            'client_id': cv.clientId,
            'status': cv.status.value,
            'voucher_code': cv.voucher?.code ?? 'NULL',
            'voucher_name': cv.voucher?.name ?? 'NULL',
          }).toList();
        } catch (e) {
          _debugInfo['provider_query_error'] = e.toString();
          AppLogger.error('❌ Provider query failed: $e');
        }
      }

      // Test 3: Check all voucher assignments (admin view)
      AppLogger.info('🔍 Test 3: All voucher assignments...');
      try {
        await voucherProvider.loadAllClientVouchers();
        _allAssignments = voucherProvider.allClientVouchers;
        _debugInfo['total_assignments_count'] = _allAssignments.length;
        
        // Filter assignments for current user
        final userAssignments = _allAssignments.where((cv) => cv.clientId == _currentUserId).toList();
        _debugInfo['user_assignments_in_all'] = userAssignments.length;
        _debugInfo['user_assignments_details'] = userAssignments.map((cv) => {
          'id': cv.id,
          'voucher_id': cv.voucherId,
          'client_id': cv.clientId,
          'status': cv.status.value,
          'voucher_code': cv.voucher?.code ?? 'NULL',
          'assigned_by': cv.assignedBy,
          'assigned_at': cv.assignedAt.toIso8601String(),
        }).toList();
      } catch (e) {
        _debugInfo['all_assignments_error'] = e.toString();
        AppLogger.error('❌ All assignments query failed: $e');
      }

      // Test 4: Check RLS policies by testing raw Supabase query
      AppLogger.info('🔍 Test 4: Testing RLS policies...');
      await _testRLSPolicies();

      // Test 5: Check user profile and authentication
      AppLogger.info('🔍 Test 5: User profile verification...');
      await _verifyUserProfile();

      // Test 6: Database integrity check
      AppLogger.info('🔍 Test 6: Database integrity check...');
      await _testDatabaseIntegrity();

      AppLogger.info('✅ Diagnostics completed');
      
    } catch (e) {
      _error = e.toString();
      AppLogger.error('❌ Diagnostics failed: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testRLSPolicies() async {
    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final supabase = supabaseProvider.client;

      // Test direct Supabase query
      final response = await supabase
          .from('client_vouchers')
          .select('''
            *,
            vouchers (*)
          ''')
          .eq('client_id', _currentUserId!);

      _debugInfo['rls_test_count'] = response.length;
      _debugInfo['rls_test_data'] = response;

      // Analyze voucher data integrity
      int nullVoucherCount = 0;
      int validVoucherCount = 0;
      final missingVoucherIds = <String>[];
      final voucherIntegrityDetails = <Map<String, dynamic>>[];

      for (final item in response) {
        final voucherId = item['voucher_id']?.toString() ?? '';
        final voucherData = item['vouchers'];

        if (voucherData == null) {
          nullVoucherCount++;
          missingVoucherIds.add(voucherId);
          voucherIntegrityDetails.add({
            'client_voucher_id': item['id'],
            'voucher_id': voucherId,
            'status': item['status'],
            'issue': 'NULL_VOUCHER_DATA',
          });
        } else {
          validVoucherCount++;
          voucherIntegrityDetails.add({
            'client_voucher_id': item['id'],
            'voucher_id': voucherId,
            'voucher_code': voucherData['code'],
            'voucher_name': voucherData['name'],
            'status': item['status'],
            'issue': 'NONE',
          });
        }
      }

      _debugInfo['voucher_integrity'] = {
        'total_assignments': response.length,
        'null_voucher_count': nullVoucherCount,
        'valid_voucher_count': validVoucherCount,
        'missing_voucher_ids': missingVoucherIds,
        'integrity_details': voucherIntegrityDetails,
      };

      AppLogger.info('🔒 RLS Test: Found ${response.length} vouchers');
      AppLogger.info('📊 Voucher Integrity: $validVoucherCount valid, $nullVoucherCount with NULL data');

      if (nullVoucherCount > 0) {
        AppLogger.warning('🚨 CRITICAL: Found $nullVoucherCount assignments with NULL voucher data!');
        AppLogger.warning('Missing voucher IDs: ${missingVoucherIds.join(', ')}');
      }

    } catch (e) {
      _debugInfo['rls_test_error'] = e.toString();
      AppLogger.error('❌ RLS test failed: $e');
    }
  }

  Future<void> _verifyUserProfile() async {
    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final supabase = supabaseProvider.client;

      // Check user profile
      final profileResponse = await supabase
          .from('user_profiles')
          .select('*')
          .eq('id', _currentUserId!)
          .maybeSingle();

      _debugInfo['user_profile'] = profileResponse;

      // Check auth user
      final authUser = supabase.auth.currentUser;
      _debugInfo['auth_user_id'] = authUser?.id;
      _debugInfo['auth_user_email'] = authUser?.email;

      AppLogger.info('👤 User Profile: ${profileResponse?['email']} (${profileResponse?['role']})');
      AppLogger.info('🔐 Auth User: ${authUser?.email}');

    } catch (e) {
      _debugInfo['user_verification_error'] = e.toString();
      AppLogger.error('❌ User verification failed: $e');
    }
  }

  Future<void> _testDatabaseIntegrity() async {
    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final supabase = supabaseProvider.client;

      AppLogger.info('🔍 Testing database integrity...');

      // Get all vouchers in the system
      final vouchersResponse = await supabase
          .from('vouchers')
          .select('id, code, name, is_active')
          .order('created_at', ascending: false);

      final vouchers = vouchersResponse as List? ?? [];
      final existingVoucherIds = vouchers.map((v) => v['id'].toString()).toSet();

      _debugInfo['database_integrity'] = {
        'total_vouchers': vouchers.length,
        'existing_voucher_ids': existingVoucherIds.toList(),
        'voucher_details': vouchers,
      };

      AppLogger.info('📊 Found ${vouchers.length} vouchers in vouchers table');

      // Test specific voucher IDs that are causing issues
      final problematicVoucherIds = [
        '9042cf49-a903-47d8-a61a-3a600aee5b9d',
        'cab36f65-f1c6-4aa0-bfd1-7f51eef742c7',
      ];

      final voucherExistenceTest = <String, bool>{};
      for (final voucherId in problematicVoucherIds) {
        final exists = existingVoucherIds.contains(voucherId);
        voucherExistenceTest[voucherId] = exists;
        AppLogger.info('🔍 Voucher $voucherId: ${exists ? 'EXISTS' : 'MISSING'}');
      }

      _debugInfo['voucher_existence_test'] = voucherExistenceTest;

      // Test manual JOIN to isolate the issue
      if (_currentUserId != null) {
        final manualJoinTest = await _testManualJoin(supabase, _currentUserId!);
        _debugInfo['manual_join_test'] = manualJoinTest;
      }

    } catch (e) {
      _debugInfo['database_integrity_error'] = e.toString();
      AppLogger.error('❌ Database integrity test failed: $e');
    }
  }

  Future<Map<String, dynamic>> _testManualJoin(SupabaseClient supabase, String clientId) async {
    try {
      // Step 1: Get client vouchers without JOIN
      final clientVouchersResponse = await supabase
          .from('client_vouchers')
          .select('id, voucher_id, client_id, status, assigned_at')
          .eq('client_id', clientId);

      final clientVouchers = clientVouchersResponse as List? ?? [];

      // Step 2: Extract voucher IDs
      final voucherIds = clientVouchers
          .map((cv) => cv['voucher_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .toList();

      // Step 3: Get vouchers separately
      final vouchersResponse = await supabase
          .from('vouchers')
          .select('id, code, name, is_active')
          .inFilter('id', voucherIds);

      final vouchers = vouchersResponse as List? ?? [];
      final foundVoucherIds = vouchers.map((v) => v['id'].toString()).toSet();

      // Step 4: Identify missing vouchers
      final missingVoucherIds = voucherIds.where((id) => !foundVoucherIds.contains(id)).toList();

      final result = {
        'client_vouchers_found': clientVouchers.length,
        'voucher_ids_requested': voucherIds,
        'vouchers_found': vouchers.length,
        'missing_voucher_ids': missingVoucherIds,
        'client_voucher_details': clientVouchers,
        'voucher_details': vouchers,
      };

      AppLogger.info('🔍 Manual JOIN test results:');
      AppLogger.info('   - Client vouchers: ${clientVouchers.length}');
      AppLogger.info('   - Voucher IDs requested: ${voucherIds.length}');
      AppLogger.info('   - Vouchers found: ${vouchers.length}');
      AppLogger.info('   - Missing vouchers: ${missingVoucherIds.length}');

      if (missingVoucherIds.isNotEmpty) {
        AppLogger.error('🚨 MISSING VOUCHERS: ${missingVoucherIds.join(', ')}');
      }

      return result;
    } catch (e) {
      AppLogger.error('❌ Manual JOIN test failed: $e');
      return {'error': e.toString()};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('تشخيص تعيين القسائم'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runDiagnostics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.green),
            )
          : _error != null
              ? _buildErrorWidget()
              : _buildDebugInfo(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text(
              'خطأ في التشخيص',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _runDiagnostics,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection('معلومات المستخدم الحالي', _buildUserInfo()),
          const SizedBox(height: 16),
          _buildSection('نتائج الاستعلامات', _buildQueryResults()),
          const SizedBox(height: 16),
          _buildSection('تحليل سلامة البيانات', _buildIntegrityAnalysis()),
          const SizedBox(height: 16),
          _buildSection('تفاصيل القسائم المعينة', _buildVoucherDetails()),
          const SizedBox(height: 16),
          _buildSection('البيانات الخام', _buildRawData()),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('معرف المستخدم', _currentUserId ?? 'غير متوفر'),
        _buildInfoRow('الدور', _currentUserRole ?? 'غير متوفر'),
        _buildInfoRow('البريد الإلكتروني', _debugInfo['current_user_email'] ?? 'غير متوفر'),
        _buildInfoRow('الاسم', _debugInfo['current_user_name'] ?? 'غير متوفر'),
      ],
    );
  }

  Widget _buildQueryResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('الاستعلام المباشر', '${_debugInfo['direct_client_vouchers_count'] ?? 0} قسيمة'),
        _buildInfoRow('استعلام المزود', '${_debugInfo['provider_client_vouchers_count'] ?? 0} قسيمة'),
        _buildInfoRow('إجمالي التعيينات', '${_debugInfo['total_assignments_count'] ?? 0} تعيين'),
        _buildInfoRow('تعيينات المستخدم في الكل', '${_debugInfo['user_assignments_in_all'] ?? 0} تعيين'),
        _buildInfoRow('اختبار RLS', '${_debugInfo['rls_test_count'] ?? 0} قسيمة'),
      ],
    );
  }

  Widget _buildIntegrityAnalysis() {
    final voucherIntegrity = _debugInfo['voucher_integrity'] as Map<String, dynamic>?;
    final databaseIntegrity = _debugInfo['database_integrity'] as Map<String, dynamic>?;
    final manualJoinTest = _debugInfo['manual_join_test'] as Map<String, dynamic>?;
    final voucherExistenceTest = _debugInfo['voucher_existence_test'] as Map<String, bool>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Voucher Integrity Summary
        if (voucherIntegrity != null) ...[
          const Text(
            'تحليل سلامة القسائم:',
            style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildInfoRow('إجمالي التعيينات', '${voucherIntegrity['total_assignments'] ?? 0}'),
          _buildInfoRow('قسائم صحيحة', '${voucherIntegrity['valid_voucher_count'] ?? 0}'),
          _buildInfoRow('قسائم بيانات فارغة', '${voucherIntegrity['null_voucher_count'] ?? 0}'),

          if ((voucherIntegrity['null_voucher_count'] ?? 0) > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🚨 مشكلة حرجة: قسائم بيانات فارغة',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'معرفات القسائم المفقودة: ${(voucherIntegrity['missing_voucher_ids'] as List?)?.join(', ') ?? 'غير متوفر'}',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],

        // Database Integrity
        if (databaseIntegrity != null) ...[
          const Text(
            'سلامة قاعدة البيانات:',
            style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildInfoRow('إجمالي القسائم في النظام', '${databaseIntegrity['total_vouchers'] ?? 0}'),
          const SizedBox(height: 16),
        ],

        // Voucher Existence Test
        if (voucherExistenceTest != null) ...[
          const Text(
            'اختبار وجود القسائم المشكوك فيها:',
            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...voucherExistenceTest.entries.map((entry) =>
            _buildInfoRow(
              '${entry.key.substring(0, 8)}...',
              entry.value ? '✅ موجود' : '❌ مفقود',
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Manual Join Test Results
        if (manualJoinTest != null && manualJoinTest['error'] == null) ...[
          const Text(
            'نتائج الاختبار اليدوي:',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildInfoRow('تعيينات العميل', '${manualJoinTest['client_vouchers_found'] ?? 0}'),
          _buildInfoRow('قسائم مطلوبة', '${(manualJoinTest['voucher_ids_requested'] as List?)?.length ?? 0}'),
          _buildInfoRow('قسائم موجودة', '${manualJoinTest['vouchers_found'] ?? 0}'),
          _buildInfoRow('قسائم مفقودة', '${(manualJoinTest['missing_voucher_ids'] as List?)?.length ?? 0}'),

          if ((manualJoinTest['missing_voucher_ids'] as List?)?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚠️ قسائم مفقودة من قاعدة البيانات',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'المعرفات: ${(manualJoinTest['missing_voucher_ids'] as List).join(', ')}',
                    style: const TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildVoucherDetails() {
    if (_clientVouchers.isEmpty) {
      return const Text(
        'لا توجد قسائم للعرض',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Column(
      children: _clientVouchers.map((voucher) => Card(
        color: Colors.grey[800],
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('كود القسيمة', voucher.voucher?.code ?? 'NULL'),
              _buildInfoRow('اسم القسيمة', voucher.voucher?.name ?? 'NULL'),
              _buildInfoRow('الحالة', voucher.status.value),
              _buildInfoRow('تاريخ التعيين', voucher.formattedAssignedDate),
            ],
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildRawData() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          _debugInfo.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
