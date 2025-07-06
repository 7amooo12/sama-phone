import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';

/// Service for analytics and reporting
class SamaAnalyticsService {
  factory SamaAnalyticsService() => _instance;

  SamaAnalyticsService._internal();
  static final SamaAnalyticsService _instance = SamaAnalyticsService._internal();

  // Using the correct admin API endpoint
  static const String baseUrl = 'https://samastock.pythonanywhere.com/api/admin';

  // API Key for admin dashboard
  static const String apiKey = 'sm@rtadmin2025Key';

  // Use demo mode when API is not available
  final bool _useDemoData = false; // Changed to false to use real API data

  // Supabase client for real data
  final SupabaseClient _supabase = Supabase.instance.client;
  
  /// Get real analytics data from Supabase
  Future<Map<String, dynamic>> getRealAnalytics() async {
    try {
      AppLogger.info('🔄 جلب البيانات التحليلية الحقيقية...');

      // جلب البيانات بشكل متوازي
      final results = await Future.wait([
        _getCustomerAnalytics(),
        _getProductAnalytics(),
        _getSalesAnalytics(),
        _getWalletAnalytics(),
        _getTopSellingProducts(),
      ]);

      final customerAnalytics = results[0] as Map<String, dynamic>;
      final productAnalytics = results[1] as Map<String, dynamic>;
      final salesAnalytics = results[2] as Map<String, dynamic>;
      final walletAnalytics = results[3] as Map<String, dynamic>;
      final topProducts = results[4] as List<Map<String, dynamic>>;

      AppLogger.info('✅ تم جلب البيانات التحليلية بنجاح');

      return {
        'customers': customerAnalytics,
        'products': productAnalytics,
        'sales': salesAnalytics,
        'financial': walletAnalytics,
        'top_products': topProducts,
      };
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب البيانات التحليلية: $e');
      // إرجاع بيانات وهمية في حالة الخطأ
      return _getFallbackData();
    }
  }

  /// Get all analytics data for the dashboard
  Future<Map<String, dynamic>> getAllAnalytics() async {
    try {
      // استخدام البيانات الحقيقية بدلاً من الوهمية
      return await getRealAnalytics();
    } catch (e) {
      AppLogger.error('خطأ في جلب التحليلات: $e');
      // العودة للبيانات الوهمية في حالة الخطأ
      return _getFallbackData();
    }
  }

  /// Get fallback data with minimal values (no fake data)
  Map<String, dynamic> _getFallbackData() {
    return {
        'sales': {
          'today': 0,
          'yesterday': 0,
          'thisWeek': 0,
          'lastWeek': 0,
          'thisMonth': 0,
          'lastMonth': 0,
          'trend': 0.0,
        },
        'orders': {
          'today': 0,
          'thisWeek': 0,
          'thisMonth': 0,
          'pending': 0,
          'processing': 0,
          'completed': 0,
          'cancelled': 0,
        },
        'products': {
          'total': 0,
          'inStock': 0,
          'lowStock': 0,
          'outOfStock': 0,
          'topSelling': [],
        },
        'customers': {
          'total': 0,
          'new': 0,
          'returning': 0,
          'topSpenders': [],
        },
        'financial': {
          'totalRevenue': 0,
          'expenses': 0,
          'profit': 0,
          'profitMargin': 0.0,
        },
        'workers': {
          'total': 0,
          'active': 0,
          'performance': [],
        },
      };
  }
  
  // بيانات تجريبية للعرض عند عدم توفر الاتصال
  Map<String, dynamic> _getDemoData() {
    return {
      'success': true,
      'analytics': {
        'sales': {
          'total_amount': 510640.0,
          'total_invoices': 91,
          'completed_invoices': 14,
          'pending_invoices': 77,
          'daily': List.generate(30, (index) => {
            'date': '2025-05-${15 - index}',
            'sales': index == 29 ? 82550.0 : 0.0
          }),
          'by_category': [
            {'category': 'دلاية', 'sales': 452150.0},
            {'category': 'ابليك', 'sales': 0},
            {'category': 'دلاية مفرد', 'sales': 12800.0},
            {'category': 'اباجورة', 'sales': 0},
            {'category': 'كريستال', 'sales': 45690.0},
            {'category': 'لامبدير', 'sales': 0},
            {'category': 'هاي باور', 'sales': 0},
          ]
        },
        'products': {
          'total': 266,
          'visible': 173,
          'featured': 12,
          'out_of_stock': 63,
          'inventory_cost': 2500000.0,
          'inventory_value': 3750000.0
        },
        'inventory': {
          'movement': {
            'additions': 0,
            'reductions': 100,
            'total_quantity_change': -2604
          }
        },
        'users': {
          'total': 1,
          'active': 1,
          'pending': 0
        }
      }
    };
  }

  /// Get sales analytics for specific time periods
  Future<Map<String, dynamic>> getSalesAnalytics({
    required String period, // daily, weekly, monthly, yearly
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 300));

      // Generate mock data based on period
      final now = DateTime.now();
      final data = <String, dynamic>{};
      
