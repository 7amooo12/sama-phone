import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';

class ProductDetailsScreen extends StatefulWidget {

  const ProductDetailsScreen({
    super.key,
    required this.product,
  });
  final ProductModel product;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.product;

    return Scaffold(
      backgroundColor: Colors.black, // خلفية سوداء
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: CustomAppBar(
          title: 'تفاصيل المنتج',
          backgroundColor: Colors.grey.shade900, // خلفية داكنة للشريط العلوي
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey.shade900,
              Colors.black,
              Colors.grey.shade900,
            ],
          ),
        ),
        child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صور المنتج
            _buildProductImages(theme),

            // معلومات المنتج
            _buildProductInfo(theme),

            // تفاصيل إضافية
            _buildAdditionalDetails(theme),

            // إحصائيات المخزون
            _buildStockInfo(theme),

            const SizedBox(height: 100), // مساحة إضافية في الأسفل
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildProductImages(ThemeData theme) {
    final images = widget.product.images.isNotEmpty
        ? widget.product.images
        : [widget.product.bestImageUrl];

    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // عرض الصور
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemCount: images.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _showImageDialog(images[index]),
                child: _buildImageWidget(images[index], theme),
              );
            },
          ),

          // مؤشر الصور
          if (images.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: images.asMap().entries.map((entry) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentImageIndex == entry.key
                          ? theme.colorScheme.primary
                          : Colors.white.withOpacity(0.5),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(String imageUrl, ThemeData theme) {
    // التحقق من صحة الرابط
    if (imageUrl.isEmpty ||
        imageUrl.contains('placeholder.png') ||
        imageUrl.contains('placeholder.com') ||
        imageUrl.startsWith('assets/')) {
      return Container(
        color: theme.colorScheme.primary.withOpacity(0.1),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 80,
                color: theme.colorScheme.primary.withOpacity(0.6),
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد صورة متاحة',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // إصلاح URL إذا كان نسبياً
    String fixedUrl = imageUrl;
    if (!imageUrl.startsWith('http')) {
      if (imageUrl.startsWith('/')) {
        fixedUrl = 'https://samastock.pythonanywhere.com$imageUrl';
      } else {
        fixedUrl = 'https://samastock.pythonanywhere.com/static/uploads/$imageUrl';
      }
    }

    // طباعة URL للتشخيص
    print('عرض صورة المنتج في التفاصيل: $fixedUrl');

    return CachedNetworkImage(
      imageUrl: fixedUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withOpacity(0.1),
              theme.colorScheme.secondary.withOpacity(0.05),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'جاري تحميل الصورة...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        // طباعة الخطأ للتشخيص
        print('خطأ في تحميل صورة المنتج في التفاصيل: $fixedUrl - $error');
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.grey.shade100,
                Colors.grey.shade200,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'فشل في تحميل الصورة',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    'اضغط للمحاولة مرة أخرى',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      // تحسين استخدام الذاكرة والكاش
      memCacheWidth: 1024,
      memCacheHeight: 768,
      maxWidthDiskCache: 1920,
      maxHeightDiskCache: 1440,
      // إعدادات الكاش المحسنة
      cacheKey: 'product_${widget.product.id}_$fixedUrl',
      // إضافة timeout للتحميل
      httpHeaders: const {
        'Cache-Control': 'max-age=86400', // 24 ساعة
        'User-Agent': 'SmartBizTracker/1.0',
        'Accept': 'image/webp,image/jpeg,image/png,image/*',
        'Accept-Encoding': 'gzip, deflate',
      },
      // تحسين الأداء
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 100),
    );
  }

  Widget _buildProductInfo(ThemeData theme) {
    final product = widget.product;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // اسم المنتج
          Text(
            product.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white, // نص أبيض
            ),
          ),
          const SizedBox(height: 8),

          // معلومات الأسعار
          _buildPriceSection(theme),
          const SizedBox(height: 16),

          // حالة المخزون
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStockStatusColor(product.quantity).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _getStockStatusColor(product.quantity).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getStockStatusIcon(product.quantity),
                  size: 16,
                  color: _getStockStatusColor(product.quantity),
                ),
                const SizedBox(width: 8),
                Text(
                  _getStockStatusText(product.quantity),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getStockStatusColor(product.quantity),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // الوصف
          if (product.description.isNotEmpty) ...[
            Text(
              'الوصف',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white, // نص أبيض
              ),
            ),
            const SizedBox(height: 8),
            Text(
              product.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade300, // نص رمادي فاتح
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceSection(ThemeData theme) {
    final product = widget.product;

    // حساب الهامش الربحي
    double profitMargin = 0.0;
    if (product.purchasePrice != null && product.purchasePrice! > 0) {
      profitMargin = ((product.price - product.purchasePrice!) / product.purchasePrice!) * 100;
    }

    return Card(
      elevation: 8,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.grey.shade900, // خلفية داكنة للكارد
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'معلومات الأسعار',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white, // نص أبيض
              ),
            ),
            const SizedBox(height: 16),

            // سعر البيع
            Row(
              children: [
                Expanded(
                  child: _buildPriceCard(
                    'سعر البيع',
                    '${product.price.toStringAsFixed(2)} جنيه',
                    Icons.sell,
                    theme.colorScheme.primary,
                    theme,
                  ),
                ),
                const SizedBox(width: 12),

                // سعر الشراء
                Expanded(
                  child: _buildPriceCard(
                    'سعر الشراء',
                    product.purchasePrice != null
                        ? '${product.purchasePrice!.toStringAsFixed(2)} جنيه'
                        : 'غير محدد',
                    Icons.shopping_cart,
                    Colors.orange,
                    theme,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // الهامش الربحي والسعر الأصلي
            Row(
              children: [
                // الهامش الربحي
                if (product.purchasePrice != null && product.purchasePrice! > 0)
                  Expanded(
                    child: _buildPriceCard(
                      'الهامش الربحي',
                      '${profitMargin.toStringAsFixed(1)}%',
                      Icons.trending_up,
                      profitMargin > 0 ? Colors.green : Colors.red,
                      theme,
                    ),
                  ),

                if (product.purchasePrice != null && product.discountPrice != null)
                  const SizedBox(width: 12),

                // السعر الأصلي (إذا كان هناك خصم)
                if (product.discountPrice != null)
                  Expanded(
                    child: _buildPriceCard(
                      'السعر الأصلي',
                      '${product.discountPrice!.toStringAsFixed(2)} جنيه',
                      Icons.local_offer,
                      Colors.grey,
                      theme,
                    ),
                  ),
              ],
            ),

            // تكلفة التصنيع (إذا كانت متوفرة)
            if (product.manufacturingCost != null) ...[
              const SizedBox(height: 12),
              _buildPriceCard(
                'تكلفة التصنيع',
                '${product.manufacturingCost!.toStringAsFixed(2)} جنيه',
                Icons.precision_manufacturing,
                Colors.purple,
                theme,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPriceCard(String title, String value, IconData icon, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white, // نص أبيض
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalDetails(ThemeData theme) {
    final product = widget.product;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 8,
        color: Colors.grey.shade900, // خلفية داكنة
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: theme.colorScheme.secondary.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تفاصيل إضافية',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // نص أبيض
                ),
              ),
              const SizedBox(height: 16),

              _buildDetailRow('رمز المنتج (SKU)', product.sku, theme),
              _buildDetailRow('التصنيف', product.category, theme),
              if (product.supplier?.isNotEmpty == true)
                _buildDetailRow('المورد', product.supplier!, theme),
              _buildDetailRow('تاريخ الإنشاء',
                  '${product.createdAt.day}/${product.createdAt.month}/${product.createdAt.year}',
                  theme),
              _buildDetailRow('الحالة',
                  product.isActive ? 'نشط' : 'غير نشط',
                  theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade400, // نص رمادي فاتح
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white, // نص أبيض
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockInfo(ThemeData theme) {
    final product = widget.product;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 8,
        color: Colors.grey.shade900, // خلفية داكنة
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.green.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'معلومات المخزون',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // نص أبيض
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildStockCard(
                      'الكمية الحالية',
                      product.quantity.toString(),
                      Icons.inventory_2,
                      _getStockStatusColor(product.quantity),
                      theme,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStockCard(
                      'نقطة إعادة الطلب',
                      product.reorderPoint.toString(),
                      Icons.warning_amber,
                      Colors.orange,
                      theme,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockCard(String title, String value, IconData icon, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white, // نص أبيض
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showImageDialog(String imageUrl) {
    // إصلاح URL إذا كان نسبياً
    String fixedUrl = imageUrl;
    if (!imageUrl.startsWith('http')) {
      if (imageUrl.startsWith('/')) {
        fixedUrl = 'https://samastock.pythonanywhere.com$imageUrl';
      } else {
        fixedUrl = 'https://samastock.pythonanywhere.com/static/uploads/$imageUrl';
      }
    }

    print('عرض صورة المنتج في النافذة المنبثقة: $fixedUrl');

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            // خلفية شفافة قابلة للنقر للإغلاق
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.transparent,
              ),
            ),
            // الصورة
            Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: InteractiveViewer(
                    panEnabled: true,
                    scaleEnabled: true,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: CachedNetworkImage(
                      imageUrl: fixedUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'جاري تحميل الصورة...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) {
                        print('خطأ في تحميل صورة المنتج في النافذة المنبثقة: $fixedUrl - $error');
                        return Container(
                          width: 300,
                          height: 300,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white70,
                                size: 60,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'فشل في تحميل الصورة',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'اضغط خارج النافذة للإغلاق',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      // تحسين الكاش للنافذة المنبثقة
                      cacheKey: 'product_dialog_${widget.product.id}_$fixedUrl',
                      httpHeaders: const {
                        'Cache-Control': 'max-age=86400',
                        'User-Agent': 'SmartBizTracker/1.0',
                        'Accept': 'image/webp,image/jpeg,image/png,image/*',
                      },
                      fadeInDuration: const Duration(milliseconds: 200),
                      fadeOutDuration: const Duration(milliseconds: 100),
                    ),
                  ),
                ),
              ),
            ),
            // زر الإغلاق
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  tooltip: 'إغلاق',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStockStatusColor(int quantity) {
    if (quantity <= 0) return Colors.red;
    if (quantity <= 5) return Colors.orange;
    if (quantity <= 10) return Colors.amber;
    return Colors.green;
  }

  String _getStockStatusText(int quantity) {
    if (quantity <= 0) return 'نفد المخزون';
    if (quantity <= 5) return 'مخزون منخفض';
    if (quantity <= 10) return 'مخزون محدود';
    return 'متوفر';
  }

  IconData _getStockStatusIcon(int quantity) {
    if (quantity <= 0) return Icons.remove_circle;
    if (quantity <= 5) return Icons.warning;
    if (quantity <= 10) return Icons.info;
    return Icons.check_circle;
  }
}
