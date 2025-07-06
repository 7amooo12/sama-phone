/// معلومات حذف أداة التصنيع مع تفاصيل القيود والتحذيرات
class ToolDeletionInfo {
  final int toolId;
  final String toolName;
  final bool canDelete;
  final bool hasProductionRecipes;
  final bool hasUsageHistory;
  final int productionRecipesCount;
  final int usageHistoryCount;
  final String blockingReason;
  final List<String> warnings;

  const ToolDeletionInfo({
    required this.toolId,
    required this.toolName,
    required this.canDelete,
    required this.hasProductionRecipes,
    required this.hasUsageHistory,
    required this.productionRecipesCount,
    required this.usageHistoryCount,
    required this.blockingReason,
    required this.warnings,
  });

  /// إنشاء من JSON
  factory ToolDeletionInfo.fromJson(Map<String, dynamic> json) {
    return ToolDeletionInfo(
      toolId: json['tool_id'] as int,
      toolName: json['tool_name'] as String,
      canDelete: json['can_delete'] as bool,
      hasProductionRecipes: json['has_production_recipes'] as bool,
      hasUsageHistory: json['has_usage_history'] as bool,
      productionRecipesCount: json['production_recipes_count'] as int,
      usageHistoryCount: json['usage_history_count'] as int,
      blockingReason: json['blocking_reason'] as String,
      warnings: List<String>.from(json['warnings'] as List<dynamic>),
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'tool_id': toolId,
      'tool_name': toolName,
      'can_delete': canDelete,
      'has_production_recipes': hasProductionRecipes,
      'has_usage_history': hasUsageHistory,
      'production_recipes_count': productionRecipesCount,
      'usage_history_count': usageHistoryCount,
      'blocking_reason': blockingReason,
      'warnings': warnings,
    };
  }

  /// التحقق من وجود تحذيرات
  bool get hasWarnings => warnings.isNotEmpty;

  /// الحصول على ملخص التحذيرات
  String get warningsSummary {
    if (warnings.isEmpty) return '';
    return warnings.join('\n• ');
  }

  /// الحصول على رسالة مفصلة للمستخدم
  String get detailedMessage {
    final buffer = StringBuffer();
    
    if (!canDelete) {
      buffer.writeln('❌ لا يمكن حذف الأداة:');
      buffer.writeln('• $blockingReason');
    } else {
      buffer.writeln('⚠️ تحذير: سيتم حذف الأداة مع:');
    }
    
    if (hasProductionRecipes) {
      buffer.writeln('• $productionRecipesCount وصفة إنتاج');
    }
    
    if (hasUsageHistory) {
      buffer.writeln('• $usageHistoryCount سجل استخدام');
    }
    
    if (hasWarnings) {
      buffer.writeln('\nتحذيرات إضافية:');
      buffer.writeln('• $warningsSummary');
    }
    
    return buffer.toString().trim();
  }

  /// إنشاء نسخة محدثة
  ToolDeletionInfo copyWith({
    int? toolId,
    String? toolName,
    bool? canDelete,
    bool? hasProductionRecipes,
    bool? hasUsageHistory,
    int? productionRecipesCount,
    int? usageHistoryCount,
    String? blockingReason,
    List<String>? warnings,
  }) {
    return ToolDeletionInfo(
      toolId: toolId ?? this.toolId,
      toolName: toolName ?? this.toolName,
      canDelete: canDelete ?? this.canDelete,
      hasProductionRecipes: hasProductionRecipes ?? this.hasProductionRecipes,
      hasUsageHistory: hasUsageHistory ?? this.hasUsageHistory,
      productionRecipesCount: productionRecipesCount ?? this.productionRecipesCount,
      usageHistoryCount: usageHistoryCount ?? this.usageHistoryCount,
      blockingReason: blockingReason ?? this.blockingReason,
      warnings: warnings ?? this.warnings,
    );
  }

  @override
  String toString() {
    return 'ToolDeletionInfo(toolId: $toolId, toolName: $toolName, canDelete: $canDelete)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ToolDeletionInfo &&
        other.toolId == toolId &&
        other.toolName == toolName &&
        other.canDelete == canDelete &&
        other.hasProductionRecipes == hasProductionRecipes &&
        other.hasUsageHistory == hasUsageHistory &&
        other.productionRecipesCount == productionRecipesCount &&
        other.usageHistoryCount == usageHistoryCount &&
        other.blockingReason == blockingReason;
  }

  @override
  int get hashCode {
    return Object.hash(
      toolId,
      toolName,
      canDelete,
      hasProductionRecipes,
      hasUsageHistory,
      productionRecipesCount,
      usageHistoryCount,
      blockingReason,
    );
  }
}

/// استثناء خاص بحذف أدوات التصنيع
class ToolDeletionException implements Exception {
  final String message;
  final ToolDeletionInfo? deletionInfo;

  const ToolDeletionException(this.message, [this.deletionInfo]);

  @override
  String toString() => 'ToolDeletionException: $message';
}
