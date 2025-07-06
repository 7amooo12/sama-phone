import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/screens/auth/auth_wrapper.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/theme_provider_new.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/utils/scroll_behavior.dart';
import 'package:smartbiztracker_new/services/app_performance_service.dart';
import 'package:flutter/services.dart';


class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final AppPerformanceService _performanceService = AppPerformanceService();
  bool _isPerformanceInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializePerformance();
  }

  Future<void> _initializePerformance() async {
    try {
      await _performanceService.initializePerformance();
      setState(() {
        _isPerformanceInitialized = true;
      });
    } catch (e) {
      debugPrint('Failed to initialize performance optimizations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Optimize system UI
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: themeProvider.themeMode == ThemeMode.dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarColor: themeProvider.themeMode == ThemeMode.dark
          ? Colors.black
          : Colors.white,
      systemNavigationBarIconBrightness: themeProvider.themeMode == ThemeMode.dark
          ? Brightness.light
          : Brightness.dark,
    ));

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SmartBizTracker',
      theme: StyleSystem.darkTheme, // Force dark theme
      darkTheme: StyleSystem.darkTheme,
      themeMode: ThemeMode.dark, // Force dark mode permanently
      locale: const Locale('ar', 'EG'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'EG'),
        Locale('en', 'US'),
      ],
      scrollBehavior: const OptimizedScrollBehavior(
        applyAndroidOverscrollIndicator: false,
        useAlwaysBouncingScroll: true,
      ),
      home: const AuthWrapper(),
      routes: AppRoutes.routes,
      navigatorKey: AppRoutes.navigatorKey,
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('الصفحة غير موجودة'),
            ),
          ),
        );
      },
      builder: (context, child) {
        // Optimize app for performance and avoid blank screens
        if (child == null) {
          return const Center(child: CircularProgressIndicator());
        }

        // Apply performance optimizations to the whole app
        final optimizedChild = _isPerformanceInitialized
            ? _buildOptimizedChild(context, child)
            : child;

        // Ensure a Material parent for all widgets in the app
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Material(
            color: Colors.transparent,
            child: optimizedChild,
          ),
        );
      },
    );
  }

  Widget _buildOptimizedChild(BuildContext context, Widget child) {
    // Apply performance optimizations to the widget tree
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Optimize scrolling performance
        return false;
      },
      child: RepaintBoundary(
        child: child,
      ),
    );
  }
}