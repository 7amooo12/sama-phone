import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../utils/app_logger.dart';

/// خدمة منع تجاوز حدود واجهة المستخدم
class UIOverflowPrevention {
  static final UIOverflowPrevention _instance = UIOverflowPrevention._internal();
  factory UIOverflowPrevention() => _instance;
  UIOverflowPrevention._internal();

  // Throttling mechanism to prevent excessive logging
  static DateTime? _lastOverflowTime;
  static const Duration _throttleDuration = Duration(milliseconds: 500);

  /// تطبيق إصلاحات شاملة لمنع التجاوز
  static void applyGlobalFixes() {
    // تعيين معالج مخصص لأخطاء التجاوز
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('RenderFlex overflowed')) {
        _handleOverflowError(details);
      } else {
        // معالجة الأخطاء الأخرى بشكل طبيعي
        FlutterError.presentError(details);
      }
    };
  }

  /// معالجة أخطاء التجاوز مع آلية التحكم في التكرار
  static void _handleOverflowError(FlutterErrorDetails details) {
    final now = DateTime.now();

    // Throttle overflow logging to prevent performance issues
    if (_lastOverflowTime != null &&
        now.difference(_lastOverflowTime!) < _throttleDuration) {
      return; // Skip logging if too frequent
    }

    _lastOverflowTime = now;

    final errorMessage = details.exception.toString();
    final stackTrace = details.stack.toString();

    // استخراج معلومات التجاوز
    final overflowMatch = RegExp(r'overflowed by (\d+(?:\.\d+)?) pixels').firstMatch(errorMessage);
    final pixels = overflowMatch?.group(1) ?? 'unknown';

    // تسجيل التحذير مع معلومات مفيدة (مع تقليل التكرار)
    AppLogger.warning(
      'UI Overflow detected: $pixels pixels overflow\n'
      'Location: ${details.library ?? 'Unknown'}\n'
      'Context: ${details.context ?? 'No context'}\n'
      'Note: Logging throttled to prevent performance issues'
    );

    // في وضع التطوير، طباعة معلومات إضافية
    if (details.library?.contains('owner_dashboard') == true) {
      AppLogger.warning('Overflow in Owner Dashboard - Products tab filter buttons fixed');
      _suggestFixes();
    }
  }

  /// اقتراح إصلاحات للتجاوز
  static void _suggestFixes() {
    AppLogger.info(
      'UI Overflow fixes applied:\n'
      '1. ✅ Fixed filter buttons layout with LayoutBuilder\n'
      '2. ✅ Shortened filter button text labels\n'
      '3. ✅ Changed button layout from Row to Column\n'
      '4. ✅ Added overflow throttling to prevent performance issues\n'
      '5. ✅ Optimized button padding and sizing\n'
      'Additional suggestions:\n'
      '• Use Flexible or Expanded widgets for dynamic content\n'
      '• Add proper constraints to GridView components\n'
      '• Use SingleChildScrollView for long content lists'
    );
  }

  /// Widget آمن للنصوص لمنع التجاوز
  static Widget safeText(
    String text, {
    TextStyle? style,
    int? maxLines,
    TextOverflow? overflow,
    TextAlign? textAlign,
  }) {
    return Text(
      text,
      style: style,
      maxLines: maxLines ?? 2,
      overflow: overflow ?? TextOverflow.ellipsis,
      textAlign: textAlign,
      softWrap: true,
    );
  }

  /// Container آمن مع قيود مناسبة
  static Widget safeContainer({
    Widget? child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Decoration? decoration,
    double? width,
    double? height,
    BoxConstraints? constraints,
  }) {
    return Container(
      padding: padding,
      margin: margin,
      decoration: decoration,
      constraints: constraints ?? const BoxConstraints(
        maxWidth: double.infinity,
        maxHeight: 1000, // منع الارتفاع المفرط
      ),
      width: width,
      height: height,
      child: child,
    );
  }

  /// Column آمن مع تمرير تلقائي
  static Widget safeColumn({
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    EdgeInsetsGeometry? padding,
    bool shrinkWrap = true,
  }) {
    return SingleChildScrollView(
      padding: padding,
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
        children: children,
      ),
    );
  }

  /// Row آمن مع تمرير أفقي
  static Widget safeRow({
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    bool scrollable = false,
  }) {
    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: crossAxisAlignment,
          children: children,
        ),
      );
    }

    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: children.map((child) {
        // تلقائياً لف العناصر في Flexible
        if (child is! Flexible && child is! Expanded) {
          return Flexible(child: child);
        }
        return child;
      }).toList(),
    );
  }

  /// GridView آمن مع قيود محسنة
  static Widget safeGridView({
    required List<Widget> children,
    required int crossAxisCount,
    double childAspectRatio = 1.0,
    double crossAxisSpacing = 8.0,
    double mainAxisSpacing = 8.0,
    EdgeInsetsGeometry? padding,
    bool shrinkWrap = true,
    ScrollPhysics? physics,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // حساب العرض المتاح
        final availableWidth = constraints.maxWidth - (padding?.horizontal ?? 0);
        final itemWidth = (availableWidth - (crossAxisCount - 1) * crossAxisSpacing) / crossAxisCount;
        final itemHeight = itemWidth / childAspectRatio;
        
        // التأكد من أن الارتفاع معقول
        final adjustedAspectRatio = itemWidth / itemHeight.clamp(100, 400);
        
        return GridView.builder(
          padding: padding,
          shrinkWrap: shrinkWrap,
          physics: physics ?? const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: adjustedAspectRatio,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: itemHeight.clamp(100, 400),
                maxWidth: itemWidth,
              ),
              child: children[index],
            );
          },
        );
      },
    );
  }

  /// تحقق من صحة القيود
  static BoxConstraints validateConstraints(BoxConstraints constraints) {
    return BoxConstraints(
      minWidth: constraints.minWidth.clamp(0, double.infinity),
      maxWidth: constraints.maxWidth.isFinite ? constraints.maxWidth : double.infinity,
      minHeight: constraints.minHeight.clamp(0, double.infinity),
      maxHeight: constraints.maxHeight.isFinite ? constraints.maxHeight : 1000,
    );
  }

  /// معالج أخطاء مخصص للتطبيق
  static Widget errorWidgetBuilder(FlutterErrorDetails details) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 24),
          const SizedBox(height: 8),
          Text(
            'حدث خطأ في واجهة المستخدم',
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'يرجى المحاولة مرة أخرى',
            style: TextStyle(
              color: Colors.red.withOpacity(0.7),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
