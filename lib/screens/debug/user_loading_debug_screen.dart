import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/supabase_provider.dart';
import '../../models/user_model.dart';
import '../../utils/app_logger.dart';

class UserLoadingDebugScreen extends StatefulWidget {
  const UserLoadingDebugScreen({super.key});

  @override
  State<UserLoadingDebugScreen> createState() => _UserLoadingDebugScreenState();
}

class _UserLoadingDebugScreenState extends State<UserLoadingDebugScreen> {
  List<UserModel> _allUsers = [];
  List<UserModel> _clients = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      
      AppLogger.info('DEBUG: Loading all users...');
      await supabaseProvider.fetchAllUsers();
      
      _allUsers = supabaseProvider.allUsers;
      AppLogger.info('DEBUG: Loaded ${_allUsers.length} total users');
      
      // Filter clients
      _clients = _allUsers.where((user) {
        final isClient = user.role.value.toLowerCase() == 'client';
        final isApproved = user.status.toLowerCase() == 'approved' || 
                          user.status.toLowerCase() == 'active' ||
                          user.isApproved;
        return isClient && isApproved;
      }).toList();
      
      AppLogger.info('DEBUG: Found ${_clients.length} approved clients');
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('DEBUG: Error loading users: $e');
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
        title: const Text('User Loading Debug'),
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadUsers,
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
                        onPressed: _loadUsers,
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
                      _buildAllUsersSection(),
                      const SizedBox(height: 20),
                      _buildClientsSection(),
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
              'Summary',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Total Users: ${_allUsers.length}',
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              'Approved Clients: ${_clients.length}',
              style: const TextStyle(color: Colors.green),
            ),
            const SizedBox(height: 8),
            Text(
              'Roles Distribution:',
              style: TextStyle(color: Colors.grey.shade400),
            ),
            ..._getRoleDistribution().entries.map((entry) => Text(
              '  ${entry.key}: ${entry.value}',
              style: TextStyle(color: Colors.grey.shade300),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildAllUsersSection() {
    return Card(
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'All Users',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._allUsers.map((user) => _buildUserTile(user, false)),
          ],
        ),
      ),
    );
  }

  Widget _buildClientsSection() {
    return Card(
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Approved Clients (Available for Voucher Assignment)',
              style: TextStyle(
                color: Colors.green,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_clients.isEmpty)
              const Text(
                'No approved clients found!',
                style: TextStyle(color: Colors.red),
              )
            else
              ..._clients.map((user) => _buildUserTile(user, true)),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTile(UserModel user, bool isClient) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isClient ? Colors.green.withOpacity(0.1) : Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isClient ? Colors.green : Colors.grey.shade600,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            user.email,
            style: TextStyle(color: Colors.grey.shade400),
          ),
          Row(
            children: [
              Chip(
                label: Text(
                  user.role.value,
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: _getRoleColor(user.role.value),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(
                  user.status,
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: _getStatusColor(user.status),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(
                  user.isApproved ? 'Approved' : 'Not Approved',
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: user.isApproved ? Colors.green : Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, int> _getRoleDistribution() {
    final distribution = <String, int>{};
    for (final user in _allUsers) {
      final role = user.role.value;
      distribution[role] = (distribution[role] ?? 0) + 1;
    }
    return distribution;
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.purple;
      case 'client':
        return Colors.blue;
      case 'worker':
        return Colors.orange;
      case 'accountant':
        return Colors.teal;
      case 'owner':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }
}
