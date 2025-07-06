import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A widget for displaying network images with advanced caching features
///
/// This widget provides an optimized way to load and display network images
/// with caching, placeholders, and error handling.
class OptimizedNetworkImage extends StatelessWidget {

  /// Creates an optimized network image with caching
  const OptimizedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.borderRadius,
    this.backgroundColor,
    this.shape = BoxShape.rectangle,
  });
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeInDuration;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final BoxShape shape;

  /// Safely converts a double to int, handling infinity and NaN values
  static int? _safeToInt(double? value) {
    if (value == null) return null;
    if (!value.isFinite || value <= 0) return null;

    // Ensure the result is within reasonable bounds (max 4K resolution)
    const maxDimension = 4096;
    final result = value.toInt();
    return result > maxDimension ? maxDimension : result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Enhanced URL validation
    if (imageUrl.isEmpty || imageUrl == 'null' || imageUrl == 'undefined') {
      return _buildContainer(
        errorWidget ?? _buildDefaultError(theme),
      );
    }

    // Validate URI format with enhanced checks
    if (!_isValidImageUrl(imageUrl)) {
      return _buildContainer(
        errorWidget ?? _buildDefaultError(theme),
      );
    }

    Widget image;
    try {
      image = CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        width: width,
        height: height,
        fadeInDuration: fadeInDuration,
        placeholder: (context, url) => placeholder ?? _buildDefaultLoading(theme),
        errorWidget: (context, url, error) {
          // Log the error for debugging
          print('🖼️ Image loading error: $url - $error');
          return errorWidget ?? _buildDefaultError(theme);
        },
        // Memory optimizations with safe conversion
        memCacheWidth: _safeToInt(width),
        memCacheHeight: _safeToInt(height),
        maxWidthDiskCache: _safeToInt(width != null ? width! * 2 : null),
        maxHeightDiskCache: _safeToInt(height != null ? height! * 2 : null),
        // Additional error prevention
        httpHeaders: const {
          'User-Agent': 'SmartBizTracker/1.0',
        },
      );
    } catch (e) {
      // Fallback for any unexpected errors
      print('🚨 Critical image widget error: $e');
      return _buildContainer(
        errorWidget ?? _buildDefaultError(theme),
      );
    }

    // If we need to apply border radius
    if (borderRadius != null && shape == BoxShape.rectangle) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return _buildContainer(image);
  }

  /// Builds the container with appropriate decorations
  Widget _buildContainer(Widget child) {
    final container = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey.shade200,
        borderRadius: shape == BoxShape.rectangle ? borderRadius : null,
        shape: shape,
      ),
      child: child,
    );

    return container;
  }

  /// Creates a default loading placeholder
  Widget _buildDefaultLoading(ThemeData theme) {
    return Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  /// Creates a default error widget
  Widget _buildDefaultError(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.broken_image_outlined,
        size: 24,
        color: theme.colorScheme.primary.withOpacity(0.5),
      ),
    );
  }

  /// Validates image URL to prevent invalid URLs and improve error handling
  ///
  /// This method performs comprehensive URL validation including:
  /// - Null/empty string checks
  /// - Basic URL format validation
  /// - Protocol scheme validation (http/https)
  /// - Common image file extension validation
  /// - Malformed URL detection
  bool _isValidImageUrl(String url) {
    // Check for null, empty, or placeholder strings
    if (url.isEmpty || url == 'null' || url == 'undefined') {
      return false;
    }

    try {
      // Parse the URL to validate its structure
      final uri = Uri.tryParse(url);
      if (uri == null) {
        return false;
      }

      // Allow relative paths starting with / (for local assets)
      if (url.startsWith('/')) {
        return true;
      }

      // Reject data URIs as they can cause parsing and memory issues
      if (uri.scheme == 'data') {
        return false;
      }

      // For absolute URLs, only allow http/https protocols
      if (uri.hasScheme && uri.scheme != 'http' && uri.scheme != 'https') {
        return false;
      }

      // For absolute URLs, must have a valid host
      if (uri.hasScheme && (uri.host.isEmpty || uri.host.contains(' '))) {
        return false;
      }

      // Optional: Check for common image file extensions
      // This is a lightweight check that can help catch obvious non-image URLs
      final path = uri.path.toLowerCase();
      if (path.isNotEmpty && !path.contains('.')) {
        // If there's a path but no extension, it might still be valid (API endpoints)
        return true;
      }

      // Check for common image extensions
      final commonImageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg', '.bmp', '.ico'];
      if (path.isNotEmpty && path.contains('.')) {
        final hasImageExtension = commonImageExtensions.any((ext) => path.endsWith(ext));
        // If it has an extension but not an image extension, it might still be valid
        // (some APIs serve images without extensions or with custom extensions)
        return true;
      }

      return true;
    } catch (e) {
      // If any exception occurs during validation, consider the URL invalid
      return false;
    }
  }
}

