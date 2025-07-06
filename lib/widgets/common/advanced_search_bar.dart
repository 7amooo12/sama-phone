import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';

class AdvancedSearchBar extends StatefulWidget {

  const AdvancedSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    this.hintText = 'البحث...',
    this.autofocus = false,
    this.accentColor = const Color(0xFF6C63FF),
    this.borderRadius,
    this.margin,
    this.showClearButton = true,
    this.trailing,
    this.showSearchAnimation = true,
    this.debounceTime = const Duration(milliseconds: 300),
  });
  final TextEditingController controller;
  final Function(String) onChanged;
  final Function(String) onSubmitted;
  final String hintText;
  final bool autofocus;
  final Color accentColor;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? margin;
  final bool showClearButton;
  final Widget? trailing;
  final bool showSearchAnimation;
  final Duration debounceTime;

  @override
  State<AdvancedSearchBar> createState() => _AdvancedSearchBarState();
}

class _AdvancedSearchBarState extends State<AdvancedSearchBar> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  bool _isFocused = false;
  final FocusNode _focusNode = FocusNode();
  
  // For search animation and live search
  bool _isSearching = false;
  String _lastQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // Setup animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Add listener to animation controller
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _animationController.forward();
      }
    });

    // Setup pulse animation
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Add focus listener
    _focusNode.addListener(_handleFocusChange);
    
    // Add listener to text controller
    widget.controller.addListener(_handleTextChange);
  }

  void _handleFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
    
    if (_isFocused && widget.showSearchAnimation) {
      _animationController.forward();
    } else {
      _animationController.reset();
    }
  }
  
  void _handleTextChange() {
    final query = widget.controller.text;
    
    if (query != _lastQuery) {
      setState(() {
        _isSearching = query.isNotEmpty;
        _lastQuery = query;
      });
      
      // Cancel previous timer
      _debounceTimer?.cancel();
      
      // Set new timer for live search
      _debounceTimer = Timer(widget.debounceTime, () {
        // Call onChanged only after debounce time
        widget.onChanged(query);
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    widget.controller.removeListener(_handleTextChange);
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(25);
    
    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isFocused && widget.showSearchAnimation ? _pulseAnimation.value : 1.0,
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withOpacity(_isFocused ? 0.15 : 0.05),
                blurRadius: _isFocused ? 12 : 5,
                spreadRadius: _isFocused ? 2 : 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: borderRadius,
                  border: Border.all(
                    color: _isFocused 
                        ? widget.accentColor
                        : Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 12),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return ScaleTransition(scale: animation, child: child);
                        },
                        child: _isSearching && _isFocused
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                key: const ValueKey('searching'),
                                child: _buildSearchingAnimation(),
                              )
                            : Icon(
                                Icons.search_rounded,
                                color: _isFocused 
                                    ? widget.accentColor 
                                    : theme.iconTheme.color?.withOpacity(0.7),
                                key: const ValueKey('search-icon'),
                              ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focusNode,
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: widget.hintText,
                          hintStyle: TextStyle(
                            color: theme.hintColor,
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.only(right: 16, top: 14, bottom: 14),
                        ),
                        onSubmitted: widget.onSubmitted,
                        textAlignVertical: TextAlignVertical.center,
                        textInputAction: TextInputAction.search,
                        autofocus: widget.autofocus,
                        keyboardType: TextInputType.text,
                        cursorColor: widget.accentColor,
                        cursorWidth: 1.5,
                        cursorRadius: const Radius.circular(4),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _isSearching && widget.showClearButton
                          ? IconButton(
                              key: const ValueKey('clear-button'),
                              icon: Icon(
                                Icons.close_rounded,
                                color: theme.iconTheme.color?.withOpacity(0.7),
                                size: 20,
                              ),
                              onPressed: () {
                                widget.controller.clear();
                                widget.onChanged('');
                                widget.onSubmitted('');
                              },
                            )
                          : widget.trailing != null
                              ? Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: widget.trailing,
                                )
                              : const SizedBox(width: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSearchingAnimation() {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(widget.accentColor),
          ),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.accentColor.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
} 