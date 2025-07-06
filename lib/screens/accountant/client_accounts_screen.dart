import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/models/wallet_model.dart';
import 'package:smartbiztracker_new/services/wallet_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientAccountsScreen extends StatefulWidget {
  const ClientAccountsScreen({super.key});

  @override
  State<ClientAccountsScreen> createState() => _ClientAccountsScreenState();
}

class _ClientAccountsScreenState extends State<ClientAccountsScreen> {
  final WalletService _walletService = WalletService();
  List<ClientAccountInfo> _clientAccounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClientAccounts();
  }

  Future<void> _loadClientAccounts() async {
    try {
      setState(() => _isLoading = true);
      
      // جلب جميع العملاء المعتمدين والنشطين
      final supabase = Supabase.instance.client;
      final clientsResponse = await supabase
          .from('user_profiles')
          .select('*')
          .or('role.eq.client,role.eq.عميل') // Support both English and Arabic role names
          .or('status.eq.approved,status.eq.active') // Support both status values
          .order('name');

      final List<ClientAccountInfo> accounts = [];
      
      for (final clientData in clientsResponse) {
        final client = UserModel.fromMap(clientData);
        
        // جلب محفظة العميل
        final wallet = await _walletService.getUserWallet(client.id);
        if (wallet != null) {
          accounts.add(ClientAccountInfo(
            client: client,
            wallet: wallet,
          ));
        } else {
          // إذا لم توجد محفظة، إنشاء واحدة جديدة
          final newWallet = await _walletService.createWallet(
            userId: client.id,
            role: 'client',
            initialBalance: 0.0,
          );
          accounts.add(ClientAccountInfo(
            client: client,
            wallet: newWallet,
          ));
        }
      }

      setState(() {
        _clientAccounts = accounts;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Error loading client accounts: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تحميل حسابات العملاء: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateClientBalance(ClientAccountInfo accountInfo, double newBalance) async {
    try {
      await _walletService.updateWalletBalance(
        walletId: accountInfo.wallet.id,
        newBalance: newBalance,
        description: 'تحديث الرصيد من المحاسب',
      );

      // تحديث البيانات المحلية
      setState(() {
        final index = _clientAccounts.indexWhere((acc) => acc.client.id == accountInfo.client.id);
        if (index != -1) {
          _clientAccounts[index] = ClientAccountInfo(
            client: accountInfo.client,
            wallet: WalletModel(
              id: accountInfo.wallet.id,
              userId: accountInfo.wallet.userId,
              balance: newBalance,
              role: accountInfo.wallet.role,
              createdAt: accountInfo.wallet.createdAt,
              updatedAt: DateTime.now(),
            ),
          );
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث رصيد ${accountInfo.client.name} بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error updating client balance: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تحديث الرصيد: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditBalanceDialog(ClientAccountInfo accountInfo) {
    final TextEditingController balanceController = TextEditingController(
      text: accountInfo.wallet.balance.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل رصيد ${accountInfo.client.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'الرصيد الحالي: ${accountInfo.wallet.balance.toStringAsFixed(2)} جنيه',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: balanceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'الرصيد الجديد',
                suffixText: 'جنيه',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final newBalance = double.tryParse(balanceController.text);
              if (newBalance != null) {
                Navigator.of(context).pop();
                _updateClientBalance(accountInfo, newBalance);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Color _getBalanceColor(double balance) {
    if (balance >= 900000) { // قريب من المليون
      return Colors.red;
    } else if (balance >= 500000) {
      return Colors.orange;
    } else if (balance >= 0) {
      return Colors.green;
    } else {
      return Colors.red.shade700; // رصيد سالب
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'حسابات العملاء',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.teal.shade600,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadClientAccounts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _clientAccounts.isEmpty
              ? const Center(
                  child: Text(
                    'لا توجد حسابات عملاء',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadClientAccounts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _clientAccounts.length,
                    itemBuilder: (context, index) {
                      final accountInfo = _clientAccounts[index];
                      final balance = accountInfo.wallet.balance;
                      final balanceColor = _getBalanceColor(balance);
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.8),
                              Colors.black.withValues(alpha: 0.9),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: balance >= 900000
                              ? Border.all(color: Colors.red, width: 2)
                              : Border.all(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: balanceColor.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.person,
                              color: balanceColor,
                            ),
                          ),
                          title: Text(
                            accountInfo.client.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                accountInfo.client.email,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: balance >= 900000
                                        ? [Colors.red, Colors.red.withValues(alpha: 0.8)]
                                        : [balanceColor, balanceColor.withValues(alpha: 0.8)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: balance >= 900000
                                      ? Border.all(color: Colors.red, width: 1)
                                      : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: balanceColor.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${balance.toStringAsFixed(2)} جنيه',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF10B981),
                                  const Color(0xFF10B981).withValues(alpha: 0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.edit_rounded,
                                color: Colors.white,
                              ),
                              onPressed: () => _showEditBalanceDialog(accountInfo),
                              tooltip: 'تعديل الرصيد',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class ClientAccountInfo {

  const ClientAccountInfo({
    required this.client,
    required this.wallet,
  });
  final UserModel client;
  final WalletModel wallet;
}
