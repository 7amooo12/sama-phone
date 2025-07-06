import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// تكوين الألوان والأنماط للوحة تحكم المحاسب
class AccountantThemeConfig {
  // الألوان الأساسية للتدرج الفاخر
  static const Color luxuryBlack = Color(0xFF0A0A0A);
  static const Color darkBlueBlack = Color(0xFF1A1A2E);
  static const Color deepBlueBlack = Color(0xFF16213E);
  static const Color richDarkBlue = Color(0xFF0F0F23);

  // ألوان العناصر التفاعلية
  static const Color primaryGreen = Color(0xFF10B981);
  static const Color secondaryGreen = Color(0xFF059669);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color deepBlue = Color(0xFF1D4ED8);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color warningDeep = Color(0xFFD97706);
  static const Color dangerRed = Color(0xFFEF4444);
  static const Color errorRed = Color(0xFFDC2626);
  static const Color successGreen = Color(0xFF10B981);

  // ألوان الحالة
  static const Color completedColor = Color(0xFF10B981);
  static const Color pendingColor = Color(0xFFF59E0B);
  static const Color canceledColor = Color(0xFFEF4444);
  static const Color neutralColor = Color(0xFF6B7280);

  // ألوان الكروت والخلفيات
  static const Color cardBackground1 = Color(0xFF1E293B);
  static const Color cardBackground2 = Color(0xFF334155);
  static const Color cardColor = Color(0xFF1E293B);

  // ألوان النصوص المتدرجة
  static const Color white70 = Color(0xFFB3B3B3);
  static const Color white60 = Color(0xFF999999);
  static const Color white30 = Color(0xFF4D4D4D);
  static const Color darkGray = Color(0xFF374151);

  // ألوان إضافية
  static const Color backgroundColor = luxuryBlack;
  static const Color borderColor = Color(0xFF374151);
  static const Color warningYellow = Color(0xFFFBBF24);

