import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../utils/accountant_theme_config.dart';
import '../../models/client_order_model.dart';

/// Widget for displaying voucher order status with enhanced visual indicators
/// Shows voucher usage status, approval state, and processing information
class VoucherOrderStatusWidget extends StatelessWidget {
  const VoucherOrderStatusWidget({
    super.key,
    required this.order,
    this.showTimeline = false,
    this.isCompact = false,
  });

  final ClientOrder order;
  final bool showTimeline;
  final bool isCompact;

  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'ar');

  /// Check if order is a voucher order
  bool get isVoucherOrder {
    final metadata = order.metadata;
    return metadata != null && metadata['order_type'] == 'voucher_order';
  }

  /// Get voucher usage information
  Map<String, dynamic>? get voucherUsage {
    if (!isVoucherOrder) return null;
    final metadata = order.metadata!;
    return metadata['voucher_usage'] as Map<String, dynamic>?;
  }

  @override
  Widget build(BuildContext context) {
    if (!isVoucherOrder) {
      return const SizedBox.shrink();
    }

    if (isCompact) {
      return _buildCompactStatus();
    }

    return _buildFullStatus();
  }

  /// Build compact status indicator
  Widget _buildCompactStatus() {
    final status = _getVoucherOrderStatus();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: status.color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status.icon,
            color: status.color,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: status.color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Build full status display with timeline
  Widget _buildFullStatus() {
    final status = _getVoucherOrderStatus();
    final usage = voucherUsage;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
        border: AccountantThemeConfig.glowBorder(status.color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  status.icon,
                  color: status.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حالة طلب القسيمة',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status.label,
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        color: status.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (showTimeline && usage != null) ...[
            const SizedBox(height: 16),
            _buildVoucherTimeline(usage),
          ],

          const SizedBox(height: 12),
          _buildStatusDescription(status),
        ],
      ),
    ).animate().fadeIn(delay: const Duration(milliseconds: 300));
  }

  /// Build voucher timeline
  Widget _buildVoucherTimeline(Map<String, dynamic> usage) {
    final usedAt = usage['used_at'] as String?;
    final usageType = usage['usage_type'] as String?;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تاريخ استخدام القسيمة',
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.primaryGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatUsageType(usageType ?? 'order_creation'),
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (usedAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _formatDateTime(usedAt),
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build status description
  Widget _buildStatusDescription(VoucherOrderStatusInfo status) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: status.color.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: status.color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status.description,
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: status.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Get voucher order status information
  VoucherOrderStatusInfo _getVoucherOrderStatus() {
    // Check if voucher was used successfully
    final usage = voucherUsage;
    final hasValidUsage = usage != null && usage['used_at'] != null;

    // Determine status based on order state and voucher usage
    switch (order.status) {
      case OrderStatus.pending:
        if (hasValidUsage) {
          return VoucherOrderStatusInfo(
            label: 'قسيمة مستخدمة - في انتظار المعالجة',
            description: 'تم استخدام القسيمة بنجاح والطلب في انتظار المراجعة والموافقة',
            icon: Icons.pending_actions,
            color: AccountantThemeConfig.warningOrange,
          );
        } else {
          return VoucherOrderStatusInfo(
            label: 'خطأ في استخدام القسيمة',
            description: 'حدث خطأ أثناء استخدام القسيمة، يرجى المراجعة',
            icon: Icons.error_outline,
            color: AccountantThemeConfig.dangerRed,
          );
        }

      case OrderStatus.confirmed:
        return VoucherOrderStatusInfo(
          label: 'قسيمة مستخدمة - طلب مؤكد',
          description: 'تم استخدام القسيمة بنجاح وتأكيد الطلب',
          icon: Icons.check_circle,
          color: AccountantThemeConfig.primaryGreen,
        );

      case OrderStatus.processing:
        return VoucherOrderStatusInfo(
          label: 'قسيمة مستخدمة - قيد التجهيز',
          description: 'الطلب قيد التجهيز والقسيمة مطبقة بنجاح',
          icon: Icons.build_circle,
          color: AccountantThemeConfig.accentBlue,
        );

      case OrderStatus.shipped:
        return VoucherOrderStatusInfo(
          label: 'قسيمة مستخدمة - تم الشحن',
          description: 'تم شحن الطلب مع تطبيق خصم القسيمة',
          icon: Icons.local_shipping,
          color: AccountantThemeConfig.accentBlue,
        );

      case OrderStatus.delivered:
        return VoucherOrderStatusInfo(
          label: 'قسيمة مستخدمة - تم التسليم',
          description: 'تم تسليم الطلب بنجاح مع تطبيق خصم القسيمة',
          icon: Icons.done_all,
          color: AccountantThemeConfig.primaryGreen,
        );

      case OrderStatus.cancelled:
        return VoucherOrderStatusInfo(
          label: 'طلب ملغي - قسيمة متاحة',
          description: 'تم إلغاء الطلب وإعادة تفعيل القسيمة للاستخدام',
          icon: Icons.cancel,
          color: AccountantThemeConfig.dangerRed,
        );

      default:
        return VoucherOrderStatusInfo(
          label: 'حالة غير معروفة',
          description: 'حالة الطلب غير محددة',
          icon: Icons.help_outline,
          color: Colors.grey,
        );
    }
  }

  /// Format usage type for display
  String _formatUsageType(String usageType) {
    switch (usageType) {
      case 'order_creation':
        return 'استخدمت عند إنشاء الطلب';
      case 'manual_application':
        return 'تم تطبيقها يدوياً';
      default:
        return 'استخدام القسيمة';
    }
  }

  /// Format date time for display
  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return _dateFormat.format(dateTime);
    } catch (e) {
      return 'غير محدد';
    }
  }
}

/// Information about voucher order status
class VoucherOrderStatusInfo {
  const VoucherOrderStatusInfo({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String label;
  final String description;
  final IconData icon;
  final Color color;
}
