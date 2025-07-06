import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/models/user_role.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/config/routes.dart';

/// Complete Warehouse Manager Creation and Testing Script
/// This script creates warehouse manager accounts and tests the authentication flow
class WarehouseManagerSetupScript {
  
  /// Create the primary warehouse manager account
  static Future<bool> createPrimaryWarehouseManager(SupabaseProvider supabaseProvider) async {
    try {
      AppLogger.info('🏭 Creating primary warehouse manager account...');
      
      final success = await supabaseProvider.createUser(
        email: 'warehouse@samastore.com',
        name: 'مدير المخزن الرئيسي',
        phone: '+966501234567',
        role: UserRole.warehouseManager,
      );
      
      if (success) {
        AppLogger.info('✅ Primary warehouse manager created successfully!');
        
        // Approve the user immediately
        await _approveWarehouseManager(supabaseProvider, 'warehouse@samastore.com');
        
        return true;
      } else {
        AppLogger.error('❌ Failed to create primary warehouse manager');
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ Error creating primary warehouse manager: $e');
      return false;
    }
  }
  
  /// Create multiple warehouse manager accounts for testing
  static Future<void> createAllWarehouseManagers(SupabaseProvider supabaseProvider) async {
    final managers = [
      {
        'email': 'warehouse@samastore.com',
        'name': 'مدير المخزن الرئيسي',
        'phone': '+966501234567',
        'location': 'الرياض - حي الملك فهد',
      },
      {
        'email': 'warehouse1@samastore.com', 
        'name': 'مدير المخزن الفرعي الأول',
        'phone': '+966501234568',
        'location': 'جدة - حي الروضة',
      },
      {
        'email': 'warehouse2@samastore.com',
        'name': 'مدير مخزن الطوارئ',
        'phone': '+966501234569',
        'location': 'الدمام - حي الفيصلية',
      },
    ];
    
    AppLogger.info('🏭 Creating ${managers.length} warehouse manager accounts...');
    
    for (final manager in managers) {
      try {
        final success = await supabaseProvider.createUser(
          email: manager['email']!,
          name: manager['name']!,
          phone: manager['phone']!,
          role: UserRole.warehouseManager,
        );
        
        if (success) {
          AppLogger.info('✅ Created: ${manager['email']} - ${manager['name']}');
          
          // Approve each user
          await _approveWarehouseManager(supabaseProvider, manager['email']!);
        } else {
          AppLogger.error('❌ Failed to create: ${manager['email']}');
        }
        
        // Small delay between creations
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        AppLogger.error('❌ Error creating ${manager['email']}: $e');
      }
    }
    
    AppLogger.info('🎉 Warehouse manager creation process completed!');
  }
  
  /// Approve warehouse manager account
  static Future<void> _approveWarehouseManager(SupabaseProvider supabaseProvider, String email) async {
    try {
      // Refresh users list
      await supabaseProvider.fetchAllUsers();
      final users = supabaseProvider.allUsers;
      
      final warehouseManager = users.firstWhere(
        (user) => user.email == email,
        orElse: () => throw Exception('Warehouse manager not found: $email'),
      );
      
      // Approve the user
      await supabaseProvider.approveUserAndSetRole(
        userId: warehouseManager.id,
        roleStr: 'warehouseManager',
      );
      
      AppLogger.info('✅ Approved warehouse manager: $email');
    } catch (e) {
      AppLogger.error('❌ Error approving warehouse manager $email: $e');
    }
  }
  
  /// Test warehouse manager authentication
  static Future<bool> testWarehouseManagerAuth(SupabaseProvider supabaseProvider) async {
    try {
      AppLogger.info('🧪 Testing warehouse manager authentication...');
      
      // Test login with warehouse manager credentials
      final success = await supabaseProvider.signIn(
        email: 'warehouse@samastore.com',
        password: 'temp123',
      );
      
      if (success) {
        final user = supabaseProvider.user;
        if (user != null && user.role == UserRole.warehouseManager) {
          AppLogger.info('✅ Warehouse manager authentication successful!');
          AppLogger.info('👤 User: ${user.name}');
          AppLogger.info('📧 Email: ${user.email}');
          AppLogger.info('🏷️ Role: ${user.role.displayName}');
          AppLogger.info('✅ Status: ${user.status}');
          
          // Test route resolution
          final dashboardRoute = AppRoutes.getDashboardRouteForRole(user.role.value);
          AppLogger.info('🔗 Dashboard route: $dashboardRoute');
          
          return true;
        } else {
          AppLogger.error('❌ User role mismatch or user not found');
          return false;
        }
      } else {
        AppLogger.error('❌ Authentication failed');
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ Error testing authentication: $e');
      return false;
    }
  }
  
  /// Get warehouse manager credentials for testing
  static Map<String, String> getTestCredentials() {
    return {
      'email': 'warehouse@samastore.com',
      'password': 'temp123',
      'role': 'warehouseManager',
      'name': 'مدير المخزن الرئيسي',
      'phone': '+966501234567',
    };
  }
  
  /// Print setup instructions
  static void printSetupInstructions() {
    AppLogger.info('📋 WAREHOUSE MANAGER SETUP INSTRUCTIONS:');
    AppLogger.info('');
    AppLogger.info('1. Run the SQL script: sql/warehouse_manager_setup.sql in Supabase');
    AppLogger.info('2. Create auth users in Supabase Auth with these emails:');
    AppLogger.info('   - warehouse@samastore.com');
    AppLogger.info('   - warehouse1@samastore.com');
    AppLogger.info('   - warehouse2@samastore.com');
    AppLogger.info('3. Set password: temp123 for all accounts');
    AppLogger.info('4. Run this script to create user profiles');
    AppLogger.info('5. Test login with warehouse@samastore.com / temp123');
    AppLogger.info('');
    AppLogger.info('🔗 Expected dashboard route: /warehouse-manager/dashboard');
    AppLogger.info('🎯 Expected role: warehouseManager');
    AppLogger.info('✅ Expected status: approved');
  }
}

/// Widget for complete warehouse manager setup
class CompleteWarehouseManagerSetupWidget extends StatefulWidget {
  const CompleteWarehouseManagerSetupWidget({super.key});

  @override
  State<CompleteWarehouseManagerSetupWidget> createState() => _CompleteWarehouseManagerSetupWidgetState();
}

class _CompleteWarehouseManagerSetupWidgetState extends State<CompleteWarehouseManagerSetupWidget> {
  bool _isCreating = false;
  bool _isTesting = false;
  String _status = '';
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    WarehouseManagerSetupScript.printSetupInstructions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إعداد مدير المخزن الكامل',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: const Color(0xFF1E293B),
      ),
      backgroundColor: const Color(0xFF0F172A),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions Card
            _buildInstructionsCard(),
            
            const SizedBox(height: 24),
            
            // Credentials Card
            _buildCredentialsCard(),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            _buildActionButtons(),
            
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildStatusCard(),
            ],
            
