import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/models/manufacturing/tool_deletion_info.dart';
import 'package:smartbiztracker_new/widgets/common/custom_loader.dart';

/// حوار حذف أداة التصنيع مع معلومات مفصلة عن القيود والتحذيرات
class ToolDeletionDialog extends StatefulWidget {
  final ToolDeletionInfo deletionInfo;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const ToolDeletionDialog({
    super.key,
    required this.deletionInfo,
    this.onConfirm,
    this.onCancel,
  });

  @override
  State<ToolDeletionDialog> createState() => _ToolDeletionDialogState();
}

class _ToolDeletionDialogState extends State<ToolDeletionDialog> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(20),
          border: AccountantThemeConfig.glowBorder(
            widget.deletionInfo.canDelete 
                ? AccountantThemeConfig.warningOrange 
                : AccountantThemeConfig.dangerRed,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildContent(),
            _buildActions(),
          ],
        ),
      ).animate().scale(
        duration: 300.ms,
        curve: Curves.easeOutBack,
      ),
    );
  }

  /// بناء رأس الحوار
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.deletionInfo.canDelete 
                ? AccountantThemeConfig.warningOrange.withValues(alpha: 0.3)
                : AccountantThemeConfig.dangerRed.withValues(alpha: 0.3),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
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
              color: widget.deletionInfo.canDelete 
                  ? AccountantThemeConfig.warningOrange.withValues(alpha: 0.2)
                  : AccountantThemeConfig.dangerRed.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.deletionInfo.canDelete 
                  ? Icons.warning_amber_rounded
                  : Icons.block_rounded,
              color: widget.deletionInfo.canDelete 
                  ? AccountantThemeConfig.warningOrange
                  : AccountantThemeConfig.dangerRed,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.deletionInfo.canDelete ? 'تأكيد حذف الأداة' : 'لا يمكن حذف الأداة',
                  style: AccountantThemeConfig.headlineSmall.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.deletionInfo.toolName,
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// بناء محتوى الحوار
  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.deletionInfo.canDelete) ...[
            _buildBlockingReasonCard(),
            const SizedBox(height: 16),
            _buildSolutionCard(),
          ] else ...[
            _buildWarningCard(),
            const SizedBox(height: 16),
            _buildImpactSummary(),
          ],
        ],
      ),
    );
  }

  /// بناء بطاقة سبب المنع
  Widget _buildBlockingReasonCard() {
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
          Icon(
            Icons.error_outline,
            color: AccountantThemeConfig.dangerRed,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.deletionInfo.blockingReason,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء بطاقة الحل المقترح
  Widget _buildSolutionCard() {
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
                Icons.lightbulb_outline,
                color: AccountantThemeConfig.accentBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'الحلول المقترحة:',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: AccountantThemeConfig.accentBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• احذف وصفات الإنتاج المرتبطة بهذه الأداة أولاً\n'
            '• أو استبدل الأداة في الوصفات بأداة أخرى\n'
            '• ثم حاول حذف الأداة مرة أخرى',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  /// بناء بطاقة التحذير
  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.warningOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.warningOrange.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AccountantThemeConfig.warningOrange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'تحذير مهم:',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: AccountantThemeConfig.warningOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'سيتم حذف الأداة نهائياً مع جميع البيانات المرتبطة بها. هذا الإجراء لا يمكن التراجع عنه.',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// بناء ملخص التأثير
  Widget _buildImpactSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'سيتم حذف:',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.deletionInfo.hasProductionRecipes)
            _buildImpactItem(
              Icons.receipt_long,
              '${widget.deletionInfo.productionRecipesCount} وصفة إنتاج',
              AccountantThemeConfig.warningOrange,
            ),
          if (widget.deletionInfo.hasUsageHistory)
            _buildImpactItem(
              Icons.history,
              '${widget.deletionInfo.usageHistoryCount} سجل استخدام',
              AccountantThemeConfig.accentBlue,
            ),
        ],
      ),
    );
  }

  /// بناء عنصر تأثير
  Widget _buildImpactItem(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  /// بناء أزرار الإجراءات
  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: _isDeleting ? null : () {
                widget.onCancel?.call();
                Navigator.of(context).pop(false);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'إلغاء',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (widget.deletionInfo.canDelete)
            Expanded(
              child: ElevatedButton(
                onPressed: _isDeleting ? null : () async {
                  setState(() => _isDeleting = true);
                  widget.onConfirm?.call();
                  Navigator.of(context).pop(true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AccountantThemeConfig.dangerRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isDeleting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('حذف نهائياً'),
              ),
            ),
        ],
      ),
    );
  }
}
