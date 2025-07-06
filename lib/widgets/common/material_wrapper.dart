import 'package:flutter/material.dart';

/// A wrapper widget that ensures all child widgets have a Material ancestor
/// This helps prevent "No Material widget found" errors
class MaterialWrapper extends StatelessWidget {
  
  const MaterialWrapper({
    super.key,
    required this.child,
    this.color,
  });
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Colors.transparent,
      child: child,
    );
  }
} 