import 'package:flutter/material.dart';
import '../../utils/responsive_builder.dart';

/// A responsive grid view that adjusts the number of columns based on screen size
class ResponsiveGridView extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry? padding;
  final int? mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final ScrollController? controller;
  final Widget? emptyWidget;
  final bool showEmptyWidget;
  
  const ResponsiveGridView({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
    this.padding,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 4,
    this.physics,
    this.shrinkWrap = false,
    this.controller,
    this.emptyWidget,
    this.showEmptyWidget = true,
  });
  
  @override
  Widget build(BuildContext context) {
    if (children.isEmpty && showEmptyWidget) {
      return emptyWidget ?? const SizedBox.shrink();
    }
    
    return ResponsiveBuilder(
      builder: (context, sizeInfo) {
        int crossAxisCount;
        
        if (sizeInfo.isMobile) {
          crossAxisCount = mobileColumns!;
        } else if (sizeInfo.isTablet) {
          crossAxisCount = tabletColumns!;
        } else {
          crossAxisCount = desktopColumns!;
        }
        
        return GridView.builder(
          padding: padding,
          physics: physics,
          shrinkWrap: shrinkWrap,
          controller: controller,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: runSpacing,
            childAspectRatio: _calculateChildAspectRatio(sizeInfo),
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
  
  /// Calculate the child aspect ratio based on screen size
  double _calculateChildAspectRatio(ScreenSizeInfo sizeInfo) {
    // Default aspect ratio
    double aspectRatio = 1.0;
    
    // Adjust aspect ratio based on device type
    if (sizeInfo.isMobile) {
      aspectRatio = 0.8; // Taller items on mobile
    } else if (sizeInfo.isTablet) {
      aspectRatio = 0.9; // Slightly taller items on tablet
    } else {
      aspectRatio = 1.0; // Square items on desktop
    }
    
    // Adjust aspect ratio based on orientation
    if (sizeInfo.isLandscape) {
      aspectRatio *= 1.2; // Wider items in landscape
    }
    
    return aspectRatio;
  }
}

/// A responsive grid view that wraps its children
class ResponsiveWrapGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry? padding;
  final WrapAlignment alignment;
  final WrapAlignment runAlignment;
  final WrapCrossAlignment crossAxisAlignment;
  final Clip clipBehavior;
  final Widget? emptyWidget;
  final bool showEmptyWidget;
  
  const ResponsiveWrapGrid({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
    this.padding,
    this.alignment = WrapAlignment.start,
    this.runAlignment = WrapAlignment.start,
    this.crossAxisAlignment = WrapCrossAlignment.start,
    this.clipBehavior = Clip.none,
    this.emptyWidget,
    this.showEmptyWidget = true,
  });
  
  @override
  Widget build(BuildContext context) {
    if (children.isEmpty && showEmptyWidget) {
      return emptyWidget ?? const SizedBox.shrink();
    }
    
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        alignment: alignment,
        runAlignment: runAlignment,
        crossAxisAlignment: crossAxisAlignment,
        clipBehavior: clipBehavior,
        children: children,
      ),
    );
  }
}

/// A responsive grid item that adjusts its width based on screen size
class ResponsiveGridItem extends StatelessWidget {
  final Widget child;
  final double? mobileWidth;
  final double? tabletWidth;
  final double? desktopWidth;
  final double? height;
  
  const ResponsiveGridItem({
    super.key,
    required this.child,
    this.mobileWidth = double.infinity,
    this.tabletWidth = 300,
    this.desktopWidth = 250,
    this.height,
  });
  
  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, sizeInfo) {
        double? width;
        
        if (sizeInfo.isMobile) {
          width = mobileWidth;
        } else if (sizeInfo.isTablet) {
          width = tabletWidth;
        } else {
          width = desktopWidth;
        }
        
        return SizedBox(
          width: width,
          height: height,
          child: child,
        );
      },
    );
  }
}
