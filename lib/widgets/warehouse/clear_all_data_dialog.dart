/// حوار تأكيد مسح جميع بيانات الصرف
/// Confirmation dialog for clearing all dispatch data

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';

class ClearAllDataDialog extends StatefulWidget {
  final int requestCount;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ClearAllDataDialog({
    super.key,
    required this.requestCount,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<ClearAllDataDialog> createState() => _ClearAllDataDialogState();
}

class _ClearAllDataDialogState extends State<ClearAllDataDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.cardGradient,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AccountantThemeConfig.warningOrange.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AccountantThemeConfig.warningOrange.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // رأس الحوار
                    _buildDialogHeader(),
                    
                    // محتوى الحوار
                    _buildDialogContent(),
                    
                    // أزرار الحوار
                    _buildDialogActions(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// بناء رأس الحوار
  Widget _buildDialogHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.warningOrange.withValues(alpha: 0.2),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AccountantThemeConfig.warningOrange,
                  AccountantThemeConfig.warningOrange.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AccountantThemeConfig.warningOrange.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.warning_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تحذير!',
                  style: GoogleFonts.cairo(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AccountantThemeConfig.warningOrange,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'عملية خطيرة',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// بناء محتوى الحوار
  Widget _buildDialogContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مسح جميع بيانات الصرف',
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          // تحذير رئيسي
          Container(
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
                      Icons.delete_forever,
                      color: AccountantThemeConfig.warningOrange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'سيتم حذف البيانات التالية نهائياً:',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AccountantThemeConfig.warningOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // قائمة البيانات المراد حذفها
                _buildDataList(),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // تحذير إضافي
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Colors.red,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'هذا الإجراء لا يمكن التراجع عنه!',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// بناء قائمة البيانات المراد حذفها
  Widget _buildDataList() {
    return Column(
      children: [
        _buildDataItem(
          icon: Icons.receipt_long,
          title: 'طلبات الصرف',
          count: widget.requestCount,
          description: 'جميع طلبات صرف المخزون',
        ),
        const SizedBox(height: 8),
        _buildDataItem(
          icon: Icons.inventory_2,
          title: 'عناصر الطلبات',
          count: null,
          description: 'جميع المنتجات المرتبطة بالطلبات',
        ),
        const SizedBox(height: 8),
        _buildDataItem(
          icon: Icons.history,
          title: 'سجل العمليات',
          count: null,
          description: 'تاريخ جميع المعاملات والتحديثات',
        ),
      ],
    );
  }

  /// بناء عنصر بيانات
  Widget _buildDataItem({
    required IconData icon,
    required String title,
    required String description,
    int? count,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.7),
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AccountantThemeConfig.warningOrange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                description,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// بناء أزرار الحوار
  Widget _buildDialogActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          // زر الإلغاء (مميز)
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: widget.onCancel,
              icon: const Icon(
                Icons.close,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                'إلغاء',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 5,
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // زر التأكيد (خطير)
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              onPressed: widget.onConfirm,
              icon: const Icon(
                Icons.delete_forever,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                'نعم، احذف جميع البيانات',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.warningOrange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 5,
                shadowColor: AccountantThemeConfig.warningOrange.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
