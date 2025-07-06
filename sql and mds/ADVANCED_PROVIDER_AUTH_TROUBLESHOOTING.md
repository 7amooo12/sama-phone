# Advanced Provider & Auth Troubleshooting Guide

## Overview

This guide addresses advanced issues that may occur after implementing the basic Provider and Directionality fixes in the SmartBizTracker Flutter app. Use this alongside `FIX_PROVIDER_DIRECTIONALITY_EXCEPTIONS.md`.

---

## 🔄 Issue 1: Race Condition in Multiple Auth State Changes

### Scenario
When `signOut()` followed immediately by `signIn()` occurs within the same widget lifecycle, causing overlapping authentication state transitions.

### Problem Symptoms
```
Another exception was thrown: setState() called after dispose()
Another exception was thrown: Provider not found above this widget
Auth state inconsistency: user is null but isAuthenticated is true
```

### Root Cause
Multiple auth operations executing simultaneously without proper synchronization.

### Solution: Transition Lock Mechanism

**Enhanced UnifiedAuthProvider with Race Condition Protection:**

```dart
class UnifiedAuthProvider extends ChangeNotifier {
  bool _transitionInProgress = false;
  final Completer<void>? _currentTransition = null;
  
  // Prevent overlapping auth transitions
  Future<T> _withTransitionLock<T>(Future<T> Function() operation) async {
    if (_transitionInProgress) {
      // Wait for current transition to complete
      await _currentTransition?.future;
    }
    
    _transitionInProgress = true;
    final completer = Completer<void>();
    _currentTransition = completer;
    
    try {
      final result = await operation();
      return result;
    } finally {
      _transitionInProgress = false;
      completer.complete();
    }
  }
  
  @override
  Future<void> signOut() async {
    return _withTransitionLock(() async {
      AppLogger.info('🔄 Starting signOut with transition lock');
      await supabaseProvider.signOut();
      notifyListeners();
      AppLogger.info('✅ SignOut completed');
    });
  }
  
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
```

### Prevention Strategy
- Always use the transition lock for auth operations
- Add logging to track transition states
- Implement timeout mechanisms for stuck transitions

---

## 💾 Issue 2: Memory Leaks from Supabase Listeners

### Scenario
Using `.listen()` in `initState()` without corresponding `.cancel()` in `dispose()`, causing persistent listeners.

### Problem Symptoms
```
Memory usage continuously increasing
App becomes sluggish over time
Multiple duplicate auth state change events
```

### Root Cause
Supabase auth listeners not properly disposed when widgets are destroyed.

### Solution: Proper Listener Lifecycle Management

**Enhanced SupabaseProvider with Listener Management:**

```dart
class SupabaseProvider extends ChangeNotifier {
  StreamSubscription<AuthState>? _authSubscription;
  bool _disposed = false;
  
  void _initializeAuthListener() {
    // Cancel existing subscription first
    _authSubscription?.cancel();
    
    _authSubscription = _supabase.auth.onAuthStateChange.listen(
      (data) {
        if (_disposed) return; // Prevent operations on disposed provider
        
        AppLogger.info('🔄 Auth state changed: ${data.event}');
        _handleAuthStateChange(data.event, data.session);
      },
      onError: (error) {
        if (_disposed) return;
        AppLogger.error('❌ Auth listener error: $error');
      },
    );
  }
  
  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    _authSubscription = null;
    super.dispose();
  }
  
  // Safe notifyListeners that checks disposal state
  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}
```

**Widget-Level Listener Management:**

```dart
class AuthAwareWidget extends StatefulWidget {
  @override
  _AuthAwareWidgetState createState() => _AuthAwareWidgetState();
}

class _AuthAwareWidgetState extends State<AuthAwareWidget> {
  StreamSubscription<AuthState>? _authSubscription;
  
  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }
  
  void _setupAuthListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        if (mounted) { // Check if widget is still mounted
          setState(() {
            // Handle auth state change
          });
        }
      },
    );
  }
  
  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
```

### Prevention Strategy
- Always pair `.listen()` with `.cancel()` in dispose
- Use `mounted` checks before calling `setState()`
- Implement disposal flags in providers

---

## 🧭 Issue 3: Navigator Issues During Widget Rebuilds

### Scenario
Using `Navigator.pushReplacement()` directly during auth state transitions causing navigation errors.

### Problem Symptoms
```
Navigator operation requested with a context that does not include a Navigator
setState() called after dispose()
Multiple navigation calls causing route stack corruption
```

### Root Cause
Navigation calls happening during widget rebuilds or on disposed contexts.

