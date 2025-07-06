import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/product_model.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';

/// مدير كاش محسن للصور مع إعدادات متوازنة للأداء والاستقرار
class OptimizedImageCacheManager {
  static const key = 'optimizedImageCache';

  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7), // زيادة فترة الاحتفاظ لتقليل إعادة التحميل
      maxNrOfCacheObjects: 200, // زيادة عدد الصور المحفوظة للأداء الأفضل
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}

/// ويدجت محسن لعرض صور المنتجات مع أداء فائق السرعة
/// مبسط ومحسن للحصول على أفضل أداء ممكن
class EnhancedProductImage extends StatelessWidget {
  final ProductModel product;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool showProductInfo;
  final VoidCallback? onTap;

  const EnhancedProductImage({
    Key? key,
    required this.product,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.showProductInfo = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        child: _buildImageContent(),
      ),
    );
  }

  /// بناء محتوى الصورة - محسن للسرعة القصوى
  Widget _buildImageContent() {
    final imageUrl = product.bestImageUrl;

    // إذا لم تكن هناك صورة، اعرض placeholder فوراً
    if (imageUrl.isEmpty) {
      return _buildFallbackContent();
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: OptimizedImageCacheManager.instance,
      fit: fit,
      width: width,
      height: height,
      placeholder: (context, url) => _buildFastPlaceholder(),
      errorWidget: (context, url, error) => _buildFallbackContent(),
      // إعدادات محسنة للسرعة القصوى
      memCacheWidth: 300, // تقليل استخدام الذاكرة
      memCacheHeight: 300,
      maxWidthDiskCache: 400, // تقليل حجم الكاش
      maxHeightDiskCache: 400,
      fadeInDuration: const Duration(milliseconds: 150), // انتقال سريع
      fadeOutDuration: const Duration(milliseconds: 100),
      filterQuality: FilterQuality.low, // جودة منخفضة للسرعة
      useOldImageOnUrlChange: true, // استخدام الصورة القديمة أثناء التحميل
    );
  }

  /// placeholder سريع ومبسط
  Widget _buildFastPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF2A3441),
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
          ),
        ),
      ),
    );
  }

  /// المحتوى الاحتياطي عند فشل التحميل
  Widget _buildFallbackContent() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF2A3441),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 28,
            color: Color(0xFF10B981),
          ),
          SizedBox(height: 4),
          Text(
            'لا توجد صورة',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }



}

/// ويدجت فائق السرعة لعرض صور المنتجات - محسن للأداء القصوى
class FastProductImage extends StatelessWidget {
  final ProductModel product;
  final double? width;
  final double? height;
  final BoxFit fit;

  const FastProductImage({
    Key? key,
    required this.product,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.bestImageUrl;

    if (imageUrl.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: const Color(0xFF2A3441),
        child: const Icon(
          Icons.inventory_2_outlined,
          color: Color(0xFF10B981),
          size: 32,
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: OptimizedImageCacheManager.instance,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: 400,
      memCacheHeight: 400,
      fadeInDuration: const Duration(milliseconds: 100),
      fadeOutDuration: const Duration(milliseconds: 50),
      filterQuality: FilterQuality.low,
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        color: const Color(0xFF2A3441),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        width: width,
        height: height,
        color: const Color(0xFF2A3441),
        child: const Icon(
          Icons.inventory_2_outlined,
          color: Color(0xFF10B981),
          size: 32,
        ),
      ),
    );
  }
}

/// ويدجت مبسط لعرض صورة المنتج مع معالجة أساسية للأخطاء
class SimpleProductImage extends StatelessWidget {
  final ProductModel product;
  final double size;
  final BoxFit fit;

  const SimpleProductImage({
    Key? key,
    required this.product,
    this.size = 60,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EnhancedProductImage(
      product: product,
      width: size,
      height: size,
      fit: fit,
      borderRadius: BorderRadius.circular(8),
    );
  }
}

/// ويدجت لعرض صورة المنتج مع معلومات إضافية
class ProductImageWithInfo extends StatelessWidget {
  final ProductModel product;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const ProductImageWithInfo({
    Key? key,
    required this.product,
    this.width = 120,
    this.height = 120,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EnhancedProductImage(
      product: product,
      width: width,
      height: height,
      showProductInfo: true,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
    );
  }
}
