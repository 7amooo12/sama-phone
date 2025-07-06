/// Attendance Settings Dialog Widget for SmartBizTracker
/// 
/// This widget provides a comprehensive settings dialog for configuring
/// attendance parameters including work hours, tolerance periods, and work days.

import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/attendance_models.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';

class AttendanceSettingsDialog extends StatefulWidget {
  final AttendanceSettings currentSettings;
  final Function(AttendanceSettings) onSettingsChanged;

  const AttendanceSettingsDialog({
    super.key,
    required this.currentSettings,
    required this.onSettingsChanged,
  });

  @override
  State<AttendanceSettingsDialog> createState() => _AttendanceSettingsDialogState();
}

class _AttendanceSettingsDialogState extends State<AttendanceSettingsDialog> {
  late TimeOfDay _workStartTime;
  late TimeOfDay _workEndTime;
  late int _lateToleranceMinutes;
  late int _earlyDepartureToleranceMinutes;
  late double _requiredDailyHours;
  late List<int> _workDays;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  void _initializeSettings() {
    _workStartTime = widget.currentSettings.workStartTime;
    _workEndTime = widget.currentSettings.workEndTime;
    _lateToleranceMinutes = widget.currentSettings.lateToleranceMinutes;
    _earlyDepartureToleranceMinutes = widget.currentSettings.earlyDepartureToleranceMinutes;
    _requiredDailyHours = widget.currentSettings.requiredDailyHours;
    _workDays = List.from(widget.currentSettings.workDays);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
          borderRadius: BorderRadius.circular(20),
          border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
          boxShadow: [
            ...AccountantThemeConfig.cardShadows,
            BoxShadow(
              color: AccountantThemeConfig.accentBlue.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Work hours section
                      _buildWorkHoursSection(),
                      
                      const SizedBox(height: 24),
                      
                      // Tolerance settings section
                      _buildToleranceSection(),
                      
                      const SizedBox(height: 24),
                      
                      // Required hours section
                      _buildRequiredHoursSection(),
                      
                      const SizedBox(height: 24),
                      
                      // Work days section
                      _buildWorkDaysSection(),
                    ],
                  ),
                ),
              ),
            ),
            
            // Actions
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border(
          bottom: BorderSide(
            color: AccountantThemeConfig.accentBlue.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.blueGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إعدادات الحضور',
                  style: AccountantThemeConfig.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'تكوين أوقات العمل وقواعد الحضور',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkHoursSection() {
    return _buildSection(
      title: 'أوقات العمل',
      icon: Icons.schedule_rounded,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTimeField(
                label: 'بداية العمل',
                time: _workStartTime,
                onTimeChanged: (time) => setState(() => _workStartTime = time),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTimeField(
                label: 'نهاية العمل',
                time: _workEndTime,
                onTimeChanged: (time) => setState(() => _workEndTime = time),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToleranceSection() {
    return _buildSection(
      title: 'فترات التسامح',
      icon: Icons.access_time_rounded,
      children: [
        _buildNumberField(
          label: 'تسامح التأخير (بالدقائق)',
          value: _lateToleranceMinutes,
          onChanged: (value) => setState(() => _lateToleranceMinutes = value),
          min: 0,
          max: 60,
        ),
        const SizedBox(height: 16),
        _buildNumberField(
          label: 'تسامح الانصراف المبكر (بالدقائق)',
          value: _earlyDepartureToleranceMinutes,
          onChanged: (value) => setState(() => _earlyDepartureToleranceMinutes = value),
          min: 0,
          max: 60,
        ),
      ],
    );
  }

  Widget _buildRequiredHoursSection() {
    return _buildSection(
      title: 'ساعات العمل المطلوبة',
      icon: Icons.timer_rounded,
      children: [
        _buildSliderField(
          label: 'عدد الساعات اليومية المطلوبة',
          value: _requiredDailyHours,
          onChanged: (value) => setState(() => _requiredDailyHours = value),
          min: 4.0,
          max: 12.0,
          divisions: 16,
          format: (value) => '${value.toStringAsFixed(1)} ساعة',
        ),
      ],
    );
  }

  Widget _buildWorkDaysSection() {
    return _buildSection(
      title: 'أيام العمل',
      icon: Icons.calendar_month_rounded,
      children: [
        _buildWorkDaysSelector(),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
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
          Row(
            children: [
              Icon(
                icon,
                color: AccountantThemeConfig.accentBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: AccountantThemeConfig.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTimeField({
    required String label,
    required TimeOfDay time,
    required Function(TimeOfDay) onTimeChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AccountantThemeConfig.accentBlue.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                final newTime = await showTimePicker(
                  context: context,
                  initialTime: time,
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.dark(
                          primary: AccountantThemeConfig.primaryGreen,
                          surface: AccountantThemeConfig.luxuryBlack,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (newTime != null) {
                  onTimeChanged(newTime);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      color: AccountantThemeConfig.accentBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time.format(context),
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberField({
    required String label,
    required int value,
    required Function(int) onChanged,
    required int min,
    required int max,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AccountantThemeConfig.accentBlue.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: TextFormField(
            initialValue: value.toString(),
            keyboardType: TextInputType.number,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffixText: 'دقيقة',
              suffixStyle: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white60,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'هذا الحقل مطلوب';
              }
              final intValue = int.tryParse(value);
              if (intValue == null || intValue < min || intValue > max) {
                return 'يجب أن تكون القيمة بين $min و $max';
              }
              return null;
            },
            onChanged: (value) {
              final intValue = int.tryParse(value);
              if (intValue != null && intValue >= min && intValue <= max) {
                onChanged(intValue);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSliderField({
    required String label,
    required double value,
    required Function(double) onChanged,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) format,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
            ),
            Text(
              format(value),
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AccountantThemeConfig.primaryGreen,
            inactiveTrackColor: Colors.white.withOpacity(0.2),
            thumbColor: AccountantThemeConfig.primaryGreen,
            overlayColor: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
            valueIndicatorColor: AccountantThemeConfig.primaryGreen,
            valueIndicatorTextStyle: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
            ),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: format(value),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkDaysSelector() {
    const dayNames = {
      1: 'الاثنين',
      2: 'الثلاثاء',
      3: 'الأربعاء',
      4: 'الخميس',
      5: 'الجمعة',
      6: 'السبت',
      7: 'الأحد',
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: dayNames.entries.map((entry) {
        final dayNumber = entry.key;
        final dayName = entry.value;
        final isSelected = _workDays.contains(dayNumber);

        return FilterChip(
          label: Text(dayName),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _workDays.add(dayNumber);
              } else {
                _workDays.remove(dayNumber);
              }
              _workDays.sort();
            });
          },
          backgroundColor: Colors.white.withOpacity(0.1),
          selectedColor: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
          checkmarkColor: AccountantThemeConfig.primaryGreen,
          labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
            color: isSelected ? Colors.white : Colors.white70,
          ),
          side: BorderSide(
            color: isSelected 
                ? AccountantThemeConfig.primaryGreen
                : Colors.white.withOpacity(0.3),
            width: 1,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AccountantThemeConfig.accentBlue.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              child: const Text('إلغاء'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('حفظ الإعدادات'),
            ),
          ),
        ],
      ),
    );
  }

  void _saveSettings() {
    if (_formKey.currentState?.validate() ?? false) {
      final newSettings = AttendanceSettings(
        workStartTime: _workStartTime,
        workEndTime: _workEndTime,
        lateToleranceMinutes: _lateToleranceMinutes,
        earlyDepartureToleranceMinutes: _earlyDepartureToleranceMinutes,
        requiredDailyHours: _requiredDailyHours,
        workDays: _workDays,
      );

      widget.onSettingsChanged(newSettings);
      Navigator.of(context).pop();
    }
  }
}
