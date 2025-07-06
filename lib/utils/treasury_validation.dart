import 'package:flutter/material.dart';

/// Comprehensive validation utilities for treasury management
class TreasuryValidation {
  /// Validate treasury vault data
  static List<String> validateTreasuryVault({
    required String name,
    required String currency,
    required double balance,
    required double exchangeRate,
    String? bankName,
    String? accountNumber,
    String? accountHolderName,
  }) {
    final errors = <String>[];

    // Name validation
    if (name.trim().isEmpty) {
      errors.add('اسم الخزنة مطلوب');
    } else if (name.trim().length < 2) {
      errors.add('اسم الخزنة يجب أن يكون على الأقل حرفين');
    } else if (name.trim().length > 100) {
      errors.add('اسم الخزنة يجب أن يكون أقل من 100 حرف');
    }

    // Currency validation
    if (currency.trim().isEmpty) {
      errors.add('العملة مطلوبة');
    } else if (!_isValidCurrency(currency)) {
      errors.add('العملة غير صحيحة');
    }

    // Balance validation
    if (balance < 0) {
      errors.add('الرصيد لا يمكن أن يكون سالباً');
    } else if (balance > 999999999.99) {
      errors.add('الرصيد كبير جداً');
    }

    // Exchange rate validation
    if (exchangeRate <= 0) {
      errors.add('سعر الصرف يجب أن يكون أكبر من صفر');
    } else if (exchangeRate > 1000) {
      errors.add('سعر الصرف كبير جداً');
    }

    // Bank account validation (if provided)
    if (bankName != null && bankName.trim().isNotEmpty) {
      if (accountNumber == null || accountNumber.trim().isEmpty) {
        errors.add('رقم الحساب مطلوب عند تحديد البنك');
      } else if (!_isValidAccountNumber(accountNumber)) {
        errors.add('رقم الحساب غير صحيح');
      }

      if (accountHolderName == null || accountHolderName.trim().isEmpty) {
        errors.add('اسم صاحب الحساب مطلوب عند تحديد البنك');
      } else if (accountHolderName.trim().length < 2) {
        errors.add('اسم صاحب الحساب يجب أن يكون على الأقل حرفين');
      }
    }

    return errors;
  }

  /// Validate treasury transaction data
  static List<String> validateTreasuryTransaction({
    required String description,
    required double amount,
    required String transactionType,
    String? referenceId,
    String? notes,
  }) {
    final errors = <String>[];

    // Description validation
    if (description.trim().isEmpty) {
      errors.add('وصف المعاملة مطلوب');
    } else if (description.trim().length < 3) {
      errors.add('وصف المعاملة يجب أن يكون على الأقل 3 أحرف');
    } else if (description.trim().length > 500) {
      errors.add('وصف المعاملة يجب أن يكون أقل من 500 حرف');
    }

    // Amount validation
    if (amount <= 0) {
      errors.add('مبلغ المعاملة يجب أن يكون أكبر من صفر');
    } else if (amount > 999999999.99) {
      errors.add('مبلغ المعاملة كبير جداً');
    }

    // Transaction type validation
    if (transactionType.trim().isEmpty) {
      errors.add('نوع المعاملة مطلوب');
    } else if (!_isValidTransactionType(transactionType)) {
      errors.add('نوع المعاملة غير صحيح');
    }

    // Reference ID validation (if provided)
    if (referenceId != null && referenceId.trim().isNotEmpty) {
      if (referenceId.trim().length < 3) {
        errors.add('المرجع يجب أن يكون على الأقل 3 أحرف');
      } else if (referenceId.trim().length > 50) {
        errors.add('المرجع يجب أن يكون أقل من 50 حرف');
      }
    }

    // Notes validation (if provided)
    if (notes != null && notes.trim().isNotEmpty) {
      if (notes.trim().length > 1000) {
        errors.add('الملاحظات يجب أن تكون أقل من 1000 حرف');
      }
    }

    return errors;
  }

