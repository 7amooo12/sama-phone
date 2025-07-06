import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/app_logger.dart';

/// Service to track and manage progress for reports generation
class ReportsProgressService extends ChangeNotifier {
  static final ReportsProgressService _instance = ReportsProgressService._internal();
  factory ReportsProgressService() => _instance;
  ReportsProgressService._internal();

  // Progress tracking
  double _currentProgress = 0.0;
  String _currentMessage = '';
  String _currentSubMessage = '';
  bool _isLoading = false;
  List<String> _completedSteps = [];
  List<String> _totalSteps = [];

  // Getters
  double get currentProgress => _currentProgress;
  String get currentMessage => _currentMessage;
  String get currentSubMessage => _currentSubMessage;
  bool get isLoading => _isLoading;
  List<String> get completedSteps => List.unmodifiable(_completedSteps);
  List<String> get totalSteps => List.unmodifiable(_totalSteps);
  int get completedStepsCount => _completedSteps.length;
  int get totalStepsCount => _totalSteps.length;

  /// Start progress tracking with defined steps
  void startProgress(List<String> steps, String initialMessage) {
    _totalSteps = List.from(steps);
    _completedSteps.clear();
    _currentProgress = 0.0;
    _currentMessage = initialMessage;
    _currentSubMessage = '';
    _isLoading = true;
    
    AppLogger.info('📊 Started progress tracking with ${steps.length} steps');
    notifyListeners();
  }

  /// Update progress with step completion
  void updateProgress(String stepName, {String? subMessage}) {
    if (!_totalSteps.contains(stepName)) {
      AppLogger.warning('⚠️ Step not found in total steps: $stepName');
      return;
    }

    if (!_completedSteps.contains(stepName)) {
      _completedSteps.add(stepName);
    }

    _currentProgress = _completedSteps.length / _totalSteps.length;
    _currentMessage = _getProgressMessage(stepName);
    _currentSubMessage = subMessage ?? '';

    AppLogger.info('📊 Progress updated: ${(_currentProgress * 100).toInt()}% - $stepName');
    notifyListeners();
  }

  /// Update progress with custom percentage
  void updateProgressPercentage(double percentage, String message, {String? subMessage}) {
    _currentProgress = (percentage / 100).clamp(0.0, 1.0);
    _currentMessage = message;
    _currentSubMessage = subMessage ?? '';

    AppLogger.info('📊 Progress updated: ${percentage.toInt()}% - $message');
    notifyListeners();
  }

  /// Complete progress tracking
  void completeProgress(String completionMessage) {
    _currentProgress = 1.0;
    _currentMessage = completionMessage;
    _currentSubMessage = '';
    _isLoading = false;

    AppLogger.info('✅ Progress completed: $completionMessage');
    notifyListeners();

    // Auto-reset after a delay
    Timer(const Duration(seconds: 2), () {
      resetProgress();
    });
  }

  /// Reset progress tracking
  void resetProgress() {
    _currentProgress = 0.0;
    _currentMessage = '';
    _currentSubMessage = '';
    _isLoading = false;
    _completedSteps.clear();
    _totalSteps.clear();

    AppLogger.info('🔄 Progress reset');
    notifyListeners();
  }

  /// Handle error in progress
  void handleError(String errorMessage) {
    _currentMessage = 'خطأ في التحميل';
    _currentSubMessage = errorMessage;
    _isLoading = false;

    AppLogger.error('❌ Progress error: $errorMessage');
    notifyListeners();
  }

  /// Get localized progress message based on step
  String _getProgressMessage(String stepName) {
    switch (stepName) {
      case 'loading_products':
        return 'جاري تحميل المنتجات...';
      case 'processing_categories':
        return 'جاري معالجة الفئات...';
      case 'calculating_analytics':
        return 'جاري حساب التحليلات...';
      case 'loading_movement_data':
        return 'جاري تحميل بيانات الحركة...';
      case 'processing_customers':
        return 'جاري معالجة بيانات العملاء...';
      case 'generating_charts':
        return 'جاري إنشاء الرسوم البيانية...';
      case 'caching_results':
        return 'جاري حفظ النتائج...';
      case 'finalizing':
        return 'جاري الانتهاء...';
      default:
        return 'جاري المعالجة...';
    }
  }

