import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter/widgets.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:flutter/material.dart';

/// مزود موحد للمصادقة يدعم كل من Supabase و Firebase Auth
/// 
/// هذا المزود يجمع بين مزودي المصادقة المختلفة ويوفر واجهة موحدة للحصول على المستخدم الحالي
/// مما يسهل الانتقال من Firebase إلى Supabase بدون الحاجة لتعديل الكثير من الكود
class UnifiedAuthProvider extends ChangeNotifier {
  static UnifiedAuthProvider of(BuildContext context) {
    return UnifiedAuthProvider(
      supabaseProvider: Provider.of<SupabaseProvider>(context),
      authProvider: Provider.of<AuthProvider>(context, listen: false),
    );
  }
  
  final SupabaseProvider supabaseProvider;
  final AuthProvider authProvider;
  bool _loading = true;
  
  UnifiedAuthProvider({
    required this.supabaseProvider,
    required this.authProvider,
  }) {
    _init();
  }
  
  bool get loading => _loading;
  bool get isAuthenticated => supabaseProvider.isAuthenticated;
  
  /// الحصول على المستخدم الحالي من Supabase أو Firebase Auth
  UserModel? get user => supabaseProvider.user;
  
  /// الحصول على دور المستخدم الحالي
  String get userRole => user?.role.value ?? 'guest';
  
  Future<void> _init() async {
    _loading = true;
    notifyListeners();

    try {
      // Check if there's an existing session
      final session = supabaseProvider.client?.auth.currentSession;
      if (session != null) {
        await supabaseProvider.refreshSession();
      }
    } catch (e) {
      debugPrint('Error initializing auth: $e');
    }

    _loading = false;
    notifyListeners();
  }
  
  /// تسجيل الخروج
  Future<void> signOut() async {
    await supabaseProvider.signOut();
    notifyListeners();
  }
}

/// إضافة امتداد للسياق للوصول بسهولة إلى الحالة المصادقة
extension UnifiedAuthContext on BuildContext {
  /// الحصول على المستخدم الحالي بسهولة
  UserModel? get currentUser {
    return UnifiedAuthProvider.of(this).user;
  }
  
  /// التحقق ما إذا كان المستخدم مسجل الدخول أم لا
  bool get isAuthenticated {
    return UnifiedAuthProvider.of(this).isAuthenticated;
  }
  
  /// الحصول على دور المستخدم الحالي
  String get userRole {
    return UnifiedAuthProvider.of(this).userRole;
  }
}

/// مكون لتفاف للمساعدة في إضافة UnifiedAuthProvider لشجرة الـ widgets
class UnifiedAuthWrapper extends StatelessWidget {
  final Widget child;
  
  const UnifiedAuthWrapper({Key? key, required this.child}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return ProxyProvider2<SupabaseProvider, AuthProvider, UnifiedAuthProvider>(
      update: (_, supabaseProvider, authProvider, __) => 
          UnifiedAuthProvider(
            supabaseProvider: supabaseProvider,
            authProvider: authProvider,
          ),
      child: child,
    );
  }
} 