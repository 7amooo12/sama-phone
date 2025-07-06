import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/worker_attendance_provider.dart';
import 'package:smartbiztracker_new/widgets/worker_attendance/professional_qr_scanner_widget.dart';
import 'package:smartbiztracker_new/widgets/worker_attendance/attendance_success_widget.dart';
import 'package:smartbiztracker_new/widgets/worker_attendance/attendance_failure_widget.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/models/worker_attendance_model.dart';
import 'package:smartbiztracker_new/screens/worker_attendance/worker_list_detail_screen.dart';

/// تبويب لوحة تحكم حضور العمال
class WorkerAttendanceDashboardTab extends StatefulWidget {
  const WorkerAttendanceDashboardTab({super.key});

  @override
  State<WorkerAttendanceDashboardTab> createState() => _WorkerAttendanceDashboardTabState();
}

class _WorkerAttendanceDashboardTabState extends State<WorkerAttendanceDashboardTab>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _showSuccessOverlay = false;
  bool _showFailureOverlay = false;
  WorkerAttendanceModel? _lastAttendanceRecord;
  String? _lastErrorMessage;
  String? _lastErrorCode;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // تأجيل تهيئة المزود حتى بعد اكتمال بناء الواجهة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProvider();
    });
  }

  Future<void> _initializeProvider() async {
    if (!mounted) return;

    try {
      AppLogger.info('🚀 بدء تهيئة مزود حضور العمال...');
      final provider = Provider.of<WorkerAttendanceProvider>(context, listen: false);
      await provider.initialize();

      if (!mounted) return;

      AppLogger.info('✅ تم تهيئة مزود حضور العمال بنجاح');
    } catch (e) {
      AppLogger.error('❌ خطأ في تهيئة مزود حضور العمال: $e');
      if (mounted) {
        // يمكن إضافة معالجة خطأ هنا إذا لزم الأمر
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkerAttendanceProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: const BoxDecoration(
              gradient: AccountantThemeConfig.mainBackgroundGradient,
            ),
            child: Stack(
              children: [
                // المحتوى الرئيسي
                Column(
                  children: [
                    // شريط التبويبات
                    _buildTabBar(),
                    
                    // محتوى التبويبات
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildQRScannerTab(provider),
                          _buildDashboardTab(provider),
                        ],
                      ),
                    ),
                  ],
                ),

                // طبقات النجاح والفشل
                if (_showSuccessOverlay && _lastAttendanceRecord != null)
                  AttendanceSuccessWidget(
                    attendanceRecord: _lastAttendanceRecord!,
                    onDismiss: () {
                      setState(() {
                        _showSuccessOverlay = false;
                        _lastAttendanceRecord = null;
                      });
                    },
                  ),

                if (_showFailureOverlay && _lastErrorMessage != null)
                  AttendanceFailureWidget(
                    errorMessage: _lastErrorMessage!,
                    errorCode: _lastErrorCode,
                    onRetry: () {
                      setState(() {
                        _showFailureOverlay = false;
                        _lastErrorMessage = null;
                        _lastErrorCode = null;
                      });
                      _tabController.animateTo(0); // العودة لتبويب الماسح
                    },
                    onDismiss: () {
                      setState(() {
                        _showFailureOverlay = false;
                        _lastErrorMessage = null;
                        _lastErrorCode = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: AccountantThemeConfig.greenGradient,
          boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: AccountantThemeConfig.bodyMedium.copyWith(
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(
            icon: Icon(Icons.qr_code_scanner, size: 20),
            text: 'مسح QR',
          ),
          Tab(
            icon: Icon(Icons.dashboard_rounded, size: 20),
            text: 'لوحة التحكم',
          ),
        ],
      ),
    );
  }

  Widget _buildQRScannerTab(WorkerAttendanceProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ماسح QR - تم توسيع المساحة المتاحة
          Expanded(
            child: ProfessionalQRScannerWidget(
              onQRDetected: (qrData) => _handleQRDetected(qrData, provider),
              onError: () => _handleScannerError(),
              showControls: true,
              showInstructions: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab(WorkerAttendanceProvider provider) {
    return RefreshIndicator(
      onRefresh: () => provider.refresh(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // عنوان القسم
            _buildSectionHeader(
              'لوحة تحكم الحضور',
              'إحصائيات وتقارير حضور العمال',
              Icons.dashboard_rounded,
            ),
            
            const SizedBox(height: 20),
            
            // الإحصائيات الرئيسية
            _buildMainStatistics(provider),
            
            const SizedBox(height: 24),
            
            // الحضور الحديث
            _buildRecentAttendance(provider),
            
            const SizedBox(height: 24),
            
            // أزرار العمل السريع
            _buildQuickActions(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AccountantThemeConfig.greenGradient,
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AccountantThemeConfig.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AccountantThemeConfig.bodyMedium.copyWith(
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

  Widget _buildQuickStats(WorkerAttendanceProvider provider) {
    final stats = provider.statistics;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('الحاضرون', stats.presentWorkers.toString(), Icons.check_circle, AccountantThemeConfig.primaryGreen),
          _buildStatItem('الغائبون', stats.absentWorkers.toString(), Icons.cancel, AccountantThemeConfig.dangerRed),
          _buildStatItem('المتأخرون', stats.lateWorkers.toString(), Icons.access_time, AccountantThemeConfig.warningOrange),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(height: 8),
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
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildMainStatistics(WorkerAttendanceProvider provider) {
    final stats = provider.statistics;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildStatCard(
          'إجمالي العمال',
          stats.totalWorkers.toString(),
          Icons.people,
          AccountantThemeConfig.accentBlue,
          onTap: () => _navigateToWorkerList(WorkerListType.all),
        ),
        _buildStatCard(
          'الحاضرون اليوم',
          stats.presentWorkers.toString(),
          Icons.check_circle,
          AccountantThemeConfig.primaryGreen,
          onTap: () => _navigateToWorkerList(WorkerListType.present),
        ),
        _buildStatCard(
          'الغائبون',
          stats.absentWorkers.toString(),
          Icons.cancel,
          AccountantThemeConfig.dangerRed,
          onTap: () => _navigateToWorkerList(WorkerListType.absent),
        ),
        _buildStatCard(
          'المتأخرون',
          stats.lateWorkers.toString(),
          Icons.access_time,
          AccountantThemeConfig.warningOrange,
          onTap: () => _navigateToWorkerList(WorkerListType.late),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(color),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.2),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: AccountantThemeConfig.headlineMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (onTap != null) ...[
                  const SizedBox(height: 8),
                  Icon(
                    Icons.touch_app,
                    color: Colors.white60,
                    size: 16,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentAttendance(WorkerAttendanceProvider provider) {
    final recentAttendance = provider.recentAttendance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الحضور الحديث',
          style: AccountantThemeConfig.headlineSmall,
        ),
        const SizedBox(height: 16),
        if (recentAttendance.isEmpty)
          _buildEmptyState()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentAttendance.length.clamp(0, 5),
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final attendance = recentAttendance[index];
              return _buildAttendanceCard(attendance);
            },
          ),
      ],
    );
  }

  Widget _buildAttendanceCard(WorkerAttendanceModel attendance) {
    final isCheckIn = attendance.type == AttendanceType.checkIn;
    final color = isCheckIn ? AccountantThemeConfig.primaryGreen : AccountantThemeConfig.warningOrange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.2),
            ),
            child: Icon(
              isCheckIn ? Icons.login : Icons.logout,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attendance.workerName,
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'رقم الموظف: ${attendance.employeeId}',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isCheckIn ? 'دخول' : 'خروج',
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(attendance.timestamp),
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'لا يوجد حضور حديث',
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ بمسح رمز QR لتسجيل حضور العمال',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(WorkerAttendanceProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إجراءات سريعة',
          style: AccountantThemeConfig.headlineSmall,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'تحديث البيانات',
                Icons.refresh,
                AccountantThemeConfig.primaryGreen,
                () => provider.refresh(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'مسح QR جديد',
                Icons.qr_code_scanner,
                AccountantThemeConfig.accentBlue,
                () => _tabController.animateTo(0),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: AccountantThemeConfig.glowShadows(color),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  Future<void> _handleQRDetected(String qrData, WorkerAttendanceProvider provider) async {
    // التحقق من صحة الحالة قبل المعالجة
    if (!mounted) {
      AppLogger.warning('⚠️ تم إلغاء معالجة QR - الواجهة غير متاحة');
      return;
    }

    try {
      AppLogger.info('🔍 معالجة QR: $qrData');

      final response = await provider.processQRCode(qrData);

      // التحقق من الحالة مرة أخرى بعد العملية غير المتزامنة
      if (!mounted) {
        AppLogger.warning('⚠️ تم إلغاء معالجة QR - الواجهة تم إلغاؤها');
        return;
      }

      if (response.isValid && response.attendanceRecord != null) {
        if (mounted) {
          setState(() {
            _lastAttendanceRecord = response.attendanceRecord;
            _showSuccessOverlay = true;
          });

          // تبديل إلى تبويب لوحة التحكم لعرض التحديثات
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _tabController.animateTo(1);
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _lastErrorMessage = response.errorMessage ?? 'حدث خطأ غير متوقع';
            _lastErrorCode = response.errorCode;
            _showFailureOverlay = true;
          });
        }
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في معالجة QR: $e');

      // التحقق من الحالة قبل تحديث الواجهة
      if (mounted) {
        setState(() {
          _lastErrorMessage = 'حدث خطأ في واجهة المستخدم';
          _lastErrorCode = AttendanceErrorCodes.databaseError;
          _showFailureOverlay = true;
        });
      }
    }
  }

  void _handleScannerError() {
    if (!mounted) return;

    AppLogger.error('❌ خطأ في ماسح QR');

    setState(() {
      _lastErrorMessage = 'خطأ في تهيئة الكاميرا. تحقق من الأذونات.';
      _lastErrorCode = AttendanceErrorCodes.cameraError;
      _showFailureOverlay = true;
    });
  }

  /// التنقل إلى قائمة العمال التفصيلية
  void _navigateToWorkerList(WorkerListType listType) {
    String title;
    switch (listType) {
      case WorkerListType.all:
        title = 'جميع العمال';
        break;
      case WorkerListType.present:
        title = 'العمال الحاضرون اليوم';
        break;
      case WorkerListType.absent:
        title = 'العمال الغائبون اليوم';
        break;
      case WorkerListType.late:
        title = 'العمال المتأخرون اليوم';
        break;
    }

    // Get the current provider instance to pass to the new screen
    final attendanceProvider = Provider.of<WorkerAttendanceProvider>(context, listen: false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: attendanceProvider,
          child: WorkerListDetailScreen(
            title: title,
            listType: listType,
          ),
        ),
      ),
    );
  }
}
