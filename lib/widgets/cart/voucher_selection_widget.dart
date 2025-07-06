import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/voucher_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../models/voucher_model.dart';
import '../../models/client_voucher_model.dart';
import '../../services/voucher_service.dart';
import '../../utils/app_logger.dart';

/// Widget for displaying and selecting vouchers in the shopping cart
class VoucherSelectionWidget extends StatefulWidget {

  const VoucherSelectionWidget({
    super.key,
    required this.cartItems,
    required this.cartTotal,
    required this.onVoucherSelected,
    this.selectedVoucher,
  });
  final List<Map<String, dynamic>> cartItems;
  final double cartTotal;
  final Function(ClientVoucherModel?, double) onVoucherSelected;
  final ClientVoucherModel? selectedVoucher;

  @override
  State<VoucherSelectionWidget> createState() => _VoucherSelectionWidgetState();
}

class _VoucherSelectionWidgetState extends State<VoucherSelectionWidget> {
  bool _isExpanded = false;
  bool _isValidating = false;
  List<ClientVoucherModel> _applicableVouchers = [];
  Map<String, double> _voucherDiscounts = {};
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _loadApplicableVouchers();
  }

  @override
  void didUpdateWidget(VoucherSelectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-validate when cart items change
    if (oldWidget.cartItems != widget.cartItems || 
        oldWidget.cartTotal != widget.cartTotal) {
      _loadApplicableVouchers();
    }
  }

  Future<void> _loadApplicableVouchers() async {
    setState(() {
      _isValidating = true;
      _validationError = null;
    });

    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final voucherProvider = Provider.of<VoucherProvider>(context, listen: false);
      final currentUser = supabaseProvider.user;

      if (currentUser == null) {
        setState(() {
          _validationError = 'يجب تسجيل الدخول لاستخدام القسائم';
          _isValidating = false;
        });
        return;
      }

      // Load client vouchers if not already loaded
      if (voucherProvider.clientVouchers.isEmpty) {
        await voucherProvider.loadClientVouchers(currentUser.id);
      }

      // Get applicable vouchers using VoucherService
      final voucherService = VoucherService();
      final applicableVouchers = await voucherService.getApplicableVouchers(
        currentUser.id, 
        widget.cartItems
      );

      // Calculate discount for each applicable voucher
      final discounts = <String, double>{};
      for (final voucher in applicableVouchers) {
        if (voucher.voucher != null) {
          final discountResult = voucherService.calculateVoucherDiscount(
            voucher.voucher!, 
            widget.cartItems
          );
          discounts[voucher.id] = discountResult['discount_amount'] as double? ?? 0.0;
        }
      }

      setState(() {
        _applicableVouchers = applicableVouchers;
        _voucherDiscounts = discounts;
        _isValidating = false;
      });

      AppLogger.info('✅ Loaded ${applicableVouchers.length} applicable vouchers');

    } catch (e) {
      setState(() {
        _validationError = 'خطأ في تحميل القسائم: ${e.toString()}';
        _isValidating = false;
      });
      AppLogger.error('❌ Error loading applicable vouchers: $e');
    }
  }

  String _getVoucherTypeDisplay(VoucherModel voucher) {
    final typeText = voucher.type == VoucherType.product
        ? 'خصم على منتج محدد'
        : 'خصم على فئة محددة';

    return '$typeText - ${voucher.formattedDiscount}';
  }

  Widget _buildVoucherCard(ClientVoucherModel clientVoucher) {
    final voucher = clientVoucher.voucher;
    if (voucher == null) return const SizedBox.shrink();

    final discount = _voucherDiscounts[clientVoucher.id] ?? 0.0;
    final isSelected = widget.selectedVoucher?.id == clientVoucher.id;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isSelected ? Colors.green.withOpacity(0.1) : null,
      child: InkWell(
        onTap: () => _selectVoucher(clientVoucher, discount),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      voucher.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.green : null,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _getVoucherTypeDisplay(voucher),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (voucher.description?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  voucher.description!,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ينتهي: ${voucher.formattedExpirationDate}',
                    style: const TextStyle(fontSize: 11, color: Colors.orange),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'وفر ${discount.toStringAsFixed(2)} ريال',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectVoucher(ClientVoucherModel clientVoucher, double discount) {
    // If same voucher is selected, deselect it
    if (widget.selectedVoucher?.id == clientVoucher.id) {
      widget.onVoucherSelected(null, 0.0);
    } else {
      widget.onVoucherSelected(clientVoucher, discount);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.local_offer, color: Colors.green),
            title: const Text('القسائم المتاحة'),
            subtitle: widget.selectedVoucher != null
                ? Text('تم تطبيق: ${widget.selectedVoucher!.voucher?.name ?? 'قسيمة'}')
                : Text('${_applicableVouchers.length} قسيمة متاحة'),
            trailing: IconButton(
              icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
            ),
          ),
          if (_isExpanded) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_isValidating)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_validationError != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _validationError!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_applicableVouchers.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.info, color: Colors.grey, size: 48),
                          const SizedBox(height: 8),
                          const Text(
                            'لا توجد قسائم متاحة للمنتجات الحالية',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _loadApplicableVouchers,
                            child: const Text('إعادة التحقق'),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        if (widget.selectedVoucher != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green),
                                const SizedBox(width: 8),
                                const Text('قسيمة مطبقة'),
                                const Spacer(),
                                TextButton(
                                  onPressed: () => widget.onVoucherSelected(null, 0.0),
                                  child: const Text('إزالة'),
                                ),
                              ],
                            ),
                          ),
                        ..._applicableVouchers.map(_buildVoucherCard),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
