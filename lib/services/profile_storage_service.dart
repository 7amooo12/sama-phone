import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import '../models/user_model.dart';
import '../utils/logger.dart';
import 'supabase_storage_service.dart';
import 'supabase_service.dart';

/// خدمة متخصصة لإدارة الصور الشخصية
class ProfileStorageService {
  final _storageService = SupabaseStorageService();
  final _supabaseService = SupabaseService();

  /// تحديث الصورة الشخصية للمستخدم
  Future<String?> updateProfileImage(String userId, File imageFile) async {
    try {
      AppLogger.info('تحديث الصورة الشخصية للمستخدم: $userId');

      // الحصول على المستخدم الحالي
      final currentUser = await _supabaseService.getRecord('user_profiles', userId);
      if (currentUser == null) {
        AppLogger.error('المستخدم غير موجود: $userId');
        return null;
      }

      // حذف الصورة القديمة إذا كانت موجودة
      final oldImageUrl = currentUser['profile_image'] as String?;
      if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
        await _storageService.deleteFileFromUrl(oldImageUrl);
        AppLogger.info('تم حذف الصورة القديمة');
      }

      // معالجة وضغط الصورة الجديدة
      final processedImage = await _processProfileImage(imageFile);
      
      // رفع الصورة الجديدة
      final newImageUrl = await _storageService.uploadProfileImage(
        userId, 
        processedImage ?? imageFile
      );

      if (newImageUrl == null) {
        AppLogger.error('فشل في رفع الصورة الجديدة');
        return null;
      }

      // تحديث بيانات المستخدم
      await _supabaseService.updateRecord('user_profiles', userId, {
        'profile_image': newImageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      AppLogger.info('تم تحديث الصورة الشخصية بنجاح: $newImageUrl');
      return newImageUrl;
    } catch (e) {
      AppLogger.error('خطأ في تحديث الصورة الشخصية: $e');
      return null;
    }
  }

  /// تحديث الصورة الشخصية من البايتات
  Future<String?> updateProfileImageFromBytes(String userId, Uint8List imageBytes) async {
    try {
      AppLogger.info('تحديث الصورة الشخصية من البايتات للمستخدم: $userId');

      // الحصول على المستخدم الحالي
      final currentUser = await _supabaseService.getRecord('user_profiles', userId);
      if (currentUser == null) {
        AppLogger.error('المستخدم غير موجود: $userId');
        return null;
      }

      // حذف الصورة القديمة إذا كانت موجودة
      final oldImageUrl = currentUser['profile_image'] as String?;
      if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
        await _storageService.deleteFileFromUrl(oldImageUrl);
      }

      // معالجة الصورة
      final processedBytes = await _processProfileImageBytes(imageBytes);

      // إنشاء مسار الملف
      final fileName = 'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'users/$userId/$fileName';

      // رفع الصورة
      final newImageUrl = await _storageService.uploadFromBytes(
        SupabaseStorageService.profileImagesBucket,
        filePath,
        processedBytes ?? imageBytes,
        contentType: 'image/jpeg',
      );

      if (newImageUrl == null) {
        AppLogger.error('فشل في رفع الصورة الجديدة');
        return null;
      }

      // تحديث بيانات المستخدم
      await _supabaseService.updateRecord('user_profiles', userId, {
        'profile_image': newImageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      AppLogger.info('تم تحديث الصورة الشخصية بنجاح: $newImageUrl');
      return newImageUrl;
    } catch (e) {
      AppLogger.error('خطأ في تحديث الصورة الشخصية من البايتات: $e');
      return null;
    }
  }

  /// حذف الصورة الشخصية
  Future<bool> removeProfileImage(String userId) async {
    try {
      AppLogger.info('حذف الصورة الشخصية للمستخدم: $userId');

      // الحصول على المستخدم الحالي
      final currentUser = await _supabaseService.getRecord('user_profiles', userId);
      if (currentUser == null) {
        AppLogger.error('المستخدم غير موجود: $userId');
        return false;
      }

      // حذف الصورة من التخزين
      final imageUrl = currentUser['profile_image'] as String?;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        await _storageService.deleteFileFromUrl(imageUrl);
      }

      // تحديث بيانات المستخدم
      await _supabaseService.updateRecord('user_profiles', userId, {
        'profile_image': null,
        'updated_at': DateTime.now().toIso8601String(),
      });

      AppLogger.info('تم حذف الصورة الشخصية بنجاح');
      return true;
    } catch (e) {
      AppLogger.error('خطأ في حذف الصورة الشخصية: $e');
      return false;
    }
  }

  /// معالجة وضغط الصورة الشخصية
  Future<File?> _processProfileImage(File imageFile) async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final bytes = await imageFile.readAsBytes();
        final processedBytes = await _processProfileImageBytes(bytes);
        
        if (processedBytes != null) {
          // إنشاء ملف مؤقت
          final tempDir = Directory.systemTemp;
          final tempFile = File('${tempDir.path}/processed_profile_${path.basename(imageFile.path)}');
          await tempFile.writeAsBytes(processedBytes);
          return tempFile;
        }
      }
      return null;
    } catch (e) {
      AppLogger.error('خطأ في معالجة الصورة الشخصية: $e');
      return null;
    }
  }

  /// معالجة البايتات للصورة الشخصية
  Future<Uint8List?> _processProfileImageBytes(Uint8List bytes) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // تحويل الصورة إلى مربع (للصور الشخصية)
      final size = image.width < image.height ? image.width : image.height;
      final croppedImage = img.copyCrop(
        image,
        x: (image.width - size) ~/ 2,
        y: (image.height - size) ~/ 2,
        width: size,
        height: size,
      );

      // تصغير الصورة إلى حجم مناسب للصور الشخصية
      final resizedImage = img.copyResize(
        croppedImage,
        width: 400,
        height: 400,
        interpolation: img.Interpolation.cubic,
      );

      // ضغط الصورة
      final compressedBytes = img.encodeJpg(resizedImage, quality: 90);
      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      AppLogger.error('خطأ في معالجة بايتات الصورة الشخصية: $e');
      return null;
    }
  }

  /// الحصول على رابط الصورة الشخصية
  Future<String?> getProfileImageUrl(String userId) async {
    try {
      final user = await _supabaseService.getRecord('user_profiles', userId);
      return user?['profile_image'] as String?;
    } catch (e) {
      AppLogger.error('خطأ في الحصول على رابط الصورة الشخصية: $e');
      return null;
    }
  }

  /// التحقق من وجود صورة شخصية
  Future<bool> hasProfileImage(String userId) async {
    try {
      final imageUrl = await getProfileImageUrl(userId);
      return imageUrl != null && imageUrl.isNotEmpty;
    } catch (e) {
      AppLogger.error('خطأ في التحقق من وجود الصورة الشخصية: $e');
      return false;
    }
  }

  /// إنشاء صورة شخصية افتراضية بالأحرف الأولى
  Future<Uint8List> generateDefaultProfileImage(String name) async {
    try {
      // الحصول على الأحرف الأولى من الاسم
      final initials = _getInitials(name);
      
      // إنشاء صورة بسيطة بالأحرف الأولى
      final image = img.Image(width: 400, height: 400);
      img.fill(image, color: img.ColorRgb8(66, 165, 245)); // لون أزرق

      // في التطبيق الحقيقي، يمكنك استخدام مكتبة لرسم النص
      // هنا سنعيد صورة بسيطة
      final bytes = img.encodePng(image);
      return Uint8List.fromList(bytes);
    } catch (e) {
      AppLogger.error('خطأ في إنشاء الصورة الافتراضية: $e');
      // إرجاع صورة فارغة في حالة الخطأ
      final image = img.Image(width: 400, height: 400);
      img.fill(image, color: img.ColorRgb8(200, 200, 200));
      final bytes = img.encodePng(image);
      return Uint8List.fromList(bytes);
    }
  }

  /// الحصول على الأحرف الأولى من الاسم
  String _getInitials(String name) {
    final words = name.trim().split(' ');
    if (words.isEmpty) return 'U';
    
    if (words.length == 1) {
      return words[0].isNotEmpty ? words[0][0].toUpperCase() : 'U';
    }
    
    return (words[0].isNotEmpty ? words[0][0] : '') +
           (words[1].isNotEmpty ? words[1][0] : '');
  }

  /// تحديث معلومات المستخدم مع الصورة
  Future<UserModel?> updateUserProfile({
    required String userId,
    String? name,
    String? phone,
    File? profileImage,
  }) async {
    try {
      AppLogger.info('تحديث ملف المستخدم: $userId');

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) updateData['name'] = name;
      if (phone != null) updateData['phone_number'] = phone; // Fixed: Use phone_number to match database schema

      // تحديث الصورة إذا تم توفيرها
      if (profileImage != null) {
        final imageUrl = await updateProfileImage(userId, profileImage);
        if (imageUrl != null) {
          updateData['profile_image'] = imageUrl;
        }
      }

      // تحديث البيانات
      await _supabaseService.updateRecord('user_profiles', userId, updateData);

      // الحصول على البيانات المحدثة
      final updatedUser = await _supabaseService.getRecord('user_profiles', userId);
      if (updatedUser != null) {
        return UserModel.fromJson(updatedUser);
      }

      return null;
    } catch (e) {
      AppLogger.error('خطأ في تحديث ملف المستخدم: $e');
      return null;
    }
  }
}
