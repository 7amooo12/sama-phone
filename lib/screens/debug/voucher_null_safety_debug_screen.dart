import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/voucher_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../models/client_voucher_model.dart';
import '../../utils/app_logger.dart';

class VoucherNullSafetyDebugScreen extends StatefulWidget {
  const VoucherNullSafetyDebugScreen({super.key});

  @override
  State<VoucherNullSafetyDebugScreen> createState() => _VoucherNullSafetyDebugScreenState();
}

class _VoucherNullSafetyDebugScreenState extends State<VoucherNullSafetyDebugScreen> {
  bool _isLoading = false;
  String? _error;
  List<ClientVoucherModel> _allClientVouchers = [];
  List<ClientVoucherModel> _validVouchers = [];
  List<ClientVoucherModel> _invalidVouchers = [];

  @override
  void initState() {
    super.initState();
    _loadVoucherData();
  }

  Future<void> _loadVoucherData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final voucherProvider = Provider.of<VoucherProvider>(context, listen: false);

      final currentUser = supabaseProvider.user;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      AppLogger.info('DEBUG: Loading voucher data for user: ${currentUser.id}');
      await voucherProvider.loadClientVouchers(currentUser.id);

      _allClientVouchers = voucherProvider.clientVouchers;
      _validVouchers = _allClientVouchers.where((cv) => cv.voucher != null).toList();
      _invalidVouchers = _allClientVouchers.where((cv) => cv.voucher == null).toList();

      AppLogger.info('DEBUG: Total vouchers: ${_allClientVouchers.length}');
      AppLogger.info('DEBUG: Valid vouchers: ${_validVouchers.length}');
      AppLogger.info('DEBUG: Invalid vouchers: ${_invalidVouchers.length}');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('DEBUG: Error loading voucher data: $e');
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
        title: const Text('Voucher Null Safety Debug'),
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadVoucherData,
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
                        onPressed: _loadVoucherData,
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
                      _buildValidVouchersSection(),
                      const SizedBox(height: 20),
                      _buildInvalidVouchersSection(),
                      const SizedBox(height: 20),
                      _buildTestResultsSection(),
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
              'Voucher Null Safety Summary',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Total Client Vouchers: ${_allClientVouchers.length}',
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              'Valid Vouchers (with data): ${_validVouchers.length}',
              style: const TextStyle(color: Colors.green),
            ),
            Text(
              'Invalid Vouchers (null data): ${_invalidVouchers.length}',
              style: TextStyle(color: _invalidVouchers.isEmpty ? Colors.green : Colors.red),
            ),
            const SizedBox(height: 8),
            Text(
              'Null Safety Status: ${_invalidVouchers.isEmpty ? "✅ SAFE" : "❌ UNSAFE"}',
              style: TextStyle(
                color: _invalidVouchers.isEmpty ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidVouchersSection() {
    return Card(
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Valid Vouchers (Safe)',
              style: TextStyle(
                color: Colors.green,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_validVouchers.isEmpty)
              const Text(
                'No valid vouchers found!',
                style: TextStyle(color: Colors.orange),
              )
            else
              ..._validVouchers.map((voucher) => _buildVoucherTile(voucher, true)),
          ],
        ),
      ),
    );
  }

  Widget _buildInvalidVouchersSection() {
    return Card(
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invalid Vouchers (Null Data)',
              style: TextStyle(
                color: Colors.red,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_invalidVouchers.isEmpty)
              const Text(
                'No invalid vouchers found! ✅',
                style: TextStyle(color: Colors.green),
              )
            else
              ..._invalidVouchers.map((voucher) => _buildVoucherTile(voucher, false)),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResultsSection() {
    return Card(
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Null Safety Test Results',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildTestItem('No null voucher data', _invalidVouchers.isEmpty),
            _buildTestItem('All vouchers have valid data', _validVouchers.length == _allClientVouchers.length),
            _buildTestItem('Safe for UI rendering', _invalidVouchers.isEmpty),
            _buildTestItem('No null check operator risks', _invalidVouchers.isEmpty),
            const SizedBox(height: 16),
            if (_invalidVouchers.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ WARNING: Null voucher data detected!',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This could cause "null check operator used on a null value" errors.',
                      style: TextStyle(color: Colors.white),
                    ),
                    Text(
                      'The safe voucher card builder should handle these cases gracefully.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoucherTile(ClientVoucherModel voucher, bool isValid) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isValid ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isValid ? Colors.green : Colors.red,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            voucher.voucherName.isNotEmpty ? voucher.voucherName : 'Unknown Voucher',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Code: ${voucher.voucherCode}',
            style: TextStyle(color: Colors.grey.shade400),
          ),
          Text(
            'Status: ${voucher.status.value}',
            style: TextStyle(color: Colors.grey.shade400),
          ),
          if (isValid && voucher.voucher != null)
            Text(
              'Voucher Data: ${voucher.voucher!.name}',
              style: const TextStyle(color: Colors.green),
            )
          else
            const Text(
              'Voucher Data: NULL ❌',
              style: TextStyle(color: Colors.red),
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
}
