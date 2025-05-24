import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../utils/image_cache_manager.dart';
import '../../utils/color_extension.dart';
import '../../utils/app_logger.dart';
import 'package:flutter/scheduler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:path_provider/path_provider.dart';

/// A widget that displays an image from a URL with caching
class CachedImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Color? backgroundColor;
  final bool showLoading;
  final Duration fadeInDuration;
  final Duration placeholderFadeOutDuration;
  final FilterQuality filterQuality;
  final int? maxCacheWidth;
  final int? maxCacheHeight;
  final double loadingIndicatorSize;
  final Color? loadingIndicatorColor;
  
  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.backgroundColor,
    this.showLoading = true,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.placeholderFadeOutDuration = const Duration(milliseconds: 200),
    this.filterQuality = FilterQuality.low,
    this.maxCacheWidth,
    this.maxCacheHeight,
    this.loadingIndicatorSize = 24.0,
    this.loadingIndicatorColor,
  });
  
  @override
  State<CachedImage> createState() => _CachedImageState();
}

class _CachedImageState extends State<CachedImage> with SingleTickerProviderStateMixin {
  File? _imageFile;
  Uint8List? _imageData;
  bool _isLoading = true;
  bool _hasError = false;
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _mounted = true;
  double? _lastWidth;
  double? _lastHeight;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.fadeInDuration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    
    // Store initial dimensions for resize detection
    _lastWidth = widget.width;
    _lastHeight = widget.height;
    
    // Use post-frame callback to avoid layout issues during build
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_mounted) {
        _loadImage();
      }
    });
  }
  
  @override
  void didUpdateWidget(CachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Only reload if URL changes or dimensions change significantly
    final urlChanged = oldWidget.imageUrl != widget.imageUrl;
    final widthChanged = _lastWidth != null && widget.width != null && 
                         (_lastWidth! - widget.width!).abs() > 20;
    final heightChanged = _lastHeight != null && widget.height != null && 
                          (_lastHeight! - widget.height!).abs() > 20;
                          
    if (urlChanged || widthChanged || heightChanged) {
      _isLoading = true;
      _hasError = false;
      _imageFile = null;
      _imageData = null;
      _controller.reset();
      
      // Update stored dimensions
      _lastWidth = widget.width;
      _lastHeight = widget.height;
      
      // Safely update state
      if (_mounted) {
        _loadImage();
      }
    }
  }
  
  @override
  void dispose() {
    _mounted = false;
    _controller.dispose();
    
    // Help garbage collection
    _imageData = null;
    _imageFile = null;
    
    super.dispose();
  }
  
  // Safe setState helper
  void _safeSetState(VoidCallback fn) {
    if (_mounted && mounted) {
      setState(fn);
    }
  }
  
  Future<void> _loadImage() async {
    if (widget.imageUrl.isEmpty) {
      _safeSetState(() {
        _hasError = true;
        _isLoading = false;
      });
      return;
    }
    
    try {
      // Try to get the cached image file
      final cachedFile = await ImageCacheManager().getCachedImageFile(widget.imageUrl);
      
      if (cachedFile != null) {
        _safeSetState(() {
          _imageFile = cachedFile;
          _isLoading = false;
        });
        _controller.forward();
        return;
      }
      
      // If not cached, download and cache
      final imageData = await ImageCacheManager().getImageData(widget.imageUrl);
      
      if (imageData != null) {
        _safeSetState(() {
          _imageData = imageData;
          _isLoading = false;
        });
        _controller.forward();
      } else {
        _safeSetState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('Error in CachedImage: ${e.toString()}');
      _safeSetState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.grey.safeOpacity(0.1),
        borderRadius: widget.borderRadius,
      ),
      clipBehavior: widget.borderRadius != null ? Clip.antiAlias : Clip.none,
      child: _buildContent(),
    );
  }
  
  Widget _buildContent() {
    if (_isLoading) {
      return _buildPlaceholder();
    }
    
    if (_hasError) {
      return _buildErrorWidget();
    }
    
    return FadeTransition(
      opacity: _animation,
      child: _buildImage(),
    );
  }
  
  Widget _buildImage() {
    final cacheWidth = widget.maxCacheWidth ?? _calculateCacheSize(widget.width);
    final cacheHeight = widget.maxCacheHeight ?? _calculateCacheSize(widget.height);
    
    if (_imageFile != null) {
      return Image.file(
        _imageFile!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          AppLogger.warning('Image.file error: ${error.toString()}');
          return _buildErrorWidget();
        },
        filterQuality: widget.filterQuality,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        gaplessPlayback: true,
      );
    }
    
    if (_imageData != null) {
      return Image.memory(
        _imageData!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          AppLogger.warning('Image.memory error: ${error.toString()}');
          return _buildErrorWidget();
        },
        filterQuality: widget.filterQuality,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        gaplessPlayback: true,
      );
    }
    
    return _buildErrorWidget();
  }
  
  // Calculate appropriate cache size to reduce memory usage
  int? _calculateCacheSize(double? dimension) {
    if (dimension == null || dimension <= 0) return null;
    
    // Default to some reasonable max size if we can't get the device pixel ratio
    double devicePixelRatio;
    try {
      devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    } catch (e) {
      devicePixelRatio = 2.0; // Default fallback
    }
    
    // Optimize max size based on device capabilities
    // Lower-end devices should use smaller cache sizes
    int maxSize;
    if (devicePixelRatio >= 3.0) {
      // High-end devices
      maxSize = 1024;
    } else if (devicePixelRatio >= 2.0) {
      // Mid-range devices
      maxSize = 768;
    } else {
      // Low-end devices
      maxSize = 512;
    }
    
    final pixelDimension = dimension * devicePixelRatio;
    if (pixelDimension <= maxSize) return pixelDimension.floor();
    
    return maxSize;
  }
  
  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }
    
    return widget.showLoading
        ? Center(
            child: SizedBox(
              width: widget.loadingIndicatorSize,
              height: widget.loadingIndicatorSize,
              child: CircularProgressIndicator(
                strokeWidth: widget.loadingIndicatorSize / 10,
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.loadingIndicatorColor ?? Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          )
        : const SizedBox.shrink();
  }
  
  Widget _buildErrorWidget() {
    if (widget.errorWidget != null) {
      return widget.errorWidget!;
    }
    
    return Center(
      child: Icon(
        Icons.broken_image,
        color: Colors.grey.safeOpacity(0.5),
        size: 24,
      ),
    );
  }
}
