import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/warehouse_provider.dart';
import 'package:google_fonts/google_fonts.dart';

/// عرض إحصائيات المخزن الشاملة
class WarehouseStatsOverview extends StatelessWidget {
  const WarehouseStatsOverview({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WarehouseProvider>(
      builder: (context, warehouseProvider, child) {
        if (warehouseProvider.isLoading) {
          return _buildLoadingState();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // عنوان القسم
            Text(
              'نظرة عامة على المخازن',
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // الإحصائيات الرئيسية
            _buildMainStats(warehouseProvider),
            const SizedBox(height: 16),

            // إحصائيات المخزن المحدد (إذا وجد)
            if (warehouseProvider.selectedWarehouse != null) ...[
              _buildSelectedWarehouseStats(warehouseProvider),
              const SizedBox(height: 16),
            ],

            // تحذيرات المخزون
            _buildStockAlerts(warehouseProvider),
          ],
        );
      },
    );
  }

  /// بناء حالة التحميل
  Widget _buildLoadingState() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withOpacity(0.3),
            Colors.black.withOpacity(0.1),
          ],
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF10B981),
        ),
      ),
    );
  }

  /// بناء الإحصائيات الرئيسية
  Widget _buildMainStats(WarehouseProvider provider) {
    final totalWarehouses = provider.warehouses.length;
    final activeWarehouses = provider.activeWarehouses.length;
    final totalProducts = provider.totalProductsInSelectedWarehouse;
    final totalQuantity = provider.totalQuantityInSelectedWarehouse;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'إجمالي المخازن',
            value: totalWarehouses.toString(),
            subtitle: '$activeWarehouses نشط',
            icon: Icons.warehouse_rounded,
            color: const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'إجمالي المنتجات',
            value: totalProducts.toString(),
            subtitle: 'في المخزن المحدد',
            icon: Icons.inventory_2_rounded,
            color: const Color(0xFF10B981),
          ),
        ),
      ],
    );
  }

  /// بناء إحصائيات المخزن المحدد
  Widget _buildSelectedWarehouseStats(WarehouseProvider provider) {
    final warehouse = provider.selectedWarehouse!;
    final lowStockCount = provider.lowStockProducts.length;
    final outOfStockCount = provider.outOfStockProducts.length;
    final pendingRequestsCount = provider.pendingRequests.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إحصائيات ${warehouse.name}',
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'مخزون منخفض',
                value: lowStockCount.toString(),
                subtitle: 'منتج',
                icon: Icons.warning_rounded,
                color: const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'نفد المخزون',
                value: outOfStockCount.toString(),
                subtitle: 'منتج',
                icon: Icons.error_rounded,
                color: const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'طلبات معلقة',
                value: pendingRequestsCount.toString(),
                subtitle: 'طلب',
                icon: Icons.pending_actions_rounded,
                color: const Color(0xFF8B5CF6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// بناء تحذيرات المخزون
  Widget _buildStockAlerts(WarehouseProvider provider) {
    final lowStockProducts = provider.lowStockProducts;
    final outOfStockProducts = provider.outOfStockProducts;

    if (lowStockProducts.isEmpty && outOfStockProducts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF10B981).withOpacity(0.1),
          border: Border.all(
            color: const Color(0xFF10B981).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: const Color(0xFF10B981),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'جميع المنتجات متوفرة بكميات كافية',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تحذيرات المخزون',
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),

        // تحذير نفاد المخزون
        if (outOfStockProducts.isNotEmpty)
          _buildAlertCard(
            title: 'منتجات نفد مخزونها',
            count: outOfStockProducts.length,
            color: const Color(0xFFEF4444),
            icon: Icons.error_rounded,
          ),

        if (outOfStockProducts.isNotEmpty && lowStockProducts.isNotEmpty)
          const SizedBox(height: 8),

        // تحذير المخزون المنخفض
        if (lowStockProducts.isNotEmpty)
          _buildAlertCard(
            title: 'منتجات مخزونها منخفض',
            count: lowStockProducts.length,
            color: const Color(0xFFF59E0B),
            icon: Icons.warning_rounded,
          ),
      ],
    );
  }

  /// بناء بطاقة إحصائية
  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withOpacity(0.4),
            Colors.black.withOpacity(0.2),
          ],
        ),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              Text(
                value,
                style: GoogleFonts.cairo(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  /// بناء بطاقة تحذير
  Widget _buildAlertCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withOpacity(0.1),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$count منتج يحتاج إلى انتباه',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
