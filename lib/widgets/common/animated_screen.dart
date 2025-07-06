import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/animation_system.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';

/// شاشة متحركة احترافية
/// توفر هذه الشاشة تأثيرات حركية متعددة وخيارات تخصيص متقدمة
class AnimatedScreen extends StatefulWidget {

  const AnimatedScreen({
    super.key,
    required this.child,
    this.title = '',
    this.actions,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.showAppBar = true,
    this.showDrawer = true,
    this.isLoading = false,
    this.backgroundColor,
    this.loadingWidget,
    this.animationType = AnimationType.fadeIn,
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeOut,
    this.safeArea = true,
    this.padding = EdgeInsets.zero,
    this.leading,
    this.centerTitle = true,
    this.bottom,
    this.elevation,
    this.appBarBackgroundColor,
    this.appBarForegroundColor,
    this.extendBodyBehindAppBar = false,
    this.extendBody = false,
    this.currentRoute,
    this.drawer,
    this.endDrawer,
    this.scaffoldKey,
  });
  final Widget child;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final bool showAppBar;
  final bool showDrawer;
  final bool isLoading;
  final Color? backgroundColor;
  final Widget? loadingWidget;
  final AnimationType animationType;
  final Duration animationDuration;
  final Curve animationCurve;
  final bool safeArea;
  final EdgeInsetsGeometry padding;
  final Widget? leading;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;
  final double? elevation;
  final Color? appBarBackgroundColor;
  final Color? appBarForegroundColor;
  final bool extendBodyBehindAppBar;
  final bool extendBody;
  final String? currentRoute;
  final Widget? drawer;
  final Widget? endDrawer;
  final GlobalKey<ScaffoldState>? scaffoldKey;

  @override
  State<AnimatedScreen> createState() => _AnimatedScreenState();
}

class _AnimatedScreenState extends State<AnimatedScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.animationCurve,
    ));

    _slideAnimation = Tween<Offset>(
      begin: _getInitialOffset(),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.animationCurve,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.animationCurve,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _getInitialOffset() {
    switch (widget.animationType) {
      case AnimationType.fadeSlideFromBottom:
        return const Offset(0, 0.1);
      case AnimationType.fadeSlideFromTop:
        return const Offset(0, -0.1);
      case AnimationType.fadeSlideFromRight:
        return const Offset(0.1, 0);
      case AnimationType.fadeSlideFromLeft:
        return const Offset(-0.1, 0);
      default:
        return Offset.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      key: widget.scaffoldKey,
      backgroundColor: widget.backgroundColor ?? theme.scaffoldBackgroundColor,
      appBar: widget.showAppBar
          ? PreferredSize(
              preferredSize: Size.fromHeight(widget.bottom != null ? 104 : 60),
              child: CustomAppBar(
                title: widget.title,
                actions: widget.actions,
                centerTitle: widget.centerTitle,
                backgroundColor: widget.appBarBackgroundColor,
                foregroundColor: widget.appBarForegroundColor,
                leading: widget.leading ?? (widget.showDrawer
                    ? IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () => widget.scaffoldKey?.currentState?.openDrawer(),
                      )
                    : null),
                bottom: widget.bottom,
                elevation: widget.elevation ?? 0,
              ),
            )
          : null,
      drawer: widget.showDrawer
          ? widget.drawer ?? MainDrawer(
              currentRoute: widget.currentRoute,
              onMenuPressed: () => widget.scaffoldKey?.currentState?.openDrawer(),
            )
          : null,
      endDrawer: widget.endDrawer,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              Widget animatedChild;

              switch (widget.animationType) {
                case AnimationType.fadeIn:
                  animatedChild = FadeTransition(
                    opacity: _opacityAnimation,
                    child: child,
                  );
                  break;

                case AnimationType.fadeSlideFromBottom:
                case AnimationType.fadeSlideFromTop:
                case AnimationType.fadeSlideFromRight:
                case AnimationType.fadeSlideFromLeft:
                  animatedChild = FadeTransition(
                    opacity: _opacityAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: child,
                    ),
                  );
                  break;

                case AnimationType.scale:
                  animatedChild = FadeTransition(
                    opacity: _opacityAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: child,
                    ),
                  );
                  break;

                case AnimationType.none:
                default:
                  animatedChild = child!;
                  break;
              }

              return animatedChild;
            },
            child: widget.safeArea
                ? SafeArea(
                    child: Padding(
                      padding: widget.padding,
                      child: widget.child,
                    ),
                  )
                : Padding(
                    padding: widget.padding,
                    child: widget.child,
                  ),
          ),

          if (widget.isLoading)
            widget.loadingWidget ?? const CustomLoader(),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
      bottomNavigationBar: widget.bottomNavigationBar,
      extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
      extendBody: widget.extendBody,
    );
  }
}

/// شاشة متحركة مع خلفية متدرجة
class GradientAnimatedScreen extends StatelessWidget {

  const GradientAnimatedScreen({
    super.key,
    required this.child,
    required this.gradientColors,
    this.title = '',
    this.actions,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.showAppBar = true,
    this.showDrawer = true,
    this.isLoading = false,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.loadingWidget,
    this.animationType = AnimationType.fadeIn,
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeOut,
    this.safeArea = true,
    this.padding = EdgeInsets.zero,
    this.leading,
    this.centerTitle = true,
    this.bottom,
    this.elevation,
    this.appBarBackgroundColor,
    this.appBarForegroundColor,
    this.currentRoute,
    this.scaffoldKey,
  });
  final Widget child;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final bool showAppBar;
  final bool showDrawer;
  final bool isLoading;
  final List<Color> gradientColors;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final Widget? loadingWidget;
  final AnimationType animationType;
  final Duration animationDuration;
  final Curve animationCurve;
  final bool safeArea;
  final EdgeInsetsGeometry padding;
  final Widget? leading;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;
  final double? elevation;
  final Color? appBarBackgroundColor;
  final Color? appBarForegroundColor;
  final String? currentRoute;
  final GlobalKey<ScaffoldState>? scaffoldKey;

  @override
  Widget build(BuildContext context) {
    return AnimatedScreen(
      title: title,
      actions: actions,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      showAppBar: showAppBar,
      showDrawer: showDrawer,
      isLoading: isLoading,
      loadingWidget: loadingWidget,
      animationType: animationType,
      animationDuration: animationDuration,
      animationCurve: animationCurve,
      safeArea: safeArea,
      padding: padding,
      leading: leading,
      centerTitle: centerTitle,
      bottom: bottom,
      elevation: elevation,
      appBarBackgroundColor: appBarBackgroundColor,
      appBarForegroundColor: appBarForegroundColor,
      currentRoute: currentRoute,
      scaffoldKey: scaffoldKey,
      extendBodyBehindAppBar: true,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: begin,
            end: end,
          ),
        ),
        child: child,
      ),
    );
  }
}