  /// التدرج الرئيسي للخلفية
  static const LinearGradient mainBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      luxuryBlack,
      darkBlueBlack,
      deepBlueBlack,
      richDarkBlue,
    ],
    stops: [0.0, 0.3, 0.7, 1.0],
  );

  /// تدرج الكروت
  static LinearGradient get cardGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      cardBackground1.withOpacity(0.9),
      cardBackground2.withOpacity(0.8),
    ],
  );

  /// تدرج أخضر للعناصر الإيجابية
  static const LinearGradient greenGradient = LinearGradient(
    colors: [primaryGreen, secondaryGreen],
  );

  /// تدرج أزرق للعناصر المعلوماتية
  static const LinearGradient blueGradient = LinearGradient(
    colors: [accentBlue, deepBlue],
  );

  /// تدرج برتقالي للتحذيرات
  static const LinearGradient orangeGradient = LinearGradient(
    colors: [warningOrange, warningDeep],
  );

  /// تدرج أحمر للعناصر الخطيرة
  static const LinearGradient redGradient = LinearGradient(
    colors: [dangerRed, Color(0xFFDC2626)],
  );

  /// ظلال الكروت
  static List<BoxShadow> get cardShadows => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 15,
      offset: const Offset(0, 5),
    ),
  ];

  /// ظلال العناصر المضيئة
  static List<BoxShadow> glowShadows(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.3),
      blurRadius: 15,
      offset: const Offset(0, 8),
    ),
  ];

  /// حدود مضيئة
  static Border glowBorder(Color color) => Border.all(
    color: color.withOpacity(0.2),
    width: 1,
  );

  /// أنماط النصوص باستخدام خط Cairo

  /// عنوان رئيسي
  static TextStyle get headlineLarge => GoogleFonts.cairo(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    shadows: [
      Shadow(
        color: Colors.black.withOpacity(0.6),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ],
  );

  /// عنوان متوسط
  static TextStyle get headlineMedium => GoogleFonts.cairo(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  /// عنوان صغير
  static TextStyle get headlineSmall => GoogleFonts.cairo(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  /// نص أساسي
  static TextStyle get bodyLarge => GoogleFonts.cairo(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Colors.white.withOpacity(0.9),
  );

  /// نص متوسط
  static TextStyle get bodyMedium => GoogleFonts.cairo(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.white.withOpacity(0.8),
  );

  /// نص صغير
  static TextStyle get bodySmall => GoogleFonts.cairo(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: Colors.white.withOpacity(0.7),
  );

  /// تسمية كبيرة
  static TextStyle get labelLarge => GoogleFonts.cairo(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  /// تسمية متوسطة
  static TextStyle get labelMedium => GoogleFonts.cairo(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  /// تسمية صغيرة
  static TextStyle get labelSmall => GoogleFonts.cairo(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  /// عنوان كبير (مطابق لـ headlineLarge للتوافق)
  static TextStyle get titleLarge => GoogleFonts.cairo(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    shadows: [
      Shadow(
        color: Colors.black.withOpacity(0.6),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ],
  );

  /// عنوان متوسط (مطابق لـ headlineMedium للتوافق)
  static TextStyle get titleMedium => GoogleFonts.cairo(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  /// أنماط الأزرار

  /// زر أساسي
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: primaryGreen,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    elevation: 0,
    shadowColor: primaryGreen.withOpacity(0.3),
  );

  /// زر ثانوي
  static ButtonStyle get secondaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: accentBlue,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    elevation: 0,
    shadowColor: accentBlue.withOpacity(0.3),
  );

  /// زر تحذير
  static ButtonStyle get warningButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: warningOrange,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    elevation: 0,
    shadowColor: warningOrange.withOpacity(0.3),
  );

  /// زر خطر
  static ButtonStyle get dangerButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: dangerRed,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    elevation: 0,
    shadowColor: dangerRed.withOpacity(0.3),
  );

  /// تصميم الكروت

  /// كرت أساسي
  static BoxDecoration get primaryCardDecoration => BoxDecoration(
    gradient: cardGradient,
    borderRadius: BorderRadius.circular(20),
    border: glowBorder(primaryGreen),
    boxShadow: cardShadows,
  );

  /// كرت مضيء
  static BoxDecoration glowCardDecoration(Color color) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [color, color.withOpacity(0.8)],
    ),
    borderRadius: BorderRadius.circular(20),
    boxShadow: glowShadows(color),
  );

  /// كرت شفاف
  static BoxDecoration get transparentCardDecoration => BoxDecoration(
    color: Colors.white.withOpacity(0.05),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: Colors.white.withOpacity(0.1),
      width: 1,
    ),
  );

  /// تصميم حقول الإدخال
  static InputDecoration get inputDecoration => InputDecoration(
    filled: true,
    fillColor: Colors.white.withOpacity(0.1),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(defaultBorderRadius),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(defaultBorderRadius),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(defaultBorderRadius),
      borderSide: const BorderSide(color: primaryGreen, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(defaultBorderRadius),
      borderSide: const BorderSide(color: dangerRed, width: 2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(defaultBorderRadius),
      borderSide: const BorderSide(color: dangerRed, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
    labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
  );

  /// أيقونات الحالة
  static IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'completed':
        return Icons.check_circle_rounded;
      case 'pending':
        return Icons.pending_rounded;
      case 'cancelled':
      case 'canceled':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  /// ألوان الحالة
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'completed':
        return completedColor;
      case 'pending':
        return pendingColor;
      case 'cancelled':
      case 'canceled':
        return canceledColor;
      default:
        return neutralColor;
    }
  }

  /// نصوص الحالة
  static String getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'completed':
        return 'مكتملة';
      case 'pending':
        return 'معلقة';
      case 'cancelled':
      case 'canceled':
        return 'ملغاة';
      default:
        return 'غير محدد';
    }
  }

  /// رسائل الترحيب حسب الوقت
  static String getWelcomeMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'صباح الخير';
    } else if (hour < 17) {
      return 'مساء الخير';
    } else {
      return 'مساء الخير';
    }
  }

  /// تنسيق الأرقام
  static String formatNumber(num number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}م';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}ك';
    } else {
      return number.toString();
    }
  }

  /// تنسيق العملة
  static String formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(2)}م جنيه';
    } else {
      // For amounts under one million, always show full precision with decimal places
      return '${amount.toStringAsFixed(2)} جنيه';
    }
  }

  /// تنسيق النسبة المئوية
  static String formatPercentage(double percentage) {
    final sign = percentage >= 0 ? '+' : '';
    return '$sign${percentage.toStringAsFixed(1)}%';
  }

  /// تنسيق التاريخ
  static String formatDate(DateTime date) {
    final months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// تنسيق التاريخ والوقت
  static String formatDateTime(DateTime dateTime) {
    final date = formatDate(dateTime);
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$date - $hour:$minute';
  }

  /// ثوابت التخطيط
  static const double defaultPadding = 16.0;
  static const double largePadding = 24.0;
  static const double smallPadding = 8.0;
  static const double defaultBorderRadius = 12.0;
  static const double largeBorderRadius = 20.0;
  static const double smallBorderRadius = 8.0;

  /// مدة الرسوم المتحركة
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 600);
}
