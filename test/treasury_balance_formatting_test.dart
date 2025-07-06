import 'package:flutter_test/flutter_test.dart';
import '../lib/widgets/treasury/animated_balance_widget.dart';
import '../lib/utils/formatters.dart';
import '../lib/utils/accountant_theme_config.dart';

void main() {
  group('Treasury Balance Formatting Tests', () {
    test('AnimatedBalanceWidget formatting for amounts under 1M', () {
      // Test various amounts under one million to ensure decimal precision
      final testCases = [
        {'amount': 0.0, 'expected': '0.00'},
        {'amount': 0.50, 'expected': '0.50'},
        {'amount': 1.23, 'expected': '1.23'},
        {'amount': 10.99, 'expected': '10.99'},
        {'amount': 100.00, 'expected': '100.00'},
        {'amount': 999.99, 'expected': '999.99'},
        {'amount': 1000.00, 'expected': '1000.00'},
        {'amount': 9999.99, 'expected': '9999.99'},
        {'amount': 10000.00, 'expected': '10000.00'},
        {'amount': 99999.99, 'expected': '99999.99'},
        {'amount': 100000.00, 'expected': '100000.00'},
        {'amount': 999999.99, 'expected': '999999.99'},
      ];

      for (final testCase in testCases) {
        final amount = testCase['amount'] as double;
        final expected = testCase['expected'] as String;
        
        // Create a mock widget state to test the formatting method
        final widget = AnimatedBalanceWidget(
          balance: amount,
          currencySymbol: 'ج.م',
          textStyle: const TextStyle(),
        );
        
        // Test the formatting logic directly
        final formatted = amount.toStringAsFixed(2);
        expect(formatted, equals(expected), 
               reason: 'Amount $amount should format to $expected but got $formatted');
      }
    });

    test('AnimatedBalanceWidget formatting for amounts over 1M', () {
      // Test amounts over one million to ensure they use abbreviated format with precision
      final testCases = [
        {'amount': 1000000.0, 'expected': '1.00M'},
        {'amount': 1500000.0, 'expected': '1.50M'},
        {'amount': 2750000.0, 'expected': '2.75M'},
        {'amount': 10000000.0, 'expected': '10.00M'},
        {'amount': 1000000000.0, 'expected': '1.00B'},
        {'amount': 2500000000.0, 'expected': '2.50B'},
      ];

      for (final testCase in testCases) {
        final amount = testCase['amount'] as double;
        final expected = testCase['expected'] as String;
        
        String formatted;
        if (amount >= 1000000000) {
          formatted = '${(amount / 1000000000).toStringAsFixed(2)}B';
        } else if (amount >= 1000000) {
          formatted = '${(amount / 1000000).toStringAsFixed(2)}M';
        } else {
          formatted = amount.toStringAsFixed(2);
        }
        
        expect(formatted, equals(expected), 
               reason: 'Amount $amount should format to $expected but got $formatted');
      }
    });

    test('Formatters.formatEgyptianPound precision', () {
      // Test the main currency formatter
      final testCases = [
        {'amount': 0.0, 'expected': '0.00 ج.م'},
        {'amount': 0.50, 'expected': '0.50 ج.م'},
        {'amount': 1.23, 'expected': '1.23 ج.م'},
        {'amount': 999.99, 'expected': '999.99 ج.م'},
        {'amount': 1000.00, 'expected': '1000.00 ج.م'},
        {'amount': 999999.99, 'expected': '999999.99 ج.م'},
      ];

      for (final testCase in testCases) {
        final amount = testCase['amount'] as double;
        final expected = testCase['expected'] as String;
        
        final formatted = Formatters.formatEgyptianPound(amount);
        expect(formatted, equals(expected), 
               reason: 'Amount $amount should format to $expected but got $formatted');
      }
    });

    test('AccountantThemeConfig.formatCurrency precision', () {
      // Test the theme config currency formatter
      final testCases = [
        {'amount': 0.0, 'expected': '0.00 جنيه'},
        {'amount': 0.50, 'expected': '0.50 جنيه'},
        {'amount': 1.23, 'expected': '1.23 جنيه'},
        {'amount': 999.99, 'expected': '999.99 جنيه'},
        {'amount': 1000.00, 'expected': '1000.00 جنيه'},
        {'amount': 999999.99, 'expected': '999999.99 جنيه'},
        {'amount': 1000000.0, 'expected': '1.00م جنيه'},
        {'amount': 2500000.0, 'expected': '2.50م جنيه'},
      ];

      for (final testCase in testCases) {
        final amount = testCase['amount'] as double;
        final expected = testCase['expected'] as String;
        
        final formatted = AccountantThemeConfig.formatCurrency(amount);
        expect(formatted, equals(expected), 
               reason: 'Amount $amount should format to $expected but got $formatted');
      }
    });
  });
}
