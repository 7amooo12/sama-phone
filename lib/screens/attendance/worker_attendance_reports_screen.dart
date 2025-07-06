/// Worker Attendance Reports Screen for SmartBizTracker
/// 
/// This screen provides comprehensive attendance reporting functionality
/// for Business Owner, Accountant, and Admin roles.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/models/attendance_models.dart';
import 'package:smartbiztracker_new/providers/worker_attendance_reports_provider.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/widgets/common/custom_loader.dart';

import 'package:smartbiztracker_new/widgets/attendance/attendance_data_table.dart';
import 'package:smartbiztracker_new/widgets/attendance/attendance_settings_dialog.dart';

class WorkerAttendanceReportsScreen extends StatefulWidget {
  final String userRole;
  
  const WorkerAttendanceReportsScreen({
    super.key,
    required this.userRole,
  });

  @override
  State<WorkerAttendanceReportsScreen> createState() => _WorkerAttendanceReportsScreenState();
}

class _WorkerAttendanceReportsScreenState extends State<WorkerAttendanceReportsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeProvider();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  Future<void> _initializeProvider() async {
    try {
      final provider = Provider.of<WorkerAttendanceReportsProvider>(context, listen: false);
      await provider.initialize();
    } catch (e) {
      AppLogger.error('❌ خطأ في تهيئة مزود تقارير الحضور: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  // Header with title and settings
                  _buildHeader(),
                  
                  // Time period selector
                  _buildPeriodSelector(),
                  
                  // Content area
                  Flexible(
                    child: Consumer<WorkerAttendanceReportsProvider>(
                      builder: (context, provider, child) {
                        if (provider.isLoading && !provider.isInitialized) {
                          return _buildLoadingState();
                        }

                        if (provider.error != null) {
                          return _buildErrorState(provider.error!);
                        }

                        return _buildReportsContent(provider);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Title section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تقارير حضور العمال',
                  style: AccountantThemeConfig.headlineLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),

              ],
            ),
          ),
          
          // Settings button
          _buildSettingsButton(),
          
          const SizedBox(width: 12),
          
          // Export button
          _buildExportButton(),
        ],
      ),
    );
  }

  Widget _buildSettingsButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.blueGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showSettingsDialog,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: const Icon(
              Icons.settings_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExportButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.greenGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showExportDialog,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: const Icon(
              Icons.file_download_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Consumer<WorkerAttendanceReportsProvider>(
      builder: (context, provider, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(16),
            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
            boxShadow: AccountantThemeConfig.cardShadows,
          ),
          child: Row(
            children: AttendanceReportPeriod.values.map((period) {
              final isSelected = provider.selectedPeriod == period;
              return Expanded(
                child: _buildPeriodButton(
                  period: period,
                  isSelected: isSelected,
                  onTap: () => provider.changePeriod(period),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildPeriodButton({
    required AttendanceReportPeriod period,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.all(2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              gradient: isSelected 
                  ? AccountantThemeConfig.greenGradient
                  : null,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSelected 
                  ? AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen)
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  period.displayName,
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  period.description,
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: isSelected ? Colors.white70 : Colors.white60,
                    fontSize: 10,
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

  Widget _buildLoadingState() {
    return const Center(
      child: CustomLoader(
        message: 'جاري تحميل تقارير الحضور...',
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
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
              Icons.error_outline_rounded,
              size: 48,
              color: AccountantThemeConfig.dangerRed,
            ),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ في تحميل التقارير',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                final provider = Provider.of<WorkerAttendanceReportsProvider>(context, listen: false);
                provider.refresh();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
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
      ),
    );
  }

  Widget _buildReportsContent(WorkerAttendanceReportsProvider provider) {
    return RefreshIndicator(
      onRefresh: () async {
        try {
          await provider.forceRefresh();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('فشل في تحديث البيانات: $e'),
                backgroundColor: AccountantThemeConfig.dangerRed,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        }
      },
      color: AccountantThemeConfig.primaryGreen,
      backgroundColor: AccountantThemeConfig.luxuryBlack,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Real-time status indicator
            _buildRealTimeStatusIndicator(provider),

            const SizedBox(height: 16),



            // Data table with enhanced error handling
            AttendanceDataTable(
              reportData: provider.reportData,
              isLoading: provider.isLoading,
              userRole: widget.userRole,
            ),

            // Additional spacing for better UX
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildRealTimeStatusIndicator(WorkerAttendanceReportsProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: provider.isLoading
                  ? AccountantThemeConfig.warningOrange
                  : AccountantThemeConfig.primaryGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            provider.isLoading ? 'جاري التحديث...' : 'محدث',
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          if (provider.isLoading) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AccountantThemeConfig.warningOrange,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }



  void _showSettingsDialog() {
    final provider = Provider.of<WorkerAttendanceReportsProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AttendanceSettingsDialog(
        currentSettings: provider.attendanceSettings,
        onSettingsChanged: (newSettings) {
          provider.updateAttendanceSettings(newSettings);
        },
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.luxuryBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AccountantThemeConfig.accentBlue.withOpacity(0.3),
            width: 1,
          ),
        ),
        title: Text(
          'تصدير التقرير',
          style: AccountantThemeConfig.headlineSmall.copyWith(
            color: Colors.white,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'اختر صيغة التصدير المطلوبة:',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _exportReport('pdf'),
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text('PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AccountantThemeConfig.dangerRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _exportReport('excel'),
                    icon: const Icon(Icons.table_chart_rounded),
                    label: const Text('Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AccountantThemeConfig.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportReport(String format) async {
    Navigator.of(context).pop(); // Close dialog
    
    try {
      final provider = Provider.of<WorkerAttendanceReportsProvider>(context, listen: false);
      final result = await provider.exportReportData(format: format);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result),
            backgroundColor: AccountantThemeConfig.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تصدير التقرير: $e'),
            backgroundColor: AccountantThemeConfig.dangerRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }
}
