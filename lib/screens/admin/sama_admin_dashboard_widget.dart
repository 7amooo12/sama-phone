import 'package:smartbiztracker_new/widgets/admin/order_management_widget.dart';

class SamaAdminDashboardWidget extends StatefulWidget {
  // ... (existing code)

  @override
  _SamaAdminDashboardWidgetState createState() => _SamaAdminDashboardWidgetState();
}

class _SamaAdminDashboardWidgetState extends State<SamaAdminDashboardWidget> {
  // ... (existing code)

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: _tabController,
      children: [
        // Dashboard tab
        _buildDashboardTab(),
        
        // Orders tab - Replace with OrderManagementWidget
        OrderManagementWidget(
          userRole: 'admin',
          showHeader: false,
          onAddOrder: () {
            // Handle add new order
          },
        ),
        
        // Products tab
        widget.productWidget ?? const ProductManagementWidget(
          showHeader: false,
        ),
        
        // ... (existing code)
      ],
    );
  }

  // ... (rest of the existing code)
} 