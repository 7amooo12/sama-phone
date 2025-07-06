import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/import_analysis_provider.dart';
import 'package:smartbiztracker_new/services/supabase_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';

/// Wrapper widget that ensures ImportAnalysisProvider is available
/// This provides a fallback mechanism if the global provider is not accessible
class ImportAnalysisProviderWrapper extends StatefulWidget {
  final Widget child;
  
  const ImportAnalysisProviderWrapper({
    super.key,
    required this.child,
  });

  @override
  State<ImportAnalysisProviderWrapper> createState() => _ImportAnalysisProviderWrapperState();
}

class _ImportAnalysisProviderWrapperState extends State<ImportAnalysisProviderWrapper> {
  ImportAnalysisProvider? _localProvider;
  bool _hasGlobalProvider = false;

  @override
  void initState() {
    super.initState();
    _checkProviderAvailability();
  }

  void _checkProviderAvailability() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          // Try to access global provider
          final globalProvider = Provider.of<ImportAnalysisProvider>(context, listen: false);
          AppLogger.info('✅ Global ImportAnalysisProvider found: ${globalProvider.runtimeType}');
          setState(() {
            _hasGlobalProvider = true;
          });
        } catch (e) {
          AppLogger.warning('⚠️ Global ImportAnalysisProvider not found, creating local provider: $e');
          _createLocalProvider();
        }
      }
    });
  }

  void _createLocalProvider() {
    try {
      // Try to get SupabaseService from global providers
      final supabaseService = Provider.of<SupabaseService>(context, listen: false);
      _localProvider = ImportAnalysisProvider(supabaseService: supabaseService);
      AppLogger.info('✅ Local ImportAnalysisProvider created successfully');
      setState(() {});
    } catch (e) {
      AppLogger.error('❌ Failed to create local ImportAnalysisProvider: $e');
      // Create with default service as last resort
      _localProvider = ImportAnalysisProvider(supabaseService: SupabaseService());
      setState(() {});
    }
  }

  @override
  void dispose() {
    _localProvider?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If global provider is available, just return the child
    if (_hasGlobalProvider) {
      return widget.child;
    }

    // If local provider is not ready, show loading
    if (_localProvider == null) {
      return Scaffold(
        backgroundColor: AccountantThemeConfig.backgroundColor,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('جاري تحميل مزود تحليل الاستيراد...'),
            ],
          ),
        ),
      );
    }

    // Provide local provider
    return ChangeNotifierProvider.value(
      value: _localProvider!,
      child: widget.child,
    );
  }
}

/// Extension to easily wrap widgets with ImportAnalysisProvider
extension ImportAnalysisProviderWrapperExtension on Widget {
  Widget withImportAnalysisProvider() {
    return ImportAnalysisProviderWrapper(child: this);
  }
}
