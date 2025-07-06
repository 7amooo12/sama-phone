import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Utility class with optimizations for UI performance
class UIOptimizations {

  /// Configures optimized [TabController] options
  ///
  /// This method sets up TabController with optimized performance settings
  static TabController createOptimizedTabController({
    required int length,
    required TickerProvider vsync,
    int initialIndex = 0,
  }) {
    final controller = TabController(
      length: length,
      vsync: vsync,
      initialIndex: initialIndex,
      // Use shorter animation duration for faster tab switching
      animationDuration: const Duration(milliseconds: 150),
    );

    return controller;
  }

  /// Configures a TabBar with optimized settings for smoother tab switching
  static TabBar createOptimizedTabBar({
    required TabController controller,
    required List<Widget> tabs,
    Color? labelColor,
    Color? unselectedLabelColor,
    Color? indicatorColor,
    double indicatorWeight = 3.0,
    TextStyle? labelStyle,
    TextStyle? unselectedLabelStyle,
    EdgeInsetsGeometry? labelPadding,
    bool isScrollable = false,
  }) {
    return TabBar(
      controller: controller,
      tabs: tabs,
      labelColor: labelColor,
      unselectedLabelColor: unselectedLabelColor,
      indicatorColor: indicatorColor,
      indicatorWeight: indicatorWeight,
      labelStyle: labelStyle,
      unselectedLabelStyle: unselectedLabelStyle,
      labelPadding: labelPadding,
      isScrollable: isScrollable,
      // Added for performance
      enableFeedback: true,
      // Use ClampingScrollPhysics for better performance
      physics: const ClampingScrollPhysics(),
    );
  }

  /// Creates a TabBarView with optimized performance settings
  static TabBarView createOptimizedTabBarView({
    required TabController controller,
    required List<Widget> children,
    bool keepAlive = true, // Keep tabs alive to prevent rebuilding
  }) {
    // Wrap children in KeepAlive widgets if needed
    final wrappedChildren = keepAlive
        ? children.map((child) => KeepAliveTabItem(child: child)).toList()
        : children;

    return TabBarView(
      controller: controller,
      // Use ClampingScrollPhysics for better performance
      physics: const ClampingScrollPhysics(),
      children: wrappedChildren,
    );
  }

  /// Creates a TabBarView that lazily loads tab content when needed
  static TabBarView createLazyTabBarView({
    required TabController controller,
    required List<Widget> children,
  }) {
    // Wrap children in LazyTabItem widgets
    final lazyChildren = children.map((child) => LazyTabItem(child: child)).toList();

    return TabBarView(
      controller: controller,
      physics: const ClampingScrollPhysics(),
      children: lazyChildren,
    );
  }

  /// Safely converts a double to int, handling infinity and NaN values
  static int? _safeToInt(double? value) {
    if (value == null) return null;
    if (!value.isFinite || value <= 0) return null;

    // Ensure the result is within reasonable bounds (max 4K resolution)
    const maxDimension = 4096;
    final result = value.toInt();
    return result > maxDimension ? maxDimension : result;
  }

  /// Optimized network image with caching
  static Widget optimizedNetworkImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (imageUrl.isEmpty || imageUrl == 'null' || !_isValidImageUrl(imageUrl)) {
      return errorWidget ?? Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image, color: Colors.grey),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => placeholder ?? Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (context, url, error) => errorWidget ?? Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      ),
      // Optimize memory usage with safe conversion
      memCacheWidth: _safeToInt(width),
      memCacheHeight: _safeToInt(height),
      maxWidthDiskCache: _safeToInt(width != null ? width * 2 : null),
      maxHeightDiskCache: _safeToInt(height != null ? height * 2 : null),
    );
  }

  /// Validate image URL to prevent data URI and other invalid URL errors
  static bool _isValidImageUrl(String url) {
    if (url.isEmpty || url == 'null') return false;

    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return false;

      // Reject data URIs as they can cause parsing issues
      if (uri.scheme == 'data') return false;

      // Only allow http/https URLs
      if (uri.scheme != 'http' && uri.scheme != 'https') return false;

      // Must have a host
      if (uri.host.isEmpty) return false;

      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Widget that keeps a tab alive when it's not visible
class KeepAliveTabItem extends StatefulWidget {

  const KeepAliveTabItem({super.key, required this.child});
  final Widget child;

  @override
  State<KeepAliveTabItem> createState() => _KeepAliveTabItemState();
}

class _KeepAliveTabItemState extends State<KeepAliveTabItem> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Widget that lazily loads tab content when it becomes visible
class LazyTabItem extends StatefulWidget {

  const LazyTabItem({super.key, required this.child});
  final Widget child;

  @override
  State<LazyTabItem> createState() => _LazyTabItemState();
}

class _LazyTabItemState extends State<LazyTabItem> {
  bool _loaded = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    // Defer loading to ensure the widget tree is built first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTab();
    });
  }

  Future<void> _initializeTab() async {
    if (!mounted) return;

    try {
      // Add small delay to improve UI responsiveness
      await Future.delayed(const Duration(milliseconds: 50));

      if (mounted) {
        setState(() {
          _loaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text('حدث خطأ أثناء تحميل المحتوى'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _initializeTab,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (!_loaded) {
      // Show placeholder while loading
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري تحميل المحتوى...'),
          ],
        ),
      );
    }

    return widget.child;
  }
}