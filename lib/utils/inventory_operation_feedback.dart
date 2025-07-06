import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartbiztracker_new/models/global_inventory_models.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// FIXED: Enhanced inventory operation feedback utility
/// Provides accurate success/failure feedback based on actual operation results
class InventoryOperationFeedback {
  
  /// Determine operation result type based on deduction result
  static OperationResultType determineResultType(InventoryDeductionResult result) {
    // Check for complete success
    if (result.success && result.isCompleteDeduction && result.errors.isEmpty) {
      return OperationResultType.completeSuccess;
    }
    
    // Check for successful deduction with warnings
    if (result.success && result.isCompleteDeduction && result.errors.isNotEmpty) {
      final hasCriticalErrors = result.errors.any((error) => _isCriticalError(error));
      return hasCriticalErrors ? OperationResultType.successWithWarnings : OperationResultType.completeSuccess;
    }
    
    // Check for partial success
    if (result.totalDeductedQuantity > 0 && result.successfulWarehousesCount > 0) {
      return result.totalDeductedQuantity >= result.totalRequestedQuantity 
          ? OperationResultType.successWithWarnings 
          : OperationResultType.partialSuccess;
    }
    
    // Complete failure
    return OperationResultType.completeFailure;
  }
  
  /// Check if an error is critical
  static bool _isCriticalError(String error) {
    final errorLower = error.toLowerCase();
    return errorLower.contains('فشل في الخصم') ||
           errorLower.contains('خطأ في قاعدة البيانات') ||
           errorLower.contains('المصادقة') ||
           errorLower.contains('الصلاحيات') ||
           errorLower.contains('connection') ||
           errorLower.contains('network') ||
           errorLower.contains('خطأ حرج');
  }
  
  /// Generate appropriate feedback message
  static OperationFeedback generateFeedback(
    InventoryDeductionResult result, 
    String productName,
  ) {
    final resultType = determineResultType(result);
    
    switch (resultType) {
      case OperationResultType.completeSuccess:
        return OperationFeedback(
          type: resultType,
          title: 'تم الخصم بنجاح ✅',
          message: 'تم خصم ${result.totalDeductedQuantity} قطعة من $productName بالكامل',
          details: 'من ${result.successfulWarehousesCount} مخزن',
          color: AccountantThemeConfig.primaryGreen,
          icon: Icons.check_circle,
          duration: const Duration(seconds: 3),
        );
        
      case OperationResultType.successWithWarnings:
        return OperationFeedback(
          type: resultType,
          title: 'تم الخصم مع تحذيرات ⚠️',
          message: 'تم خصم ${result.totalDeductedQuantity} من ${result.totalRequestedQuantity} قطعة من $productName',
          details: 'مع ${result.errors.length} تحذير',
          color: AccountantThemeConfig.warningOrange,
          icon: Icons.warning,
          duration: const Duration(seconds: 4),
        );
        
      case OperationResultType.partialSuccess:
        return OperationFeedback(
          type: resultType,
          title: 'خصم جزئي ⚠️',
          message: 'تم خصم ${result.totalDeductedQuantity} من ${result.totalRequestedQuantity} قطعة من $productName',
          details: 'تحقق من توفر المخزون للكمية المتبقية',
          color: Colors.orange.shade600,
          icon: Icons.info,
          duration: const Duration(seconds: 5),
        );
        
      case OperationResultType.completeFailure:
        return OperationFeedback(
          type: resultType,
          title: 'فشل في الخصم ❌',
          message: 'لم يتم خصم أي كمية من $productName',
          details: result.errors.isNotEmpty ? result.errors.first : 'خطأ غير محدد',
          color: Colors.red,
          icon: Icons.error,
          duration: const Duration(seconds: 6),
        );
    }
  }
  
  /// Show feedback as SnackBar
  static void showFeedback(
    BuildContext context,
    InventoryDeductionResult result,
    String productName,
  ) {
    final feedback = generateFeedback(result, productName);
    
    // Log the feedback for debugging
    AppLogger.info('📢 عرض تغذية راجعة: ${feedback.title}');
    AppLogger.info('   النوع: ${feedback.type}');
    AppLogger.info('   الرسالة: ${feedback.message}');
    if (feedback.details.isNotEmpty) {
      AppLogger.info('   التفاصيل: ${feedback.details}');
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(feedback.icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feedback.title,
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              feedback.message,
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: Colors.white,
              ),
            ),
            if (feedback.details.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                feedback.details,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
            ],
          ],
        ),
        backgroundColor: feedback.color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: feedback.duration,
      ),
    );
  }
}

/// Operation result types
enum OperationResultType {
  completeSuccess,
  successWithWarnings,
  partialSuccess,
  completeFailure,
}

/// Operation feedback data
class OperationFeedback {
  final OperationResultType type;
  final String title;
  final String message;
  final String details;
  final Color color;
  final IconData icon;
  final Duration duration;
  
  const OperationFeedback({
    required this.type,
    required this.title,
    required this.message,
    required this.details,
    required this.color,
    required this.icon,
    required this.duration,
  });
}
