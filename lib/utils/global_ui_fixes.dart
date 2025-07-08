import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartbiztracker_new/utils/ui_fixes.dart';

/// إصلاحات شاملة لجميع صفحات التطبيق
class GlobalUIFixes {

  /// تطبيق إصلاحات الثيم على التطبيق بالكامل
  static ThemeData applyGlobalThemeFixes(ThemeData theme) {
    return UIFixes.fixThemeData(theme).copyWith(
      // إصلاحات إضافية للثيم العام
      visualDensity: VisualDensity.adaptivePlatformDensity,

      // إصلاح مشاكل الألوان في الوضع المظلم
      brightness: theme.brightness,

      // إصلاح مشاكل الـ Scaffold
      scaffoldBackgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF121212)
          : const Color(0xFFFAFAFA),

      // إصلاح مشاكل الـ BottomNavigationBar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: theme.brightness == Brightness.dark
            ? Colors.grey[900]
            : Colors.white,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.brightness == Brightness.dark
            ? Colors.grey[400]
            : Colors.grey[600],
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // إصلاح مشاكل الـ TabBar
      tabBarTheme: TabBarTheme(
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.brightness == Brightness.dark
            ? Colors.grey[400]
            : Colors.grey[600],
        indicatorColor: theme.colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.tab,
      ),

      // إصلاح مشاكل الـ Dialog
      dialogTheme: DialogTheme(
        backgroundColor: theme.brightness == Brightness.dark
            ? Colors.grey[850]
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 8,
      ),

      // إصلاح مشاكل الـ SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: theme.brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[900],
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// إصلاح مشاكل الـ overflow في جميع الصفحات
  static Widget fixOverflowIssues(Widget child) {
    return Builder(
      builder: (context) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(MediaQuery.of(context).textScaler.scale(1.0).clamp(0.8, 1.2)),
          ),
          child: child,
        );
      },
    );
  }

  /// إصلاح مشاكل overflow في Manufacturing Tools
  static Widget fixManufacturingToolsOverflow(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth,
            maxHeight: constraints.maxHeight,
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: child,
          ),
        );
      },
    );
  }

  /// إصلاح مشاكل overflow في النصوص الطويلة
  static Widget fixTextOverflow(
    String text, {
    TextStyle? style,
    int maxLines = 1,
    TextAlign textAlign = TextAlign.start,
    TextOverflow overflow = TextOverflow.ellipsis,
  }) {
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      softWrap: true,
    );
  }

  /// إصلاح مشاكل overflow في الصفوف (Rows)
  static Widget fixRowOverflow({
    required List<Widget> children,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    MainAxisSize mainAxisSize = MainAxisSize.max,
  }) {
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: children.map((child) {
        return Flexible(child: child);
      }).toList(),
    );
  }

  /// إصلاح مشاكل الـ keyboard overflow
  static Widget fixKeyboardOverflow(Widget child) {
    return Builder(
      builder: (context) {
        return Scaffold(
          resizeToAvoidBottomInset: true,
          body: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height,
              ),
              child: IntrinsicHeight(
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  /// إصلاح مشاكل الصور المكسورة
  static Widget fixBrokenImages(String imageUrl, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    return UIFixes.safeImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      errorWidget: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(
            Icons.image_not_supported,
            color: Colors.grey,
            size: 32,
          ),
        ),
      ),
    );
  }

  /// إصلاح مشاكل الـ ListView
  static Widget fixListViewIssues({
    required List<Widget> children,
    ScrollPhysics? physics,
    EdgeInsetsGeometry? padding,
    bool shrinkWrap = false,
  }) {
    return ListView.builder(
      physics: physics ?? const ClampingScrollPhysics(),
      padding: padding ?? const EdgeInsets.all(8),
      shrinkWrap: shrinkWrap,
      itemCount: children.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: children[index],
        );
      },
    );
  }

  /// إصلاح مشاكل الـ GridView
  static Widget fixGridViewIssues({
    required List<Widget> children,
    int crossAxisCount = 2,
    double childAspectRatio = 1.0,
    double crossAxisSpacing = 8,
    double mainAxisSpacing = 8,
    EdgeInsetsGeometry? padding,
    bool shrinkWrap = false,
  }) {
    return GridView.builder(
      physics: const ClampingScrollPhysics(),
      padding: padding ?? const EdgeInsets.all(8),
      shrinkWrap: shrinkWrap,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) {
        return children[index];
      },
    );
  }

  /// إصلاح مشاكل الـ AppBar
  static PreferredSizeWidget fixAppBarIssues({
    required String title,
    List<Widget>? actions,
    Widget? leading,
    bool automaticallyImplyLeading = true,
    Color? backgroundColor,
    Color? foregroundColor,
    double? elevation,
  }) {
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: actions,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: elevation ?? 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    );
  }

  /// إصلاح مشاكل الـ FloatingActionButton
  static Widget fixFABIssues({
    required VoidCallback onPressed,
    required Widget child,
    Color? backgroundColor,
    Color? foregroundColor,
    double? elevation,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return FloatingActionButton(
          onPressed: onPressed,
          backgroundColor: backgroundColor ?? theme.colorScheme.primary,
          foregroundColor: foregroundColor ?? theme.colorScheme.onPrimary,
          elevation: elevation ?? 6,
          child: child,
        );
      },
    );
  }

  /// إصلاح مشاكل الـ BottomSheet
  static Widget fixBottomSheetIssues({
    required Widget child,
    bool isScrollControlled = true,
    bool enableDrag = true,
    bool showDragHandle = true,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDragHandle)
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Flexible(child: child),
            ],
          ),
        );
      },
    );
  }

  /// إصلاح مشاكل الـ Card
  static Widget fixCardIssues({
    required Widget child,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    double? elevation,
    Color? color,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Card(
          margin: margin ?? const EdgeInsets.all(8),
          elevation: elevation ?? 2,
          color: color ?? theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        );
      },
    );
  }
}