            if (_logs.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildLogsCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تعليمات الإعداد',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 16),
            _buildInstructionStep('1', 'تشغيل سكريبت SQL في Supabase'),
            _buildInstructionStep('2', 'إنشاء مستخدمين في Supabase Auth'),
            _buildInstructionStep('3', 'تعيين كلمة المرور: temp123'),
            _buildInstructionStep('4', 'تشغيل هذا السكريبت'),
            _buildInstructionStep('5', 'اختبار تسجيل الدخول'),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialsCard() {
    final credentials = WarehouseManagerSetupScript.getTestCredentials();
    
    return Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'بيانات الاختبار',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 16),
            ...credentials.entries.map((entry) => 
              _buildCredentialRow(entry.key, entry.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$key:',
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Cairo',
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _isCreating ? null : _createWarehouseManagers,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isCreating
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'جاري الإنشاء...',
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'Cairo',
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              : const Text(
                  'إنشاء حسابات مديري المخازن',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                    color: Colors.white,
                  ),
                ),
        ),
        
        const SizedBox(height: 12),
        
        ElevatedButton(
          onPressed: _isTesting ? null : _testAuthentication,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isTesting
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'جاري الاختبار...',
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'Cairo',
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              : const Text(
                  'اختبار تسجيل الدخول',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                    color: Colors.white,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return Card(
      color: _status.contains('✅') 
          ? const Color(0xFF10B981).withOpacity(0.2)
          : const Color(0xFFEF4444).withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _status,
          style: TextStyle(
            color: _status.contains('✅') 
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444),
            fontFamily: 'Cairo',
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildLogsCard() {
    return Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سجل العمليات',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _logs.map((log) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      log,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createWarehouseManagers() async {
    setState(() {
      _isCreating = true;
      _status = '';
      _logs.clear();
    });

    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      
      _addLog('بدء إنشاء حسابات مديري المخازن...');
      
      await WarehouseManagerSetupScript.createAllWarehouseManagers(supabaseProvider);
      
      _addLog('تم إنشاء جميع الحسابات بنجاح');
      
      setState(() {
        _status = '✅ تم إنشاء حسابات مديري المخازن بنجاح!\n\nيمكنك الآن اختبار تسجيل الدخول.';
      });
    } catch (e) {
      _addLog('خطأ: $e');
      setState(() {
        _status = '❌ فشل في إنشاء الحسابات: $e';
      });
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  Future<void> _testAuthentication() async {
    setState(() {
      _isTesting = true;
      _status = '';
    });

    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      
      _addLog('بدء اختبار تسجيل الدخول...');
      
      final success = await WarehouseManagerSetupScript.testWarehouseManagerAuth(supabaseProvider);
      
      if (success) {
        _addLog('نجح اختبار تسجيل الدخول');
        setState(() {
          _status = '✅ نجح اختبار تسجيل الدخول!\n\nمدير المخزن جاهز للاستخدام.';
        });
      } else {
        _addLog('فشل اختبار تسجيل الدخول');
        setState(() {
          _status = '❌ فشل اختبار تسجيل الدخول. تحقق من إعداد المستخدم في Supabase.';
        });
      }
    } catch (e) {
      _addLog('خطأ في الاختبار: $e');
      setState(() {
        _status = '❌ خطأ في الاختبار: $e';
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
  }
}
