import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/warehouse_inventory_model.dart';
import '../../providers/warehouse_provider.dart';
import '../../providers/supabase_provider.dart';
import '../common/enhanced_product_image.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';

/// بطاقة مخزون تفاعلية مع إمكانيات التحرير والحذف والنقل
class InteractiveInventoryCard extends StatelessWidget {
  final WarehouseInventoryModel inventoryItem;
  final String currentWarehouseId;
  final VoidCallback? onRefresh;

  const InteractiveInventoryCard({
    Key? key,
    required this.inventoryItem,
    required this.currentWarehouseId,
    this.onRefresh,
  }) : super(key: key);

  /// لون المخزون بناءً على حالة المخزون
  Color get stockColor {
    final isLowStock = inventoryItem.quantity <= (inventoryItem.minimumStock ?? 10);
    return isLowStock ? AccountantThemeConfig.warningOrange : AccountantThemeConfig.primaryGreen;
  }

  @override
  Widget build(BuildContext context) {
    // إضافة تسجيل للتحقق من القيم المعروضة
    AppLogger.info('🔍 UI عرض المنتج ${inventoryItem.productId}: quantity=${inventoryItem.quantity}, quantityPerCarton=${inventoryItem.quantityPerCarton}, cartonsCount=${inventoryItem.cartonsCount}');

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AccountantThemeConfig.cardBackground1,
            AccountantThemeConfig.cardBackground2.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: stockColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: stockColor.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showProductDetails(context),
          onLongPress: () => _showActionMenu(context),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 12),
                _buildProductInfo(),
                const SizedBox(height: 12),
                _buildQuantityInfo(),
                const SizedBox(height: 12),
                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: stockColor.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: inventoryItem.product != null
                    ? EnhancedProductImage(
                        product: inventoryItem.product!,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(16),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: AccountantThemeConfig.greenGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.inventory_2,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
              ),
              // مؤشر حالة المخزون
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: stockColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                inventoryItem.product?.name ?? 'منتج ${inventoryItem.productId}',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                'رقم المنتج: ${inventoryItem.productId}',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              // معلومات إضافية عن الفئة
              if (inventoryItem.product?.category != null)
                Text(
                  inventoryItem.product!.category,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AccountantThemeConfig.primaryGreen.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        _buildStockIndicator(),
      ],
    );
  }

  Widget _buildStockIndicator() {
    final isLowStock = inventoryItem.quantity <= (inventoryItem.minimumStock ?? 10);
    final color = isLowStock ? AccountantThemeConfig.warningOrange : AccountantThemeConfig.primaryGreen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLowStock ? Icons.warning_rounded : Icons.check_circle_rounded,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(height: 2),
          Text(
            '${inventoryItem.quantity}',
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            'قطعة',
            style: GoogleFonts.cairo(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (inventoryItem.product?.description != null) ...[
          Text(
            inventoryItem.product!.description!,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.7),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            if (inventoryItem.product?.category != null) ...[
              Icon(
                Icons.category,
                size: 16,
                color: Colors.white.withOpacity(0.6),
              ),
              const SizedBox(width: 4),
              Text(
                inventoryItem.product!.category!,
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 16),
            ],
            if (inventoryItem.product?.sku != null) ...[
              Icon(
                Icons.qr_code,
                size: 16,
                color: Colors.white.withOpacity(0.6),
              ),
              const SizedBox(width: 4),
              Text(
                inventoryItem.product!.sku!,
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildQuantityInfo() {
    return Column(
      children: [
        // الصف الأول - الكمية والحدود
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildQuantityItem(
                  'الكمية الحالية',
                  inventoryItem.quantity.toString(),
                  AccountantThemeConfig.primaryGreen,
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: Colors.white.withOpacity(0.2),
              ),
              Expanded(
                child: _buildQuantityItem(
                  'الحد الأدنى',
                  (inventoryItem.minimumStock ?? 0).toString(),
                  AccountantThemeConfig.warningOrange,
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: Colors.white.withOpacity(0.2),
              ),
              Expanded(
                child: _buildQuantityItem(
                  'الحد الأقصى',
                  (inventoryItem.maximumStock ?? 0).toString(),
                  AccountantThemeConfig.accentBlue,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // الصف الثاني - معلومات الكراتين
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                AccountantThemeConfig.primaryGreen.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              // أيقونة الكراتين
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.all_inbox_outlined,
                  color: AccountantThemeConfig.primaryGreen,
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              // معلومات الكراتين
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'عدد الكراتين: ',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          inventoryItem.cartonsDisplayText,
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: AccountantThemeConfig.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'الكمية في الكرتونة: ',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.6),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          inventoryItem.quantityPerCartonDisplayText,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // عدد الكراتين كرقم كبير
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      inventoryItem.cartonsCount.toString(),
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        color: AccountantThemeConfig.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'كرتونة',
                      style: GoogleFonts.cairo(
                        fontSize: 10,
                        color: AccountantThemeConfig.primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: AccountantThemeConfig.headlineSmall.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: Colors.white.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            context,
            'تعديل الكمية',
            Icons.edit,
            AccountantThemeConfig.primaryGreen,
            () => _showEditQuantityDialog(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionButton(
            context,
            'نقل',
            Icons.swap_horiz,
            AccountantThemeConfig.accentBlue,
            () => _showTransferDialog(context),
          ),
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          context,
          'حذف',
          Icons.delete,
          AccountantThemeConfig.warningOrange,
          () => _showDeleteConfirmation(context),
          isCompact: true,
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    bool isCompact = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: isCompact ? const SizedBox.shrink() : Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
        elevation: 0,
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 12 : 16,
          vertical: 8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
      ),
    );
  }

  void _showProductDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardBackground1,
        title: Text(
          'تفاصيل المنتج',
          style: AccountantThemeConfig.headlineSmall,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('اسم المنتج', inventoryItem.product?.name ?? 'غير محدد'),
            _buildDetailRow('رقم المنتج', inventoryItem.productId),
            _buildDetailRow('الوصف', inventoryItem.product?.description ?? 'غير محدد'),
            _buildDetailRow('الفئة', inventoryItem.product?.category ?? 'غير محدد'),
            _buildDetailRow('الكمية الحالية', inventoryItem.quantity.toString()),
            _buildDetailRow('عدد الكراتين', inventoryItem.cartonsDisplayText),
            _buildDetailRow('الكمية في الكرتونة', inventoryItem.quantityPerCartonDisplayText),
            _buildDetailRow('آخر تحديث', _formatDate(inventoryItem.lastUpdated)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إغلاق',
              style: GoogleFonts.cairo(color: AccountantThemeConfig.primaryGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AccountantThemeConfig.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showActionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AccountantThemeConfig.cardBackground1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              inventoryItem.product?.name ?? 'منتج ${inventoryItem.productId}',
              style: AccountantThemeConfig.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildMenuOption(
              context,
              'تعديل الكمية',
              Icons.edit,
              AccountantThemeConfig.primaryGreen,
              () {
                Navigator.pop(context);
                _showEditQuantityDialog(context);
              },
            ),
            _buildMenuOption(
              context,
              'نقل إلى مخزن آخر',
              Icons.swap_horiz,
              AccountantThemeConfig.accentBlue,
              () {
                Navigator.pop(context);
                _showTransferDialog(context);
              },
            ),
            _buildMenuOption(
              context,
              'عرض التفاصيل',
              Icons.info,
              Colors.white.withOpacity(0.7),
              () {
                Navigator.pop(context);
                _showProductDetails(context);
              },
            ),
            _buildMenuOption(
              context,
              'حذف من المخزن',
              Icons.delete,
              AccountantThemeConfig.warningOrange,
              () {
                Navigator.pop(context);
                _showDeleteConfirmation(context);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: color.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: color.withOpacity(0.5),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditQuantityDialog(BuildContext context) {
    final quantityController = TextEditingController(
      text: inventoryItem.quantity.toString(),
    );
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardBackground1,
        title: Text(
          'تعديل الكمية',
          style: AccountantThemeConfig.headlineSmall,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              style: AccountantThemeConfig.bodyMedium,
              decoration: InputDecoration(
                labelText: 'الكمية الجديدة',
                labelStyle: GoogleFonts.cairo(color: Colors.white.withOpacity(0.7)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AccountantThemeConfig.primaryGreen),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: AccountantThemeConfig.bodyMedium,
              decoration: InputDecoration(
                labelText: 'سبب التعديل',
                labelStyle: GoogleFonts.cairo(color: Colors.white.withOpacity(0.7)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AccountantThemeConfig.primaryGreen),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(color: Colors.white.withOpacity(0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () => _updateQuantity(context, quantityController, reasonController),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'تحديث',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _updateQuantity(
    BuildContext context,
    TextEditingController quantityController,
    TextEditingController reasonController,
  ) async {
    final newQuantity = int.tryParse(quantityController.text);
    if (newQuantity == null || newQuantity < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يرجى إدخال كمية صحيحة',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AccountantThemeConfig.warningOrange,
        ),
      );
      return;
    }

    final quantityChange = (newQuantity - inventoryItem.quantity).toInt();
    if (quantityChange == 0) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pop();

    final warehouseProvider = Provider.of<WarehouseProvider>(context, listen: false);
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final currentUser = supabaseProvider.user;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يجب تسجيل الدخول أولاً',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AccountantThemeConfig.warningOrange,
        ),
      );
      return;
    }

    final success = await warehouseProvider.updateProductQuantity(
      warehouseId: currentWarehouseId,
      productId: inventoryItem.productId,
      quantityChange: quantityChange,
      performedBy: currentUser.id,
      reason: reasonController.text.isNotEmpty
          ? reasonController.text
          : 'تعديل كمية المنتج',
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تحديث الكمية بنجاح',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AccountantThemeConfig.primaryGreen,
        ),
      );
      onRefresh?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            warehouseProvider.error ?? 'فشل في تحديث الكمية',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AccountantThemeConfig.warningOrange,
        ),
      );
    }
  }

  void _showTransferDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'ميزة النقل ستكون متاحة قريباً',
          style: GoogleFonts.cairo(),
        ),
        backgroundColor: AccountantThemeConfig.accentBlue,
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardBackground1,
        title: Text(
          'تأكيد الحذف',
          style: AccountantThemeConfig.headlineSmall,
        ),
        content: Text(
          'هل أنت متأكد من حذف "${inventoryItem.product?.name ?? inventoryItem.productId}" من المخزن؟\n\nسيتم سحب جميع الكمية المتوفرة (${inventoryItem.quantity}).',
          style: AccountantThemeConfig.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(color: Colors.white.withOpacity(0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () => _deleteProduct(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.warningOrange,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'حذف',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteProduct(BuildContext context) async {
    Navigator.of(context).pop();

    final warehouseProvider = Provider.of<WarehouseProvider>(context, listen: false);
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final currentUser = supabaseProvider.user;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يجب تسجيل الدخول أولاً',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AccountantThemeConfig.warningOrange,
        ),
      );
      return;
    }

    final success = await warehouseProvider.removeProductFromWarehouse(
      warehouseId: currentWarehouseId,
      productId: inventoryItem.productId,
      performedBy: currentUser.id,
      reason: 'حذف المنتج من المخزن',
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم حذف المنتج من المخزن بنجاح',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AccountantThemeConfig.primaryGreen,
        ),
      );
      onRefresh?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            warehouseProvider.error ?? 'فشل في حذف المنتج',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AccountantThemeConfig.warningOrange,
        ),
      );
    }
  }
}
