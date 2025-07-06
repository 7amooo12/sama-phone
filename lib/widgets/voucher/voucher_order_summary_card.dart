import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../utils/accountant_theme_config.dart';
import '../../models/client_order_model.dart';

/// Compact voucher order summary card for dashboard and list views
/// Shows key voucher information in a condensed format
class VoucherOrderSummaryCard extends StatelessWidget {
  const VoucherOrderSummaryCard({
    super.key,
    required this.order,
    this.onTap,
    this.showAnimation = true,
  });

  final ClientOrder order;
  final VoidCallback? onTap;
  final bool showAnimation;

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'ar_EG',
    symbol: 'ج.م',
    decimalDigits: 2,
  );

  /// Check if order is a voucher order
  bool get isVoucherOrder {
    final metadata = order.metadata;
    return metadata != null && metadata['order_type'] == 'voucher_order';
  }

  /// Get voucher information from order metadata
  Map<String, dynamic>? get voucherInfo {
    if (!isVoucherOrder) return null;
    return order.metadata;
  }

  /// Get pricing details from voucher order
  Map<String, dynamic>? get pricingDetails {
    final voucher = voucherInfo;
    if (voucher == null) return null;
    return voucher['pricing_details'] as Map<String, dynamic>?;
  }

  @override
  Widget build(BuildContext context) {
    if (!isVoucherOrder) {
      return const SizedBox.shrink();
    }

    final voucher = voucherInfo!;
    final pricing = pricingDetails;
    
    final voucherName = voucher['voucher_name'] as String? ?? 'قسيمة';
    final discountPercentage = voucher['discount_percentage'] as num? ?? 0;
    final totalSavings = pricing?['total_savings'] as num? ?? 0;
    final originalTotal = pricing?['original_total'] as num? ?? 0;
    final discountedTotal = pricing?['discounted_total'] as num? ?? 0;

    Widget card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
        gradient: AccountantThemeConfig.greenGradient,
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with voucher icon and name
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.local_offer,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'طلب بقسيمة خصم',
                            style: AccountantThemeConfig.bodySmall.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            voucherName,
                            style: AccountantThemeConfig.bodyLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$discountPercentage%',
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Pricing summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'السعر الأصلي:',
                            style: AccountantThemeConfig.bodySmall.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            _currencyFormat.format(originalTotal),
                            style: AccountantThemeConfig.bodySmall.copyWith(
                              color: Colors.white70,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'المبلغ النهائي:',
                            style: AccountantThemeConfig.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _currencyFormat.format(discountedTotal),
                            style: AccountantThemeConfig.bodyLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Savings highlight
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.savings,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'وفرت ${_currencyFormat.format(totalSavings)}',
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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

    if (showAnimation) {
      return card.animate().fadeIn(delay: const Duration(milliseconds: 200)).slideX(begin: -0.3);
    }

    return card;
  }
}

/// Voucher order badge for inline display in order lists
class VoucherOrderBadge extends StatelessWidget {
  const VoucherOrderBadge({
    super.key,
    required this.order,
    this.size = VoucherBadgeSize.medium,
  });

  final ClientOrder order;
  final VoucherBadgeSize size;

  /// Check if order is a voucher order
  bool get isVoucherOrder {
    final metadata = order.metadata;
    return metadata != null && metadata['order_type'] == 'voucher_order';
  }

  @override
  Widget build(BuildContext context) {
    if (!isVoucherOrder) {
      return const SizedBox.shrink();
    }

    final voucher = order.metadata!;
    final voucherName = voucher['voucher_name'] as String? ?? 'قسيمة';
    final discountPercentage = voucher['discount_percentage'] as num? ?? 0;

    final double iconSize;
    final double fontSize;
    final EdgeInsets padding;

    switch (size) {
      case VoucherBadgeSize.small:
        iconSize = 12;
        fontSize = 10;
        padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2);
        break;
      case VoucherBadgeSize.medium:
        iconSize = 14;
        fontSize = 12;
        padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
        break;
      case VoucherBadgeSize.large:
        iconSize = 16;
        fontSize = 14;
        padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
        break;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.greenGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: size == VoucherBadgeSize.large 
            ? AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_offer,
            color: Colors.white,
            size: iconSize,
          ),
          const SizedBox(width: 4),
          Text(
            '$voucherName ($discountPercentage%)',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}

/// Voucher savings indicator for highlighting savings amount
class VoucherSavingsIndicator extends StatelessWidget {
  const VoucherSavingsIndicator({
    super.key,
    required this.order,
    this.showIcon = true,
    this.style,
  });

  final ClientOrder order;
  final bool showIcon;
  final TextStyle? style;

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'ar_EG',
    symbol: 'ج.م',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context) {
    final metadata = order.metadata;
    if (metadata == null || metadata['order_type'] != 'voucher_order') {
      return const SizedBox.shrink();
    }

    final pricingDetails = metadata['pricing_details'] as Map<String, dynamic>?;
    final totalSavings = pricingDetails?['total_savings'] as num? ?? 0;

    if (totalSavings <= 0) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIcon) ...[
          Icon(
            Icons.savings,
            color: AccountantThemeConfig.primaryGreen,
            size: 16,
          ),
          const SizedBox(width: 4),
        ],
        Text(
          'وفرت ${_currencyFormat.format(totalSavings)}',
          style: style ?? AccountantThemeConfig.bodyMedium.copyWith(
            color: AccountantThemeConfig.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Enum for voucher badge sizes
enum VoucherBadgeSize {
  small,
  medium,
  large,
}
