import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

class ARService {
  factory ARService() => _instance;
  ARService._internal();
  static final ARService _instance = ARService._internal();

  List<CameraDescription>? _cameras;
  CameraController? _cameraController;
  bool _isInitialized = false;

  // Enhanced AR properties with software optimization
  final Map<String, ui.Image> _imageCache = {};
  final Map<String, Uint8List> _processedImageCache = {};
  final Map<String, img.Image> _decodedImageCache = {};
  final bool _isSoftwareOptimizationEnabled = true;

  // Initialize AR service
  Future<bool> initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        return false;
      }

      _cameraController = CameraController(
        _cameras!.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      _isInitialized = true;
      return true;
    } catch (e) {
      print('Error initializing AR service: $e');
      return false;
    }
  }

  // Get camera controller
  CameraController? get cameraController => _cameraController;
  bool get isInitialized => _isInitialized;

  // Capture photo from camera
  Future<File?> capturePhoto() async {
    if (!_isInitialized || _cameraController == null) {
      return null;
    }

    try {
      final XFile photo = await _cameraController!.takePicture();
      return File(photo.path);
    } catch (e) {
      print('Error capturing photo: $e');
      return null;
    }
  }

  // Remove background from image using optimized edge detection
  Future<File?> removeBackground(File imageFile) async {
    try {
      print('🎨 بدء إزالة الخلفية للملف: ${imageFile.path}');

      // Check if file exists
      if (!await imageFile.exists()) {
        throw Exception('الملف غير موجود: ${imageFile.path}');
      }

      final bytes = await imageFile.readAsBytes();
      print('📁 تم قراءة ${bytes.length} بايت من الملف');

      if (bytes.isEmpty) {
        throw Exception('الملف فارغ');
      }

      final image = img.decodeImage(bytes);
      if (image == null) {
        throw Exception('فشل في فك تشفير الصورة - تنسيق غير مدعوم');
      }

      print('🖼️ أبعاد الصورة: ${image.width}x${image.height}');

      // Resize image for faster processing if too large
      img.Image workingImage = image;
      if (image.width > 800 || image.height > 800) {
        print('📏 تصغير الصورة لتحسين الأداء...');
        workingImage = img.copyResize(
          image,
          width: image.width > image.height ? 800 : null,
          height: image.height > image.width ? 800 : null,
          interpolation: img.Interpolation.linear, // Faster than cubic
        );
        print('📏 الأبعاد الجديدة: ${workingImage.width}x${workingImage.height}');
      }

      // Apply optimized background removal algorithm
      print('⚙️ تطبيق خوارزمية إزالة الخلفية المحسنة...');
      final processedImage = await _optimizedBackgroundRemoval(workingImage);

      // Resize back to original size if needed
      img.Image finalImage = processedImage;
      if (workingImage.width != image.width || workingImage.height != image.height) {
        print('📏 إعادة تحجيم للحجم الأصلي...');
        finalImage = img.copyResize(
          processedImage,
          width: image.width,
          height: image.height,
          interpolation: img.Interpolation.linear,
        );
      }

      // Save processed image
      final directory = await getTemporaryDirectory();
      final processedPath = path.join(
        directory.path,
        'processed_${DateTime.now().millisecondsSinceEpoch}.png'
      );

      print('💾 حفظ الصورة المعالجة في: $processedPath');
      final processedFile = File(processedPath);
      final encodedBytes = img.encodePng(finalImage);
      await processedFile.writeAsBytes(encodedBytes);

      print('✅ تم إنتاج ${encodedBytes.length} بايت من الصورة المعالجة');

      // Verify the processed file
      if (!await processedFile.exists()) {
        throw Exception('فشل في حفظ الصورة المعالجة');
      }

      return processedFile;
    } catch (e) {
      print('❌ خطأ في إزالة الخلفية: $e');
      return null;
    }
  }

  // Optimized background removal algorithm for better performance
  Future<img.Image> _optimizedBackgroundRemoval(img.Image image) async {
    // Create a copy of the image
    final result = img.Image.from(image);

    // Use simplified color-based background removal for speed
    final cornerColors = <img.Color>[];
    final cornerSize = math.min(20, math.min(image.width, image.height) ~/ 10);

    // Sample corner regions more efficiently
    for (int y = 0; y < cornerSize; y += 2) { // Skip every other pixel for speed
      for (int x = 0; x < cornerSize; x += 2) {
        if (x < image.width && y < image.height) {
          cornerColors.add(image.getPixel(x, y));
        }
        if (image.width - 1 - x >= 0 && y < image.height) {
          cornerColors.add(image.getPixel(image.width - 1 - x, y));
        }
        if (x < image.width && image.height - 1 - y >= 0) {
          cornerColors.add(image.getPixel(x, image.height - 1 - y));
        }
        if (image.width - 1 - x >= 0 && image.height - 1 - y >= 0) {
          cornerColors.add(image.getPixel(image.width - 1 - x, image.height - 1 - y));
        }
      }
    }

    if (cornerColors.isEmpty) return result;

    // Calculate average background color
    final avgR = cornerColors.map((c) => c.r).reduce((a, b) => a + b) / cornerColors.length;
    final avgG = cornerColors.map((c) => c.g).reduce((a, b) => a + b) / cornerColors.length;
    final avgB = cornerColors.map((c) => c.b).reduce((a, b) => a + b) / cornerColors.length;

    // Apply simplified background removal
    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);

        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;

        // Calculate color distance from background (simplified)
        final colorDistance = math.sqrt((r - avgR) * (r - avgR) +
                              (g - avgG) * (g - avgG) +
                              (b - avgB) * (b - avgB));

        // Use a more lenient threshold for faster processing
        if (colorDistance < 60) {
          // Make background transparent
          result.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
        }
      }
    }

    return result;
  }

  // Advanced background removal algorithm (kept for reference)
  Future<img.Image> _advancedBackgroundRemoval(img.Image image) async {
    // Create a copy of the image
    final result = img.Image.from(image);

    // Convert to grayscale for edge detection
    final grayscale = img.grayscale(img.Image.from(image));

    // Apply Gaussian blur to reduce noise
    final blurred = img.gaussianBlur(grayscale, radius: 2);

    // Apply edge detection (Sobel operator)
    final edges = _applySobelEdgeDetection(blurred);

    // Create mask based on edge detection and color analysis
    final mask = _createBackgroundMask(image, edges);

    // Apply mask to original image
    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        final maskPixel = mask.getPixel(x, y);
        if (img.getLuminance(maskPixel) < 128) {
          // Make background transparent
          result.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
        }
      }
    }

    return result;
  }

  // Apply Sobel edge detection
  img.Image _applySobelEdgeDetection(img.Image image) {
    final result = img.Image(width: image.width, height: image.height);

    // Sobel kernels
    final sobelX = [
      [-1, 0, 1],
      [-2, 0, 2],
      [-1, 0, 1]
    ];

    final sobelY = [
      [-1, -2, -1],
      [0, 0, 0],
      [1, 2, 1]
    ];

    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        double gx = 0, gy = 0;

        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = image.getPixel(x + kx, y + ky);
            final intensity = img.getLuminance(pixel);

            gx += intensity * sobelX[ky + 1][kx + 1];
            gy += intensity * sobelY[ky + 1][kx + 1];
          }
        }

        final magnitude = math.sqrt(gx * gx + gy * gy);
        final normalizedMagnitude = (magnitude.clamp(0, 255)).toInt();

        result.setPixel(x, y, img.ColorRgb8(
          normalizedMagnitude,
          normalizedMagnitude,
          normalizedMagnitude
        ));
      }
    }

    return result;
  }

  // Create background mask using color analysis and edge information
  img.Image _createBackgroundMask(img.Image original, img.Image edges) {
    final mask = img.Image(width: original.width, height: original.height);

    // Analyze corner pixels to determine background color
    final cornerColors = <img.Color>[];
    const cornerSize = 20;

    // Sample corner regions
    for (int y = 0; y < cornerSize; y++) {
      for (int x = 0; x < cornerSize; x++) {
        cornerColors.add(original.getPixel(x, y));
        cornerColors.add(original.getPixel(original.width - 1 - x, y));
        cornerColors.add(original.getPixel(x, original.height - 1 - y));
        cornerColors.add(original.getPixel(original.width - 1 - x, original.height - 1 - y));
      }
    }

    // Calculate average background color
    final avgR = cornerColors.map((c) => c.r).reduce((a, b) => a + b) / cornerColors.length;
    final avgG = cornerColors.map((c) => c.g).reduce((a, b) => a + b) / cornerColors.length;
    final avgB = cornerColors.map((c) => c.b).reduce((a, b) => a + b) / cornerColors.length;

    // Create mask based on color similarity and edge strength
    for (int y = 0; y < original.height; y++) {
      for (int x = 0; x < original.width; x++) {
        final pixel = original.getPixel(x, y);
        final edgePixel = edges.getPixel(x, y);

        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;

        // Calculate color distance from background
        final colorDistance = math.sqrt((r - avgR) * (r - avgR) +
                              (g - avgG) * (g - avgG) +
                              (b - avgB) * (b - avgB));

        final edgeStrength = (edgePixel.r + edgePixel.g + edgePixel.b) / 3;

        // Combine color similarity and edge information
        final isBackground = colorDistance < 50 && edgeStrength < 100;

        mask.setPixel(x, y, isBackground
          ? img.ColorRgb8(0, 0, 0)  // Background (black)
          : img.ColorRgb8(255, 255, 255));  // Foreground (white)
      }
    }

    // Apply morphological operations to clean up the mask
    return _morphologicalClosing(_morphologicalOpening(mask));
  }

  // Morphological opening (erosion followed by dilation)
  img.Image _morphologicalOpening(img.Image image) {
    final eroded = _morphologicalErosion(image);
    return _morphologicalDilation(eroded);
  }

  // Morphological closing (dilation followed by erosion)
  img.Image _morphologicalClosing(img.Image image) {
    final dilated = _morphologicalDilation(image);
    return _morphologicalErosion(dilated);
  }

  // Morphological erosion
  img.Image _morphologicalErosion(img.Image image) {
    final result = img.Image.from(image);
    const kernel = 3; // 3x3 kernel
    const offset = kernel ~/ 2;

    for (int y = offset; y < image.height - offset; y++) {
      for (int x = offset; x < image.width - offset; x++) {
        int minValue = 255;

        for (int ky = -offset; ky <= offset; ky++) {
          for (int kx = -offset; kx <= offset; kx++) {
            final pixel = image.getPixel(x + kx, y + ky);
            final value = ((pixel.r + pixel.g + pixel.b) / 3).toInt();
            minValue = minValue < value ? minValue : value;
          }
        }

        result.setPixel(x, y, img.ColorRgb8(minValue, minValue, minValue));
      }
    }

    return result;
  }

  // Morphological dilation
  img.Image _morphologicalDilation(img.Image image) {
    final result = img.Image.from(image);
    const kernel = 3; // 3x3 kernel
    const offset = kernel ~/ 2;

    for (int y = offset; y < image.height - offset; y++) {
      for (int x = offset; x < image.width - offset; x++) {
        int maxValue = 0;

        for (int ky = -offset; ky <= offset; ky++) {
          for (int kx = -offset; kx <= offset; kx++) {
            final pixel = image.getPixel(x + kx, y + ky);
            final value = ((pixel.r + pixel.g + pixel.b) / 3).toInt();
            maxValue = maxValue > value ? maxValue : value;
          }
        }

        result.setPixel(x, y, img.ColorRgb8(maxValue, maxValue, maxValue));
      }
    }

    return result;
  }

  // Compress image for better performance
  Future<File?> compressImage(File imageFile, {int quality = 85}) async {
    try {
      final directory = await getTemporaryDirectory();
      final compressedPath = path.join(
        directory.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg'
      );

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        compressedPath,
        quality: quality,
        minWidth: 1024,
        minHeight: 1024,
      );

      return compressedFile != null ? File(compressedFile.path) : null;
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }

  /// Advanced AR transformation with 3D matrix calculations
  vm.Matrix4 calculateTransformMatrix({
    required double x,
    required double y,
    required double scale,
    required double rotationX,
    required double rotationY,
    required double rotationZ,
    required Size screenSize,
  }) {
    final matrix = vm.Matrix4.identity();

    // Translate to position
    matrix.translate(x * screenSize.width, y * screenSize.height, 0.0);

    // Apply rotations
    matrix.rotateX(rotationX);
    matrix.rotateY(rotationY);
    matrix.rotateZ(rotationZ);

    // Apply scale
    matrix.scale(scale, scale, 1.0);

    return matrix;
  }

  /// Software-optimized image compositing with real-time performance
  Future<Uint8List?> compositeImageAdvanced({
    required Uint8List backgroundBytes,
    required Uint8List productBytes,
    required double x,
    required double y,
    required double scale,
    required double rotation,
    required double opacity,
    required double brightness,
    required double contrast,
    required double saturation,
    bool useSoftwareOptimization = true,
  }) async {
    try {
      // Use cached images for better performance
      final cacheKey = '${productBytes.hashCode}_${scale}_${rotation}_${brightness}_${contrast}_$saturation';

      if (_processedImageCache.containsKey(cacheKey)) {
        return await _compositeWithBackground(
          backgroundBytes,
          _processedImageCache[cacheKey]!,
          x,
          y,
          opacity
        );
      }

      // Use cached decoded images for better performance
      img.Image? backgroundImage;
      img.Image? productImage;

      final backgroundCacheKey = 'bg_${backgroundBytes.hashCode}';
      final productCacheKey = 'prod_${productBytes.hashCode}';

      if (_decodedImageCache.containsKey(backgroundCacheKey)) {
        backgroundImage = _decodedImageCache[backgroundCacheKey];
      } else {
        backgroundImage = img.decodeImage(backgroundBytes);
        if (backgroundImage != null) {
          _decodedImageCache[backgroundCacheKey] = backgroundImage;
        }
      }

      if (_decodedImageCache.containsKey(productCacheKey)) {
        productImage = _decodedImageCache[productCacheKey];
      } else {
        productImage = img.decodeImage(productBytes);
        if (productImage != null) {
          _decodedImageCache[productCacheKey] = productImage;
        }
      }

      if (backgroundImage == null || productImage == null) {
        return null;
      }

      // Create a copy of the background
      final composite = img.Image.from(backgroundImage);

      // Apply software-optimized transformations to product image
      final img.Image transformedProduct = await _applySoftwareOptimizedTransformations(
        productImage,
        scale: scale,
        rotation: rotation,
        brightness: brightness,
        contrast: contrast,
        saturation: saturation,
      );

      // Cache the processed product image
      _processedImageCache[cacheKey] = Uint8List.fromList(img.encodePng(transformedProduct));

      // Calculate position with improved precision
      final posX = (x * composite.width - transformedProduct.width / 2).round();
      final posY = (y * composite.height - transformedProduct.height / 2).round();

      // Advanced compositing with lighting simulation
      await _compositeWithLighting(
        composite,
        transformedProduct,
        posX,
        posY,
        opacity,
      );

      // Encode result with optimized quality
      return Uint8List.fromList(img.encodeJpg(composite, quality: 95));
    } catch (e) {
      print('Error in advanced composite: $e');
      return null;
    }
  }

  /// Apply software-optimized transformations for better performance
  Future<img.Image> _applySoftwareOptimizedTransformations(
    img.Image image, {
    required double scale,
    required double rotation,
    required double brightness,
    required double contrast,
    required double saturation,
  }) async {
    img.Image result = image;

    // Apply scaling first to reduce processing load for subsequent operations
    if (scale != 1.0) {
      final newWidth = (result.width * scale).round();
      final newHeight = (result.height * scale).round();

      // Use linear interpolation for better performance on mobile devices
      result = img.copyResize(
        result,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );
    }

    // Apply rotation with optimized interpolation
    if (rotation != 0) {
      result = img.copyRotate(
        result,
        angle: rotation,
        interpolation: img.Interpolation.linear, // Faster than cubic
      );
    }

    // Apply color adjustments last for better visual quality
    if (brightness != 0.0 || contrast != 1.0 || saturation != 1.0) {
      result = img.adjustColor(
        result,
        brightness: brightness,
        contrast: contrast,
        saturation: saturation,
      );
    }

    return result;
  }

  /// Advanced compositing with lighting and shadow effects
  Future<void> _compositeWithLighting(
    img.Image background,
    img.Image product,
    int posX,
    int posY,
    double opacity,
  ) async {
    // Create shadow effect
    final shadow = img.Image.from(product);
    img.fill(shadow, color: img.ColorRgba8(0, 0, 0, (opacity * 0.3 * 255).round()));

    // Composite shadow first (slightly offset)
    img.compositeImage(
      background,
      shadow,
      dstX: posX + 5,
      dstY: posY + 5,
      blend: img.BlendMode.multiply,
    );

    // Composite main product with proper alpha blending
    img.compositeImage(
      background,
      product,
      dstX: posX,
      dstY: posY,
      blend: img.BlendMode.alpha,
    );
  }

  /// Optimized background compositing
  Future<Uint8List?> _compositeWithBackground(
    Uint8List backgroundBytes,
    Uint8List productBytes,
    double x,
    double y,
    double opacity,
  ) async {
    try {
      final backgroundImage = img.decodeImage(backgroundBytes);
      final productImage = img.decodeImage(productBytes);

      if (backgroundImage == null || productImage == null) {
        return null;
      }

      final composite = img.Image.from(backgroundImage);
      final posX = (x * composite.width - productImage.width / 2).round();
      final posY = (y * composite.height - productImage.height / 2).round();

      img.compositeImage(
        composite,
        productImage,
        dstX: posX,
        dstY: posY,
        blend: img.BlendMode.alpha,
      );

      return Uint8List.fromList(img.encodeJpg(composite, quality: 95));
    } catch (e) {
      print('Error in background composite: $e');
      return null;
    }
  }

  /// Clear image caches to free memory
  void clearCache() {
    _imageCache.clear();
    _processedImageCache.clear();
    _decodedImageCache.clear();
    print('🧹 AR Service: Cleared all image caches');
  }

  /// Get cache statistics for debugging
  Map<String, int> getCacheStats() {
    return {
      'imageCache': _imageCache.length,
      'processedImageCache': _processedImageCache.length,
      'decodedImageCache': _decodedImageCache.length,
    };
  }

  // Dispose resources
  void dispose() {
    _cameraController?.dispose();
    clearCache();
    _isInitialized = false;
  }
}
