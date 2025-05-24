import 'package:flutter/material.dart';

/// Device screen type
enum DeviceScreenType {
  mobile,
  tablet,
  desktop,
}

/// Orientation type
enum OrientationType {
  portrait,
  landscape,
}

/// Screen size information
class ScreenSizeInfo {
  final DeviceScreenType deviceScreenType;
  final OrientationType orientationType;
  final Size screenSize;
  final Size localWidgetSize;
  
  const ScreenSizeInfo({
    required this.deviceScreenType,
    required this.orientationType,
    required this.screenSize,
    required this.localWidgetSize,
  });
  
  bool get isMobile => deviceScreenType == DeviceScreenType.mobile;
  bool get isTablet => deviceScreenType == DeviceScreenType.tablet;
  bool get isDesktop => deviceScreenType == DeviceScreenType.desktop;
  bool get isPortrait => orientationType == OrientationType.portrait;
  bool get isLandscape => orientationType == OrientationType.landscape;
  
  double get width => localWidgetSize.width;
  double get height => localWidgetSize.height;
  
  /// Get the device screen type based on width
  static DeviceScreenType getDeviceType(double width) {
    if (width < 600) {
      return DeviceScreenType.mobile;
    } else if (width < 1200) {
      return DeviceScreenType.tablet;
    } else {
      return DeviceScreenType.desktop;
    }
  }
  
  /// Get the orientation type based on width and height
  static OrientationType getOrientationType(double width, double height) {
    return width < height ? OrientationType.portrait : OrientationType.landscape;
  }
}

/// A builder widget that provides screen size information
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenSizeInfo sizeInfo) builder;
  
  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.of(context);
        final screenSize = mediaQuery.size;
        final localWidgetSize = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        
        final deviceScreenType = ScreenSizeInfo.getDeviceType(screenSize.width);
        final orientationType = ScreenSizeInfo.getOrientationType(
          screenSize.width,
          screenSize.height,
        );
        
        final sizeInfo = ScreenSizeInfo(
          deviceScreenType: deviceScreenType,
          orientationType: orientationType,
          screenSize: screenSize,
          localWidgetSize: localWidgetSize,
        );
        
        return builder(context, sizeInfo);
      },
    );
  }
}

/// A widget that builds different layouts based on screen size
class ScreenTypeLayout extends StatelessWidget {
  final Widget? mobile;
  final Widget? tablet;
  final Widget? desktop;
  
  const ScreenTypeLayout({
    super.key,
    this.mobile,
    this.tablet,
    this.desktop,
  }) : assert(mobile != null || tablet != null || desktop != null);
  
  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, sizeInfo) {
        // If we're on a desktop and we have a desktop widget
        if (sizeInfo.isDesktop && desktop != null) {
          return desktop!;
        }
        
        // If we're on a tablet and we have a tablet widget
        if (sizeInfo.isTablet && tablet != null) {
          return tablet!;
        }
        
        // If we're on a mobile and we have a mobile widget
        if (sizeInfo.isMobile && mobile != null) {
          return mobile!;
        }
        
        // If we're on a tablet but don't have a tablet widget
        if (sizeInfo.isTablet && desktop != null) {
          return desktop!;
        }
        
        // If we're on a tablet but don't have a tablet or desktop widget
        if (sizeInfo.isTablet && mobile != null) {
          return mobile!;
        }
        
        // If we're on a desktop but don't have a desktop widget
        if (sizeInfo.isDesktop && tablet != null) {
          return tablet!;
        }
        
        // If we're on a desktop but don't have a desktop or tablet widget
        if (sizeInfo.isDesktop && mobile != null) {
          return mobile!;
        }
        
        // If we're on mobile but don't have a mobile widget
        if (sizeInfo.isMobile && tablet != null) {
          return tablet!;
        }
        
        // If we're on mobile but don't have a mobile or tablet widget
        if (sizeInfo.isMobile && desktop != null) {
          return desktop!;
        }
        
        // This should never happen because of the assert
        throw Exception('No layout provided for current screen type');
      },
    );
  }
}

/// A widget that builds different layouts based on orientation
class OrientationLayout extends StatelessWidget {
  final Widget? portrait;
  final Widget? landscape;
  
  const OrientationLayout({
    super.key,
    this.portrait,
    this.landscape,
  }) : assert(portrait != null || landscape != null);
  
  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, sizeInfo) {
        // If we're in portrait and we have a portrait widget
        if (sizeInfo.isPortrait && portrait != null) {
          return portrait!;
        }
        
        // If we're in landscape and we have a landscape widget
        if (sizeInfo.isLandscape && landscape != null) {
          return landscape!;
        }
        
        // If we're in portrait but don't have a portrait widget
        if (sizeInfo.isPortrait && landscape != null) {
          return landscape!;
        }
        
        // If we're in landscape but don't have a landscape widget
        if (sizeInfo.isLandscape && portrait != null) {
          return portrait!;
        }
        
        // This should never happen because of the assert
        throw Exception('No layout provided for current orientation');
      },
    );
  }
}
