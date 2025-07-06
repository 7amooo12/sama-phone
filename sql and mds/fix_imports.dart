import 'dart:io';
import 'dart:async';

// Helper class for script logging
class ScriptLogger {
  static void info(String message) {
    // Use stderr for logging in production code
    stderr.writeln('INFO: $message');
  }

  static void warning(String message) {
    stderr.writeln('WARNING: $message');
  }

  static void error(String message, [Object? error]) {
    stderr.writeln('ERROR: $message${error != null ? ': $error' : ''}');
  }
}

void main() async {
  ScriptLogger.info(
      'Starting import path replacement in smartbiztracker_new/lib directory...');
  int filesProcessed = 0;
  int filesChanged = 0;

  const String libPath = 'smartbiztracker_new/lib';
  final Directory libDir = Directory(libPath);

  if (!libDir.existsSync()) {
    ScriptLogger.error('Directory not found: $libPath');
    return;
  }

  ScriptLogger.info('Scanning for Dart files in $libPath...');
  final List<FileSystemEntity> allFiles = await libDir
      .list(recursive: true)
      .where((entity) => entity is File && entity.path.endsWith('.dart'))
      .toList();

  ScriptLogger.info('Found ${allFiles.length} Dart files in lib directory.');

  // Process all found files
  for (final entity in allFiles) {
    filesProcessed++;

    try {
      final bool fileChanged = await processFile(entity.path);
      if (fileChanged) {
        filesChanged++;
        ScriptLogger.info('Updated imports in: ${entity.path}');
      }
    } catch (e) {
      ScriptLogger.error('Error processing file ${entity.path}', e);
    }

    // Print progress every 10 files
    if (filesProcessed % 10 == 0) {
      ScriptLogger.info(
          'Processed $filesProcessed files out of ${allFiles.length}, changed $filesChanged files.');
    }
  }

  ScriptLogger.info(
      'Complete! Processed $filesProcessed files, changed $filesChanged files.');
}

Future<bool> processFile(String filePath) async {
  final File file = File(filePath);

  try {
    final String content = await file.readAsString();

    if (!content.contains('package:flutter_multi_role_app/')) {
      return false;
    }

    final String newContent = content.replaceAll(
        'package:flutter_multi_role_app/', 'package:smartbiztracker_new/');

    if (content == newContent) {
      return false;
    }

    await file.writeAsString(newContent);
    return true;
  } catch (e) {
    ScriptLogger.error('Error processing $filePath', e);
    return false;
  }
}