  /// Validate fund transfer data
  static List<String> validateFundTransfer({
    required String fromTreasuryId,
    required String toTreasuryId,
    required double amount,
    required String description,
    double? exchangeRate,
    String? notes,
  }) {
    final errors = <String>[];

    // Treasury IDs validation
    if (fromTreasuryId.trim().isEmpty) {
      errors.add('خزنة المصدر مطلوبة');
    }

    if (toTreasuryId.trim().isEmpty) {
      errors.add('خزنة الوجهة مطلوبة');
    }

    if (fromTreasuryId == toTreasuryId) {
      errors.add('لا يمكن التحويل من وإلى نفس الخزنة');
    }

    // Amount validation
    if (amount <= 0) {
      errors.add('مبلغ التحويل يجب أن يكون أكبر من صفر');
    } else if (amount > 999999999.99) {
      errors.add('مبلغ التحويل كبير جداً');
    }

    // Description validation
    if (description.trim().isEmpty) {
      errors.add('وصف التحويل مطلوب');
    } else if (description.trim().length < 3) {
      errors.add('وصف التحويل يجب أن يكون على الأقل 3 أحرف');
    }

    // Exchange rate validation (if provided)
    if (exchangeRate != null) {
      if (exchangeRate <= 0) {
        errors.add('سعر الصرف يجب أن يكون أكبر من صفر');
      } else if (exchangeRate > 1000) {
        errors.add('سعر الصرف كبير جداً');
      }
    }

    return errors;
  }

  /// Validate treasury limit data
  static List<String> validateTreasuryLimit({
    required String limitType,
    required double limitValue,
    required double warningThreshold,
    required double criticalThreshold,
  }) {
    final errors = <String>[];

    // Limit type validation
    if (limitType.trim().isEmpty) {
      errors.add('نوع الحد مطلوب');
    } else if (!_isValidLimitType(limitType)) {
      errors.add('نوع الحد غير صحيح');
    }

    // Limit value validation
    if (limitValue < 0) {
      errors.add('قيمة الحد لا يمكن أن تكون سالبة');
    } else if (limitValue > 999999999.99) {
      errors.add('قيمة الحد كبيرة جداً');
    }

    // Threshold validation
    if (warningThreshold < 0 || warningThreshold > 100) {
      errors.add('عتبة التحذير يجب أن تكون بين 0 و 100');
    }

    if (criticalThreshold < 0 || criticalThreshold > 100) {
      errors.add('العتبة الحرجة يجب أن تكون بين 0 و 100');
    }

    if (warningThreshold > criticalThreshold) {
      errors.add('عتبة التحذير يجب أن تكون أقل من أو تساوي العتبة الحرجة');
    }

    return errors;
  }

  /// Validate backup configuration data
  static List<String> validateBackupConfig({
    required String name,
    required String backupType,
    required String scheduleType,
    String? scheduleFrequency,
    TimeOfDay? scheduleTime,
    int? scheduleDayOfWeek,
    int? scheduleDayOfMonth,
    required int retentionDays,
  }) {
    final errors = <String>[];

    // Name validation
    if (name.trim().isEmpty) {
      errors.add('اسم إعداد النسخ الاحتياطي مطلوب');
    } else if (name.trim().length < 3) {
      errors.add('اسم إعداد النسخ الاحتياطي يجب أن يكون على الأقل 3 أحرف');
    }

    // Backup type validation
    if (!_isValidBackupType(backupType)) {
      errors.add('نوع النسخ الاحتياطي غير صحيح');
    }

    // Schedule type validation
    if (!_isValidScheduleType(scheduleType)) {
      errors.add('نوع الجدولة غير صحيح');
    }

    // Schedule validation for scheduled backups
    if (scheduleType == 'scheduled') {
      if (scheduleFrequency == null || scheduleFrequency.trim().isEmpty) {
        errors.add('تكرار الجدولة مطلوب للنسخ المجدولة');
      } else if (!_isValidScheduleFrequency(scheduleFrequency)) {
        errors.add('تكرار الجدولة غير صحيح');
      }

      if (scheduleFrequency == 'weekly' && (scheduleDayOfWeek == null || scheduleDayOfWeek < 0 || scheduleDayOfWeek > 6)) {
        errors.add('يوم الأسبوع غير صحيح للجدولة الأسبوعية');
      }

      if (scheduleFrequency == 'monthly' && (scheduleDayOfMonth == null || scheduleDayOfMonth < 1 || scheduleDayOfMonth > 31)) {
        errors.add('يوم الشهر غير صحيح للجدولة الشهرية');
      }
    }

    // Retention days validation
    if (retentionDays < 1) {
      errors.add('أيام الاحتفاظ يجب أن تكون على الأقل يوم واحد');
    } else if (retentionDays > 365) {
      errors.add('أيام الاحتفاظ يجب أن تكون أقل من أو تساوي 365 يوم');
    }

    return errors;
  }

