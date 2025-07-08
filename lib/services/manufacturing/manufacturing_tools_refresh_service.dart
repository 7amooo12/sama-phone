import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/manufacturing/production_batch.dart';
import 'package:smartbiztracker_new/services/manufacturing/production_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// حالة التحديث
enum RefreshState {
  idle,
  refreshing,
  success,
  error,
}

/// نتيجة التحديث
class RefreshResult {
  final RefreshState state;
  final String? message;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  const RefreshResult({
    required this.state,
    this.message,
    required this.timestamp,
    this.data,
  });

  factory RefreshResult.success({String? message, Map<String, dynamic>? data}) {
    return RefreshResult(
      state: RefreshState.success,
      message: message,
      timestamp: DateTime.now(),
      data: data,
    );
  }

  factory RefreshResult.error(String message) {
    return RefreshResult(
      state: RefreshState.error,
      message: message,
      timestamp: DateTime.now(),
    );
  }

  factory RefreshResult.idle() {
    return RefreshResult(
      state: RefreshState.idle,
      timestamp: DateTime.now(),
    );
  }

  bool get isSuccess => state == RefreshState.success;
  bool get isError => state == RefreshState.error;
  bool get isRefreshing => state == RefreshState.refreshing;
  bool get isIdle => state == RefreshState.idle;
}

/// بيانات أدوات التصنيع المحدثة
class ManufacturingToolsData {
  final List<ToolUsageAnalytics> toolAnalytics;
  final ProductionGapAnalysis? gapAnalysis;
  final RequiredToolsForecast? toolsForecast;
  final DateTime lastUpdated;

  const ManufacturingToolsData({
    required this.toolAnalytics,
    this.gapAnalysis,
    this.toolsForecast,
    required this.lastUpdated,
  });

