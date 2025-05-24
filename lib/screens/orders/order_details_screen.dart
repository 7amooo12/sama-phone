import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/order_model.dart';
import 'package:smartbiztracker_new/utils/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';

class OrderDetailsScreen extends StatelessWidget {
  final OrderModel order;

  const OrderDetailsScreen({Key? key, required this.order}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    final screenSize = MediaQuery.of(context).size;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.userRole;
    final canEdit = userRole == 'admin' || userRole == 'owner';
    final canViewPrices = userRole == 'admin' || userRole == 'owner' || userRole == 'accountant';
    final canPrint = userRole == 'admin' || userRole == 'owner' || userRole == 'accountant';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(appLocalizations.translate('order_details') ?? 'تفاصيل الطلب'),
        actions: [
          if (canPrint) ...[
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('جاري طباعة الطلب ${order.orderNumber}'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: Colors.blue.shade700,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
            ),
          ],
          if (canEdit && order.status.toLowerCase() != "delivered" && 
              order.status.toLowerCase() != "cancelled" && 
              order.status.toLowerCase() != "canceled") ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                // تنفيذ وظيفة التعديل
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تعديل الطلب ${order.orderNumber}'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOrderHeader(context),
              const SizedBox(height: 20),
              
              _buildSectionHeader(appLocalizations.translate('customer_info') ?? 'معلومات العميل'),
              _buildCustomerCard(context),
              
              const SizedBox(height: 20),
              
              _buildSectionHeader(appLocalizations.translate('order_items') ?? 'عناصر الطلب'),
              if (order.items.isEmpty) ...[
                _buildEmptyItemsCard(),
              ] else ...[
                _buildProductsGridView(context, canViewPrices),
                if (canViewPrices) _buildOrderSummaryCard(context),
              ],
              
              const SizedBox(height: 20),
              
              if (canViewPrices && order.paymentMethod != null) ...[
                _buildSectionHeader(appLocalizations.translate('payment_info') ?? 'معلومات الدفع'),
                _buildPaymentMethodCard(context),
                const SizedBox(height: 20),
              ],
              
              if (order.notes != null && order.notes!.isNotEmpty) ...[
                _buildSectionHeader(appLocalizations.translate('notes') ?? 'ملاحظات'),
                _buildNotesCard(context),
                const SizedBox(height: 20),
              ],
              
              if (canEdit) _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  // عرض رأس الطلب بشكل محسن
  Widget _buildOrderHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade500],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade200.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'طلب رقم: ${order.orderNumber}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  order.status,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRowLight(
            Icons.calendar_today,
            'تاريخ الطلب:',
            _formatDate(order.createdAt),
          ),
          if (order.deliveryDate != null) ...[
            const SizedBox(height: 8),
            _buildInfoRowLight(
              Icons.delivery_dining,
              'تاريخ التسليم:',
              _formatDate(order.deliveryDate!),
            ),
          ],
        ],
      ),
    );
  }
  
  // إضافة طريقة عرض جديدة على شكل شبكة للمنتجات
  Widget _buildProductsGridView(BuildContext context, bool canViewPrices) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: order.items.length,
              itemBuilder: (context, index) {
                final item = order.items[index];
                return _buildProductGridItem(context, item, canViewPrices);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  // عنصر المنتج في عرض الشبكة
  Widget _buildProductGridItem(BuildContext context, OrderItem item, bool canViewPrices) {
    return InkWell(
      onTap: () {
        if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
          _showProductImageDialog(context, item, canViewPrices);
        }
      },
      child: Card(
        elevation: 4,
        shadowColor: Colors.blue.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // صورة المنتج محسنة
            Expanded(
              flex: 5,
              child: Hero(
                tag: 'product_image_${item.id}',
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    color: Colors.grey.shade50,
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    child: (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: item.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(color: Colors.white),
                            ),
                            errorWidget: (context, url, error) => _buildImageErrorWidget(item.productName),
                          )
                        : _buildImageErrorWidget(item.productName),
                  ),
                ),
              ),
            ),
            // تفاصيل المنتج محسنة
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (canViewPrices) ...[
                          _buildInfoChip(
                            Icons.attach_money,
                            '${item.price.toStringAsFixed(2)}',
                            Colors.green.shade100,
                            Colors.green.shade700,
                          ),
                        ],
                        _buildInfoChip(
                          Icons.shopping_basket,
                          '${item.quantity}',
                          Colors.orange.shade100,
                          Colors.orange.shade700,
                        ),
                      ],
                    ),
                    if (canViewPrices) ...[
                      const SizedBox(height: 8),
                      _buildInfoChip(
                        Icons.calculate,
                        'الإجمالي: ${item.subtotal.toStringAsFixed(2)}',
                        Colors.blue.shade50,
                        Colors.blue.shade700,
                        fullWidth: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // عرض صورة المنتج في حوار منبثق
  void _showProductImageDialog(BuildContext context, OrderItem item, bool canViewPrices) {
    if (item.imageUrl == null || item.imageUrl!.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(
                item.productName,
                style: const TextStyle(fontSize: 16),
              ),
              automaticallyImplyLeading: false,
              backgroundColor: Colors.blue.shade700,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 3,
                child: Hero(
                  tag: 'product_image_${item.id}',
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl!,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        width: double.infinity,
                        height: 300,
                        color: Colors.white,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: double.infinity,
                      height: 300,
                      color: Colors.grey.shade100,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported_rounded,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا يمكن تحميل الصورة',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (canViewPrices) ...[
                        _buildDetailRow(
                          Icons.attach_money,
                          'السعر',
                          item.price.toStringAsFixed(2),
                          Colors.green.shade700,
                        ),
                      ],
                      _buildDetailRow(
                        Icons.shopping_basket,
                        'الكمية',
                        '${item.quantity}',
                        Colors.orange.shade700,
                      ),
                    ],
                  ),
                  if (canViewPrices) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.calculate,
                      'الإجمالي',
                      item.subtotal.toStringAsFixed(2),
                      Colors.blue.shade700,
                    ),
                    if (item.purchasePrice > 0) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.trending_up,
                        'الربح',
                        (item.subtotal - (item.purchasePrice * item.quantity)).toStringAsFixed(2),
                        Colors.green.shade700,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // ويدجت خطأ تحميل الصورة
  Widget _buildImageErrorWidget(String productName) {
    return Container(
      color: Colors.grey.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 32,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 4),
          Text(
            productName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  // عنصر معلومات صغير (Chip)
  Widget _buildInfoChip(IconData icon, String text, Color bgColor, Color fgColor, {bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: fullWidth ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: fgColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: fgColor,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // صف تفاصيل في الحوار المنبثق
  Widget _buildDetailRow(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // ملخص الطلب (المجاميع والربح)
  Widget _buildOrderSummaryCard(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.calculate, color: Colors.blue.shade700),
                ),
                const SizedBox(width: 12),
                const Text(
                  'ملخص الطلب',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Divider(thickness: 1, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'عدد العناصر:',
                  style: TextStyle(fontSize: 15),
                ),
                Text(
                  '${order.items.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'إجمالي الكميات:',
                  style: TextStyle(fontSize: 15),
                ),
                Text(
                  '${order.items.fold<int>(0, (sum, item) => sum + item.quantity)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'إجمالي الطلب:',
                  style: TextStyle(fontSize: 15),
                ),
                Text(
                  order.totalAmount.toStringAsFixed(2),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'إجمالي الربح:',
                  style: TextStyle(fontSize: 15),
                ),
                Text(
                  _calculateProfit(order).toStringAsFixed(2),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: _calculateProfit(order) > 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // بطاقة معلومات العميل
  Widget _buildCustomerCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person, color: Colors.orange.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    order.customerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            if (order.customerPhone != null && order.customerPhone!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildDetailItem(
                icon: Icons.phone,
                title: 'هاتف العميل',
                value: order.customerPhone!,
              ),
            ],
            if (order.address != null && order.address!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                context,
                Icons.location_on,
                'العنوان',
                order.address!,
              ),
            ],
            if (order.warehouse_name != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                context,
                Icons.store,
                'المستودع',
                order.warehouse_name!,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  // بطاقة معلومات الدفع
  Widget _buildPaymentMethodCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.payment, color: Colors.green.shade700),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'طريقة الدفع',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatPaymentMethod(order.paymentMethod!),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // بطاقة الملاحظات
  Widget _buildNotesCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.note, color: Colors.purple.shade700),
                ),
                const SizedBox(width: 12),
                Text(
                  'ملاحظات',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                order.notes!,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // إذا لم يكن هناك عناصر في الطلب
  Widget _buildEmptyItemsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد عناصر في هذا الطلب',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // أزرار الإجراءات في أسفل الصفحة
  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              // Implement print functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('جاري طباعة الطلب ${order.orderNumber}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.print),
            label: const Text('طباعة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          if (order.status.toLowerCase() != "delivered" && 
              order.status.toLowerCase() != "cancelled" && 
              order.status.toLowerCase() != "canceled")
            ElevatedButton.icon(
              onPressed: () {
                // Implement edit functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تعديل الطلب ${order.orderNumber}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.edit),
              label: const Text('تعديل'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  // ترويسة القسم
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
        ],
      ),
    );
  }
  
  // صف معلومات (أسلوب عادي)
  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // صف معلومات (أسلوب فاتح لرأس الطلب)
  Widget _buildInfoRowLight(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
  
  // Helper para mostrar un elemento de detalle con icono y texto
  Widget _buildDetailItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Color _getStatusColor(String status) {
    status = status.toLowerCase();
    
    if (status.contains('complet') || status.contains('تم')) {
      return Colors.green;
    } else if (status.contains('pend') || status.contains('انتظار')) {
      return Colors.orange;
    } else if (status.contains('cancel') || status.contains('ملغي')) {
      return Colors.red;
    } else if (status.contains('process') || status.contains('جاري')) {
      return Colors.blue;
    } else {
      return Colors.grey;
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  String _formatPaymentMethod(String method) {
    // Format payment method for display
    switch (method.toLowerCase()) {
      case 'cash':
      case 'نقدا':
        return 'نقداً';
      case 'credit_card':
      case 'بطاقة ائتمان':
        return 'بطاقة ائتمان';
      case 'bank_transfer':
      case 'تحويل بنكي':
        return 'تحويل بنكي';
      default:
        return method;
    }
  }
  
  double _calculateProfit(OrderModel order) {
    double totalCost = 0.0;
    for (var item in order.items) {
      totalCost += item.purchasePrice * item.quantity;
    }
    return order.totalAmount - totalCost;
  }
} 