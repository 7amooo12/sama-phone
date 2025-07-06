import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/warehouse_model.dart';
import '../../providers/warehouse_provider.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';
import '../../widgets/common/custom_loader.dart';

/// نموذج بيانات المخزن المتاح للنقل
class AvailableWarehouse {
  final String id;
  final String name;
  final String location;
  final int totalCapacity;
  final int currentInventoryCount;
  final int availableCapacity;
  final int suitabilityScore;

  const AvailableWarehouse({
    required this.id,
    required this.name,
    required this.location,
    required this.totalCapacity,
    required this.currentInventoryCount,
    required this.availableCapacity,
    required this.suitabilityScore,
  });

  /// لون مؤشر الملاءمة
  Color get suitabilityColor {
    if (suitabilityScore >= 80) return AccountantThemeConfig.primaryGreen;
    if (suitabilityScore >= 60) return AccountantThemeConfig.accentBlue;
    if (suitabilityScore >= 40) return AccountantThemeConfig.warningOrange;
    return AccountantThemeConfig.dangerRed;
  }

  /// نص مستوى الملاءمة
  String get suitabilityText {
    if (suitabilityScore >= 80) return 'ممتاز';
    if (suitabilityScore >= 60) return 'جيد';
    if (suitabilityScore >= 40) return 'مقبول';
    return 'ضعيف';
  }

  /// نسبة الاستخدام
  double get usagePercentage {
    if (totalCapacity == 0) return 0.0;
    return (currentInventoryCount / totalCapacity).clamp(0.0, 1.0);
  }
}

/// حوار اختيار المخزن الهدف لنقل الطلبات
class WarehouseSelectionDialog extends StatefulWidget {
  final String sourceWarehouseId;
  final String sourceWarehouseName;
  final int ordersToTransfer;
  final Function(String targetWarehouseId, String targetWarehouseName)? onWarehouseSelected;

  const WarehouseSelectionDialog({
    super.key,
    required this.sourceWarehouseId,
    required this.sourceWarehouseName,
    required this.ordersToTransfer,
    this.onWarehouseSelected,
  });

  @override
  State<WarehouseSelectionDialog> createState() => _WarehouseSelectionDialogState();
}

class _WarehouseSelectionDialogState extends State<WarehouseSelectionDialog> {
  List<AvailableWarehouse> _availableWarehouses = [];
  AvailableWarehouse? _selectedWarehouse;
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAvailableWarehouses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableWarehouses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // محاكاة تحميل المخازن المتاحة - سيتم استبدالها بالاستدعاء الفعلي لقاعدة البيانات
      await Future.delayed(const Duration(milliseconds: 800));
      
      final warehouseProvider = context.read<WarehouseProvider>();
      final allWarehouses = warehouseProvider.warehouses;
      
      // تصفية المخازن المتاحة (استبعاد المخزن المصدر)
      final availableWarehouses = allWarehouses
          .where((w) => w.id != widget.sourceWarehouseId)
          .map((w) => AvailableWarehouse(
                id: w.id,
                name: w.name,
                location: w.location ?? 'غير محدد',
                totalCapacity: 1000, // قيمة افتراضية - ستأتي من قاعدة البيانات
                currentInventoryCount: 150, // قيمة افتراضية - ستأتي من قاعدة البيانات
                availableCapacity: 850, // قيمة افتراضية - ستأتي من قاعدة البيانات
                suitabilityScore: 85, // قيمة افتراضية - ستحسب من قاعدة البيانات
              ))
          .toList();

