/// Worker Attendance Summary Screen for SmartBizTracker
/// 
/// This screen provides a comprehensive attendance summary for the current worker
/// with daily records, weekly summary, work hours calculation, overtime tracking,
/// and late arrival indicators.

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/supabase_provider.dart';

import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';
import '../../models/attendance_models.dart' as attendance_models;
import '../../models/worker_attendance_model.dart';


class WorkerAttendanceSummaryScreen extends StatefulWidget {
  const WorkerAttendanceSummaryScreen({super.key});

  @override
  State<WorkerAttendanceSummaryScreen> createState() => _WorkerAttendanceSummaryScreenState();
}

class _WorkerAttendanceSummaryScreenState extends State<WorkerAttendanceSummaryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAttendanceData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAttendanceData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
      final userModel = supabaseProvider.user;

      if (userModel != null) {
        // Load current worker's attendance data
        await attendanceProvider.refreshAttendanceData(userModel.id);
        
        // Load attendance records for the current week (Saturday to Friday)
        final now = DateTime.now();
        // Calculate start of week as Saturday (weekday: Saturday=6, Sunday=7, Monday=1, etc.)
        // We want Saturday to be day 0 of our week, so we adjust the calculation
        final daysFromSaturday = (now.weekday + 1) % 7; // Saturday=0, Sunday=1, Monday=2, etc.
        final startOfWeek = now.subtract(Duration(days: daysFromSaturday));
        final endOfWeek = startOfWeek.add(const Duration(days: 6)); // Friday
        
        await attendanceProvider.loadAttendanceRecords(
          workerId: userModel.id,
          startDate: startOfWeek,
          endDate: endOfWeek,
        );

        AppLogger.info('✅ تم تحميل بيانات الحضور للعامل: ${userModel.name}');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل بيانات الحضور: $e');
      setState(() {
        _error = 'فشل في تحميل بيانات الحضور: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.mainBackgroundGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                _buildCustomAppBar(),
                
                // Tab Bar
                _buildTabBar(),
                
                // Content
                Expanded(
                  child: _isLoading
                      ? _buildLoadingState()
                      : _error != null
                          ? _buildErrorState()
                          : _buildContent(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Back Button
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AccountantThemeConfig.cardGradient,
              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Title
          Expanded(
            child: Text(
              'ملخص الحضور',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Refresh Button
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AccountantThemeConfig.cardGradient,
              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
            ),
            child: IconButton(
              onPressed: _loadAttendanceData,
              icon: const Icon(
                Icons.refresh,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(25),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: AccountantThemeConfig.greenGradient,
          borderRadius: BorderRadius.circular(25),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: AccountantThemeConfig.bodyMedium,
        tabs: const [
          Tab(text: 'الأسبوع الحالي'),
          Tab(text: 'اليوم'),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AccountantThemeConfig.primaryGreen),
          ),
          const SizedBox(height: 16),
          Text(
            'جاري تحميل بيانات الحضور...',
            style: AccountantThemeConfig.bodyLarge.copyWith(
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
            size: 64,
            color: AccountantThemeConfig.dangerRed,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadAttendanceData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildWeeklySummaryTab(),
        _buildDailySummaryTab(),
      ],
    );
  }

  Widget _buildWeeklySummaryTab() {
    return Consumer<AttendanceProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWeeklyStatsCards(provider),
              const SizedBox(height: 24),
              _buildWeeklyAttendanceList(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDailySummaryTab() {
    return Consumer<AttendanceProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTodayStatusCard(provider),
              const SizedBox(height: 24),
              _buildTodayDetailsCard(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeeklyStatsCards(AttendanceProvider provider) {
    final now = DateTime.now();
    // Calculate start of week as Saturday (Saturday to Friday work week)
    final daysFromSaturday = (now.weekday + 1) % 7; // Saturday=0, Sunday=1, Monday=2, etc.
    final startOfWeek = now.subtract(Duration(days: daysFromSaturday));
    final endOfWeek = startOfWeek.add(const Duration(days: 6)); // Friday

    // Calculate weekly statistics from attendance records
    final weeklyRecords = provider.attendanceRecords.where((record) {
      return record.timestamp.isAfter(startOfWeek) &&
             record.timestamp.isBefore(endOfWeek.add(const Duration(days: 1)));
    }).toList();

    final workingDays = _calculateWorkingDays(weeklyRecords);
    final totalHours = _calculateTotalHours(weeklyRecords);
    final lateArrivals = _calculateLateArrivals(weeklyRecords);
    final overtimeHours = _calculateOvertimeHours(totalHours, workingDays);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'أيام العمل',
                value: '$workingDays',
                subtitle: 'من 5 أيام',
                icon: Icons.calendar_today,
                color: AccountantThemeConfig.primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'إجمالي الساعات',
                value: '${totalHours.toStringAsFixed(1)}',
                subtitle: 'ساعة',
                icon: Icons.access_time,
                color: AccountantThemeConfig.accentBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'التأخير',
                value: '$lateArrivals',
                subtitle: 'مرة',
                icon: Icons.schedule,
                color: lateArrivals > 0 ? AccountantThemeConfig.warningOrange : AccountantThemeConfig.primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'الإضافي',
                value: '${overtimeHours.toStringAsFixed(1)}',
                subtitle: 'ساعة',
                icon: Icons.trending_up,
                color: overtimeHours > 0 ? AccountantThemeConfig.primaryGreen : Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

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
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(color),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AccountantThemeConfig.headlineMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subtitle,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: color,
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
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0);
  }

  Widget _buildWeeklyAttendanceList(AttendanceProvider provider) {
    final now = DateTime.now();
    // Calculate start of week as Saturday (Saturday to Friday work week)
    final daysFromSaturday = (now.weekday + 1) % 7; // Saturday=0, Sunday=1, Monday=2, etc.
    final startOfWeek = now.subtract(Duration(days: daysFromSaturday));

    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.list_alt,
                  color: AccountantThemeConfig.accentBlue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'سجل الحضور الأسبوعي',
                  style: AccountantThemeConfig.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          ...List.generate(7, (index) {
            final date = startOfWeek.add(Duration(days: index));
            return _buildDayAttendanceItem(date, provider);
          }),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideX(begin: -0.3, end: 0);
  }

  Widget _buildDayAttendanceItem(DateTime date, AttendanceProvider provider) {
    final dayRecords = provider.attendanceRecords.where((record) {
      return record.timestamp.year == date.year &&
             record.timestamp.month == date.month &&
             record.timestamp.day == date.day;
    }).toList();

    final checkIn = dayRecords.where((r) => r.attendanceType == attendance_models.AttendanceType.checkIn).firstOrNull;
    final checkOut = dayRecords.where((r) => r.attendanceType == attendance_models.AttendanceType.checkOut).firstOrNull;

    final dayName = _getDayName(date.weekday);
    final isToday = date.year == DateTime.now().year &&
                   date.month == DateTime.now().month &&
                   date.day == DateTime.now().day;

    final isLate = checkIn != null && _isLateArrival(checkIn.timestamp);
    final workHours = checkIn != null && checkOut != null
        ? checkOut.timestamp.difference(checkIn.timestamp).inMinutes / 60.0
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Date and Day
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayName,
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: isToday ? AccountantThemeConfig.primaryGreen : Colors.white,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  DateFormat('dd/MM').format(date),
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // Check-in Time
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  checkIn != null ? DateFormat('HH:mm').format(checkIn.timestamp) : '--:--',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: isLate ? AccountantThemeConfig.warningOrange : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isLate)
                  Text(
                    'متأخر',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: AccountantThemeConfig.warningOrange,
                    ),
                  ),
              ],
            ),
          ),

          // Check-out Time
          Expanded(
            flex: 2,
            child: Text(
              checkOut != null ? DateFormat('HH:mm').format(checkOut.timestamp) : '--:--',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Work Hours
          Expanded(
            flex: 2,
            child: Text(
              workHours > 0 ? '${workHours.toStringAsFixed(1)}س' : '--',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: workHours >= 8 ? AccountantThemeConfig.primaryGreen : Colors.white70,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Status Icon
          Icon(
            checkIn != null && checkOut != null
                ? Icons.check_circle
                : checkIn != null
                    ? Icons.schedule
                    : Icons.remove_circle_outline,
            color: checkIn != null && checkOut != null
                ? AccountantThemeConfig.primaryGreen
                : checkIn != null
                    ? AccountantThemeConfig.warningOrange
                    : Colors.grey,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildTodayStatusCard(AttendanceProvider provider) {
    final todayStatus = provider.todayStatus;
    final hasCheckedIn = provider.hasCheckedInToday;
    final hasCheckedOut = provider.hasCheckedOutToday;
    final isCurrentlyWorking = provider.isCurrentlyWorking;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(
          hasCheckedIn ? AccountantThemeConfig.primaryGreen : AccountantThemeConfig.warningOrange
        ),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasCheckedIn ? Icons.check_circle : Icons.schedule,
                color: hasCheckedIn ? AccountantThemeConfig.primaryGreen : AccountantThemeConfig.warningOrange,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حالة اليوم',
                      style: AccountantThemeConfig.headlineSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _getTodayStatusText(hasCheckedIn, hasCheckedOut, isCurrentlyWorking),
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (hasCheckedIn) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 16),
            _buildTodayTimeInfo(provider),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.3, end: 0);
  }

  Widget _buildTodayTimeInfo(AttendanceProvider provider) {
    final todayStatus = provider.todayStatus;
    final checkInTime = todayStatus?['checkInTime'] as DateTime?;
    final checkOutTime = todayStatus?['checkOutTime'] as DateTime?;
    final workDuration = todayStatus?['workDuration'] as Duration?;

    return Row(
      children: [
        Expanded(
          child: _buildTimeInfoItem(
            'وقت الحضور',
            checkInTime != null ? DateFormat('HH:mm').format(checkInTime) : '--:--',
            Icons.login,
            checkInTime != null && _isLateArrival(checkInTime)
                ? AccountantThemeConfig.warningOrange
                : AccountantThemeConfig.primaryGreen,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTimeInfoItem(
            'وقت الانصراف',
            checkOutTime != null ? DateFormat('HH:mm').format(checkOutTime) : '--:--',
            Icons.logout,
            AccountantThemeConfig.accentBlue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTimeInfoItem(
            'ساعات العمل',
            workDuration != null ? '${(workDuration.inMinutes / 60.0).toStringAsFixed(1)}س' : '--',
            Icons.access_time,
            workDuration != null && workDuration.inHours >= 8
                ? AccountantThemeConfig.primaryGreen
                : Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeInfoItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: AccountantThemeConfig.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTodayDetailsCard(AttendanceProvider provider) {
    final todayStatus = provider.todayStatus;
    final checkInTime = todayStatus?['checkInTime'] as DateTime?;
    final workDuration = todayStatus?['workDuration'] as Duration?;

    final isLate = checkInTime != null && _isLateArrival(checkInTime);
    final lateMinutes = isLate ? _calculateLateMinutes(checkInTime!) : 0;
    final overtimeHours = workDuration != null ? _calculateDailyOvertime(workDuration) : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تفاصيل اليوم',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          if (isLate) ...[
            _buildDetailItem(
              'التأخير',
              '$lateMinutes دقيقة',
              Icons.schedule,
              AccountantThemeConfig.warningOrange,
            ),
            const SizedBox(height: 12),
          ],

          if (overtimeHours > 0) ...[
            _buildDetailItem(
              'الوقت الإضافي',
              '${overtimeHours.toStringAsFixed(1)} ساعة',
              Icons.trending_up,
              AccountantThemeConfig.primaryGreen,
            ),
            const SizedBox(height: 12),
          ],

          if (!isLate && overtimeHours == 0 && checkInTime != null) ...[
            _buildDetailItem(
              'الحالة',
              'يوم عمل عادي',
              Icons.check_circle,
              AccountantThemeConfig.primaryGreen,
            ),
          ],

          if (checkInTime == null) ...[
            _buildDetailItem(
              'الحالة',
              'لم يتم تسجيل الحضور بعد',
              Icons.info,
              Colors.grey,
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.3, end: 0);
  }

  Widget _buildDetailItem(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white70,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // Helper methods for calculations
  int _calculateWorkingDays(List<attendance_models.WorkerAttendanceRecord> records) {
    final workDays = <DateTime>{};
    for (final record in records) {
      if (record.attendanceType == attendance_models.AttendanceType.checkIn) {
        final date = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
        workDays.add(date);
      }
    }
    return workDays.length;
  }

  double _calculateTotalHours(List<attendance_models.WorkerAttendanceRecord> records) {
    double totalHours = 0.0;
    final recordsByDate = <DateTime, List<attendance_models.WorkerAttendanceRecord>>{};

    // Group records by date
    for (final record in records) {
      final date = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
      recordsByDate.putIfAbsent(date, () => []).add(record);
    }

    // Calculate hours for each day
    for (final dayRecords in recordsByDate.values) {
      final checkIn = dayRecords.where((r) => r.attendanceType == attendance_models.AttendanceType.checkIn).firstOrNull;
      final checkOut = dayRecords.where((r) => r.attendanceType == attendance_models.AttendanceType.checkOut).firstOrNull;

      if (checkIn != null && checkOut != null) {
        totalHours += checkOut.timestamp.difference(checkIn.timestamp).inMinutes / 60.0;
      }
    }

    return totalHours;
  }

  int _calculateLateArrivals(List<attendance_models.WorkerAttendanceRecord> records) {
    int lateCount = 0;
    for (final record in records) {
      if (record.attendanceType == attendance_models.AttendanceType.checkIn && _isLateArrival(record.timestamp)) {
        lateCount++;
      }
    }
    return lateCount;
  }

  double _calculateOvertimeHours(double totalHours, int workingDays) {
    const standardHoursPerDay = 8.0;
    final standardHours = workingDays * standardHoursPerDay;
    return totalHours > standardHours ? totalHours - standardHours : 0.0;
  }

  double _calculateDailyOvertime(Duration workDuration) {
    const standardHours = 8.0;
    final actualHours = workDuration.inMinutes / 60.0;
    return actualHours > standardHours ? actualHours - standardHours : 0.0;
  }

  bool _isLateArrival(DateTime checkInTime) {
    // Using default work start time of 9:00 AM with 15 minutes tolerance
    final workStartTime = DateTime(
      checkInTime.year,
      checkInTime.month,
      checkInTime.day,
      9, // 9:00 AM
      0,
    );
    final toleranceTime = workStartTime.add(const Duration(minutes: 15));
    return checkInTime.isAfter(toleranceTime);
  }

  int _calculateLateMinutes(DateTime checkInTime) {
    final workStartTime = DateTime(
      checkInTime.year,
      checkInTime.month,
      checkInTime.day,
      9, // 9:00 AM
      0,
    );
    return checkInTime.difference(workStartTime).inMinutes.clamp(0, double.infinity).toInt();
  }

  String _getDayName(int weekday) {
    // Map weekday to Arabic day names
    // weekday: Monday=1, Tuesday=2, ..., Saturday=6, Sunday=7
    const dayNames = {
      1: 'الاثنين',    // Monday
      2: 'الثلاثاء',   // Tuesday
      3: 'الأربعاء',   // Wednesday
      4: 'الخميس',    // Thursday
      5: 'الجمعة',    // Friday
      6: 'السبت',     // Saturday
      7: 'الأحد',     // Sunday
    };
    return dayNames[weekday] ?? 'غير معروف';
  }

  String _getTodayStatusText(bool hasCheckedIn, bool hasCheckedOut, bool isCurrentlyWorking) {
    if (!hasCheckedIn) {
      return 'لم يتم تسجيل الحضور بعد';
    } else if (hasCheckedIn && !hasCheckedOut) {
      return 'في العمل حالياً';
    } else if (hasCheckedIn && hasCheckedOut) {
      return 'تم إنهاء العمل لليوم';
    } else {
      return 'حالة غير محددة';
    }
  }
}
