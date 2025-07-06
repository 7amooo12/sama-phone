import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';
import '../utils/app_logger.dart';

/// Service to sync external API products with Supabase for invoice image support
class ExternalProductSyncService {
  final _supabase = Supabase.instance.client;

  /// Sync a product from external API to Supabase for image storage in invoices
  Future<bool> syncProductToSupabase(ProductModel product) async {
    try {
      AppLogger.info('🔄 Syncing external product to Supabase: ${product.id}');

      // Use the database function for reliable sync
      final result = await _supabase.rpc('sync_external_product', params: {
        'p_external_id': product.id,
        'p_name': product.name,
        'p_description': product.description,
        'p_price': product.price,
        'p_image_url': product.bestImageUrl.isNotEmpty ? product.bestImageUrl : null,
        'p_category': product.category,
        'p_stock_quantity': product.quantity,
      });

      if (result != null) {
        AppLogger.info('✅ Product synced successfully: ${product.id}');
        return true;
      } else {
        AppLogger.error('❌ Failed to sync product: ${product.id}');
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ Error syncing product ${product.id}: $e');
      return false;
    }
  }

  /// Sync multiple products from external API
  Future<int> syncMultipleProducts(List<ProductModel> products) async {
    int successCount = 0;
    
    AppLogger.info('🔄 Syncing ${products.length} products to Supabase');

    for (final product in products) {
      final success = await syncProductToSupabase(product);
      if (success) {
        successCount++;
      }
      
      // Add small delay to avoid overwhelming the database
      await Future.delayed(const Duration(milliseconds: 100));
    }

    AppLogger.info('✅ Synced $successCount/${products.length} products successfully');
    return successCount;
  }

  /// Get product image URL from Supabase (for invoice generation)
  Future<String?> getProductImageForInvoice(String productId) async {
    try {
      AppLogger.info('🖼️ Getting product image for invoice: $productId');

      final result = await _supabase.rpc('get_product_image_url', params: {
        'product_id': productId,
      });

      if (result != null && result.toString().isNotEmpty && result.toString() != 'null') {
        AppLogger.info('✅ Found image for invoice: $result');
        return result.toString();
      }

      AppLogger.warning('⚠️ No image found for product: $productId');
      return null;
    } catch (e) {
      AppLogger.error('❌ Error getting product image for invoice: $e');
      return null;
    }
  }

  /// Ensure product exists in Supabase before creating invoice
  Future<String?> ensureProductForInvoice(ProductModel product) async {
    try {
      AppLogger.info('🔍 Ensuring product exists for invoice: ${product.id}');

      // First, try to get existing image
      final String? existingImage = await getProductImageForInvoice(product.id);
      
      if (existingImage != null) {
        AppLogger.info('✅ Product already exists with image: $existingImage');
        return existingImage;
      }

      // If no existing image, sync the product
      final syncSuccess = await syncProductToSupabase(product);
      
      if (syncSuccess) {
        // Try to get image again after sync
        return await getProductImageForInvoice(product.id);
      }

      AppLogger.warning('⚠️ Failed to ensure product for invoice: ${product.id}');
      return null;
    } catch (e) {
      AppLogger.error('❌ Error ensuring product for invoice: $e');
      return null;
    }
  }

  /// Batch sync products that will be used in invoices
  Future<Map<String, String?>> ensureProductsForInvoice(List<ProductModel> products) async {
    final Map<String, String?> productImages = {};
    
    AppLogger.info('🔄 Ensuring ${products.length} products for invoice generation');

    for (final product in products) {
      final imageUrl = await ensureProductForInvoice(product);
      productImages[product.id] = imageUrl;
    }

    final successCount = productImages.values.where((url) => url != null).length;
    AppLogger.info('✅ Ensured $successCount/${products.length} products with images for invoice');

    return productImages;
  }

  /// Check if product exists in Supabase
  Future<bool> productExistsInSupabase(String productId) async {
    try {
      final response = await _supabase
          .from('products')
          .select('id')
          .eq('id', productId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      AppLogger.error('❌ Error checking product existence: $e');
      return false;
    }
  }

  /// Get all synced products from Supabase
  Future<List<Map<String, dynamic>>> getSyncedProducts() async {
    try {
      final response = await _supabase
          .from('products')
          .select('id, name, image_url, main_image_url, source, external_id')
          .eq('source', 'external_api')
          .order('updated_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger.error('❌ Error getting synced products: $e');
      return [];
    }
  }

  /// Clean up old synced products (optional maintenance)
  Future<int> cleanupOldSyncedProducts({int daysOld = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      
      final response = await _supabase
          .from('products')
          .delete()
          .eq('source', 'external_api')
          .lt('updated_at', cutoffDate.toIso8601String());

      AppLogger.info('🧹 Cleaned up old synced products');
      return response.length;
    } catch (e) {
      AppLogger.error('❌ Error cleaning up old products: $e');
      return 0;
    }
  }

  /// Update product image URL in Supabase
  Future<bool> updateProductImage(String productId, String imageUrl) async {
    try {
      await _supabase
          .from('products')
          .update({
            'image_url': imageUrl,
            'main_image_url': imageUrl,
            'image_urls': [imageUrl],
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', productId);

      AppLogger.info('✅ Updated product image: $productId');
      return true;
    } catch (e) {
      AppLogger.error('❌ Error updating product image: $e');
      return false;
    }
  }

  /// Get product sync statistics
  Future<Map<String, int>> getSyncStatistics() async {
    try {
      // Use count() method instead of count parameter
      final totalProductsResponse = await _supabase
          .from('products')
          .select('id')
          .eq('source', 'external_api')
          .count();

      final productsWithImagesResponse = await _supabase
          .from('products')
          .select('id')
          .eq('source', 'external_api')
          .not('main_image_url', 'is', null)
          .count();

      final totalCount = totalProductsResponse.count;
      final withImagesCount = productsWithImagesResponse.count;

      return {
        'total_synced': totalCount,
        'with_images': withImagesCount,
        'without_images': totalCount - withImagesCount,
      };
    } catch (e) {
      AppLogger.error('❌ Error getting sync statistics: $e');

      // Fallback: Get actual data and count manually
      try {
        final totalProducts = await _supabase
            .from('products')
            .select('id, main_image_url')
            .eq('source', 'external_api');

        final totalCount = totalProducts.length;
        final withImagesCount = totalProducts
            .where((product) => product['main_image_url'] != null)
            .length;

        return {
          'total_synced': totalCount,
          'with_images': withImagesCount,
          'without_images': totalCount - withImagesCount,
        };
      } catch (fallbackError) {
        AppLogger.error('❌ Fallback sync statistics failed: $fallbackError');
        return {
          'total_synced': 0,
          'with_images': 0,
          'without_images': 0,
        };
      }
    }
  }
}
