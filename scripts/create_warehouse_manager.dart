import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/models/user_role.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Script to create a warehouse manager test account
/// Run this from your main app or create a separate test file
class CreateWarehouseManagerScript {
  
  /// Create warehouse manager account with predefined credentials
  static Future<bool> createWarehouseManager(SupabaseProvider supabaseProvider) async {
    try {
      AppLogger.info('🏭 Creating warehouse manager test account...');
      
      final success = await supabaseProvider.createUser(
        email: 'warehouse@samastore.com',
        name: 'مدير المخزن الرئيسي',
        phone: '+966501234567',
        role: UserRole.warehouseManager,
      );
      
      if (success) {
        AppLogger.info('✅ Warehouse manager account created successfully!');
        AppLogger.info('📧 Email: warehouse@samastore.com');
        AppLogger.info('🔑 Password: temp123');
        AppLogger.info('👤 Role: warehouseManager');
        AppLogger.info('📱 Phone: +966501234567');
        
        // Also approve the user immediately
        await _approveWarehouseManager(supabaseProvider);
        
        return true;
      } else {
        AppLogger.error('❌ Failed to create warehouse manager account');
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ Error creating warehouse manager: $e');
      return false;
    }
  }
  
  /// Approve the warehouse manager account
  static Future<void> _approveWarehouseManager(SupabaseProvider supabaseProvider) async {
    try {
      // Find the user by email
      await supabaseProvider.fetchAllUsers();
      final users = supabaseProvider.allUsers;
      final warehouseManager = users.firstWhere(
        (user) => user.email == 'warehouse@samastore.com',
        orElse: () => throw Exception('Warehouse manager not found'),
      );
      
      // Approve the user
      await supabaseProvider.approveUserAndSetRole(
        userId: warehouseManager.id,
        roleStr: 'warehouseManager',
      );
      
      AppLogger.info('✅ Warehouse manager account approved and activated');
    } catch (e) {
      AppLogger.error('❌ Error approving warehouse manager: $e');
    }
  }
  
  /// Create multiple test warehouse managers for different warehouses
  static Future<void> createMultipleWarehouseManagers(SupabaseProvider supabaseProvider) async {
    final managers = [
      {
        'email': 'warehouse1@samastore.com',
        'name': 'مدير المخزن الرئيسي',
        'phone': '+966501234567',
      },
      {
        'email': 'warehouse2@samastore.com', 
        'name': 'مدير المخزن الفرعي',
        'phone': '+966501234568',
      },
      {
        'email': 'warehouse3@samastore.com',
        'name': 'مدير مخزن الطوارئ',
        'phone': '+966501234569',
      },
    ];
    
    for (final manager in managers) {
      try {
        final success = await supabaseProvider.createUser(
          email: manager['email']!,
          name: manager['name']!,
          phone: manager['phone']!,
          role: UserRole.warehouseManager,
        );
        
        if (success) {
          AppLogger.info('✅ Created: ${manager['email']}');
        }
      } catch (e) {
        AppLogger.error('❌ Failed to create ${manager['email']}: $e');
      }
    }
  }
}

/// Widget to run the script from within the app
class WarehouseManagerCreatorWidget extends StatefulWidget {
  const WarehouseManagerCreatorWidget({super.key});

  @override
  State<WarehouseManagerCreatorWidget> createState() => _WarehouseManagerCreatorWidgetState();
}

class _WarehouseManagerCreatorWidgetState extends State<WarehouseManagerCreatorWidget> {
  bool _isCreating = false;
  String _status = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء حساب مدير المخزن'),
        backgroundColor: const Color(0xFF1E293B),
      ),
      backgroundColor: const Color(0xFF0F172A),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: const Color(0xFF1E293B),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إنشاء حساب مدير المخزن',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'سيتم إنشاء حساب بالبيانات التالية:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('البريد الإلكتروني:', 'warehouse@samastore.com'),
                    _buildInfoRow('كلمة المرور:', 'temp123'),
                    _buildInfoRow('الاسم:', 'مدير المخزن الرئيسي'),
                    _buildInfoRow('الدور:', 'مدير المخزن'),
                    _buildInfoRow('الهاتف:', '+966501234567'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            ElevatedButton(
              onPressed: _isCreating ? null : _createWarehouseManager,
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
                      'إنشاء حساب مدير المخزن',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                        color: Colors.white,
                      ),
                    ),
            ),
            
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
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
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
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

  Future<void> _createWarehouseManager() async {
    setState(() {
      _isCreating = true;
      _status = '';
    });

    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final success = await CreateWarehouseManagerScript.createWarehouseManager(supabaseProvider);
      
      setState(() {
        _status = success 
            ? '✅ تم إنشاء حساب مدير المخزن بنجاح!\n\nيمكنك الآن تسجيل الدخول باستخدام:\nالبريد: warehouse@samastore.com\nكلمة المرور: temp123'
            : '❌ فشل في إنشاء حساب مدير المخزن';
      });
    } catch (e) {
      setState(() {
        _status = '❌ خطأ: $e';
      });
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }
}
