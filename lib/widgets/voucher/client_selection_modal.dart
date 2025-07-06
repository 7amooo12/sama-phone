import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/supabase_provider.dart';
import '../../models/voucher_model.dart';
import '../../models/user_model.dart';
import '../../utils/accountant_theme_config.dart';

class ClientSelectionModal extends StatefulWidget {

  const ClientSelectionModal({
    super.key,
    required this.voucher,
    required this.onClientsSelected,
  });
  final VoucherModel voucher;
  final Function(List<String>) onClientsSelected;

  @override
  State<ClientSelectionModal> createState() => _ClientSelectionModalState();
}

class _ClientSelectionModalState extends State<ClientSelectionModal> {
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _allClients = [];
  List<UserModel> _filteredClients = [];
  Set<String> _selectedClientIds = {};
  bool _isLoading = true;
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _loadClients();
    _searchController.addListener(_filterClients);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);

      // Debug: Log current user info
      print('DEBUG: Current user role: ${supabaseProvider.user?.role.value}');
      print('DEBUG: Total users in allUsers: ${supabaseProvider.allUsers.length}');

      // Use the new method to get approved clients
      final clients = await supabaseProvider.getApprovedClients();

      print('DEBUG: Found ${clients.length} approved clients');

      // Debug: Log client details
      for (final client in clients) {
        print('DEBUG: Client: ${client.name} (${client.email}) - Status: ${client.status}');
      }

      setState(() {
        _allClients = clients;
        _filteredClients = clients;
        _isLoading = false;
      });

      // Show a message if no clients found
      if (clients.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يوجد عملاء موافق عليهم في النظام'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('ERROR: Failed to load clients: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في تحميل العملاء: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _filterClients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredClients = _allClients.where((client) {
        return client.name.toLowerCase().contains(query) ||
               client.email.toLowerCase().contains(query) ||
               (client.phone.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      if (_selectAll) {
        _selectedClientIds = _filteredClients.map((client) => client.id).toSet();
      } else {
        _selectedClientIds.clear();
      }
    });
  }

  void _toggleClientSelection(String clientId) {
    setState(() {
      if (_selectedClientIds.contains(clientId)) {
        _selectedClientIds.remove(clientId);
      } else {
        _selectedClientIds.add(clientId);
      }
      _selectAll = _selectedClientIds.length == _filteredClients.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AccountantThemeConfig.accentBlue.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: AccountantThemeConfig.accentBlue.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              // Header with gradient
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AccountantThemeConfig.accentBlue.withOpacity(0.8),
                      AccountantThemeConfig.primaryGreen.withOpacity(0.6),
                    ],
                  ),
                ),
                child: _buildHeader(),
              ),

              // Content area
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildSearchBar(),
                      const SizedBox(height: 20),
                      _buildSelectAllOption(),
                      const SizedBox(height: 20),
                      Expanded(
                        child: _buildClientsList(),
                      ),
                    ],
                  ),
                ),
              ),

              // Action buttons
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: _buildActionButtons(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.person_add,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تعيين القسيمة للعملاء',
                style: AccountantThemeConfig.headlineMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'القسيمة: ${widget.voucher.name}',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'إغلاق',
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AccountantThemeConfig.accentBlue.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: AccountantThemeConfig.bodyLarge.copyWith(
          color: Colors.white,
        ),
        decoration: InputDecoration(
          hintText: 'البحث بالاسم أو البريد الإلكتروني أو رقم الهاتف',
          hintStyle: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white60,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.accentBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.search,
              color: AccountantThemeConfig.accentBlue,
              size: 20,
            ),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _filterClients();
                  },
                  icon: Icon(
                    Icons.clear,
                    color: Colors.grey.shade400,
                  ),
                )
              : null,
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AccountantThemeConfig.accentBlue,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectAllOption() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AccountantThemeConfig.primaryGreen.withOpacity(0.1),
            AccountantThemeConfig.primaryGreen.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AccountantThemeConfig.primaryGreen.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: _selectAll
                  ? AccountantThemeConfig.primaryGreen
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AccountantThemeConfig.primaryGreen,
                width: 2,
              ),
            ),
            child: InkWell(
              onTap: _toggleSelectAll,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 24,
                height: 24,
                child: _selectAll
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.people,
            color: AccountantThemeConfig.primaryGreen,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'تحديد جميع العملاء (${_filteredClients.length})',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_selectedClientIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AccountantThemeConfig.primaryGreen,
                    AccountantThemeConfig.primaryGreen.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '${_selectedClientIds.length} محدد',
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClientsList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AccountantThemeConfig.accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: CircularProgressIndicator(
                color: AccountantThemeConfig.accentBlue,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'جاري تحميل العملاء...',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredClients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.withOpacity(0.1),
                    Colors.grey.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.3),
                ),
              ),
              child: Icon(
                Icons.people_outline,
                color: Colors.grey.shade400,
                size: 64,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _allClients.isEmpty ? 'لا يوجد عملاء مسجلين' : 'لا توجد نتائج للبحث',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white60,
              ),
            ),
            if (_allClients.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'يرجى إضافة عملاء أولاً',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white60,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredClients.length,
      itemBuilder: (context, index) {
        final client = _filteredClients[index];
        final isSelected = _selectedClientIds.contains(client.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      AccountantThemeConfig.primaryGreen.withOpacity(0.15),
                      AccountantThemeConfig.primaryGreen.withOpacity(0.08),
                    ],
                  )
                : LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.05),
                      Colors.white.withOpacity(0.02),
                    ],
                  ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AccountantThemeConfig.primaryGreen.withOpacity(0.4)
                  : Colors.white.withOpacity(0.1),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleClientSelection(client.id),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  AccountantThemeConfig.primaryGreen,
                                  AccountantThemeConfig.primaryGreen.withOpacity(0.8),
                                ],
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.grey.shade600,
                                  Colors.grey.shade700,
                                ],
                              ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: (isSelected
                                ? AccountantThemeConfig.primaryGreen
                                : Colors.grey).withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          client.name.isNotEmpty ? client.name[0].toUpperCase() : 'C',
                          style: AccountantThemeConfig.headlineSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Client info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            client.name,
                            style: AccountantThemeConfig.bodyLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            client.email,
                            style: AccountantThemeConfig.bodyMedium.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          if (client.phone.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              client.phone,
                              style: AccountantThemeConfig.bodySmall.copyWith(
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Selection indicator
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AccountantThemeConfig.primaryGreen
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? AccountantThemeConfig.primaryGreen
                              : Colors.grey.shade500,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.grey.withOpacity(0.1),
                  Colors.grey.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, size: 18),
              label: Text(
                'إلغاء',
                style: AccountantThemeConfig.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade300,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: _selectedClientIds.isEmpty
                  ? LinearGradient(
                      colors: [
                        Colors.grey.withOpacity(0.3),
                        Colors.grey.withOpacity(0.2),
                      ],
                    )
                  : AccountantThemeConfig.blueGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: _selectedClientIds.isEmpty ? null : [
                BoxShadow(
                  color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _selectedClientIds.isEmpty ? null : _assignVouchers,
              icon: Icon(
                Icons.assignment_turned_in,
                size: 18,
                color: _selectedClientIds.isEmpty ? Colors.grey.shade500 : Colors.white,
              ),
              label: Text(
                _selectedClientIds.isEmpty
                    ? 'اختر عملاء أولاً'
                    : 'تعيين لـ ${_selectedClientIds.length} عميل',
                style: AccountantThemeConfig.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _selectedClientIds.isEmpty ? Colors.white60 : Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _assignVouchers() {
    if (_selectedClientIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار عميل واحد على الأقل'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    widget.onClientsSelected(_selectedClientIds.toList());
  }
}
