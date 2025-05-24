import 'package:flutter/material.dart';

/// Utility class for showing snackbar notifications across the app
class ShowSnackbar {
  /// Show a snackbar with a message
  /// 
  /// [context] - BuildContext to show the snackbar
  /// [message] - Message to display
  /// [isError] - Whether this is an error message (changes color)
  /// [duration] - How long to show the snackbar
  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Dismiss any existing snackbars
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    // Show new snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
} 