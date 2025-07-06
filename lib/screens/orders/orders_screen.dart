import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/widgets/admin/order_management_widget.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/config/routes.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  _OrdersScreenState createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _userRole = 'admin'; // Default role, will be determined from user context

  @override
  void initState() {
    super.initState();
    _determineUserRole();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _determineUserRole() {
    // Get user role from providers
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = supabaseProvider.user ?? authProvider.user;

    if (user != null) {
      setState(() {
        if (user.isOwner()) {
          _userRole = 'owner';
        } else if (user.isAccountant()) {
          _userRole = 'accountant';
        } else if (user.isAdmin()) {
          _userRole = 'admin';
        } else if (user.isWorker()) {
          _userRole = 'worker';
        } else {
          _userRole = 'admin'; // Default fallback
        }
      });
    }
  }

  String _getAppBarTitle() {
    switch (_userRole) {
      case 'owner':
        return 'إدارة الطلبات';
      case 'accountant':
        return 'الطلبات';
      case 'admin':
        return 'إدارة الطلبات';
      default:
        return 'الطلبات';
    }
  }

  String _getCurrentRoute() {
    switch (_userRole) {
      case 'owner':
        return '/orders';
      case 'accountant':
        return '/orders';
      case 'admin':
        return '/orders';
      default:
        return '/orders';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get user information to determine role and handle authentication
    final supabaseProvider = Provider.of<SupabaseProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = supabaseProvider.user ?? authProvider.user;

    // Handle case where user is not logged in
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Update user role if it has changed
    final currentUserRole = user.isOwner() ? 'owner' :
                           user.isAccountant() ? 'accountant' :
                           user.isAdmin() ? 'admin' :
                           user.isWorker() ? 'worker' : 'admin';

    if (currentUserRole != _userRole) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _userRole = currentUserRole;
        });
      });
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AccountantThemeConfig.luxuryBlack,
      appBar: CustomAppBar(
        title: _getAppBarTitle(),
        backgroundColor: AccountantThemeConfig.darkBlueBlack,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
            ),
            onPressed: () {
              // Refresh functionality will be handled by OrderManagementWidget
            },
          ),
        ],
      ),
      drawer: MainDrawer(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        currentRoute: _getCurrentRoute(),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: OrderManagementWidget(
          userRole: _userRole,
          showHeader: false, // Don't show header since we have AppBar
          showSearchBar: true,
          showFilterOptions: true,
          showStatusFilters: true,
          showStatusFilter: true,
          showDateFilter: true,
          isEmbedded: false, // This is a standalone screen, not embedded in dashboard
        ),
      ),
    );
  }
}
