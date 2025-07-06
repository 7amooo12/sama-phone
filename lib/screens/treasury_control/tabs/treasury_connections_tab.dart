import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/accountant_theme_config.dart';
import '../../../providers/treasury_provider.dart';
import '../../../models/treasury_models.dart';

/// Treasury Connections Management Tab
/// Handles treasury connections, flow management, and visual connections
class TreasuryConnectionsTab extends StatefulWidget {
  final String treasuryId;
  final String treasuryType;

  const TreasuryConnectionsTab({
    super.key,
    required this.treasuryId,
    required this.treasuryType,
  });

  @override
  State<TreasuryConnectionsTab> createState() => _TreasuryConnectionsTabState();
}

class _TreasuryConnectionsTabState extends State<TreasuryConnectionsTab>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  List<TreasuryConnection> _connections = [];
  List<TreasuryVault> _availableTreasuries = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadConnections();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  Future<void> _loadConnections() async {
    if (widget.treasuryType != 'treasury') return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final treasuryProvider = context.read<TreasuryProvider>();
      await treasuryProvider.loadConnections();
      await treasuryProvider.loadTreasuryVaults();

      final allConnections = treasuryProvider.connections;
      final allTreasuries = treasuryProvider.treasuryVaults;

      // Filter connections related to this treasury
      final relatedConnections = allConnections.where((connection) =>
          connection.sourceTreasuryId == widget.treasuryId ||
          connection.targetTreasuryId == widget.treasuryId).toList();

      // Get available treasuries for new connections (excluding current treasury)
      final availableTreasuries = allTreasuries
          .where((treasury) => treasury.id != widget.treasuryId)
          .toList();

      setState(() {
        _connections = relatedConnections;
        _availableTreasuries = availableTreasuries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.treasuryType != 'treasury') {
      return _buildUnsupportedMessage();
    }

    return Column(
      children: [
        // Action buttons
        _buildActionButtons(),

        const SizedBox(height: 16),

        // Connection statistics
        _buildConnectionStatistics(),

        const SizedBox(height: 16),

        // Connections list
        Expanded(
          child: _buildConnectionsList(),
        ),
      ],
    );
  }

  Widget _buildUnsupportedMessage() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AccountantThemeConfig.cardShadows,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 64,
              color: AccountantThemeConfig.primaryGreen,
            ),
            const SizedBox(height: 16),
            Text(
              'الاتصالات غير متاحة',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'إدارة الاتصالات متاحة فقط للخزائن العادية',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _availableTreasuries.isNotEmpty ? () => _showAddConnectionDialog() : null,
            icon: const Icon(Icons.add_link_rounded),
            label: const Text('إضافة اتصال'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _loadConnections(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('تحديث'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.accentBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: ElevatedButton.icon(
            onPressed: _connections.isNotEmpty ? () => _showConnectionsMap() : null,
            icon: const Icon(Icons.map_rounded),
            label: const Text('خريطة الاتصالات'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.accentBlue.withValues(alpha: 0.8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionStatistics() {
    final incomingConnections = _connections.where((c) => c.targetTreasuryId == widget.treasuryId).length;
    final outgoingConnections = _connections.where((c) => c.sourceTreasuryId == widget.treasuryId).length;
    final totalAmount = _connections.fold<double>(0.0, (sum, c) => sum + c.connectionAmount);

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'الاتصالات الواردة',
            incomingConnections.toString(),
            Icons.call_received_rounded,
            AccountantThemeConfig.primaryGreen,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _buildStatCard(
            'الاتصالات الصادرة',
            outgoingConnections.toString(),
            Icons.call_made_rounded,
            AccountantThemeConfig.accentBlue,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _buildStatCard(
            'إجمالي المبالغ',
            '${totalAmount.toStringAsFixed(2)} ج.م',
            Icons.account_balance_rounded,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: AccountantThemeConfig.white70,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionsList() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            AccountantThemeConfig.primaryGreen,
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AccountantThemeConfig.white60,
            ),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ في تحميل الاتصالات',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: AccountantThemeConfig.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: AccountantThemeConfig.white60,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadConnections,
              style: AccountantThemeConfig.primaryButtonStyle,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (_connections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Icon(
                    Icons.hub_rounded,
                    size: 64,
                    color: AccountantThemeConfig.primaryGreen,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد اتصالات',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: AccountantThemeConfig.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'اضغط على "إضافة اتصال" لربط هذه الخزنة بخزائن أخرى',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: AccountantThemeConfig.white60,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _connections.length,
      itemBuilder: (context, index) {
        final connection = _connections[index];
        return _buildConnectionItem(connection);
      },
    );
  }

  Widget _buildConnectionItem(TreasuryConnection connection) {
    final treasuryProvider = context.watch<TreasuryProvider>();
    final isOutgoing = connection.sourceTreasuryId == widget.treasuryId;
    final connectedTreasuryId = isOutgoing ? connection.targetTreasuryId : connection.sourceTreasuryId;

    final connectedTreasury = treasuryProvider.treasuryVaults
        .where((t) => t.id == connectedTreasuryId)
        .firstOrNull;

    if (connectedTreasury == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: Border.all(
          color: isOutgoing
              ? AccountantThemeConfig.accentBlue.withValues(alpha: 0.5)
              : AccountantThemeConfig.primaryGreen.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Direction indicator
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isOutgoing
                      ? AccountantThemeConfig.accentBlue
                      : AccountantThemeConfig.primaryGreen).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isOutgoing ? Icons.call_made_rounded : Icons.call_received_rounded,
                  color: isOutgoing
                      ? AccountantThemeConfig.accentBlue
                      : AccountantThemeConfig.primaryGreen,
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              // Treasury info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connectedTreasury.name,
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${connectedTreasury.treasuryType.nameAr} • ${connectedTreasury.currency}',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: AccountantThemeConfig.white70,
                      ),
                    ),
                  ],
                ),
              ),

              // Connection amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${connection.connectionAmount.toStringAsFixed(2)} ج.م',
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      color: isOutgoing
                          ? AccountantThemeConfig.accentBlue
                          : AccountantThemeConfig.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOutgoing ? 'صادر' : 'وارد',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: AccountantThemeConfig.white60,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Connection details
          Row(
            children: [
              Expanded(
                child: Text(
                  'تاريخ الإنشاء: ${connection.createdAt.day}/${connection.createdAt.month}/${connection.createdAt.year}',
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: AccountantThemeConfig.white60,
                  ),
                ),
              ),

              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _showConnectionDetails(connection, connectedTreasury),
                    icon: const Icon(Icons.info_outline_rounded),
                    color: AccountantThemeConfig.white70,
                    iconSize: 20,
                  ),
                  IconButton(
                    onPressed: () => _confirmRemoveConnection(connection, connectedTreasury),
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: Colors.red,
                    iconSize: 20,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddConnectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AccountantThemeConfig.cardShadows,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'إضافة اتصال جديد',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'اختر الخزنة التي تريد الاتصال بها:',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: AccountantThemeConfig.white70,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: _availableTreasuries.length,
                  itemBuilder: (context, index) {
                    final treasury = _availableTreasuries[index];
                    return ListTile(
                      leading: Icon(
                        treasury.treasuryType == TreasuryType.bank
                            ? Icons.account_balance_rounded
                            : Icons.account_balance_wallet_rounded,
                        color: AccountantThemeConfig.primaryGreen,
                      ),
                      title: Text(
                        treasury.name,
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        '${treasury.treasuryType.nameAr} • ${treasury.balance.toStringAsFixed(2)} ${treasury.currency}',
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: AccountantThemeConfig.white60,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _createConnection(treasury);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('إلغاء'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createConnection(TreasuryVault targetTreasury) {
    showDialog(
      context: context,
      builder: (context) => _ConnectionAmountDialog(
        sourceTreasuryId: widget.treasuryId,
        targetTreasuryId: targetTreasury.id,
        targetTreasuryName: targetTreasury.name,
        onConnectionCreated: () {
          _loadConnections();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم إنشاء الاتصال بنجاح',
                style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
              ),
              backgroundColor: AccountantThemeConfig.primaryGreen,
            ),
          );
        },
      ),
    );
  }

  void _showConnectionDetails(TreasuryConnection connection, TreasuryVault connectedTreasury) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: Container(
          width: 350,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AccountantThemeConfig.cardShadows,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'تفاصيل الاتصال',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildDetailRow('الخزنة المتصلة:', connectedTreasury.name),
              _buildDetailRow('نوع الخزنة:', connectedTreasury.treasuryType.nameAr),
              _buildDetailRow('مبلغ الاتصال:', '${connection.connectionAmount.toStringAsFixed(2)} ج.م'),
              _buildDetailRow('سعر الصرف:', connection.exchangeRateUsed.toStringAsFixed(4)),
              _buildDetailRow('تاريخ الإنشاء:', '${connection.createdAt.day}/${connection.createdAt.month}/${connection.createdAt.year}'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: AccountantThemeConfig.primaryButtonStyle,
                child: const Text('إغلاق'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.white70,
            ),
          ),
          Text(
            value,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveConnection(TreasuryConnection connection, TreasuryVault connectedTreasury) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: Container(
          width: 350,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AccountantThemeConfig.cardShadows,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_rounded,
                size: 48,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                'تأكيد حذف الاتصال',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'هل أنت متأكد من حذف الاتصال مع "${connectedTreasury.name}"؟',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: AccountantThemeConfig.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _removeConnection(connection);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('حذف'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _removeConnection(TreasuryConnection connection) async {
    try {
      await context.read<TreasuryProvider>().removeConnection(connection.id);
      await _loadConnections();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم حذف الاتصال بنجاح',
            style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AccountantThemeConfig.primaryGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل في حذف الاتصال: $e',
            style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showConnectionsMap() {
    // TODO: Implement connections map visualization
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'سيتم تنفيذ خريطة الاتصالات قريباً',
          style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: AccountantThemeConfig.accentBlue,
      ),
    );
  }
}

// Connection Amount Dialog Widget
class _ConnectionAmountDialog extends StatefulWidget {
  final String sourceTreasuryId;
  final String targetTreasuryId;
  final String targetTreasuryName;
  final VoidCallback onConnectionCreated;

  const _ConnectionAmountDialog({
    required this.sourceTreasuryId,
    required this.targetTreasuryId,
    required this.targetTreasuryName,
    required this.onConnectionCreated,
  });

  @override
  State<_ConnectionAmountDialog> createState() => _ConnectionAmountDialogState();
}

class _ConnectionAmountDialogState extends State<_ConnectionAmountDialog> {
  final TextEditingController _amountController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.transparent,
      content: Container(
        width: 350,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AccountantThemeConfig.cardShadows,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'إنشاء اتصال جديد',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'الاتصال مع: ${widget.targetTreasuryName}',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: AccountantThemeConfig.white70,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AccountantThemeConfig.bodyLarge.copyWith(
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  labelText: 'مبلغ الاتصال',
                  labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
                    color: AccountantThemeConfig.white70,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AccountantThemeConfig.primaryGreen,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال مبلغ الاتصال';
                  }
                  if (double.tryParse(value) == null) {
                    return 'يرجى إدخال رقم صحيح';
                  }
                  if (double.parse(value) <= 0) {
                    return 'يجب أن يكون المبلغ أكبر من صفر';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createConnection,
                      style: AccountantThemeConfig.primaryButtonStyle,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('إنشاء'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = double.parse(_amountController.text);
      await context.read<TreasuryProvider>().createConnection(
        sourceTreasuryId: widget.sourceTreasuryId,
        targetTreasuryId: widget.targetTreasuryId,
        connectionAmount: amount,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onConnectionCreated();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل في إنشاء الاتصال: $e',
            style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
