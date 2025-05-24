import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

/// Service for analytics and reporting
class SamaAnalyticsService {
  static final SamaAnalyticsService _instance = SamaAnalyticsService._internal();
  factory SamaAnalyticsService() => _instance;

  SamaAnalyticsService._internal();

  // Using the correct admin API endpoint
  static const String baseUrl = 'https://samastock.pythonanywhere.com/api/admin';
  
  // API Key for admin dashboard
  static const String apiKey = 'sm@rtadmin2025Key';
  
  // Use demo mode when API is not available
  final bool _useDemoData = false; // Changed to false to use real API data
  
  /// Get all analytics data for the dashboard
  Future<Map<String, dynamic>> getAllAnalytics() async {
    try {
      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 500));

      // Return mock data
      return {
        'sales': {
          'today': 1500,
          'yesterday': 1200,
          'thisWeek': 9500,
          'lastWeek': 8200,
          'thisMonth': 35000,
          'lastMonth': 32000,
          'trend': 8.5, // percentage increase
        },
        'orders': {
          'today': 12,
          'thisWeek': 87,
          'thisMonth': 320,
          'pending': 15,
          'processing': 22,
          'completed': 283,
          'cancelled': 10,
        },
        'products': {
          'total': 150,
          'inStock': 120,
          'lowStock': 15,
          'outOfStock': 15,
          'topSelling': [
            {'id': 1, 'name': 'Product 1', 'sales': 52},
            {'id': 2, 'name': 'Product 2', 'sales': 48},
            {'id': 3, 'name': 'Product 3', 'sales': 35},
            {'id': 4, 'name': 'Product 4', 'sales': 30},
            {'id': 5, 'name': 'Product 5', 'sales': 25},
          ],
        },
        'customers': {
          'total': 250,
          'new': 15,
          'returning': 235,
          'topSpenders': [
            {'id': 1, 'name': 'Customer 1', 'total': 5200},
            {'id': 2, 'name': 'Customer 2', 'total': 4800},
            {'id': 3, 'name': 'Customer 3', 'total': 3500},
          ],
        },
        'financial': {
          'totalRevenue': 35000,
          'expenses': 12000,
          'profit': 23000,
          'profitMargin': 65.7,
        },
        'workers': {
          'total': 10,
          'active': 8,
          'performance': [
            {'id': 1, 'name': 'Worker 1', 'efficiency': 95, 'ordersCompleted': 52},
            {'id': 2, 'name': 'Worker 2', 'efficiency': 88, 'ordersCompleted': 48},
            {'id': 3, 'name': 'Worker 3', 'efficiency': 82, 'ordersCompleted': 35},
          ],
        },
      };
    } catch (e) {
      AppLogger.error('Error fetching analytics: $e');
      rethrow;
    }
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
} 