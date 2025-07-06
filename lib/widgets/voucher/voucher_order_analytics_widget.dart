import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../utils/accountant_theme_config.dart';
import '../../models/client_order_model.dart';

/// Analytics widget for voucher orders showing key metrics and insights
/// Displays voucher usage statistics, savings totals, and performance indicators
class VoucherOrderAnalyticsWidget extends StatelessWidget {
  const VoucherOrderAnalyticsWidget({
    super.key,
    required this.orders,
    this.showDetailedMetrics = true,
  });

  final List<ClientOrder> orders;
  final bool showDetailedMetrics;

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'ar_EG',
    symbol: 'ج.م',
    decimalDigits: 2,
  );

  static final NumberFormat _percentFormat = NumberFormat.percentPattern('ar');

  /// Get voucher orders from the list
  List<ClientOrder> get voucherOrders {
    return orders.where((order) {
      final metadata = order.metadata;
      return metadata != null && metadata['order_type'] == 'voucher_order';
    }).toList();
  }

  /// Calculate total savings from voucher orders
  double get totalSavings {
    return voucherOrders.fold(0.0, (sum, order) {
      final metadata = order.metadata;
      if (metadata == null) return sum;
      
      final pricingDetails = metadata['pricing_details'] as Map<String, dynamic>?;
      final savings = pricingDetails?['total_savings'] as num? ?? 0;
      return sum + savings.toDouble();
    });
  }

  /// Calculate total original value before discounts
  double get totalOriginalValue {
    return voucherOrders.fold(0.0, (sum, order) {
      final metadata = order.metadata;
      if (metadata == null) return sum;
      
      final pricingDetails = metadata['pricing_details'] as Map<String, dynamic>?;
      final original = pricingDetails?['original_total'] as num? ?? 0;
      return sum + original.toDouble();
    });
  }

  /// Calculate average discount percentage
  double get averageDiscountPercentage {
    if (voucherOrders.isEmpty) return 0.0;
    
    final totalDiscount = voucherOrders.fold(0.0, (sum, order) {
      final metadata = order.metadata;
      if (metadata == null) return sum;
      
      final discount = metadata['discount_percentage'] as num? ?? 0;
      return sum + discount.toDouble();
    });
    
    return totalDiscount / voucherOrders.length;
  }

  /// Get voucher usage by type
  Map<String, int> get voucherUsageByType {
    final usage = <String, int>{};
    
    for (final order in voucherOrders) {
      final metadata = order.metadata;
      if (metadata == null) continue;
      
      final voucherType = metadata['voucher_type'] as String? ?? 'unknown';
      usage[voucherType] = (usage[voucherType] ?? 0) + 1;
    }
    
    return usage;
  }

  @override
  Widget build(BuildContext context) {
    if (voucherOrders.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
        gradient: AccountantThemeConfig.greenGradient,
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildKeyMetrics(),
          if (showDetailedMetrics) ...[
            const SizedBox(height: 20),
            _buildDetailedAnalytics(),
          ],
        ],
      ),
    ).animate().fadeIn(delay: const Duration(milliseconds: 200)).slideY(begin: 0.3);
  }

  /// Build empty state when no voucher orders exist
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        children: [
          Icon(
            Icons.local_offer_outlined,
            size: 48,
            color: Colors.white54,
          ),
          const SizedBox(height: 12),
          Text(
            'لا توجد طلبات قسائم',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر إحصائيات القسائم هنا عند وجود طلبات',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white54,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build analytics header
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.analytics,
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
                'إحصائيات طلبات القسائم',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${voucherOrders.length} طلب من أصل ${orders.length}',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build key metrics section
  Widget _buildKeyMetrics() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'إجمالي الوفورات',
            _currencyFormat.format(totalSavings),
            Icons.savings,
            Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'متوسط الخصم',
            '${averageDiscountPercentage.toStringAsFixed(1)}%',
            Icons.percent,
            Colors.white,
          ),
        ),
      ],
    );
  }

  /// Build individual metric card
  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Build detailed analytics section
  Widget _buildDetailedAnalytics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تفاصيل إضافية',
          style: AccountantThemeConfig.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildVoucherTypeBreakdown(),
        const SizedBox(height: 12),
        _buildSavingsBreakdown(),
      ],
    );
  }

  /// Build voucher type breakdown
  Widget _buildVoucherTypeBreakdown() {
    final usage = voucherUsageByType;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'استخدام القسائم حسب النوع',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...usage.entries.map((entry) => _buildUsageRow(
            _getVoucherTypeDisplayName(entry.key),
            entry.value,
            voucherOrders.length,
          )),
        ],
      ),
    );
  }

  /// Build usage row for voucher types
  Widget _buildUsageRow(String type, int count, int total) {
    final percentage = total > 0 ? (count / total) : 0.0;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              type,
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '$count طلب',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              '${(percentage * 100).toStringAsFixed(1)}%',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  /// Build savings breakdown
  Widget _buildSavingsBreakdown() {
    final conversionRate = orders.isNotEmpty ? (voucherOrders.length / orders.length) : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تحليل الوفورات',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildSavingsRow('القيمة الأصلية:', _currencyFormat.format(totalOriginalValue)),
          _buildSavingsRow('القيمة بعد الخصم:', _currencyFormat.format(totalOriginalValue - totalSavings)),
          _buildSavingsRow('معدل التحويل:', '${(conversionRate * 100).toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  /// Build savings row
  Widget _buildSavingsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white70,
            ),
          ),
          Text(
            value,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Get display name for voucher type
  String _getVoucherTypeDisplayName(String type) {
    switch (type) {
      case 'category':
        return 'قسائم الفئات';
      case 'product':
        return 'قسائم المنتجات';
      default:
        return 'نوع غير محدد';
    }
  }
}
