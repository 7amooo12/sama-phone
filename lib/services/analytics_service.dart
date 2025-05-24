import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/analytics_dashboard_model.dart';

class AnalyticsService {
  // نمط Singleton
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  // الثوابت
  static const String _baseUrl = 'https://samastock.pythonanywhere.com'; // قم بتغيير هذا للرابط الفعلي الخاص بك
  static const String _flutterApiKey = 'lux2025FlutterAccess';
  static const String _adminDashboardApiKey = 'sm@rtadmin2025Key';

  // الحصول على بيانات لوحة التحكم التحليلية
  Future<AnalyticsDashboardModel> getDashboardAnalytics() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/flutter/api/analytics/dashboard'),
        headers: {
          'x-api-key': _flutterApiKey,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['analytics'] != null) {
          return AnalyticsDashboardModel.fromJson(data['analytics']);
        }
        throw Exception('API returned success false or no analytics data');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid API key');
      } else {
        throw Exception('Failed to load analytics: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching analytics: $e');
      rethrow;
    }
  }

  // الحصول على بيانات لوحة التحكم للمسؤول (مشروع الويب)
  Future<AnalyticsDashboardModel> getAdminDashboardAnalytics() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/admin/dashboard'),
        headers: {
          'X-API-KEY': _adminDashboardApiKey,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['analytics'] != null) {
          return AnalyticsDashboardModel.fromJson(data['analytics']);
        }
        throw Exception('API returned success false or no analytics data');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid API key');
      } else {
        throw Exception('Failed to load admin analytics: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching admin analytics: $e');
      rethrow;
    }
  }

  // دالة مساعدة للتحقق من صحة الرد
  bool _isValidResponse(http.Response response) {
    return response.statusCode == 200 && 
           json.decode(response.body)['success'] == true;
  }
} 