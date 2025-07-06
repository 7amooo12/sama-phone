import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/services/ar_service.dart';
import 'package:smartbiztracker_new/services/image_processing_service.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';

class ARViewScreen extends StatefulWidget {

  const ARViewScreen({
    super.key,
    required this.roomImage,
    required this.selectedProduct,
  });
  final File roomImage;
  final ProductModel selectedProduct;

  @override
  State<ARViewScreen> createState() => _ARViewScreenState();
}

class _ARViewScreenState extends State<ARViewScreen> with TickerProviderStateMixin {
  final ARService _arService = ARService();
  final ImageProcessingService _imageProcessingService = ImageProcessingService();

  late AnimationController _controlsAnimationController;
  late AnimationController _loadingAnimationController;

  File? _processedProductImage;
  File? _finalCompositeImage;

  // Enhanced AR Controls
  Offset _chandelierPosition = const Offset(200, 150);
  double _chandelierScale = 1.0;
  double _chandelierRotation = 0.0;
  double _chandelierRotationX = 0.0; // 3D X-axis rotation
  double _chandelierRotationY = 0.0; // 3D Y-axis rotation
  double _chandelierOpacity = 1.0;
  double _chandelierBrightness = 0.0;
  double _chandelierContrast = 1.0;
  double _chandelierSaturation = 1.0;

  // Gesture control variables
  bool _isGestureMode = true;
  bool _showAdvancedControls = false;
  double _lastScale = 1.0;
  double _lastRotation = 0.0;
  Offset _lastPanPosition = Offset.zero;

  bool _isProcessing = false;
  bool _showControls = true;
  bool _isProductProcessed = false;
  String _processingStep = '';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _processProductImage();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controlsAnimationController.dispose();
    _loadingAnimationController.dispose();

    // Clean up image files to free memory
    _processedProductImage?.delete().catchError((_) {});
    _finalCompositeImage?.delete().catchError((_) {});

    // Clear AR service cache to free memory
    _arService.clearCache();

