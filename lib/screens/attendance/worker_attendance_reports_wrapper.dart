/// Worker Attendance Reports Wrapper for SmartBizTracker
/// 
/// This wrapper provides the WorkerAttendanceReportsProvider to the
/// attendance reports screen and handles proper initialization.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/worker_attendance_reports_provider.dart';
import 'package:smartbiztracker_new/screens/attendance/worker_attendance_reports_screen.dart';

class WorkerAttendanceReportsWrapper extends StatelessWidget {
  final String userRole;

  const WorkerAttendanceReportsWrapper({
    super.key,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => WorkerAttendanceReportsProvider(),
      child: WorkerAttendanceReportsScreen(userRole: userRole),
    );
  }
}
