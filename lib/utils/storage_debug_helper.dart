import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_logger.dart';

class StorageDebugHelper {
  static final _supabase = Supabase.instance.client;

  /// فحص حالة البكتات
  static Future<void> checkBuckets() async {
    try {
      AppLogger.info('🔍 فحص البكتات...');

      final buckets = await _supabase.storage.listBuckets();
      AppLogger.info('📦 البكتات الموجودة: ${buckets.length}');

      for (final bucket in buckets) {
        AppLogger.info('  - ${bucket.name} (public: ${bucket.public})');
      }

      // فحص البكت المطلوب
      final profileBucket = buckets.where((b) => b.name == 'profile_images').firstOrNull;
      if (profileBucket == null) {
        AppLogger.warning('⚠️ بكت profile_images غير موجود!');
        await _createProfileImagesBucket();
      } else {
        AppLogger.info('✅ بكت profile_images موجود');
        if (!profileBucket.public) {
          AppLogger.warning('⚠️ بكت profile_images ليس عام!');
        }
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في فحص البكتات: $e');
    }
  }

  /// إنشاء بكت الصور الشخصية
  static Future<void> _createProfileImagesBucket() async {
    try {
      AppLogger.info('🔨 إنشاء بكت profile_images...');

      await _supabase.storage.createBucket(
        'profile_images',
        const BucketOptions(
          public: true,
          allowedMimeTypes: [
            'image/jpeg',
            'image/jpg',
            'image/png',
            'image/webp',
          ],
          fileSizeLimit: '10MB'
        ),
      );

      AppLogger.info('✅ تم إنشاء بكت profile_images بنجاح');
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء بكت profile_images: $e');
    }
  }

  /// اختبار رفع ملف تجريبي
  static Future<void> testUpload() async {
    try {
      AppLogger.info('🧪 اختبار رفع ملف تجريبي...');

      // إنشاء بيانات تجريبية (صورة 1x1 pixel)
      final testData = [
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
        0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
        0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
        0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
        0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
        0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
        0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x11, 0x08, 0x00, 0x01,
        0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01,
        0xFF, 0xC4, 0x00, 0x14, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0xFF, 0xC4,
        0x00, 0x14, 0x10, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xDA, 0x00, 0x0C,
        0x03, 0x01, 0x00, 0x02, 0x11, 0x03, 0x11, 0x00, 0x3F, 0x00, 0x9F, 0xFF, 0xD9
      ];

      final fileName = 'test_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'test/$fileName';

      await _supabase.storage
          .from('profile_images')
          .uploadBinary(
            filePath,
            Uint8List.fromList(testData),
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              cacheControl: '3600',
            ),
          );

      final url = _supabase.storage
          .from('profile_images')
          .getPublicUrl(filePath);

      AppLogger.info('✅ تم رفع الملف التجريبي بنجاح: $url');

      // حذف الملف التجريبي
      await _supabase.storage
          .from('profile_images')
          .remove([filePath]);

      AppLogger.info('🗑️ تم حذف الملف التجريبي');

    } catch (e) {
      AppLogger.error('❌ خطأ في اختبار الرفع: $e');
    }
  }

  /// فحص صلاحيات المستخدم
  static Future<void> checkUserPermissions() async {
    try {
      AppLogger.info('🔐 فحص صلاحيات المستخدم...');

      final user = _supabase.auth.currentUser;
      if (user == null) {
        AppLogger.warning('⚠️ المستخدم غير مسجل دخول');
        return;
      }

      AppLogger.info('👤 المستخدم: ${user.id}');
      AppLogger.info('📧 البريد: ${user.email}');
      AppLogger.info('🔑 الدور: ${user.userMetadata?['role'] ?? 'غير محدد'}');

    } catch (e) {
      AppLogger.error('❌ خطأ في فحص صلاحيات المستخدم: $e');
    }
  }

  /// تشغيل جميع الفحوصات
  static Future<void> runAllChecks() async {
    AppLogger.info('🚀 بدء فحص شامل للتخزين...');

    await checkUserPermissions();
    await checkBuckets();
    await testUpload();

    AppLogger.info('✅ انتهى الفحص الشامل للتخزين');
  }

  /// طباعة معلومات مفصلة عن خطأ
  static void logDetailedError(dynamic error, String context) {
    AppLogger.error('❌ خطأ في $context:');
    AppLogger.error('   النوع: ${error.runtimeType}');
    AppLogger.error('   الرسالة: $error');

    if (error is StorageException) {
      AppLogger.error('   كود الخطأ: ${error.statusCode}');
      AppLogger.error('   الرسالة التفصيلية: ${error.message}');
    }

    if (error is PostgrestException) {
      AppLogger.error('   كود الخطأ: ${error.code}');
      AppLogger.error('   التفاصيل: ${error.details}');
      AppLogger.error('   التلميح: ${error.hint}');
    }
  }
}
