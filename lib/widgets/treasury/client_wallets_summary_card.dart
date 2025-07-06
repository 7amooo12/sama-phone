import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/accountant_theme_config.dart';
import '../../providers/wallet_provider.dart';
import '../../models/wallet_model.dart';
import '../../widgets/common/animated_balance_widget.dart';

/// Client Wallets Summary Card Widget
/// Displays total balance and count of all client wallets
class ClientWalletsSummaryCard extends StatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isConnectionMode;

  const ClientWalletsSummaryCard({
    super.key,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isConnectionMode = false,
  });

  @override
  State<ClientWalletsSummaryCard> createState() => _ClientWalletsSummaryCardState();
}

class _ClientWalletsSummaryCardState extends State<ClientWalletsSummaryCard>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _scaleController;
  late Animation<double> _glowAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadWalletData();
  }

  void _initializeAnimations() {
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    if (widget.isConnectionMode) {
      _glowController.repeat(reverse: true);
    }
  }

  void _loadWalletData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      walletProvider.loadAllWallets();
    });
  }

  @override
  void didUpdateWidget(ClientWalletsSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isConnectionMode != oldWidget.isConnectionMode) {
      if (widget.isConnectionMode) {
        _glowController.repeat(reverse: true);
      } else {
        _glowController.stop();
        _glowController.reset();
      }
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _scaleController.reverse();
  }

  void _handleTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        final clientWallets = walletProvider.wallets
            .where((wallet) => wallet.role == 'client')
            .toList();

        final totalBalance = clientWallets.fold<double>(
          0.0,
          (sum, wallet) => sum + (wallet.balance ?? 0.0),
        );

        final activeWalletsCount = clientWallets
            .where((wallet) => wallet.isActive ?? false)
            .length;

        return AnimatedBuilder(
          animation: Listenable.merge([_glowAnimation, _scaleAnimation]),
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: GestureDetector(
                onTap: widget.onTap,
                onLongPress: widget.onLongPress,
                onTapDown: _handleTapDown,
                onTapUp: _handleTapUp,
                onTapCancel: _handleTapCancel,
                child: Container(
                  // Remove fixed height to allow parent container to control size
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.cardGradient,
                    borderRadius: BorderRadius.circular(16),
                    border: widget.isSelected
                        ? Border.all(
                            color: AccountantThemeConfig.primaryGreen,
                            width: 2,
                          )
                        : AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
                    boxShadow: [
                      ...AccountantThemeConfig.cardShadows,
                      if (widget.isConnectionMode)
                        BoxShadow(
                          color: AccountantThemeConfig.accentBlue.withValues(alpha: _glowAnimation.value),
                          blurRadius: 15,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20), // Increased padding for larger cards
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with icon and title
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.account_balance_wallet_rounded,
                                color: AccountantThemeConfig.primaryGreen,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'محافظ العملاء',
                                style: AccountantThemeConfig.headlineSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2, // Improved line height for Arabic
                                ),
                                textDirection: ui.TextDirection.rtl,
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Status indicator
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$activeWalletsCount نشط',
                                style: AccountantThemeConfig.bodySmall.copyWith(
                                  color: AccountantThemeConfig.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2, // Improved line height for Arabic
                                ),
                                textDirection: ui.TextDirection.rtl,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20), // Increased spacing for larger cards

                        // Balance and statistics - Simplified layout to prevent overlap
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Total balance section
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'إجمالي الأرصدة',
                                    style: AccountantThemeConfig.bodyMedium.copyWith(
                                      color: AccountantThemeConfig.white70,
                                      height: 1.2,
                                    ),
                                    textDirection: ui.TextDirection.rtl,
                                    textAlign: TextAlign.right,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8), // Increased spacing
                                  // Simplified balance display without complex nesting
                                  Container(
                                    width: double.infinity,
                                    child: Text(
                                      _formatBalance(totalBalance.toDouble()),
                                      style: AccountantThemeConfig.headlineSmall.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        height: 1.1,
                                      ),
                                      textDirection: ui.TextDirection.rtl,
                                      textAlign: TextAlign.right,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),

                              // Statistics row with proper spacing
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatItem(
                                      'العدد الكلي',
                                      clientWallets.length.toString(),
                                      Icons.people_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildStatItem(
                                      'متوسط الرصيد',
                                      clientWallets.isNotEmpty
                                          ? _formatBalance((totalBalance / clientWallets.length).toDouble())
                                          : '0',
                                      Icons.trending_up_rounded,
                                    ),
                                  ),
                                ],
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
          },
        );
      },
    );
  }



  /// Format balance with proper Arabic number formatting
  String _formatBalance(double balance) {
    if (balance >= 1000000) {
      return '${(balance / 1000000).toStringAsFixed(2)}م'; // Million in Arabic with more precision
    } else {
      // For amounts under one million, always show full precision with decimal places
      return balance.toStringAsFixed(2);
    }
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: AccountantThemeConfig.white60,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: AccountantThemeConfig.white60,
                      fontSize: 10,
                      height: 1.3, // Improved line height for Arabic
                    ),
                    textDirection: ui.TextDirection.rtl,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                height: 1.2, // Improved line height
              ),
              textDirection: ui.TextDirection.rtl,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