  /// Predefined step sequences for different report types
  static List<String> get productAnalyticsSteps => [
    'loading_products',
    'loading_movement_data',
    'calculating_analytics',
    'processing_customers',
    'generating_charts',
    'caching_results',
    'finalizing',
  ];

  static List<String> get categoryAnalyticsSteps => [
    'loading_products',
    'processing_categories',
    'loading_movement_data',
    'calculating_analytics',
    'processing_customers',
    'generating_charts',
    'caching_results',
    'finalizing',
  ];

  static List<String> get overallAnalyticsSteps => [
    'loading_products',
    'processing_categories',
    'calculating_analytics',
    'generating_charts',
    'caching_results',
    'finalizing',
  ];

  /// Batch progress tracking for multiple operations
  void startBatchProgress(int totalBatches, String operationName) {
    _totalSteps = List.generate(totalBatches, (index) => 'batch_${index + 1}');
    _completedSteps.clear();
    _currentProgress = 0.0;
    _currentMessage = 'جاري $operationName...';
    _currentSubMessage = 'دفعة 1 من $totalBatches';
    _isLoading = true;

    AppLogger.info('📊 Started batch progress: $totalBatches batches for $operationName');
    notifyListeners();
  }

  void updateBatchProgress(int completedBatches, int totalBatches, String operationName) {
    _currentProgress = completedBatches / totalBatches;
    _currentMessage = 'جاري $operationName...';
    _currentSubMessage = 'دفعة ${completedBatches + 1} من $totalBatches';

    AppLogger.info('📊 Batch progress: $completedBatches/$totalBatches');
    notifyListeners();
  }

  /// Simulate realistic progress for better UX
  void simulateRealisticProgress(String operation, Duration totalDuration) {
    _isLoading = true;
    _currentMessage = operation;
    _currentProgress = 0.0;
    notifyListeners();

    final steps = 20; // 20 steps for smooth animation
    final stepDuration = Duration(milliseconds: totalDuration.inMilliseconds ~/ steps);

    Timer.periodic(stepDuration, (timer) {
      if (_currentProgress >= 1.0) {
        timer.cancel();
        completeProgress('تم الانتهاء بنجاح');
        return;
      }

      // Simulate realistic progress curve (faster at start, slower at end)
      final increment = _calculateRealisticIncrement(timer.tick, steps);
      _currentProgress = (_currentProgress + increment).clamp(0.0, 1.0);
      
      // Update sub-message with realistic steps
      _currentSubMessage = _getRealisticSubMessage(timer.tick, steps);
      
      notifyListeners();
    });
  }

  double _calculateRealisticIncrement(int tick, int totalSteps) {
    // Exponential decay for realistic progress feel
    final normalizedTick = tick / totalSteps;
    if (normalizedTick < 0.3) {
      return 0.08; // Fast initial progress
    } else if (normalizedTick < 0.7) {
      return 0.04; // Medium progress
    } else {
      return 0.02; // Slow final progress
    }
  }

  String _getRealisticSubMessage(int tick, int totalSteps) {
    final percentage = (tick / totalSteps * 100).toInt();
    
    if (percentage < 20) {
      return 'تحضير البيانات...';
    } else if (percentage < 40) {
      return 'معالجة المعلومات...';
    } else if (percentage < 60) {
      return 'حساب التحليلات...';
    } else if (percentage < 80) {
      return 'إنشاء الرسوم البيانية...';
    } else {
      return 'الانتهاء من التحضير...';
    }
  }
}