      if (period == 'daily') {
        // Hourly data for the current day
        final hourlyData = <Map<String, dynamic>>[];
        for (int i = 0; i < 24; i++) {
          hourlyData.add({
            'hour': i,
            'sales': 100 + (i * 25) + (i % 3 == 0 ? 50 : 0),
            'orders': 1 + (i % 5),
          });
        }
        data['hourly'] = hourlyData;
      } else if (period == 'weekly') {
        // Daily data for the week
        final dailyData = <Map<String, dynamic>>[];
        for (int i = 0; i < 7; i++) {
          dailyData.add({
            'day': now.subtract(Duration(days: 6 - i)).toString().substring(0, 10),
            'sales': 500 + (i * 150) + (i % 2 == 0 ? 200 : 0),
            'orders': 5 + (i * 2),
          });
        }
        data['daily'] = dailyData;
      } else if (period == 'monthly') {
        // Weekly data for the month
        final weeklyData = <Map<String, dynamic>>[];
        for (int i = 0; i < 4; i++) {
          weeklyData.add({
            'week': 'Week ${i + 1}',
            'sales': 3500 + (i * 500) + (i % 2 == 0 ? 300 : 0),
            'orders': 35 + (i * 5),
          });
        }
        data['weekly'] = weeklyData;
      } else {
        // Monthly data for the year
        final monthlyData = <Map<String, dynamic>>[];
        for (int i = 0; i < 12; i++) {
          monthlyData.add({
            'month': i + 1,
            'sales': 15000 + (i * 1200) + (i % 3 == 0 ? 2000 : 0),
            'orders': 120 + (i * 10),
          });
        }
        data['monthly'] = monthlyData;
      }
      
