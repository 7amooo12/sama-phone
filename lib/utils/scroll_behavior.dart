import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// A custom scroll behavior that optimizes scrolling across the app
///
/// This applies better physics for scrolling and enables platform-specific
/// behaviors while disabling glow effects on Android for a more polished look.
class OptimizedScrollBehavior extends ScrollBehavior {
  final bool applyAndroidOverscrollIndicator;
  final bool useAlwaysBouncingScroll;

  /// Creates an optimized scroll behavior
  ///
  /// [applyAndroidOverscrollIndicator] - Whether to show the glow effect on Android
  /// [useAlwaysBouncingScroll] - Whether to use iOS-style bouncing scrolling everywhere
  const OptimizedScrollBehavior({
    this.applyAndroidOverscrollIndicator = false,
    this.useAlwaysBouncingScroll = true,
  });

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Don't apply the Android glow effect if disabled
    if (!applyAndroidOverscrollIndicator && defaultTargetPlatform == TargetPlatform.android) {
      return child;
    }
    return super.buildOverscrollIndicator(context, child, details);
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Use platform-specific scroll physics based on parameters
    if (useAlwaysBouncingScroll) {
      return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
    }
    
    // Use platform default but ensure scrolling is always possible
    return super.getScrollPhysics(context).applyTo(const AlwaysScrollableScrollPhysics());
  }
}

/// Applies optimized scroll behavior to the entire application
///
/// Usage:
/// ```dart
/// MaterialApp(
///   scrollBehavior: OptimizedScrollBehavior(),
///   ...
/// )
/// ```
class ScrollBehaviorModified extends ScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingScrollPhysics();
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return const ClampingScrollPhysics();
    }
  }
} 