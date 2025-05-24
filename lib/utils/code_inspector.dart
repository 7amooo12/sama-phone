import 'package:flutter/foundation.dart';
import 'code_quality.dart';
import 'import_cleaner.dart';
import 'naming_convention.dart';

/// A simple entry point for code quality tools.
/// Usage:
/// ```dart
/// // To analyze a single file
/// CodeInspector.analyzeFile('lib/models/user_model.dart');
///
/// // To analyze all Dart files in the models directory
/// CodeInspector.analyzeDirectory('lib/models');
///
/// // To improve a single file by removing unused imports and fixing naming conventions
/// CodeInspector.improveFile('lib/models/user_model.dart');
///
/// // To improve all files in a directory
/// CodeInspector.improveDirectory('lib/models');
/// ```
class CodeInspector {
  /// Analyze a single file for code quality issues
  static void analyzeFile(String filePath) {
    CodeQuality.analyzeFile(filePath);
  }

  /// Analyze all Dart files in a directory for code quality issues
  static void analyzeDirectory(String directoryPath, {bool recursive = true}) {
    CodeQuality.analyzeDirectory(directoryPath, recursive: recursive);
  }

  /// Apply code quality improvements to a single file
  static void improveFile(String filePath) {
    CodeQuality.improveFile(filePath);
  }

  /// Apply code quality improvements to all Dart files in a directory
  static void improveDirectory(String directoryPath, {bool recursive = true}) {
    CodeQuality.improveDirectory(directoryPath, recursive: recursive);
  }

  /// Check if a file has unused imports
  static void checkUnusedImports(String filePath) {
    ImportCleaner.checkUnusedImports(filePath);
  }

  /// Remove unused imports from a file
  static void removeUnusedImports(String filePath) {
    ImportCleaner.removeUnusedImports(filePath);
  }

  /// Check if a file has uppercase constants that should be camelCase
  static void checkConstantsNaming(String filePath) {
    NamingConvention.checkConstantsNaming(filePath);
  }

  /// Transform uppercase constants to camelCase in a file
  static void transformConstantsToCamelCase(String filePath) {
    NamingConvention.transformConstantsToCamelCase(filePath);
  }

  /// A quick function to run all checks on the entire project
  static void analyzeProject() {
    if (!kDebugMode) return;

    debugPrint('====== Starting SmartBizTracker Code Analysis ======');

    // Analyze the main directories
    CodeQuality.analyzeDirectory('lib/models');
    CodeQuality.analyzeDirectory('lib/screens');
    CodeQuality.analyzeDirectory('lib/providers');
    CodeQuality.analyzeDirectory('lib/services');
    CodeQuality.analyzeDirectory('lib/utils');
    CodeQuality.analyzeDirectory('lib/widgets');

    debugPrint('====== Analysis Complete ======');
  }

  /// A quick function to apply all improvements to the entire project
  static void improveProject({bool dryRun = true}) {
    if (!kDebugMode) return;

    if (dryRun) {
      debugPrint('====== [DRY RUN] SmartBizTracker Code Improvements ======');
      debugPrint('This is a dry run. No changes will be made.');
      debugPrint(
          'To make actual changes, call this function with dryRun: false');
      analyzeProject();
      return;
    }

    debugPrint('====== Starting SmartBizTracker Code Improvements ======');

    // Improve the main directories
    CodeQuality.improveDirectory('lib/models');
    CodeQuality.improveDirectory('lib/screens');
    CodeQuality.improveDirectory('lib/providers');
    CodeQuality.improveDirectory('lib/services');
    CodeQuality.improveDirectory('lib/utils');
    CodeQuality.improveDirectory('lib/widgets');

    debugPrint('====== Improvements Complete ======');
  }
}
