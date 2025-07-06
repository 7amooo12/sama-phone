import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/providers/client_orders_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/providers/voucher_provider.dart';
import 'package:smartbiztracker_new/providers/app_settings_provider.dart';
import 'package:smartbiztracker_new/screens/client/order_success_screen.dart';
import 'package:smartbiztracker_new/models/client_voucher_model.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

class CheckoutScreen extends StatefulWidget {

  const CheckoutScreen({
    super.key,
    this.appliedVoucher,
    this.discountAmount = 0.0,
    this.originalTotal = 0.0,
    this.finalTotal = 0.0,
  });
  final ClientVoucherModel? appliedVoucher;
  final double discountAmount;
  final double originalTotal;
  final double finalTotal;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  // Voucher-related state
  ClientVoucherModel? _selectedVoucher;
  List<ClientVoucherModel> _applicableVouchers = [];
  bool _isLoadingVouchers = false;
  double _voucherDiscount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadUserData();

    // Use voucher data passed from cart if available
    if (widget.appliedVoucher != null) {
      _selectedVoucher = widget.appliedVoucher;
      _voucherDiscount = widget.discountAmount;
    } else {
      _loadApplicableVouchers();
    }
  }

  void _loadUserData() {
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final user = supabaseProvider.user;

    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phone ?? '';
    }
  }

  Future<void> _loadApplicableVouchers() async {
    setState(() {
      _isLoadingVouchers = true;
    });

    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final orderProvider = Provider.of<ClientOrdersProvider>(context, listen: false);
      final user = supabaseProvider.user;

      if (user != null && orderProvider.cartItems.isNotEmpty) {
        // Convert cart items to the format expected by voucher service
        final cartItemsForVoucher = orderProvider.cartItems.map((item) => {
          'productId': item.productId,
          'category': item.category ?? '',
          'price': item.price,
          'quantity': item.quantity,
        }).toList();

        _applicableVouchers = await supabaseProvider.getApplicableVouchers(
          user.id,
          cartItemsForVoucher,
        );
      }
    } catch (e) {
      print('Error loading applicable vouchers: $e');
    } finally {
      setState(() {
        _isLoadingVouchers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'إتمام الطلب',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer2<ClientOrdersProvider, SupabaseProvider>(
        builder: (context, orderProvider, supabaseProvider, child) {
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOrderSummaryCard(theme, orderProvider),
                        const SizedBox(height: 20),
                        _buildVoucherSelectionCard(theme, orderProvider),
                        const SizedBox(height: 20),
                        _buildCustomerInfoCard(theme),
                        const SizedBox(height: 20),
                        _buildShippingAddressCard(theme),
                        const SizedBox(height: 20),
                        _buildNotesCard(theme),
                      ],
                    ),
                  ),
                ),
              ),
              _buildCheckoutButton(theme, orderProvider, supabaseProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrderSummaryCard(ThemeData theme, ClientOrdersProvider orderProvider) {
    final subtotal = orderProvider.cartTotal;
    final total = subtotal - _voucherDiscount;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ملخص الطلب',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            ...orderProvider.cartItems.map((item) => Consumer<AppSettingsProvider>(
              builder: (context, settingsProvider, child) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.productName} × ${item.quantity}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        if (settingsProvider.showPricesToPublic) ...[
                          // Show actual price when public
                          Text(
                            '${(item.price * item.quantity).toStringAsFixed(0)} ج.م',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ] else ...[
                          // Show both pending pricing and actual price
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'في انتظار التسعير',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                '${(item.price * item.quantity).toStringAsFixed(0)} ج.م',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            )),

            const Divider(height: 20),

            _buildSummaryRow('المجموع الفرعي', subtotal, theme),
            if (_voucherDiscount > 0) ...[
              _buildSummaryRow('خصم القسيمة', -_voucherDiscount, theme, isDiscount: true),
              const Divider(height: 16),
            ],
            _buildSummaryRow('الإجمالي', total, theme, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, ThemeData theme, {bool isTotal = false, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)} ج.م',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isTotal
                  ? theme.colorScheme.primary
                  : isDiscount
                      ? Colors.green
                      : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherSelectionCard(ThemeData theme, ClientOrdersProvider orderProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_offer, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'قسائم الخصم',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                if (_isLoadingVouchers)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            if (_applicableVouchers.isEmpty && !_isLoadingVouchers)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'لا توجد قسائم متاحة لهذا الطلب',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              )
            else if (_applicableVouchers.isNotEmpty)
              Column(
                children: [
                  DropdownButtonFormField<ClientVoucherModel>(
                    value: _selectedVoucher,
                    decoration: InputDecoration(
                      labelText: 'اختر قسيمة خصم',
                      prefixIcon: const Icon(Icons.local_offer),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: [
                      const DropdownMenuItem<ClientVoucherModel>(
                        value: null,
                        child: Text('بدون قسيمة'),
                      ),
                      ..._applicableVouchers.map((voucher) {
                        return DropdownMenuItem<ClientVoucherModel>(
                          value: voucher,
                          child: Text(
                            '${voucher.voucherName} - ${voucher.voucher?.formattedDiscount ?? 'خصم غير محدد'}',
                          ),
                        );
                      }),
                    ],
                    onChanged: (voucher) {
                      setState(() {
                        _selectedVoucher = voucher;
                        _calculateVoucherDiscount(orderProvider);
                      });
                    },
                  ),

                  if (_selectedVoucher != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'قسيمة مطبقة',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'الكود: ${_selectedVoucher!.voucherCode}',
                            style: TextStyle(
                              color: Colors.green.shade600,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Text(
                            'خصم: ${_voucherDiscount.toStringAsFixed(2)} ج.م',
                            style: TextStyle(
                              color: Colors.green.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _calculateVoucherDiscount(ClientOrdersProvider orderProvider) {
    if (_selectedVoucher?.voucher == null) {
      _voucherDiscount = 0.0;
      return;
    }

    final voucher = _selectedVoucher!.voucher!;
    final cartItemsForVoucher = orderProvider.cartItems.map((item) => {
      'productId': item.productId,
      'category': item.category ?? '',
      'price': item.price,
      'quantity': item.quantity,
    }).toList();

    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final discountResult = supabaseProvider.calculateVoucherDiscount(voucher, cartItemsForVoucher);

    _voucherDiscount = (discountResult['totalDiscount'] as double?) ?? 0.0;
  }

  Widget _buildCustomerInfoCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'بيانات العميل',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'الاسم الكامل *',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'الاسم مطلوب';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'البريد الإلكتروني *',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'البريد الإلكتروني مطلوب';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'البريد الإلكتروني غير صحيح';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'رقم الهاتف *',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'رقم الهاتف مطلوب';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShippingAddressCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'عنوان الشحن',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'العنوان الكامل *',
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: 'المحافظة، المدينة، الشارع، رقم المبنى',
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'عنوان الشحن مطلوب';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3);
  }

  Widget _buildNotesCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ملاحظات إضافية',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                prefixIcon: const Icon(Icons.note_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: 'أي ملاحظات خاصة بالطلب...',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3);
  }

  Widget _buildCheckoutButton(
    ThemeData theme,
    ClientOrdersProvider orderProvider,
    SupabaseProvider supabaseProvider,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: orderProvider.isLoading ? null : () => _submitOrder(orderProvider, supabaseProvider),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: orderProvider.isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
                  'تأكيد الطلب',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _submitOrder(
    ClientOrdersProvider orderProvider,
    SupabaseProvider supabaseProvider,
  ) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = supabaseProvider.user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول أولاً'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Prepare order metadata with voucher information
    Map<String, dynamic>? orderMetadata;
    if (_selectedVoucher != null && _voucherDiscount > 0) {
      orderMetadata = {
        'voucher_id': _selectedVoucher!.voucherId,
        'voucher_code': _selectedVoucher!.voucherCode,
        'voucher_discount': _voucherDiscount,
        'original_total': orderProvider.cartTotal,
        'final_total': orderProvider.cartTotal - _voucherDiscount,
      };
    }

    final orderId = await orderProvider.createOrder(
      clientId: user.id,
      clientName: _nameController.text.trim(),
      clientEmail: _emailController.text.trim(),
      clientPhone: _phoneController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      shippingAddress: _addressController.text.trim(),
      metadata: orderMetadata,
    );

    if (orderId != null) {
      // Mark voucher as used if one was applied
      if (_selectedVoucher != null && _voucherDiscount > 0) {
        try {
          final voucherProvider = Provider.of<VoucherProvider>(context, listen: false);
          final success = await voucherProvider.useVoucher(
            _selectedVoucher!.id,
            orderId,
            _voucherDiscount,
          );

          if (success) {
            AppLogger.info('✅ Voucher ${_selectedVoucher!.id} marked as used for order $orderId');
          } else {
            AppLogger.warning('⚠️ Failed to mark voucher as used, but order was created successfully');
          }
        } catch (e) {
          AppLogger.error('❌ Error marking voucher as used: $e');
          // Don't fail the order creation if voucher usage fails
        }
      }

      // الانتقال لصفحة نجاح الطلب
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrderSuccessScreen(orderId: orderId),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(orderProvider.error ?? 'فشل في إنشاء الطلب'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