### Solution: Safe Navigation with Context Validation

**Safe Navigation Helper:**

```dart
class SafeNavigator {
  static Future<void> pushReplacementSafely(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) async {
    // Wait for current frame to complete
    await WidgetsBinding.instance.endOfFrame;
    
    if (!context.mounted) {
      AppLogger.warning('⚠️ Context not mounted, skipping navigation');
      return;
    }
    
    try {
      Navigator.of(context).pushReplacementNamed(routeName, arguments: arguments);
    } catch (e) {
      AppLogger.error('❌ Navigation error: $e');
    }
  }
  
  static Future<void> pushSafely(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) async {
    await WidgetsBinding.instance.endOfFrame;
    
    if (!context.mounted) return;
    
    try {
      Navigator.of(context).pushNamed(routeName, arguments: arguments);
    } catch (e) {
      AppLogger.error('❌ Navigation error: $e');
    }
  }
}
```

**Enhanced AuthWrapper with Safe Navigation:**

```dart
class AuthWrapper extends StatefulWidget {
  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _navigationInProgress = false;
  
  void _navigateBasedOnAuthState(UserModel? user) {
    if (_navigationInProgress) return;
    
    _navigationInProgress = true;
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _navigationInProgress = false;
        return;
      }
      
      try {
        String dashboardRoute = _getDashboardRoute(user);
        await SafeNavigator.pushReplacementSafely(context, dashboardRoute);
      } finally {
        if (mounted) {
          _navigationInProgress = false;
        }
      }
    });
  }
  
  String _getDashboardRoute(UserModel? user) {
    if (user == null) return AppRoutes.menu;
    
    switch (user.role) {
      case UserRole.admin:
        return AppRoutes.adminDashboard;
      case UserRole.client:
        return AppRoutes.clientDashboard;
      default:
        return AppRoutes.menu;
    }
  }
}
```

### Prevention Strategy
- Use `addPostFrameCallback` for navigation during rebuilds
- Always check `mounted` before navigation
- Implement navigation locks to prevent multiple calls

---

## 🌐 Issue 4: GlobalContext vs LocalContext Errors

### Scenario
Calling `Provider.of(context)` in `initState()` or constructors before widget tree is established.

### Problem Symptoms
```
Provider not found above this widget
Bad state: No element
Context used after being disposed
```

### Root Cause
Accessing Provider before the widget tree context is fully established.

### Solution: Proper Context Timing

**Wrong Approach:**
```dart
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late SupabaseProvider supabaseProvider;
  
  @override
  void initState() {
    super.initState();
    // ❌ WRONG: Context not ready yet
    supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
  }
}
```

**Correct Approach:**
```dart
class _MyWidgetState extends State<MyWidget> {
  SupabaseProvider? _supabaseProvider;
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ CORRECT: Context is ready
    _supabaseProvider ??= Provider.of<SupabaseProvider>(context, listen: false);
  }
  
  @override
  Widget build(BuildContext context) {
    // ✅ CORRECT: Always safe in build method
    final supabaseProvider = Provider.of<SupabaseProvider>(context);
    
    return Consumer<SupabaseProvider>(
      builder: (context, provider, child) {
        // ✅ CORRECT: Consumer ensures proper context
        return YourWidget();
      },
    );
  }
}
```

**Safe Provider Access Helper:**
```dart
extension SafeProviderAccess on BuildContext {
  T? tryProvider<T>() {
    try {
      return Provider.of<T>(this, listen: false);
    } catch (e) {
      AppLogger.warning('⚠️ Provider<$T> not found: $e');
      return null;
    }
  }
  
  T? tryProviderWithListen<T>() {
    try {
      return Provider.of<T>(this, listen: true);
    } catch (e) {
      AppLogger.warning('⚠️ Provider<$T> not found: $e');
      return null;
    }
  }
}
```

### Prevention Strategy
- Use `didChangeDependencies()` instead of `initState()` for Provider access
- Prefer `Consumer` widgets over `Provider.of()`
- Implement safe Provider access helpers

---

## 🔍 Quick Reference Checklist

### Before Deploying Auth Changes:
- [ ] All auth listeners have corresponding disposal
- [ ] Navigation calls use `addPostFrameCallback`
- [ ] Provider access happens in `didChangeDependencies()` or `build()`
- [ ] Transition locks prevent race conditions
- [ ] Error boundaries handle Provider exceptions
- [ ] Memory leak testing completed
- [ ] Context validation implemented