  /// Validate phone number for electronic wallets
  static List<String> validatePhoneNumber(String phoneNumber) {
    final errors = <String>[];

    if (phoneNumber.trim().isEmpty) {
      errors.add('رقم الهاتف مطلوب');
      return errors;
    }

    // Remove spaces and special characters
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // Egyptian phone number validation
    if (!_isValidEgyptianPhoneNumber(cleanNumber)) {
      errors.add('رقم الهاتف غير صحيح. يجب أن يكون رقم مصري صحيح');
    }

    return errors;
  }

  /// Validate wallet name
  static List<String> validateWalletName(String name) {
    final errors = <String>[];

    if (name.trim().isEmpty) {
      errors.add('اسم المحفظة مطلوب');
    } else if (name.trim().length < 2) {
      errors.add('اسم المحفظة يجب أن يكون على الأقل حرفين');
    } else if (name.trim().length > 100) {
      errors.add('اسم المحفظة يجب أن يكون أقل من 100 حرف');
    }

    return errors;
  }

  // Private helper methods
  static bool _isValidCurrency(String currency) {
    const validCurrencies = ['EGP', 'USD', 'EUR', 'SAR', 'AED'];
    return validCurrencies.contains(currency.toUpperCase());
  }

  static bool _isValidAccountNumber(String accountNumber) {
    // Basic account number validation (digits only, 8-20 characters)
    return RegExp(r'^\d{8,20}$').hasMatch(accountNumber.trim());
  }

  static bool _isValidTransactionType(String type) {
    const validTypes = [
      'credit',
      'debit',
      'connection',
      'disconnection',
      'exchange_rate_update',
      'transfer_in',
      'transfer_out',
      'balance_adjustment'
    ];
    return validTypes.contains(type.toLowerCase());
  }

  static bool _isValidLimitType(String type) {
    const validTypes = ['min_balance', 'max_balance', 'daily_transaction', 'monthly_transaction'];
    return validTypes.contains(type.toLowerCase());
  }

  static bool _isValidBackupType(String type) {
    const validTypes = ['full', 'incremental', 'differential'];
    return validTypes.contains(type.toLowerCase());
  }

  static bool _isValidScheduleType(String type) {
    const validTypes = ['manual', 'scheduled'];
    return validTypes.contains(type.toLowerCase());
  }

  static bool _isValidScheduleFrequency(String frequency) {
    const validFrequencies = ['daily', 'weekly', 'monthly'];
    return validFrequencies.contains(frequency.toLowerCase());
  }

  static bool _isValidEgyptianPhoneNumber(String phoneNumber) {
    // Egyptian mobile numbers: +201xxxxxxxxx or 01xxxxxxxxx
    return RegExp(r'^(\+201|01)[0-9]{9}$').hasMatch(phoneNumber) ||
           RegExp(r'^(\+2010|010)[0-9]{8}$').hasMatch(phoneNumber) ||
           RegExp(r'^(\+2011|011)[0-9]{8}$').hasMatch(phoneNumber) ||
           RegExp(r'^(\+2012|012)[0-9]{8}$').hasMatch(phoneNumber) ||
           RegExp(r'^(\+2015|015)[0-9]{8}$').hasMatch(phoneNumber);
  }
}
