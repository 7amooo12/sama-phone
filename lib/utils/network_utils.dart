import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Utility class for network-related operations
class NetworkUtils {
  static const Duration _defaultTimeout = Duration(seconds: 5);

  /// Check if device has internet connectivity
  static Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }

      // Additional check by trying to reach a reliable host
      return await canReachHost('8.8.8.8', 53);
    } catch (e) {
      AppLogger.error('خطأ في فحص الاتصال بالإنترنت', e);
      return false;
    }
  }

  /// Check if a specific host is reachable
  static Future<bool> canReachHost(String host, int port, {Duration? timeout}) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: timeout ?? _defaultTimeout,
      );
      socket.destroy();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if the main API server is reachable
  static Future<bool> canReachApiServer() async {
    const hosts = [
      'samastock.pythonanywhere.com',
      'stockwarehouse.pythonanywhere.com',
    ];

    for (final host in hosts) {
      if (await canReachHost(host, 443)) {
        AppLogger.info('✅ يمكن الوصول للخادم: $host');
        return true;
      }
    }

    AppLogger.warning('⚠️ لا يمكن الوصول لأي من الخوادم');
    return false;
  }

  /// Get network error message based on error type
  static String getNetworkErrorMessage(String error) {
    if (error.contains('Failed host lookup') || 
        error.contains('No address associated with hostname')) {
      return 'لا يمكن الاتصال بالخادم. تحقق من اتصالك بالإنترنت';
    } else if (error.contains('Connection refused') || 
               error.contains('Connection timed out')) {
      return 'انتهت مهلة الاتصال. يرجى المحاولة لاحقاً';
    } else if (error.contains('SocketException')) {
      return 'خطأ في الشبكة. تحقق من اتصالك بالإنترنت';
    } else if (error.contains('TimeoutException')) {
      return 'انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى';
    } else if (error.contains('HandshakeException')) {
      return 'خطأ في الأمان. تحقق من إعدادات الشبكة';
    } else {
      return 'حدث خطأ في الاتصال. يرجى المحاولة مرة أخرى';
    }
  }

  /// Check if error is network-related
  static bool isNetworkError(String error) {
    return error.contains('Failed host lookup') ||
           error.contains('No address associated with hostname') ||
           error.contains('Connection refused') ||
           error.contains('Connection timed out') ||
           error.contains('SocketException') ||
           error.contains('TimeoutException') ||
           error.contains('HandshakeException');
  }

  /// Get connectivity status as string
  static Future<String> getConnectivityStatus() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      
      switch (connectivityResult) {
        case ConnectivityResult.wifi:
          return 'WiFi';
        case ConnectivityResult.mobile:
          return 'بيانات الجوال';
        case ConnectivityResult.ethernet:
          return 'إيثرنت';
        case ConnectivityResult.none:
          return 'غير متصل';
        default:
          return 'غير معروف';
      }
    } catch (e) {
      return 'خطأ في فحص الاتصال';
    }
  }

  /// Perform network diagnostics
  static Future<Map<String, dynamic>> performNetworkDiagnostics() async {
    final diagnostics = <String, dynamic>{};
    
    try {
      // Check basic connectivity
      diagnostics['hasConnectivity'] = await hasInternetConnection();
      diagnostics['connectivityType'] = await getConnectivityStatus();
      
      // Check API servers
      diagnostics['canReachApiServer'] = await canReachApiServer();
      diagnostics['canReachGoogle'] = await canReachHost('8.8.8.8', 53);
      
      // Check specific hosts
      diagnostics['samastock'] = await canReachHost('samastock.pythonanywhere.com', 443);
      diagnostics['stockwarehouse'] = await canReachHost('stockwarehouse.pythonanywhere.com', 443);
      
      diagnostics['timestamp'] = DateTime.now().toIso8601String();
      
      AppLogger.info('🔍 تشخيص الشبكة: $diagnostics');
      
    } catch (e) {
      AppLogger.error('خطأ في تشخيص الشبكة', e);
      diagnostics['error'] = e.toString();
    }
    
    return diagnostics;
  }

  /// Wait for network connectivity to be restored
  static Future<bool> waitForConnectivity({Duration timeout = const Duration(seconds: 30)}) async {
    final startTime = DateTime.now();
    
    while (DateTime.now().difference(startTime) < timeout) {
      if (await hasInternetConnection()) {
        return true;
      }
      
      await Future.delayed(const Duration(seconds: 2));
    }
    
    return false;
  }
}
