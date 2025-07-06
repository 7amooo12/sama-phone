/// Location-Aware Analytics Widget for Admin Dashboard
/// 
/// This widget provides comprehensive analytics and reporting features
/// for location-based attendance data in the SmartBizTracker system.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/location_models.dart';
import '../../providers/attendance_provider.dart';
import '../../services/location_service.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';

class LocationAnalyticsWidget extends StatefulWidget {
  const LocationAnalyticsWidget({super.key});

  @override
  State<LocationAnalyticsWidget> createState() => _LocationAnalyticsWidgetState();
}

class _LocationAnalyticsWidgetState extends State<LocationAnalyticsWidget>
    with TickerProviderStateMixin {
  
  final LocationService _locationService = LocationService();
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  
  // State
  bool _isLoading = false;
  Map<String, dynamic>? _locationStats;
  DateTime _selectedStartDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _selectedEndDate = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadLocationStats();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadLocationStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load real location statistics from database
      _locationStats = await _locationService.getLocationAttendanceStats(
        startDate: _selectedStartDate,
        endDate: _selectedEndDate,
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل إحصائيات الموقع: $e');
      // Set empty stats on error
      _locationStats = {
        'total_records': 0,
        'location_validated': 0,
        'biometric_records': 0,
        'qr_records': 0,
        'average_distance': 0.0,
        'outside_geofence': 0,
        'location_validation_rate': 0.0,
      };
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.mainBackgroundGradient,
      ),
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeController,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 30),
                _buildDateRangeSelector(),
                const SizedBox(height: 30),
                if (_isLoading) ...[
                  _buildLoadingState(),
                ] else if (_locationStats != null) ...[
                  _buildStatsOverview(),
                  const SizedBox(height: 30),
                  _buildMethodDistributionChart(),
                  const SizedBox(height: 30),
                  _buildLocationValidationChart(),
                  const SizedBox(height: 30),
                  _buildDistanceAnalytics(),
                ] else ...[
                  _buildEmptyState(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(-0.3, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.elasticOut,
      )),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  AccountantThemeConfig.accentBlue.withValues(alpha: 0.3),
                  AccountantThemeConfig.accentBlue.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.analytics_rounded,
              color: AccountantThemeConfig.accentBlue,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تحليلات الموقع والحضور',
                  style: AccountantThemeConfig.headlineLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'إحصائيات شاملة للحضور المبني على الموقع',
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

  Widget _buildDateRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'فترة التحليل',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: AccountantThemeConfig.primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDateSelector(
                  label: 'من تاريخ',
                  date: _selectedStartDate,
                  onDateSelected: (date) {
                    setState(() {
                      _selectedStartDate = date;
                    });
                    _loadLocationStats();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDateSelector(
                  label: 'إلى تاريخ',
                  date: _selectedEndDate,
                  onDateSelected: (date) {
                    setState(() {
                      _selectedEndDate = date;
                    });
                    _loadLocationStats();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector({
    required String label,
    required DateTime date,
    required Function(DateTime) onDateSelected,
  }) {
    return GestureDetector(
      onTap: () async {
        final selectedDate = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.dark(
                  primary: AccountantThemeConfig.primaryGreen,
                  surface: Colors.grey[800]!,
                ),
              ),
              child: child!,
            );
          },
        );
        if (selectedDate != null) {
          onDateSelected(selectedDate);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${date.day}/${date.month}/${date.year}',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AccountantThemeConfig.accentBlue,
            ),
            const SizedBox(height: 16),
            Text(
              'جاري تحميل التحليلات...',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsOverview() {
    final stats = _locationStats!;
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          title: 'إجمالي السجلات',
          value: stats['total_records'].toString(),
          icon: Icons.receipt_long_rounded,
          color: AccountantThemeConfig.accentBlue,
        ),
        _buildStatCard(
          title: 'التحقق من الموقع',
          value: '${stats['location_validation_rate']}%',
          icon: Icons.location_on_rounded,
          color: AccountantThemeConfig.primaryGreen,
        ),
        _buildStatCard(
          title: 'الحضور البيومتري',
          value: stats['biometric_records'].toString(),
          icon: Icons.fingerprint_rounded,
          color: AccountantThemeConfig.warningOrange,
        ),
        _buildStatCard(
          title: 'خارج النطاق',
          value: stats['outside_geofence'].toString(),
          icon: Icons.location_off_rounded,
          color: AccountantThemeConfig.dangerRed,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: 32,
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
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMethodDistributionChart() {
    final stats = _locationStats!;
    final biometricCount = stats['biometric_records'] as int;
    final qrCount = stats['qr_records'] as int;
    final total = biometricCount + qrCount;

    if (total == 0) {
      return _buildEmptyChartCard('توزيع طرق الحضور');
    }

    return Container(
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
            'توزيع طرق الحضور',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: AccountantThemeConfig.accentBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: biometricCount.toDouble(),
                    title: 'بصمة\n${((biometricCount / total) * 100).toStringAsFixed(1)}%',
                    color: AccountantThemeConfig.primaryGreen,
                    radius: 80,
                    titleStyle: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  PieChartSectionData(
                    value: qrCount.toDouble(),
                    title: 'QR\n${((qrCount / total) * 100).toStringAsFixed(1)}%',
                    color: AccountantThemeConfig.warningOrange,
                    radius: 80,
                    titleStyle: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationValidationChart() {
    final stats = _locationStats!;
    final validatedCount = stats['location_validated'] as int;
    final totalCount = stats['total_records'] as int;
    final invalidCount = totalCount - validatedCount;

    if (totalCount == 0) {
      return _buildEmptyChartCard('التحقق من الموقع');
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'التحقق من الموقع',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: AccountantThemeConfig.primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: validatedCount.toDouble(),
                    title: 'صحيح\n${((validatedCount / totalCount) * 100).toStringAsFixed(1)}%',
                    color: AccountantThemeConfig.primaryGreen,
                    radius: 80,
                    titleStyle: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  PieChartSectionData(
                    value: invalidCount.toDouble(),
                    title: 'خاطئ\n${((invalidCount / totalCount) * 100).toStringAsFixed(1)}%',
                    color: AccountantThemeConfig.dangerRed,
                    radius: 80,
                    titleStyle: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceAnalytics() {
    final stats = _locationStats!;
    final avgDistance = stats['average_distance'] as double;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.warningOrange),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تحليل المسافات',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: AccountantThemeConfig.warningOrange,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(
                Icons.straighten_rounded,
                color: AccountantThemeConfig.warningOrange,
                size: 32,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'متوسط المسافة من المخزن',
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${avgDistance.toStringAsFixed(1)} متر',
                    style: AccountantThemeConfig.headlineMedium.copyWith(
                      color: AccountantThemeConfig.warningOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChartCard(String title) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        children: [
          Text(
            title,
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Icon(
            Icons.pie_chart_outline_rounded,
            color: Colors.white30,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد بيانات للفترة المحددة',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white50,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              color: Colors.white30,
              size: 80,
            ),
            const SizedBox(height: 20),
            Text(
              'لا توجد بيانات تحليلية',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ابدأ بتسجيل الحضور لرؤية التحليلات',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white50,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
