import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/warehouse_dispatch_model.dart';
import '../../providers/warehouse_dispatch_provider.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';

/// شاشة تفاصيل طلب الصرف
class DispatchDetailsScreen extends StatefulWidget {
  final WarehouseDispatchModel dispatch;

  const DispatchDetailsScreen({
    Key? key,
    required this.dispatch,
  }) : super(key: key);

  @override
  State<DispatchDetailsScreen> createState() => _DispatchDetailsScreenState();
}

class _DispatchDetailsScreenState extends State<DispatchDetailsScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    AppLogger.info('📋 عرض تفاصيل طلب الصرف: ${widget.dispatch.requestNumber}');
    AppLogger.info('📦 عدد العناصر في الطلب: ${widget.dispatch.items.length}');

    // تسجيل تفاصيل العناصر للتشخيص
    for (int i = 0; i < widget.dispatch.items.length; i++) {
      final item = widget.dispatch.items[i];
      AppLogger.info('🔍 عنصر ${i + 1}: ID=${item.id}, ProductID=${item.productId}, Quantity=${item.quantity}, Notes=${item.notes}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// بناء شريط التطبيق
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.greenGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تفاصيل طلب الصرف',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  widget.dispatch.requestNumber,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          // زر التشخيص (للتطوير فقط)
          IconButton(
            onPressed: () => _showDebugInfo(),
            icon: const Icon(Icons.bug_report, color: Colors.white70, size: 20),
            tooltip: 'معلومات التشخيص',
          ),
          _buildStatusChip(),
        ],
      ),
    );
  }

  /// بناء شريحة الحالة
  Widget _buildStatusChip() {
    final status = widget.dispatch.status;
    Color statusColor;
    String statusText;

    switch (status) {
      case 'pending':
        statusColor = AccountantThemeConfig.warningOrange;
        statusText = 'في الانتظار';
        break;
      case 'approved':
        statusColor = AccountantThemeConfig.accentBlue;
        statusText = 'موافق عليه';
        break;
      case 'executed':
        statusColor = AccountantThemeConfig.primaryGreen;
        statusText = 'تم التنفيذ';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'مرفوض';
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusText = 'ملغي';
        break;
      default:
        statusColor = Colors.grey;
        statusText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.5)),
      ),
      child: Text(
        statusText,
        style: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: statusColor,
        ),
      ),
    );
  }

  /// بناء حالة التحميل
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              AccountantThemeConfig.primaryGreen,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'جاري تحميل التفاصيل...',
            style: GoogleFonts.cairo(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  /// بناء المحتوى الرئيسي
  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(),
          const SizedBox(height: 16),
          _buildItemsCard(),
          const SizedBox(height: 16),
          _buildTimelineCard(),
          const SizedBox(height: 16),
          if (widget.dispatch.notes != null && widget.dispatch.notes!.isNotEmpty)
            _buildNotesCard(),
        ],
      ),
    );
  }

  /// بناء بطاقة المعلومات الأساسية
  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AccountantThemeConfig.primaryGreen,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'معلومات الطلب',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('رقم الطلب', widget.dispatch.requestNumber),
          _buildInfoRow('نوع الطلب', _getTypeText(widget.dispatch.type)),
          _buildInfoRow('السبب', widget.dispatch.reason),
          _buildInfoRow('تاريخ الطلب', _formatDateTime(widget.dispatch.requestedAt)),
          if (widget.dispatch.warehouseId != null)
            _buildInfoRow('المخزن', widget.dispatch.warehouseId!),
        ],
      ),
    );
  }

  /// بناء بطاقة العناصر
  Widget _buildItemsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                color: AccountantThemeConfig.primaryGreen,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'عناصر الطلب (${widget.dispatch.items.length})',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // التحقق من وجود عناصر
          if (widget.dispatch.items.isEmpty)
            _buildEmptyItemsState()
          else
            ...widget.dispatch.items.map((item) => _buildItemRow(item)),
        ],
      ),
    );
  }

  /// بناء حالة عدم وجود عناصر
  Widget _buildEmptyItemsState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardBackground2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.warningOrange.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.warning_amber_outlined,
            color: AccountantThemeConfig.warningOrange,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد عناصر في هذا الطلب',
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'قد يكون هناك خطأ في تحميل البيانات أو أن الطلب لم يتم حفظه بشكل صحيح',
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              // إعادة تحميل البيانات
              AppLogger.info('🔄 محاولة إعادة تحميل تفاصيل الطلب: ${widget.dispatch.id}');
              setState(() {
                _isLoading = true;
              });

              // محاولة إعادة تحميل البيانات من قاعدة البيانات
              _reloadDispatchDetails();
            },
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: Text(
              'إعادة المحاولة',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء صف عنصر
  Widget _buildItemRow(WarehouseDispatchItemModel item) {
    // استخراج اسم المنتج من الملاحظات إذا كان متوفراً
    String productName = 'منتج غير معروف';
    String additionalInfo = '';

    if (item.notes != null && item.notes!.isNotEmpty) {
      final parts = item.notes!.split(' - ');
      if (parts.isNotEmpty) {
        productName = parts.first;
        if (parts.length > 1) {
          additionalInfo = parts.skip(1).join(' - ');
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // اسم المنتج
          Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                color: AccountantThemeConfig.primaryGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  productName,
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.greenGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'الكمية: ${item.quantity}',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // معرف المنتج
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.cardBackground2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.qr_code,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'معرف المنتج: ',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                Expanded(
                  child: Text(
                    item.productId,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AccountantThemeConfig.accentBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // معلومات إضافية
          if (additionalInfo.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AccountantThemeConfig.cardBackground2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      additionalInfo,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// إعادة تحميل تفاصيل الطلب
  Future<void> _reloadDispatchDetails() async {
    try {
      final provider = Provider.of<WarehouseDispatchProvider>(context, listen: false);

      AppLogger.info('🔄 بدء إعادة تحميل تفاصيل الطلب: ${widget.dispatch.id}');

      // التحقق من سلامة البيانات أولاً
      final integrity = await provider.verifyRequestIntegrity(widget.dispatch.id);
      AppLogger.info('📊 نتائج التحقق من السلامة: ${integrity['integrity']}');

      if (integrity['integrity'] == 'error') {
        throw Exception('الطلب غير موجود في قاعدة البيانات');
      }

      // محاولة إعادة تحميل الطلب المحدد
      final reloadedRequest = await provider.reloadDispatchRequest(widget.dispatch.id);

      if (reloadedRequest != null) {
        AppLogger.info('✅ تم إعادة تحميل الطلب بنجاح مع ${reloadedRequest.items.length} عنصر');

        // تحديث البيانات المحلية
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم إعادة تحميل البيانات بنجاح',
                style: GoogleFonts.cairo(),
              ),
              backgroundColor: AccountantThemeConfig.primaryGreen,
            ),
          );
        }
      } else {
        throw Exception('فشل في إعادة تحميل الطلب');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في إعادة تحميل تفاصيل الطلب: $e');

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'فشل في إعادة تحميل البيانات: ${e.toString()}',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// بناء بطاقة الجدول الزمني
  Widget _buildTimelineCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.timeline,
                color: AccountantThemeConfig.primaryGreen,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'الجدول الزمني',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTimelineItem(
            'تم إنشاء الطلب',
            widget.dispatch.requestedAt,
            true,
          ),
          if (widget.dispatch.approvedAt != null)
            _buildTimelineItem(
              'تم الموافقة على الطلب',
              widget.dispatch.approvedAt!,
              true,
            ),
          if (widget.dispatch.executedAt != null)
            _buildTimelineItem(
              'تم تنفيذ الطلب',
              widget.dispatch.executedAt!,
              true,
            ),
        ],
      ),
    );
  }

  /// بناء عنصر الجدول الزمني
  Widget _buildTimelineItem(String title, DateTime dateTime, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isCompleted
                  ? AccountantThemeConfig.primaryGreen
                  : Colors.grey,
              shape: BoxShape.circle,
            ),
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
                  _formatDateTime(dateTime),
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// بناء بطاقة الملاحظات
  Widget _buildNotesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.note_outlined,
                color: AccountantThemeConfig.primaryGreen,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'ملاحظات',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.dispatch.notes!,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// بناء صف معلومات
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// تحويل نوع الطلب إلى نص
  String _getTypeText(String type) {
    switch (type) {
      case 'withdrawal':
        return 'سحب';
      case 'transfer':
        return 'نقل';
      case 'adjustment':
        return 'تعديل';
      case 'return':
        return 'إرجاع';
      default:
        return type;
    }
  }

  /// عرض معلومات التشخيص
  void _showDebugInfo() {
    showDialog(
      context: context,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: AlertDialog(
          backgroundColor: AccountantThemeConfig.cardBackground1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.bug_report,
                color: AccountantThemeConfig.primaryGreen,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'معلومات التشخيص',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDebugRow('معرف الطلب', widget.dispatch.id),
                _buildDebugRow('رقم الطلب', widget.dispatch.requestNumber),
                _buildDebugRow('الحالة', widget.dispatch.status),
                _buildDebugRow('النوع', widget.dispatch.type),
                _buildDebugRow('عدد العناصر', widget.dispatch.items.length.toString()),
                _buildDebugRow('معرف المخزن', widget.dispatch.warehouseId ?? 'غير محدد'),
                _buildDebugRow('طلب بواسطة', widget.dispatch.requestedBy),
                const SizedBox(height: 16),
                Text(
                  'تفاصيل العناصر:',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AccountantThemeConfig.primaryGreen,
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.dispatch.items.isEmpty)
                  Text(
                    'لا توجد عناصر',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  )
                else
                  ...widget.dispatch.items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AccountantThemeConfig.cardBackground2,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'عنصر ${index + 1}:',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'ID: ${item.id}',
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            'ProductID: ${item.productId}',
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            'Quantity: ${item.quantity}',
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                          ),
                          if (item.notes != null)
                            Text(
                              'Notes: ${item.notes}',
                              style: GoogleFonts.cairo(
                                fontSize: 10,
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'إغلاق',
                style: GoogleFonts.cairo(
                  color: Colors.white70,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final provider = Provider.of<WarehouseDispatchProvider>(context, listen: false);
                final integrity = await provider.verifyRequestIntegrity(widget.dispatch.id);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'نتائج التحقق: ${integrity['integrity']} - العناصر: ${integrity['itemsCount'] ?? 'غير معروف'}',
                        style: GoogleFonts.cairo(),
                      ),
                      backgroundColor: integrity['integrity'] == 'good'
                          ? AccountantThemeConfig.primaryGreen
                          : AccountantThemeConfig.warningOrange,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.primaryGreen,
              ),
              child: Text(
                'فحص البيانات',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// بناء صف معلومات التشخيص
  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// تنسيق التاريخ والوقت
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
