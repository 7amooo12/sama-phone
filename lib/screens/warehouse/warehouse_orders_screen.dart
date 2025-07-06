import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:smartbiztracker_new/widgets/admin/order_management_widget.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/routes/app_routes.dart';

/// شاشة إدارة الطلبات لمدير المخزن
/// تستخدم OrderManagementWidget مع دور warehouseManager
class WarehouseOrdersScreen extends StatefulWidget {
  const WarehouseOrdersScreen({super.key});

  @override
  State<WarehouseOrdersScreen> createState() => _WarehouseOrdersScreenState();
}

class _WarehouseOrdersScreenState extends State<WarehouseOrdersScreen> {
  String _userRole = 'warehouseManager';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _determineUserRole();
    });
  }

  void _determineUserRole() {
    // Get user role from providers
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = supabaseProvider.user ?? authProvider.user;

    if (user != null) {
      setState(() {
        if (user.isWarehouseManager()) {
          _userRole = 'warehouseManager';
        } else if (user.isAdmin()) {
          _userRole = 'admin';
        } else if (user.isAccountant()) {
          _userRole = 'accountant';
        } else if (user.isOwner()) {
          _userRole = 'owner';
        } else {
          _userRole = 'warehouseManager'; // Default fallback for this screen
        }
      });
    }
  }

  String _getAppBarTitle() {
    return 'إدارة الطلبات';
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
    final currentUserRole = user.isWarehouseManager() ? 'warehouseManager' :
                           user.isAdmin() ? 'admin' :
                           user.isAccountant() ? 'accountant' :
                           user.isOwner() ? 'owner' : 'warehouseManager';

    if (currentUserRole != _userRole) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _userRole = currentUserRole;
        });
      });
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: const MainDrawer(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              CustomAppBar(
                title: _getAppBarTitle(),
                showBackButton: false,
              ),
              
              // Orders Management Content
              Expanded(
                child: OrderManagementWidget(
                  userRole: _userRole,
                  showHeader: false, // Don't show header since we have AppBar
                  showSearchBar: true,
                  showFilterOptions: true,
                  showStatusFilters: true,
                  showStatusFilter: true,
                  showDateFilter: true,
                  isEmbedded: true, // This widget is embedded in an Expanded container
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
