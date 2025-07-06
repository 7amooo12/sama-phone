import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_logger.dart';

/// Arabic RTL Performance Optimizer
/// Optimizes Arabic text rendering, RTL layout performance, and font loading
class ArabicRTLOptimizer {
  static bool _isInitialized = false;
  static final Map<String, TextStyle> _cachedTextStyles = {};
  static final Map<String, Widget> _cachedRTLWidgets = {};
  
  /// Initialize Arabic RTL optimizations
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Preload Arabic fonts
      await _preloadArabicFonts();
      
      // Setup RTL text direction optimizations
      _setupRTLOptimizations();
      
      // Cache common text styles
      _cacheCommonTextStyles();
      
      _isInitialized = true;
      AppLogger.info('🔤 Arabic RTL optimizer initialized');
      
    } catch (e) {
      AppLogger.error('❌ Failed to initialize Arabic RTL optimizer: $e');
    }
  }

  /// Preload commonly used Arabic fonts
  static Future<void> _preloadArabicFonts() async {
    try {
      // Preload Cairo font family (commonly used for Arabic)
      await GoogleFonts.pendingFonts([
        GoogleFonts.cairo(),
        GoogleFonts.cairo(fontWeight: FontWeight.bold),
        GoogleFonts.cairo(fontWeight: FontWeight.w600),
        GoogleFonts.cairo(fontWeight: FontWeight.w500),
      ]);
      
      AppLogger.info('✅ Arabic fonts preloaded successfully');
    } catch (e) {
      AppLogger.warning('⚠️ Failed to preload Arabic fonts: $e');
    }
  }

  /// Setup RTL layout optimizations
  static void _setupRTLOptimizations() {
    // Configure text direction for better RTL performance
    // This is handled at the app level in main.dart
  }

  /// Cache common Arabic text styles for better performance
  static void _cacheCommonTextStyles() {
    final commonStyles = {
      'headline_large': GoogleFonts.cairo(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      'headline_medium': GoogleFonts.cairo(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      'headline_small': GoogleFonts.cairo(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      'body_large': GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: Colors.white,
      ),
      'body_medium': GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: Colors.white70,
      ),
      'body_small': GoogleFonts.cairo(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: Colors.white60,
      ),
    };

    _cachedTextStyles.addAll(commonStyles);
    AppLogger.info('📝 Cached ${commonStyles.length} common Arabic text styles');
  }

  /// Get cached text style for better performance
  static TextStyle? getCachedTextStyle(String styleKey) {
    return _cachedTextStyles[styleKey];
  }

  /// Create optimized Arabic text widget
  static Widget optimizedArabicText(
    String text, {
    TextStyle? style,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
    bool softWrap = true,
  }) {
    return Text(
      text,
      style: style,
      textAlign: textAlign ?? TextAlign.right, // Default to right align for Arabic
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      textDirection: TextDirection.rtl,
      // Performance optimization: disable expensive text features when not needed
      textScaleFactor: 1.0, // Disable text scaling for better performance
    );
  }

  /// Create optimized RTL container
  static Widget optimizedRTLContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Decoration? decoration,
    double? width,
    double? height,
    String? cacheKey,
  }) {
    if (cacheKey != null && _cachedRTLWidgets.containsKey(cacheKey)) {
      return _cachedRTLWidgets[cacheKey]!;
    }

    final container = Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: padding,
        margin: margin,
        decoration: decoration,
        width: width,
        height: height,
        child: child,
      ),
    );

    if (cacheKey != null) {
      _cachedRTLWidgets[cacheKey] = container;
    }

    return container;
  }

  /// Create optimized RTL row
  static Widget optimizedRTLRow({
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    MainAxisSize mainAxisSize = MainAxisSize.max,
  }) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: children,
      ),
    );
  }

  /// Create optimized RTL column
  static Widget optimizedRTLColumn({
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
    MainAxisSize mainAxisSize = MainAxisSize.max,
  }) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: children,
      ),
    );
  }

  /// Optimize Arabic text input field
  static Widget optimizedArabicTextField({
    required TextEditingController controller,
    String? labelText,
    String? hintText,
    TextStyle? style,
    InputDecoration? decoration,
    TextInputType? keyboardType,
    int? maxLines,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: TextFormField(
        controller: controller,
        style: style,
        keyboardType: keyboardType,
        maxLines: maxLines,
        enabled: enabled,
        validator: validator,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        decoration: decoration ?? InputDecoration(
          labelText: labelText,
          hintText: hintText,
          hintTextDirection: TextDirection.rtl,
        ),
        // Performance optimizations
        autocorrect: false, // Disable autocorrect for better performance
        enableSuggestions: false, // Disable suggestions for better performance
      ),
    );
  }

  /// Format Arabic currency with proper RTL support
  static String formatArabicCurrency(double amount, {String currency = 'ج.م'}) {
    // Format number with Arabic locale support
    final formattedAmount = amount.toStringAsFixed(2);
    return '$formattedAmount $currency'; // RTL: amount then currency
  }

  /// Format Arabic date with RTL support
  static String formatArabicDate(DateTime date) {
    // Simple Arabic date formatting
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    
    return '$day/$month/$year'; // DD/MM/YYYY format
  }

  /// Get Arabic month name
  static String getArabicMonthName(int month) {
    const arabicMonths = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    
    return month >= 1 && month <= 12 ? arabicMonths[month - 1] : '';
  }

  /// Get Arabic day name
  static String getArabicDayName(int weekday) {
    const arabicDays = [
      'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'
    ];
    
    return weekday >= 1 && weekday <= 7 ? arabicDays[weekday - 1] : '';
  }

  /// Clear cached widgets and styles
  static void clearCache() {
    _cachedTextStyles.clear();
    _cachedRTLWidgets.clear();
    AppLogger.info('🧹 Arabic RTL cache cleared');
  }

  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    return {
      'cached_text_styles': _cachedTextStyles.length,
      'cached_rtl_widgets': _cachedRTLWidgets.length,
      'is_initialized': _isInitialized,
    };
  }

  /// Optimize Arabic text for search
  static String normalizeArabicText(String text) {
    // Remove diacritics and normalize Arabic text for better search performance
    return text
        .replaceAll(RegExp(r'[ًٌٍَُِّْ]'), '') // Remove diacritics
        .replaceAll('ة', 'ه') // Normalize taa marbouta
        .replaceAll('ى', 'ي') // Normalize alif maksura
        .trim()
        .toLowerCase();
  }

  /// Check if text contains Arabic characters
  static bool containsArabic(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  /// Dispose Arabic RTL optimizer
  static void dispose() {
    clearCache();
    _isInitialized = false;
    AppLogger.info('🔤 Arabic RTL optimizer disposed');
  }
}

/// Extension for easy Arabic RTL optimization
extension ArabicRTLExtension on Widget {
  /// Wrap widget with RTL directionality
  Widget withRTL() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: this,
    );
  }
  
  /// Cache RTL widget for better performance
  Widget cachedRTL(String cacheKey) {
    return ArabicRTLOptimizer.optimizedRTLContainer(
      child: this,
      cacheKey: cacheKey,
    );
  }
}
