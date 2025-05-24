import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

class ElegantSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final Function(String)? onChanged;
  final Function()? onClear;
  final String hintText;
  final IconData? prefixIcon;
  final Widget? suffixWidget;
  final bool autofocus;
  final bool autoFillFromClipboard;
  final bool showAnimation;
  final double elevation;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final Color? fillColor;
  final Color? hintColor;
  final Color? iconColor;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry contentPadding;

  const ElegantSearchBar({
    Key? key,
    required this.controller,
    this.onChanged,
    this.onClear,
    this.hintText = 'بحث...',
    this.prefixIcon = Icons.search_rounded,
    this.suffixWidget,
    this.autofocus = false,
    this.autoFillFromClipboard = false,
    this.showAnimation = true,
    this.elevation = 3.0,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.fillColor,
    this.hintColor,
    this.iconColor,
    this.onTap,
    this.borderRadius,
    this.margin,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  }) : super(key: key);

  @override
  State<ElegantSearchBar> createState() => _ElegantSearchBarState();
}

class _ElegantSearchBarState extends State<ElegantSearchBar> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  bool _isFocused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.showAnimation) {
      _animationController.repeat(reverse: true);
    }

    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });

    if (widget.autoFillFromClipboard && widget.controller.text.isEmpty) {
      _tryPasteFromClipboard();
    }
  }

  Future<void> _tryPasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text;
    
    if (text != null && text.isNotEmpty && mounted) {
      widget.controller.text = text;
      if (widget.onChanged != null) {
        widget.onChanged!(text);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    
    final Color backgroundColor = widget.backgroundColor ?? theme.cardColor;
    final Color textColor = widget.textColor ?? theme.textTheme.bodyMedium?.color ?? Colors.black87;
    final Color borderColor = widget.borderColor ?? theme.primaryColor;
    final Color fillColor = widget.fillColor ?? backgroundColor;
    final Color hintColor = widget.hintColor ?? theme.hintColor;
    final Color iconColor = widget.iconColor ?? theme.primaryColor;
    
    final BorderRadius borderRadius = widget.borderRadius ?? BorderRadius.circular(15);

    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isFocused && widget.showAnimation ? _pulseAnimation.value : 1.0,
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: widget.elevation,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Color(0x05000000),
                blurRadius: widget.elevation * 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  borderRadius: borderRadius,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: TextStyle(color: hintColor, fontWeight: FontWeight.w400),
                      prefixIcon: Icon(widget.prefixIcon, color: iconColor, size: 22),
                      suffixIcon: widget.controller.text.isNotEmpty
                          ? widget.suffixWidget ?? IconButton(
                              icon: Icon(Icons.clear, color: iconColor.withOpacity(0.7), size: 20),
                              onPressed: () {
                                widget.controller.clear();
                                if (widget.onClear != null) {
                                  widget.onClear!();
                                } else if (widget.onChanged != null) {
                                  widget.onChanged!('');
                                }
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: fillColor,
                      contentPadding: widget.contentPadding,
                      border: OutlineInputBorder(
                        borderRadius: borderRadius,
                        borderSide: const BorderSide(width: 0, color: Colors.transparent),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: borderRadius,
                        borderSide: BorderSide(width: 1.5, color: borderColor.withOpacity(0.15)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: borderRadius,
                        borderSide: BorderSide(width: 2, color: borderColor.withOpacity(0.8)),
                      ),
                    ),
                    onChanged: widget.onChanged,
                    textAlignVertical: TextAlignVertical.center,
                    textInputAction: TextInputAction.search,
                    autofocus: widget.autofocus,
                    keyboardType: TextInputType.text,
                    cursorColor: borderColor,
                    cursorWidth: 1.5,
                    cursorRadius: const Radius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// A fancier search bar with advanced styling
class GlassSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final Function(String)? onChanged;
  final Function()? onClear;
  final String hintText;
  final Color accentColor;
  final bool autofocus;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const GlassSearchBar({
    Key? key,
    required this.controller,
    this.onChanged,
    this.onClear,
    this.hintText = 'بحث...',
    this.accentColor = const Color(0xFF6C63FF),
    this.autofocus = false,
    this.margin,
    this.onTap,
  }) : super(key: key);

  @override
  State<GlassSearchBar> createState() => _GlassSearchBarState();
}

class _GlassSearchBarState extends State<GlassSearchBar> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isFocused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
      
      if (_isFocused) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    
    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: _isFocused 
                    ? widget.accentColor 
                    : Colors.white.withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withOpacity(_isFocused ? 0.15 : 0),
                  blurRadius: 12,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background animations when focused
                AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return Positioned.fill(
                      child: Opacity(
                        opacity: _fadeAnimation.value * 0.3,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                widget.accentColor.withOpacity(0.2),
                                Colors.transparent,
                                widget.accentColor.withOpacity(0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                // Search field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded, 
                        color: _isFocused 
                            ? widget.accentColor 
                            : theme.colorScheme.onSurface.withOpacity(0.7),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: widget.controller,
                          focusNode: _focusNode,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: widget.hintText,
                            hintStyle: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                            border: InputBorder.none,
                          ),
                          onChanged: widget.onChanged,
                          cursorColor: widget.accentColor,
                          cursorWidth: 1.5,
                          cursorRadius: const Radius.circular(4),
                          autofocus: widget.autofocus,
                        ),
                      ),
                      if (widget.controller.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            widget.controller.clear();
                            if (widget.onClear != null) {
                              widget.onClear!();
                            } else if (widget.onChanged != null) {
                              widget.onChanged!('');
                            }
                          },
                          child: AnimatedOpacity(
                            opacity: widget.controller.text.isNotEmpty ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 