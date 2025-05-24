import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// ويدجت لعرض تأثير التحميل اللامع (Shimmer)
/// يستخدم هذا الويدجت لإظهار تأثير جمالي متحرك أثناء تحميل البيانات
class ShimmerLoading extends StatelessWidget {
  final double? height;
  final double? width;
  final Color baseColor;
  final Color highlightColor;
  final double borderRadius;
  final BoxShape shape;

  const ShimmerLoading({
    Key? key,
    this.height,
    this.width,
    this.baseColor = const Color(0xFFE0E0E0),
    this.highlightColor = const Color(0xFFF5F5F5),
    this.borderRadius = 8.0,
    this.shape = BoxShape.rectangle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // تعديل الألوان حسب وضع السمة
    final effectiveBaseColor = isDarkMode 
        ? const Color(0xFF303030) 
        : baseColor;
    final effectiveHighlightColor = isDarkMode 
        ? const Color(0xFF424242) 
        : highlightColor;

    return Shimmer.fromColors(
      baseColor: effectiveBaseColor,
      highlightColor: effectiveHighlightColor,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: shape == BoxShape.rectangle 
              ? BorderRadius.circular(borderRadius) 
              : null,
          shape: shape,
        ),
      ),
    );
  }
} 