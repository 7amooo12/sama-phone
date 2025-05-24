import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';

/// A widget for displaying network images with advanced caching features
/// 
/// This widget provides an optimized way to load and display network images
/// with caching, placeholders, and error handling.
class OptimizedNetworkImage extends StatelessWidget {
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
  
  /// Creates an optimized network image with caching
  const OptimizedNetworkImage({
    Key? key,
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
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (imageUrl.isEmpty) {
      return _buildContainer(
        errorWidget ?? _buildDefaultError(theme),
      );
    }
    
    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      fadeInDuration: fadeInDuration,
      placeholder: (context, url) => placeholder ?? _buildDefaultLoading(theme),
      errorWidget: (context, url, error) => errorWidget ?? _buildDefaultError(theme),
      // Memory optimizations
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
      maxWidthDiskCache: (width != null) ? (width! * 2).toInt() : null,
      maxHeightDiskCache: (height != null) ? (height! * 2).toInt() : null,
    );
    
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
}

/// An optimized image widget that uses caching and placeholder strategies
/// to improve performance of image loading throughout the app
class OptimizedImage extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    // Empty URL check - quick fail 
    if (imageUrl.isEmpty) {
      return _buildErrorWidget(context);
    }

    // Calculate cache dimensions based on device pixel ratio if not explicitly provided
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final calculatedMemCacheWidth = memCacheWidth ?? (width != null ? (width! * devicePixelRatio).ceil() : null);
    final calculatedMemCacheHeight = memCacheHeight ?? (height != null ? (height! * devicePixelRatio).ceil() : null);

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: useFadeIn ? fadeInDuration : Duration.zero,
      fadeInCurve: Curves.easeInOut,
      placeholder: (context, url) => _buildPlaceholderWidget(context),
      errorWidget: (context, url, error) => _buildErrorWidget(context),
      // Memory cache optimizations
      memCacheWidth: calculatedMemCacheWidth,
      memCacheHeight: calculatedMemCacheHeight,
      // Enable or disable progress placeholder based on prop
      progressIndicatorBuilder: useProgressIndicator 
          ? (context, url, downloadProgress) => _buildProgressWidget(context, downloadProgress) 
          : null,
    );
  }

  Widget _buildPlaceholderWidget(BuildContext context) {
    if (placeholder != null) return placeholder!;
    
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
      // Skip animations in release mode for better performance
      child: kDebugMode
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : const SizedBox.shrink(),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    if (errorWidget != null) return errorWidget!;
    
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
      child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
    );
  }

  Widget _buildProgressWidget(BuildContext context, DownloadProgress progress) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
      child: Center(
        child: CircularProgressIndicator(
          value: progress.progress,
          strokeWidth: 2,
        ),
      ),
    );
  }
} 