import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/screens/orders/orders_screen.dart';
import 'package:smartbiztracker_new/screens/damaged/damaged_items_screen.dart';
import 'package:smartbiztracker_new/screens/products/products_screen.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/utils/localization.dart';

class AppDrawer extends StatefulWidget {
  final UserRole userRole;
  
  const AppDrawer({
    Key? key,
    required this.userRole,
  }) : super(key: key);

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: Colors.blue),
                ),
                const SizedBox(height: 10),
                Text(
                  'سمارت ستوك',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'إدارة المخزون الذكية',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          if (widget.userRole == UserRole.admin || 
              widget.userRole == UserRole.owner || 
              widget.userRole == UserRole.worker) {
            ExpansionTile(
              title: Text(AppLocalizations.of(context)?.translate('warehouse') ?? 'المخزن'),
              leading: const Icon(Icons.warehouse),
              children: [
                ListTile(
                  leading: const Icon(Icons.shopping_cart),
                  title: Text(AppLocalizations.of(context)?.translate('orders') ?? 'الطلبات'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const OrdersScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.warning),
                  title: Text(AppLocalizations.of(context)?.translate('damaged_items') ?? 'التالف'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DamagedItemsScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.inventory),
                  title: Text(AppLocalizations.of(context)?.translate('products') ?? 'المنتجات'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProductsScreen()),
                    );
                  },
                ),
              ],
            ),
          },
          
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text(AppLocalizations.of(context)?.translate('settings') ?? 'الإعدادات'),
            onTap: () {
              Navigator.pop(context);
              // Navigate to settings
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(AppLocalizations.of(context)?.translate('logout') ?? 'تسجيل الخروج'),
            onTap: () {
              Navigator.pop(context);
              // Implement logout
            },
          ),
        ],
      ),
    );
  }
} 