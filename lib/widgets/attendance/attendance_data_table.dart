/// Attendance Data Table Widget for SmartBizTracker
/// 
/// This widget displays a professional data table with worker attendance information
/// including status indicators, responsive design, and RTL support.

import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/attendance_models.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:intl/intl.dart';

class AttendanceDataTable extends StatefulWidget {
  final List<WorkerAttendanceReportData> reportData;
  final bool isLoading;
  final String userRole;

  const AttendanceDataTable({
    super.key,
    required this.reportData,
    this.isLoading = false,
    required this.userRole,
  });

  @override
  State<AttendanceDataTable> createState() => _AttendanceDataTableState();
}

class _AttendanceDataTableState extends State<AttendanceDataTable> {
  String _searchQuery = '';
  AttendanceReportStatus? _statusFilter;
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  List<WorkerAttendanceReportData> _filteredData = [];

  @override
  void initState() {
    super.initState();
    _updateFilteredData();
  }

  @override
  void didUpdateWidget(AttendanceDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reportData != widget.reportData) {
      _updateFilteredData();
    }
  }

  void _updateFilteredData() {
    _filteredData = widget.reportData.where((data) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        if (!data.workerName.toLowerCase().contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }
      
      // Status filter
      if (_statusFilter != null) {
        if (data.checkInStatus != _statusFilter && data.checkOutStatus != _statusFilter) {
          return false;
        }
      }
      
      return true;
    }).toList();

    // Sort data
    _sortData();
  }

  void _sortData() {
    _filteredData.sort((a, b) {
      int comparison = 0;
      
      switch (_sortColumnIndex) {
        case 0: // Worker name
          comparison = a.workerName.compareTo(b.workerName);
          break;
        case 1: // Check-in time
          if (a.checkInTime != null && b.checkInTime != null) {
            comparison = a.checkInTime!.compareTo(b.checkInTime!);
          } else if (a.checkInTime != null) {
            comparison = -1;
          } else if (b.checkInTime != null) {
            comparison = 1;
          }
          break;
        case 2: // Check-out time
          if (a.checkOutTime != null && b.checkOutTime != null) {
            comparison = a.checkOutTime!.compareTo(b.checkOutTime!);
          } else if (a.checkOutTime != null) {
            comparison = -1;
          } else if (b.checkOutTime != null) {
            comparison = 1;
          }
          break;
        case 3: // Total hours
          comparison = a.totalHoursWorked.compareTo(b.totalHoursWorked);
          break;
        case 4: // Attendance days
          comparison = a.attendanceDays.compareTo(b.attendanceDays);
          break;
        case 5: // Absence days
          comparison = a.absenceDays.compareTo(b.absenceDays);
          break;
        case 6: // Late arrivals
          comparison = a.lateArrivals.compareTo(b.lateArrivals);
          break;
        case 7: // Status (sort by attendance days, then by late arrivals)
          comparison = a.attendanceDays.compareTo(b.attendanceDays);
          if (comparison == 0) {
            comparison = a.lateArrivals.compareTo(b.lateArrivals);
          }
          break;
      }
      
      return _sortAscending ? comparison : -comparison;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header and controls
        _buildTableHeader(),
        
        const SizedBox(height: 16),
        
        // Search and filter controls
        _buildSearchAndFilters(),
        
        const SizedBox(height: 16),
        
        // Data table
        _buildDataTable(),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.list_alt_rounded,
                    color: AccountantThemeConfig.accentBlue,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'سجل الحضور الشامل',
                    style: AccountantThemeConfig.headlineSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${_filteredData.length} من ${widget.reportData.length} عامل',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        
        // Refresh button
        Container(
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.blueGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.isLoading ? null : () {
                // Trigger refresh
                setState(() {
                  _updateFilteredData();
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Row(
      children: [
        // Search field
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.cardGradient,
              borderRadius: BorderRadius.circular(12),
              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _updateFilteredData();
                });
              },
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: 'البحث عن عامل...',
                hintStyle: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white60,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.white60,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Status filter
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.cardGradient,
              borderRadius: BorderRadius.circular(12),
              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AttendanceReportStatus?>(
                value: _statusFilter,
                onChanged: (value) {
                  setState(() {
                    _statusFilter = value;
                    _updateFilteredData();
                  });
                },
                hint: Text(
                  'فلترة الحالة',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white60,
                  ),
                ),
                dropdownColor: AccountantThemeConfig.luxuryBlack,
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white,
                ),
                items: [
                  DropdownMenuItem<AttendanceReportStatus?>(
                    value: null,
                    child: Text('جميع الحالات'),
                  ),
                  ...AttendanceReportStatus.values.map((status) =>
                    DropdownMenuItem<AttendanceReportStatus?>(
                      value: status,
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: status.statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(status.displayName),
                        ],
                      ),
                    ),
                  ),
                ],
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataTable() {
    if (widget.isLoading) {
      return _buildLoadingTable();
    }

    if (_filteredData.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          sortColumnIndex: _sortColumnIndex,
          sortAscending: _sortAscending,
          headingRowColor: MaterialStateProperty.all(
            AccountantThemeConfig.accentBlue.withOpacity(0.1),
          ),
          headingTextStyle: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          dataTextStyle: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white70,
          ),
          columns: [
            DataColumn(
              label: const Text('العامل'),
              onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),
            ),
            DataColumn(
              label: const Text('الحضور'),
              onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),
            ),
            DataColumn(
              label: const Text('الانصراف'),
              onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),
            ),
            DataColumn(
              label: const Text('ساعات العمل'),
              numeric: true,
              onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),
            ),
            DataColumn(
              label: const Text('أيام الحضور'),
              numeric: true,
              onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),
            ),
            DataColumn(
              label: const Text('أيام الغياب'),
              numeric: true,
              onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),
            ),
            DataColumn(
              label: const Text('التأخيرات'),
              numeric: true,
              onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),
            ),
            DataColumn(
              label: const Text('الحالة'),
              onSort: (columnIndex, ascending) => _onSort(columnIndex, ascending),
            ),
          ],
          rows: _filteredData.map((data) => _buildDataRow(data)).toList(),
        ),
      ),
    );
  }

  DataRow _buildDataRow(WorkerAttendanceReportData data) {
    return DataRow(
      cells: [
        // Worker name with profile image
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AccountantThemeConfig.accentBlue.withOpacity(0.2),
                backgroundImage: data.profileImageUrl != null 
                    ? NetworkImage(data.profileImageUrl!) 
                    : null,
                child: data.profileImageUrl == null 
                    ? Icon(
                        Icons.person_rounded,
                        color: AccountantThemeConfig.accentBlue,
                        size: 20,
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  data.workerName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        
        // Check-in time with status
        DataCell(_buildTimeCell(data.checkInTime, data.checkInStatus)),
        
        // Check-out time with status
        DataCell(_buildTimeCell(data.checkOutTime, data.checkOutStatus)),
        
        // Total hours worked
        DataCell(Text(_formatHours(data.totalHoursWorked))),
        
        // Attendance days
        DataCell(Text(data.attendanceDays.toString())),
        
        // Absence days
        DataCell(Text(data.absenceDays.toString())),
        
        // Late arrivals
        DataCell(_buildLateCell(data.lateArrivals, data.lateMinutes)),

        // Overall status
        DataCell(_buildStatusCell(data)),
      ],
    );
  }

  Widget _buildTimeCell(DateTime? time, AttendanceReportStatus status) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: status.statusColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          time != null 
              ? DateFormat('HH:mm').format(time)
              : '--:--',
        ),
      ],
    );
  }

  Widget _buildLateCell(int lateCount, int lateMinutes) {
    if (lateCount == 0) {
      return const Text('--');
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lateCount.toString()),
        Text(
          '($lateMinutes د)',
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: Colors.white60,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCell(WorkerAttendanceReportData data) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (data.attendanceDays == 0) {
      statusText = 'غائب';
      statusColor = Colors.grey;
      statusIcon = Icons.remove_circle_outline;
    } else if (data.lateArrivals > 0) {
      statusText = 'متأخر';
      statusColor = AccountantThemeConfig.warningOrange;
      statusIcon = Icons.schedule;
    } else if (data.totalHoursWorked >= 8.0) {
      statusText = 'ممتاز';
      statusColor = AccountantThemeConfig.primaryGreen;
      statusIcon = Icons.check_circle;
    } else {
      statusText = 'حاضر';
      statusColor = AccountantThemeConfig.accentBlue;
      statusIcon = Icons.check_circle_outline;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          statusIcon,
          color: statusColor,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          statusText,
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: statusColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatHours(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    return '${h}س ${m}د';
  }

  Widget _buildLoadingTable() {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: AccountantThemeConfig.primaryGreen,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Colors.white60,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد بيانات حضور',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لم يتم العثور على بيانات حضور للفترة المحددة',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white60,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _sortData();
    });
  }
}
