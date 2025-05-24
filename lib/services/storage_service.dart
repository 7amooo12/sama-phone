import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../utils/logger.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  // Upload a file to Firebase Storage
  Future<String> uploadFile(File file, String folder) async {
    try {
      final fileName = '${_uuid.v4()}${path.extension(file.path)}';
      final ref = _storage.ref().child('$folder/$fileName');
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      AppLogger.error('Error uploading file', e);
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
      AppLogger.error('Error uploading files', e);
      throw Exception('Failed to upload files');
    }
  }

  // Delete a file from Firebase Storage
  Future<void> deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      AppLogger.error('Error deleting file', e);
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
      AppLogger.error('Error deleting files', e);
      throw Exception('Failed to delete files');
    }
  }

  // Get file metadata
  Future<Map<String, dynamic>> getFileMetadata(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      final metadata = await ref.getMetadata();
      return {
        'name': metadata.name,
        'size': metadata.size,
        'contentType': metadata.contentType,
        'timeCreated': metadata.timeCreated,
        'updated': metadata.updated,
      };
    } catch (e) {
      AppLogger.error('Error getting file metadata', e);
      throw Exception('Failed to get file metadata');
    }
  }

  // Update file metadata
  Future<void> updateFileMetadata(
      String url, Map<String, String> metadata) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.updateMetadata(SettableMetadata(customMetadata: metadata));
    } catch (e) {
      AppLogger.error('Error updating file metadata', e);
      throw Exception('Failed to update file metadata');
    }
  }

  // Get file download URL
  Future<String> getDownloadURL(String path) async {
    try {
      final ref = _storage.ref().child(path);
      return await ref.getDownloadURL();
    } catch (e) {
      AppLogger.error('Error getting download URL', e);
      throw Exception('Failed to get download URL');
    }
  }

  // List files in a folder
  Future<List<String>> listFiles(String folder) async {
    try {
      final ListResult result = await _storage.ref().child(folder).listAll();
      final urls = <String>[];
      for (final ref in result.items) {
        final url = await ref.getDownloadURL();
        urls.add(url);
      }
      return urls;
    } catch (e) {
      AppLogger.error('Error listing files', e);
      throw Exception('Failed to list files');
    }
  }

  // Generate a unique file name
  String generateUniqueFileName(String originalFileName) {
    final extension = path.extension(originalFileName);
    return '${_uuid.v4()}$extension';
  }
}
