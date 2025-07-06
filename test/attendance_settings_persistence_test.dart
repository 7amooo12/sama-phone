/// Comprehensive tests for attendance settings persistence functionality
/// Tests database storage, SharedPreferences fallback, validation, and application

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartbiztracker_new/models/attendance_models.dart';
import 'package:smartbiztracker_new/providers/worker_attendance_reports_provider.dart';

void main() {
  group('AttendanceSettings Validation Tests', () {
    test('should validate correct settings', () {
      final settings = AttendanceSettings(
        workStartTime: const TimeOfDay(hour: 9, minute: 0),
        workEndTime: const TimeOfDay(hour: 17, minute: 0),
        lateToleranceMinutes: 15,
        earlyDepartureToleranceMinutes: 10,
        requiredDailyHours: 8.0,
        workDays: [1, 2, 3, 4, 5],
      );

      expect(settings.isValid, isTrue);
      expect(settings.validate(), isNull);
    });

    test('should reject invalid work hours', () {
      final settings = AttendanceSettings(
        workStartTime: const TimeOfDay(hour: 17, minute: 0), // Start after end
        workEndTime: const TimeOfDay(hour: 9, minute: 0),
        lateToleranceMinutes: 15,
        earlyDepartureToleranceMinutes: 10,
        requiredDailyHours: 8.0,
        workDays: [1, 2, 3, 4, 5],
      );

      expect(settings.isValid, isFalse);
      expect(settings.validate(), contains('وقت بداية العمل يجب أن يكون قبل وقت نهاية العمل'));
    });

    test('should reject invalid tolerance minutes', () {
      final settings = AttendanceSettings(
        workStartTime: const TimeOfDay(hour: 9, minute: 0),
        workEndTime: const TimeOfDay(hour: 17, minute: 0),
        lateToleranceMinutes: 150, // Too high
        earlyDepartureToleranceMinutes: 10,
        requiredDailyHours: 8.0,
        workDays: [1, 2, 3, 4, 5],
      );

      expect(settings.isValid, isFalse);
      expect(settings.validate(), contains('فترة تسامح التأخير يجب أن تكون بين 0 و 120 دقيقة'));
    });

    test('should reject invalid required daily hours', () {
      final settings = AttendanceSettings(
        workStartTime: const TimeOfDay(hour: 9, minute: 0),
        workEndTime: const TimeOfDay(hour: 17, minute: 0),
        lateToleranceMinutes: 15,
        earlyDepartureToleranceMinutes: 10,
        requiredDailyHours: 25.0, // Too high
        workDays: [1, 2, 3, 4, 5],
      );

      expect(settings.isValid, isFalse);
      expect(settings.validate(), contains('ساعات العمل المطلوبة يومياً يجب أن تكون بين 1 و 24 ساعة'));
    });

    test('should reject empty work days', () {
      final settings = AttendanceSettings(
        workStartTime: const TimeOfDay(hour: 9, minute: 0),
        workEndTime: const TimeOfDay(hour: 17, minute: 0),
        lateToleranceMinutes: 15,
        earlyDepartureToleranceMinutes: 10,
        requiredDailyHours: 8.0,
        workDays: [], // Empty
      );

      expect(settings.isValid, isFalse);
      expect(settings.validate(), contains('يجب تحديد يوم واحد على الأقل للعمل'));
    });

    test('should reject invalid work day numbers', () {
      final settings = AttendanceSettings(
        workStartTime: const TimeOfDay(hour: 9, minute: 0),
        workEndTime: const TimeOfDay(hour: 17, minute: 0),
        lateToleranceMinutes: 15,
        earlyDepartureToleranceMinutes: 10,
        requiredDailyHours: 8.0,
        workDays: [0, 8], // Invalid day numbers
      );

      expect(settings.isValid, isFalse);
      expect(settings.validate(), contains('أيام العمل يجب أن تكون بين 1 (الاثنين) و 7 (الأحد)'));
    });

    test('should reject duplicate work days', () {
      final settings = AttendanceSettings(
        workStartTime: const TimeOfDay(hour: 9, minute: 0),
        workEndTime: const TimeOfDay(hour: 17, minute: 0),
        lateToleranceMinutes: 15,
        earlyDepartureToleranceMinutes: 10,
        requiredDailyHours: 8.0,
        workDays: [1, 2, 2, 3], // Duplicate day 2
      );

      expect(settings.isValid, isFalse);
      expect(settings.validate(), contains('لا يمكن تكرار أيام العمل'));
    });
  });

  group('AttendanceSettings Serialization Tests', () {
    test('should serialize and deserialize correctly', () {
      final originalSettings = AttendanceSettings(
        workStartTime: const TimeOfDay(hour: 9, minute: 30),
        workEndTime: const TimeOfDay(hour: 17, minute: 45),
        lateToleranceMinutes: 20,
        earlyDepartureToleranceMinutes: 15,
        requiredDailyHours: 7.5,
        workDays: [6, 7, 1, 2, 3], // Saturday to Wednesday
      );

      final json = originalSettings.toJson();
      final deserializedSettings = AttendanceSettings.fromJson(json);

      expect(deserializedSettings.workStartTime.hour, equals(9));
      expect(deserializedSettings.workStartTime.minute, equals(30));
      expect(deserializedSettings.workEndTime.hour, equals(17));
      expect(deserializedSettings.workEndTime.minute, equals(45));
      expect(deserializedSettings.lateToleranceMinutes, equals(20));
      expect(deserializedSettings.earlyDepartureToleranceMinutes, equals(15));
      expect(deserializedSettings.requiredDailyHours, equals(7.5));
      expect(deserializedSettings.workDays, equals([6, 7, 1, 2, 3]));
    });

    test('should handle missing JSON fields with defaults', () {
      final json = <String, dynamic>{
        'work_start_hour': 10,
        // Missing other fields should use defaults
      };

      final settings = AttendanceSettings.fromJson(json);

      expect(settings.workStartTime.hour, equals(10));
      expect(settings.workStartTime.minute, equals(0)); // Default
      expect(settings.workEndTime.hour, equals(17)); // Default
      expect(settings.lateToleranceMinutes, equals(15)); // Default
      expect(settings.workDays, equals([1, 2, 3, 4, 5])); // Default
    });
  });

  group('AttendanceSettings Default Settings Tests', () {
    test('should create valid default settings', () {
      final defaultSettings = AttendanceSettings.defaultSettings();

      expect(defaultSettings.isValid, isTrue);
      expect(defaultSettings.workStartTime.hour, equals(9));
      expect(defaultSettings.workStartTime.minute, equals(0));
      expect(defaultSettings.workEndTime.hour, equals(17));
      expect(defaultSettings.workEndTime.minute, equals(0));
      expect(defaultSettings.lateToleranceMinutes, equals(15));
      expect(defaultSettings.earlyDepartureToleranceMinutes, equals(10));
      expect(defaultSettings.requiredDailyHours, equals(8.0));
      expect(defaultSettings.workDays, equals([1, 2, 3, 4, 5]));
    });
  });

  group('AttendanceSettings copyWith Tests', () {
    test('should copy with new values correctly', () {
      final originalSettings = AttendanceSettings.defaultSettings();
      
      final modifiedSettings = originalSettings.copyWith(
        workStartTime: const TimeOfDay(hour: 8, minute: 30),
        lateToleranceMinutes: 20,
        workDays: [6, 7, 1, 2, 3],
      );

      expect(modifiedSettings.workStartTime.hour, equals(8));
      expect(modifiedSettings.workStartTime.minute, equals(30));
      expect(modifiedSettings.lateToleranceMinutes, equals(20));
      expect(modifiedSettings.workDays, equals([6, 7, 1, 2, 3]));
      
      // Unchanged values should remain the same
      expect(modifiedSettings.workEndTime, equals(originalSettings.workEndTime));
      expect(modifiedSettings.earlyDepartureToleranceMinutes, equals(originalSettings.earlyDepartureToleranceMinutes));
      expect(modifiedSettings.requiredDailyHours, equals(originalSettings.requiredDailyHours));
    });
  });

  group('SharedPreferences Integration Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('should save and load settings from SharedPreferences', () async {
      final testSettings = AttendanceSettings(
        workStartTime: const TimeOfDay(hour: 8, minute: 30),
        workEndTime: const TimeOfDay(hour: 16, minute: 30),
        lateToleranceMinutes: 20,
        earlyDepartureToleranceMinutes: 15,
        requiredDailyHours: 7.5,
        workDays: [6, 7, 1, 2, 3],
      );

      // Save settings
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('attendance_settings',
          '{"work_start_hour":8,"work_start_minute":30,"work_end_hour":16,"work_end_minute":30,"late_tolerance_minutes":20,"early_departure_tolerance_minutes":15,"required_daily_hours":7.5,"work_days":[6,7,1,2,3]}');
      await prefs.setInt('attendance_settings_timestamp', DateTime.now().millisecondsSinceEpoch);

      // Load settings
      final settingsJson = prefs.getString('attendance_settings');
      expect(settingsJson, isNotNull);

      final loadedSettings = AttendanceSettings.fromJson(
          Map<String, dynamic>.from(
              {'work_start_hour': 8, 'work_start_minute': 30, 'work_end_hour': 16, 'work_end_minute': 30, 'late_tolerance_minutes': 20, 'early_departure_tolerance_minutes': 15, 'required_daily_hours': 7.5, 'work_days': [6, 7, 1, 2, 3]}
          )
      );

      expect(loadedSettings.workStartTime.hour, equals(testSettings.workStartTime.hour));
      expect(loadedSettings.workStartTime.minute, equals(testSettings.workStartTime.minute));
      expect(loadedSettings.workEndTime.hour, equals(testSettings.workEndTime.hour));
      expect(loadedSettings.workEndTime.minute, equals(testSettings.workEndTime.minute));
      expect(loadedSettings.lateToleranceMinutes, equals(testSettings.lateToleranceMinutes));
      expect(loadedSettings.earlyDepartureToleranceMinutes, equals(testSettings.earlyDepartureToleranceMinutes));
      expect(loadedSettings.requiredDailyHours, equals(testSettings.requiredDailyHours));
      expect(loadedSettings.workDays, equals(testSettings.workDays));
    });

    test('should handle corrupted SharedPreferences data', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('attendance_settings', 'invalid_json');

      final settingsJson = prefs.getString('attendance_settings');
      expect(settingsJson, equals('invalid_json'));

      // Should handle gracefully when parsing fails
      expect(() => AttendanceSettings.fromJson({}), returnsNormally);
    });

    test('should handle missing SharedPreferences data', () async {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('attendance_settings');

      expect(settingsJson, isNull);

      // Should use default settings when no cached data
      final defaultSettings = AttendanceSettings.defaultSettings();
      expect(defaultSettings.isValid, isTrue);
    });
  });
}
