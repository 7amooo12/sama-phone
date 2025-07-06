import 'package:intl/intl.dart';
import 'constants.dart';

class Formatters {
  static final _currencyFormatter = NumberFormat.currency(
    locale: 'ar_EG',
    symbol: 'ج.م',
    decimalDigits: 2,
  );

  static final _numberFormatter = NumberFormat.decimalPattern();
  static final _dateFormatter = DateFormat(AppConstants.dateFormat);
  static final _timeFormatter = DateFormat(AppConstants.timeFormat);
  static final _dateTimeFormatter = DateFormat(AppConstants.dateTimeFormat);

  static String formatCurrency(double value) {
    return _currencyFormatter.format(value);
  }

  static String formatEgyptianPound(double value) {
    return '${value.toStringAsFixed(2)} ج.م';
  }

  /// Format treasury balance with full precision and proper Arabic formatting
  static String formatTreasuryBalance(double balance, String currencySymbol) {
    // Always show full decimal precision for treasury balances
    final formattedNumber = balance.toStringAsFixed(2);

    // Add thousand separators for better readability
    final parts = formattedNumber.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '00';

    // Add thousand separators to integer part
    String formattedInteger = '';
    for (int i = 0; i < integerPart.length; i++) {
      if (i > 0 && (integerPart.length - i) % 3 == 0) {
        formattedInteger += ',';
      }
      formattedInteger += integerPart[i];
    }

    return '$formattedInteger.$decimalPart $currencySymbol';
  }

  /// Format treasury balance for display in AnimatedBalanceWidget
  static String formatAnimatedBalance(double balance) {
    // For animated balance, use consistent decimal precision
    if (balance.abs() >= 1000000000) {
      // Billions - show abbreviated format with full precision
      return '${(balance / 1000000000).toStringAsFixed(2)}B';
    } else if (balance.abs() >= 1000000) {
      // Millions - show abbreviated format with full precision
      return '${(balance / 1000000).toStringAsFixed(2)}M';
    } else {
      // For amounts under one million, always show full precision with thousand separators
      return _addThousandSeparators(balance.toStringAsFixed(2));
    }
  }

  /// Add thousand separators to a formatted number string
  static String _addThousandSeparators(String numberString) {
    final parts = numberString.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '';

    String formattedInteger = '';
    for (int i = 0; i < integerPart.length; i++) {
      if (i > 0 && (integerPart.length - i) % 3 == 0) {
        formattedInteger += ',';
      }
      formattedInteger += integerPart[i];
    }

    return decimalPart.isNotEmpty ? '$formattedInteger.$decimalPart' : formattedInteger;
  }

  /// Convert SAR to EGP using current exchange rate
  static double convertSarToEgp(double sarAmount) {
    const double exchangeRate = 8.25; // 1 SAR = 8.25 EGP
    return sarAmount * exchangeRate;
  }

  /// Format currency with automatic SAR to EGP conversion
  static String formatCurrencyWithConversion(double value, {String fromCurrency = 'SAR'}) {
    double egpValue = value;
    if (fromCurrency == 'SAR') {
      egpValue = convertSarToEgp(value);
    }
    return formatEgyptianPound(egpValue);
  }

  static String formatNumber(num value) {
    return _numberFormatter.format(value);
  }

  static String formatDate(DateTime date) {
    // Convert to local time if UTC to ensure proper timezone handling
    final localDate = date.isUtc ? date.toLocal() : date;
    return _dateFormatter.format(localDate);
  }

  static String formatTime(DateTime time) {
    // Convert to local time if UTC to ensure proper timezone handling
    final localTime = time.isUtc ? time.toLocal() : time;
    return _timeFormatter.format(localTime);
  }

  static String formatDateTime(DateTime dateTime) {
    // Convert to local time if UTC to ensure proper timezone handling
    final localDateTime = dateTime.isUtc ? dateTime.toLocal() : dateTime;
    return _dateTimeFormatter.format(localDateTime);
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  static String formatPercentage(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  static String formatPhoneNumber(String phoneNumber) {
    // Remove any non-digit characters
    final digits = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.length <= 3) {
      return digits;
    }
    if (digits.length <= 6) {
      return '${digits.substring(0, 3)}-${digits.substring(3)}';
    }
    if (digits.length <= 10) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6, 10)}';
  }

  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  static String titleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) => capitalize(word)).join(' ');
  }

  static String snakeToTitleCase(String text) {
    return titleCase(text.replaceAll('_', ' ').toLowerCase());
  }

  static String formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    }
    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    }
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    }
    if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    }
    return 'Just now';
  }
}
