import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/electronic_payment_provider.dart';
import '../../providers/electronic_wallet_provider.dart';
import '../../models/wallet_payment_option_model.dart';
import '../../models/electronic_wallet_model.dart';
import '../../utils/app_logger.dart';

class WalletPaymentIntegrationDebugScreen extends StatefulWidget {
  const WalletPaymentIntegrationDebugScreen({super.key});

  @override
  State<WalletPaymentIntegrationDebugScreen> createState() => _WalletPaymentIntegrationDebugScreenState();
}

class _WalletPaymentIntegrationDebugScreenState extends State<WalletPaymentIntegrationDebugScreen> {
  bool _isLoading = false;
  String? _error;
  List<ElectronicWalletModel> _accountantWallets = [];
  List<WalletPaymentOptionModel> _clientPaymentOptions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final walletProvider = Provider.of<ElectronicWalletProvider>(context, listen: false);
      final paymentProvider = Provider.of<ElectronicPaymentProvider>(context, listen: false);

      AppLogger.info('DEBUG: Loading accountant wallets...');
      await walletProvider.loadActiveWalletsForPayments();
      _accountantWallets = walletProvider.wallets;

      AppLogger.info('DEBUG: Loading client payment options...');
      await paymentProvider.loadWalletPaymentOptions();
      _clientPaymentOptions = paymentProvider.walletPaymentOptions;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('DEBUG: Error loading data: $e');
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
        title: const Text('Wallet Payment Integration Debug'),
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadData,
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
                        onPressed: _loadData,
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
                      _buildAccountantWalletsSection(),
                      const SizedBox(height: 20),
                      _buildClientPaymentOptionsSection(),
                      const SizedBox(height: 20),
                      _buildIntegrationStatusSection(),
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
              'Integration Summary',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Accountant Wallets: ${_accountantWallets.length}',
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              'Client Payment Options: ${_clientPaymentOptions.length}',
              style: const TextStyle(color: Colors.green),
            ),
            const SizedBox(height: 8),
            Text(
              'Integration Status: ${_accountantWallets.length == _clientPaymentOptions.length ? "✅ Synchronized" : "❌ Not Synchronized"}',
              style: TextStyle(
                color: _accountantWallets.length == _clientPaymentOptions.length ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountantWalletsSection() {
    return Card(
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Accountant Managed Wallets',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_accountantWallets.isEmpty)
              const Text(
                'No wallets found in accountant system!',
                style: TextStyle(color: Colors.red),
              )
            else
              ..._accountantWallets.map((wallet) => _buildWalletTile(wallet)),
          ],
        ),
      ),
    );
  }

  Widget _buildClientPaymentOptionsSection() {
    return Card(
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Client Payment Options',
              style: TextStyle(
                color: Colors.green,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_clientPaymentOptions.isEmpty)
              const Text(
                'No payment options available for clients!',
                style: TextStyle(color: Colors.red),
              )
            else
              ..._clientPaymentOptions.map((option) => _buildPaymentOptionTile(option)),
          ],
        ),
      ),
    );
  }

  Widget _buildIntegrationStatusSection() {
    return Card(
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Integration Status Details',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatusItem('Wallet Count Match', _accountantWallets.length == _clientPaymentOptions.length),
            _buildStatusItem('Vodafone Cash Available', _clientPaymentOptions.any((o) => o.accountType == 'vodafone_cash')),
            _buildStatusItem('InstaPay Available', _clientPaymentOptions.any((o) => o.accountType == 'instapay')),
            _buildStatusItem('All Options Active', _clientPaymentOptions.every((o) => o.isActive)),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletTile(ElectronicWalletModel wallet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            wallet.walletName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            wallet.phoneNumber,
            style: TextStyle(color: Colors.grey.shade400),
          ),
          Row(
            children: [
              Chip(
                label: Text(
                  wallet.walletType == ElectronicWalletType.vodafoneCash ? 'Vodafone Cash' : 'InstaPay',
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: wallet.walletType == ElectronicWalletType.vodafoneCash ? Colors.red : Colors.blue,
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(
                  wallet.isActive ? 'Active' : 'Inactive',
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: wallet.isActive ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(
                  '${wallet.currentBalance.toStringAsFixed(2)} EGP',
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOptionTile(WalletPaymentOptionModel option) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            option.accountHolderName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            option.maskedAccountNumber,
            style: TextStyle(color: Colors.grey.shade400),
          ),
          Row(
            children: [
              Chip(
                label: Text(
                  option.accountTypeDisplayName,
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: option.accountType == 'vodafone_cash' ? Colors.red : Colors.blue,
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(
                  option.statusDisplay,
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: option.isActive ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(
                  option.formattedBalance,
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, bool isOk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isOk ? Icons.check_circle : Icons.error,
            color: isOk ? Colors.green : Colors.red,
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
}
