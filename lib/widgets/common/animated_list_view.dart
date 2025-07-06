import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/animation_system.dart';

/// قائمة متحركة احترافية
/// توفر هذه القائمة تأثيرات حركية متعددة وخيارات تخصيص متقدمة
class AnimatedListView extends StatelessWidget {

  const AnimatedListView({
    super.key,
    required this.children,
    this.controller,
    this.padding = const EdgeInsets.all(16),
    this.shrinkWrap = false,
    this.physics,
    this.primary,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.animationType = AnimationType.fadeSlideFromBottom,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
    this.curve = Curves.easeOut,
    this.offset = 50,
    this.staggered = true,
    this.staggeredDelayFactor = 50,
  });
  final List<Widget> children;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final bool? primary;
  final Axis scrollDirection;
  final bool reverse;
  final AnimationType animationType;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final double offset;
  final bool staggered;
  final int staggeredDelayFactor;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      primary: primary,
      scrollDirection: scrollDirection,
      reverse: reverse,
      itemCount: children.length,
      itemBuilder: (context, index) {
        final staggeredDelay = staggered
            ? Duration(milliseconds: delay.inMilliseconds + (index * staggeredDelayFactor))
            : delay;

        return _buildAnimatedItem(
          children[index],
          index,
          staggeredDelay,
        );
      },
    );
  }

  Widget _buildAnimatedItem(Widget child, int index, Duration itemDelay) {
    switch (animationType) {
      case AnimationType.fadeIn:
        return AnimationSystem.fadeInWithDelay(
          child,
          delay: itemDelay,
          duration: duration,
          curve: curve,
        );

      case AnimationType.fadeSlideFromBottom:
        return AnimationSystem.fadeSlideInWithDelay(
          child,
          delay: itemDelay,
          duration: duration,
          curve: curve,
          offset: Offset(0, offset),
        );

      case AnimationType.fadeSlideFromTop:
        return AnimationSystem.fadeSlideInWithDelay(
          child,
          delay: itemDelay,
          duration: duration,
          curve: curve,
          offset: Offset(0, -offset),
        );

      case AnimationType.fadeSlideFromRight:
        return AnimationSystem.fadeSlideInWithDelay(
          child,
          delay: itemDelay,
          duration: duration,
          curve: curve,
          offset: Offset(offset, 0),
        );

      case AnimationType.fadeSlideFromLeft:
        return AnimationSystem.fadeSlideInWithDelay(
          child,
          delay: itemDelay,
          duration: duration,
          curve: curve,
          offset: Offset(-offset, 0),
        );

      case AnimationType.scale:
        return _ScaleAnimation(
          delay: itemDelay,
          duration: duration,
          curve: curve,
          child: child,
        );

      case AnimationType.none:
        return child;
    }
  }
}

/// قائمة شبكية متحركة احترافية
class AnimatedGridView extends StatelessWidget {

  const AnimatedGridView({
    super.key,
    required this.children,
    this.controller,
    this.padding = const EdgeInsets.all(16),
    this.shrinkWrap = false,
    this.physics,
    this.primary,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.animationType = AnimationType.fadeSlideFromBottom,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
    this.curve = Curves.easeOut,
    this.offset = 50,
    this.staggered = true,
    this.staggeredDelayFactor = 50,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = 16,
    this.crossAxisSpacing = 16,
    this.childAspectRatio = 1.0,
  });
  final List<Widget> children;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final bool? primary;
  final Axis scrollDirection;
  final bool reverse;
  final AnimationType animationType;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final double offset;
  final bool staggered;
  final int staggeredDelayFactor;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: controller,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      primary: primary,
      scrollDirection: scrollDirection,
      reverse: reverse,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) {
        final staggeredDelay = staggered
            ? Duration(milliseconds: delay.inMilliseconds + (index * staggeredDelayFactor))
            : delay;

        return _buildAnimatedItem(
          children[index],
          index,
          staggeredDelay,
        );
      },
    );
  }

  Widget _buildAnimatedItem(Widget child, int index, Duration itemDelay) {
    switch (animationType) {
      case AnimationType.fadeIn:
        return AnimationSystem.fadeInWithDelay(
          child,
          delay: itemDelay,
          duration: duration,
          curve: curve,
        );

      case AnimationType.fadeSlideFromBottom:
        return AnimationSystem.fadeSlideInWithDelay(
          child,
          delay: itemDelay,
          duration: duration,
          curve: curve,
          offset: Offset(0, offset),
        );

      case AnimationType.fadeSlideFromTop:
        return AnimationSystem.fadeSlideInWithDelay(
          child,
          delay: itemDelay,
          duration: duration,
          curve: curve,
          offset: Offset(0, -offset),
        );

      case AnimationType.fadeSlideFromRight:
        return AnimationSystem.fadeSlideInWithDelay(
          child,
          delay: itemDelay,
          duration: duration,
          curve: curve,
          offset: Offset(offset, 0),
        );

      case AnimationType.fadeSlideFromLeft:
        return AnimationSystem.fadeSlideInWithDelay(
          child,
          delay: itemDelay,
          duration: duration,
          curve: curve,
          offset: Offset(-offset, 0),
        );

      case AnimationType.scale:
        return _ScaleAnimation(
          delay: itemDelay,
          duration: duration,
          curve: curve,
          child: child,
        );

      case AnimationType.none:
        return child;
    }
  }
}

/// أنواع الرسوم المتحركة المتاحة
enum AnimationType {
  fadeIn,
  fadeSlideFromBottom,
  fadeSlideFromTop,
  fadeSlideFromRight,
  fadeSlideFromLeft,
  scale,
  none,
}

/// ويدجت للرسوم المتحركة بتأثير التكبير
class _ScaleAnimation extends StatefulWidget {

  const _ScaleAnimation({
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeOut,
  });
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Curve curve;

  @override
  State<_ScaleAnimation> createState() => _ScaleAnimationState();
}

class _ScaleAnimationState extends State<_ScaleAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
