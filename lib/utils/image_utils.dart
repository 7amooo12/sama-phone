import 'package:image/image.dart' as img;

// Extension method for Image class to safely get pixel values
extension ImageExtension on img.Image {
  dynamic getPixelSafe(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return 0; // Return black for out-of-bounds
    }
    return getPixel(x, y);
  }
}

// Utility functions for image processing
class ImageUtils {
  // Get red channel value from pixel
  static int getRed(dynamic pixel) {
    if (pixel is int) {
      return (pixel >> 16) & 0xFF;
    } else {
      return pixel.r as int;  // Assuming pixel is Pixel type with r property
    }
  }
  
  // Get green channel value from pixel
  static int getGreen(dynamic pixel) {
    if (pixel is int) {
      return (pixel >> 8) & 0xFF;
    } else {
      return pixel.g as int;  // Assuming pixel is Pixel type with g property
    }
  }
  
  // Get blue channel value from pixel
  static int getBlue(dynamic pixel) {
    if (pixel is int) {
      return pixel & 0xFF;
    } else {
      return pixel.b as int;  // Assuming pixel is Pixel type with b property
    }
  }
  
  // Helper method for Dart 'min' function that works with generics
  static T min<T extends num>(T a, T b) {
    return a < b ? a : b;
  }
  
  // Helper method for Dart 'max' function that works with generics
  static T max<T extends num>(T a, T b) {
    return a > b ? a : b;
  }
} 