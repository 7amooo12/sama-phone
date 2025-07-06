import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/import_analysis_provider.dart';
import 'package:smartbiztracker_new/services/supabase_service.dart';

/// Test to verify ImportAnalysisProvider is properly accessible and working
void main() {
  group('ImportAnalysisProvider Integration Tests', () {
    testWidgets('should be accessible in widget tree', (WidgetTester tester) async {
      // Create a mock SupabaseService for testing
      final mockSupabaseService = SupabaseService();

      // Create the provider
      final importAnalysisProvider = ImportAnalysisProvider(
        supabaseService: mockSupabaseService,
      );

      // Build a widget tree with the provider
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: importAnalysisProvider,
            child: const TestWidget(),
          ),
        ),
      );

      // Verify the provider is accessible
      expect(find.text('Provider accessible'), findsOneWidget);
    });

    testWidgets('should handle provider state changes', (WidgetTester tester) async {
      final mockSupabaseService = SupabaseService();
      final importAnalysisProvider = ImportAnalysisProvider(
        supabaseService: mockSupabaseService,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: importAnalysisProvider,
            child: const TestWidget(),
          ),
        ),
      );

      // Verify initial state
      expect(find.text('Loading: false'), findsOneWidget);
      expect(find.text('Processing: false'), findsOneWidget);
    });

    testWidgets('should handle provider not found gracefully', (WidgetTester tester) async {
      // Build widget tree without provider to test error handling
      await tester.pumpWidget(
        const MaterialApp(
          home: TestProviderAccessWidget(),
        ),
      );

      // Should show error message
      expect(find.text('Provider not accessible'), findsOneWidget);
    });

    testWidgets('should work with MultiProvider setup', (WidgetTester tester) async {
      final mockSupabaseService = SupabaseService();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              Provider<SupabaseService>.value(value: mockSupabaseService),
              ChangeNotifierProvider(
                create: (context) => ImportAnalysisProvider(
                  supabaseService: Provider.of<SupabaseService>(context, listen: false),
                ),
              ),
            ],
            child: const TestWidget(),
          ),
        ),
      );

      // Verify the provider is accessible through MultiProvider
      expect(find.text('Provider accessible'), findsOneWidget);
    });
  });
}

/// Test widget that consumes ImportAnalysisProvider
class TestWidget extends StatelessWidget {
  const TestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ImportAnalysisProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          body: Column(
            children: [
              const Text('Provider accessible'),
              Text('Loading: ${provider.isLoading}'),
              Text('Processing: ${provider.isProcessing}'),
              Text('Status: ${provider.currentStatus}'),
              Text('Progress: ${provider.processingProgress}'),
            ],
          ),
        );
      },
    );
  }
}

/// Test widget that tests provider access with error handling
class TestProviderAccessWidget extends StatelessWidget {
  const TestProviderAccessWidget({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      final provider = Provider.of<ImportAnalysisProvider>(context, listen: false);
      return Scaffold(
        body: Column(
          children: [
            const Text('Provider accessible'),
            Text('Provider type: ${provider.runtimeType}'),
          ],
        ),
      );
    } catch (e) {
      return const Scaffold(
        body: Column(
          children: [
            Text('Provider not accessible'),
            Text('This is expected when provider is not in widget tree'),
          ],
        ),
      );
    }
  }
}
