import 'package:intl/intl.dart';
import 'constants.dart';

class Formatters {
    static final _currencyFormatter = NumberFormat.currency(    symbol: 'جنيه ',    decimalDigits: 2,  );

  static final _numberFormatter = NumberFormat.decimalPattern();
  static final _dateFormatter = DateFormat(AppConstants.dateFormat);
  static final _timeFormatter = DateFormat(AppConstants.timeFormat);
  static final _dateTimeFormatter = DateFormat(AppConstants.dateTimeFormat);

  static String formatCurrency(double value) {
    return _currencyFormatter.format(value);
  }

    static String formatEgyptianPound(double value) {    return '${value.toStringAsFixed(2)} جنيه';  }

  static String formatNumber(num value) {
    return _numberFormatter.format(value);
  }

  static String formatDate(DateTime date) {
    return _dateFormatter.format(date);
  }

  static String formatTime(DateTime time) {
    return _timeFormatter.format(time);
  }

  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormatter.format(dateTime);
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