  /// نسخ مع تحديث البيانات
  ManufacturingToolsData copyWith({
    List<ToolUsageAnalytics>? toolAnalytics,
    ProductionGapAnalysis? gapAnalysis,
    RequiredToolsForecast? toolsForecast,
    DateTime? lastUpdated,
  }) {
    return ManufacturingToolsData(
      toolAnalytics: toolAnalytics ?? this.toolAnalytics,
      gapAnalysis: gapAnalysis ?? this.gapAnalysis,
      toolsForecast: toolsForecast ?? this.toolsForecast,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// التحقق من وجود بيانات
  bool get hasData => toolAnalytics.isNotEmpty || gapAnalysis != null || toolsForecast != null;

  /// عدد العناصر الإجمالي
  int get totalItems => toolAnalytics.length + 
      (gapAnalysis != null ? 1 : 0) + 
      (toolsForecast != null ? 1 : 0);
}

/// خدمة تحديث بيانات أدوات التصنيع
class ManufacturingToolsRefreshService extends ChangeNotifier {
  final ProductionService _productionService;
  
  // حالة التحديث
  RefreshState _refreshState = RefreshState.idle;
  String? _lastErrorMessage;
  DateTime? _lastRefreshTime;
  
  // البيانات المحدثة
  ManufacturingToolsData? _currentData;
  
  // إعدادات التحديث التلقائي
  Timer? _autoRefreshTimer;
  Duration _autoRefreshInterval = const Duration(minutes: 5);
  bool _autoRefreshEnabled = false;
  
  // معرفات للتتبع
  int? _currentBatchId;
  int? _currentProductId;

  ManufacturingToolsRefreshService(this._productionService);

  // Getters
  RefreshState get refreshState => _refreshState;
  String? get lastErrorMessage => _lastErrorMessage;
  DateTime? get lastRefreshTime => _lastRefreshTime;
  ManufacturingToolsData? get currentData => _currentData;
  bool get autoRefreshEnabled => _autoRefreshEnabled;
  Duration get autoRefreshInterval => _autoRefreshInterval;
  bool get isRefreshing => _refreshState == RefreshState.refreshing;
  bool get hasError => _refreshState == RefreshState.error;

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  /// تهيئة الخدمة مع معرفات الدفعة والمنتج
  void initialize({
    required int batchId,
    required int productId,
    bool enableAutoRefresh = false,
    Duration? autoRefreshInterval,
  }) {
    AppLogger.info('🔄 Initializing refresh service for batch: $batchId, product: $productId');
    
    _currentBatchId = batchId;
    _currentProductId = productId;
    
    if (autoRefreshInterval != null) {
      _autoRefreshInterval = autoRefreshInterval;
    }
    
    if (enableAutoRefresh) {
      this.enableAutoRefresh();
    }
  }

  /// تحديث البيانات يدوياً
  Future<RefreshResult> refreshData({
    bool includeAnalytics = true,
    bool includeGapAnalysis = true,
    bool includeForecast = true,
    bool showLoadingState = true,
  }) async {
    if (_currentBatchId == null || _currentProductId == null) {
      final error = 'لم يتم تهيئة الخدمة بمعرفات الدفعة والمنتج';
      AppLogger.error('❌ $error');
      return RefreshResult.error(error);
    }

    try {
      if (showLoadingState) {
        _setRefreshState(RefreshState.refreshing);
      }

      AppLogger.info('🔄 Starting data refresh...');

      // تحميل البيانات بشكل متوازي
      final futures = <Future>[];
      List<ToolUsageAnalytics>? toolAnalytics;
      ProductionGapAnalysis? gapAnalysis;
      RequiredToolsForecast? toolsForecast;

      if (includeAnalytics) {
        futures.add(_productionService.getToolUsageAnalytics(_currentBatchId!).then((data) {
          toolAnalytics = data;
        }));
      }

      if (includeGapAnalysis) {
        futures.add(_productionService.getProductionGapAnalysis(_currentProductId!, _currentBatchId!).then((data) {
          gapAnalysis = data;
        }));
      }

      if (includeForecast) {
        // إذا لم يتم تحميل تحليل الفجوة في هذا الطلب، استخدم البيانات المحفوظة
        final remainingPieces = gapAnalysis?.remainingPieces ?? _currentData?.gapAnalysis?.remainingPieces ?? 0.0;

        AppLogger.info('🔮 Forecast refresh: remainingPieces = $remainingPieces (from ${gapAnalysis != null ? 'current request' : 'cached data'})');

        if (remainingPieces > 0) {
          futures.add(_productionService.getRequiredToolsForecast(_currentProductId!, remainingPieces).then((data) {
            toolsForecast = data;
            AppLogger.info('✅ Forecast loaded successfully: ${data?.toolsCount ?? 0} tools');
          }));
        } else {
          AppLogger.warning('⚠️ Cannot load forecast: no remaining pieces data available (remainingPieces = $remainingPieces)');
        }
      }

      // انتظار اكتمال جميع الطلبات
      await Future.wait(futures);

      // تحديث البيانات المحلية
      _currentData = ManufacturingToolsData(
        toolAnalytics: toolAnalytics ?? _currentData?.toolAnalytics ?? [],
        gapAnalysis: gapAnalysis ?? _currentData?.gapAnalysis,
        toolsForecast: toolsForecast ?? _currentData?.toolsForecast,
        lastUpdated: DateTime.now(),
      );

      _lastRefreshTime = DateTime.now();
      _lastErrorMessage = null;
      _setRefreshState(RefreshState.success);

      AppLogger.info('✅ Data refresh completed successfully');
      
      return RefreshResult.success(
        message: 'تم تحديث البيانات بنجاح',
        data: {
          'analytics_count': toolAnalytics?.length ?? 0,
          'has_gap_analysis': gapAnalysis != null,
          'has_forecast': toolsForecast != null,
        },
      );

    } catch (e) {
      final errorMessage = 'فشل في تحديث البيانات: $e';
      AppLogger.error('❌ $errorMessage');
      
      _lastErrorMessage = errorMessage;
      _setRefreshState(RefreshState.error);
      
      return RefreshResult.error(errorMessage);
    }
  }

  /// تحديث جزئي لنوع معين من البيانات
  Future<RefreshResult> refreshSpecificData(String dataType) async {
    switch (dataType) {
      case 'analytics':
        return refreshData(
          includeAnalytics: true,
          includeGapAnalysis: false,
          includeForecast: false,
        );
      case 'gap_analysis':
        return refreshData(
          includeAnalytics: false,
          includeGapAnalysis: true,
          includeForecast: false,
        );
      case 'forecast':
        // للتوقعات، نحتاج إلى بيانات تحليل الفجوة للحصول على القطع المتبقية
        // إذا لم تكن متوفرة، نحمّلها أيضاً
        final needsGapAnalysis = _currentData?.gapAnalysis == null;
        return refreshData(
          includeAnalytics: false,
          includeGapAnalysis: needsGapAnalysis,
          includeForecast: true,
        );
      default:
        return RefreshResult.error('نوع البيانات غير مدعوم: $dataType');
    }
  }

  /// تحديث توقعات الأدوات مع ضمان توفر بيانات تحليل الفجوة
  Future<RefreshResult> refreshForecastWithDependencies() async {
    AppLogger.info('🔮 Refreshing forecast with dependencies check');

    // التأكد من وجود بيانات تحليل الفجوة
    if (_currentData?.gapAnalysis == null) {
      AppLogger.info('📊 Gap analysis data not available, loading it first');
      return refreshData(
        includeAnalytics: false,
        includeGapAnalysis: true,
        includeForecast: true,
      );
    } else {
      AppLogger.info('📊 Gap analysis data available, refreshing forecast only');
      return refreshData(
        includeAnalytics: false,
        includeGapAnalysis: false,
        includeForecast: true,
      );
    }
  }

  /// تفعيل التحديث التلقائي
  void enableAutoRefresh() {
    if (_autoRefreshEnabled) return;
    
    AppLogger.info('🔄 Enabling auto-refresh with interval: ${_autoRefreshInterval.inMinutes} minutes');
    
    _autoRefreshEnabled = true;
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (timer) {
      if (_refreshState != RefreshState.refreshing) {
        refreshData(showLoadingState: false);
      }
    });
    
    notifyListeners();
  }

  /// إيقاف التحديث التلقائي
  void disableAutoRefresh() {
    if (!_autoRefreshEnabled) return;
    
    AppLogger.info('⏹️ Disabling auto-refresh');
    
    _autoRefreshEnabled = false;
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    
    notifyListeners();
  }

  /// تغيير فترة التحديث التلقائي
  void setAutoRefreshInterval(Duration interval) {
    AppLogger.info('⏱️ Setting auto-refresh interval to: ${interval.inMinutes} minutes');
    
    _autoRefreshInterval = interval;
    
    if (_autoRefreshEnabled) {
      disableAutoRefresh();
      enableAutoRefresh();
    }
    
    notifyListeners();
  }

  /// إعادة تعيين حالة الخطأ
  void clearError() {
    if (_refreshState == RefreshState.error) {
      _lastErrorMessage = null;
      _setRefreshState(RefreshState.idle);
    }
  }

  /// الحصول على معلومات حالة التحديث
  Map<String, dynamic> getRefreshStatus() {
    return {
      'state': _refreshState.toString(),
      'last_refresh_time': _lastRefreshTime?.toIso8601String(),
      'last_error': _lastErrorMessage,
      'auto_refresh_enabled': _autoRefreshEnabled,
      'auto_refresh_interval_minutes': _autoRefreshInterval.inMinutes,
      'has_data': _currentData?.hasData ?? false,
      'data_items_count': _currentData?.totalItems ?? 0,
    };
  }

  /// التحقق من الحاجة للتحديث
  bool shouldRefresh({Duration? maxAge}) {
    if (_lastRefreshTime == null) return true;
    if (_refreshState == RefreshState.error) return true;
    
    final age = DateTime.now().difference(_lastRefreshTime!);
    final threshold = maxAge ?? const Duration(minutes: 10);
    
    return age > threshold;
  }

  /// تحديث حالة التحديث مع إشعار المستمعين
  void _setRefreshState(RefreshState state) {
    if (_refreshState != state) {
      _refreshState = state;
      notifyListeners();
    }
  }

  /// إنشاء ويدجت Pull-to-Refresh
  Widget buildPullToRefresh({
    required Widget child,
    VoidCallback? onRefresh,
    String refreshText = 'اسحب للتحديث',
    String refreshingText = 'جاري التحديث...',
  }) {
    return RefreshIndicator(
      onRefresh: () async {
        final result = await refreshData();
        onRefresh?.call();
        
        if (result.isError) {
          throw Exception(result.message);
        }
      },
      color: Colors.white,
      backgroundColor: Colors.blue,
      strokeWidth: 3,
      displacement: 40,
      child: child,
    );
  }

  /// إنشاء ويدجت معلومات آخر تحديث
  Widget buildLastUpdateInfo() {
    if (_lastRefreshTime == null) {
      return const SizedBox.shrink();
    }

    final timeDiff = DateTime.now().difference(_lastRefreshTime!);
    String timeText;

    if (timeDiff.inMinutes < 1) {
      timeText = 'الآن';
    } else if (timeDiff.inMinutes < 60) {
      timeText = 'منذ ${timeDiff.inMinutes} دقيقة';
    } else if (timeDiff.inHours < 24) {
      timeText = 'منذ ${timeDiff.inHours} ساعة';
    } else {
      timeText = 'منذ ${timeDiff.inDays} يوم';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time,
            size: 14,
            color: Colors.white70,
          ),
          const SizedBox(width: 4),
          Text(
            'آخر تحديث: $timeText',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
