import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/animation_system.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/widgets/common/animated_button.dart';

/// نظام الحوارات المتحركة
/// يوفر هذا الملف مجموعة من الحوارات المتحركة التي يمكن استخدامها في التطبيق
class AnimatedDialogs {
  /// عرض حوار متحرك بسيط
  static Future<T?> showSimpleDialog<T>({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool barrierDismissible = true,
    DialogAnimationType animationType = DialogAnimationType.scale,
    Duration animationDuration = const Duration(milliseconds: 300),
    Curve animationCurve = Curves.easeOut,
    Color? backgroundColor,
    Color? titleColor,
    Color? messageColor,
    Color? confirmColor,
    Color? cancelColor,
    Widget? icon,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: animationDuration,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return _buildDialogAnimation(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
          animationType: animationType,
          curve: animationCurve,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        final theme = Theme.of(context);
        
        return Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: backgroundColor ?? theme.cardColor,
              borderRadius: StyleSystem.borderRadiusLarge,
              boxShadow: StyleSystem.shadowLarge,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  icon,
                  const SizedBox(height: 16),
                ],
                Text(
                  title,
                  style: StyleSystem.headlineMedium.copyWith(
                    color: titleColor ?? theme.textTheme.headlineMedium?.color,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: StyleSystem.bodyMedium.copyWith(
                    color: messageColor ?? theme.textTheme.bodyMedium?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (cancelText != null)
                      Expanded(
                        child: AnimatedButton(
                          text: cancelText,
                          onPressed: () {
                            Navigator.of(context).pop();
                            if (onCancel != null) onCancel();
                          },
                          style: StyleSystem.outlinedButtonStyle.copyWith(
                            foregroundColor: MaterialStateProperty.all(
                              cancelColor ?? StyleSystem.neutralMedium,
                            ),
                          ),
                        ),
                      ),
                    if (cancelText != null && confirmText != null)
                      const SizedBox(width: 16),
                    if (confirmText != null)
                      Expanded(
                        child: AnimatedButton(
                          text: confirmText,
                          onPressed: () {
                            Navigator.of(context).pop(true);
                            if (onConfirm != null) onConfirm();
                          },
                          backgroundColor: confirmColor ?? StyleSystem.primaryColor,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  /// عرض حوار متحرك للتأكيد
  static Future<bool?> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'تأكيد',
    String cancelText = 'إلغاء',
    bool barrierDismissible = true,
    DialogAnimationType animationType = DialogAnimationType.scale,
    Duration animationDuration = const Duration(milliseconds: 300),
    Curve animationCurve = Curves.easeOut,
    Color? backgroundColor,
    Color? titleColor,
    Color? messageColor,
    Color confirmColor = StyleSystem.primaryColor,
    Color cancelColor = StyleSystem.neutralMedium,
    Widget? icon,
  }) {
    return showSimpleDialog<bool>(
      context: context,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      barrierDismissible: barrierDismissible,
      animationType: animationType,
      animationDuration: animationDuration,
      animationCurve: animationCurve,
      backgroundColor: backgroundColor,
      titleColor: titleColor,
      messageColor: messageColor,
      confirmColor: confirmColor,
      cancelColor: cancelColor,
      icon: icon,
    );
  }
  
  /// عرض حوار متحرك للنجاح
  static Future<void> showSuccessDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'حسناً',
    VoidCallback? onConfirm,
    bool barrierDismissible = true,
    DialogAnimationType animationType = DialogAnimationType.scale,
    Duration animationDuration = const Duration(milliseconds: 300),
    Curve animationCurve = Curves.easeOut,
  }) {
    return showSimpleDialog(
      context: context,
      title: title,
      message: message,
      confirmText: confirmText,
      onConfirm: onConfirm,
      barrierDismissible: barrierDismissible,
      animationType: animationType,
      animationDuration: animationDuration,
      animationCurve: animationCurve,
      confirmColor: StyleSystem.successColor,
      icon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: StyleSystem.successColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.check_circle,
          color: StyleSystem.successColor,
          size: 40,
        ),
      ),
    );
  }
  
  /// عرض حوار متحرك للخطأ
  static Future<void> showErrorDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'حسناً',
    VoidCallback? onConfirm,
    bool barrierDismissible = true,
    DialogAnimationType animationType = DialogAnimationType.scale,
    Duration animationDuration = const Duration(milliseconds: 300),
    Curve animationCurve = Curves.easeOut,
  }) {
    return showSimpleDialog(
      context: context,
      title: title,
      message: message,
      confirmText: confirmText,
      onConfirm: onConfirm,
      barrierDismissible: barrierDismissible,
      animationType: animationType,
      animationDuration: animationDuration,
      animationCurve: animationCurve,
      confirmColor: StyleSystem.errorColor,
      icon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: StyleSystem.errorColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.error,
          color: StyleSystem.errorColor,
          size: 40,
        ),
      ),
    );
  }
  
  /// عرض حوار متحرك للتحذير
  static Future<bool?> showWarningDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'تأكيد',
    String cancelText = 'إلغاء',
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool barrierDismissible = true,
    DialogAnimationType animationType = DialogAnimationType.scale,
    Duration animationDuration = const Duration(milliseconds: 300),
    Curve animationCurve = Curves.easeOut,
  }) {
    return showSimpleDialog<bool>(
      context: context,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      onConfirm: onConfirm,
      onCancel: onCancel,
      barrierDismissible: barrierDismissible,
      animationType: animationType,
      animationDuration: animationDuration,
      animationCurve: animationCurve,
      confirmColor: StyleSystem.warningColor,
      icon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: StyleSystem.warningColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.warning,
          color: StyleSystem.warningColor,
          size: 40,
        ),
      ),
    );
  }
  
  /// بناء الرسوم المتحركة للحوار
  static Widget _buildDialogAnimation({
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
    required DialogAnimationType animationType,
    required Curve curve,
  }) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: curve,
    );
    
    switch (animationType) {
      case DialogAnimationType.scale:
        return ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      
      case DialogAnimationType.slideFromTop:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.5),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      
      case DialogAnimationType.slideFromBottom:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.5),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      
      case DialogAnimationType.slideFromLeft:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-0.5, 0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      
      case DialogAnimationType.slideFromRight:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.5, 0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      
      case DialogAnimationType.fade:
        return FadeTransition(
          opacity: curvedAnimation,
          child: child,
        );
      
      case DialogAnimationType.rotation:
        return RotationTransition(
          turns: Tween<double>(begin: 0.1, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
    }
  }
}

/// أنواع الرسوم المتحركة للحوارات
enum DialogAnimationType {
  scale,
  slideFromTop,
  slideFromBottom,
  slideFromLeft,
  slideFromRight,
  fade,
  rotation,
}
