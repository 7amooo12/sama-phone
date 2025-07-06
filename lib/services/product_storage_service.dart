import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/product_model.dart';
import '../utils/app_logger.dart';
import 'supabase_storage_service.dart';
import 'supabase_service.dart';

/// خدمة متخصصة لإدارة صور وملفات المنتجات
class ProductStorageService {
  final _storageService = SupabaseStorageService();
  final _supabaseService = SupabaseService();
  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  /// إضافة منتج جديد مع الصور
  Future<ProductModel?> createProductWithImages({
    required String name,
    required String description,
    required double price,
    required int quantity,
    required String category,
    required String sku,
    List<File>? imageFiles,
    List<String>? tags,
  }) async {
    try {
      AppLogger.info('بدء إنشاء منتج جديد: $name');

      // إنشاء ID فريد للمنتج
      final productId = _uuid.v4();

      // رفع الصور أولاً
      final List<String> imageUrls = [];
      if (imageFiles != null && imageFiles.isNotEmpty) {
        AppLogger.info('رفع ${imageFiles.length} صورة للمنتج');
        
        for (int i = 0; i < imageFiles.length; i++) {
          final imageFile = imageFiles[i];
          
          // ضغط الصورة قبل الرفع
          final compressedImage = await _compressImage(imageFile);
          
          // رفع الصورة
          final imageUrl = await _storageService.uploadProductImage(
            productId, 
            compressedImage ?? imageFile
          );
          
          if (imageUrl != null) {
            imageUrls.add(imageUrl);
            AppLogger.info('تم رفع الصورة ${i + 1}: $imageUrl');
          }
        }
      }

      // إنشاء بيانات المنتج
      final productData = {
        'id': productId,
        'name': name,
        'description': description,
        'price': price,
        'quantity': quantity,
        'category': category,
        'sku': sku,
        'image_urls': imageUrls,
        'main_image_url': imageUrls.isNotEmpty ? imageUrls.first : null,
        'tags': tags ?? [],
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // حفظ المنتج في قاعدة البيانات
      final result = await _supabaseService.createRecord('products', productData);
      
      final product = ProductModel.fromJson(result);
      AppLogger.info('تم إنشاء المنتج بنجاح: ${product.id}');
      
      return product;
    } catch (e) {
      AppLogger.error('خطأ في إنشاء المنتج: $e');
      return null;
    }
  }

  /// تحديث صور المنتج
  Future<bool> updateProductImages(String productId, List<File> newImageFiles) async {
    try {
      AppLogger.info('تحديث صور المنتج: $productId');

      // الحصول على المنتج الحالي
      final currentProduct = await _supabaseService.getRecord('products', productId);
      if (currentProduct == null) {
        AppLogger.error('المنتج غير موجود: $productId');
        return false;
      }

      // حذف الصور القديمة
      final oldImageUrls = List<String>.from((currentProduct['image_urls'] as List<dynamic>?) ?? []);
      for (final oldUrl in oldImageUrls) {
        await _storageService.deleteFileFromUrl(oldUrl);
      }

      // رفع الصور الجديدة
      final List<String> newImageUrls = [];
      for (int i = 0; i < newImageFiles.length; i++) {
        final imageFile = newImageFiles[i];
        
        // ضغط الصورة
        final compressedImage = await _compressImage(imageFile);
        
        // رفع الصورة
        final imageUrl = await _storageService.uploadProductImage(
          productId, 
          compressedImage ?? imageFile
        );
        
        if (imageUrl != null) {
          newImageUrls.add(imageUrl);
          AppLogger.info('تم رفع الصورة الجديدة ${i + 1}: $imageUrl');
        }
      }

      // تحديث بيانات المنتج
      final updateData = {
        'image_urls': newImageUrls,
        'main_image_url': newImageUrls.isNotEmpty ? newImageUrls.first : null,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabaseService.updateRecord('products', productId, updateData);
      AppLogger.info('تم تحديث صور المنتج بنجاح');
      
      return true;
    } catch (e) {
      AppLogger.error('خطأ في تحديث صور المنتج: $e');
      return false;
    }
  }

  /// إضافة صورة واحدة للمنتج
  Future<bool> addProductImage(String productId, File imageFile) async {
    try {
      AppLogger.info('إضافة صورة للمنتج: $productId');

      // ضغط الصورة
      final compressedImage = await _compressImage(imageFile);
      
      // رفع الصورة
      final imageUrl = await _storageService.uploadProductImage(
        productId, 
        compressedImage ?? imageFile
      );

      if (imageUrl == null) {
        AppLogger.error('فشل في رفع الصورة');
        return false;
      }

      // الحصول على المنتج الحالي
      final currentProduct = await _supabaseService.getRecord('products', productId);
      if (currentProduct == null) {
        AppLogger.error('المنتج غير موجود: $productId');
        return false;
      }

      // إضافة الصورة الجديدة للقائمة
      final currentImageUrls = List<String>.from((currentProduct['image_urls'] as List<dynamic>?) ?? []);
      currentImageUrls.add(imageUrl);

      // تحديث بيانات المنتج
      final updateData = {
        'image_urls': currentImageUrls,
        'main_image_url': currentProduct['main_image_url'] ?? imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabaseService.updateRecord('products', productId, updateData);
      AppLogger.info('تم إضافة الصورة للمنتج بنجاح: $imageUrl');
      
      return true;
    } catch (e) {
      AppLogger.error('خطأ في إضافة صورة للمنتج: $e');
      return false;
    }
  }

  /// حذف صورة من المنتج
  Future<bool> removeProductImage(String productId, String imageUrl) async {
    try {
      AppLogger.info('حذف صورة من المنتج: $productId');

      // حذف الصورة من التخزين
      await _storageService.deleteFileFromUrl(imageUrl);

      // الحصول على المنتج الحالي
      final currentProduct = await _supabaseService.getRecord('products', productId);
      if (currentProduct == null) {
        AppLogger.error('المنتج غير موجود: $productId');
        return false;
      }

      // إزالة الصورة من القائمة
      final currentImageUrls = List<String>.from((currentProduct['image_urls'] as List<dynamic>?) ?? []);
      currentImageUrls.remove(imageUrl);

      // تحديث الصورة الرئيسية إذا كانت هي المحذوفة
      String? mainImageUrl = currentProduct['main_image_url'] as String?;
      if (mainImageUrl == imageUrl) {
        mainImageUrl = currentImageUrls.isNotEmpty ? currentImageUrls.first : null;
      }

      // تحديث بيانات المنتج
      final updateData = {
        'image_urls': currentImageUrls,
        'main_image_url': mainImageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabaseService.updateRecord('products', productId, updateData);
      AppLogger.info('تم حذف الصورة من المنتج بنجاح');
      
      return true;
    } catch (e) {
      AppLogger.error('خطأ في حذف صورة من المنتج: $e');
      return false;
    }
  }

  /// حذف منتج مع جميع صوره
  Future<bool> deleteProduct(String productId) async {
    try {
      AppLogger.info('حذف المنتج: $productId');

      // الحصول على المنتج
      final product = await _supabaseService.getRecord('products', productId);
      if (product == null) {
        AppLogger.error('المنتج غير موجود: $productId');
        return false;
      }

      // حذف جميع الصور
      final imageUrls = List<String>.from((product['image_urls'] as List<dynamic>?) ?? []);
      for (final imageUrl in imageUrls) {
        await _storageService.deleteFileFromUrl(imageUrl);
      }

      // حذف المنتج من قاعدة البيانات
      await _supabaseService.deleteRecord('products', productId);
      AppLogger.info('تم حذف المنتج وجميع صوره بنجاح');
      
      return true;
    } catch (e) {
      AppLogger.error('خطأ في حذف المنتج: $e');
      return false;
    }
  }

  /// ضغط الصورة لتوفير مساحة التخزين
  Future<File?> _compressImage(File imageFile) async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final bytes = await imageFile.readAsBytes();
        final image = img.decodeImage(bytes);
        
        if (image != null) {
          // تصغير الصورة إذا كانت كبيرة
          img.Image resizedImage = image;
          if (image.width > 1200 || image.height > 1200) {
            resizedImage = img.copyResize(
              image,
              width: image.width > image.height ? 1200 : null,
              height: image.height > image.width ? 1200 : null,
            );
          }

          // ضغط الصورة
          final compressedBytes = img.encodeJpg(resizedImage, quality: 85);
          
          // إنشاء ملف مؤقت
          final tempDir = Directory.systemTemp;
          final tempFile = File('${tempDir.path}/compressed_${path.basename(imageFile.path)}');
          await tempFile.writeAsBytes(compressedBytes);
          
          return tempFile;
        }
      }
      return null;
    } catch (e) {
      AppLogger.error('خطأ في ضغط الصورة: $e');
      return null;
    }
  }

  /// الحصول على جميع منتجات المستخدم
  Future<List<ProductModel>> getUserProducts(String userId) async {
    try {
      final response = await _supabase
          .from('products')
          .select('*')
          .eq('created_by', userId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>? ?? [])
          .map<ProductModel>((json) => ProductModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('خطأ في الحصول على منتجات المستخدم: $e');
      return [];
    }
  }
}
