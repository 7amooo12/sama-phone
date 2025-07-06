import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../widgets/common/product_card_zoom_overlay.dart';

/// Helper class for showing product card zoom functionality across the application
class ProductCardZoomHelper {
  /// Show zoom overlay for any product card
  static Future<void> showProductZoom({
    required BuildContext context,
    required ProductModel product,
    required Widget originalCard,
    String currencySymbol = 'جنيه',
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    bool showAdminButtons = false,
  }) async {
    // Prevent multiple overlays
    if (ModalRoute.of(context)?.isCurrent != true) return;

    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ProductCardZoomOverlay(
            product: product,
            originalCard: originalCard,
            currencySymbol: currencySymbol,
            onEdit: onEdit,
            onDelete: onDelete,
            showAdminButtons: showAdminButtons,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  /// Determine if admin buttons should be shown based on card type
  static bool shouldShowAdminButtons(String userRole) {
    return userRole == 'admin' || userRole == 'owner';
  }

  /// Get appropriate currency symbol based on user preferences
  static String getCurrencySymbol() {
    return 'جنيه'; // Egyptian Pound
  }
}

/// Extension to add zoom functionality to any widget
extension ProductCardZoomExtension on Widget {
  /// Wrap any widget with zoom functionality
  Widget withProductZoom({
    required BuildContext context,
    required ProductModel product,
    String currencySymbol = 'جنيه',
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    bool showAdminButtons = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: () {
        // Call original onTap if provided
        onTap?.call();
        
        // Show zoom overlay
        ProductCardZoomHelper.showProductZoom(
          context: context,
          product: product,
          originalCard: this,
          currencySymbol: currencySymbol,
          onEdit: onEdit,
          onDelete: onDelete,
          showAdminButtons: showAdminButtons,
        );
      },
      child: this,
    );
  }
}
