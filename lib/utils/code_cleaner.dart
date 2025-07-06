import 'dart:io';
import 'package:flutter/foundation.dart';

/// A utility class to help with removing dead code and improving performance
class CodeCleaner {
  /// List of files or directories that should be ignored when cleaning
  static const List<String> _ignoreList = [
    'no_firebase_main.dart',
    'simple_main.dart',
    'minimal_main.dart',
    'flask_main.dart',
    'test',
    'temp',
  ];

  /// List of common unused imports to remove
  static const List<String> _commonUnusedImports = [
    "import 'package:smartbiztracker_new/screens/transition_screen.dart';",
    "import 'robot_web_view_preloader.dart';",
    "import 'package:smartbiztracker_new/utils/code_inspector.dart';",
    "import 'code_quality.dart';",
    "import 'naming_convention.dart';",
  ];

  /// Cleans up unused imports in a Dart file
  static bool cleanImports(String filePath) {
    if (!_shouldProcessFile(filePath)) {
      return false;
    }

    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return false;
      }

      String content = file.readAsStringSync();
      bool madeChanges = false;

      // Remove common unused imports
      for (final unusedImport in _commonUnusedImports) {
        if (content.contains(unusedImport)) {
          content = content.replaceAll('$unusedImport\n', '');
          madeChanges = true;
        }
      }

      // Save changes if any were made
      if (madeChanges) {
        file.writeAsStringSync(content);
        if (kDebugMode) {
          print('Cleaned imports in $filePath');
        }
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error cleaning imports in $filePath: $e');
      }
      return false;
    }
  }

  /// Cleans up duplicate provider declarations
  static bool cleanDuplicateProviders(String filePath) {
    if (!_shouldProcessFile(filePath)) {
      return false;
    }

    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return false;
      }

      String content = file.readAsStringSync();
      final firstIndex = content.indexOf('MultiProvider(\n      providers: [');
      final bool hasDuplicateProviders = firstIndex >= 0 &&
                                   content.indexOf('MultiProvider(\n      providers: [', firstIndex + 20) >= 0;

      if (hasDuplicateProviders) {
        // Extract the second MultiProvider section and remove it
        final int firstProviderIndex = content.indexOf('MultiProvider(\n      providers: [');
        final int secondProviderIndex = content.indexOf('MultiProvider(\n      providers: [', firstProviderIndex + 20);

        if (secondProviderIndex > 0) {
          final int secondProviderEnd = _findClosingBracket(content, secondProviderIndex);
          if (secondProviderEnd > 0) {
            final String beforeSecondProvider = content.substring(0, secondProviderIndex);
            final String afterSecondProvider = content.substring(secondProviderEnd + 1);
            content = beforeSecondProvider + afterSecondProvider;

            file.writeAsStringSync(content);
            if (kDebugMode) {
              print('Removed duplicate providers in $filePath');
            }
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error cleaning duplicate providers in $filePath: $e');
      }
      return false;
    }
  }

  /// Finds the position of the closing bracket that matches the opening bracket at the given position
  static int _findClosingBracket(String text, int openingPosition) {
    // Find the first opening bracket starting from the given position
    final int openingBracket = text.indexOf('(', openingPosition);
    if (openingBracket < 0) return -1;

    int count = 1;
    for (int i = openingBracket + 1; i < text.length; i++) {
      if (text[i] == '(') {
        count++;
      } else if (text[i] == ')') {
        count--;
        if (count == 0) {
          return i;
        }
      }
    }

    return -1;
  }

  /// Determines if a file should be processed
  static bool _shouldProcessFile(String filePath) {
    // Make sure it's a Dart file
    if (!filePath.endsWith('.dart')) {
      return false;
    }

    // Check if it's in the ignore list
    for (final ignore in _ignoreList) {
      if (filePath.contains(ignore)) {
        return false;
      }
    }

    return true;
  }

  /// Clean all Dart files in a directory and its subdirectories
  static void cleanDirectory(String directoryPath) {
    if (!kDebugMode) return;

    try {
      final directory = Directory(directoryPath);
      if (!directory.existsSync()) {
        return;
      }

      final files = directory.listSync(recursive: true);
      int cleanedFiles = 0;

      for (final fileEntity in files) {
        if (fileEntity is File && fileEntity.path.endsWith('.dart')) {
          final bool cleaned = cleanImports(fileEntity.path) ||
                        cleanDuplicateProviders(fileEntity.path);
          if (cleaned) {
            cleanedFiles++;
          }
        }
      }

      if (kDebugMode) {
        print('Cleaned $cleanedFiles files in $directoryPath');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cleaning directory $directoryPath: $e');
      }
    }
  }
}