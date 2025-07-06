import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/accountant_theme_config.dart';

class ProductStatusCard extends StatelessWidget {
  const ProductStatusCard({
    super.key,
    required this.name,
    required this.quantity,
    this.isLowStock = false,
    this.onTap,
  });
  final String name;
  final int quantity;
  final bool isLowStock;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Determine status color based on stock levels
    Color statusColor;
    Color glowColor;
    IconData statusIcon;

    if (quantity == 0) {
      statusColor = AccountantThemeConfig.dangerRed;
      glowColor = Colors.red;
      statusIcon = Icons.error_outline;
    } else if (quantity <= 5) {
      statusColor = AccountantThemeConfig.warningOrange;
      glowColor = Colors.orange;
      statusIcon = Icons.warning_amber;
    } else {
      statusColor = AccountantThemeConfig.primaryGreen;
      glowColor = AccountantThemeConfig.primaryGreen;
      statusIcon = Icons.check_circle;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: glowColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: 80,
              maxHeight: 100,
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Product icon with glow effect
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        glowColor.withOpacity(0.2),
                        glowColor.withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: AccountantThemeConfig.glowShadows(glowColor),
                  ),
                  child: Icon(
                    Icons.inventory_2,
                    color: glowColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Product details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        style: AccountantThemeConfig.headlineSmall.copyWith(
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.inventory,
                            size: 14,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'المخزون: $quantity وحدة',
                            style: AccountantThemeConfig.bodyMedium.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Quantity display with color-coded indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        statusColor.withOpacity(0.2),
                        statusColor.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: AccountantThemeConfig.glowShadows(statusColor),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        quantity.toString(),
                        style: GoogleFonts.cairo(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '📦',
                        style: const TextStyle(fontSize: 10),
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
  }
}
