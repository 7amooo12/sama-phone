import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/services/flask_api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// هذا الملف يوضح كيفية تسجيل الدخول كمحاسب والحصول على توكن JWT
/// استخدم هذا المثال كمرجع لتنفيذ شاشة تسجيل الدخول للمحاسبين

class AccountantLoginExample extends StatefulWidget {
  const AccountantLoginExample({Key? key}) : super(key: key);

  @override
  State<AccountantLoginExample> createState() => _AccountantLoginExampleState();
}

class _AccountantLoginExampleState extends State<AccountantLoginExample> {
  final FlaskApiService _apiService = FlaskApiService();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final storage = const FlutterSecureStorage();
  
  bool _isLoading = false;
  String _errorMessage = '';
  String _successMessage = '';
  String? _currentToken;
  
  @override
  void initState() {
    super.initState();
    // تحقق مما إذا كان المستخدم مسجل الدخول بالفعل
    _checkLoginStatus();
  }
  
  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  // التحقق من حالة تسجيل الدخول
  Future<void> _checkLoginStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });
    
    try {
      // تهيئة خدمة API
      await _apiService.init();
      
      setState(() {
        _isLoading = false;
        if (_apiService.isAuthenticated) {
          // قراءة التوكن من التخزين
          _checkCurrentToken();
          _successMessage = 'أنت مسجل الدخول بالفعل 🎉';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'حدث خطأ أثناء التحقق من حالة تسجيل الدخول: ${e.toString()}';
      });
    }
  }
  
  // قراءة التوكن الحالي من التخزين
  Future<void> _checkCurrentToken() async {
    try {
      final token = await storage.read(key: 'flask_api_token');
      setState(() {
        _currentToken = token;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ أثناء قراءة التوكن: ${e.toString()}';
      });
    }
  }
  
  // تسجيل الدخول
  Future<void> _login() async {
    // التحقق من صحة المدخلات
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'يرجى إدخال اسم المستخدم وكلمة المرور';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });
    
    try {
      // تسجيل الدخول باستخدام خدمة API
      final result = await _apiService.login(
        _usernameController.text,
        _passwordController.text,
      );
      
      setState(() {
        _isLoading = false;
        if (result.isAuthenticated) {
          _successMessage = 'تم تسجيل الدخول بنجاح 🎉';
          // قراءة التوكن من التخزين
          _checkCurrentToken();
        } else {
          _errorMessage = 'فشل تسجيل الدخول: ${result.error}';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'حدث خطأ أثناء تسجيل الدخول: ${e.toString()}';
      });
    }
  }
  
  // تسجيل الخروج
  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });
    
    try {
      // تسجيل الخروج باستخدام خدمة API
      await _apiService.logout();
      
      setState(() {
        _isLoading = false;
        _successMessage = 'تم تسجيل الخروج بنجاح';
        _currentToken = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'حدث خطأ أثناء تسجيل الخروج: ${e.toString()}';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مثال تسجيل دخول المحاسب'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16.0),
                      margin: const EdgeInsets.only(bottom: 16.0),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ),
                  
                  if (_successMessage.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16.0),
                      margin: const EdgeInsets.only(bottom: 16.0),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Text(
                        _successMessage,
                        style: TextStyle(color: Colors.green.shade900),
                      ),
                    ),
                  
                  // معلومات التوكن الحالي
                  if (_currentToken != null) ...[
                    const Text(
                      'معلومات التوكن الحالي:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'التوكن JWT:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentToken!,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'مدة صلاحية التوكن هي عادة 24 ساعة',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _logout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('تسجيل الخروج'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  if (_currentToken == null) ...[
                    const Text(
                      'تسجيل الدخول كمحاسب:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // نموذج تسجيل الدخول
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم المستخدم أو البريد الإلكتروني',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'تسجيل الدخول',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // بيانات اختبار
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'بيانات اختبار:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('اسم المستخدم: hima@sama.com'),
                          const Text('كلمة المرور: hima@123'),
                          const SizedBox(height: 8),
                          const Text(
                            'ملاحظة: استبدل هذه البيانات ببيانات حقيقية في بيئة الإنتاج',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // شرح كيفية استخدام التوكن
                  const Text(
                    'كيفية استخدام التوكن في الطلبات:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1. أضف التوكن في رأس HTTP:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Authorization: Bearer [YOUR_JWT_TOKEN]',
                          style: TextStyle(fontFamily: 'monospace'),
                        ),
                        SizedBox(height: 12),
                        Text(
                          '2. أضف مفتاح API في رأس HTTP:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'X-API-KEY: lux2025FlutterAccess',
                          style: TextStyle(fontFamily: 'monospace'),
                        ),
                        SizedBox(height: 12),
                        Text(
                          '3. استخدم الدوال المضمنة في FlaskApiService وInvoiceService للتعامل مع API',
                          style: TextStyle(fontWeight: FontWeight.bold),
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

/*
  كيفية استخدام هذا المثال في المشروع:
  
  1. قم بتضمين هذا الملف في المشروع (تم وضعه في مجلد examples)
  2. استخدم الدالة `_login()` لتسجيل الدخول والحصول على التوكن
  3. استخدم الدالة `_logout()` لتسجيل الخروج وإزالة التوكن
  4. استخدم الدالة `_checkLoginStatus()` للتحقق من حالة تسجيل الدخول
  
  في المشروع الحقيقي:
  
  ```dart
  // استخدام FlaskApiService
  final apiService = FlaskApiService();
  
  // تهيئة الخدمة عند بدء التطبيق
  await apiService.init();
  
  // التحقق مما إذا كان المستخدم مسجل الدخول
  if (apiService.isAuthenticated) {
    // المستخدم مسجل الدخول، انتقل إلى الشاشة الرئيسية
    Navigator.pushReplacementNamed(context, '/accountant/dashboard');
  } else {
    // المستخدم غير مسجل الدخول، انتقل إلى شاشة تسجيل الدخول
    Navigator.pushReplacementNamed(context, '/login');
  }
  ```
*/ 