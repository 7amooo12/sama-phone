import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Service to optimize performance for TabBarViews and prevent blank screens
class TabOptimizationService {
  /// Enhances TabController with optimizations to reduce blank screens
  static TabController enhanceTabController(TabController controller) {
    return controller;
  }
  
  /// Wraps a tab's content with performance optimizations
  static Widget optimizedTabContent({
    required Widget child,
    bool deferRendering = false,
    Duration deferDuration = const Duration(milliseconds: 0),
    Widget? loadingPlaceholder,
  }) {
    return child;
  }
  
  /// Pre-initialize heavy widgets to prevent jank when switching tabs
  static void preInitializeWidgets(List<Widget> widgets) {
    // تم تعطيل هذه الوظيفة لأنها تسبب مشاكل في الذاكرة
  }
  
  /// Apply critical performance optimizations to the TabBarView
  static Widget optimizedTabBarView({
    required TabController controller,
    required List<Widget> children,
    ScrollPhysics? physics = const ClampingScrollPhysics(),
    bool keepAlive = true,
    bool deferRendering = false,
  }) {
    final wrappedChildren = children.map((child) {
      if (keepAlive) {
        return _KeepAliveOptimized(child: child);
      }
      return child;
    }).toList();
    
    return TabBarView(
      controller: controller,
      children: wrappedChildren,
      physics: physics,
    );
  }
  
  /// Reduce jank by precaching images that will appear in tabs
  static Future<void> precacheTabImages(
    BuildContext context, 
    List<String> imageUrls,
  ) async {
    // تم تعطيل هذه الوظيفة لتجنب استهلاك الذاكرة
  }
  
  /// Apply memory optimizations for heavy tabs
  static void applyMemoryOptimizations() {
    // استخدام قيم معقولة لحجم ذاكرة التخزين المؤقت للصور
    PaintingBinding.instance.imageCache?.maximumSizeBytes = 50 * 1024 * 1024; // 50MB
    
    // تم تعطيل الوظائف التي قد تؤثر على أداء النظام
  }
}

/// Optimized widget that keeps a tab alive when it's not visible
class _KeepAliveOptimized extends StatefulWidget {
  final Widget child;

  const _KeepAliveOptimized({required this.child});

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
  final Widget child;
  final bool deferRendering;
  final Duration deferDuration;
  final Widget? loadingPlaceholder;

  const _OptimizedTabContent({
    required this.child,
    this.deferRendering = false,
    this.deferDuration = const Duration(milliseconds: 50),
    this.loadingPlaceholder,
  });

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