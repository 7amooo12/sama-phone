import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../utils/accountant_theme_config.dart';
import '../../models/client_order_model.dart';

/// Reusable widget for displaying voucher order information
/// Shows voucher name, discount amounts, original vs discounted pricing, and savings highlights
class VoucherOrderDetailsWidget extends StatelessWidget {
  const VoucherOrderDetailsWidget({
    super.key,
    required this.order,
    this.showFullDetails = true,
    this.isCompact = false,
  });

  final ClientOrder order;
  final bool showFullDetails;
  final bool isCompact;

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

    if (isCompact) {
      return _buildCompactVoucherBadge();
    }

    return _buildFullVoucherDetails();
  }

  /// Compact voucher badge for order cards
  Widget _buildCompactVoucherBadge() {
    final voucher = voucherInfo;
    if (voucher == null) return const SizedBox.shrink();

    final voucherName = voucher['voucher_name'] as String? ?? 'قسيمة';
    final discountPercentage = voucher['discount_percentage'] as num? ?? 0;
    final totalSavings = pricingDetails?['total_savings'] as num? ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.greenGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_offer,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            '$voucherName ($discountPercentage%)',
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (totalSavings > 0) ...[
            const SizedBox(width: 4),
            Text(
              '• وفرت ${_currencyFormat.format(totalSavings)}',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Full voucher details for order details screens
  Widget _buildFullVoucherDetails() {
    final voucher = voucherInfo;
    final pricing = pricingDetails;
    if (voucher == null || pricing == null) return const SizedBox.shrink();

    final voucherName = voucher['voucher_name'] as String? ?? 'قسيمة';
    final voucherCode = voucher['voucher_code'] as String? ?? '';
    final discountPercentage = voucher['discount_percentage'] as num? ?? 0;
    final originalTotal = pricing['original_total'] as num? ?? 0;
    final discountedTotal = pricing['discounted_total'] as num? ?? 0;
    final totalSavings = pricing['total_savings'] as num? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
        gradient: AccountantThemeConfig.greenGradient,
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Voucher Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_offer,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'طلب بقسيمة خصم',
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      voucherName,
                      style: AccountantThemeConfig.headlineSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (voucherCode.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'كود: $voucherCode',
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: Colors.white70,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'خصم $discountPercentage%',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Pricing Breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildPricingRow(
                  'السعر الأصلي:',
                  _currencyFormat.format(originalTotal),
                  isOriginal: true,
                ),
                const SizedBox(height: 12),
                _buildPricingRow(
                  'الخصم المطبق:',
                  '- ${_currencyFormat.format(totalSavings)}',
                  isDiscount: true,
                ),
                const Divider(color: Colors.white24, height: 24),
                _buildPricingRow(
                  'المبلغ النهائي:',
                  _currencyFormat.format(discountedTotal),
                  isFinal: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Savings Highlight
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.savings,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'إجمالي الوفورات: ${_currencyFormat.format(totalSavings)}',
                  style: AccountantThemeConfig.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          if (showFullDetails) ...[
            const SizedBox(height: 16),
            _buildVoucherMetadata(voucher),
          ],
        ],
      ),
    ).animate().fadeIn(delay: const Duration(milliseconds: 200)).slideX(begin: -0.3);
  }

  /// Build pricing row with appropriate styling
  Widget _buildPricingRow(String label, String value, {bool isOriginal = false, bool isDiscount = false, bool isFinal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AccountantThemeConfig.bodyLarge.copyWith(
            color: isOriginal ? Colors.white70 : Colors.white,
            decoration: isOriginal ? TextDecoration.lineThrough : null,
          ),
        ),
        Text(
          value,
          style: AccountantThemeConfig.bodyLarge.copyWith(
            color: isDiscount 
                ? Colors.white 
                : isFinal 
                    ? Colors.white 
                    : isOriginal 
                        ? Colors.white70 
                        : Colors.white,
            fontWeight: isFinal ? FontWeight.bold : FontWeight.normal,
            fontSize: isFinal ? 18 : 16,
            decoration: isOriginal ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
  }

  /// Build voucher metadata section
  Widget _buildVoucherMetadata(Map<String, dynamic> voucher) {
    final voucherType = voucher['voucher_type'] as String? ?? '';
    final targetName = voucher['voucher_target_name'] as String? ?? '';
    final usageInfo = voucher['voucher_usage'] as Map<String, dynamic>?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تفاصيل القسيمة',
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (voucherType.isNotEmpty)
            _buildMetadataRow('نوع القسيمة:', _getVoucherTypeDisplayName(voucherType)),
          if (targetName.isNotEmpty)
            _buildMetadataRow('المطبقة على:', targetName),
          if (usageInfo != null) ...[
            _buildMetadataRow(
              'تاريخ الاستخدام:',
              _formatDateTime(usageInfo['used_at'] as String?),
            ),
          ],
        ],
      ),
    );
  }

  /// Build metadata row
  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Get voucher type display name
  String _getVoucherTypeDisplayName(String type) {
    switch (type) {
      case 'category':
        return 'فئة منتجات';
      case 'product':
        return 'منتج محدد';
      case 'multiple_products':
        return 'منتجات متعددة';
      default:
        return type;
    }
  }

  /// Format date time for display
  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'غير محدد';

    try {
      final dateTime = DateTime.parse(dateTimeString);
      // Convert to local time if UTC to ensure proper timezone handling
      final localDateTime = dateTime.isUtc ? dateTime.toLocal() : dateTime;
      final formatter = DateFormat('dd/MM/yyyy HH:mm', 'ar');
      return formatter.format(localDateTime);
    } catch (e) {
      return 'غير محدد';
    }
  }
}
