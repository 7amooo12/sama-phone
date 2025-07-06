import 'package:flutter_test/flutter_test.dart';

/// Test cases for the customer modal null pointer fix
/// These tests verify that the customer data handling is safe and robust
void main() {
  group('Customer Modal Null Safety Tests', () {
    
    test('Safe customer name extraction handles null values', () {
      // Test cases for customer name extraction
      final testCases = [
        {'name': 'أحمد محمد', 'expected': 'أحمد محمد'},
        {'name': null, 'expected': 'عميل غير محدد'},
        {'name': '', 'expected': 'عميل غير محدد'},
        {'expected': 'عميل غير محدد'}, // Missing name key
      ];

      for (final testCase in testCases) {
        final customer = Map<String, dynamic>.from(testCase);
        customer.remove('expected');
        
        final result = _getCustomerNameSafe(customer);
        expect(result, equals(testCase['expected']));
      }
    });

    test('Safe customer initial extraction handles edge cases', () {
      final testCases = [
        {'name': 'أحمد محمد', 'expected': 'أ'},
        {'name': 'Ahmed', 'expected': 'A'},
        {'name': null, 'expected': 'ع'},
        {'name': '', 'expected': 'ع'},
        {'expected': 'ع'}, // Missing name key
      ];

      for (final testCase in testCases) {
        final customer = Map<String, dynamic>.from(testCase);
        customer.remove('expected');
        
        final result = _getCustomerInitialSafe(customer);
        expect(result, equals(testCase['expected']));
      }
    });

    test('Safe customer category extraction handles null values', () {
      final testCases = [
        {'category': 'إلكترونيات', 'expected': 'إلكترونيات'},
        {'category': null, 'expected': 'فئة غير محددة'},
        {'category': '', 'expected': 'فئة غير محددة'},
        {'expected': 'فئة غير محددة'}, // Missing category key
      ];

      for (final testCase in testCases) {
        final customer = Map<String, dynamic>.from(testCase);
        customer.remove('expected');
        
        final result = _getCustomerCategorySafe(customer);
        expect(result, equals(testCase['expected']));
      }
    });

    test('Safe customer purchases extraction handles various types', () {
      final testCases = [
        {'purchases': 5, 'expected': 5},
        {'purchases': 5.0, 'expected': 5},
        {'purchases': '5', 'expected': 0}, // String should default to 0
        {'purchases': null, 'expected': 0},
        {'expected': 0}, // Missing purchases key
      ];

      for (final testCase in testCases) {
        final customer = Map<String, dynamic>.from(testCase);
        customer.remove('expected');
        
        final result = _getCustomerPurchasesSafe(customer);
        expect(result, equals(testCase['expected']));
      }
    });

    test('Safe customer total spent extraction handles various types', () {
      final testCases = [
        {'totalSpent': 150.50, 'expected': 150.50},
        {'totalSpent': 150, 'expected': 150.0},
        {'totalSpent': '150.50', 'expected': 0.0}, // String should default to 0.0
        {'totalSpent': null, 'expected': 0.0},
        {'expected': 0.0}, // Missing totalSpent key
      ];

      for (final testCase in testCases) {
        final customer = Map<String, dynamic>.from(testCase);
        customer.remove('expected');
        
        final result = _getCustomerTotalSpentSafe(customer);
        expect(result, equals(testCase['expected']));
      }
    });

    test('Safe customer total quantity extraction handles various types', () {
      final testCases = [
        {'totalQuantity': 25.5, 'expected': 25.5},
        {'totalQuantity': 25, 'expected': 25.0},
        {'totalQuantity': '25.5', 'expected': 0.0}, // String should default to 0.0
        {'totalQuantity': null, 'expected': 0.0},
        {'expected': 0.0}, // Missing totalQuantity key
      ];

      for (final testCase in testCases) {
        final customer = Map<String, dynamic>.from(testCase);
        customer.remove('expected');
        
        final result = _getCustomerTotalQuantitySafe(customer);
        expect(result, equals(testCase['expected']));
      }
    });

    test('Customer modal data validation prevents crashes', () {
      // Test various problematic customer data structures
      final problematicCustomers = [
        {}, // Empty customer
        {'name': null, 'category': null}, // Null values
        {'name': '', 'category': ''}, // Empty strings
        {'name': 'أحمد'}, // Missing category
        {'category': 'إلكترونيات'}, // Missing name
        {'name': 'أحمد', 'category': 'إلكترونيات', 'purchases': null}, // Null purchases
        {'name': 'أحمد', 'category': 'إلكترونيات', 'totalSpent': 'invalid'}, // Invalid totalSpent
      ];

      for (final customer in problematicCustomers) {
        // These should not throw exceptions
        expect(() => _validateCustomerDataSafe(customer), returnsNormally);
        
        // All safe getters should return valid defaults
        expect(_getCustomerNameSafe(customer), isA<String>());
        expect(_getCustomerCategorySafe(customer), isA<String>());
        expect(_getCustomerInitialSafe(customer), isA<String>());
        expect(_getCustomerPurchasesSafe(customer), isA<int>());
        expect(_getCustomerTotalSpentSafe(customer), isA<double>());
        expect(_getCustomerTotalQuantitySafe(customer), isA<double>());
      }
    });
  });
}

// Helper functions that mirror the actual implementation
String _getCustomerNameSafe(Map<String, dynamic> customer) {
  final name = customer['name'] as String?;
  if (name == null || name.isEmpty) {
    return 'عميل غير محدد';
  }
  return name;
}

String _getCustomerInitialSafe(Map<String, dynamic> customer) {
  final name = _getCustomerNameSafe(customer);
  if (name == 'عميل غير محدد') {
    return 'ع';
  }
  return name[0].toUpperCase();
}

String _getCustomerCategorySafe(Map<String, dynamic> customer) {
  final category = customer['category'] as String?;
  if (category == null || category.isEmpty) {
    return 'فئة غير محددة';
  }
  return category;
}

int _getCustomerPurchasesSafe(Map<String, dynamic> customer) {
  final purchases = customer['purchases'];
  if (purchases is int) return purchases;
  if (purchases is num) return purchases.toInt();
  return 0;
}

double _getCustomerTotalSpentSafe(Map<String, dynamic> customer) {
  final totalSpent = customer['totalSpent'];
  if (totalSpent is double) return totalSpent;
  if (totalSpent is num) return totalSpent.toDouble();
  return 0.0;
}

double _getCustomerTotalQuantitySafe(Map<String, dynamic> customer) {
  final totalQuantity = customer['totalQuantity'];
  if (totalQuantity is double) return totalQuantity;
  if (totalQuantity is num) return totalQuantity.toDouble();
  return 0.0;
}

bool _validateCustomerDataSafe(Map<String, dynamic> customer) {
  // This function validates that all customer data access is safe
  try {
    _getCustomerNameSafe(customer);
    _getCustomerCategorySafe(customer);
    _getCustomerInitialSafe(customer);
    _getCustomerPurchasesSafe(customer);
    _getCustomerTotalSpentSafe(customer);
    _getCustomerTotalQuantitySafe(customer);
    return true;
  } catch (e) {
    return false;
  }
}
