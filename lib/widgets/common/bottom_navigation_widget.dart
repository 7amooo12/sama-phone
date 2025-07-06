import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/providers/home_provider.dart';
import 'package:smartbiztracker_new/models/user_role.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';

class BottomNavigationWidget extends StatelessWidget {
  const BottomNavigationWidget({
    super.key,
    required this.userRole,
  });
  final UserRole userRole;

  @override
  Widget build(BuildContext context) {
    final homeProvider = Provider.of<HomeProvider>(context);
    final currentIndex = homeProvider.currentIndex;

    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor:
          Theme.of(context).colorScheme.onSurface.safeOpacity(0.6),
      selectedFontSize: 12,
      unselectedFontSize: 10,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications_outlined),
          activeIcon: Icon(Icons.notifications),
          label: 'الإشعارات',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_outlined),
          activeIcon: Icon(Icons.chat),
          label: 'الدردشات',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'الملف الشخصي',
        ),
      ],
      onTap: (index) {
        // Handle navigation based on role and index
        String route = '';

        switch (index) {
          case 0:
            // Notifications
            route = AppRoutes.notifications;
            break;
          case 1:
            // Chat list
            route = AppRoutes.chatList;
            break;
          case 2:
            // Profile
            route = AppRoutes.profile;
            break;
        }

        // Update the selected tab in the provider
        homeProvider.changeTab(index, route);

        // Navigate to the selected route
        if (route.isNotEmpty &&
            ModalRoute.of(context)?.settings.name != route) {
          Navigator.of(context).pushReplacementNamed(route);
        }
      },
    );
  }
}
