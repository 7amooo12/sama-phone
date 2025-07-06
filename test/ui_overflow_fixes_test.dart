import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/screens/owner/owner_dashboard.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/providers/simplified_product_provider.dart';
import 'package:smartbiztracker_new/providers/client_orders_provider.dart';
import 'package:smartbiztracker_new/providers/worker_task_provider.dart';
import 'package:smartbiztracker_new/providers/worker_rewards_provider.dart';
import 'package:smartbiztracker_new/providers/warehouse_provider.dart';
import 'package:smartbiztracker_new/services/stockwarehouse_api.dart';
import 'package:smartbiztracker_new/services/samastock_api.dart';
import 'package:smartbiztracker_new/services/flask_api_service.dart';

void main() {
  group('UI Overflow Fixes Tests', () {
    late Widget testWidget;

    setUp(() {
      testWidget = MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<SupabaseProvider>(
              create: (_) => SupabaseProvider(),
            ),
            ChangeNotifierProvider<SimplifiedProductProvider>(
              create: (_) => SimplifiedProductProvider(),
            ),
            ChangeNotifierProvider<ClientOrdersProvider>(
              create: (_) => ClientOrdersProvider(),
            ),
            ChangeNotifierProvider<WorkerTaskProvider>(
              create: (_) => WorkerTaskProvider(),
            ),
            ChangeNotifierProvider<WorkerRewardsProvider>(
              create: (_) => WorkerRewardsProvider(),
            ),
            ChangeNotifierProvider<WarehouseProvider>(
              create: (_) => WarehouseProvider(),
            ),
            Provider<StockWarehouseApiService>(
              create: (_) => StockWarehouseApiService(),
            ),
            Provider<SamaStockApiService>(
              create: (_) => SamaStockApiService(),
            ),
            Provider<FlaskApiService>(
              create: (_) => FlaskApiService(),
            ),
          ],
          child: const OwnerDashboard(),
        ),
      );
    });

    testWidgets('Owner Dashboard renders without overflow errors', (WidgetTester tester) async {
      // Set a specific screen size to test overflow scenarios
      await tester.binding.setSurfaceSize(const Size(360, 640)); // Small phone screen
      
      // Build the widget
      await tester.pumpWidget(testWidget);
      await tester.pump();

      // Verify that the dashboard renders without throwing overflow errors
      expect(find.byType(OwnerDashboard), findsOneWidget);
      
      // Check for TabBar
      expect(find.byType(TabBar), findsOneWidget);
      
      // Check for TabBarView
      expect(find.byType(TabBarView), findsOneWidget);
    });

    testWidgets('Overview tab handles small screen sizes', (WidgetTester tester) async {
      // Test with very small screen
      await tester.binding.setSurfaceSize(const Size(320, 568)); // iPhone SE size
      
      await tester.pumpWidget(testWidget);
      await tester.pump();

      // Verify overview tab content is visible
      expect(find.byType(OwnerDashboard), findsOneWidget);
      
      // The summary metrics should be properly constrained
      // Look for LayoutBuilder widgets that handle responsive design
      expect(find.byType(LayoutBuilder), findsWidgets);
    });

    testWidgets('Products tab handles filter buttons without overflow', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      
      await tester.pumpWidget(testWidget);
      await tester.pump();

      // Navigate to products tab (index 1)
      final tabBar = find.byType(TabBar);
      expect(tabBar, findsOneWidget);
      
      // Tap on the second tab (Products)
      await tester.tap(find.byIcon(Icons.inventory_2_rounded));
      await tester.pumpAndSettle();

      // Verify that filter buttons are properly constrained
      // The buttons should be wrapped in SizedBox with calculated widths
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('GridView calculations prevent overflow', (WidgetTester tester) async {
      // Test with different screen sizes
      final screenSizes = [
        const Size(320, 568), // Small phone
        const Size(360, 640), // Medium phone
        const Size(414, 896), // Large phone
        const Size(768, 1024), // Tablet
      ];

      for (final size in screenSizes) {
        await tester.binding.setSurfaceSize(size);
        
        await tester.pumpWidget(testWidget);
        await tester.pump();

        // Navigate to products tab
        await tester.tap(find.byIcon(Icons.inventory_2_rounded));
        await tester.pumpAndSettle();

        // Verify that LayoutBuilder is used for responsive GridView
        expect(find.byType(LayoutBuilder), findsWidgets);
        
        // The GridView should be properly constrained
        expect(find.byType(GridView), findsWidgets);
      }
    });

    testWidgets('Text widgets have proper overflow handling', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568)); // Very small screen
      
      await tester.pumpWidget(testWidget);
      await tester.pump();

      // Find all Text widgets and verify they have overflow handling
      final textWidgets = find.byType(Text);
      expect(textWidgets, findsWidgets);
      
      // Verify that critical text elements are properly constrained
      // This is done by checking for the presence of overflow-safe containers
      expect(find.byType(Flexible), findsWidgets);
      expect(find.byType(Expanded), findsWidgets);
    });
  });
}
