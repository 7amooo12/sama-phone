import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import '../../../lib/widgets/treasury/main_treasury_vault_widget.dart';
import '../../../lib/widgets/treasury/sub_treasury_card_widget.dart';
import '../../../lib/models/treasury_models.dart';
import '../../../lib/providers/treasury_provider.dart';

void main() {
  group('Treasury Card Layout Tests', () {
    late TreasuryProvider mockTreasuryProvider;

    setUp(() {
      mockTreasuryProvider = TreasuryProvider();
    });

    Widget createTestWidget(Widget child) {
      return MaterialApp(
        home: ChangeNotifierProvider<TreasuryProvider>.value(
          value: mockTreasuryProvider,
          child: Scaffold(
            body: child,
          ),
        ),
      );
    }

    testWidgets('Main Treasury Card handles small balance amounts', (WidgetTester tester) async {
      final treasury = TreasuryVault(
        id: '1',
        name: 'Main Treasury',
        currency: 'EGP',
        currencySymbol: 'ج.م',
        currencyFlag: '🇪🇬',
        balance: 123.45,
        exchangeRateToEgp: 1.0,
        isMainTreasury: true,
      );

      await tester.pumpWidget(
        createTestWidget(
          MainTreasuryVaultWidget(
            treasury: treasury,
            allTreasuries: [treasury],
          ),
        ),
      );

      expect(find.text('123.45'), findsOneWidget);
      expect(find.text('ج.م'), findsOneWidget);
    });

    testWidgets('Main Treasury Card handles large balance amounts', (WidgetTester tester) async {
      final treasury = TreasuryVault(
        id: '1',
        name: 'Main Treasury',
        currency: 'EGP',
        currencySymbol: 'ج.م',
        currencyFlag: '🇪🇬',
        balance: 1234567890.50,
        exchangeRateToEgp: 1.0,
        isMainTreasury: true,
      );

      await tester.pumpWidget(
        createTestWidget(
          MainTreasuryVaultWidget(
            treasury: treasury,
            allTreasuries: [treasury],
          ),
        ),
      );

      // Should display formatted large number
      expect(find.textContaining('1.2B'), findsOneWidget);
      expect(find.text('ج.م'), findsOneWidget);
    });

    testWidgets('Sub Treasury Card handles medium balance amounts', (WidgetTester tester) async {
      final treasury = TreasuryVault(
        id: '2',
        name: 'Sub Treasury',
        currency: 'USD',
        currencySymbol: '\$',
        currencyFlag: '🇺🇸',
        balance: 45678.90,
        exchangeRateToEgp: 30.5,
        isMainTreasury: false,
      );

      await tester.pumpWidget(
        createTestWidget(
          SubTreasuryCardWidget(
            treasury: treasury,
            allTreasuries: [treasury],
          ),
        ),
      );

      // Should display formatted medium number
      expect(find.textContaining('45.7K'), findsOneWidget);
    });

    testWidgets('Sub Treasury Card handles very large balance amounts', (WidgetTester tester) async {
      final treasury = TreasuryVault(
        id: '3',
        name: 'Large Sub Treasury',
        currency: 'EUR',
        currencySymbol: '€',
        currencyFlag: '🇪🇺',
        balance: 999999999.99,
        exchangeRateToEgp: 32.8,
        isMainTreasury: false,
      );

      await tester.pumpWidget(
        createTestWidget(
          SubTreasuryCardWidget(
            treasury: treasury,
            allTreasuries: [treasury],
          ),
        ),
      );

      // Should display formatted very large number
      expect(find.textContaining('1.0B'), findsOneWidget);
    });

    testWidgets('Treasury cards handle long names without overflow', (WidgetTester tester) async {
      final treasury = TreasuryVault(
        id: '4',
        name: 'Very Long Treasury Name That Should Not Overflow The Card Layout',
        currency: 'GBP',
        currencySymbol: '£',
        currencyFlag: '🇬🇧',
        balance: 12345.67,
        exchangeRateToEgp: 38.2,
        isMainTreasury: false,
      );

      await tester.pumpWidget(
        createTestWidget(
          SubTreasuryCardWidget(
            treasury: treasury,
            allTreasuries: [treasury],
          ),
        ),
      );

      // Should find the treasury name (possibly truncated)
      expect(find.textContaining('Very Long Treasury'), findsOneWidget);
      expect(find.textContaining('12.3K'), findsOneWidget);
    });

    group('Treasury Positioning Algorithm Tests', () {
      test('Single treasury should be centered', () {
        // Test positioning for 1 treasury
        final positions = _calculateTestTreePositions(1, 1000.0, 200.0, 150.0);
        expect(positions.length, 1);
        expect(positions[0].dx, closeTo(400.0, 10.0)); // Center position (500 - 100)
        expect(positions[0].dy, 0.0);
      });

      test('Two treasuries should be positioned left and right', () {
        // Test positioning for 2 treasuries
        final positions = _calculateTestTreePositions(2, 1000.0, 200.0, 150.0);
        expect(positions.length, 2);
        expect(positions[0].dx, closeTo(200.0, 10.0)); // Left position (30% - half width)
        expect(positions[1].dx, closeTo(600.0, 10.0)); // Right position (70% - half width)
        expect(positions[0].dy, 0.0);
        expect(positions[1].dy, 0.0);
      });

      test('Three treasuries should form triangle layout', () {
        // Test positioning for 3 treasuries
        final positions = _calculateTestTreePositions(3, 1000.0, 200.0, 150.0);
        expect(positions.length, 3);
        expect(positions[0].dx, closeTo(400.0, 10.0)); // Top center
        expect(positions[1].dx, closeTo(150.0, 10.0)); // Bottom left
        expect(positions[2].dx, closeTo(650.0, 10.0)); // Bottom right
        expect(positions[0].dy, 0.0);
        expect(positions[1].dy, greaterThan(0.0)); // Below first
        expect(positions[2].dy, greaterThan(0.0)); // Below first
      });

      test('Four treasuries should form 2x2 grid', () {
        // Test positioning for 4 treasuries
        final positions = _calculateTestTreePositions(4, 1000.0, 200.0, 150.0);
        expect(positions.length, 4);
        // Should have 2 rows with 2 columns each
        expect(positions[0].dy, 0.0); // First row
        expect(positions[1].dy, 0.0); // First row
        expect(positions[2].dy, greaterThan(0.0)); // Second row
        expect(positions[3].dy, greaterThan(0.0)); // Second row
      });

      test('Five or more treasuries should use grid layout', () {
        // Test positioning for 5 treasuries
        final positions = _calculateTestTreePositions(5, 1000.0, 200.0, 150.0);
        expect(positions.length, 5);
        // Should distribute across multiple rows
        final uniqueYPositions = positions.map((p) => p.dy).toSet();
        expect(uniqueYPositions.length, greaterThanOrEqualTo(2)); // At least 2 rows
      });
    });
  });
}