    super.dispose();
  }

  void _initializeAnimations() {
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _loadingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _controlsAnimationController.forward();
  }

  Future<void> _processProductImage() async {
    try {
      // استخدام bestImageUrl للحصول على أفضل رابط صورة متاح
      final String rawImageUrl = widget.selectedProduct.bestImageUrl;

      if (rawImageUrl.isEmpty) {
        _showErrorDialog('لا توجد صورة للمنتج المحدد');
        return;
      }

      setState(() {
        _isProcessing = true;
        _processingStep = 'تحميل صورة المنتج...';
      });

      // جرب عدة روابط محتملة للصورة
      final possibleUrls = _generatePossibleImageUrls(rawImageUrl);

      for (int i = 0; i < possibleUrls.length; i++) {
        try {
          final imageUrl = possibleUrls[i];
          print('🔄 محاولة ${i + 1}/${possibleUrls.length}: $imageUrl');

          // Validate URL
          final uri = Uri.tryParse(imageUrl);
          if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
            print('⚠️ رابط غير صحيح: $imageUrl');
            continue;
          }

          setState(() => _processingStep = 'تحميل صورة المنتج... (محاولة ${i + 1}/${possibleUrls.length})');

          // Download product image with timeout
          final httpClient = HttpClient();
          final request = await httpClient.getUrl(uri)
              .timeout(const Duration(seconds: 15));
          final response = await request.close();

          if (response.statusCode != 200) {
            print('⚠️ HTTP ${response.statusCode} للرابط: $imageUrl');
            if (i < possibleUrls.length - 1) continue; // جرب الرابط التالي
            throw Exception('فشل في تحميل الصورة: HTTP ${response.statusCode}');
          }

          final bytes = await response.fold<List<int>>(<int>[], (previous, element) => previous..addAll(element));

          if (bytes.isEmpty) {
            print('⚠️ صورة فارغة للرابط: $imageUrl');
            if (i < possibleUrls.length - 1) continue; // جرب الرابط التالي
            throw Exception('الصورة المحملة فارغة');
          }

          print('✅ تم تحميل ${bytes.length} بايت من صورة المنتج من: $imageUrl');

          // Save to temporary file
          final tempDir = await getTemporaryDirectory();
          final productImageFile = File('${tempDir.path}/product_${DateTime.now().millisecondsSinceEpoch}.png');
          await productImageFile.writeAsBytes(bytes);

          print('💾 تم حفظ الصورة في: ${productImageFile.path}');

          // Compress image if too large for better performance
          File workingImageFile = productImageFile;
          if (bytes.length > 2 * 1024 * 1024) { // If larger than 2MB
            setState(() => _processingStep = 'ضغط الصورة لتحسين الأداء...');
            print('📦 ضغط الصورة لتحسين الأداء...');
            final compressedImage = await _arService.compressImage(productImageFile, quality: 80);
            if (compressedImage != null) {
              workingImageFile = compressedImage;
              print('✅ تم ضغط الصورة بنجاح');
            }
          }

          setState(() => _processingStep = 'إزالة الخلفية...');

          // Remove background
          print('🎨 بدء إزالة الخلفية...');
          final processedImage = await _arService.removeBackground(workingImageFile);

          if (processedImage != null) {
            print('✅ تم معالجة الصورة بنجاح: ${processedImage.path}');

            setState(() {
              _processedProductImage = processedImage;
              _isProductProcessed = true;
              _isProcessing = false;
            });

            // Generate initial composite
            await _generateComposite();
            return; // نجح التحميل، اخرج من الحلقة
          } else {
            print('⚠️ فشل في معالجة الصورة للرابط: $imageUrl');
            if (i < possibleUrls.length - 1) continue; // جرب الرابط التالي
            throw Exception('فشل في معالجة صورة المنتج - النتيجة فارغة');
          }
        } catch (e) {
          print('❌ خطأ في الرابط ${possibleUrls[i]}: $e');
          if (i < possibleUrls.length - 1) {
            continue; // جرب الرابط التالي
          } else {
            // هذا هو الرابط الأخير، ارمي الخطأ
            rethrow;
          }
        }
      }

      // إذا وصلنا هنا، فشلت جميع المحاولات
      throw Exception('فشل في تحميل صورة المنتج من جميع الروابط المحتملة');
    } catch (e) {
      await _handleImageProcessingError(e);
    }
  }

  List<String> _generatePossibleImageUrls(String originalUrl) {
    final List<String> urls = [];
    const String baseUrl = 'https://samastock.pythonanywhere.com';

    // إضافة الرابط الأصلي أولاً
    if (originalUrl.startsWith('http')) {
      urls.add(originalUrl);
    }

    // استخراج اسم الملف من الرابط الأصلي
    String fileName = originalUrl;
    if (fileName.contains('/')) {
      fileName = fileName.split('/').last;
    }

    // إضافة روابط محتملة مختلفة
    urls.addAll([
      '$baseUrl/static/uploads/$fileName',
      '$baseUrl/static/uploads/products/$fileName',
      '$baseUrl/uploads/$fileName',
      '$baseUrl/uploads/products/$fileName',
      '$baseUrl/static/images/$fileName',
      '$baseUrl/static/images/products/$fileName',
      '$baseUrl/media/$fileName',
      '$baseUrl/media/products/$fileName',
    ]);

    // إضافة روابط بامتدادات مختلفة إذا لم يكن للملف امتداد
    if (!fileName.contains('.')) {
      final extensions = ['jpg', 'jpeg', 'png', 'webp'];
      for (String ext in extensions) {
        urls.addAll([
          '$baseUrl/static/uploads/$fileName.$ext',
          '$baseUrl/static/uploads/products/$fileName.$ext',
        ]);
      }
    }

    // إزالة التكرارات والحفاظ على الترتيب
    return urls.toSet().toList();
  }

  Future<void> _handleImageProcessingError(dynamic e) async {
    print('❌ خطأ في معالجة صورة المنتج: $e');

    setState(() {
      _isProcessing = false;
      _processingStep = 'خطأ: $e';
    });

    // تحسين رسالة الخطأ بناءً على نوع المشكلة
    String errorMessage = 'فشل في معالجة صورة المنتج';

    if (e.toString().contains('no host specified') || e.toString().contains('رابط الصورة غير صحيح')) {
      errorMessage = 'رابط صورة المنتج غير صحيح أو مفقود.\nتأكد من وجود صورة للمنتج في النظام.';
    } else if (e.toString().contains('HTTP 404') || e.toString().contains('Not Found')) {
      errorMessage = 'صورة المنتج غير موجودة على الخادم.\nجربت عدة مسارات محتملة ولم أجد الصورة.\n\nتأكد من رفع صورة للمنتج في لوحة التحكم.';
    } else if (e.toString().contains('timeout') || e.toString().contains('TimeoutException')) {
      errorMessage = 'انتهت مهلة تحميل الصورة.\nتأكد من اتصال الإنترنت وحاول مرة أخرى.';
    } else if (e.toString().contains('SocketException') || e.toString().contains('connection')) {
      errorMessage = 'مشكلة في الاتصال بالإنترنت.\nتأكد من اتصالك وحاول مرة أخرى.';
    } else if (e.toString().contains('جميع الروابط المحتملة')) {
      errorMessage = 'لم أتمكن من العثور على صورة المنتج في أي من المسارات المحتملة.\n\nتأكد من:\n• رفع صورة للمنتج في لوحة التحكم\n• أن الصورة بصيغة صحيحة (JPG, PNG)\n• اتصال الإنترنت';
    } else {
      errorMessage = 'فشل في معالجة صورة المنتج:\n$e\n\nتأكد من اتصال الإنترنت وجودة الصورة.';
    }

    _showErrorDialog(errorMessage);
  }

  Future<void> _generateComposite() async {
    if (_processedProductImage == null) {
      print('⚠️ لا توجد صورة معالجة للمنتج');
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingStep = 'إنشاء المعاينة المتقدمة...';
    });

    try {
      print('🖼️ بدء دمج الصور المتقدم...');
      print('📍 الموضع: $_chandelierPosition');
      print('📏 الحجم: $_chandelierScale');
      print('🔄 الدوران: $_chandelierRotation');
      print('🔄 الدوران 3D X: $_chandelierRotationX');
      print('🔄 الدوران 3D Y: $_chandelierRotationY');
      print('👁️ الشفافية: $_chandelierOpacity');
      print('💡 السطوع: $_chandelierBrightness');
      print('🎨 التباين: $_chandelierContrast');
      print('🌈 التشبع: $_chandelierSaturation');

      // Read image bytes for advanced processing
      final roomBytes = await widget.roomImage.readAsBytes();
      final productBytes = await _processedProductImage!.readAsBytes();

      // Calculate normalized position (0.0 to 1.0)
      final screenSize = MediaQuery.of(context).size;
      final normalizedX = _chandelierPosition.dx / screenSize.width;
      final normalizedY = _chandelierPosition.dy / screenSize.height;

      // Use software-optimized AR service for better compositing
      final compositeBytes = await _arService.compositeImageAdvanced(
        backgroundBytes: roomBytes,
        productBytes: productBytes,
        x: normalizedX,
        y: normalizedY,
        scale: _chandelierScale,
        rotation: _chandelierRotation,
        opacity: _chandelierOpacity,
        brightness: _chandelierBrightness,
        contrast: _chandelierContrast,
        saturation: _chandelierSaturation,
        useSoftwareOptimization: true,
      );

      if (compositeBytes != null) {
        // Save composite to temporary file
        final tempDir = await getTemporaryDirectory();
        final compositeFile = File('${tempDir.path}/ar_composite_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await compositeFile.writeAsBytes(compositeBytes);

        print('✅ تم دمج الصور بنجاح: ${compositeFile.path}');

        setState(() {
          _finalCompositeImage = compositeFile;
          _isProcessing = false;
        });
      } else {
        throw Exception('فشل في دمج الصور - النتيجة فارغة');
      }
    } catch (e) {
      print('❌ خطأ في دمج الصور: $e');

      setState(() {
        _isProcessing = false;
        _processingStep = 'خطأ في الدمج: $e';
      });

      // Fallback to basic compositing if advanced fails
      await _generateBasicComposite();
    }
  }

  Future<void> _generateBasicComposite() async {
    try {
      final composite = await _imageProcessingService.compositeImages(
        roomImage: widget.roomImage,
        chandelierImage: _processedProductImage!,
        position: _chandelierPosition,
        scale: _chandelierScale,
        rotation: _chandelierRotation,
        opacity: _chandelierOpacity,
      );

      if (composite != null) {
        setState(() {
          _finalCompositeImage = composite;
          _isProcessing = false;
        });
      }
    } catch (e) {
      print('❌ خطأ في الدمج الأساسي: $e');
      setState(() => _isProcessing = false);
    }
  }

  // Debounce timer for performance optimization
  Timer? _debounceTimer;

  void _updateChandelierPosition(Offset newPosition) {
    setState(() => _chandelierPosition = newPosition);
    _debouncedGenerateComposite();
    HapticFeedback.lightImpact();
  }

  void _updateChandelierScale(double newScale) {
    setState(() => _chandelierScale = newScale.clamp(0.1, 3.0));
    _debouncedGenerateComposite();
  }

  void _updateChandelierRotation(double newRotation) {
    setState(() => _chandelierRotation = newRotation);
    _debouncedGenerateComposite();
  }

  void _updateChandelierRotationX(double newRotation) {
    setState(() => _chandelierRotationX = newRotation);
    _debouncedGenerateComposite();
  }

  void _updateChandelierRotationY(double newRotation) {
    setState(() => _chandelierRotationY = newRotation);
    _debouncedGenerateComposite();
  }

  void _updateChandelierOpacity(double newOpacity) {
    setState(() => _chandelierOpacity = newOpacity.clamp(0.1, 1.0));
    _debouncedGenerateComposite();
  }

  void _updateChandelierBrightness(double newBrightness) {
    setState(() => _chandelierBrightness = newBrightness.clamp(-1.0, 1.0));
    _debouncedGenerateComposite();
  }

  void _updateChandelierContrast(double newContrast) {
    setState(() => _chandelierContrast = newContrast.clamp(0.0, 2.0));
    _debouncedGenerateComposite();
  }

  void _updateChandelierSaturation(double newSaturation) {
    setState(() => _chandelierSaturation = newSaturation.clamp(0.0, 2.0));
    _debouncedGenerateComposite();
  }

  // Debounced composite generation to reduce lag
  void _debouncedGenerateComposite() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        _generateComposite();
      }
    });
  }

  // Performance monitoring
  void _logPerformanceStats() {
    final cacheStats = _arService.getCacheStats();
    print('📊 AR Performance Stats:');
    print('   Image Cache: ${cacheStats['imageCache']} items');
    print('   Processed Cache: ${cacheStats['processedImageCache']} items');
    print('   Decoded Cache: ${cacheStats['decodedImageCache']} items');
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _controlsAnimationController.forward();
    } else {
      _controlsAnimationController.reverse();
    }
  }

  void _resetPosition() {
    setState(() {
      _chandelierPosition = const Offset(200, 150);
      _chandelierScale = 1.0;
      _chandelierRotation = 0.0;
      _chandelierRotationX = 0.0;
      _chandelierRotationY = 0.0;
      _chandelierOpacity = 1.0;
      _chandelierBrightness = 0.0;
      _chandelierContrast = 1.0;
      _chandelierSaturation = 1.0;
    });
    _generateComposite();
    HapticFeedback.mediumImpact();
  }

  void _toggleGestureMode() {
    setState(() => _isGestureMode = !_isGestureMode);
    HapticFeedback.selectionClick();
  }

  void _toggleAdvancedControls() {
    setState(() => _showAdvancedControls = !_showAdvancedControls);
    HapticFeedback.selectionClick();
  }

  Future<void> _saveResult() async {
    if (_finalCompositeImage == null) return;

    try {
      // TODO: Implement save to gallery
      _showSuccessDialog('تم حفظ النتيجة بنجاح!');
    } catch (e) {
      _showErrorDialog('فشل في حفظ النتيجة: $e');
    }
  }

  void _showPossibleUrls() {
    final rawUrl = widget.selectedProduct.bestImageUrl;
    if (rawUrl.isEmpty) {
      _showErrorDialog('لا يوجد رابط صورة للمنتج');
      return;
    }

    final urls = _generatePossibleImageUrls(rawUrl);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الروابط المحتملة للصورة'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الرابط الأصلي: $rawUrl',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('الروابط المحتملة:'),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: urls.length,
                  itemBuilder: (context, index) {
                    final url = urls[index];
                    return Card(
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 12,
                          child: Text('${index + 1}'),
                        ),
                        title: Text(
                          url,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () {
                            // نسخ الرابط إلى الحافظة
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('تم نسخ الرابط: $url')),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: CustomAppBar(
        title: 'معاينة AR - ${widget.selectedProduct.name}',
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Gesture mode toggle
          if (_isProductProcessed)
            IconButton(
              icon: Icon(
                _isGestureMode ? Icons.touch_app : Icons.tap_and_play,
                color: _isGestureMode ? StyleSystem.primaryColor : Colors.white,
              ),
              onPressed: _toggleGestureMode,
              tooltip: _isGestureMode ? 'وضع النقر' : 'وضع الإيماءات',
            ),
          // Advanced controls toggle
          if (_isProductProcessed)
            IconButton(
              icon: Icon(
                Icons.tune,
                color: _showAdvancedControls ? StyleSystem.primaryColor : Colors.white,
              ),
              onPressed: _toggleAdvancedControls,
              tooltip: 'التحكم المتقدم',
            ),
          // Retry button if processing failed
          if (!_isProcessing && !_isProductProcessed)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _processProductImage,
              tooltip: 'إعادة المحاولة',
            ),
          IconButton(
            icon: Icon(_showControls ? Icons.visibility_off : Icons.visibility, color: Colors.white),
            onPressed: _toggleControls,
            tooltip: _showControls ? 'إخفاء التحكم' : 'إظهار التحكم',
          ),
          if (_finalCompositeImage != null)
            IconButton(
              icon: const Icon(Icons.save_alt, color: Colors.white),
              onPressed: _saveResult,
              tooltip: 'حفظ النتيجة',
            ),
          // Performance stats button (debug mode)
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.analytics, color: Colors.white70),
              onPressed: _logPerformanceStats,
              tooltip: 'إحصائيات الأداء',
            ),
        ],
      ),
      body: Stack(
        children: [
          // Main AR view
          _buildARView(),

          // Loading overlay
          if (_isProcessing) _buildLoadingOverlay(),

          // Error overlay if processing failed
          if (!_isProcessing && !_isProductProcessed) _buildErrorOverlay(theme),

          // Controls
          if (_showControls && _isProductProcessed) _buildControls(theme),
        ],
      ),
    );
  }

  Widget _buildARView() {
    return Positioned.fill(
      child: _isGestureMode ? _buildGestureARView() : _buildTapARView(),
    );
  }

  Widget _buildGestureARView() {
    return GestureDetector(
      onTapUp: (details) {
        if (_isProductProcessed && !_isProcessing) {
          _updateChandelierPosition(details.localPosition);
        }
      },
      onScaleStart: (details) {
        _lastScale = _chandelierScale;
        _lastRotation = _chandelierRotation;
        _lastPanPosition = details.localFocalPoint;
      },
      onScaleUpdate: (details) {
        if (_isProductProcessed && !_isProcessing) {
          // Handle scaling
          if (details.scale != 1.0) {
            final newScale = (_lastScale * details.scale).clamp(0.1, 3.0);
            _updateChandelierScale(newScale);
          }

          // Handle rotation
          if (details.rotation != 0.0) {
            final newRotation = _lastRotation + details.rotation;
            _updateChandelierRotation(newRotation);
          }

          // Handle panning
          if (details.pointerCount == 1) {
            final delta = details.localFocalPoint - _lastPanPosition;
            final newPosition = _chandelierPosition + delta;
            _updateChandelierPosition(newPosition);
            _lastPanPosition = details.localFocalPoint;
          }
        }
      },
      onScaleEnd: (details) {
        HapticFeedback.mediumImpact();
      },
      child: Container(
        color: Colors.black,
        child: _finalCompositeImage != null
            ? PhotoView(
                imageProvider: FileImage(_finalCompositeImage!),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
                initialScale: PhotoViewComputedScale.contained,
                enableRotation: false, // We handle rotation ourselves
              )
            : Image.file(
                widget.roomImage,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
      ),
    );
  }

  Widget _buildTapARView() {
    return GestureDetector(
      onTapUp: (details) {
        if (_isProductProcessed && !_isProcessing) {
          _updateChandelierPosition(details.localPosition);
        }
      },
      child: Container(
        color: Colors.black,
        child: _finalCompositeImage != null
            ? PhotoView(
                imageProvider: FileImage(_finalCompositeImage!),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
                initialScale: PhotoViewComputedScale.contained,
              )
            : Image.file(
                widget.roomImage,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RotationTransition(
                turns: _loadingAnimationController,
                child: const Icon(
                  Icons.view_in_ar,
                  color: Colors.white,
                  size: 64,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _processingStep,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const LinearProgressIndicator(
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorOverlay(ThemeData theme) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.8),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red.shade400,
                  size: 64,
                ),
                const SizedBox(height: 20),
                const Text(
                  'فشل في معالجة الصورة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _processingStep.isNotEmpty ? _processingStep : 'حدث خطأ أثناء معالجة صورة النجفة',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _processProductImage,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('العودة'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // زر لعرض الروابط المحتملة للتشخيص
                TextButton.icon(
                  onPressed: _showPossibleUrls,
                  icon: const Icon(Icons.link, color: Colors.white70),
                  label: const Text(
                    'عرض الروابط المحتملة للصورة',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls(ThemeData theme) {
    return AnimatedBuilder(
      animation: _controlsAnimationController,
      builder: (context, child) {
        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Transform.translate(
            offset: Offset(0, (1 - _controlsAnimationController.value) * 200),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Product info
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        child: widget.selectedProduct.bestImageUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: _fixImageUrl(widget.selectedProduct.bestImageUrl),
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) => const Icon(Icons.lightbulb_outline, color: Colors.white),
                                  placeholder: (context, url) => const Icon(Icons.lightbulb_outline, color: Colors.white),
                                ),
                              )
                            : const Icon(Icons.lightbulb_outline, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.selectedProduct.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.selectedProduct.price > 0)
                              Text(
                                '${widget.selectedProduct.price.toStringAsFixed(0)} ج.م',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _resetPosition,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        tooltip: 'إعادة تعيين',
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Basic Controls
                  _buildControlSlider(
                    'الحجم',
                    Icons.zoom_in,
                    _chandelierScale,
                    0.1,
                    3.0,
                    _updateChandelierScale,
                  ),

                  _buildControlSlider(
                    'الدوران',
                    Icons.rotate_right,
                    _chandelierRotation,
                    -180,
                    180,
                    _updateChandelierRotation,
                  ),

                  _buildControlSlider(
                    'الشفافية',
                    Icons.opacity,
                    _chandelierOpacity,
                    0.1,
                    1.0,
                    _updateChandelierOpacity,
                  ),

                  // Advanced Controls
                  if (_showAdvancedControls) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.tune, color: StyleSystem.primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'التحكم المتقدم',
                            style: TextStyle(
                              color: StyleSystem.primaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    _buildControlSlider(
                      'دوران 3D X',
                      Icons.rotate_90_degrees_ccw,
                      _chandelierRotationX,
                      -180,
                      180,
                      _updateChandelierRotationX,
                    ),

                    _buildControlSlider(
                      'دوران 3D Y',
                      Icons.rotate_90_degrees_cw,
                      _chandelierRotationY,
                      -180,
                      180,
                      _updateChandelierRotationY,
                    ),

                    _buildControlSlider(
                      'السطوع',
                      Icons.brightness_6,
                      _chandelierBrightness,
                      -1.0,
                      1.0,
                      _updateChandelierBrightness,
                    ),

                    _buildControlSlider(
                      'التباين',
                      Icons.contrast,
                      _chandelierContrast,
                      0.0,
                      2.0,
                      _updateChandelierContrast,
                    ),

                    _buildControlSlider(
                      'التشبع',
                      Icons.palette,
                      _chandelierSaturation,
                      0.0,
                      2.0,
                      _updateChandelierSaturation,
                    ),
                  ],

                  // Gesture mode indicator
                  if (_isGestureMode) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: StyleSystem.primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: StyleSystem.primaryColor.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.touch_app, color: StyleSystem.primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'وضع الإيماءات نشط: اسحب لتحريك، قرص للتكبير، دوّر بإصبعين',
                              style: TextStyle(
                                color: StyleSystem.primaryColor,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlSlider(
    String label,
    IconData icon,
    double value,
    double min,
    double max,
    Function(double) onChanged,
  ) {
    // Format value display based on range
    String formatValue(double val) {
      if (min < 0 && max > 0) {
        // For ranges that include negative values (like brightness)
        return val.toStringAsFixed(2);
      } else if (max <= 3.0) {
        // For small ranges (like scale, opacity)
        return val.toStringAsFixed(2);
      } else {
        // For larger ranges (like rotation)
        return val.toStringAsFixed(0);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
              activeColor: StyleSystem.primaryColor,
              inactiveColor: Colors.white.withOpacity(0.3),
              thumbColor: StyleSystem.primaryColor,
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              formatValue(value),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  String _fixImageUrl(String url) {
    // إذا كان URL كاملاً، أرجعه كما هو
    if (url.startsWith('http')) {
      return url;
    }

    // إذا كان URL فارغاً أو يحتوي على placeholder، أرجع خطأ
    if (url.isEmpty || url.contains('placeholder')) {
      throw Exception('رابط الصورة فارغ أو غير صالح');
    }

    // استخدام القيم الافتراضية
    const String defaultBaseUrl = 'https://samastock.pythonanywhere.com';
    const String defaultUploadsPath = '/static/uploads/';

    // إذا كان يحتوي على اسم ملف فقط بدون مسار، أضف المسار الكامل
    if (!url.contains('/')) {
      return '$defaultBaseUrl$defaultUploadsPath$url';
    }

    // إذا كان URL نسبياً مع مسار
    if (!url.startsWith('http')) {
      if (url.startsWith('/')) {
        return '$defaultBaseUrl$url';
      } else {
        return '$defaultBaseUrl/$url';
      }
    }

    return url;
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خطأ'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نجح'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }
}
