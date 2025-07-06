/// Attendance Summary Cards Widget for SmartBizTracker
/// 
/// This widget displays summary statistics cards for attendance reports
/// with professional styling and animations.

import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/attendance_models.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';

class AttendanceSummaryCards extends StatefulWidget {
  final AttendanceReportSummary summary;
  final bool isLoading;

  const AttendanceSummaryCards({
    super.key,
    required this.summary,
    this.isLoading = false,
  });

  @override
  State<AttendanceSummaryCards> createState() => _AttendanceSummaryCardsState();
}

class _AttendanceSummaryCardsState extends State<AttendanceSummaryCards>
    with TickerProviderStateMixin {
  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<double>> _fadeAnimations;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationControllers = List.generate(
      6, // Number of summary cards
      (index) => AnimationController(
        duration: Duration(milliseconds: 600 + (index * 100)),
        vsync: this,
      ),
    );

    _scaleAnimations = _animationControllers.map((controller) =>
        Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(
          parent: controller,
          curve: Curves.elasticOut,
        ))).toList();

    _fadeAnimations = _animationControllers.map((controller) =>
        Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ))).toList();

    // Start animations with staggered delays
    for (int i = 0; i < _animationControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _animationControllers[i].forward();
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'إحصائيات الحضور - ${widget.summary.period.displayName}',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Summary cards grid
        LayoutBuilder(
          builder: (context, constraints) {
            // Responsive grid based on screen width
            final crossAxisCount = constraints.maxWidth > 1200 ? 3 : 
                                   constraints.maxWidth > 800 ? 2 : 1;
            
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.8,
              children: [
                _buildSummaryCard(
                  index: 0,
                  title: 'إجمالي العمال',
                  value: widget.summary.totalWorkers.toString(),
                  icon: Icons.people_rounded,
                  color: AccountantThemeConfig.accentBlue,
                  subtitle: 'عامل مسجل',
                ),
                _buildSummaryCard(
                  index: 1,
                  title: 'العمال الحاضرون',
                  value: widget.summary.presentWorkers.toString(),
                  icon: Icons.check_circle_rounded,
                  color: AccountantThemeConfig.primaryGreen,
                  subtitle: 'حاضر اليوم',
                ),
                _buildSummaryCard(
                  index: 2,
                  title: 'العمال الغائبون',
                  value: widget.summary.absentWorkers.toString(),
                  icon: Icons.cancel_rounded,
                  color: AccountantThemeConfig.dangerRed,
                  subtitle: 'غائب اليوم',
                ),
                _buildSummaryCard(
                  index: 3,
                  title: 'معدل الحضور',
                  value: widget.summary.formattedAttendanceRate,
                  icon: Icons.trending_up_rounded,
                  color: AccountantThemeConfig.warningOrange,
                  subtitle: 'نسبة الحضور',
                ),
                _buildSummaryCard(
                  index: 4,
                  title: 'التأخيرات',
                  value: widget.summary.totalLateArrivals.toString(),
                  icon: Icons.access_time_rounded,
                  color: AccountantThemeConfig.warningOrange,
                  subtitle: 'حالة تأخير',
                ),
                _buildSummaryCard(
                  index: 5,
                  title: 'متوسط ساعات العمل',
                  value: widget.summary.formattedAverageHours,
                  icon: Icons.schedule_rounded,
                  color: AccountantThemeConfig.accentBlue,
                  subtitle: 'ساعة يومياً',
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required int index,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return AnimatedBuilder(
      animation: _animationControllers[index],
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimations[index],
          child: ScaleTransition(
            scale: _scaleAnimations[index],
            child: Container(
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.cardGradient,
                borderRadius: BorderRadius.circular(16),
                border: AccountantThemeConfig.glowBorder(color),
                boxShadow: [
                  ...AccountantThemeConfig.cardShadows,
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.isLoading ? null : () => _onCardTap(index),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon and title row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    color.withOpacity(0.2),
                                    color.withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: color.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                icon,
                                color: color,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                title,
                                style: AccountantThemeConfig.bodyMedium.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Value
                        if (widget.isLoading)
                          Container(
                            height: 32,
                            width: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          )
                        else
                          Text(
                            value,
                            style: AccountantThemeConfig.headlineLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                            ),
                          ),
                        
                        const SizedBox(height: 4),
                        
                        // Subtitle
                        Text(
                          subtitle,
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onCardTap(int index) {
    // Add haptic feedback
    // HapticFeedback.lightImpact();
    
    // Add visual feedback animation
    _animationControllers[index].reverse().then((_) {
      if (mounted) {
        _animationControllers[index].forward();
      }
    });
    
    // TODO: Implement navigation to detailed views based on card type
    switch (index) {
      case 0: // Total workers
        // Navigate to all workers list
        break;
      case 1: // Present workers
        // Navigate to present workers list
        break;
      case 2: // Absent workers
        // Navigate to absent workers list
        break;
      case 3: // Attendance rate
        // Show attendance rate details
        break;
      case 4: // Late arrivals
        // Navigate to late arrivals list
        break;
      case 5: // Average hours
        // Show working hours details
        break;
    }
  }
}
