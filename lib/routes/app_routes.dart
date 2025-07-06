class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String register = '/register';
  static const String adminDashboard = '/admin-dashboard';
  static const String ownerDashboard = '/owner-dashboard';
  static const String accountantDashboard = '/accountant-dashboard';
  static const String clientDashboard = '/client-dashboard';
  static const String workerDashboard = '/worker-dashboard';
  // SECURITY FIX: Align warehouse manager route with config/routes.dart
  static const String warehouseManagerDashboard = '/warehouse-manager';
  static const String waitingApproval = '/waiting-approval';
  static const String profile = '/profile';
  static const String workerAttendanceReports = '/worker-attendance-reports';
  static const String changePassword = '/change-password';
}