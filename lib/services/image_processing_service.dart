import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageProcessingService {
  factory ImageProcessingService() => _instance;
  ImageProcessingService._internal();
  static final ImageProcessingService _instance = ImageProcessingService._internal();

  // Optimized image compositing for better performance
  Future<File?> compositeImages({
    required File roomImage,
    required File chandelierImage,
    required Offset position,
    required double scale,
    required double rotation,
    double opacity = 1.0,
  }) async {
    try {
      print('🖼️ بدء دمج الصور المحسن...');

      // Verify files exist
      if (!await roomImage.exists()) {
        throw Exception('صورة الغرفة غير موجودة');
      }
      if (!await chandelierImage.exists()) {
        throw Exception('صورة النجفة غير موجودة');
      }

      final roomBytes = await roomImage.readAsBytes();
      final chandelierBytes = await chandelierImage.readAsBytes();

      print('📁 تم قراءة ${roomBytes.length} بايت من صورة الغرفة');
      print('📁 تم قراءة ${chandelierBytes.length} بايت من صورة النجفة');

      final roomImg = img.decodeImage(roomBytes);
      final chandelierImg = img.decodeImage(chandelierBytes);

      if (roomImg == null) {
        throw Exception('فشل في فك تشفير صورة الغرفة');
      }
      if (chandelierImg == null) {
        throw Exception('فشل في فك تشفير صورة النجفة');
      }

      print('🖼️ أبعاد صورة الغرفة: ${roomImg.width}x${roomImg.height}');
      print('💡 أبعاد صورة النجفة: ${chandelierImg.width}x${chandelierImg.height}');

      // Optimize room image size for faster processing
      img.Image workingRoomImg = roomImg;
      double scaleFactor = 1.0;

      if (roomImg.width > 1200 || roomImg.height > 1200) {
        scaleFactor = 1200 / math.max(roomImg.width, roomImg.height);
        workingRoomImg = img.copyResize(
          roomImg,
          width: (roomImg.width * scaleFactor).round(),
          height: (roomImg.height * scaleFactor).round(),
          interpolation: img.Interpolation.linear, // Faster than cubic
        );
        print('📏 تم تصغير صورة الغرفة للمعالجة السريعة: ${workingRoomImg.width}x${workingRoomImg.height}');
      }

      // Create result image
      final result = img.Image.from(workingRoomImg);

      // Scale chandelier with optimized size
      print('📏 تطبيق التحجيم: ${scale}x');
      final adjustedScale = scale * scaleFactor;
      final newWidth = (chandelierImg.width * adjustedScale).round();
      final newHeight = (chandelierImg.height * adjustedScale).round();

      if (newWidth <= 0 || newHeight <= 0) {
        throw Exception('حجم النجفة غير صالح بعد التحجيم: ${newWidth}x$newHeight');
      }

      final scaledChandelier = img.copyResize(
        chandelierImg,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear, // Faster interpolation
      );

      // Rotate chandelier if needed (optimized)
      img.Image rotatedChandelier = scaledChandelier;
      if (rotation.abs() > 0.1) { // Only rotate if significant rotation
        print('🔄 تطبيق الدوران: $rotation درجة');
        rotatedChandelier = img.copyRotate(scaledChandelier, angle: rotation);
      }

      // Calculate position with scale factor
      final adjustedPosition = Offset(position.dx * scaleFactor, position.dy * scaleFactor);
      final x = (adjustedPosition.dx - rotatedChandelier.width / 2).round();
      final y = (adjustedPosition.dy - rotatedChandelier.height / 2).round();

      print('📍 موضع النجفة النهائي: ($x, $y)');

      // Composite with optimized blending
      print('🎨 تطبيق المزج المحسن...');
      _optimizedCompositeWithBlending(
        result,
        rotatedChandelier,
        x,
        y,
        opacity
      );

      // Skip lighting effects for better performance (can be re-enabled if needed)
      // print('💡 تطبيق تأثيرات الإضاءة...');
      // _applyLightingEffects(result, x, y, rotatedChandelier.width, rotatedChandelier.height);

      // Resize back to original size if we scaled down
      img.Image finalResult = result;
      if (scaleFactor != 1.0) {
        print('📏 إعادة تحجيم للحجم الأصلي...');
        finalResult = img.copyResize(
          result,
          width: roomImg.width,
          height: roomImg.height,
          interpolation: img.Interpolation.linear,
        );
      }

      // Save result
      final directory = await getTemporaryDirectory();
      final resultPath = path.join(
        directory.path,
        'ar_result_${DateTime.now().millisecondsSinceEpoch}.png'
      );

      print('💾 حفظ النتيجة النهائية في: $resultPath');
      final resultFile = File(resultPath);
      final encodedResult = img.encodePng(finalResult);
      await resultFile.writeAsBytes(encodedResult);

      print('✅ تم إنتاج ${encodedResult.length} بايت من الصورة النهائية');

      // Verify the result file
      if (!await resultFile.exists()) {
        throw Exception('فشل في حفظ الصورة النهائية');
      }

      return resultFile;
    } catch (e) {
      print('❌ خطأ في دمج الصور: $e');
      return null;
    }
  }

  // Optimized image compositing for better performance
  void _optimizedCompositeWithBlending(
    img.Image background,
    img.Image foreground,
    int offsetX,
    int offsetY,
    double opacity,
  ) {
    // Pre-calculate bounds to avoid repeated checks
    final startX = math.max(0, offsetX);
    final startY = math.max(0, offsetY);
    final endX = math.min(background.width, offsetX + foreground.width);
    final endY = math.min(background.height, offsetY + foreground.height);

    // Skip if completely outside bounds
    if (startX >= endX || startY >= endY) return;

    for (int bgY = startY; bgY < endY; bgY++) {
      final fgY = bgY - offsetY;
      for (int bgX = startX; bgX < endX; bgX++) {
        final fgX = bgX - offsetX;

        final fgPixel = foreground.getPixel(fgX, fgY);

        // Skip transparent pixels for better performance
        if (fgPixel.a == 0) continue;

        final fgAlpha = (fgPixel.a * opacity) / 255.0;

        // Skip nearly transparent pixels
        if (fgAlpha < 0.01) continue;

        final bgPixel = background.getPixel(bgX, bgY);

        // Optimized blending calculation
        final invAlpha = 1.0 - fgAlpha;
        final resultR = (fgPixel.r * fgAlpha + bgPixel.r * invAlpha).round();
        final resultG = (fgPixel.g * fgAlpha + bgPixel.g * invAlpha).round();
        final resultB = (fgPixel.b * fgAlpha + bgPixel.b * invAlpha).round();

        background.setPixel(bgX, bgY, img.ColorRgb8(resultR, resultG, resultB));
      }
    }
  }

  // Advanced image compositing with proper alpha blending (kept for reference)
  void _compositeWithBlending(
    img.Image background,
    img.Image foreground,
    int offsetX,
    int offsetY,
    double opacity,
  ) {
    for (int y = 0; y < foreground.height; y++) {
      for (int x = 0; x < foreground.width; x++) {
        final bgX = offsetX + x;
        final bgY = offsetY + y;

        if (bgX >= 0 && bgX < background.width && bgY >= 0 && bgY < background.height) {
          final fgPixel = foreground.getPixel(x, y);
          final bgPixel = background.getPixel(bgX, bgY);

          final fgAlpha = (fgPixel.a * opacity) / 255.0;

          if (fgAlpha > 0) {
            final fgR = fgPixel.r;
            final fgG = fgPixel.g;
            final fgB = fgPixel.b;

            final bgR = bgPixel.r;
            final bgG = bgPixel.g;
            final bgB = bgPixel.b;

            // Alpha blending formula
            final resultR = (fgR * fgAlpha + bgR * (1 - fgAlpha)).round();
            final resultG = (fgG * fgAlpha + bgG * (1 - fgAlpha)).round();
            final resultB = (fgB * fgAlpha + bgB * (1 - fgAlpha)).round();

            background.setPixel(bgX, bgY, img.ColorRgb8(resultR, resultG, resultB));
          }
        }
      }
    }
  }

  // Apply realistic lighting effects around the chandelier
  void _applyLightingEffects(
    img.Image image,
    int centerX,
    int centerY,
    int width,
    int height,
  ) {
    final lightRadius = (width + height) / 2 * 1.5;
    final lightCenterX = centerX + width / 2;
    final lightCenterY = centerY + height / 2;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final distance = math.sqrt((x - lightCenterX) * (x - lightCenterX) +
                         (y - lightCenterY) * (y - lightCenterY));

        if (distance < lightRadius) {
          final pixel = image.getPixel(x, y);
          final intensity = 1.0 - (distance / lightRadius);
          final lightEffect = intensity * 0.3; // Subtle lighting effect

          final r = pixel.r;
          final g = pixel.g;
          final b = pixel.b;

          // Add warm light effect
          final newR = (r + lightEffect * 50).clamp(0, 255).round();
          final newG = (g + lightEffect * 40).clamp(0, 255).round();
          final newB = (b + lightEffect * 20).clamp(0, 255).round();

          image.setPixel(x, y, img.ColorRgb8(newR, newG, newB));
        }
      }
    }
  }

  // Enhance image quality with filters
  Future<File?> enhanceImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      // Apply enhancement filters
      var enhanced = img.adjustColor(
        image,
        brightness: 1.05,
        contrast: 1.1,
        saturation: 1.05,
      );

      // Apply subtle sharpening
      enhanced = _applySharpeningFilter(enhanced);

      // Reduce noise
      enhanced = img.gaussianBlur(enhanced, radius: 1);

      // Save enhanced image
      final directory = await getTemporaryDirectory();
      final enhancedPath = path.join(
        directory.path,
        'enhanced_${DateTime.now().millisecondsSinceEpoch}.png'
      );

      final enhancedFile = File(enhancedPath);
      await enhancedFile.writeAsBytes(img.encodePng(enhanced));

      return enhancedFile;
    } catch (e) {
      print('Error enhancing image: $e');
      return null;
    }
  }

  // Apply sharpening filter
  img.Image _applySharpeningFilter(img.Image image) {
    final result = img.Image.from(image);

    // Sharpening kernel
    final kernel = [
      [0, -1, 0],
      [-1, 5, -1],
      [0, -1, 0]
    ];

    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        double r = 0, g = 0, b = 0;

        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = image.getPixel(x + kx, y + ky);
            final weight = kernel[ky + 1][kx + 1].toDouble();

            r += pixel.r * weight;
            g += pixel.g * weight;
            b += pixel.b * weight;
          }
        }

        result.setPixel(x, y, img.ColorRgb8(
          r.clamp(0, 255).round(),
          g.clamp(0, 255).round(),
          b.clamp(0, 255).round(),
        ));
      }
    }

    return result;
  }

  // Create shadow effect for chandelier
  Future<File?> createShadowEffect({
    required File roomImage,
    required Offset chandelierPosition,
    required Size chandelierSize,
    double shadowOpacity = 0.3,
    Offset shadowOffset = const Offset(10, 10),
  }) async {
    try {
      final roomBytes = await roomImage.readAsBytes();
      final roomImg = img.decodeImage(roomBytes);

      if (roomImg == null) return null;

      final result = img.Image.from(roomImg);

      // Create shadow
      final shadowX = (chandelierPosition.dx + shadowOffset.dx).round();
      final shadowY = (chandelierPosition.dy + shadowOffset.dy).round();

      _drawShadow(
        result,
        shadowX,
        shadowY,
        chandelierSize.width.round(),
        chandelierSize.height.round(),
        shadowOpacity,
      );

      // Save result
      final directory = await getTemporaryDirectory();
      final resultPath = path.join(
        directory.path,
        'shadow_${DateTime.now().millisecondsSinceEpoch}.png'
      );

      final resultFile = File(resultPath);
      await resultFile.writeAsBytes(img.encodePng(result));

      return resultFile;
    } catch (e) {
      print('Error creating shadow: $e');
      return null;
    }
  }

  // Draw realistic shadow
  void _drawShadow(
    img.Image image,
    int x,
    int y,
    int width,
    int height,
    double opacity,
  ) {
    // Create elliptical shadow
    final centerX = x + width / 2;
    final centerY = y + height;
    final radiusX = width * 0.6;
    final radiusY = height * 0.3;

    for (int py = 0; py < image.height; py++) {
      for (int px = 0; px < image.width; px++) {
        final dx = (px - centerX) / radiusX;
        final dy = (py - centerY) / radiusY;
        final distance = dx * dx + dy * dy;

        if (distance <= 1.0) {
          final shadowStrength = (1.0 - distance) * opacity;
          final pixel = image.getPixel(px, py);

          final r = pixel.r;
          final g = pixel.g;
          final b = pixel.b;

          final newR = (r * (1 - shadowStrength)).round();
          final newG = (g * (1 - shadowStrength)).round();
          final newB = (b * (1 - shadowStrength)).round();

          image.setPixel(px, py, img.ColorRgb8(newR, newG, newB));
        }
      }
    }
  }

  // Resize image while maintaining aspect ratio
  Future<File?> resizeImage(
    File imageFile, {
    int? maxWidth,
    int? maxHeight,
    bool maintainAspectRatio = true,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      img.Image resized;

      if (maintainAspectRatio) {
        resized = img.copyResize(
          image,
          width: maxWidth,
          height: maxHeight,
          interpolation: img.Interpolation.cubic,
        );
      } else {
        resized = img.copyResize(
          image,
          width: maxWidth ?? image.width,
          height: maxHeight ?? image.height,
          interpolation: img.Interpolation.cubic,
        );
      }

      // Save resized image
      final directory = await getTemporaryDirectory();
      final resizedPath = path.join(
        directory.path,
        'resized_${DateTime.now().millisecondsSinceEpoch}.png'
      );

      final resizedFile = File(resizedPath);
      await resizedFile.writeAsBytes(img.encodePng(resized));

      return resizedFile;
    } catch (e) {
      print('Error resizing image: $e');
      return null;
    }
  }
}
