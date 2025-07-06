import 'package:flutter/material.dart';
import '../../utils/user_fix_utility.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../utils/login_test_utility.dart';
import '../../utils/emergency_fix.dart';
import '../../utils/auth_fix_utility.dart';

/// شاشة الإصلاح السريع للمستخدمين العالقين
class QuickFixScreen extends StatefulWidget {
  const QuickFixScreen({super.key});

  @override
  State<QuickFixScreen> createState() => _QuickFixScreenState();
}

class _QuickFixScreenState extends State<QuickFixScreen> {
  bool _isLoading = false;
  String _result = '';
  FixReport? _lastReport;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: const CustomAppBar(
        title: 'أدوات الإصلاح السريع',
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // معلومات المستخدم المحدد
            _buildSpecificUserCard(),
            const SizedBox(height: 16),

            // أدوات الإصلاح
            _buildFixToolsCard(),
            const SizedBox(height: 16),

            // الإصلاح الطارئ
            _buildEmergencyFixCard(),
            const SizedBox(height: 16),

            // النتائج
            if (_result.isNotEmpty) _buildResultCard(),
            if (_lastReport != null) _buildReportCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecificUserCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_pin, color: Colors.blue[600]),
                const SizedBox(width: 8),
                const Text(
                  'المستخدم المحدد',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('معرف المستخدم: 6a9eb412-d07a-4c65-ae26-2f9d5a4b63af'),
                  SizedBox(height: 4),
                  Text('تاريخ الإنشاء: 1 يونيو 2025'),
                  SizedBox(height: 4),
                  Text('المشكلة: موافق عليه من الأدمن لكن البريد غير مؤكد'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _fixSpecificUser,
                icon: const Icon(Icons.build_circle),
                label: const Text('إصلاح هذا المستخدم'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixToolsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build, color: Colors.orange[600]),
                const SizedBox(width: 8),
                const Text(
                  'أدوات الإصلاح',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // إصلاح جميع المستخدمين العالقين
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _fixAllStuckUsers,
                icon: const Icon(Icons.group),
                label: const Text('إصلاح جميع المستخدمين العالقين'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // فحص شامل
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _runComprehensiveCheck,
                icon: const Icon(Icons.analytics),
                label: const Text('فحص شامل وتقرير'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // إضافة عمود email_confirmed
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _ensureEmailConfirmedColumn,
                icon: const Icon(Icons.table_chart),
                label: const Text('التأكد من وجود عمود email_confirmed'),
              ),
            ),
            const SizedBox(height: 12),

            // اختبار تسجيل الدخول
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _testLoginFlow,
                icon: const Icon(Icons.login),
                label: const Text('اختبار تدفق تسجيل الدخول'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.indigo,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyFixCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emergency, color: Colors.red[600]),
                const SizedBox(width: 8),
                const Text(
                  'الإصلاح الطارئ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'للمستخدم testo@sama.com والمستخدمين العالقين',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            // إصلاح المستخدم المحدد
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _emergencyFixSpecificUser,
                icon: const Icon(Icons.person_pin),
                label: const Text('إصلاح testo@sama.com'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // إصلاح شامل
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _emergencyFixAll,
                icon: const Icon(Icons.healing),
                label: const Text('إصلاح شامل طارئ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // إصلاح المصادقة المتقدم
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _advancedAuthFix,
                icon: const Icon(Icons.security),
                label: const Text('إصلاح المصادقة المتقدم'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // اختبار تسجيل الدخول
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _testEmergencyLogin,
                icon: const Icon(Icons.login),
                label: const Text('اختبار تسجيل دخول testo@sama.com'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.green[600]),
                const SizedBox(width: 8),
                const Text(
                  'النتيجة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Text(
                _result,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assessment, color: Colors.indigo[600]),
                const SizedBox(width: 8),
                const Text(
                  'التقرير الشامل',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo[200]!),
              ),
              child: Text(
                _lastReport.toString(),
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fixSpecificUser() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final success = await UserFixUtility.fixSpecificUser();
      setState(() {
        _result = success
            ? 'تم إصلاح المستخدم المحدد بنجاح ✅'
            : 'فشل في إصلاح المستخدم المحدد ❌';
      });
    } catch (e) {
      setState(() {
        _result = 'خطأ: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fixAllStuckUsers() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final fixedUsers = await UserFixUtility.fixAllStuckUsers();
      setState(() {
        _result = 'تم إصلاح ${fixedUsers.length} مستخدم:\n${fixedUsers.join('\n')}';
      });
    } catch (e) {
      setState(() {
        _result = 'خطأ: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _runComprehensiveCheck() async {
    setState(() {
      _isLoading = true;
      _result = '';
      _lastReport = null;
    });

    try {
      final report = await UserFixUtility.runComprehensiveCheck();
      setState(() {
        _lastReport = report;
        _result = 'تم إنجاز الفحص الشامل بنجاح';
      });
    } catch (e) {
      setState(() {
        _result = 'خطأ في الفحص الشامل: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _ensureEmailConfirmedColumn() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final added = await UserFixUtility.ensureEmailConfirmedColumn();
      setState(() {
        _result = added
            ? 'تم إضافة عمود email_confirmed بنجاح'
            : 'عمود email_confirmed موجود بالفعل';
      });
    } catch (e) {
      setState(() {
        _result = 'خطأ: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testLoginFlow() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final results = await LoginTestUtility.runComprehensiveTest();

      if (mounted) {
        LoginTestUtility.showTestResults(context, results);
      }

      setState(() {
        _result = 'تم إنجاز اختبار تدفق تسجيل الدخول';
      });
    } catch (e) {
      setState(() {
        _result = 'خطأ في اختبار تسجيل الدخول: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _emergencyFixSpecificUser() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final success = await EmergencyFix.fixSpecificUser();
      setState(() {
        _result = success
            ? '✅ تم إصلاح المستخدم testo@sama.com بنجاح'
            : '❌ فشل في إصلاح المستخدم testo@sama.com';
      });
    } catch (e) {
      setState(() {
        _result = 'خطأ في الإصلاح الطارئ: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _emergencyFixAll() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final result = await EmergencyFix.runComprehensiveFix();
      setState(() {
        _result = result.toString();
      });
    } catch (e) {
      setState(() {
        _result = 'خطأ في الإصلاح الشامل: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testEmergencyLogin() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final success = await EmergencyFix.testLogin('testo@sama.com', 'password123');
      setState(() {
        _result = success
            ? '✅ تسجيل الدخول نجح لـ testo@sama.com'
            : '❌ تسجيل الدخول فشل لـ testo@sama.com';
      });
    } catch (e) {
      setState(() {
        _result = 'خطأ في اختبار تسجيل الدخول: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _advancedAuthFix() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final result = await AuthFixUtility.comprehensiveUserFix('testo@sama.com');
      setState(() {
        _result = result.toString();
      });
    } catch (e) {
      setState(() {
        _result = 'خطأ في الإصلاح المتقدم: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
