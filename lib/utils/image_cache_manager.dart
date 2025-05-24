import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../utils/logger.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as path;
import 'app_logger.dart';

/// Manages caching of images from URLs
class ImageCacheManager extends BaseCacheManager {
  static const key = 'customImageCache';
  static const maxAgeCacheObject = Duration(days: 30);
  static const maxNrOfCacheObjects = 100;

  static ImageCacheManager? _instance;

  factory ImageCacheManager() {
    _instance ??= ImageCacheManager._();
    return _instance!;
  }

  ImageCacheManager._() : super(
    key,
    maxAgeCacheObject: maxAgeCacheObject,
    maxNrOfCacheObjects: maxNrOfCacheObjects,
    fileService: HttpFileService(),
  );
  
  /// Returns a cached file for the given URL, or null if not cached
  Future<File?> getCachedImageFile(String url) async {
    if (url.isEmpty) {
      return null;
    }
    
    url = _fixImageUrl(url);
    
    try {
      final cacheDir = await _getCacheDirectory();
      final fileName = _generateCacheFileName(url);
      final file = File('${cacheDir.path}/$fileName');
      
      if (await file.exists()) {
        return file;
      }
      
      return null;
    } catch (e) {
      AppLogger.error('Error getting cached file: $e');
      return null;
    }
  }
  
  /// Downloads and caches an image, returns the image data
  Future<Uint8List?> getImageData(String url) async {
    if (url.isEmpty) {
      return null;
    }
    
    final originalUrl = url;
    url = _fixImageUrl(url);
    AppLogger.info('تحميل صورة المنتج: $url');
    
    try {
      // Try to get from cache first
      final cachedFile = await getCachedImageFile(url);
      if (cachedFile != null) {
        try {
          return await cachedFile.readAsBytes();
        } catch (e) {
          // Cache file might be corrupt, delete it and try downloading again
          await cachedFile.delete();
          AppLogger.warning('Deleted corrupt cache file for: $url');
        }
      }
      
      // Not in cache, download and cache
      final client = http.Client();
      try {
        // Add User-Agent header to avoid some server restrictions
        final response = await client.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'SmartBizTracker/1.0 Flutter App',
            'Accept': 'image/*',
          },
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            AppLogger.warning('Timeout downloading image: $url');
            return http.Response('', 408); // 408 Request Timeout
          },
        );
        
        if (response.statusCode == 200) {
          final imageData = response.bodyBytes;
          
          if (imageData.isNotEmpty) {
            // Cache the image asynchronously
            _cacheImageData(url, imageData);
            
            return imageData;
          } else {
            AppLogger.warning('Empty response body for image: $url');
          }
        } else if (response.statusCode == 301 || response.statusCode == 302 || response.statusCode == 307 || response.statusCode == 308) {
          // Handle redirects
          final redirectUrl = response.headers['location'];
          if (redirectUrl != null && redirectUrl != url && redirectUrl != originalUrl) {
            AppLogger.info('Following redirect from $url to $redirectUrl');
            return getImageData(redirectUrl);
          } else {
            AppLogger.error('Invalid redirect URL or redirect loop detected: ${response.headers['location']}');
          }
        } else {
          AppLogger.error('خطأ في تحميل الصورة: $url - HttpException: Invalid statusCode: ${response.statusCode}, uri = $url');
        }
      } catch (e) {
        AppLogger.error('خطأ في تحميل الصورة: $url - $e');
        
        // Try alternative URL format if this might be the issue
        if (e.toString().contains('Invalid') || e.toString().contains('URL') || e.toString().contains('URI')) {
          final altUrl = _generateAlternativeUrl(url);
          if (altUrl != null && altUrl != url) {
            AppLogger.info('Trying alternative URL format: $altUrl');
            return getImageData(altUrl);
          }
        }
      } finally {
        client.close();
      }
      
      return null;
    } catch (e) {
      AppLogger.error('Error downloading image: $e');
      return null;
    }
  }
  
  /// Generates alternative URL formats to try if the main URL fails
  String? _generateAlternativeUrl(String url) {
    // Don't attempt to retry an already retried URL
    if (url.contains('_retry')) {
      return null;
    }
    
    try {
      final uri = Uri.parse(url);
      // Try adding https if protocol is missing
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        return 'https://$url';
      }
      
      // Try converting http to https
      if (url.startsWith('http://')) {
        return url.replaceFirst('http://', 'https://');
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Caches image data for a URL
  Future<void> _cacheImageData(String url, Uint8List imageData) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final fileName = _generateCacheFileName(url);
      final file = File('${cacheDir.path}/$fileName');
      
      await file.writeAsBytes(imageData);
    } catch (e) {
      AppLogger.error('Error caching image data: $e');
    }
  }
  
  /// Gets the cache directory
  Future<Directory> _getCacheDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/image_cache');
    
    if (!(await cacheDir.exists())) {
      await cacheDir.create(recursive: true);
    }
    
    return cacheDir;
  }
  
  /// Generates a file name for the cache based on the URL
  String _generateCacheFileName(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Fix common URL issues such as extra digits in date part
  String _fixImageUrl(String url) {
    // Fix issue with incorrect URL format with extra 0 after year
    if (url.contains('202500')) {
      url = url.replaceAll('202500', '2025');
    }
    
    // Fix other common year format issues
    if (url.contains('202300')) {
      url = url.replaceAll('202300', '2023');
    }
    
    if (url.contains('202400')) {
      url = url.replaceAll('202400', '2024');
    }
    
    // Ensure URL uses https instead of http when available
    if (url.startsWith('http://') && !url.contains('localhost') && !url.contains('127.0.0.1')) {
      url = url.replaceFirst('http://', 'https://');
    }
    
    // Ensure URL is properly encoded
    try {
      final uri = Uri.parse(url);
      final encodedPath = Uri.encodeFull(uri.path);
      if (encodedPath != uri.path) {
        final newUri = Uri(
          scheme: uri.scheme,
          userInfo: uri.userInfo,
          host: uri.host,
          port: uri.port,
          path: encodedPath,
          query: uri.query,
          fragment: uri.fragment,
        );
        return newUri.toString();
      }
    } catch (e) {
      AppLogger.warning('Error parsing URL for encoding: $e');
    }
    
    return url;
  }
  
  /// Clears the entire image cache
  Future<void> clearCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }
    } catch (e) {
      AppLogger.error('Error clearing cache: $e');
    }
  }
  
  /// Limits cache size to prevent excessive storage usage
  Future<void> trimCache(int maxSizeInMB) async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        final files = await cacheDir.list().toList();
        
        // Sort files by last access time
        files.sort((a, b) {
          final aLastAccess = (a as File).lastAccessedSync();
          final bLastAccess = (b as File).lastAccessedSync();
          return aLastAccess.compareTo(bLastAccess);
        });
        
        // Calculate current size
        int totalSize = 0;
        for (var file in files) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
        
        // Convert maxSize to bytes
        final maxSizeInBytes = maxSizeInMB * 1024 * 1024;
        
        // Remove oldest files until within size limit
        int i = 0;
        while (totalSize > maxSizeInBytes && i < files.length) {
          if (files[i] is File) {
            final file = files[i] as File;
            final fileSize = await file.length();
            await file.delete();
            totalSize -= fileSize;
          }
          i++;
        }
      }
    } catch (e) {
      AppLogger.error('Error trimming cache: $e');
    }
  }
} 