### Debugging Tips:
1. **Enable verbose logging** for auth state changes
2. **Use Flutter Inspector** to check widget tree structure
3. **Monitor memory usage** during auth operations
4. **Test rapid auth state changes** (quick login/logout)
5. **Verify disposal methods** are called correctly

---

## � Issue 5: Provider Rebuild Cascades

### Scenario
One Provider change triggering unnecessary rebuilds across the entire widget tree.

### Problem Symptoms
```
Excessive build() calls
UI lag during auth state changes
Multiple Provider notifications for single auth event
```

### Solution: Selective Provider Listening

**Optimized Provider Usage:**
```dart
class OptimizedAuthWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Selector<SupabaseProvider, bool>(
      selector: (context, provider) => provider.isAuthenticated,
      builder: (context, isAuthenticated, child) {
        // Only rebuilds when isAuthenticated changes
        return isAuthenticated ? DashboardWidget() : LoginWidget();
      },
    );
  }
}

// Use Consumer only for specific data
class UserProfileWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SupabaseProvider>(
      builder: (context, provider, child) {
        if (provider.user == null) return SizedBox();

        return Column(
          children: [
            Text(provider.user!.name),
            // Static child won't rebuild
            child!,
          ],
        );
      },
      child: StaticFooterWidget(), // This won't rebuild
    );
  }
}
```

---

## ⚡ Issue 6: Async Provider Operations Blocking UI

### Scenario
Long-running auth operations blocking the UI thread.

### Solution: Non-blocking Auth Operations

**Enhanced Provider with UI-friendly Async Operations:**
```dart
class SupabaseProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _loadingMessage;

  bool get isLoading => _isLoading;
  String? get loadingMessage => _loadingMessage;

  Future<bool> signInWithProgress(String email, String password) async {
    _setLoading(true, 'جاري تسجيل الدخول...');

    try {
      // Yield control to UI thread
      await Future.delayed(Duration(milliseconds: 10));

      final result = await _performSignIn(email, password);

      _setLoading(false);
      return result;
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  void _setLoading(bool loading, [String? message]) {
    _isLoading = loading;
    _loadingMessage = message;
    notifyListeners();
  }
}
```

---

## 🔧 Implementation Examples for SmartBizTracker

### Enhanced AuthSyncService with Advanced Error Handling

```dart
class AuthSyncService {
  static final Map<String, Completer<bool>> _pendingOperations = {};
  static bool _disposed = false;

  static Future<bool> syncAuthStateWithLock(String operationId) async {
    // Prevent duplicate operations
    if (_pendingOperations.containsKey(operationId)) {
      return await _pendingOperations[operationId]!.future;
    }

    final completer = Completer<bool>();
    _pendingOperations[operationId] = completer;

    try {
      if (_disposed) {
        completer.complete(false);
        return false;
      }

      final result = await _performSyncOperation();
      completer.complete(result);
      return result;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _pendingOperations.remove(operationId);
    }
  }

  static void dispose() {
    _disposed = true;
    for (final completer in _pendingOperations.values) {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    }
    _pendingOperations.clear();
  }
}
```

### Safe Widget State Management

```dart
mixin SafeStateMixin<T extends StatefulWidget> on State<T> {
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void safeSetState(VoidCallback fn) {
    if (!_disposed && mounted) {
      setState(fn);
    }
  }

  Future<void> safeAsyncOperation(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (e) {
      if (!_disposed && mounted) {
        // Handle error in UI
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: ${e.toString()}')),
        );
      }
    }
  }
}
```

---

## 📋 Advanced Testing Strategies

### Auth State Testing Scenarios

```dart
// Test rapid auth state changes
void testRapidAuthChanges() async {
  final provider = SupabaseProvider();

  // Simulate rapid login/logout
  for (int i = 0; i < 10; i++) {
    await provider.signIn('test@example.com', 'password');
    await Future.delayed(Duration(milliseconds: 100));
    await provider.signOut();
    await Future.delayed(Duration(milliseconds: 100));
  }

  // Verify no memory leaks or race conditions
  assert(provider.isAuthenticated == false);
}

// Test Provider disposal
void testProviderDisposal() {
  final provider = SupabaseProvider();
  provider.dispose();

  // Verify no operations work after disposal
  try {
    provider.signIn('test@example.com', 'password');
    assert(false, 'Should throw after disposal');
  } catch (e) {
    // Expected
  }
}
```

---

## �🔗 Related Documentation
- `FIX_PROVIDER_DIRECTIONALITY_EXCEPTIONS.md` - Basic Provider fixes
- Flutter Provider documentation
- Supabase Flutter auth documentation
- Flutter performance best practices
