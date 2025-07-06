import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/warehouse_deletion_models.dart';
import '../../models/warehouse_model.dart';
import '../../providers/warehouse_provider.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';
import '../../widgets/common/custom_loader.dart';
import 'warehouse_selection_dialog.dart';

/// حوار الحذف القسري للمخزن مع نقل الطلبات التلقائي
class ForceDeletionDialog extends StatefulWidget {
  final WarehouseModel warehouse;
  final WarehouseDeletionAnalysis analysis;
  final Function(String targetWarehouseId)? onForceDelete;

  const ForceDeletionDialog({
    super.key,
    required this.warehouse,
    required this.analysis,
    this.onForceDelete,
  });

  @override
  State<ForceDeletionDialog> createState() => _ForceDeletionDialogState();
}

class _ForceDeletionDialogState extends State<ForceDeletionDialog> {
  String? _selectedTargetWarehouseId;
  String? _selectedTargetWarehouseName;
  bool _isProcessing = false;
  bool _showTransferPreview = false;
  bool _confirmationChecked = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(20),
          border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.dangerRed),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWarningCard(),
                    const SizedBox(height: 16),
                    _buildConstraintsCard(),
                    const SizedBox(height: 16),
                    _buildTargetWarehouseSelection(),
                    if (_showTransferPreview) ...[
                      const SizedBox(height: 16),
                      _buildTransferPreview(),
                    ],
                    const SizedBox(height: 16),
                    _buildConfirmationCheckbox(),
                  ],
                ),
              ),
            ),
            _buildActionButtons(),
          ],
        ),
      ).animate().scale(
        duration: 300.ms,
        curve: Curves.easeOutBack,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.dangerRed.withValues(alpha: 0.1),
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
              color: AccountantThemeConfig.dangerRed.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.warning,
              color: AccountantThemeConfig.dangerRed,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حذف قسري للمخزن',
                  style: AccountantThemeConfig.headingStyle.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AccountantThemeConfig.dangerRed,
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

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.dangerRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.dangerRed.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.dangerous,
                color: AccountantThemeConfig.dangerRed,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'تحذير هام',
                style: AccountantThemeConfig.bodyStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AccountantThemeConfig.dangerRed,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'الحذف القسري سيؤدي إلى:\n'
            '• نقل جميع الطلبات النشطة (${widget.analysis.activeRequests.length} طلب) إلى المخزن المحدد\n'
            '• حذف جميع بيانات المخزون (${widget.analysis.inventoryAnalysis.totalItems} منتج)\n'
            '• أرشفة جميع المعاملات (${widget.analysis.transactionAnalysis.totalTransactions} معاملة)\n'
            '• حذف المخزن نهائياً بدون إمكانية الاسترداد',
            style: AccountantThemeConfig.bodyStyle.copyWith(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConstraintsCard() {
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
            'العوامل المانعة للحذف العادي',
            style: AccountantThemeConfig.bodyStyle.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...widget.analysis.blockingFactors.map((factor) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.block,
                  size: 16,
                  color: AccountantThemeConfig.warningOrange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    factor,
                    style: AccountantThemeConfig.bodyStyle.copyWith(
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildTargetWarehouseSelection() {
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
            'اختيار مخزن الوجهة للطلبات',
            style: AccountantThemeConfig.bodyStyle.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'يجب اختيار مخزن لنقل ${widget.analysis.activeRequests.length} طلب نشط إليه',
            style: AccountantThemeConfig.bodyStyle.copyWith(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          if (_selectedTargetWarehouseId != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AccountantThemeConfig.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AccountantThemeConfig.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warehouse,
                    color: AccountantThemeConfig.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedTargetWarehouseName!,
                      style: AccountantThemeConfig.bodyStyle.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _showWarehouseSelection,
                    child: Text(
                      'تغيير',
                      style: AccountantThemeConfig.bodyStyle.copyWith(
                        color: AccountantThemeConfig.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showWarehouseSelection,
                icon: const Icon(Icons.add),
                label: const Text('اختيار مخزن الوجهة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AccountantThemeConfig.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransferPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.preview,
                color: AccountantThemeConfig.accentBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'معاينة عملية النقل',
                style: AccountantThemeConfig.bodyStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AccountantThemeConfig.accentBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPreviewItem(
            'الطلبات المراد نقلها',
            '${widget.analysis.activeRequests.length} طلب',
            Icons.receipt_long,
          ),
          _buildPreviewItem(
            'المخزن المصدر',
            widget.warehouse.name,
            Icons.warehouse,
          ),
          _buildPreviewItem(
            'المخزن الهدف',
            _selectedTargetWarehouseName ?? 'غير محدد',
            Icons.warehouse,
          ),
          _buildPreviewItem(
            'الوقت المقدر',
            'أقل من 3 ثوانٍ',
            Icons.timer,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.white70,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: AccountantThemeConfig.bodyStyle.copyWith(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AccountantThemeConfig.bodyStyle.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationCheckbox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.dangerRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.dangerRed.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _confirmationChecked,
            onChanged: (value) {
              setState(() {
                _confirmationChecked = value ?? false;
              });
            },
            activeColor: AccountantThemeConfig.dangerRed,
            checkColor: Colors.white,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'أؤكد أنني أفهم عواقب الحذف القسري وأن هذا الإجراء لا يمكن التراجع عنه',
              style: AccountantThemeConfig.bodyStyle.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final canProceed = _selectedTargetWarehouseId != null && _confirmationChecked;

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
              onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'إلغاء',
                style: AccountantThemeConfig.bodyStyle.copyWith(
                  color: Colors.white70,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: canProceed && !_isProcessing ? _executeForceDelete : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.dangerRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isProcessing
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'تنفيذ الحذف القسري',
                      style: AccountantThemeConfig.bodyStyle.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showWarehouseSelection() async {
    final result = await showDialog<AvailableWarehouse>(
      context: context,
      builder: (context) => WarehouseSelectionDialog(
        sourceWarehouseId: widget.warehouse.id,
        sourceWarehouseName: widget.warehouse.name,
        ordersToTransfer: widget.analysis.activeRequests.length,
        onWarehouseSelected: (id, name) {
          setState(() {
            _selectedTargetWarehouseId = id;
            _selectedTargetWarehouseName = name;
            _showTransferPreview = true;
          });
        },
      ),
    );

    if (result != null) {
      setState(() {
        _selectedTargetWarehouseId = result.id;
        _selectedTargetWarehouseName = result.name;
        _showTransferPreview = true;
      });
    }
  }

  Future<void> _executeForceDelete() async {
    if (_selectedTargetWarehouseId == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      AppLogger.info('🔥 بدء الحذف القسري للمخزن: ${widget.warehouse.name}');

      // استدعاء دالة الحذف القسري
      widget.onForceDelete?.call(_selectedTargetWarehouseId!);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في الحذف القسري: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في الحذف القسري: $e'),
            backgroundColor: AccountantThemeConfig.dangerRed,
          ),
        );

        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}
