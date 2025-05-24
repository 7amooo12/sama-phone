import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/models/user_role.dart';

class WaitingApprovalScreen extends StatelessWidget {
  const WaitingApprovalScreen({Key? key}) : super(key: key);

  // Add this method to determine the dashboard route based on user role
  String _getDashboardRoute(UserModel user) {
    switch (user.role) {
      case UserRole.admin:
        return AppRoutes.adminDashboard;
      case UserRole.client:
        return AppRoutes.clientDashboard;
      case UserRole.worker:
        return AppRoutes.workerDashboard;
      case UserRole.owner:
        return AppRoutes.ownerDashboard;
      case UserRole.accountant:
        return AppRoutes.accountantDashboard;
      default:
        return AppRoutes.login;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final user = supabaseProvider.user;

    // Check if user is approved already
    if (user != null && user.status == 'approved') {
      // Navigate to appropriate dashboard
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(_getDashboardRoute(user));
      });
    }

    // Using the newer onWillPop callback approach with Navigator 2.0
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        // Log user out when going back
        await supabaseProvider.signOut();
        if (context.mounted) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.login);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animation
                  Lottie.asset(
                    'assets/animations/waiting.json',
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 32),

                  // Title
                  const Text(
                    'في انتظار الموافقة',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  const Text(
                    'حسابك في انتظار الموافقة من الإدارة. سيتم إعلامك عندما يتم الموافقة على حسابك.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),
                
                  // Sign out button
                  ElevatedButton(
                    onPressed: () async {
                      await supabaseProvider.signOut();
                      
                      if (context.mounted) {
                        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: const Text('تسجيل الخروج'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
