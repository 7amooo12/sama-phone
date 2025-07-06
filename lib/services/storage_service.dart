import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../utils/app_logger.dart';

class StorageService {
  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  // Upload a file to Supabase Storage
  Future<String> uploadFile(File file, String folder) async {
    try {
      final fileName = '${_uuid.v4()}${path.extension(file.path)}';
      final filePath = '$folder/$fileName';
      final bytes = await file.readAsBytes();

      await _supabase.storage
          .from('attachments')
          .uploadBinary(filePath, bytes);

      return _supabase.storage
          .from('attachments')
          .getPublicUrl(filePath);
    } catch (e) {
      AppLogger.error('Error uploading file: $e');
      throw Exception('Failed to upload file');
    }
  }

  // Upload multiple files
  Future<List<String>> uploadFiles(List<File> files, String folder) async {
    try {
      final urls = <String>[];
      for (final file in files) {
        final url = await uploadFile(file, folder);
        urls.add(url);
      }
      return urls;
    } catch (e) {
      AppLogger.error('Error uploading files: $e');
      throw Exception('Failed to upload files');
    }
  }

  // Delete a file from Supabase Storage
  Future<void> deleteFile(String url) async {
    try {
      // Extract file path from URL
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.length >= 3) {
        final bucket = pathSegments[pathSegments.length - 3];
        final filePath = pathSegments.sublist(pathSegments.length - 2).join('/');
        await _supabase.storage.from(bucket).remove([filePath]);
      }
    } catch (e) {
      AppLogger.error('Error deleting file: $e');
      throw Exception('Failed to delete file');
    }
  }

  // Delete multiple files
  Future<void> deleteFiles(List<String> urls) async {
    try {
      for (final url in urls) {
        await deleteFile(url);
      }
    } catch (e) {
      AppLogger.error('Error deleting files: $e');
      throw Exception('Failed to delete files');
    }
  }

  // Get file metadata (simplified for Supabase)
  Future<Map<String, dynamic>> getFileMetadata(String url) async {
    try {
      // For Supabase, we can extract basic info from URL
      final uri = Uri.parse(url);
      final fileName = uri.pathSegments.last;
      return {
        'name': fileName,
        'url': url,
        'contentType': _getContentTypeFromExtension(fileName),
      };
    } catch (e) {
      AppLogger.error('Error getting file metadata: $e');
      throw Exception('Failed to get file metadata');
    }
  }

  // Helper method to get content type from file extension
  String _getContentTypeFromExtension(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  // Get file download URL
  Future<String> getDownloadURL(String filePath) async {
    try {
      return _supabase.storage
          .from('attachments')
          .getPublicUrl(filePath);
    } catch (e) {
      AppLogger.error('Error getting download URL: $e');
      throw Exception('Failed to get download URL');
    }
  }

  // List files in a folder
  Future<List<String>> listFiles(String folder) async {
    try {
      final response = await _supabase.storage
          .from('attachments')
          .list(path: folder);

      final urls = <String>[];
      for (final file in response) {
        final url = _supabase.storage
            .from('attachments')
            .getPublicUrl('$folder/${file.name}');
        urls.add(url);
      }
      return urls;
    } catch (e) {
      AppLogger.error('Error listing files: $e');
      throw Exception('Failed to list files');
    }
  }

  // Generate a unique file name
  String generateUniqueFileName(String originalFileName) {
    final extension = path.extension(originalFileName);
    return '${_uuid.v4()}$extension';
  }
}
