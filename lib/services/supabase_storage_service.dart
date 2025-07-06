import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../utils/logger.dart';

/// خدمة شاملة للتعامل مع Supabase Storage
class SupabaseStorageService {
  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  // أسماء البكتات (Buckets)
  static const String profileImagesBucket = 'profile-images';
  static const String productImagesBucket = 'product-images';
  static const String invoicesBucket = 'invoices';
  static const String attachmentsBucket = 'attachments';
  static const String documentsBucket = 'documents';

  // Worker system buckets
  static const String taskAttachmentsBucket = 'task-attachments';
  static const String taskEvidenceBucket = 'task-evidence';
  static const String workerDocumentsBucket = 'worker-documents';
  static const String rewardCertificatesBucket = 'reward-certificates';

  // Electronic payment buckets
  static const String paymentProofsBucket = 'payment-proofs';

  /// تهيئة البكتات المطلوبة
  Future<void> initializeBuckets() async {
    try {
      final buckets = [
        profileImagesBucket,
        productImagesBucket,
        invoicesBucket,
        attachmentsBucket,
        documentsBucket,
        taskAttachmentsBucket,
        taskEvidenceBucket,
        workerDocumentsBucket,
        rewardCertificatesBucket,
        paymentProofsBucket,
      ];

      for (final bucketName in buckets) {
        await _ensureBucketExists(bucketName);
      }
    } catch (e) {
      AppLogger.error('خطأ في تهيئة البكتات: $e');
    }
  }

  /// التأكد من وجود البكت وإنشاؤه إذا لم يكن موجوداً
  Future<void> _ensureBucketExists(String bucketName) async {
    try {
      // محاولة الحصول على معلومات البكت للتحقق من وجوده
      await _supabase.storage.getBucket(bucketName);
      AppLogger.info('البكت موجود: $bucketName');
    } catch (e) {
      // إذا لم يكن البكت موجوداً، قم بإنشائه
      try {
        await _supabase.storage.createBucket(
          bucketName,
          BucketOptions(
            public: true,
            allowedMimeTypes: _getAllowedMimeTypes(),
            fileSizeLimit: '50MB'
          ),
        );
        AppLogger.info('تم إنشاء البكت: $bucketName');
      } catch (createError) {
        final errorMessage = createError.toString().toLowerCase();
        if (errorMessage.contains('already exists')) {
          AppLogger.info('البكت موجود بالفعل: $bucketName');
        } else if (errorMessage.contains('row-level security') ||
                   errorMessage.contains('rls') ||
                   errorMessage.contains('403')) {
          AppLogger.warning('تحذير: لا يمكن إنشاء البكت $bucketName بسبب إعدادات الأمان. سيتم المتابعة بدون إنشاء البكت.');
          AppLogger.warning('يرجى إنشاء البكت يدوياً في لوحة تحكم Supabase أو تعديل إعدادات RLS.');
          // Don't rethrow - allow the app to continue
        } else {
          AppLogger.error('خطأ في إنشاء البكت $bucketName: $createError');
          // Don't rethrow for bucket creation failures - allow graceful degradation
        }
      }
    }
  }

  /// رفع صورة شخصية
  Future<String?> uploadProfileImage(String userId, File imageFile) async {
    try {
      // التأكد من وجود البكت أولاً
      await _ensureBucketExists(profileImagesBucket);

      final fileName = 'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'users/$userId/$fileName';

      final bytes = await imageFile.readAsBytes();

      await _supabase.storage
          .from(profileImagesBucket)
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              cacheControl: '3600',
            ),
          );

      final url = _supabase.storage
          .from(profileImagesBucket)
          .getPublicUrl(filePath);

