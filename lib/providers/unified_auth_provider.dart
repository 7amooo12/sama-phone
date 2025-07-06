import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter/widgets.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:flutter/material.dart';

/// مزود موحد للمصادقة يدعم كل من Supabase و Firebase Auth
/// 
/// هذا المزود يجمع بين مزودي المصادقة المختلفة ويوفر واجهة موحدة للحصول على المستخدم الحالي
/// مما يسهل الانتقال من Firebase إلى Supabase بدون الحاجة لتعديل الكثير من الكود
class UnifiedAuthProvider extends ChangeNotifier {

  UnifiedAuthProvider({
    required this.supabaseProvider,
    required this.authProvider,
  }) {
    _init();
  }
  static UnifiedAuthProvider of(BuildContext context) {
    return Provider.of<UnifiedAuthProvider>(context, listen: false);
  }

  final SupabaseProvider supabaseProvider;
  final AuthProvider authProvider;
  bool _loading = true;

  // Race condition prevention
  bool _transitionInProgress = false;
  Completer<void>? _currentTransition;
  
  bool get loading => _loading;
  bool get isAuthenticated => supabaseProvider.isAuthenticated;
  
  /// الحصول على المستخدم الحالي من Supabase أو Firebase Auth
  UserModel? get user => supabaseProvider.user;
  
  /// الحصول على دور المستخدم الحالي
  String get userRole => user?.role.value ?? 'guest';
  
  Future<void> _init() async {
    try {
      _loading = true;
      notifyListeners();

      // Check if there's an existing session
      final session = supabaseProvider.client.auth.currentSession;
      if (session != null) {
        await supabaseProvider.refreshSession();
      }
    } catch (e) {
      debugPrint('Error initializing auth: $e');
      // Don't rethrow to avoid breaking the Provider tree
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
  
  /// Prevent overlapping auth transitions using mutex-style lock
  Future<T> _withTransitionLock<T>(Future<T> Function() operation) async {
    if (_transitionInProgress) {
      AppLogger.info('🔄 Auth transition in progress, waiting...');
      // Wait for current transition to complete
      await _currentTransition?.future;
    }

    _transitionInProgress = true;
    _currentTransition = Completer<void>();

    try {
      AppLogger.info('🔒 Starting auth transition with lock');
      final result = await operation();
      return result;
    } finally {
      _transitionInProgress = false;
      _currentTransition?.complete();
      _currentTransition = null;
      AppLogger.info('🔓 Auth transition lock released');
    }
  }

  /// تسجيل الخروج with race condition protection
  Future<void> signOut() async {
    return _withTransitionLock(() async {
      AppLogger.info('🔄 Starting signOut with transition lock');
      await supabaseProvider.signOut();
      notifyListeners();
      AppLogger.info('✅ SignOut completed');
    });
  }

  /// تسجيل الدخول with race condition protection
  Future<bool> signIn(String email, String password) async {
    return _withTransitionLock(() async {
      AppLogger.info('🔄 Starting signIn with transition lock');
      final result = await supabaseProvider.signIn(email, password);
      notifyListeners();
      AppLogger.info('✅ SignIn completed: $result');
      return result;
    });
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
  
  const UnifiedAuthWrapper({super.key, required this.child});
  final Widget child;
  
  @override
  Widget build(BuildContext context) {
    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      return Provider<UnifiedAuthProvider>(
        create: (_) => UnifiedAuthProvider(
          supabaseProvider: supabaseProvider,
          authProvider: authProvider,
        ),
        child: child,
      );
    } catch (e) {
      // Fallback widget with Directionality
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('خطأ في تحميل المصادقة'),
                const SizedBox(height: 8),
                Text('$e'),
              ],
            ),
          ),
        ),
      );
    }
  }
} 