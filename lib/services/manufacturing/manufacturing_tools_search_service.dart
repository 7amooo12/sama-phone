import 'package:smartbiztracker_new/models/manufacturing/production_batch.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// معايير البحث والفلترة لأدوات التصنيع
class ToolSearchCriteria {
  final String? searchQuery;
  final List<String>? stockStatuses;
  final double? minUsagePercentage;
  final double? maxUsagePercentage;
  final List<String>? units;
  final DateTime? usageDateFrom;
  final DateTime? usageDateTo;
  final bool? isAvailable;
  final String? sortBy;
  final bool sortAscending;

  const ToolSearchCriteria({
    this.searchQuery,
    this.stockStatuses,
    this.minUsagePercentage,
    this.maxUsagePercentage,
    this.units,
    this.usageDateFrom,
    this.usageDateTo,
    this.isAvailable,
    this.sortBy,
    this.sortAscending = true,
  });

  /// نسخ مع تعديل المعايير
  ToolSearchCriteria copyWith({
    String? searchQuery,
    List<String>? stockStatuses,
    double? minUsagePercentage,
    double? maxUsagePercentage,
    List<String>? units,
    DateTime? usageDateFrom,
    DateTime? usageDateTo,
    bool? isAvailable,
    String? sortBy,
    bool? sortAscending,
  }) {
    return ToolSearchCriteria(
      searchQuery: searchQuery ?? this.searchQuery,
      stockStatuses: stockStatuses ?? this.stockStatuses,
      minUsagePercentage: minUsagePercentage ?? this.minUsagePercentage,
      maxUsagePercentage: maxUsagePercentage ?? this.maxUsagePercentage,
      units: units ?? this.units,
      usageDateFrom: usageDateFrom ?? this.usageDateFrom,
      usageDateTo: usageDateTo ?? this.usageDateTo,
      isAvailable: isAvailable ?? this.isAvailable,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }

  /// التحقق من وجود معايير بحث نشطة
  bool get hasActiveFilters {
    return searchQuery?.isNotEmpty == true ||
           stockStatuses?.isNotEmpty == true ||
           minUsagePercentage != null ||
           maxUsagePercentage != null ||
           units?.isNotEmpty == true ||
           usageDateFrom != null ||
           usageDateTo != null ||
           isAvailable != null;
  }

  /// عدد المعايير النشطة
  int get activeFiltersCount {
    int count = 0;
    if (searchQuery?.isNotEmpty == true) count++;
    if (stockStatuses?.isNotEmpty == true) count++;
    if (minUsagePercentage != null) count++;
    if (maxUsagePercentage != null) count++;
    if (units?.isNotEmpty == true) count++;
    if (usageDateFrom != null) count++;
    if (usageDateTo != null) count++;
    if (isAvailable != null) count++;
    return count;
  }
}

/// نتائج البحث مع معلومات إضافية
class ToolSearchResults<T> {
  final List<T> items;
  final int totalCount;
  final int filteredCount;
  final ToolSearchCriteria criteria;
  final Map<String, dynamic> aggregations;

  const ToolSearchResults({
    required this.items,
    required this.totalCount,
    required this.filteredCount,
    required this.criteria,
    this.aggregations = const {},
  });

  /// نسبة النتائج المفلترة
  double get filterRatio => totalCount > 0 ? filteredCount / totalCount : 0.0;

  /// هل تم تطبيق فلاتر
  bool get isFiltered => criteria.hasActiveFilters;
}

/// خدمة البحث والفلترة لأدوات التصنيع
class ManufacturingToolsSearchService {
  
