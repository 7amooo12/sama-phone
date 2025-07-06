import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/warehouse_deletion_models.dart';
import '../../models/warehouse_model.dart';
import '../../services/warehouse_service.dart';
import '../../providers/warehouse_provider.dart';
import '../../config/accountant_theme_config.dart';
import '../../utils/app_logger.dart';
import 'warehouse_deletion_action_card.dart';
import 'warehouse_request_management_dialog.dart';
import 'force_deletion_dialog.dart';

/// حوار حذف المخزن المحسن مع تحليل شامل للعوامل المانعة
class WarehouseDeletionDialog extends StatefulWidget {
  final WarehouseModel warehouse;

  const WarehouseDeletionDialog({
    super.key,
    required this.warehouse,
  });

  @override
  State<WarehouseDeletionDialog> createState() => _WarehouseDeletionDialogState();
}

class _WarehouseDeletionDialogState extends State<WarehouseDeletionDialog> {
  final WarehouseService _warehouseService = WarehouseService();
  WarehouseDeletionAnalysis? _analysis;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDeletionAnalysis();
  }

  Future<void> _loadDeletionAnalysis() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final analysis = await _warehouseService.analyzeWarehouseDeletion(widget.warehouse.id);
      setState(() {
        _analysis = analysis;
      });
    } catch (e) {
      setState(() {
        _error = 'فشل في تحليل إمكانية حذف المخزن: $e';
      });
      AppLogger.error('خطأ في تحليل حذف المخزن: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AccountantThemeConfig.cardShadow,
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _error != null
                      ? _buildErrorState()
                      : _buildAnalysisContent(),
            ),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.delete_forever,
              color: Colors.red,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حذف المخزن',
                  style: AccountantThemeConfig.headingStyle.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.warehouse.name,
                  style: AccountantThemeConfig.bodyStyle.copyWith(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'جاري تحليل إمكانية حذف المخزن...',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadDeletionAnalysis,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisContent() {
    if (_analysis == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusCard(),
          const SizedBox(height: 16),
          if (_analysis!.blockingFactors.isNotEmpty) ...[
            _buildBlockingFactorsCard(),
            const SizedBox(height: 16),
          ],
          if (_analysis!.requiredActions.isNotEmpty) ...[
            _buildRequiredActionsCard(),
            const SizedBox(height: 16),
          ],
          _buildSummaryCard(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _analysis!.canDelete 
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _analysis!.canDelete 
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _analysis!.canDelete ? Icons.check_circle : Icons.warning,
            color: _analysis!.canDelete ? Colors.green : Colors.orange,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _analysis!.statusMessage,
                  style: AccountantThemeConfig.bodyStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (!_analysis!.canDelete) ...[
                  const SizedBox(height: 4),
                  Text(
                    'الوقت المقدر للتنظيف: ${_analysis!.estimatedCleanupTime}',
                    style: AccountantThemeConfig.bodyStyle.copyWith(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Color(int.parse(_analysis!.riskLevelColor.substring(1), radix: 16) + 0xFF000000)
                  .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _analysis!.riskLevelText,
              style: TextStyle(
                color: Color(int.parse(_analysis!.riskLevelColor.substring(1), radix: 16) + 0xFF000000),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockingFactorsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.block, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                'العوامل المانعة للحذف',
                style: AccountantThemeConfig.bodyStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...(_analysis!.blockingFactors.map((factor) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 8, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  factor,
                  style: AccountantThemeConfig.bodyStyle.copyWith(fontSize: 14),
                ),
              ],
            ),
          ))),
        ],
      ),
    );
  }

  Widget _buildRequiredActionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الإجراءات المطلوبة',
            style: AccountantThemeConfig.bodyStyle.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...(_analysis!.requiredActions.map((action) => 
            WarehouseDeletionActionCard(
              action: action,
              onActionTap: () => _handleActionTap(action),
            )
          )),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ملخص التحليل',
            style: AccountantThemeConfig.bodyStyle.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('الطلبات النشطة', '${_analysis!.activeRequests.length}'),
          _buildSummaryRow('عناصر المخزون', '${_analysis!.inventoryAnalysis.totalItems}'),
          _buildSummaryRow('إجمالي الكمية', '${_analysis!.inventoryAnalysis.totalQuantity}'),
          _buildSummaryRow('المعاملات الحديثة', '${_analysis!.transactionAnalysis.recentTransactions}'),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AccountantThemeConfig.bodyStyle.copyWith(fontSize: 14),
          ),
          Text(
            value,
            style: AccountantThemeConfig.bodyStyle.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AccountantThemeConfig.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(width: 12),
          if (_analysis?.canDelete == true) ...[
            Expanded(
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _confirmDeletion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('حذف المخزن', style: TextStyle(color: Colors.white)),
              ),
            ),
          ] else ...[
            Expanded(
              child: ElevatedButton(
                onPressed: _startCleanupProcess,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AccountantThemeConfig.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('بدء التنظيف', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _showForceDeleteDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AccountantThemeConfig.dangerRed,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('حذف قسري', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleActionTap(WarehouseDeletionAction action) {
    switch (action.type) {
      case DeletionActionType.manageRequests:
        _showRequestManagementDialog();
        break;
      case DeletionActionType.manageInventory:
        _navigateToInventoryManagement();
        break;
      case DeletionActionType.archiveTransactions:
        _archiveTransactions();
        break;
      default:
        break;
    }
  }

  void _showRequestManagementDialog() {
    showDialog(
      context: context,
      builder: (context) => WarehouseRequestManagementDialog(
        warehouseId: widget.warehouse.id,
        activeRequests: _analysis!.activeRequests,
        onRequestsUpdated: _loadDeletionAnalysis,
      ),
    );
  }

  void _navigateToInventoryManagement() {
    Navigator.of(context).pop();
    // Navigate to inventory management screen
    // This would be implemented based on your navigation structure
  }

  void _archiveTransactions() async {
    // Implement transaction archiving
    setState(() {
      _isProcessing = true;
    });

    try {
      // Archive transactions logic here
      await Future.delayed(const Duration(seconds: 2)); // Placeholder
      _loadDeletionAnalysis();
    } catch (e) {
      AppLogger.error('خطأ في أرشفة المعاملات: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _startCleanupProcess() {
    // Implement cleanup process
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('سيتم تنفيذ عملية التنظيف قريباً'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showForceDeleteDialog() async {
    if (_analysis == null) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ForceDeletionDialog(
        warehouse: widget.warehouse,
        analysis: _analysis!,
        onForceDelete: (targetWarehouseId) async {
          await _executeForceDelete(targetWarehouseId);
        },
      ),
    );

    if (result == true && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم الحذف القسري بنجاح'),
          backgroundColor: AccountantThemeConfig.primaryGreen,
        ),
      );
    }
  }

  Future<void> _executeForceDelete(String targetWarehouseId) async {
    try {
      AppLogger.info('🔥 تنفيذ الحذف القسري للمخزن: ${widget.warehouse.name}');

      final warehouseProvider = context.read<WarehouseProvider>();
      final success = await warehouseProvider.deleteWarehouse(
        widget.warehouse.id,
        forceDelete: true,
        targetWarehouseId: targetWarehouseId,
      );

      if (!success) {
        throw Exception('فشل في تنفيذ الحذف القسري');
      }

      AppLogger.info('✅ تم الحذف القسري بنجاح');
    } catch (e) {
      AppLogger.error('❌ خطأ في الحذف القسري: $e');
      rethrow;
    }
  }

  void _confirmDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف المخزن "${widget.warehouse.name}"؟\n\nهذا الإجراء لا يمكن التراجع عنه.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isProcessing = true;
      });

      try {
        await context.read<WarehouseProvider>().deleteWarehouse(widget.warehouse.id);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف المخزن بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isProcessing = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل في حذف المخزن: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
