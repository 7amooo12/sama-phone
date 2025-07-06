import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

/// Service to optimize performance for TabBarViews and prevent blank screens
class TabOptimizationService {
  /// Enhances TabController with optimizations to reduce blank screens
  static TabController enhanceTabController(TabController controller) {
    // Add optimized response time for tab animations
    controller.animation?.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Force a frame rebuild after tab animation completes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          WidgetsBinding.instance.scheduleForcedFrame();
        });
      }
    });
    
    return controller;
  }
  
  /// Wraps a tab's content with performance optimizations
  static Widget optimizedTabContent({
    required Widget child,
    bool deferRendering = false,
    Duration deferDuration = const Duration(milliseconds: 50),
    Widget? loadingPlaceholder,
  }) {
    return _OptimizedTabContent(
      deferRendering: deferRendering,
      deferDuration: deferDuration,
      loadingPlaceholder: loadingPlaceholder,
      child: child,
    );
  }
  
  /// Pre-initialize heavy widgets to prevent jank when switching tabs
  static void preInitializeWidgets(List<Widget> widgets) {
    // Creating offscreen widgets can cause issues, so we'll use a simpler approach
    for (final widget in widgets) {
      // Schedule precaching for performance optimization
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Just ensure the widget is created but not attached to the tree
        widget.createElement();
      });
    }
  }
  
  /// Apply critical performance optimizations to the TabBarView
  static Widget optimizedTabBarView({
    required TabController controller,
    required List<Widget> children,
    ScrollPhysics? physics = const ClampingScrollPhysics(),
    bool keepAlive = true,
    bool deferRendering = true,
  }) {
    final wrappedChildren = children.map((child) {
      Widget optimizedChild = child;
      
      // Apply deferred rendering optimization
      if (deferRendering) {
        optimizedChild = optimizedTabContent(
          child: optimizedChild,
          deferRendering: true,
        );
      }
      
      // Apply keep alive optimization if requested
      if (keepAlive) {
        optimizedChild = _KeepAliveOptimized(child: optimizedChild);
      }
      
      return optimizedChild;
    }).toList();
    
    return TabBarView(
      controller: controller,
      physics: physics,
      children: wrappedChildren,
    );
  }
  
  /// Reduce jank by precaching images that will appear in tabs
  static Future<void> precacheTabImages(
    BuildContext context, 
    List<String> imageUrls,
  ) async {
    final futures = <Future>[];
    
    for (final url in imageUrls) {
      if (url.isNotEmpty) {
        final future = precacheImage(NetworkImage(url), context);
        futures.add(future);
      }
    }
    
    // Wait for the first few images (most critical ones) to load
    await Future.wait(
      futures.take(3).toList(),
      eagerError: false,
    );
  }
  
  /// Apply memory optimizations for heavy tabs
  static void applyMemoryOptimizations() {
    // Increase image cache size
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024; // 100MB
    
    // Optimize rendering engine settings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    });
    
    // Adjust platform channels for better performance
    ServicesBinding.instance.defaultBinaryMessenger.setMessageHandler(
      'flutter/system',
      (ByteData? message) async => null,
    );
  }
}

/// Optimized widget that keeps a tab alive when it's not visible
class _KeepAliveOptimized extends StatefulWidget {

  const _KeepAliveOptimized({required this.child});
  final Widget child;

  @override
  State<_KeepAliveOptimized> createState() => _KeepAliveOptimizedState();
}

class _KeepAliveOptimizedState extends State<_KeepAliveOptimized> 
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Widget that optimizes tab content rendering to prevent blank screens
class _OptimizedTabContent extends StatefulWidget {

  const _OptimizedTabContent({
    required this.child,
    this.deferRendering = false,
    this.deferDuration = const Duration(milliseconds: 50),
    this.loadingPlaceholder,
  });
  final Widget child;
  final bool deferRendering;
  final Duration deferDuration;
  final Widget? loadingPlaceholder;

  @override
  State<_OptimizedTabContent> createState() => _OptimizedTabContentState();
}

class _OptimizedTabContentState extends State<_OptimizedTabContent> {
  bool _isReady = false;
  
  @override
  void initState() {
    super.initState();
    _prepareContent();
  }
  
  Future<void> _prepareContent() async {
    if (widget.deferRendering) {
      // Short delay to allow UI to be responsive
      await Future.delayed(widget.deferDuration);
    }
    
    if (mounted) {
      setState(() {
        _isReady = true;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return widget.loadingPlaceholder ?? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 16),
            Text('جاري التحميل...')
          ],
        )
      );
    }
    
    // Optimize rebuild performance by using RepaintBoundary
    return RepaintBoundary(
      child: widget.child,
    );
  }
} 