      return data;
    } catch (e) {
      AppLogger.error('Error fetching sales analytics: $e');
      rethrow;
    }
  }

  /// Track a specific event for analytics
  Future<void> trackEvent(String eventName, Map<String, dynamic> properties) async {
    try {
      // In a real app, this would send data to an analytics service
      AppLogger.info('Tracking event: $eventName, properties: $properties');
      
      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      AppLogger.error('Error tracking event: $e');
    }
  }

  /// Export analytics data to a report format
  Future<String> exportAnalyticsReport(String reportType) async {
    try {
      // Simulate report generation
      await Future.delayed(const Duration(seconds: 1));

      return 'https://example.com/reports/mock-report-$reportType.pdf';
    } catch (e) {
      AppLogger.error('Error generating report: $e');
      rethrow;
    }
  }

  // ===== طرق جلب البيانات الحقيقية =====

  /// جلب إحصائيات العملاء الحقيقية
  Future<Map<String, dynamic>> _getCustomerAnalytics() async {
    try {
      // جلب إجمالي العملاء
      final totalCustomersResponse = await _supabase
          .from('user_profiles')
          .select('id')
          .eq('role', 'client');

      // جلب العملاء النشطين
      final activeCustomersResponse = await _supabase
          .from('user_profiles')
          .select('id')
          .eq('role', 'client')
          .eq('status', 'active');

      // جلب العملاء الجدد (آخر 30 يوم)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final newCustomersResponse = await _supabase
          .from('user_profiles')
          .select('id')
          .eq('role', 'client')
          .filter('created_at', 'gte', thirtyDaysAgo.toIso8601String());

      final totalCustomers = totalCustomersResponse.length;
      final activeCustomers = activeCustomersResponse.length;
      final newCustomers = newCustomersResponse.length;
      final returningCustomers = totalCustomers - newCustomers;

      // حساب معدل الاحتفاظ
      final retentionRate = totalCustomers > 0
          ? (returningCustomers / totalCustomers) * 100
          : 0.0;

      return {
        'total': totalCustomers,
        'active': activeCustomers,
        'new': newCustomers,
        'returning': returningCustomers,
        'retention_rate': retentionRate,
      };
    } catch (e) {
      AppLogger.error('خطأ في جلب إحصائيات العملاء: $e');
      return {
        'total': 0,
        'active': 0,
        'new': 0,
        'returning': 0,
        'retention_rate': 0.0,
      };
    }
  }

  /// جلب إحصائيات المنتجات الحقيقية
  Future<Map<String, dynamic>> _getProductAnalytics() async {
    try {
      // جلب إجمالي المنتجات من Flask API
      final response = await http.get(
        Uri.parse('$baseUrl/analytics'),
        headers: {'X-API-Key': apiKey},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['analytics'] != null) {
          final products = data['analytics']['products'];
          return {
            'total': products['total'] ?? 0,
            'visible': products['visible'] ?? 0,
            'inStock': products['total'] - (products['out_of_stock'] ?? 0),
            'lowStock': 0, // يمكن إضافة هذا لاحقاً
            'outOfStock': products['out_of_stock'] ?? 0,
          };
        }
      }

      // بيانات احتياطية
      return {
        'total': 0,
        'visible': 0,
        'inStock': 0,
        'lowStock': 0,
        'outOfStock': 0,
      };
    } catch (e) {
      AppLogger.error('خطأ في جلب إحصائيات المنتجات: $e');
      return {
        'total': 0,
        'visible': 0,
        'inStock': 0,
        'lowStock': 0,
        'outOfStock': 0,
      };
    }
  }

  /// جلب إحصائيات المبيعات الحقيقية
  Future<Map<String, dynamic>> _getSalesAnalytics() async {
    try {
      // جلب الفواتير من Flask API
      final response = await http.get(
        Uri.parse('$baseUrl/analytics'),
        headers: {'X-API-Key': apiKey},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['analytics'] != null) {
          final sales = data['analytics']['sales'];
          return {
            'today': 0, // يمكن حسابها من البيانات اليومية
            'thisWeek': 0,
            'thisMonth': sales['total_amount'] ?? 0,
            'totalInvoices': sales['total_invoices'] ?? 0,
            'completedInvoices': sales['completed_invoices'] ?? 0,
            'pendingInvoices': sales['pending_invoices'] ?? 0,
            'trend': 0.0,
          };
        }
      }

      return {
        'today': 0,
        'thisWeek': 0,
        'thisMonth': 0,
        'totalInvoices': 0,
        'completedInvoices': 0,
        'pendingInvoices': 0,
        'trend': 0.0,
      };
    } catch (e) {
      AppLogger.error('خطأ في جلب إحصائيات المبيعات: $e');
      return {
        'today': 0,
        'thisWeek': 0,
        'thisMonth': 0,
        'totalInvoices': 0,
        'completedInvoices': 0,
        'pendingInvoices': 0,
        'trend': 0.0,
      };
    }
  }

  /// جلب إحصائيات المحافظ الحقيقية
  Future<Map<String, dynamic>> _getWalletAnalytics() async {
    try {
      // جلب إجمالي أرصدة المحافظ
      final walletsResponse = await _supabase
          .from('wallets')
          .select('balance, role')
          .eq('status', 'active');

      double totalRevenue = 0.0;
      double clientBalance = 0.0;
      double workerBalance = 0.0;

      for (final wallet in walletsResponse) {
        final balance = (wallet['balance'] as num).toDouble();
        final role = wallet['role'] as String;

        totalRevenue += balance;

        if (role == 'client') {
          clientBalance += balance;
        } else if (role == 'worker') {
          workerBalance += balance;
        }
      }

      return {
        'totalRevenue': totalRevenue,
        'clientBalance': clientBalance,
        'workerBalance': workerBalance,
        'expenses': 0.0, // يمكن حسابها من المعاملات
        'profit': totalRevenue, // مبسط
        'profitMargin': totalRevenue > 0 ? 100.0 : 0.0,
      };
    } catch (e) {
      AppLogger.error('خطأ في جلب إحصائيات المحافظ: $e');
      return {
        'totalRevenue': 0.0,
        'clientBalance': 0.0,
        'workerBalance': 0.0,
        'expenses': 0.0,
        'profit': 0.0,
        'profitMargin': 0.0,
      };
    }
  }

  /// جلب المنتجات الأكثر مبيعاً من الفواتير الحقيقية
  Future<List<Map<String, dynamic>>> _getTopSellingProducts() async {
    try {
      AppLogger.info('🔄 جلب المنتجات الأكثر مبيعاً...');

      // جلب بيانات الفواتير من Flask API
      final response = await http.get(
        Uri.parse('https://samastock.pythonanywhere.com/api/invoices'),
        headers: {
          'X-API-Key': 'lux2025FlutterAccess',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['invoices'] != null) {
          final invoices = data['invoices'] as List;

          // حساب كمية المبيعات لكل منتج
          final Map<String, Map<String, dynamic>> productSales = {};

          for (final invoice in invoices) {
            if (invoice['status'] == 'completed' && invoice['items'] != null) {
              final items = invoice['items'] as List;

              for (final item in items) {
                final productName = item['product_name'] as String? ?? 'منتج غير معروف';
                final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
                final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                final total = quantity * price;

                if (productSales.containsKey(productName)) {
                  productSales[productName]!['sales'] =
                      (productSales[productName]!['sales'] as double) + quantity;
                  productSales[productName]!['revenue'] =
                      (productSales[productName]!['revenue'] as double) + total;
                } else {
                  productSales[productName] = {
                    'name': productName,
                    'sales': quantity,
                    'revenue': total,
                  };
                }
              }
            }
          }

          // ترتيب المنتجات حسب الكمية المباعة
          final sortedProducts = productSales.values.toList()
            ..sort((a, b) => (b['sales'] as double).compareTo(a['sales'] as double));

          // إرجاع أفضل 5 منتجات
          final topProducts = sortedProducts.take(5).map((product) => {
            'name': product['name'],
            'sales': (product['sales'] as double).toInt(),
            'revenue': (product['revenue'] as double).toStringAsFixed(2),
          }).toList();

          AppLogger.info('✅ تم جلب ${topProducts.length} منتج من الأكثر مبيعاً');
          return topProducts;
        }
      }

      AppLogger.warning('⚠️ لم يتم العثور على بيانات فواتير');
      return [];

    } catch (e) {
      AppLogger.error('❌ خطأ في جلب المنتجات الأكثر مبيعاً: $e');
      return [];
    }
  }
}