// Helper function to test the positioning algorithm
List<Offset> _calculateTestTreePositions(
  int count,
  double screenWidth,
  double cardWidth,
  double cardHeight,
) {
  final positions = <Offset>[];
  final verticalSpacing = cardHeight + 40.0; // Default spacing
  final horizontalMargin = cardWidth * 0.05;

  if (count == 0) return positions;

  // Replicate the positioning logic from the main screen
  for (int i = 0; i < count; i++) {
    double x, y;

    if (count == 1) {
      // Single treasury: center it
      x = screenWidth * 0.5 - cardWidth / 2;
      y = 0;
    } else if (count == 2) {
      // Two treasuries: left and right
      if (i == 0) {
        x = screenWidth * 0.3 - cardWidth / 2; // Left position
        y = 0;
      } else {
        x = screenWidth * 0.7 - cardWidth / 2; // Right position
        y = 0;
      }
    } else if (count == 3) {
      // Three treasuries: top center, bottom left, bottom right
      if (i == 0) {
        x = screenWidth * 0.5 - cardWidth / 2; // Top center
        y = 0;
      } else if (i == 1) {
        x = screenWidth * 0.25 - cardWidth / 2; // Bottom left
        y = verticalSpacing;
      } else {
        x = screenWidth * 0.75 - cardWidth / 2; // Bottom right
        y = verticalSpacing;
      }
    } else if (count == 4) {
      // Four treasuries: 2x2 grid
      final row = i ~/ 2;
      final col = i % 2;
      x = screenWidth * (col == 0 ? 0.25 : 0.75) - cardWidth / 2;
      y = row * verticalSpacing;
    } else {
      // Five or more treasuries: use grid layout
      final columns = _calculateTestOptimalColumns(count, screenWidth, cardWidth);
      final row = i ~/ columns;
      final col = i % columns;

      final availableWidth = screenWidth - (2 * horizontalMargin);
      final totalCardWidth = columns * cardWidth;
      final totalSpacing = availableWidth - totalCardWidth;
      final spacingBetweenCards = totalSpacing / (columns + 1);

      x = horizontalMargin + spacingBetweenCards + (col * (cardWidth + spacingBetweenCards));
      y = row * verticalSpacing;
    }

    // Ensure cards don't go outside screen bounds
    x = x.clamp(horizontalMargin, screenWidth - cardWidth - horizontalMargin);

    positions.add(Offset(x, y));
  }

  return positions;
}

int _calculateTestOptimalColumns(int totalCount, double screenWidth, double cardWidth) {
  final horizontalMargin = cardWidth * 0.05;
  final availableWidth = screenWidth - (2 * horizontalMargin);

  final maxColumns = (availableWidth / (cardWidth * 1.1)).floor();

  if (totalCount <= 3) return totalCount;
  if (totalCount == 4) return 2;
  if (totalCount <= 6) return 3;
  if (totalCount <= 8) return 4;

  return maxColumns.clamp(2, 4);
}
