import 'package:flutter/material.dart';

import 'package:intl/intl.dart' as intl;
import 'package:smartbiztracker_new/widgets/admin/product_management_widget.dart';

class SamaAdminDashboardWidget extends StatelessWidget {

  const SamaAdminDashboardWidget({
    super.key,
    required this.dashboardData,
    required this.isLoading,
    this.errorMessage,
    this.onRefresh,
  });
  final Map<String, dynamic>? dashboardData;
  final bool isLoading;
  final String? errorMessage;
  final Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('جاري تحميل بيانات لوحة التحكم...', style: theme.textTheme.bodyLarge),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 8),
            Text('حدث خطأ أثناء تحميل البيانات', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(errorMessage!, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (dashboardData == null || dashboardData!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text('لا توجد بيانات لعرضها', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('تحديث البيانات'),
            ),
          ],
        ),
      );
    }

    // استخراج البيانات المطلوبة من dashboardData
    final analytics = dashboardData!['analytics'] ?? {};
    final salesData = analytics['sales'] ?? {};
    final productsData = analytics['products'] ?? {};
    final inventoryData = analytics['inventory'] ?? {};
    final usersData = analytics['users'] ?? {};

    // استخراج بيانات المبيعات الحقيقية
    final totalSales = salesData['total_invoices'] ?? 0;
    final totalRevenue = salesData['total_amount'] ?? 0.0;
    final completedInvoices = salesData['completed_invoices'] ?? 0;
    final pendingInvoices = salesData['pending_invoices'] ?? 0;

    // استخراج بيانات المنتجات الحقيقية - تم تصحيح الوصول إلى القيم
    final totalProducts = productsData['total'] ?? 0;
    final featuredProducts = productsData['featured'] ?? 0;
    final outOfStockCount = productsData['out_of_stock'] ?? 0;

    // استخراج قيم المخزون بشكل صحيح - تأكد من الوصول للمسار الصحيح
    final inventoryCost = productsData['inventory_cost'] ??
                         (dashboardData!['inventory_cost'] ?? 0.0);
    final inventoryValue = productsData['inventory_value'] ??
                          (dashboardData!['inventory_value'] ?? 0.0);

    // استخراج بيانات المستخدمين الحقيقية
    final totalUsers = usersData['total'] ?? 0;
    final activeUsers = usersData['active'] ?? 0;

    // استخراج بيانات المخزون
    final inventoryMovement = inventoryData['movement'] ?? {};
    final totalQuantityChange = inventoryMovement['total_quantity_change'] ?? 0;

    // بيانات الفواتير الحديثة
    final recentInvoices = dashboardData!['recent_invoices'] as List? ?? [];
    final lowStockProducts = dashboardData!['low_stock_products'] as List? ?? [];

    // حساب الربح المتوقع
    final expectedProfit = (inventoryValue - inventoryCost).toDouble();

    return RefreshIndicator(
      onRefresh: () async {
        if (onRefresh != null) {
          onRefresh!();
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SAMA Store header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.dashboard_rounded,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'لوحة تحكم سما',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'إحصائيات وبيانات مفصلة لأعمالك',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Key stats cards - Updated with inventory values and product counts
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.3 : 0.9,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Inventory purchase value (cost)
                _buildStatCard(
                  context: context,
                  title: 'قيمة المخزون (تكلفة)',
                  value: '${inventoryCost.toStringAsFixed(2)} جنيه',
                  subtitle: 'سعر الشراء',
                  icon: Icons.inventory_2,
                  color: Colors.blue,
                ),
                // Inventory selling price value
                _buildStatCard(
                  context: context,
                  title: 'قيمة المخزون (بيع)',
                  value: '${inventoryValue.toStringAsFixed(2)} جنيه',
                  subtitle: 'سعر البيع',
                  icon: Icons.monetization_on,
                  color: Colors.green,
                ),
                // Total products
                _buildStatCard(
                  context: context,
                  title: 'إجمالي المنتجات',
                  value: totalProducts.toString(),
                  subtitle: 'منتج',
                  icon: Icons.category,
                  color: theme.colorScheme.primary,
                ),
                // Out of stock products
                _buildStatCard(
                  context: context,
                  title: 'منتجات نفذت',
                  value: outOfStockCount.toString(),
                  subtitle: 'منتج',
                  icon: Icons.remove_shopping_cart,
                  color: Colors.red,
                ),
                // Expected profit
                _buildStatCard(
                  context: context,
                  title: 'الربح المتوقع',
                  value: '${expectedProfit.toStringAsFixed(2)} جنيه',
                  subtitle: 'إجمالي',
                  icon: Icons.trending_up,
                  color: Colors.purple,
                ),
                // Total inventory movement
                _buildStatCard(
                  context: context,
                  title: 'حركة المخزون',
                  value: totalQuantityChange.toString(),
                  subtitle: 'وحدة',
                  icon: Icons.swap_horiz,
                  color: Colors.orange,
                ),
                // Total sales
                _buildStatCard(
                  context: context,
                  title: 'إجمالي المبيعات',
                  value: totalSales.toString(),
                  subtitle: 'طلب',
                  icon: Icons.point_of_sale,
                  color: Colors.teal,
                ),
                // Total revenue
                _buildStatCard(
                  context: context,
                  title: 'إجمالي الإيرادات',
                  value: '${totalRevenue.toStringAsFixed(2)} جنيه',
                  subtitle: '',
                  icon: Icons.attach_money,
                  color: theme.colorScheme.secondary,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Products stats
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory_2,
                    size: 24,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'تقرير المخزون والمنتجات',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              height: 500, // Set a fixed height for the widget
              child: ProductManagementWidget(
                showHeader: false,
                isEmbedded: true,
                maxHeight: 500,
                hideVisibleFilter: true,
              ),
            ),

            const SizedBox(height: 24),

            // Recent invoices
            if (recentInvoices.isNotEmpty)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أحدث الفواتير',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 220,
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: recentInvoices.length > 5 ? 5 : recentInvoices.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final invoice = recentInvoices[index];
                            final date = DateTime.tryParse((invoice['created_at'] as String?) ?? '');
                            final formattedDate = date != null
                                ? intl.DateFormat('yyyy-MM-dd').format(date)
                                : 'تاريخ غير معروف';

                            final statusColors = {
                              'pending': Colors.orange,
                              'completed': Colors.green,
                              'cancelled': Colors.red,
                            };

                            final status = invoice['status'] as String? ?? 'pending';
                            final statusColor = statusColors[status] ?? Colors.grey;

                            return ListTile(
                              title: Text('فاتورة #${invoice['id'] ?? '?'}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text((invoice['customer_name'] as String?) ?? 'عميل غير معروف'),
                                  Text(formattedDate),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'LE ${(invoice['final_amount'] as num? ?? 0).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      _getStatusText(status),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: statusColor,
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Title at the top
            Text(
              title,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 8),
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 8),
            // Value with adaptive text size
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Subtitle
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }
}