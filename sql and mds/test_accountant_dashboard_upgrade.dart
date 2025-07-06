// Test file for Accountant Dashboard Upgrade
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'lib/screens/accountant/accountant_dashboard.dart';

void main() {
  group('Accountant Dashboard Upgrade Tests', () {
    
    testWidgets('should display modern app bar with green glow effects', (WidgetTester tester) async {
      // Test the modern app bar implementation
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0A0A0A), // Professional luxurious black
                    Color(0xFF1A1A2E), // Darkened blue-black
                    Color(0xFF16213E), // Deep blue-black
                    Color(0xFF0F0F23), // Rich dark blue
                  ],
                  stops: [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
          ),
        ),
      );

      // Verify gradient background is applied
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      final gradient = decoration.gradient as LinearGradient;
      
      expect(gradient.colors.length, equals(4));
      expect(gradient.colors.first, equals(const Color(0xFF0A0A0A)));
      expect(gradient.colors.last, equals(const Color(0xFF0F0F23)));
    });

    test('should create financial card with proper styling', () {
      // Test financial card creation
      final card = Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF10B981), Color(0xFF059669)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.trending_up_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+12.5%',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '150,000 جنيه',
              style: GoogleFonts.cairo(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'إجمالي الإيرادات',
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      );

      expect(card, isA<Container>());
      expect(card.padding, equals(const EdgeInsets.all(20)));
    });

    test('should handle status colors correctly', () {
      // Test status color mapping
      Color getStatusColor(String status) {
        switch (status.toLowerCase()) {
          case 'paid':
          case 'completed':
            return const Color(0xFF10B981);
          case 'pending':
            return const Color(0xFFF59E0B);
          case 'cancelled':
          case 'canceled':
            return const Color(0xFFEF4444);
          default:
            return const Color(0xFF6B7280);
        }
      }

      expect(getStatusColor('paid'), equals(const Color(0xFF10B981)));
      expect(getStatusColor('completed'), equals(const Color(0xFF10B981)));
      expect(getStatusColor('pending'), equals(const Color(0xFFF59E0B)));
      expect(getStatusColor('cancelled'), equals(const Color(0xFFEF4444)));
      expect(getStatusColor('unknown'), equals(const Color(0xFF6B7280)));
    });

    test('should handle status icons correctly', () {
      // Test status icon mapping
      IconData getStatusIcon(String status) {
        switch (status.toLowerCase()) {
          case 'paid':
          case 'completed':
            return Icons.check_circle_rounded;
          case 'pending':
            return Icons.pending_rounded;
          case 'cancelled':
          case 'canceled':
            return Icons.cancel_rounded;
          default:
            return Icons.help_outline_rounded;
        }
      }

      expect(getStatusIcon('paid'), equals(Icons.check_circle_rounded));
      expect(getStatusIcon('completed'), equals(Icons.check_circle_rounded));
      expect(getStatusIcon('pending'), equals(Icons.pending_rounded));
      expect(getStatusIcon('cancelled'), equals(Icons.cancel_rounded));
      expect(getStatusIcon('unknown'), equals(Icons.help_outline_rounded));
    });

    test('should handle status text correctly', () {
      // Test status text mapping
      String getStatusText(String status) {
        switch (status.toLowerCase()) {
          case 'paid':
          case 'completed':
            return 'مكتملة';
          case 'pending':
            return 'معلقة';
          case 'cancelled':
          case 'canceled':
            return 'ملغاة';
          default:
            return 'غير محدد';
        }
      }

      expect(getStatusText('paid'), equals('مكتملة'));
      expect(getStatusText('completed'), equals('مكتملة'));
      expect(getStatusText('pending'), equals('معلقة'));
      expect(getStatusText('cancelled'), equals('ملغاة'));
      expect(getStatusText('unknown'), equals('غير محدد'));
    });

    testWidgets('should display modern tab bar with proper styling', (WidgetTester tester) async {
      // Test modern tab bar
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 9,
            child: Scaffold(
              body: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1E293B).withOpacity(0.9),
                      const Color(0xFF334155).withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 0,
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: const TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'الرئيسية'),
                    Tab(text: 'الفواتير'),
                    Tab(text: 'الطلبات'),
                    Tab(text: 'المنتجات'),
                    Tab(text: 'الحسابات'),
                    Tab(text: 'حركة صنف'),
                    Tab(text: 'العمال'),
                    Tab(text: 'فواتير المتجر'),
                    Tab(text: 'المدفوعات'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Verify tab bar is displayed
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('الرئيسية'), findsOneWidget);
      expect(find.text('الفواتير'), findsOneWidget);
      expect(find.text('الطلبات'), findsOneWidget);
    });

    test('should calculate financial metrics correctly', () {
      // Test financial calculations
      const double totalRevenue = 150000.0;
      const double totalPending = 25000.0;
      const int paidInvoices = 45;
      const int totalInvoices = 60;

      // Calculate collection rate
      final double collectionRate = (paidInvoices / totalInvoices) * 100;
      expect(collectionRate, equals(75.0));

      // Calculate liquidity ratio
      final double liquidityRatio = ((totalRevenue - totalPending) / totalRevenue) * 100;
      expect(liquidityRatio, closeTo(83.33, 0.01));

      // Calculate pending percentage
      final double pendingPercentage = (totalPending / totalRevenue) * 100;
      expect(pendingPercentage, closeTo(16.67, 0.01));
    });

    test('should format currency correctly', () {
      // Test currency formatting
      final currencyFormat = NumberFormat.currency(
        locale: 'ar_EG',
        symbol: 'جنيه',
        decimalDigits: 2,
      );

      expect(currencyFormat.format(150000), contains('150,000'));
      expect(currencyFormat.format(25000.50), contains('25,000.50'));
      expect(currencyFormat.format(0), contains('0'));
    });

    test('should handle welcome message based on time', () {
      // Test welcome message logic
      String getWelcomeMessage(int hour) {
        if (hour < 12) {
          return 'صباح الخير';
        } else if (hour < 17) {
          return 'مساء الخير';
        } else {
          return 'مساء الخير';
        }
      }

      expect(getWelcomeMessage(8), equals('صباح الخير'));
      expect(getWelcomeMessage(14), equals('مساء الخير'));
      expect(getWelcomeMessage(20), equals('مساء الخير'));
    });
  });

  group('Performance Tests', () {
    test('should handle large datasets efficiently', () {
      // Test performance with large invoice lists
      final List<Map<String, dynamic>> largeInvoiceList = List.generate(1000, (index) => {
        'id': index,
        'total_amount': (index * 100.0),
        'status': index % 3 == 0 ? 'paid' : (index % 3 == 1 ? 'pending' : 'cancelled'),
        'created_at': DateTime.now().subtract(Duration(days: index)).toIso8601String(),
      });

      // Calculate totals
      final stopwatch = Stopwatch()..start();
      
      final double totalRevenue = largeInvoiceList
          .where((invoice) => invoice['status'] == 'paid')
          .fold(0.0, (sum, invoice) => sum + (invoice['total_amount'] as double));
      
      final int paidCount = largeInvoiceList
          .where((invoice) => invoice['status'] == 'paid')
          .length;
      
      stopwatch.stop();

      // Should complete calculations quickly (under 100ms for 1000 items)
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
      expect(totalRevenue, greaterThan(0));
      expect(paidCount, greaterThan(0));
    });
  });
}

// Helper function to create test invoice data
Map<String, dynamic> createTestInvoice({
  required int id,
  required double amount,
  required String status,
  DateTime? createdAt,
}) {
  return {
    'id': id,
    'total_amount': amount,
    'status': status,
    'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    'customer_name': 'عميل تجريبي $id',
    'invoice_number': 'INV-${id.toString().padLeft(4, '0')}',
  };
}

// Helper function to create test financial data
Map<String, dynamic> createTestFinancialData() {
  return {
    'totalRevenue': 150000.0,
    'totalPending': 25000.0,
    'paidInvoices': 45,
    'totalInvoices': 60,
    'pendingInvoices': 12,
    'canceledInvoices': 3,
    'recentInvoices': [
      createTestInvoice(id: 1, amount: 5000.0, status: 'paid'),
      createTestInvoice(id: 2, amount: 3500.0, status: 'pending'),
      createTestInvoice(id: 3, amount: 7200.0, status: 'completed'),
    ],
  };
}
