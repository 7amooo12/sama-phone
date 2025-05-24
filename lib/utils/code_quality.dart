import 'dart:io';
import 'package:flutter/foundation.dart';
import 'import_cleaner.dart';
import 'naming_convention.dart';

/// A utility class for improving code quality in the project
class CodeQuality {
  /// Run all code quality checks on a file
  static void analyzeFile(String filePath) {
    if (!kDebugMode) return;

    try {
      debugPrint('=== Analyzing file: $filePath ===');
      ImportCleaner.checkUnusedImports(filePath);
      NamingConvention.checkConstantsNaming(filePath);
      _checkForUnnecessaryNulls(filePath);
      _checkForLongFunctions(filePath);
      debugPrint('=== Analysis complete ===\n');
    } catch (e) {
      debugPrint('Error analyzing file: $e');
    }
  }

  /// Apply all code quality improvements to a file
  static void improveFile(String filePath) {
    if (!kDebugMode) return;

    try {
      debugPrint('=== Improving file: $filePath ===');
      bool madeChanges = false;

      final importsFixed = ImportCleaner.removeUnusedImports(filePath);
      final constantsFixed =
          NamingConvention.transformConstantsToCamelCase(filePath);

      madeChanges = importsFixed || constantsFixed;

      if (madeChanges) {
        debugPrint('Made improvements to $filePath');
      } else {
        debugPrint('No improvements needed for $filePath');
      }
      debugPrint('=== Improvements complete ===\n');
    } catch (e) {
      debugPrint('Error improving file: $e');
    }
  }

  /// Run all code quality checks on all Dart files in a directory
  static void analyzeDirectory(String directoryPath, {bool recursive = true}) {
    if (!kDebugMode) return;

    try {
      final dir = Directory(directoryPath);
      if (!dir.existsSync()) {
        debugPrint('Directory not found: $directoryPath');
        return;
      }

      debugPrint('=== Analyzing directory: $directoryPath ===');
      final dartFiles = _findDartFiles(dir, recursive);

      for (final file in dartFiles) {
        analyzeFile(file.path);
      }

      debugPrint('=== Directory analysis complete ===\n');
    } catch (e) {
      debugPrint('Error analyzing directory: $e');
    }
  }

  /// Apply all code quality improvements to all Dart files in a directory
  static void improveDirectory(String directoryPath, {bool recursive = true}) {
    if (!kDebugMode) return;

    try {
      final dir = Directory(directoryPath);
      if (!dir.existsSync()) {
        debugPrint('Directory not found: $directoryPath');
        return;
      }

      debugPrint('=== Improving directory: $directoryPath ===');
      final dartFiles = _findDartFiles(dir, recursive);

      for (final file in dartFiles) {
        improveFile(file.path);
      }

      debugPrint('=== Directory improvements complete ===\n');
    } catch (e) {
      debugPrint('Error improving directory: $e');
    }
  }

  /// Find all Dart files in a directory
  static List<File> _findDartFiles(Directory directory, bool recursive) {
    final files = <File>[];

    try {
      final entities = directory.listSync(recursive: recursive);

      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.dart')) {
          files.add(entity);
        }
      }
    } catch (e) {
      debugPrint('Error finding Dart files: $e');
    }

    return files;
  }

  /// Check for unnecessary null checks or null-aware operators
  static void _checkForUnnecessaryNulls(String filePath) {
    if (!kDebugMode) return;

    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        debugPrint('File not found: $filePath');
        return;
      }

      final content = file.readAsStringSync();
      final lines = content.split('\n');

      final reqPattern = RegExp(r'required\s+this\.(\w+),');
      final nullablePattern = RegExp(r'(\w+)\?\?');

      final requiredFields = <String>{};
      final nullCheckedFields = <String>{};

      // Find required fields
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();

        // Find required fields in constructor
        final reqMatches = reqPattern.allMatches(line);
        for (final match in reqMatches) {
          requiredFields.add(match.group(1)!);
        }

        // Find null-checked fields
        final nullMatches = nullablePattern.allMatches(line);
        for (final match in nullMatches) {
          nullCheckedFields.add(match.group(1)!);
        }
      }

      // Report unnecessary null checks on required fields
      final unnecessaryChecks = <String>[];
      for (final field in nullCheckedFields) {
        if (requiredFields.contains(field)) {
          unnecessaryChecks.add(field);
        }
      }

      if (unnecessaryChecks.isNotEmpty) {
        debugPrint(
            'Found ${unnecessaryChecks.length} unnecessary null checks in $filePath:');
        for (final field in unnecessaryChecks) {
          debugPrint('  $field is marked as required but has null checks');
        }
      }
    } catch (e) {
      debugPrint('Error checking for unnecessary nulls: $e');
    }
  }

  /// Check for excessively long functions (over 50 lines)
  static void _checkForLongFunctions(String filePath) {
    if (!kDebugMode) return;

    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        debugPrint('File not found: $filePath');
        return;
      }

      final content = file.readAsStringSync();
      final lines = content.split('\n');

      bool inFunction = false;
      String? currentFunction;
      int functionStartLine = 0;
      final longFunctions = <String, int>{};

      // Simple pattern to detect function declarations
      final funcPattern = RegExp(r'(\w+)\s*\([^)]*\)\s*(?:async\s*)?{');

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();

        if (!inFunction) {
          final match = funcPattern.firstMatch(line);
          if (match != null) {
            inFunction = true;
            currentFunction = match.group(1);
            functionStartLine = i;
          }
        } else if (line == '}') {
          // Function may have ended
          final length = i - functionStartLine;
          if (length > 50 && currentFunction != null) {
            longFunctions[currentFunction] = length;
          }
          inFunction = false;
          currentFunction = null;
        }
      }

      if (longFunctions.isNotEmpty) {
        debugPrint(
            'Found ${longFunctions.length} excessively long functions in $filePath:');
        longFunctions.forEach((function, length) {
          debugPrint(
              '  $function is $length lines long (recommended: < 50 lines)');
        });
      }
    } catch (e) {
      debugPrint('Error checking for long functions: $e');
    }
  }
}
