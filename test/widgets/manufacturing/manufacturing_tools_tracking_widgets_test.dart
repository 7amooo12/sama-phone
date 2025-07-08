import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/models/manufacturing/production_batch.dart';
import 'package:smartbiztracker_new/screens/manufacturing/widgets/manufacturing_tools_tracking_widgets.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';

void main() {
  group('Manufacturing Tools Tracking Widgets', () {
    late List<ToolUsageAnalytics> testAnalytics;
    late ProductionGapAnalysis testGapAnalysis;
    late RequiredToolsForecast testForecast;

    setUp(() {
      testAnalytics = [
        ToolUsageAnalytics(
          toolId: 1,
          toolName: 'مطرقة كبيرة',
          unit: 'قطعة',
          quantityUsedPerUnit: 1.0,
          totalQuantityUsed: 10.0,
          remainingStock: 5.0,
          initialStock: 15.0,
          usagePercentage: 66.7,
          stockStatus: 'medium',
          usageHistory: [],
        ),
        ToolUsageAnalytics(
          toolId: 2,
          toolName: 'مفك صغير',
          unit: 'قطعة',
          quantityUsedPerUnit: 2.0,
          totalQuantityUsed: 20.0,
          remainingStock: 2.0,
          initialStock: 22.0,
          usagePercentage: 90.9,
          stockStatus: 'low',
          usageHistory: [],
        ),
      ];

      testGapAnalysis = ProductionGapAnalysis(
        productId: 1,
        productName: 'منتج اختبار',
        currentProduction: 80.0,
        targetQuantity: 100.0,
        remainingPieces: 20.0,
        completionPercentage: 80.0,
        isOverProduced: false,
        isCompleted: false,
      );

      testForecast = RequiredToolsForecast(
        productId: 1,
        remainingPieces: 20.0,
        requiredTools: [
          RequiredToolItem(
            toolId: 1,
            toolName: 'مسامير حديد',
            unit: 'كيلو',
            quantityPerUnit: 0.5,
            totalQuantityNeeded: 10.0,
            availableStock: 8.0,
            shortfall: 2.0,
            isAvailable: false,
            availabilityStatus: 'partial',
          ),
        ],
        canCompleteProduction: false,
        unavailableTools: ['مسامير حديد'],
        totalCost: 50.0,
      );
    });

    group('ToolUsageAnalyticsWidget', () {
      testWidgets('should display analytics data correctly', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: ToolUsageAnalyticsWidget(
                analytics: testAnalytics,
                isLoading: false,
              ),
            ),
          ),
        );

        // Act
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('أدوات التصنيع المستخدمة'), findsOneWidget);
        expect(find.text('مطرقة كبيرة'), findsOneWidget);
        expect(find.text('مفك صغير'), findsOneWidget);
        expect(find.text('مخزون متوسط'), findsOneWidget);
        expect(find.text('مخزون منخفض'), findsOneWidget);
      });

      testWidgets('should display loading state', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: ToolUsageAnalyticsWidget(
                analytics: [],
                isLoading: true,
              ),
            ),
          ),
        );

        // Act
        await tester.pumpAndSettle();

        // Assert
        expect(find.byType(CircularProgressIndicator), findsWidgets);
      });

      testWidgets('should display empty state', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: ToolUsageAnalyticsWidget(
                analytics: [],
                isLoading: false,
              ),
            ),
          ),
        );

        // Act
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('لا توجد بيانات استخدام أدوات'), findsOneWidget);
      });

      testWidgets('should call refresh callback', (WidgetTester tester) async {
        // Arrange
        bool refreshCalled = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: ToolUsageAnalyticsWidget(
                analytics: testAnalytics,
                isLoading: false,
                onRefresh: () => refreshCalled = true,
              ),
            ),
          ),
        );

        // Act
        await tester.tap(find.byIcon(Icons.refresh));
        await tester.pumpAndSettle();

        // Assert
        expect(refreshCalled, isTrue);
      });
    });

    group('ProductionGapAnalysisWidget', () {
      testWidgets('should display gap analysis data correctly', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: ProductionGapAnalysisWidget(
                gapAnalysis: testGapAnalysis,
                isLoading: false,
              ),
            ),
          ),
        );

        // Act
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('تحليل فجوة الإنتاج'), findsOneWidget);
        expect(find.text('80.0%'), findsOneWidget);
        expect(find.text('80 / 100'), findsOneWidget);
      });

      testWidgets('should display loading state', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: ProductionGapAnalysisWidget(
                gapAnalysis: null,
                isLoading: true,
              ),
            ),
          ),
        );

        // Act
        await tester.pumpAndSettle();

        // Assert
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should display empty state', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: ProductionGapAnalysisWidget(
                gapAnalysis: null,
                isLoading: false,
              ),
            ),
          ),
        );

        // Act
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('لا توجد بيانات تحليل الفجوة'), findsOneWidget);
      });

      testWidgets('should show correct status for completed production', (WidgetTester tester) async {
        // Arrange
        final completedGapAnalysis = ProductionGapAnalysis(
          productId: 1,
          productName: 'منتج مكتمل',
          currentProduction: 100.0,
          targetQuantity: 100.0,
          remainingPieces: 0.0,
          completionPercentage: 100.0,
          isOverProduced: false,
          isCompleted: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: ProductionGapAnalysisWidget(
                gapAnalysis: completedGapAnalysis,
                isLoading: false,
              ),
            ),
          ),
        );

        // Act
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('مكتمل'), findsOneWidget);
        expect(find.text('تم إكمال الإنتاج'), findsOneWidget);
      });
    });

    group('RequiredToolsForecastWidget', () {
      testWidgets('should display forecast data correctly', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: RequiredToolsForecastWidget(
                forecast: testForecast,
                isLoading: false,
              ),
            ),
          ),
        );

        // Act
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('الأدوات المطلوبة للإكمال'), findsOneWidget);
        expect(find.text('لا يمكن إكمال الإنتاج'), findsOneWidget);
        expect(find.text('مسامير حديد'), findsOneWidget);
        expect(find.text('1 أداة'), findsOneWidget);
      });

      testWidgets('should display loading state', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: RequiredToolsForecastWidget(
                forecast: null,
                isLoading: true,
              ),
            ),
          ),
        );

        // Act
        await tester.pumpAndSettle();

        // Assert
        expect(find.byType(CircularProgressIndicator), findsWidgets);
      });

      testWidgets('should display empty state', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: RequiredToolsForecastWidget(
                forecast: null,
                isLoading: false,
              ),
            ),
          ),
        );

        // Act
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('لا توجد توقعات أدوات'), findsOneWidget);
      });

      testWidgets('should show unavailable tools warning', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: RequiredToolsForecastWidget(
                forecast: testForecast,
                isLoading: false,
              ),
            ),
          ),
        );

        // Act
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('أدوات غير متوفرة (1)'), findsOneWidget);
        expect(find.byIcon(Icons.warning), findsWidgets);
      });

      testWidgets('should call tool tap callback', (WidgetTester tester) async {
        // Arrange
        int? tappedToolId;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: RequiredToolsForecastWidget(
                forecast: testForecast,
                isLoading: false,
                onToolTap: (toolId) => tappedToolId = toolId,
              ),
            ),
          ),
        );

        // Act
        await tester.tap(find.text('مسامير حديد'));
        await tester.pumpAndSettle();

        // Assert
        expect(tappedToolId, equals(1));
      });
    });

    group('Widget Animations', () {
      testWidgets('should animate widgets on load', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: ToolUsageAnalyticsWidget(
                analytics: testAnalytics,
                isLoading: false,
              ),
            ),
          ),
        );

        // Act - pump a few frames to see animation
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Assert - widget should be visible after animation
        expect(find.text('أدوات التصنيع المستخدمة'), findsOneWidget);
      });
    });

    group('Responsive Design', () {
      testWidgets('should adapt to different screen sizes', (WidgetTester tester) async {
        // Arrange - Set a small screen size
        await tester.binding.setSurfaceSize(const Size(400, 600));
        
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ToolUsageAnalyticsWidget(
                  analytics: testAnalytics,
                  isLoading: false,
                ),
              ),
            ),
          ),
        );

        // Act
        await tester.pumpAndSettle();

        // Assert - Widget should still be rendered properly
        expect(find.text('أدوات التصنيع المستخدمة'), findsOneWidget);
        
        // Reset screen size
        await tester.binding.setSurfaceSize(null);
      });
    });

    group('Error Handling', () {
      testWidgets('should handle null data gracefully', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: ProductionGapAnalysisWidget(
                gapAnalysis: null,
                isLoading: false,
              ),
            ),
          ),
        );

        // Act
        await tester.pumpAndSettle();

        // Assert - Should show empty state instead of crashing
        expect(find.text('لا توجد بيانات تحليل الفجوة'), findsOneWidget);
      });
    });
  });
}
