import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/client_orders_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../models/client_order_model.dart';
import '../../services/supabase_orders_service.dart';
import '../../utils/app_logger.dart';

class OrderWorkflowDebugScreen extends StatefulWidget {
  const OrderWorkflowDebugScreen({super.key});

  @override
  State<OrderWorkflowDebugScreen> createState() => _OrderWorkflowDebugScreenState();
}

class _OrderWorkflowDebugScreenState extends State<OrderWorkflowDebugScreen> {
  bool _isLoading = false;
  String? _error;
  List<ClientOrder> _allOrders = [];
  List<ClientOrder> _clientOrders = [];
  List<ClientOrder> _pendingOrders = [];

  @override
  void initState() {
    super.initState();
    _loadOrderData();
  }

  Future<void> _loadOrderData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final orderProvider = Provider.of<ClientOrdersProvider>(context, listen: false);

      final currentUser = supabaseProvider.user;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      AppLogger.info('DEBUG: Loading order data for user: ${currentUser.id}');

      // Test direct Supabase service call
      AppLogger.info('DEBUG: Testing direct SupabaseOrdersService.getAllOrders()');
      final supabaseOrdersService = SupabaseOrdersService();
      final directOrders = await supabaseOrdersService.getAllOrders();
      AppLogger.info('DEBUG: Direct service returned ${directOrders.length} orders');

      // Load all orders (admin view)
      await orderProvider.loadAllOrders();
      _allOrders = orderProvider.orders;

      // Load client-specific orders
      await orderProvider.loadClientOrders(currentUser.id);
      _clientOrders = orderProvider.orders;

      // Filter pending orders
      _pendingOrders = _allOrders.where((order) => order.status == OrderStatus.pending).toList();

      AppLogger.info('DEBUG: All orders: ${_allOrders.length}');
      AppLogger.info('DEBUG: Client orders: ${_clientOrders.length}');
      AppLogger.info('DEBUG: Pending orders: ${_pendingOrders.length}');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('DEBUG: Error loading order data: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Order Workflow Debug'),
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadOrderData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.green),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'Error: $_error',
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadOrderData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 20),
                      _buildAllOrdersSection(),
                      const SizedBox(height: 20),
                      _buildClientOrdersSection(),
                      const SizedBox(height: 20),
                      _buildPendingOrdersSection(),
                      const SizedBox(height: 20),
                      _buildWorkflowTestSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Workflow Summary',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Total Orders (Admin View): ${_allOrders.length}',
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              'Client Orders: ${_clientOrders.length}',
              style: const TextStyle(color: Colors.blue),
            ),
            Text(
              'Pending Orders: ${_pendingOrders.length}',
              style: const TextStyle(color: Colors.orange),
            ),
            const SizedBox(height: 8),
            Text(
              'Workflow Status: ${_getWorkflowStatus()}',
              style: TextStyle(
                color: _getWorkflowStatusColor(),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllOrdersSection() {
    return Card(
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'All Orders (Admin View)',
              style: TextStyle(
                color: Colors.green,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_allOrders.isEmpty)
              const Text(
                'No orders found in admin view!',
                style: TextStyle(color: Colors.red),
              )
            else
              ..._allOrders.take(5).map((order) => _buildOrderTile(order, 'Admin')),
            if (_allOrders.length > 5)
              Text(
                '... and ${_allOrders.length - 5} more orders',
                style: TextStyle(color: Colors.grey.shade400),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientOrdersSection() {
    return Card(
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Client Orders (Tracking View)',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_clientOrders.isEmpty)
              const Text(
                'No orders found in client view!',
                style: TextStyle(color: Colors.red),
              )
            else
              ..._clientOrders.take(5).map((order) => _buildOrderTile(order, 'Client')),
            if (_clientOrders.length > 5)
              Text(
                '... and ${_clientOrders.length - 5} more orders',
                style: TextStyle(color: Colors.grey.shade400),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingOrdersSection() {
    return Card(
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pending Orders (Admin Approval)',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_pendingOrders.isEmpty)
              const Text(
                'No pending orders found!',
                style: TextStyle(color: Colors.green),
              )
            else
              ..._pendingOrders.map((order) => _buildOrderTile(order, 'Pending')),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflowTestSection() {
    return Card(
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Workflow Test Results',
              style: TextStyle(
                color: Colors.purple,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildTestItem('Orders can be created', _allOrders.isNotEmpty),
            _buildTestItem('Orders appear in admin view', _allOrders.isNotEmpty),
            _buildTestItem('Orders appear in client tracking', _clientOrders.isNotEmpty),
            _buildTestItem('Pending orders visible to admin', _pendingOrders.isNotEmpty),
            _buildTestItem('Order submission working', _allOrders.isNotEmpty),
            _buildTestItem('Order tracking working', _clientOrders.isNotEmpty),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTile(ClientOrder order, String viewType) {
    Color borderColor;
    switch (viewType) {
      case 'Admin':
        borderColor = Colors.green;
        break;
      case 'Client':
        borderColor = Colors.blue;
        break;
      case 'Pending':
        borderColor = Colors.orange;
        break;
      default:
        borderColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: borderColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order #${order.id.substring(0, 8)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Client: ${order.clientName}',
            style: TextStyle(color: Colors.grey.shade400),
          ),
          Text(
            'Status: ${order.status.toString().split('.').last}',
            style: TextStyle(color: Colors.grey.shade400),
          ),
          Text(
            'Total: ${order.total.toStringAsFixed(2)} EGP',
            style: const TextStyle(color: Colors.green),
          ),
          Text(
            'Items: ${order.items.length}',
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildTestItem(String label, bool passed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.error,
            color: passed ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  String _getWorkflowStatus() {
    if (_allOrders.isEmpty) return '❌ NO ORDERS';
    if (_clientOrders.isEmpty) return '⚠️ CLIENT TRACKING BROKEN';
    if (_pendingOrders.isEmpty && _allOrders.any((o) => o.status == OrderStatus.pending)) {
      return '⚠️ PENDING ORDERS NOT VISIBLE';
    }
    return '✅ WORKING';
  }

  Color _getWorkflowStatusColor() {
    final status = _getWorkflowStatus();
    if (status.contains('✅')) return Colors.green;
    if (status.contains('⚠️')) return Colors.orange;
    return Colors.red;
  }
}