      setState(() {
        _availableWarehouses = availableWarehouses;
      });
    } catch (e) {
      setState(() {
        _error = 'فشل في تحميل المخازن المتاحة: $e';
      });
      AppLogger.error('خطأ في تحميل المخازن المتاحة: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<AvailableWarehouse> get _filteredWarehouses {
    if (_searchQuery.isEmpty) return _availableWarehouses;
    
    return _availableWarehouses.where((warehouse) {
      return warehouse.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             warehouse.location.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
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
          border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryColor),
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _error != null
                      ? _buildErrorState()
                      : _buildWarehousesList(),
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
              color: AccountantThemeConfig.primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.swap_horiz,
              color: AccountantThemeConfig.primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اختيار مخزن الوجهة',
                  style: AccountantThemeConfig.headingStyle.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'نقل ${widget.ordersToTransfer} طلب من ${widget.sourceWarehouseName}',
                  style: AccountantThemeConfig.bodyStyle.copyWith(
                    fontSize: 14,
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

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        style: AccountantThemeConfig.bodyStyle,
        decoration: InputDecoration(
          hintText: 'البحث عن مخزن (الاسم، الموقع)...',
          hintStyle: AccountantThemeConfig.bodyStyle.copyWith(
            color: Colors.white54,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: AccountantThemeConfig.primaryColor,
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AccountantThemeConfig.primaryColor,
              width: 2,
            ),
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomLoader(
            size: 60,
            color: AccountantThemeConfig.primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'جاري تحميل المخازن المتاحة...',
            style: AccountantThemeConfig.bodyStyle.copyWith(
              color: Colors.white70,
            ),
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
          Icon(
            Icons.error_outline,
            color: AccountantThemeConfig.dangerRed,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: AccountantThemeConfig.bodyStyle.copyWith(
              color: AccountantThemeConfig.dangerRed,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAvailableWarehouses,
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryColor,
            ),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildWarehousesList() {
    final filteredWarehouses = _filteredWarehouses;

    if (filteredWarehouses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warehouse,
              color: Colors.white54,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'لا توجد مخازن متاحة للنقل'
                  : 'لا توجد مخازن تطابق البحث',
              style: AccountantThemeConfig.bodyStyle.copyWith(
                color: Colors.white54,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredWarehouses.length,
      itemBuilder: (context, index) {
        final warehouse = filteredWarehouses[index];
        return _buildWarehouseCard(warehouse);
      },
    );
  }

  Widget _buildWarehouseCard(AvailableWarehouse warehouse) {
    final isSelected = _selectedWarehouse?.id == warehouse.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: isSelected
            ? AccountantThemeConfig.cardGradient
            : LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.05),
                  Colors.white.withValues(alpha: 0.02),
                ],
              ),
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryColor)
            : Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _selectedWarehouse = warehouse;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: warehouse.suitabilityColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.warehouse,
                        color: warehouse.suitabilityColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            warehouse.name,
                            style: AccountantThemeConfig.bodyStyle.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            warehouse.location,
                            style: AccountantThemeConfig.bodyStyle.copyWith(
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
                        color: warehouse.suitabilityColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        warehouse.suitabilityText,
                        style: AccountantThemeConfig.bodyStyle.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: warehouse.suitabilityColor,
                        ),
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check_circle,
                        color: AccountantThemeConfig.primaryColor,
                        size: 24,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                _buildCapacityIndicator(warehouse),
                const SizedBox(height: 8),
                _buildWarehouseStats(warehouse),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOut,
    );
  }

  Widget _buildCapacityIndicator(AvailableWarehouse warehouse) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'السعة المستخدمة',
              style: AccountantThemeConfig.bodyStyle.copyWith(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
            Text(
              '${(warehouse.usagePercentage * 100).toInt()}%',
              style: AccountantThemeConfig.bodyStyle.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: warehouse.suitabilityColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: warehouse.usagePercentage,
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(warehouse.suitabilityColor),
          minHeight: 6,
        ),
      ],
    );
  }

  Widget _buildWarehouseStats(AvailableWarehouse warehouse) {
    return Row(
      children: [
        _buildStatItem(
          'السعة الإجمالية',
          '${warehouse.totalCapacity}',
          Icons.inventory,
        ),
        const SizedBox(width: 16),
        _buildStatItem(
          'المخزون الحالي',
          '${warehouse.currentInventoryCount}',
          Icons.inventory_2,
        ),
        const SizedBox(width: 16),
        _buildStatItem(
          'السعة المتاحة',
          '${warehouse.availableCapacity}',
          Icons.add_box,
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.white54,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AccountantThemeConfig.bodyStyle.copyWith(
                    fontSize: 10,
                    color: Colors.white54,
                  ),
                ),
                Text(
                  value,
                  style: AccountantThemeConfig.bodyStyle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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
              onPressed: _selectedWarehouse != null
                  ? () {
                      widget.onWarehouseSelected?.call(
                        _selectedWarehouse!.id,
                        _selectedWarehouse!.name,
                      );
                      Navigator.of(context).pop(_selectedWarehouse);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'تأكيد الاختيار',
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
}
