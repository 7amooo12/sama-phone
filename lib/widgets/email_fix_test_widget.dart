import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../utils/app_logger.dart';

/// Simple test widget to verify email confirmation fix
class EmailFixTestWidget extends StatefulWidget {
  const EmailFixTestWidget({super.key});

  @override
  State<EmailFixTestWidget> createState() => _EmailFixTestWidgetState();
}

class _EmailFixTestWidgetState extends State<EmailFixTestWidget> {
  final _supabaseService = SupabaseService();
  final _emailController = TextEditingController(text: 'tesz@sama.com');
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  String? _statusMessage;
  Color _statusColor = Colors.blue;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkUserStatus() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري فحص حالة المستخدم...';
      _statusColor = Colors.blue;
    });

    try {
      final email = _emailController.text.trim();
      final userProfile = await _supabaseService.getUserDataByEmail(email);
      
      if (userProfile == null) {
        setState(() {
          _statusMessage = 'المستخدم غير موجود: $email';
          _statusColor = Colors.red;
        });
        return;
      }

      final statusText = '''
👤 الاسم: ${userProfile.name}
📧 البريد: ${userProfile.email}
🔑 الدور: ${userProfile.role}
✅ الحالة: ${userProfile.status}
📬 البريد مؤكد: ${userProfile.emailConfirmed ?? false}
📅 تاريخ التأكيد: ${userProfile.emailConfirmedAt ?? 'غير محدد'}
🆔 معرف المستخدم: ${userProfile.id}

${_shouldBeAbleToLogin(userProfile) ? '✅ يجب أن يتمكن من تسجيل الدخول' : '❌ قد لا يتمكن من تسجيل الدخول'}
      ''';

      setState(() {
        _statusMessage = statusText;
        _statusColor = _shouldBeAbleToLogin(userProfile) ? Colors.green : Colors.orange;
      });

    } catch (e) {
      setState(() {
        _statusMessage = 'خطأ في فحص المستخدم: $e';
        _statusColor = Colors.red;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _shouldBeAbleToLogin(dynamic userProfile) {
    return (userProfile.status == 'active' || userProfile.status == 'approved') 
           && userProfile.role != 'client';
  }

  Future<void> _testLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _statusMessage = 'يرجى إدخال البريد الإلكتروني وكلمة المرور';
        _statusColor = Colors.red;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري اختبار تسجيل الدخول...';
      _statusColor = Colors.blue;
    });

    try {
      final user = await _supabaseService.signIn(email, password);
      
      if (user != null) {
        setState(() {
          _statusMessage = '''
🎉 نجح تسجيل الدخول!
👤 معرف المستخدم: ${user.id}
📧 البريد: ${user.email}
✅ البريد مؤكد في: ${user.emailConfirmedAt ?? 'غير محدد'}
🔑 بيانات المستخدم: ${user.userMetadata}
          ''';
          _statusColor = Colors.green;
        });
        
        // Sign out after test
        await _supabaseService.signOut();
        AppLogger.info('تم تسجيل الخروج بعد الاختبار');
        
      } else {
        setState(() {
          _statusMessage = '❌ فشل تسجيل الدخول - لم يتم إرجاع مستخدم';
          _statusColor = Colors.red;
        });
      }
      
    } catch (e) {
      String errorMessage = '❌ خطأ في تسجيل الدخول: $e';
      
      if (e.toString().contains('Email not confirmed')) {
        errorMessage += '\n\n🚨 لا يزال هناك خطأ في تأكيد البريد الإلكتروني!';
        errorMessage += '\n💡 هذا يعني أن الإصلاح لم يعمل بشكل صحيح';
      }
      
      setState(() {
        _statusMessage = errorMessage;
        _statusColor = Colors.red;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _applyFix() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري تطبيق الإصلاح...';
      _statusColor = Colors.blue;
    });

    try {
      final email = _emailController.text.trim();
      final success = await _supabaseService.manuallyConfirmUserEmail(email);
      
      if (success) {
        setState(() {
          _statusMessage = '✅ تم تطبيق الإصلاح بنجاح!\nيرجى فحص حالة المستخدم مرة أخرى.';
          _statusColor = Colors.green;
        });
      } else {
        setState(() {
          _statusMessage = '❌ فشل في تطبيق الإصلاح';
          _statusColor = Colors.red;
        });
      }
      
    } catch (e) {
      setState(() {
        _statusMessage = '❌ خطأ في تطبيق الإصلاح: $e';
        _statusColor = Colors.red;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'اختبار إصلاح تأكيد البريد الإلكتروني',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Email input
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 12),
            
            // Password input (for login test)
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور (للاختبار)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            
            // Action buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _checkUserStatus,
                  icon: const Icon(Icons.search),
                  label: const Text('فحص الحالة'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _applyFix,
                  icon: const Icon(Icons.build),
                  label: const Text('تطبيق الإصلاح'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _testLogin,
                  icon: const Icon(Icons.login),
                  label: const Text('اختبار تسجيل الدخول'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Status display
            if (_statusMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  border: Border.all(color: _statusColor.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoading)
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('جاري المعالجة...'),
                        ],
                      )
                    else
                      Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: _statusColor.withOpacity(0.8),
                          fontFamily: 'monospace',
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
