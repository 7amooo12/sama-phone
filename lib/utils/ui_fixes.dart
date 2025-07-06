import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// مجموعة شاملة من الإصلاحات للمشاكل الشائعة في واجهة المستخدم
class UIFixes {

  /// إصلاح مشاكل الثيم والألوان
  static ThemeData fixThemeData(ThemeData theme) {
    return theme.copyWith(
      // إصلاح ألوان AppBar
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: theme.appBarTheme.backgroundColor ??
                        (theme.brightness == Brightness.dark
                         ? Colors.grey[900]
                         : Colors.white),
        foregroundColor: theme.appBarTheme.foregroundColor ??
                        (theme.brightness == Brightness.dark
                         ? Colors.white
                         : Colors.black),
        elevation: theme.appBarTheme.elevation ?? 0,
        centerTitle: true,
        systemOverlayStyle: theme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      // إصلاح ألوان الكاردز
      cardTheme: theme.cardTheme.copyWith(
        color: theme.cardColor,
        elevation: theme.cardTheme.elevation ?? 2,
        shape: theme.cardTheme.shape ?? RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: theme.cardTheme.margin ?? const EdgeInsets.all(8),
      ),

      // إصلاح ألوان النصوص
      textTheme: theme.textTheme.copyWith(
        bodyLarge: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        bodyMedium: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        bodySmall: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.7),
        ),
        titleLarge: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),

      // إصلاح ألوان الأزرار
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      // إصلاح ألوان الحقول
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.colorScheme.error),
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
      ),
    );
  }

  /// ويدجت آمن للنصوص يمنع overflow
  static Widget safeText(
    String text, {
    TextStyle? style,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow overflow = TextOverflow.ellipsis,
    bool softWrap = true,
  }) {
    return Text(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }

  /// ويدجت آمن للصفوف يمنع overflow
  static Widget safeRow({
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    bool scrollable = true,
  }) {
    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
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
      children: children.map((child) => Flexible(child: child)).toList(),
    );
  }

  /// ويدجت آمن للأعمدة يمنع overflow
  static Widget safeColumn({
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    bool scrollable = true,
  }) {
    if (scrollable) {
      return SingleChildScrollView(
        child: Column(
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: crossAxisAlignment,
          children: children,
        ),
      );
    }
    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: children.map((child) => Flexible(child: child)).toList(),
    );
  }

  /// إصلاح مشاكل الصور
  static Widget safeImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (imageUrl.isEmpty || imageUrl == 'null' || !_isValidImageUrl(imageUrl)) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[200],
        ),
        child: errorWidget ??
               const Center(
                 child: Icon(
                   Icons.image_not_supported,
                   color: Colors.grey,
                   size: 32,
                 ),
               ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[200],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          width: width,
          height: height,
          fit: fit,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return placeholder ??
                   Center(
                     child: CircularProgressIndicator(
                       value: loadingProgress.expectedTotalBytes != null
                           ? loadingProgress.cumulativeBytesLoaded /
                             loadingProgress.expectedTotalBytes!
                           : null,
                     ),
                   );
          },
          errorBuilder: (context, error, stackTrace) {
            return errorWidget ??
                   const Center(
                     child: Icon(
                       Icons.image_not_supported,
                       color: Colors.grey,
                       size: 32,
                     ),
                   );
          },
        ),
      ),
    );
  }

  /// إصلاح مشاكل التخطيط المتجاوب
  static Widget responsiveContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double? maxWidth,
    double? maxHeight,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin,
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? double.infinity,
        maxHeight: maxHeight ?? double.infinity,
      ),
      child: child,
    );
  }

  /// إصلاح مشاكل الشاشات الصغيرة
  static Widget responsiveLayout({
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1200) {
          return desktop ?? tablet ?? mobile;
        } else if (constraints.maxWidth >= 768) {
          return tablet ?? mobile;
        } else {
          return mobile;
        }
      },
    );
  }

  /// إصلاح مشاكل الحالات الفارغة
  static Widget emptyState({
    required String title,
    String? subtitle,
    IconData? icon,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action,
            ],
          ],
        ),
      ),
    );
  }

  /// إصلاح مشاكل التحميل
  static Widget loadingState({
    String? message,
    Color? color,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: color,
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// إصلاح مشاكل الأخطاء
  static Widget errorState({
    required String message,
    VoidCallback? onRetry,
    IconData? icon,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Validate image URL to prevent data URI and other invalid URL errors
  static bool _isValidImageUrl(String url) {
    if (url.isEmpty || url == 'null') return false;

    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return false;

      // Reject data URIs as they can cause parsing issues
      if (uri.scheme == 'data') return false;

      // Only allow http/https URLs
      if (uri.scheme != 'http' && uri.scheme != 'https') return false;

      // Must have a host
      if (uri.host.isEmpty) return false;

      return true;
    } catch (e) {
      return false;
    }
  }
}
