import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/screens/accountant/accountant_products_screen.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/config/routes.dart';

class StandaloneAccountantProductsScreen extends StatefulWidget {
  const StandaloneAccountantProductsScreen({super.key});

  @override
  State<StandaloneAccountantProductsScreen> createState() => _StandaloneAccountantProductsScreenState();
}

class _StandaloneAccountantProductsScreenState extends State<StandaloneAccountantProductsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _userRole = 'accountant'; // Default to accountant role for this screen

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
          _userRole = 'accountant'; // Default fallback for this screen
        }
      });
    }
  }

  String _getAppBarTitle() {
    return 'المنتجات';
  }

  String _getCurrentRoute() {
    return '/accountant/products';
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
                           user.isWorker() ? 'worker' : 'accountant';
    
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
              // Refresh functionality will be handled by AccountantProductsScreen
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
        child: const AccountantProductsScreen(),
      ),
    );
  }
}