  /// البحث والفلترة في تحليلات استخدام الأدوات
  ToolSearchResults<ToolUsageAnalytics> searchToolUsageAnalytics(
    List<ToolUsageAnalytics> analytics,
    ToolSearchCriteria criteria,
  ) {
    try {
      AppLogger.info('🔍 Searching tool usage analytics with criteria');

      List<ToolUsageAnalytics> filtered = List.from(analytics);
      final totalCount = analytics.length;

      // تطبيق البحث النصي
      if (criteria.searchQuery?.isNotEmpty == true) {
        final query = criteria.searchQuery!.toLowerCase();
        filtered = filtered.where((analytic) {
          return analytic.toolName.toLowerCase().contains(query) ||
                 analytic.unit.toLowerCase().contains(query) ||
                 analytic.stockStatus.toLowerCase().contains(query);
        }).toList();
      }

      // فلترة حسب حالة المخزون
      if (criteria.stockStatuses?.isNotEmpty == true) {
        filtered = filtered.where((analytic) {
          return criteria.stockStatuses!.contains(analytic.stockStatus.toLowerCase());
        }).toList();
      }

      // فلترة حسب نسبة الاستهلاك
      if (criteria.minUsagePercentage != null) {
        filtered = filtered.where((analytic) {
          return analytic.usagePercentage >= criteria.minUsagePercentage!;
        }).toList();
      }

      if (criteria.maxUsagePercentage != null) {
        filtered = filtered.where((analytic) {
          return analytic.usagePercentage <= criteria.maxUsagePercentage!;
        }).toList();
      }

      // فلترة حسب الوحدة
      if (criteria.units?.isNotEmpty == true) {
        filtered = filtered.where((analytic) {
          return criteria.units!.contains(analytic.unit.toLowerCase());
        }).toList();
      }

      // فلترة حسب تاريخ الاستخدام
      if (criteria.usageDateFrom != null || criteria.usageDateTo != null) {
        filtered = filtered.where((analytic) {
          return _isDateInRange(
            analytic.usageHistory.isNotEmpty 
                ? analytic.usageHistory.first.usageDate 
                : DateTime.now(),
            criteria.usageDateFrom,
            criteria.usageDateTo,
          );
        }).toList();
      }

      // ترتيب النتائج
      if (criteria.sortBy != null) {
        _sortToolUsageAnalytics(filtered, criteria.sortBy!, criteria.sortAscending);
      }

      // حساب التجميعات
      final aggregations = _calculateToolUsageAggregations(filtered);

      AppLogger.info('✅ Search completed: ${filtered.length}/${totalCount} results');

      return ToolSearchResults(
        items: filtered,
        totalCount: totalCount,
        filteredCount: filtered.length,
        criteria: criteria,
        aggregations: aggregations,
      );
    } catch (e) {
      AppLogger.error('❌ Error searching tool usage analytics: $e');
      return ToolSearchResults(
        items: [],
        totalCount: analytics.length,
        filteredCount: 0,
        criteria: criteria,
      );
    }
  }

  /// البحث والفلترة في توقعات الأدوات المطلوبة
  ToolSearchResults<RequiredToolItem> searchRequiredTools(
    List<RequiredToolItem> tools,
    ToolSearchCriteria criteria,
  ) {
    try {
      AppLogger.info('🔍 Searching required tools with criteria');

      List<RequiredToolItem> filtered = List.from(tools);
      final totalCount = tools.length;

      // تطبيق البحث النصي
      if (criteria.searchQuery?.isNotEmpty == true) {
        final query = criteria.searchQuery!.toLowerCase();
        filtered = filtered.where((tool) {
          return tool.toolName.toLowerCase().contains(query) ||
                 tool.unit.toLowerCase().contains(query) ||
                 tool.availabilityStatus.toLowerCase().contains(query);
        }).toList();
      }

      // فلترة حسب التوفر
      if (criteria.isAvailable != null) {
        filtered = filtered.where((tool) {
          return tool.isAvailable == criteria.isAvailable!;
        }).toList();
      }

      // فلترة حسب الوحدة
      if (criteria.units?.isNotEmpty == true) {
        filtered = filtered.where((tool) {
          return criteria.units!.contains(tool.unit.toLowerCase());
        }).toList();
      }

      // ترتيب النتائج
      if (criteria.sortBy != null) {
        _sortRequiredTools(filtered, criteria.sortBy!, criteria.sortAscending);
      }

      // حساب التجميعات
      final aggregations = _calculateRequiredToolsAggregations(filtered);

      AppLogger.info('✅ Search completed: ${filtered.length}/${totalCount} results');

      return ToolSearchResults(
        items: filtered,
        totalCount: totalCount,
        filteredCount: filtered.length,
        criteria: criteria,
        aggregations: aggregations,
      );
    } catch (e) {
      AppLogger.error('❌ Error searching required tools: $e');
      return ToolSearchResults(
        items: [],
        totalCount: tools.length,
        filteredCount: 0,
        criteria: criteria,
      );
    }
  }

