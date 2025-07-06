import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../providers/supabase_provider.dart';
import '../../providers/worker_attendance_provider.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../models/worker_attendance_model.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/custom_loader.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';
import 'package:intl/intl.dart';

class WorkerListDetailScreen extends StatefulWidget {
  final String title;
  final WorkerListType listType;

  const WorkerListDetailScreen({
    super.key,
    required this.title,
    required this.listType,
  });

  @override
  State<WorkerListDetailScreen> createState() => _WorkerListDetailScreenState();
}

class _WorkerListDetailScreenState extends State<WorkerListDetailScreen> {
  List<UserModel> _workers = [];
  List<WorkerAttendanceModel> _attendanceRecords = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWorkerData();
  }

  Future<void> _loadWorkerData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final attendanceProvider = Provider.of<WorkerAttendanceProvider>(context, listen: false);

      // Load all workers with role "عامل"
      final allWorkers = await supabaseProvider.getUsersByRole(UserRole.worker.value);
      
      // Load today's attendance records
      final today = DateTime.now();
      final todayAttendance = await attendanceProvider.getAttendanceForDate(today);

      List<UserModel> filteredWorkers = [];

      switch (widget.listType) {
        case WorkerListType.all:
          filteredWorkers = allWorkers;
          break;
        case WorkerListType.present:
          // Workers who checked in today
          final presentWorkerIds = todayAttendance
              .where((record) => record.type == AttendanceType.checkIn)
              .map((record) => record.workerId)
              .toSet();
          filteredWorkers = allWorkers
              .where((worker) => presentWorkerIds.contains(worker.id))
              .toList();
          break;
        case WorkerListType.absent:
          // Workers who didn't check in today
          final presentWorkerIds = todayAttendance
              .where((record) => record.type == AttendanceType.checkIn)
              .map((record) => record.workerId)
              .toSet();
          filteredWorkers = allWorkers
              .where((worker) => !presentWorkerIds.contains(worker.id))
              .toList();
          break;
        case WorkerListType.late:
          // Workers who checked in after 9 AM
          final lateWorkerIds = todayAttendance
              .where((record) => 
                  record.type == AttendanceType.checkIn &&
                  record.timestamp.hour >= 9)
              .map((record) => record.workerId)
              .toSet();
          filteredWorkers = allWorkers
              .where((worker) => lateWorkerIds.contains(worker.id))
              .toList();
          break;
      }

      setState(() {
        _workers = filteredWorkers;
        _attendanceRecords = todayAttendance;
        _isLoading = false;
      });

      AppLogger.info('✅ تم تحميل ${_workers.length} عامل للقائمة: ${widget.listType}');

    } catch (e) {
      setState(() {
        _error = 'خطأ في تحميل بيانات العمال: $e';
        _isLoading = false;
      });
      AppLogger.error('❌ خطأ في تحميل بيانات العمال: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.luxuryBlack,
      appBar: CustomAppBar(
        title: widget.title,
        backgroundColor: AccountantThemeConfig.primaryGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadWorkerData,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CustomLoader(message: 'جاري تحميل بيانات العمال...'),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_workers.isEmpty) {
      return _buildEmptyState();
    }

    return _buildWorkersList();
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.dangerRed),
          boxShadow: AccountantThemeConfig.cardShadows,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AccountantThemeConfig.dangerRed,
            ),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: AccountantThemeConfig.dangerRed,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadWorkerData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
          boxShadow: AccountantThemeConfig.cardShadows,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: AccountantThemeConfig.accentBlue,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد بيانات',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: AccountantThemeConfig.accentBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getEmptyMessage(),
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getEmptyMessage() {
    switch (widget.listType) {
      case WorkerListType.all:
        return 'لا يوجد عمال مسجلين في النظام';
      case WorkerListType.present:
        return 'لا يوجد عمال حاضرين اليوم';
      case WorkerListType.absent:
        return 'جميع العمال حاضرين اليوم';
      case WorkerListType.late:
        return 'لا يوجد عمال متأخرين اليوم';
    }
  }

  Widget _buildWorkersList() {
    return RefreshIndicator(
      onRefresh: _loadWorkerData,
      child: AnimationLimiter(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _workers.length,
          itemBuilder: (context, index) {
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 375),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: _buildWorkerCard(_workers[index], index),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWorkerCard(UserModel worker, int index) {
    final attendanceRecord = _attendanceRecords
        .where((record) => record.workerId == worker.id)
        .where((record) => record.type == AttendanceType.checkIn)
        .lastOrNull;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(_getCardColor()),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showWorkerDetails(worker, attendanceRecord),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildWorkerAvatar(worker),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildWorkerInfo(worker, attendanceRecord),
                ),
                _buildStatusIndicator(worker, attendanceRecord),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkerAvatar(UserModel worker) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AccountantThemeConfig.greenGradient,
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: worker.profileImage != null
          ? ClipOval(
              child: Image.network(
                worker.profileImage!,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(worker),
              ),
            )
          : _buildDefaultAvatar(worker),
    );
  }

  Widget _buildDefaultAvatar(UserModel worker) {
    return Icon(
      Icons.person,
      color: Colors.white,
      size: 28,
    );
  }

  Widget _buildWorkerInfo(UserModel worker, WorkerAttendanceModel? attendanceRecord) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          worker.name,
          style: AccountantThemeConfig.bodyLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          worker.email,
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white70,
          ),
        ),
        if (attendanceRecord != null) ...[
          const SizedBox(height: 4),
          Text(
            'وقت الحضور: ${DateFormat('HH:mm').format(attendanceRecord.timestamp)}',
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white60,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusIndicator(UserModel worker, WorkerAttendanceModel? attendanceRecord) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (widget.listType) {
      case WorkerListType.all:
        if (attendanceRecord != null) {
          statusColor = AccountantThemeConfig.primaryGreen;
          statusIcon = Icons.check_circle;
          statusText = 'حاضر';
        } else {
          statusColor = AccountantThemeConfig.dangerRed;
          statusIcon = Icons.cancel;
          statusText = 'غائب';
        }
        break;
      case WorkerListType.present:
        statusColor = AccountantThemeConfig.primaryGreen;
        statusIcon = Icons.check_circle;
        statusText = 'حاضر';
        break;
      case WorkerListType.absent:
        statusColor = AccountantThemeConfig.dangerRed;
        statusIcon = Icons.cancel;
        statusText = 'غائب';
        break;
      case WorkerListType.late:
        statusColor = AccountantThemeConfig.warningOrange;
        statusIcon = Icons.access_time;
        statusText = 'متأخر';
        break;
    }

    return Column(
      children: [
        Icon(
          statusIcon,
          color: statusColor,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          statusText,
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: statusColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getCardColor() {
    switch (widget.listType) {
      case WorkerListType.all:
        return AccountantThemeConfig.accentBlue;
      case WorkerListType.present:
        return AccountantThemeConfig.primaryGreen;
      case WorkerListType.absent:
        return AccountantThemeConfig.dangerRed;
      case WorkerListType.late:
        return AccountantThemeConfig.warningOrange;
    }
  }

  void _showWorkerDetails(UserModel worker, WorkerAttendanceModel? attendanceRecord) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardBackground1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'تفاصيل العامل',
          style: AccountantThemeConfig.headlineSmall.copyWith(
            color: Colors.white,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('الاسم', worker.name),
                _buildDetailRow('البريد الإلكتروني', worker.email),
                _buildDetailRow('رقم الهاتف', worker.phone),
                _buildDetailRow('الحالة', worker.status),
                if (attendanceRecord != null) ...[
                  _buildDetailRow(
                    'وقت الحضور',
                    DateFormat('yyyy-MM-dd HH:mm').format(attendanceRecord.timestamp),
                  ),
                  _buildDetailRow(
                    'نوع السجل',
                    attendanceRecord.type == AttendanceType.checkIn ? 'حضور' : 'انصراف',
                  ),
                ] else ...[
                  _buildDetailRow('حالة الحضور', 'غائب اليوم'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إغلاق',
              style: TextStyle(color: AccountantThemeConfig.primaryGreen),
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
            width: 80,
            child: Text(
              '$label:',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum WorkerListType {
  all,
  present,
  absent,
  late,
}