      AppLogger.info('تم رفع الصورة الشخصية: $url');
      return url;
    } catch (e) {
      AppLogger.error('خطأ في رفع الصورة الشخصية: $e');
      return null;
    }
  }

  /// رفع صورة منتج
  Future<String?> uploadProductImage(String productId, File imageFile) async {
    try {
      final extension = path.extension(imageFile.path);
      final fileName = 'product_${productId}_${_uuid.v4()}$extension';
      final filePath = 'products/$productId/$fileName';

      final bytes = await imageFile.readAsBytes();

      await _supabase.storage
          .from(productImagesBucket)
          .uploadBinary(filePath, bytes);

      final url = _supabase.storage
          .from(productImagesBucket)
          .getPublicUrl(filePath);

      AppLogger.info('تم رفع صورة المنتج: $url');
      return url;
    } catch (e) {
      AppLogger.error('خطأ في رفع صورة المنتج: $e');
      return null;
    }
  }

  /// رفع عدة صور للمنتج
  Future<List<String>> uploadProductImages(String productId, List<File> imageFiles) async {
    final urls = <String>[];

    for (final imageFile in imageFiles) {
      final url = await uploadProductImage(productId, imageFile);
      if (url != null) {
        urls.add(url);
      }
    }

    return urls;
  }

  /// رفع فاتورة
  Future<String?> uploadInvoice(String invoiceId, File invoiceFile) async {
    try {
      final extension = path.extension(invoiceFile.path);
      final fileName = 'invoice_${invoiceId}_${DateTime.now().millisecondsSinceEpoch}$extension';
      final filePath = 'invoices/${DateTime.now().year}/${DateTime.now().month}/$fileName';

      final bytes = await invoiceFile.readAsBytes();

      await _supabase.storage
          .from(invoicesBucket)
          .uploadBinary(filePath, bytes);

      final url = _supabase.storage
          .from(invoicesBucket)
          .getPublicUrl(filePath);

      AppLogger.info('تم رفع الفاتورة: $url');
      return url;
    } catch (e) {
      AppLogger.error('خطأ في رفع الفاتورة: $e');
      return null;
    }
  }

  /// رفع مرفق عام
  Future<String?> uploadAttachment(String category, File file) async {
    try {
      final extension = path.extension(file.path);
      final fileName = '${category}_${_uuid.v4()}$extension';
      final filePath = '$category/${DateTime.now().year}/${DateTime.now().month}/$fileName';

      final bytes = await file.readAsBytes();

      await _supabase.storage
          .from(attachmentsBucket)
          .uploadBinary(filePath, bytes);

      final url = _supabase.storage
          .from(attachmentsBucket)
          .getPublicUrl(filePath);

      AppLogger.info('تم رفع المرفق: $url');
      return url;
    } catch (e) {
      AppLogger.error('خطأ في رفع المرفق: $e');
      return null;
    }
  }

  /// رفع من البايتات مباشرة
  Future<String?> uploadFromBytes(
    String bucketName,
    String filePath,
    Uint8List bytes, {
    String? contentType,
  }) async {
    try {
      // التأكد من وجود البكت أولاً
      await _ensureBucketExists(bucketName);

      AppLogger.info('بدء رفع الملف: $filePath إلى البكت: $bucketName');

      await _supabase.storage
          .from(bucketName)
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType ?? 'application/octet-stream',
              cacheControl: '3600',
            ),
          );

      final url = _supabase.storage
          .from(bucketName)
          .getPublicUrl(filePath);

      AppLogger.info('تم رفع الملف من البايتات بنجاح: $url');
      return url;
    } catch (e) {
      AppLogger.error('خطأ في رفع الملف من البايتات: $e');
      AppLogger.error('تفاصيل الخطأ - البكت: $bucketName, المسار: $filePath, حجم البايتات: ${bytes.length}');
      return null;
    }
  }

  /// حذف ملف
  Future<bool> deleteFile(String bucketName, String filePath) async {
    try {
      await _supabase.storage
          .from(bucketName)
          .remove([filePath]);

      AppLogger.info('تم حذف الملف: $filePath');
      return true;
    } catch (e) {
      AppLogger.error('خطأ في حذف الملف: $e');
      return false;
    }
  }

  /// حذف ملف من URL
  Future<bool> deleteFileFromUrl(String url) async {
    try {
      // استخراج اسم البكت ومسار الملف من URL
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      if (pathSegments.length < 4) {
        AppLogger.error('URL غير صحيح: $url');
        return false;
      }

      final bucketName = pathSegments[2];
      final filePath = pathSegments.skip(3).join('/');

      return await deleteFile(bucketName, filePath);
    } catch (e) {
      AppLogger.error('خطأ في حذف الملف من URL: $e');
      return false;
    }
  }

  /// الحصول على قائمة الملفات في مجلد
  Future<List<FileObject>> listFiles(String bucketName, String folderPath) async {
    try {
      final files = await _supabase.storage
          .from(bucketName)
          .list(path: folderPath);

      return files;
    } catch (e) {
      AppLogger.error('خطأ في الحصول على قائمة الملفات: $e');
      return [];
    }
  }

  /// الحصول على أنواع MIME المسموحة
  List<String> _getAllowedMimeTypes() {
    return [
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/webp',
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'text/plain',
      'text/csv',
    ];
  }

  /// التحقق من نوع الملف
  bool isValidFileType(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    final allowedExtensions = [
      '.jpg', '.jpeg', '.png', '.gif', '.webp',
      '.pdf', '.doc', '.docx', '.xls', '.xlsx',
      '.txt', '.csv'
    ];

    return allowedExtensions.contains(extension);
  }

  /// الحصول على حجم الملف المسموح (بالبايت)
  int getMaxFileSize() {
    return 50 * 1024 * 1024; // 50MB
  }

  // =====================================================
  // WORKER SYSTEM STORAGE METHODS
  // =====================================================

  /// رفع مرفق مهمة
  Future<String?> uploadTaskAttachment({
    required String userId,
    required String taskId,
    required File file,
  }) async {
    try {
      final extension = path.extension(file.path);
      final fileName = 'attachment_${_uuid.v4()}$extension';
      final filePath = '$userId/tasks/$taskId/$fileName';

      final bytes = await file.readAsBytes();

      await _supabase.storage
          .from(taskAttachmentsBucket)
          .uploadBinary(filePath, bytes);

      final url = _supabase.storage
          .from(taskAttachmentsBucket)
          .getPublicUrl(filePath);

      AppLogger.info('تم رفع مرفق المهمة: $url');
      return url;
    } catch (e) {
      AppLogger.error('خطأ في رفع مرفق المهمة: $e');
      return null;
    }
  }

  /// رفع دليل إنجاز المهمة (صور/فيديو)
  Future<String?> uploadTaskEvidence({
    required String userId,
    required String taskId,
    required String submissionId,
    required File file,
  }) async {
    try {
      final extension = path.extension(file.path);
      final fileName = 'evidence_${_uuid.v4()}$extension';
      final filePath = '$userId/evidence/$taskId/$submissionId/$fileName';

      final bytes = await file.readAsBytes();

      await _supabase.storage
          .from(taskEvidenceBucket)
          .uploadBinary(filePath, bytes);

      final url = _supabase.storage
          .from(taskEvidenceBucket)
          .getPublicUrl(filePath);

      AppLogger.info('تم رفع دليل إنجاز المهمة: $url');
      return url;
    } catch (e) {
      AppLogger.error('خطأ في رفع دليل إنجاز المهمة: $e');
      return null;
    }
  }

  /// رفع عدة ملفات للمهمة
  Future<List<String>> uploadMultipleTaskFiles({
    required String userId,
    required String taskId,
    required String submissionId,
    required List<File> files,
    required String type, // 'attachment' or 'evidence'
  }) async {
    final uploadedUrls = <String>[];

    for (final file in files) {
      String? url;

      if (type == 'attachment') {
        url = await uploadTaskAttachment(
          userId: userId,
          taskId: taskId,
          file: file,
        );
      } else if (type == 'evidence') {
        url = await uploadTaskEvidence(
          userId: userId,
          taskId: taskId,
          submissionId: submissionId,
          file: file,
        );
      }

      if (url != null) {
        uploadedUrls.add(url);
      }
    }

    AppLogger.info('تم رفع ${uploadedUrls.length} من أصل ${files.length} ملف');
    return uploadedUrls;
  }

  /// رفع إثبات دفع إلكتروني
  Future<String?> uploadPaymentProof({
    required String clientId,
    required String paymentId,
    required File file,
  }) async {
    try {
      final extension = path.extension(file.path);
      final fileName = 'payment_proof_${_uuid.v4()}$extension';
      final filePath = '$clientId/payments/$paymentId/$fileName';

      final bytes = await file.readAsBytes();

      await _supabase.storage
          .from(paymentProofsBucket)
          .uploadBinary(filePath, bytes);

      final url = _supabase.storage
          .from(paymentProofsBucket)
          .getPublicUrl(filePath);

      AppLogger.info('تم رفع إثبات الدفع: $url');
      return url;
    } catch (e) {
      AppLogger.error('خطأ في رفع إثبات الدفع: $e');
      return null;
    }
  }

  /// الحصول على رابط صورة المنتج من قاعدة البيانات أو API خارجي
  Future<String?> getProductImageUrl(String productId) async {
    try {
      AppLogger.info('🔍 البحث عن صورة المنتج: $productId');

      // Try using database function first (handles UUID/TEXT conversion)
      try {
        final response = await _supabase
            .rpc('get_product_image_url', params: {'product_id': productId});

        if (response != null && response.toString().isNotEmpty && response.toString() != 'null') {
          AppLogger.info('✅ تم العثور على صورة المنتج من الدالة: $response');
          return response.toString();
        }
      } catch (functionError) {
        AppLogger.warning('⚠️ Database function failed, trying direct query: $functionError');
      }

      // Fallback: Direct query with enhanced error handling
      try {
        final response = await _supabase
            .from('products')
            .select('main_image_url, image_urls, image_url')
            .eq('id', productId)
            .maybeSingle();

        if (response == null) {
          AppLogger.warning('⚠️ المنتج غير موجود: $productId');
          return null;
        }

        // محاولة الحصول على الصورة الرئيسية أولاً
        String? imageUrl = response['main_image_url'] as String?;

        // إذا لم توجد صورة رئيسية، جرب الحصول على أول صورة من القائمة
        if (imageUrl == null || imageUrl.isEmpty || imageUrl == 'null') {
          final imageUrls = response['image_urls'] as List<dynamic>?;
          if (imageUrls != null && imageUrls.isNotEmpty) {
            imageUrl = imageUrls.first as String?;
          }
        }

        // إذا لم توجد صورة، جرب العمود القديم image_url
        if (imageUrl == null || imageUrl.isEmpty || imageUrl == 'null') {
          imageUrl = response['image_url'] as String?;
        }

        if (imageUrl != null && imageUrl.isNotEmpty && imageUrl != 'null') {
          AppLogger.info('✅ تم العثور على صورة المنتج: $imageUrl');
          return imageUrl;
        }

      } catch (schemaError) {
        AppLogger.warning('⚠️ Schema error, trying legacy approach: $schemaError');

        // Final fallback: try legacy image_url column only
        try {
          final fallbackResponse = await _supabase
              .from('products')
              .select('image_url')
              .eq('id', productId)
              .maybeSingle();

          if (fallbackResponse != null) {
            final imageUrl = fallbackResponse['image_url'] as String?;
            if (imageUrl != null && imageUrl.isNotEmpty && imageUrl != 'null') {
              AppLogger.info('✅ تم العثور على صورة المنتج (legacy): $imageUrl');
              return imageUrl;
            }
          }
        } catch (fallbackError) {
          AppLogger.error('❌ All fallback attempts failed: $fallbackError');
        }
      }

      AppLogger.warning('⚠️ لا توجد صورة للمنتج: $productId');
      return null;
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على صورة المنتج $productId: $e');
      return null;
    }
  }

  /// الحصول على جميع صور المنتج
  Future<List<String>> getProductImageUrls(String productId) async {
    try {
      AppLogger.info('🔍 البحث عن جميع صور المنتج: $productId');

      final response = await _supabase
          .from('products')
          .select('main_image_url, image_urls')
          .eq('id', productId)
          .maybeSingle();

      if (response == null) {
        AppLogger.warning('⚠️ المنتج غير موجود: $productId');
        return [];
      }

      final List<String> allImages = [];

      // إضافة الصورة الرئيسية
      final mainImageUrl = response['main_image_url'] as String?;
      if (mainImageUrl != null && mainImageUrl.isNotEmpty && mainImageUrl != 'null') {
        allImages.add(mainImageUrl);
      }

      // إضافة باقي الصور
      final imageUrls = response['image_urls'] as List<dynamic>?;
      if (imageUrls != null) {
        for (final url in imageUrls) {
          final imageUrl = url as String?;
          if (imageUrl != null && imageUrl.isNotEmpty && imageUrl != 'null' && !allImages.contains(imageUrl)) {
            allImages.add(imageUrl);
          }
        }
      }

      AppLogger.info('✅ تم العثور على ${allImages.length} صورة للمنتج: $productId');
      return allImages;
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على صور المنتج $productId: $e');
      return [];
    }
  }
}
