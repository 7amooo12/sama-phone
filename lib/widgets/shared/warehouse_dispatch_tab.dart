import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/warehouse_dispatch_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/models/warehouse_dispatch_model.dart';
import 'package:smartbiztracker_new/screens/shared/dispatch_details_screen.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/widgets/shared/add_manual_dispatch_dialog.dart';
import 'package:smartbiztracker_new/widgets/warehouse/clear_all_data_dialog.dart';

/// تبويب صرف المخزون المشترك للمحاسب والأدمن
/// يعرض طلبات الصرف مع إمكانية إضافة طلبات يدوية
class WarehouseDispatchTab extends StatefulWidget {
  final String userRole; // 'admin' or 'accountant'

  const WarehouseDispatchTab({
    super.key,
    required this.userRole,
  });

  @override
  State<WarehouseDispatchTab> createState() => _WarehouseDispatchTabState();
}

class _WarehouseDispatchTabState extends State<WarehouseDispatchTab> {
  @override
  void initState() {
    super.initState();
    // تحميل طلبات الصرف عند فتح التبويب
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDispatchData();
    });
  }

  /// تهيئة بيانات طلبات الصرف مع معالجة الأخطاء المحسنة
  Future<void> _initializeDispatchData() async {
    try {
      AppLogger.info('🚀 بدء تهيئة بيانات طلبات الصرف...');

      final provider = Provider.of<WarehouseDispatchProvider>(context, listen: false);

      // التحقق من حالة المزود
      AppLogger.info('📊 حالة المزود - تحميل: ${provider.isLoading}, خطأ: ${provider.hasError}');
      AppLogger.info('📋 عدد الطلبات المحملة: ${provider.dispatchRequests.length}');

      // تحميل البيانات مع إجبار التحديث
      await provider.loadDispatchRequests(forceRefresh: true);

      AppLogger.info('✅ انتهت تهيئة بيانات طلبات الصرف');
      AppLogger.info('📊 النتيجة النهائية - طلبات: ${provider.dispatchRequests.length}, مفلترة: ${provider.filteredRequests.length}');

    } catch (e) {
      AppLogger.error('❌ خطأ في تهيئة بيانات طلبات الصرف: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'فشل في تحميل بيانات طلبات الصرف',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AccountantThemeConfig.dangerRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WarehouseDispatchProvider>(
      builder: (context, dispatchProvider, child) {
        return Container(
          decoration: const BoxDecoration(
            gradient: AccountantThemeConfig.mainBackgroundGradient,
          ),
          child: Column(
            children: [
              // شريط الأدوات
              _buildToolbar(dispatchProvider),
              
              // فلاتر الحالة
              _buildStatusFilters(dispatchProvider),
              
              // محتوى الطلبات
              Expanded(
                child: _buildDispatchContent(dispatchProvider),
              ),
            ],
          ),
        );
      },
    );
  }

  /// بناء شريط الأدوات
  Widget _buildToolbar(WarehouseDispatchProvider provider) {
    final stats = provider.getRequestsStats();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.3),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final isSmallScreen = screenWidth < 600;

          if (isSmallScreen) {
            // تخطيط عمودي للشاشات الصغيرة
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // العنوان والوصف
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'صرف من المخزون',
                      style: AccountantThemeConfig.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'إدارة طلبات صرف المنتجات من المخزن',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // الأزرار والإحصائيات
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // إحصائيات سريعة
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: AccountantThemeConfig.greenGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.pending_actions,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${stats['pending'] ?? 0} معلق',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // زر مسح جميع البيانات
                      _buildClearAllDataButton(),

                      const SizedBox(width: 12),

                      // زر إضافة طلب يدوي
                      _buildAddManualDispatchButton(),
                    ],
                  ),
                ),
              ],
            );
          } else {
            // تخطيط أفقي للشاشات الكبيرة
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'صرف من المخزون',
                        style: AccountantThemeConfig.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'إدارة طلبات صرف المنتجات من المخزن',
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),

                // إحصائيات سريعة
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.greenGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.pending_actions,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${stats['pending'] ?? 0} معلق',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // زر مسح جميع البيانات
                _buildClearAllDataButton(),

                const SizedBox(width: 12),

                // زر إضافة طلب يدوي
                _buildAddManualDispatchButton(),
              ],
            );
          }
        },
      ),
    );
  }

  /// بناء زر مسح جميع البيانات
  Widget _buildClearAllDataButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.warningOrange,
            AccountantThemeConfig.warningOrange.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AccountantThemeConfig.warningOrange.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showClearAllDataDialog,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.delete_forever,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'مسح جميع البيانات',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// بناء زر إضافة طلب يدوي - محدث ومحسن
  Widget _buildAddManualDispatchButton() {
    return Consumer<WarehouseDispatchProvider>(
      builder: (context, provider, child) {
        final isLoading = provider.isLoading;

        return AnimatedContainer(
          duration: AccountantThemeConfig.animationDuration,
          decoration: BoxDecoration(
            gradient: isLoading
                ? LinearGradient(
                    colors: [
                      AccountantThemeConfig.primaryGreen.withOpacity(0.6),
                      AccountantThemeConfig.secondaryGreen.withOpacity(0.6),
                    ],
                  )
                : AccountantThemeConfig.greenGradient,
            borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
            boxShadow: isLoading
                ? []
                : AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
            child: InkWell(
              onTap: isLoading ? null : () => _showAddManualDispatchDialog(),
              borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
              splashColor: Colors.white.withOpacity(0.2),
              highlightColor: Colors.white.withOpacity(0.1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AccountantThemeConfig.defaultPadding,
                  vertical: AccountantThemeConfig.smallPadding + 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: AccountantThemeConfig.animationDuration,
                      child: isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withOpacity(0.8),
                                ),
                              ),
                            )
                          : Icon(
                              Icons.add_box_outlined,
                              color: Colors.white,
                              size: 20,
                              semanticLabel: 'إضافة طلب صرف جديد',
                            ),
                    ),
                    const SizedBox(width: AccountantThemeConfig.smallPadding),
                    Text(
                      isLoading ? 'جاري المعالجة...' : 'إضافة طلب',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// بناء فلاتر الحالة مع تصميم متجاوب
  Widget _buildStatusFilters(WarehouseDispatchProvider provider) {
    final filters = [
      {'key': 'all', 'label': 'الكل', 'icon': Icons.list_alt},
      {'key': 'pending', 'label': 'معلق', 'icon': Icons.pending},
      {'key': 'processing', 'label': 'قيد المعالجة', 'icon': Icons.sync},
      {'key': 'completed', 'label': 'مكتمل', 'icon': Icons.check_circle},
      {'key': 'cancelled', 'label': 'ملغي', 'icon': Icons.cancel},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isSmallScreen = screenWidth < 600;
        final isTablet = screenWidth >= 600 && screenWidth < 1024;
        final isDesktop = screenWidth >= 1024;

        // تحديد ارتفاع الحاوية حسب حجم الشاشة
        final containerHeight = isSmallScreen ? 60.0 : 50.0;
        final horizontalPadding = isSmallScreen ? 12.0 : 16.0;
        final chipSpacing = isSmallScreen ? 6.0 : 8.0;

        return Container(
          height: containerHeight,
          margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: isDesktop
              ? _buildDesktopFilters(filters, provider)
              : _buildMobileTabletFilters(filters, provider, chipSpacing, isSmallScreen),
        );
      },
    );
  }

  /// بناء فلاتر للشاشات الكبيرة (سطح المكتب)
  Widget _buildDesktopFilters(List<Map<String, dynamic>> filters, WarehouseDispatchProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: filters.map((filter) {
        final isSelected = provider.statusFilter == filter['key'];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          child: _buildFilterChip(filter, isSelected, provider, false),
        );
      }).toList(),
    );
  }

  /// بناء فلاتر للشاشات الصغيرة والمتوسطة
  Widget _buildMobileTabletFilters(List<Map<String, dynamic>> filters, WarehouseDispatchProvider provider, double spacing, bool isSmallScreen) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 5),
      itemCount: filters.length,
      itemBuilder: (context, index) {
        final filter = filters[index];
        final isSelected = provider.statusFilter == filter['key'];

        return Container(
          margin: EdgeInsets.only(right: spacing),
          child: _buildFilterChip(filter, isSelected, provider, isSmallScreen),
        );
      },
    );
  }

  /// بناء رقاقة الفلتر
  Widget _buildFilterChip(Map<String, dynamic> filter, bool isSelected, WarehouseDispatchProvider provider, bool isSmallScreen) {
    return FilterChip(
      selected: isSelected,
      label: isSmallScreen
          ? Icon(
              filter['icon'] as IconData,
              size: 18,
              color: isSelected ? Colors.white : Colors.white70,
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  filter['icon'] as IconData,
                  size: 16,
                  color: isSelected ? Colors.white : Colors.white70,
                ),
                const SizedBox(width: 4),
                Text(
                  filter['label'] as String,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                ),
              ],
            ),
      onSelected: (selected) {
        provider.setStatusFilter(filter['key'] as String);
      },
      backgroundColor: Colors.white.withOpacity(0.1),
      selectedColor: AccountantThemeConfig.primaryGreen,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected
            ? AccountantThemeConfig.primaryGreen
            : Colors.white.withOpacity(0.3),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : 12,
        vertical: isSmallScreen ? 6 : 8,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  /// بناء محتوى طلبات الصرف
  Widget _buildDispatchContent(WarehouseDispatchProvider provider) {
    if (provider.isLoading) {
      return _buildLoadingState();
    }

    if (provider.hasError) {
      return _buildErrorState(provider.errorMessage, provider);
    }

    if (provider.filteredRequests.isEmpty) {
      return _buildEmptyState();
    }

    return _buildDispatchList(provider.filteredRequests);
  }

  /// بناء حالة التحميل
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AccountantThemeConfig.greenGradient,
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'جاري تحميل طلبات الصرف...',
            style: AccountantThemeConfig.bodyLarge,
          ),
        ],
      ),
    );
  }

  /// بناء حالة الخطأ
  Widget _buildErrorState(String? errorMessage, WarehouseDispatchProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AccountantThemeConfig.warningOrange,
          ),
          const SizedBox(height: 16),
          Text(
            'خطأ في تحميل طلبات الصرف',
            style: AccountantThemeConfig.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage ?? 'حدث خطأ غير متوقع',
            style: AccountantThemeConfig.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => provider.loadDispatchRequests(forceRefresh: true),
            icon: const Icon(Icons.refresh),
            label: Text(
              'إعادة المحاولة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء حالة عدم وجود طلبات
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد طلبات صرف',
            style: AccountantThemeConfig.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'يمكنك إضافة طلب صرف يدوي أو إرسال فاتورة للصرف',
            style: AccountantThemeConfig.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildAddManualDispatchButton(),
        ],
      ),
    );
  }

  /// بناء قائمة طلبات الصرف مع تصميم متجاوب
  Widget _buildDispatchList(List<WarehouseDispatchModel> requests) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isSmallScreen = screenWidth < 600;

        return RefreshIndicator(
          onRefresh: () async {
            final provider = Provider.of<WarehouseDispatchProvider>(context, listen: false);
            await provider.loadDispatchRequests(forceRefresh: true);
          },
          backgroundColor: AccountantThemeConfig.cardBackground1,
          color: AccountantThemeConfig.primaryGreen,
          child: ListView.builder(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _buildDispatchCard(request);
            },
          ),
        );
      },
    );
  }

  /// بناء بطاقة طلب الصرف مع تصميم متجاوب
  Widget _buildDispatchCard(WarehouseDispatchModel request) {
    final statusColor = _getStatusColor(request.status);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isSmallScreen = screenWidth < 600;
        final isTablet = screenWidth >= 600 && screenWidth < 1024;

        return Container(
          margin: EdgeInsets.only(
            bottom: isSmallScreen ? 12 : 16,
            left: isSmallScreen ? 8 : 0,
            right: isSmallScreen ? 8 : 0,
          ),
          decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isSmallScreen ? 0.1 : 0.15),
                blurRadius: isSmallScreen ? 6 : 8,
                spreadRadius: isSmallScreen ? 1 : 2,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: isSmallScreen
              ? _buildCompactCard(request, statusColor)
              : _buildFullCard(request, statusColor, isTablet),
        );
      },
    );
  }

  /// بناء بطاقة مضغوطة للشاشات الصغيرة
  Widget _buildCompactCard(WarehouseDispatchModel request, Color statusColor) {
    return InkWell(
      onTap: () => _showDispatchDetails(request),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الصف الأول: الأيقونة ورقم الطلب والحالة
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getTypeIcon(request.type),
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    request.requestNumber,
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    request.statusText,
                    style: GoogleFonts.cairo(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // الصف الثاني: اسم العميل
            Text(
              request.customerName,
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.white70,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // الصف الثالث: المبلغ وعدد المنتجات
            Row(
              children: [
                Icon(
                  Icons.monetization_on_outlined,
                  size: 14,
                  color: Colors.white60,
                ),
                const SizedBox(width: 4),
                Text(
                  '${request.totalAmount.toStringAsFixed(2)} جنيه',
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: Colors.white60,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.inventory_2_outlined,
                  size: 14,
                  color: Colors.white60,
                ),
                const SizedBox(width: 4),
                Text(
                  '${request.itemsCount} منتج',
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// بناء بطاقة كاملة للشاشات الكبيرة والمتوسطة
  Widget _buildFullCard(WarehouseDispatchModel request, Color statusColor, bool isTablet) {
    return ListTile(
      contentPadding: EdgeInsets.all(isTablet ? 14 : 16),
      leading: Container(
        width: isTablet ? 44 : 48,
        height: isTablet ? 44 : 48,
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          _getTypeIcon(request.type),
          color: statusColor,
          size: isTablet ? 22 : 24,
        ),
      ),
      title: Text(
        request.requestNumber,
        style: AccountantThemeConfig.bodyLarge.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: isTablet ? 15 : 16,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            request.customerName,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white70,
              fontSize: isTablet ? 13 : 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${request.totalAmount.toStringAsFixed(2)} جنيه • ${request.itemsCount} منتج',
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white60,
              fontSize: isTablet ? 11 : 12,
            ),
          ),
        ],
      ),
      trailing: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 6 : 8,
          vertical: isTablet ? 3 : 4,
        ),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _getStatusDisplayText(request.status),
          style: GoogleFonts.cairo(
            fontSize: isTablet ? 9 : 10,
            fontWeight: FontWeight.w600,
            color: statusColor,
          ),
        ),
      ),
      onTap: () => _showDispatchDetails(request),
    );
  }

  /// FIXED: Enhanced status color determination with better visual feedback
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AccountantThemeConfig.warningOrange;
      case 'processing':
        return AccountantThemeConfig.accentBlue;
      case 'completed':
        return AccountantThemeConfig.primaryGreen;
      case 'cancelled':
        return Colors.red;
      case 'failed':
        return Colors.red.shade700;
      case 'partial':
        return Colors.orange.shade600;
      default:
        return Colors.grey;
    }
  }

  /// FIXED: Enhanced status text with more descriptive labels
  String _getStatusDisplayText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'معلق';
      case 'processing':
        return 'قيد المعالجة';
      case 'completed':
        return 'مكتمل ✅';
      case 'cancelled':
        return 'ملغي';
      case 'failed':
        return 'فشل ❌';
      case 'partial':
        return 'جزئي ⚠️';
      default:
        return status;
    }
  }

  /// الحصول على أيقونة النوع
  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'invoice':
        return Icons.receipt_outlined;
      case 'manual':
        return Icons.edit_outlined;
      default:
        return Icons.local_shipping_outlined;
    }
  }

  /// عرض تفاصيل طلب الصرف
  void _showDispatchDetails(WarehouseDispatchModel request) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DispatchDetailsScreen(dispatch: request),
        fullscreenDialog: true,
      ),
    );
  }

  /// عرض حوار إضافة طلب يدوي - محدث ومحسن
  void _showAddManualDispatchDialog() {
    try {
      // التحقق من صحة السياق
      if (!mounted) {
        AppLogger.warning('⚠️ محاولة عرض حوار إضافة طلب بعد إلغاء تحميل الويدجت');
        return;
      }

      // التحقق من حالة المزود
      final provider = Provider.of<WarehouseDispatchProvider>(context, listen: false);
      if (provider.isLoading) {
        AppLogger.info('ℹ️ المزود في حالة تحميل، تأجيل عرض الحوار');

        // عرض رسالة للمستخدم
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'يرجى الانتظار حتى انتهاء العملية الحالية',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            backgroundColor: AccountantThemeConfig.accentBlue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      AppLogger.info('📋 عرض حوار إضافة طلب صرف يدوي');

      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.7),
        builder: (dialogContext) => AddManualDispatchDialog(
          userRole: widget.userRole,
          onDispatchAdded: () async {
            try {
              AppLogger.info('✅ تم إضافة طلب صرف جديد، جاري تحديث القائمة...');

              // إغلاق الحوار أولاً
              if (Navigator.of(dialogContext).canPop()) {
                Navigator.of(dialogContext).pop();
              }

              // تحديث قائمة الطلبات مع التحقق من السياق
              if (mounted) {
                final refreshProvider = Provider.of<WarehouseDispatchProvider>(
                  context,
                  listen: false,
                );
                await refreshProvider.loadDispatchRequests(forceRefresh: true);

                // عرض رسالة نجاح
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'تم إضافة طلب الصرف بنجاح',
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AccountantThemeConfig.primaryGreen,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            } catch (e) {
              AppLogger.error('❌ خطأ في تحديث قائمة الطلبات بعد الإضافة: $e');

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'تم إضافة الطلب ولكن حدث خطأ في التحديث',
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: AccountantThemeConfig.warningOrange,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                    ),
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            }
          },
        ),
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في عرض حوار إضافة طلب الصرف: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'حدث خطأ في فتح نافذة إضافة الطلب',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AccountantThemeConfig.dangerRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// عرض حوار تأكيد مسح جميع البيانات
  void _showClearAllDataDialog() async {
    try {
      final provider = Provider.of<WarehouseDispatchProvider>(context, listen: false);

      // الحصول على عدد الطلبات الحالية
      final requestCount = await provider.getDispatchRequestsCount();

      if (requestCount == 0) {
        // إذا لم توجد طلبات، عرض رسالة إعلامية
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'لا توجد طلبات صرف للحذف',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              backgroundColor: AccountantThemeConfig.accentBlue,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }

      // عرض حوار التأكيد
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => ClearAllDataDialog(
            requestCount: requestCount,
            onConfirm: () async {
              Navigator.of(context).pop(); // إغلاق الحوار
              await _performClearAllData();
            },
            onCancel: () {
              Navigator.of(context).pop(); // إغلاق الحوار
            },
          ),
        );
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في عرض حوار مسح البيانات: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'خطأ في تحميل بيانات الطلبات',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            backgroundColor: AccountantThemeConfig.warningOrange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  /// تنفيذ عملية مسح جميع البيانات
  Future<void> _performClearAllData() async {
    try {
      final provider = Provider.of<WarehouseDispatchProvider>(context, listen: false);

      // عرض مؤشر التحميل
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: AccountantThemeConfig.primaryCardDecoration,
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'جاري مسح جميع البيانات...',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'يرجى الانتظار، لا تغلق التطبيق',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // تنفيذ عملية المسح
      final success = await provider.clearAllDispatchRequests();

      // إغلاق مؤشر التحميل
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (success) {
        // إعادة تحميل البيانات من قاعدة البيانات للتأكد من التحديث
        AppLogger.info('🔄 إعادة تحميل البيانات بعد المسح للتأكد من التحديث...');
        await provider.loadDispatchRequests(forceRefresh: true);
        AppLogger.info('✅ تم إعادة تحميل البيانات بعد المسح');
      }

      // عرض رسالة النتيجة
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error_outline,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  success
                      ? 'تم مسح جميع طلبات الصرف بنجاح'
                      : 'فشل في مسح طلبات الصرف',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            backgroundColor: success
                ? AccountantThemeConfig.primaryGreen
                : AccountantThemeConfig.warningOrange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      AppLogger.info(success
          ? '✅ تم مسح جميع طلبات الصرف بنجاح'
          : '❌ فشل في مسح طلبات الصرف');

    } catch (e) {
      AppLogger.error('❌ خطأ في تنفيذ عملية مسح البيانات: $e');

      // إغلاق مؤشر التحميل في حالة الخطأ
      if (mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'حدث خطأ أثناء مسح البيانات: ${e.toString()}',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AccountantThemeConfig.warningOrange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
