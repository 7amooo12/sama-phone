import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/models/user_role.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/screens/admin/admin_dashboard.dart';
import 'package:smartbiztracker_new/screens/auth/login_screen.dart';
import 'package:smartbiztracker_new/screens/auth/waiting_approval_screen.dart';
import 'package:smartbiztracker_new/screens/client/client_dashboard.dart';
import 'package:smartbiztracker_new/screens/owner/owner_dashboard.dart';
import 'package:smartbiztracker_new/screens/worker/worker_dashboard.dart';
import 'package:smartbiztracker_new/screens/accountant/accountant_dashboard.dart';
import 'package:smartbiztracker_new/screens/menu_screen.dart';
import 'package:smartbiztracker_new/screens/transition_screen.dart';
import 'package:smartbiztracker_new/utils/logger.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Check auth state when this widget initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).checkAuthState();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    // Show loading screen while checking authentication
    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // If not authenticated, show menu screen
    if (user == null) {
      return const MenuScreen();
    }

    // If user is pending approval
    if (user.status == 'pending') {
      return const WaitingApprovalScreen();
    }

    // If user is rejected
    if (user.status == 'rejected') {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'تم رفض طلب التسجيل',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await authProvider.signOut();
                  if (mounted) {
                    Navigator.of(context).pushReplacementNamed(AppRoutes.menu);
                  }
                },
                child: const Text('العودة للقائمة الرئيسية'),
              ),
            ],
          ),
        ),
      );
    }

    // Navigate to appropriate dashboard based on user role
    WidgetsBinding.instance.addPostFrameCallback((_) {
      String dashboardRoute;
      final role = UserRole.fromString(user.userRole);
      
      switch (role) {
        case UserRole.admin:
          dashboardRoute = AppRoutes.adminDashboard;
          break;
        case UserRole.owner:
          dashboardRoute = AppRoutes.ownerDashboard;
          break;
        case UserRole.worker:
          dashboardRoute = AppRoutes.workerDashboard;
          break;
        case UserRole.client:
          dashboardRoute = AppRoutes.clientDashboard;
          break;
        case UserRole.accountant:
          dashboardRoute = AppRoutes.accountantDashboard;
          break;
        default:
          AppLogger().w('Unknown user role: ${user.userRole}');
          dashboardRoute = AppRoutes.menu;
          break;
      }
      
      Navigator.of(context).pushReplacementNamed(dashboardRoute);
    });
    
    // Return loading indicator while navigation is being processed
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
