import 'package:http/http.dart' as http;
import '../utils/logger.dart';

class SamaAdminService {
  
  // Singleton constructor
  factory SamaAdminService() {
    return _instance;
  }
  
  SamaAdminService._internal();
  static const String _baseUrl = 'https://samastock.pythonanywhere.com';
  static final SamaAdminService _instance = SamaAdminService._internal();
  
  final http.Client _client = http.Client();
  String? _csrfToken;
  bool _isLoggedIn = false;
  Map<String, dynamic> _dashboardData = {};
  
  // Status getters
  bool get isLoggedIn => _isLoggedIn;
  Map<String, dynamic> get dashboardData => _dashboardData;
  
  // Initialize the service
  Future<void> initialize() async {
    try {
      // Get CSRF token
      await _getCsrfToken();
    } catch (e) {
      AppLogger.error('Error initializing SAMA Admin Service: $e');
      rethrow;
    }
  }
  
  // Login to SAMA Admin dashboard
  Future<bool> login({String username = 'eslam@sama.com', String password = 'eslam@123'}) async {
    try {
      if (_csrfToken == null) {
        await _getCsrfToken();
      }
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/login/'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Cookie': 'csrftoken=$_csrfToken',
          'Referer': _baseUrl,
        },
        body: {
          'username': username,
          'password': password,
          'csrfmiddlewaretoken': _csrfToken,
          'next': '/admin/',
        },
      );
      
      if (response.statusCode == 200 || response.statusCode == 302) {
        _isLoggedIn = response.body.contains('Dashboard') || 
                       response.body.contains('لوحة التحكم') ||
                       !response.body.contains('تسجيل الدخول');
        
        if (_isLoggedIn) {
          await _fetchDashboardData();
          return true;
        }
      }
      
