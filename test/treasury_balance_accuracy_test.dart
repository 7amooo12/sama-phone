import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import '../lib/providers/treasury_provider.dart';
import '../lib/models/treasury_models.dart';
import '../lib/screens/treasury_control/tabs/treasury_balance_tab.dart';
import '../lib/utils/formatters.dart';

// Generate mocks
@GenerateMocks([TreasuryProvider])
import 'treasury_balance_accuracy_test.mocks.dart';

void main() {
  group('Treasury Balance Display Accuracy Tests', () {
    late MockTreasuryProvider mockTreasuryProvider;
    late TreasuryVault testTreasury;

    setUp(() {
      mockTreasuryProvider = MockTreasuryProvider();
      
      // Create test treasury with specific balance
      testTreasury = TreasuryVault(
        id: 'test-treasury-id',
        name: 'Test Treasury',
        balance: 1234.56,
        currency: 'EGP',
        currencySymbol: 'ج.م',
        treasuryType: TreasuryType.cash,
        isMainTreasury: false,
        exchangeRateToEgp: 1.0,
        positionX: 0,
        positionY: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Setup mock behavior
      when(mockTreasuryProvider.treasuryVaults).thenReturn([testTreasury]);
      when(mockTreasuryProvider.isLoading).thenReturn(false);
      when(mockTreasuryProvider.error).thenReturn(null);
    });

    testWidgets('Balance display shows exact treasury balance', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TreasuryProvider>.value(
            value: mockTreasuryProvider,
            child: Scaffold(
              body: TreasuryBalanceTab(
                treasuryId: 'test-treasury-id',
                treasuryType: 'treasury',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that the balance is displayed correctly
      expect(find.text('1,234.56 ج.م'), findsOneWidget);
    });

    test('Balance formatting consistency', () {
      // Test various balance amounts
      final testCases = [
        {'balance': 0.0, 'expected': '0.00 ج.م'},
        {'balance': 1.0, 'expected': '1.00 ج.م'},
        {'balance': 1234.56, 'expected': '1,234.56 ج.م'},
        {'balance': 1000000.0, 'expected': '1,000,000.00 ج.م'},
        {'balance': 1234567.89, 'expected': '1,234,567.89 ج.م'},
      ];

      for (final testCase in testCases) {
        final balance = testCase['balance'] as double;
        final expected = testCase['expected'] as String;
        final result = Formatters.formatTreasuryBalance(balance, 'ج.م');
        
        expect(result, equals(expected), 
          reason: 'Balance $balance should format to $expected but got $result');
      }
    });

    test('Animated balance formatting consistency', () {
      // Test animated balance formatting
      final testCases = [
        {'balance': 0.0, 'expected': '0.00'},
        {'balance': 1234.56, 'expected': '1,234.56'},
        {'balance': 1000000.0, 'expected': '1.00M'},
        {'balance': 1000000000.0, 'expected': '1.00B'},
      ];

      for (final testCase in testCases) {
        final balance = testCase['balance'] as double;
        final expected = testCase['expected'] as String;
        final result = Formatters.formatAnimatedBalance(balance);
        
        expect(result, equals(expected), 
          reason: 'Animated balance $balance should format to $expected but got $result');
      }
    });

    test('Currency symbol consistency', () {
      // Test different currency symbols
      final testCases = [
        {'balance': 1234.56, 'symbol': 'ج.م', 'expected': '1,234.56 ج.م'},
        {'balance': 1234.56, 'symbol': '\$', 'expected': '1,234.56 \$'},
        {'balance': 1234.56, 'symbol': '€', 'expected': '1,234.56 €'},
      ];

      for (final testCase in testCases) {
        final balance = testCase['balance'] as double;
        final symbol = testCase['symbol'] as String;
        final expected = testCase['expected'] as String;
        final result = Formatters.formatTreasuryBalance(balance, symbol);
        
        expect(result, equals(expected), 
          reason: 'Balance $balance with symbol $symbol should format to $expected but got $result');
      }
    });

    test('Decimal precision accuracy', () {
      // Test that decimal precision is maintained
      final testCases = [
        1234.1,
        1234.12,
        1234.123, // Should round to 2 decimal places
        1234.999, // Should round to 2 decimal places
      ];

      for (final balance in testCases) {
        final result = Formatters.formatTreasuryBalance(balance, 'ج.م');
        
        // Extract the decimal part
        final parts = result.split(' ')[0].split('.');
        expect(parts.length, equals(2), 
          reason: 'Balance $balance should have decimal part');
        expect(parts[1].length, equals(2), 
          reason: 'Balance $balance should have exactly 2 decimal places');
      }
    });

    group('Edge Cases', () {
      test('Negative balance formatting', () {
        final result = Formatters.formatTreasuryBalance(-1234.56, 'ج.م');
        expect(result, equals('-1,234.56 ج.م'));
      });

      test('Zero balance formatting', () {
        final result = Formatters.formatTreasuryBalance(0.0, 'ج.م');
        expect(result, equals('0.00 ج.م'));
      });

      test('Very large balance formatting', () {
        final result = Formatters.formatAnimatedBalance(999999999.99);
        expect(result, equals('999,999,999.99'));
      });

      test('Billion threshold formatting', () {
        final result = Formatters.formatAnimatedBalance(1000000000.0);
        expect(result, equals('1.00B'));
      });
    });
  });
}