/// An optimized image widget that uses caching and placeholder strategies
/// to improve performance of image loading throughout the app
///
/// **Important**: Avoid passing `double.infinity` for width or height as it can
/// cause runtime errors. Instead, let the widget fill available space naturally
/// by omitting these parameters when the parent container defines the size.
class OptimizedImage extends StatelessWidget {

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.useFadeIn = true,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.useProgressIndicator = false,
    this.memCacheWidth,
    this.memCacheHeight,
  });
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool useFadeIn;
  final Duration fadeInDuration;
  final bool useProgressIndicator;
  final int? memCacheWidth;
  final int? memCacheHeight;

  @override
  Widget build(BuildContext context) {
    // Enhanced URL validation
    if (imageUrl.isEmpty || imageUrl == 'null' || imageUrl == 'undefined') {
      return _buildErrorWidget(context);
    }

    // Validate URI format
    try {
      final uri = Uri.tryParse(imageUrl);
      if (uri == null || (!uri.hasScheme && !imageUrl.startsWith('/'))) {
        return _buildErrorWidget(context);
      }
    } catch (e) {
      print('🚨 URI parsing error for: $imageUrl - $e');
      return _buildErrorWidget(context);
    }

    // Calculate cache dimensions based on device pixel ratio if not explicitly provided
    // Safely get device pixel ratio with fallback
    double devicePixelRatio = 1.0;
    try {
      final mediaQuery = MediaQuery.maybeOf(context);
      if (mediaQuery != null) {
        devicePixelRatio = mediaQuery.devicePixelRatio;
        // Validate devicePixelRatio is finite and positive
        if (!devicePixelRatio.isFinite || devicePixelRatio <= 0) {
          devicePixelRatio = 1.0;
        }
      }
    } catch (e) {
      // Fallback to 1.0 if MediaQuery is not available
      devicePixelRatio = 1.0;
    }

    // Helper function to safely calculate cache dimensions
    int? _safeCalculateCacheDimension(double? dimension, double pixelRatio) {
      if (dimension == null) return null;

      // Check for invalid values (infinity, NaN, or negative)
      if (!dimension.isFinite || dimension <= 0) {
        return null; // Return null for invalid dimensions to let CachedNetworkImage handle it
      }

      final calculated = dimension * pixelRatio;

      // Double-check the calculated value is finite before converting to int
      if (!calculated.isFinite) {
        return null;
      }

      // Ensure the result is within reasonable bounds (max 4K resolution)
      const maxCacheDimension = 4096;
      final result = calculated.ceil();
      return result > maxCacheDimension ? maxCacheDimension : result;
    }

    final calculatedMemCacheWidth = memCacheWidth ?? _safeCalculateCacheDimension(width, devicePixelRatio);
    final calculatedMemCacheHeight = memCacheHeight ?? _safeCalculateCacheDimension(height, devicePixelRatio);

    // Wrap in error boundary
    try {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: useFadeIn ? fadeInDuration : Duration.zero,
        fadeInCurve: Curves.easeInOut,
        // Use either placeholder OR progressIndicatorBuilder, not both
        placeholder: useProgressIndicator ? null : (context, url) => _buildPlaceholderWidget(context),
        errorWidget: (context, url, error) {
          print('🖼️ OptimizedImage loading error: $url - $error');
          return _buildErrorWidget(context);
        },
        // Memory cache optimizations
        memCacheWidth: calculatedMemCacheWidth,
        memCacheHeight: calculatedMemCacheHeight,
        // Enable progress indicator only when useProgressIndicator is true
        progressIndicatorBuilder: useProgressIndicator
            ? (context, url, downloadProgress) => _buildProgressWidget(context, downloadProgress)
            : null,
        // Additional error prevention
        httpHeaders: const {
          'User-Agent': 'SmartBizTracker/1.0',
        },
      );
    } catch (e) {
      // Fallback for any unexpected errors
      print('🚨 Critical OptimizedImage widget error: $e');
      return _buildErrorWidget(context);
    }
  }

  Widget _buildPlaceholderWidget(BuildContext context) {
    if (placeholder != null) return placeholder!;

    final theme = Theme.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[100]!,
            Colors.grey[200]!,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'جاري التحميل...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    if (errorWidget != null) return errorWidget!;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.red[50]!,
            Colors.red[100]!,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: Colors.red[300],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              'فشل التحميل',
              style: TextStyle(
                color: Colors.red[400],
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressWidget(BuildContext context, dynamic progress) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      child: Center(
        child: CircularProgressIndicator(
          value: progress?.progress as double?,
          strokeWidth: 2,
        ),
      ),
    );
  }

  /// Validate image URL to prevent data URI and other invalid URL errors
  bool _isValidImageUrl(String url) {
    if (url.isEmpty || url == 'null' || url == 'undefined') return false;

    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return false;

      // Allow relative paths starting with /
      if (url.startsWith('/')) return true;

      // Reject data URIs as they can cause parsing issues
      if (uri.scheme == 'data') return false;

      // Only allow http/https URLs for absolute URLs
      if (uri.hasScheme && uri.scheme != 'http' && uri.scheme != 'https') return false;

      // For absolute URLs, must have a host
      if (uri.hasScheme && uri.host.isEmpty) return false;

      return true;
    } catch (e) {
      return false;
    }
  }
}