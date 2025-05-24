import 'dart:io';
import 'package:flutter/foundation.dart';

/// A utility class for cleaning up unused imports in Dart files
class ImportCleaner {
  /// Check and log files with unused imports. This should be used
  /// during development, not in production.
  static void checkUnusedImports(String filePath) {
    if (!kDebugMode) return;

    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        debugPrint('File not found: $filePath');
        return;
      }

      final content = file.readAsStringSync();
      final lines = content.split('\n');

      final importLines = <String>[];
      final importPackages = <String>[];

      // Find all import statements
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('import ') && line.endsWith(';')) {
          importLines.add(line);

          // Extract package name
          final quote = line.contains("'") ? "'" : '"';
          final startIndex = line.indexOf(quote) + 1;
          final endIndex = line.indexOf(quote, startIndex);
          if (startIndex > 0 && endIndex > startIndex) {
            final packageName = line.substring(startIndex, endIndex);
            importPackages.add(packageName);
          }
        }
      }

      // Check which imports are unused
      final unusedImports = <String>[];
      for (int i = 0; i < importPackages.length; i++) {
        final packageName = importPackages[i];
        final importLine = importLines[i];

        // Extract simple name from package (last part after '/')
        String simpleName = packageName;
        if (packageName.contains('/')) {
          simpleName = packageName.split('/').last;
        }

        // Check if this import is used anywhere in the file
        bool isUsed = false;
        for (final line in lines) {
          if (!line.startsWith('import ') &&
              !line.startsWith('export ') &&
              line.contains(simpleName)) {
            isUsed = true;
            break;
          }
        }

        if (!isUsed) {
          unusedImports.add(importLine);
        }
      }

      // Log unused imports
      if (unusedImports.isNotEmpty) {
        debugPrint('Unused imports in $filePath:');
        for (final unusedImport in unusedImports) {
          debugPrint('  $unusedImport');
        }
      } else {
        debugPrint('No unused imports found in $filePath');
      }
    } catch (e) {
      debugPrint('Error checking unused imports: $e');
    }
  }

  /// Clean up unused imports from a Dart file
  /// Returns true if any imports were removed, false otherwise
  static bool removeUnusedImports(String filePath) {
    if (!kDebugMode) return false;

    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        debugPrint('File not found: $filePath');
        return false;
      }

      final content = file.readAsStringSync();
      final lines = content.split('\n');

      final importLines = <String>[];
      final importPackages = <String>[];
      final lineIndices = <int>[];

      // Find all import statements
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('import ') && line.endsWith(';')) {
          importLines.add(line);
          lineIndices.add(i);

          // Extract package name
          final quote = line.contains("'") ? "'" : '"';
          final startIndex = line.indexOf(quote) + 1;
          final endIndex = line.indexOf(quote, startIndex);
          if (startIndex > 0 && endIndex > startIndex) {
            final packageName = line.substring(startIndex, endIndex);
            importPackages.add(packageName);
          }
        }
      }

      // Check which imports are unused
      final unusedImportIndices = <int>[];
      for (int i = 0; i < importPackages.length; i++) {
        final packageName = importPackages[i];

        // Extract simple name from package (last part after '/')
        String simpleName = packageName;
        if (packageName.contains('/')) {
          simpleName = packageName.split('/').last;
        }

        // Check if this import is used anywhere in the file
        bool isUsed = false;
        for (final line in lines) {
          if (!line.startsWith('import ') &&
              !line.startsWith('export ') &&
              line.contains(simpleName)) {
            isUsed = true;
            break;
          }
        }

        if (!isUsed) {
          unusedImportIndices.add(lineIndices[i]);
        }
      }

      // Remove unused imports
      if (unusedImportIndices.isNotEmpty) {
        final newLines = <String>[];
        for (int i = 0; i < lines.length; i++) {
          if (!unusedImportIndices.contains(i)) {
            newLines.add(lines[i]);
          }
        }

        file.writeAsStringSync(newLines.join('\n'));
        debugPrint(
            'Removed ${unusedImportIndices.length} unused imports from $filePath');
        return true;
      } else {
        debugPrint('No unused imports found in $filePath');
        return false;
      }
    } catch (e) {
      debugPrint('Error removing unused imports: $e');
      return false;
    }
  }
}