  /// البحث في تاريخ استخدام الأدوات
  ToolSearchResults<ToolUsageEntry> searchToolUsageHistory(
    List<ToolUsageEntry> history,
    ToolSearchCriteria criteria,
  ) {
    try {
      AppLogger.info('🔍 Searching tool usage history with criteria');

      List<ToolUsageEntry> filtered = List.from(history);
      final totalCount = history.length;

      // فلترة حسب التاريخ
      if (criteria.usageDateFrom != null || criteria.usageDateTo != null) {
        filtered = filtered.where((entry) {
          return _isDateInRange(
            entry.usageDate,
            criteria.usageDateFrom,
            criteria.usageDateTo,
          );
        }).toList();
      }

      // ترتيب النتائج
      if (criteria.sortBy != null) {
        _sortToolUsageHistory(filtered, criteria.sortBy!, criteria.sortAscending);
      }

      // حساب التجميعات
      final aggregations = _calculateUsageHistoryAggregations(filtered);

      AppLogger.info('✅ Search completed: ${filtered.length}/${totalCount} results');

      return ToolSearchResults(
        items: filtered,
        totalCount: totalCount,
        filteredCount: filtered.length,
        criteria: criteria,
        aggregations: aggregations,
      );
    } catch (e) {
      AppLogger.error('❌ Error searching tool usage history: $e');
      return ToolSearchResults(
        items: [],
        totalCount: history.length,
        filteredCount: 0,
        criteria: criteria,
      );
    }
  }

  /// التحقق من وجود التاريخ في النطاق المحدد
  bool _isDateInRange(DateTime date, DateTime? from, DateTime? to) {
    if (from != null && date.isBefore(from)) return false;
    if (to != null && date.isAfter(to)) return false;
    return true;
  }

  /// ترتيب تحليلات استخدام الأدوات
  void _sortToolUsageAnalytics(List<ToolUsageAnalytics> analytics, String sortBy, bool ascending) {
    analytics.sort((a, b) {
      int comparison = 0;
      
      switch (sortBy) {
        case 'name':
          comparison = a.toolName.compareTo(b.toolName);
          break;
        case 'usage_percentage':
          comparison = a.usagePercentage.compareTo(b.usagePercentage);
          break;
        case 'total_used':
          comparison = a.totalQuantityUsed.compareTo(b.totalQuantityUsed);
          break;
        case 'remaining_stock':
          comparison = a.remainingStock.compareTo(b.remainingStock);
          break;
        case 'stock_status':
          comparison = a.stockStatus.compareTo(b.stockStatus);
          break;
        default:
          comparison = a.toolName.compareTo(b.toolName);
      }
      
      return ascending ? comparison : -comparison;
    });
  }

