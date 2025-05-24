import 'dart:io';
import 'package:flutter/foundation.dart';

/// A utility class for helping with naming conventions in Dart files
class NamingConvention {
  /// Check for constant variables using uppercase naming conventions
  /// and suggest camelCase alternatives
  static void checkConstantsNaming(String filePath) {
    if (!kDebugMode) return;

    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        debugPrint('File not found: $filePath');
        return;
      }

      final content = file.readAsStringSync();
      final lines = content.split('\n');

      final uppercaseConstants = <String>[];
      final camelCaseSuggestions = <String, String>{};

      // Regular expression to find static const String UPPERCASE_CONSTANT
      final regex = RegExp(r'static\s+const\s+\w+\s+([A-Z][A-Z0-9_]+)\s*=');

      // Find all uppercase constants
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        final match = regex.firstMatch(line);
        if (match != null) {
          final constantName = match.group(1)!;
          uppercaseConstants.add(constantName);

          // Create camelCase suggestion
          final camelCase = _toCamelCase(constantName);
          camelCaseSuggestions[constantName] = camelCase;
        }
      }

      // Log suggestions
      if (uppercaseConstants.isNotEmpty) {
        debugPrint(
            'Found ${uppercaseConstants.length} uppercase constants in $filePath:');
        for (final constant in uppercaseConstants) {
          debugPrint('  $constant -> ${camelCaseSuggestions[constant]}');
        }
      } else {
        debugPrint('No uppercase constants found in $filePath');
      }
    } catch (e) {
      debugPrint('Error checking constants naming: $e');
    }
  }

  /// Transform a constant from UPPERCASE_NAMING to camelCase
  static String _toCamelCase(String uppercaseConstant) {
    if (uppercaseConstant.isEmpty) return '';

    final parts = uppercaseConstant.split('_');
    final camelCaseParts = <String>[];

    for (int i = 0; i < parts.length; i++) {
      final part = parts[i].toLowerCase();
      if (part.isEmpty) continue;

      if (i == 0) {
        // First part starts with lowercase
        camelCaseParts.add(part);
      } else {
        // Capitalize first letter of other parts
        camelCaseParts.add(part[0].toUpperCase() + part.substring(1));
      }
    }

    return camelCaseParts.join('');
  }

  /// Transform UPPERCASE constant declarations to camelCase in a file
  /// Returns true if any constants were transformed, false otherwise
  static bool transformConstantsToCamelCase(String filePath) {
    if (!kDebugMode) return false;

    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        debugPrint('File not found: $filePath');
        return false;
      }

      final content = file.readAsStringSync();
      final lines = content.split('\n');

      // Regular expression to find static const String UPPERCASE_CONSTANT
      final regex = RegExp(r'static\s+const\s+\w+\s+([A-Z][A-Z0-9_]+)\s*=');
      bool madeChanges = false;

      // Transform constants
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final match = regex.firstMatch(line);
        if (match != null) {
          final constantName = match.group(1)!;
          final camelCase = _toCamelCase(constantName);

          // Replace the constant name with camelCase
          lines[i] = line.replaceFirst(constantName, camelCase);
          madeChanges = true;
        }
      }

      // Save changes
      if (madeChanges) {
        file.writeAsStringSync(lines.join('\n'));
        debugPrint('Transformed constants to camelCase in $filePath');
        return true;
      } else {
        debugPrint('No constants to transform in $filePath');
        return false;
      }
    } catch (e) {
      debugPrint('Error transforming constants: $e');
      return false;
    }
  }
}