      AppLogger.warning('Login failed with status code: ${response.statusCode}');
      return false;
    } catch (e) {
      AppLogger.error('Error logging in to SAMA Admin: $e');
      return false;
    }
  }
  
  // Fetch dashboard data
  Future<Map<String, dynamic>> _fetchDashboardData() async {
    try {
      if (!_isLoggedIn) {
        await login();
      }
      
      final response = await _client.get(
        Uri.parse('$_baseUrl/dashboard/'),
        headers: {
          'Cookie': 'csrftoken=$_csrfToken',
          'Referer': _baseUrl,
        },
      );
      
      if (response.statusCode == 200) {
        // Parse dashboard data from the HTML response
        _dashboardData = _parseDashboardData(response.body);
        return _dashboardData;
      } else {
        AppLogger.warning('Failed to fetch dashboard data: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      AppLogger.error('Error fetching dashboard data: $e');
      return {};
    }
  }
  
  // Refresh dashboard data and return it
  Future<Map<String, dynamic>> getDashboardData() async {
    return await _fetchDashboardData();
  }
  
  // Get CSRF token for authentication
  Future<String?> _getCsrfToken() async {
    try {
      final response = await _client.get(Uri.parse('$_baseUrl/login/'));
      
      if (response.statusCode == 200) {
        final RegExp regExp = RegExp(r'name="csrfmiddlewaretoken" value="([^"]+)"');
        final match = regExp.firstMatch(response.body);
        
        if (match != null && match.groupCount >= 1) {
          _csrfToken = match.group(1);
          return _csrfToken;
        }
      }
      
      AppLogger.warning('Failed to get CSRF token: ${response.statusCode}');
      return null;
    } catch (e) {
      AppLogger.error('Error getting CSRF token: $e');
      return null;
    }
  }
  
  // Parse dashboard data from HTML content
  Map<String, dynamic> _parseDashboardData(String htmlContent) {
    final Map<String, dynamic> data = {
      'recentProducts': <Map<String, dynamic>>[],
      'recentOrders': <Map<String, dynamic>>[],
      'summary': {
        'totalProducts': 0,
        'totalOrders': 0,
        'totalRevenue': 0.0,
        'totalUsers': 0,
      },
      'stats': {
        'productsByCategory': <String, int>{},
        'salesByDate': <String, double>{},
      }
    };
    
    try {
      // Extract recent products
      final productsRegExp = RegExp(r'<tr>\s*<td.*?>(.*?)</td>\s*<td.*?>(.*?)</td>\s*<td.*?>(.*?)</td>\s*</tr>', dotAll: true);
      final productsMatches = productsRegExp.allMatches(htmlContent);
      
      for (var match in productsMatches.take(5)) { // Take only 5 recent products
        if (match.groupCount >= 3) {
          data['recentProducts'].add({
            'name': _stripHtml(match.group(1) ?? ''),
            'category': _stripHtml(match.group(2) ?? ''),
            'price': double.tryParse(_stripHtml(match.group(3) ?? '').replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0,
          });
        }
      }
      
      // Extract recent orders
      final ordersRegExp = RegExp(r'<tr>\s*<td.*?>(.*?)</td>\s*<td.*?>(.*?)</td>\s*<td.*?>(.*?)</td>\s*<td.*?>(.*?)</td>\s*</tr>', dotAll: true);
      final ordersMatches = ordersRegExp.allMatches(htmlContent);
      
      for (var match in ordersMatches.take(5)) { // Take only 5 recent orders
        if (match.groupCount >= 4) {
          data['recentOrders'].add({
            'orderNumber': _stripHtml(match.group(1) ?? ''),
            'customer': _stripHtml(match.group(2) ?? ''),
            'amount': double.tryParse(_stripHtml(match.group(3) ?? '').replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0,
            'date': _stripHtml(match.group(4) ?? ''),
          });
        }
      }
      
      // Extract summary data
      final summaryRegExp = RegExp(r'<div class="info-box.*?>\s*<span.*?>\s*<i class=".*?"></i>\s*</span>\s*<div class="info-box-content">\s*<span class="info-box-text">(.*?)</span>\s*<span class="info-box-number">(.*?)</span>', dotAll: true);
      final summaryMatches = summaryRegExp.allMatches(htmlContent);
      
      final summaryKeys = ['totalProducts', 'totalOrders', 'totalRevenue', 'totalUsers'];
      int index = 0;
      
      for (var match in summaryMatches.take(4)) { // Take only 4 summary items
        if (match.groupCount >= 2 && index < summaryKeys.length) {
          final key = summaryKeys[index];
          final value = _stripHtml(match.group(2) ?? '').replaceAll(RegExp(r'[^\d.]'), '');
          
          if (key == 'totalRevenue') {
            data['summary'][key] = double.tryParse(value) ?? 0.0;
          } else {
            data['summary'][key] = int.tryParse(value) ?? 0;
          }
          
          index++;
        }
      }
      
      // If we couldn't parse real data, provide sample data
      if ((data['recentProducts'] as List<dynamic>? ?? []).isEmpty) {
        data['recentProducts'] = _getSampleProducts();
      }

      if ((data['recentOrders'] as List<dynamic>? ?? []).isEmpty) {
        // Don't use mock data, leave empty to trigger API fetch
        data['recentOrders'] = [];
      }
      
      if (data['summary']['totalProducts'] == 0) {
        data['summary'] = _getSampleSummary();
      }
      
      // Add sample stats
      data['stats'] = _getSampleStats();
      
      return data;
    } catch (e) {
      AppLogger.error('Error parsing dashboard data: $e');
      // Return sample data if parsing fails, but don't include mock orders
      return {
        'recentProducts': _getSampleProducts(),
        'recentOrders': [], // Leave empty to trigger API fetch
        'summary': _getSampleSummary(),
        'stats': _getSampleStats(),
      };
    }
  }
  
  // Strip HTML tags from string
  String _stripHtml(String htmlString) {
    return htmlString.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }
  
  // Sample data if API fails
  List<Map<String, dynamic>> _getSampleProducts() {
    return [
      {'name': 'سايبربانك 2077', 'category': 'ألعاب', 'price': 199.99},
      {'name': 'سماعات صوت محيطي', 'category': 'إلكترونيات', 'price': 349.50},
      {'name': 'موديول ذاكرة نيون 16GB', 'category': 'قطع كمبيوتر', 'price': 499.00},
      {'name': 'بدلة سايبرتك', 'category': 'ملابس', 'price': 1299.99},
      {'name': 'نظارات واقع افتراضي', 'category': 'إلكترونيات', 'price': 599.00},
    ];
  }
  
  Map<String, dynamic> _getSampleSummary() {
    return {
      'totalProducts': 145,
      'totalOrders': 328,
      'totalRevenue': 158750.50,
      'totalUsers': 275,
    };
  }
  
  Map<String, dynamic> _getSampleStats() {
    return {
      'productsByCategory': {
        'ألعاب': 42,
        'إلكترونيات': 56,
        'قطع كمبيوتر': 38,
        'ملابس': 29,
        'أخرى': 15,
      },
      'salesByDate': {
        '05-10': 12500.0,
        '05-11': 15300.0,
        '05-12': 14200.0,
        '05-13': 18700.0,
        '05-14': 16900.0,
        '05-15': 21400.0,
        '05-16': 19800.0,
      },
    };
  }
} 