  /// ترتيب الأدوات المطلوبة
  void _sortRequiredTools(List<RequiredToolItem> tools, String sortBy, bool ascending) {
    tools.sort((a, b) {
      int comparison = 0;
      
      switch (sortBy) {
        case 'name':
          comparison = a.toolName.compareTo(b.toolName);
          break;
        case 'quantity_needed':
          comparison = a.totalQuantityNeeded.compareTo(b.totalQuantityNeeded);
          break;
        case 'available_stock':
          comparison = a.availableStock.compareTo(b.availableStock);
          break;
        case 'shortfall':
          comparison = a.shortfall.compareTo(b.shortfall);
          break;
        case 'availability':
          comparison = a.isAvailable.toString().compareTo(b.isAvailable.toString());
          break;
        default:
          comparison = a.toolName.compareTo(b.toolName);
      }
      
      return ascending ? comparison : -comparison;
    });
  }

  /// ترتيب تاريخ استخدام الأدوات
  void _sortToolUsageHistory(List<ToolUsageEntry> history, String sortBy, bool ascending) {
    history.sort((a, b) {
      int comparison = 0;
      
      switch (sortBy) {
        case 'date':
          comparison = a.usageDate.compareTo(b.usageDate);
          break;
        case 'quantity':
          comparison = a.quantityUsed.compareTo(b.quantityUsed);
          break;
        case 'batch_id':
          comparison = a.batchId.compareTo(b.batchId);
          break;
        default:
          comparison = a.usageDate.compareTo(b.usageDate);
      }
      
      return ascending ? comparison : -comparison;
    });
  }

  /// حساب تجميعات تحليلات استخدام الأدوات
  Map<String, dynamic> _calculateToolUsageAggregations(List<ToolUsageAnalytics> analytics) {
    if (analytics.isEmpty) return {};

    final totalUsed = analytics.fold<double>(0, (sum, a) => sum + a.totalQuantityUsed);
    final avgUsage = analytics.fold<double>(0, (sum, a) => sum + a.usagePercentage) / analytics.length;
    
    final statusCounts = <String, int>{};
    for (final analytic in analytics) {
      statusCounts[analytic.stockStatus] = (statusCounts[analytic.stockStatus] ?? 0) + 1;
    }

    return {
      'total_quantity_used': totalUsed,
      'average_usage_percentage': avgUsage,
      'status_distribution': statusCounts,
      'tools_count': analytics.length,
    };
  }

  /// حساب تجميعات الأدوات المطلوبة
  Map<String, dynamic> _calculateRequiredToolsAggregations(List<RequiredToolItem> tools) {
    if (tools.isEmpty) return {};

    final totalNeeded = tools.fold<double>(0, (sum, t) => sum + t.totalQuantityNeeded);
    final totalAvailable = tools.fold<double>(0, (sum, t) => sum + t.availableStock);
    final totalShortfall = tools.fold<double>(0, (sum, t) => sum + t.shortfall);
    final availableCount = tools.where((t) => t.isAvailable).length;

    return {
      'total_quantity_needed': totalNeeded,
      'total_available_stock': totalAvailable,
      'total_shortfall': totalShortfall,
      'available_tools_count': availableCount,
      'unavailable_tools_count': tools.length - availableCount,
      'availability_percentage': tools.isNotEmpty ? (availableCount / tools.length) * 100 : 0,
    };
  }

  /// حساب تجميعات تاريخ الاستخدام
  Map<String, dynamic> _calculateUsageHistoryAggregations(List<ToolUsageEntry> history) {
    if (history.isEmpty) return {};

    final totalQuantity = history.fold<double>(0, (sum, h) => sum + h.quantityUsed);
    final uniqueBatches = history.map((h) => h.batchId).toSet().length;
    
    final dailyUsage = <String, double>{};
    for (final entry in history) {
      final dateKey = '${entry.usageDate.year}-${entry.usageDate.month}-${entry.usageDate.day}';
      dailyUsage[dateKey] = (dailyUsage[dateKey] ?? 0) + entry.quantityUsed;
    }

    return {
      'total_quantity_used': totalQuantity,
      'unique_batches_count': uniqueBatches,
      'usage_entries_count': history.length,
      'daily_usage_distribution': dailyUsage,
    };
  }
}
