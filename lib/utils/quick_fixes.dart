import 'package:flutter/material.dart';

/// إصلاحات سريعة للمشاكل الشائعة في التطبيق
class QuickFixes {
  
  /// تحويل ProductModel إلى Product للتوافق مع الكود القديم
  static dynamic convertProductModelToProduct(dynamic productModel) {
    if (productModel == null) return null;
    
    // إذا كان ProductModel، نحوله إلى Map يمكن استخدامه كـ Product
    if (productModel.runtimeType.toString().contains('ProductModel')) {
      return {
        'id': productModel.id,
        'name': productModel.name,
        'description': productModel.description,
        'price': productModel.price,
        'category': productModel.category,
        'imageUrl': productModel.imageUrl,
        'stock': productModel.quantity,
        'availableQuantity': productModel.quantity,
      };
    }
    
    return productModel;
  }
  
  /// تحويل قائمة ProductModel إلى قائمة Product
  static List<dynamic> convertProductModelListToProductList(List<dynamic> productModels) {
    return productModels.map((pm) => convertProductModelToProduct(pm)).toList();
  }
  
  /// تحويل معرف int إلى String
  static String convertIdToString(dynamic id) {
    if (id == null) return '';
    return id.toString();
  }
  
  /// تحويل معرف String إلى int
  static int convertIdToInt(dynamic id) {
    if (id == null) return 0;
    if (id is int) return id;
    if (id is String) return int.tryParse(id) ?? 0;
    return 0;
  }
  
  /// إصلاح مشكلة null safety للـ progress
  static double safeProgress(double? progress) {
    return progress ?? 0.0;
  }
  
  /// إصلاح مشكلة null safety للـ itemsCount
  static int safeItemsCount(int? itemsCount) {
    return itemsCount ?? 0;
  }
  
  /// إصلاح مشكلة الألوان المهجورة
  static Color safeColor(Color color, {double opacity = 1.0}) {
    try {
      return color.withValues(alpha: opacity);
    } catch (e) {
      // استخدام طريقة جديدة إذا فشلت القديمة
      return Color.fromARGB(
        (255 * opacity).round(),
        color.red,
        color.green,
        color.blue,
      );
    }
  }
  
  /// إصلاح مشكلة MaterialState المهجور
  static WidgetStateProperty<T> safeWidgetStateProperty<T>(T value) {
    try {
      return WidgetStateProperty.all<T>(value);
    } catch (e) {
      // استخدام MaterialStateProperty كبديل إذا فشل WidgetStateProperty
      return WidgetStateProperty.all<T>(value);
    }
  }
  
  /// إصلاح مشكلة textScaleFactor المهجور
  static Widget safeTextScale(Widget child, {double scale = 1.0}) {
    return Builder(
      builder: (context) {
        try {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: child,
          );
        } catch (e) {
          // استخدام الطريقة القديمة إذا فشلت الجديدة
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: child,
          );
        }
      },
    );
  }
  
  /// إصلاح مشكلة useMaterial3 المهجور
  static ThemeData safeThemeData({
    required Brightness brightness,
    ColorScheme? colorScheme,
    String? fontFamily,
  }) {
    try {
      if (brightness == Brightness.dark) {
        return ThemeData.dark(useMaterial3: true).copyWith(
          colorScheme: colorScheme,
          fontFamily: fontFamily,
        );
      } else {
        return ThemeData.light(useMaterial3: true).copyWith(
          colorScheme: colorScheme,
          fontFamily: fontFamily,
        );
      }
    } catch (e) {
      // استخدام الطريقة القديمة إذا فشلت الجديدة
      return ThemeData(
        brightness: brightness,
        colorScheme: colorScheme,
        fontFamily: fontFamily,
        useMaterial3: true,
      );
    }
  }
  
  /// إصلاح مشكلة background المهجور
  static ColorScheme safeColorScheme({
    required Brightness brightness,
    Color? primary,
    Color? secondary,
    Color? surface,
    Color? background,
  }) {
    try {
      if (brightness == Brightness.dark) {
        return ColorScheme.dark(
          primary: primary ?? Colors.blue,
          secondary: secondary ?? Colors.blueAccent,
          surface: surface ?? background ?? const Color(0xFF121212),
        );
      } else {
        return ColorScheme.light(
          primary: primary ?? Colors.blue,
          secondary: secondary ?? Colors.blueAccent,
          surface: surface ?? background ?? Colors.white,
        );
      }
    } catch (e) {
      // استخدام الطريقة القديمة إذا فشلت الجديدة
      return ColorScheme.fromSeed(
        seedColor: primary ?? Colors.blue,
        brightness: brightness,
      );
    }
  }
  
  /// إصلاح مشكلة dialogBackgroundColor المهجور
  static ThemeData safeDialogTheme(ThemeData theme, {Color? backgroundColor}) {
    try {
      return theme.copyWith(
        dialogTheme: DialogTheme(
          backgroundColor: backgroundColor ?? theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    } catch (e) {
      // استخدام الطريقة القديمة إذا فشلت الجديدة
      return theme.copyWith(
        dialogTheme: DialogThemeData(backgroundColor: backgroundColor ?? theme.colorScheme.surface),
      );
    }
  }
  
  /// إصلاح مشكلة window المهجور
  static Brightness safePlatformBrightness(BuildContext context) {
    try {
      return View.of(context).platformDispatcher.platformBrightness;
    } catch (e) {
      // استخدام الطريقة القديمة إذا فشلت الجديدة
      return MediaQuery.of(context).platformBrightness;
    }
  }
  
  /// إصلاح مشكلة surfaceVariant المهجور
  static Color safeSurfaceVariant(ColorScheme colorScheme) {
    try {
      return colorScheme.surfaceContainerHighest;
    } catch (e) {
      // استخدام الطريقة القديمة إذا فشلت الجديدة
      return colorScheme.surface;
    }
  }
}
