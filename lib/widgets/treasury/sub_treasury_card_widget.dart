import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../models/treasury_models.dart';
import '../../utils/accountant_theme_config.dart';
import '../../providers/treasury_provider.dart';
import '../../utils/safe_provider_access.dart';
import 'animated_balance_widget.dart';
import 'animated_currency_converter.dart';
import 'currency_converter_toggle_button.dart' as converter;

class SubTreasuryCardWidget extends StatefulWidget {
  final TreasuryVault treasury;
  final List<TreasuryVault> allTreasuries;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isConnectionMode;
  final bool isConnectionManagementMode;
  final List<TreasuryConnection> connections;
  final Function(String)? onConnectionRemove;

  const SubTreasuryCardWidget({
    super.key,
    required this.treasury,
    required this.allTreasuries,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isConnectionMode = false,
    this.isConnectionManagementMode = false,
    this.connections = const [],
    this.onConnectionRemove,
  });

  @override
  State<SubTreasuryCardWidget> createState() => _SubTreasuryCardWidgetState();
}

class _SubTreasuryCardWidgetState extends State<SubTreasuryCardWidget>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late AnimationController _glowController;
  late AnimationController _scaleController;
  late Animation<double> _flipAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _scaleAnimation;
  
  bool _isFlipped = false;
  bool _showCurrencyConverter = false;

  @override
  void initState() {
    super.initState();
    
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _flipAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    ));
    
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
    
    _glowController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(SubTreasuryCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _scaleController.forward();
      } else {
        _scaleController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    _glowController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_flipAnimation, _glowAnimation, _scaleAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: _buildCardContainer(),
        );
      },
    );
  }

  Widget _buildCardContainer() {
    final cardContent = Container(
      // Further optimized height for more compact design and better space utilization
      height: 120, // Reduced from 140px to 120px for more compact layout
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12), // Slightly reduced border radius
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12), // Match container border radius
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(_flipAnimation.value * math.pi),
          child: _flipAnimation.value < 0.5
              ? _buildFrontSide()
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: _buildBackSide(),
                ),
        ),
      ),
    );

    // Only wrap with GestureDetector when card is not flipped
    if (_isFlipped) {
      return cardContent;
    } else {
      return GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: cardContent,
      );
    }
  }

  Widget _buildFrontSide() {
    return Stack(
      children: [
        // Main content
        Padding(
          padding: const EdgeInsets.all(12), // Further reduced padding for more compact design
          child: Row(
            children: [
              // Currency/Bank icon
              Container(
                width: 36, // Further reduced for more compact design
                height: 36, // Further reduced for more compact design
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.treasury.isBankTreasury
                        ? [
                            AccountantThemeConfig.primaryGreen,
                            AccountantThemeConfig.primaryGreen.withValues(alpha: 0.7),
                          ]
                        : [
                            AccountantThemeConfig.accentBlue,
                            AccountantThemeConfig.accentBlue.withValues(alpha: 0.7),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    widget.treasury.isBankTreasury
                        ? widget.treasury.bankIcon
                        : widget.treasury.currencyFlag,
                    style: const TextStyle(fontSize: 18), // Further optimized for more compact design
                  ),
                ),
              ),

              const SizedBox(width: 8), // Further reduced spacing for more compact design
              
              // Treasury info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.treasury.name,
                      style: AccountantThemeConfig.bodyMedium.copyWith( // Reduced font size for compact design
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1, // Single line for compact design
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Bank name for bank treasuries
                    if (widget.treasury.isBankTreasury && widget.treasury.bankName != null) ...[
                      const SizedBox(height: 1), // Further reduced spacing for more compact design
                      Text(
                        widget.treasury.bankName!,
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: AccountantThemeConfig.white70,
                          fontWeight: FontWeight.w500,
                          fontSize: 11, // Smaller font for compact design
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Account number for bank treasuries
                    if (widget.treasury.isBankTreasury && widget.treasury.maskedAccountNumber.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        widget.treasury.maskedAccountNumber,
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: AccountantThemeConfig.white60,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 8), // Increased spacing for better layout
                    // Balance display with proper overflow handling
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: AnimatedBalanceWidget(
                          balance: widget.treasury.balance,
                          currencySymbol: widget.treasury.currencySymbol,
                          textStyle: AccountantThemeConfig.bodyMedium.copyWith(
                            color: AccountantThemeConfig.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                          animationDuration: const Duration(milliseconds: 900),
                        ),
                      ),
                    ),
                    if (widget.treasury.exchangeRateToEgp != 1.0)
                      Text(
                        'سعر الصرف: ${widget.treasury.exchangeRateToEgp.toStringAsFixed(4)}',
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: AccountantThemeConfig.white60,
                        ),
                      ),

                    // Currency converter display
                    if (_showCurrencyConverter)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: AnimatedCurrencyConverter(
                          treasury: widget.treasury,
                          showConverter: _showCurrencyConverter,
                          onToggle: () {
                            setState(() {
                              _showCurrencyConverter = !_showCurrencyConverter;
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Currency converter toggle button
        converter.TreasuryCardCurrencyConverter(
          treasury: widget.treasury,
          allTreasuries: widget.allTreasuries,
          isMainTreasury: false,
        ),

        // Connection indicator
        if (widget.connections.isNotEmpty)
          Positioned(
            top: 8,
            right: 8,
            child: widget.isConnectionManagementMode
                ? _buildConnectionManagementIndicator()
                : Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AccountantThemeConfig.primaryGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.connections.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
          ),
        
        // Flip button
        Positioned(
          bottom: 8,
          right: 8,
          child: GestureDetector(
            onTap: _toggleFlip,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AccountantThemeConfig.white60,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.more_horiz_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
        
        // Connection points
        if (widget.isConnectionMode) ...[
          _buildConnectionPoint(Alignment.topCenter),
          _buildConnectionPoint(Alignment.bottomCenter),
          _buildConnectionPoint(Alignment.centerLeft),
          _buildConnectionPoint(Alignment.centerRight),
        ],
        
        // Selection indicator
        if (widget.isSelected)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AccountantThemeConfig.primaryGreen,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AccountantThemeConfig.primaryGreen.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBackSide() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الإجراءات',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: _toggleFlip,
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  Icons.close_rounded,
                  color: AccountantThemeConfig.white70,
                  size: 20,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Action buttons
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'تعديل الرصيد',
                    Icons.edit_rounded,
                    AccountantThemeConfig.blueGradient,
                    () => _editBalance(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    'حذف',
                    Icons.delete_rounded,
                    AccountantThemeConfig.redGradient,
                    () => _deleteTreasury(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    LinearGradient gradient,
    VoidCallback onPressed,
  ) {
    return GestureDetector(
      onTap: () {
        // Stop event propagation and execute the action
        onPressed();
      },
      // Prevent the tap from bubbling up to parent GestureDetectors
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionPoint(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AccountantThemeConfig.primaryGreen
                  : Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AccountantThemeConfig.accentBlue,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AccountantThemeConfig.accentBlue.withOpacity(_glowAnimation.value),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _toggleFlip() {
    setState(() {
      _isFlipped = !_isFlipped;
    });
    
    if (_isFlipped) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
  }

  void _editBalance() {
    showDialog(
      context: context,
      builder: (context) => _EditBalanceDialog(
        treasury: widget.treasury,
        onBalanceUpdated: () {
          // Keep the card flipped so user can see the updated balance
          // The card will automatically update via provider notifications
        },
      ),
    );
  }

  void _deleteTreasury() {
    showDialog(
      context: context,
      builder: (context) => _DeleteTreasuryDialog(
        treasury: widget.treasury,
        onDeleted: () {
          // Close the card flip after successful deletion
          _toggleFlip();
        },
      ),
    );
  }

  Widget _buildConnectionManagementIndicator() {
    return GestureDetector(
      onTap: () => _showConnectionManagementMenu(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AccountantThemeConfig.dangerRed,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.link_off_rounded,
              color: Colors.white,
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              '${widget.connections.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConnectionManagementMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(16),
            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.dangerRed),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'إدارة الاتصالات',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...widget.connections.map((connection) => _buildConnectionItem(connection)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionItem(TreasuryConnection connection) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مبلغ الاتصال: ${connection.connectionAmount.toStringAsFixed(2)}',
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: Colors.white,
                  ),
                ),
                Text(
                  'تاريخ الإنشاء: ${connection.createdAt.day}/${connection.createdAt.month}/${connection.createdAt.year}',
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: AccountantThemeConfig.white70,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onConnectionRemove?.call(connection.id);
            },
            icon: Icon(
              Icons.delete_rounded,
              color: AccountantThemeConfig.dangerRed,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteTreasuryDialog extends StatefulWidget {
  final TreasuryVault treasury;
  final VoidCallback onDeleted;

  const _DeleteTreasuryDialog({
    required this.treasury,
    required this.onDeleted,
  });

  @override
  State<_DeleteTreasuryDialog> createState() => _DeleteTreasuryDialogState();
}

class _DeleteTreasuryDialogState extends State<_DeleteTreasuryDialog> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AccountantThemeConfig.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.warning_rounded,
            color: AccountantThemeConfig.dangerRed,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            'تأكيد الحذف',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'هل أنت متأكد من حذف الخزنة "${widget.treasury.name}"؟',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.white70,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.dangerRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AccountantThemeConfig.dangerRed.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تحذير:',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: AccountantThemeConfig.dangerRed,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• لا يمكن التراجع عن هذا الإجراء\n• تأكد من عدم وجود رصيد في الخزنة\n• تأكد من عدم وجود اتصالات مع خزائن أخرى',
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: AccountantThemeConfig.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.pop(context),
          child: Text(
            'إلغاء',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.white70,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isDeleting ? null : _deleteTreasury,
          style: ElevatedButton.styleFrom(
            backgroundColor: AccountantThemeConfig.dangerRed,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isDeleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'حذف',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _deleteTreasury() async {
    setState(() {
      _isDeleting = true;
    });

    try {
      // Get the treasury provider from the context
      final treasuryProvider = context.getProviderSafely<TreasuryProvider>();

      await treasuryProvider.deleteTreasuryVault(widget.treasury.id);

      if (mounted) {
        Navigator.pop(context);
        widget.onDeleted();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم حذف الخزنة "${widget.treasury.name}" بنجاح',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AccountantThemeConfig.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'فشل في حذف الخزنة: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AccountantThemeConfig.dangerRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }
}

class _EditBalanceDialog extends StatefulWidget {
  final TreasuryVault treasury;
  final VoidCallback onBalanceUpdated;

  const _EditBalanceDialog({
    required this.treasury,
    required this.onBalanceUpdated,
  });

  @override
  State<_EditBalanceDialog> createState() => _EditBalanceDialogState();
}

class _EditBalanceDialogState extends State<_EditBalanceDialog> {
  late TextEditingController _balanceController;
  late TextEditingController _descriptionController;
  bool _isUpdating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _balanceController = TextEditingController(
      text: widget.treasury.balance.toStringAsFixed(2),
    );
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AccountantThemeConfig.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          const Icon(
            Icons.edit_rounded,
            color: AccountantThemeConfig.primaryGreen,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            'تعديل رصيد الخزنة',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'خزنة: ${widget.treasury.name}',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Current balance display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AccountantThemeConfig.primaryGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'الرصيد الحالي: ${widget.treasury.balance.toStringAsFixed(2)} ${widget.treasury.currency}',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // New balance input
          Text(
            'الرصيد الجديد',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _balanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'أدخل الرصيد الجديد',
              hintStyle: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.white60,
              ),
              suffixText: widget.treasury.currency,
              suffixStyle: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.white70,
              ),
              filled: true,
              fillColor: AccountantThemeConfig.white60.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AccountantThemeConfig.white60.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AccountantThemeConfig.white60.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AccountantThemeConfig.primaryGreen,
                ),
              ),
              errorText: _errorMessage,
              errorStyle: AccountantThemeConfig.bodySmall.copyWith(
                color: AccountantThemeConfig.dangerRed,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Description input
          Text(
            'وصف العملية (اختياري)',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            maxLines: 2,
            style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'أدخل وصف للعملية (مثل: تعديل رصيد، تصحيح خطأ، إلخ)',
              hintStyle: AccountantThemeConfig.bodySmall.copyWith(
                color: AccountantThemeConfig.white60,
              ),
              filled: true,
              fillColor: AccountantThemeConfig.white60.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AccountantThemeConfig.white60.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AccountantThemeConfig.white60.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AccountantThemeConfig.primaryGreen,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isUpdating ? null : () => Navigator.pop(context),
          child: Text(
            'إلغاء',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.white70,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isUpdating ? null : _updateBalance,
          style: ElevatedButton.styleFrom(
            backgroundColor: AccountantThemeConfig.primaryGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isUpdating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'تحديث الرصيد',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _updateBalance() async {
    setState(() {
      _errorMessage = null;
    });

    // Validate input
    final balanceText = _balanceController.text.trim();
    if (balanceText.isEmpty) {
      setState(() {
        _errorMessage = 'يرجى إدخال الرصيد الجديد';
      });
      return;
    }

    final newBalance = double.tryParse(balanceText);
    if (newBalance == null) {
      setState(() {
        _errorMessage = 'يرجى إدخال رقم صحيح';
      });
      return;
    }

    if (newBalance < 0) {
      setState(() {
        _errorMessage = 'لا يمكن أن يكون الرصيد سالباً';
      });
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final treasuryProvider = context.getProviderSafely<TreasuryProvider>();

      final description = _descriptionController.text.trim().isEmpty
          ? 'تعديل رصيد الخزنة'
          : _descriptionController.text.trim();

      await treasuryProvider.updateTreasuryBalance(
        treasuryId: widget.treasury.id,
        newBalance: newBalance,
        transactionType: 'balance_adjustment',
        description: description,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onBalanceUpdated();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تحديث رصيد الخزنة "${widget.treasury.name}" بنجاح',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AccountantThemeConfig.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _errorMessage = 'فشل في تحديث الرصيد: $e';
        });
      }
    }
  }
}
