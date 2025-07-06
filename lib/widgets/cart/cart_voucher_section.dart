import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/voucher_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../models/voucher_model.dart';
import '../../models/client_voucher_model.dart';
import '../../services/client_orders_service.dart';
import '../../utils/app_logger.dart';

/// Comprehensive voucher section for shopping cart
/// Handles voucher display, selection, validation, and application
class CartVoucherSection extends StatefulWidget {

  const CartVoucherSection({
    super.key,
    required this.cartItems,
    required this.onVoucherApplied,
    this.onVoucherRemoved,
    this.appliedVoucher,
    this.discountAmount = 0.0,
  });
  final List<CartItem> cartItems;
  final Function(ClientVoucherModel?, double) onVoucherApplied;
  final VoidCallback? onVoucherRemoved;
  final ClientVoucherModel? appliedVoucher;
  final double discountAmount;

  @override
  State<CartVoucherSection> createState() => _CartVoucherSectionState();
}

class _CartVoucherSectionState extends State<CartVoucherSection> {
  bool _isExpanded = false;
  bool _isLoading = false;
  String? _validationError;
  List<ClientVoucherModel> _applicableVouchers = [];

  @override
  void initState() {
    super.initState();
    _loadApplicableVouchers();
  }

  @override
  void didUpdateWidget(CartVoucherSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload vouchers if cart items changed
    if (oldWidget.cartItems.length != widget.cartItems.length) {
      _loadApplicableVouchers();
    }
  }

  Future<void> _loadApplicableVouchers() async {
    AppLogger.info('🔄 Starting _loadApplicableVouchers...');

    if (widget.cartItems.isEmpty) {
      AppLogger.info('⚠️ Cart is empty, skipping voucher loading');
      return;
    }

    AppLogger.info('📦 Cart has ${widget.cartItems.length} items');

    setState(() {
      _isLoading = true;
      _validationError = null;
    });

    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final voucherProvider = Provider.of<VoucherProvider>(context, listen: false);
      final currentUser = supabaseProvider.user;

      AppLogger.info('👤 Current user: ${currentUser?.id ?? 'null'}');

      if (currentUser == null) {
        AppLogger.warning('❌ No authenticated user found');
        setState(() {
          _validationError = 'يجب تسجيل الدخول لاستخدام القسائم';
          _isLoading = false;
        });
        return;
      }

      // Load client vouchers if not already loaded
      AppLogger.info('📋 Current voucher count: ${voucherProvider.clientVouchers.length}');
      if (voucherProvider.clientVouchers.isEmpty) {
        AppLogger.info('🔄 Loading client vouchers for user: ${currentUser.id}');
        await voucherProvider.loadClientVouchers(currentUser.id);
        AppLogger.info('✅ Loaded ${voucherProvider.clientVouchers.length} client vouchers');
      }

      // Check valid active vouchers
      final validActiveVouchers = voucherProvider.validActiveClientVouchers;
      AppLogger.info('✅ Valid active vouchers: ${validActiveVouchers.length}');

      // Convert cart items to the format expected by VoucherService
      final cartItemsForVoucher = widget.cartItems.map((item) => {
        'productId': item.productId,
        'productName': item.productName,
        'price': item.price,
        'quantity': item.quantity,
        'category': item.category,
      }).toList();

      AppLogger.info('🛒 Cart items for voucher service: ${cartItemsForVoucher.length}');
      for (final item in cartItemsForVoucher) {
        AppLogger.info('   - ${item['productName']} (${item['category']}) - ${item['price']} x ${item['quantity']}');
      }

      // Get applicable vouchers
      AppLogger.info('🔍 Getting applicable vouchers...');
      final applicableVouchers = await voucherProvider.getApplicableVouchers(
        currentUser.id,
        cartItemsForVoucher,
      );

      AppLogger.info('✅ Found ${applicableVouchers.length} applicable vouchers');
      for (final voucher in applicableVouchers) {
        AppLogger.info('   - ${voucher.voucher?.name ?? 'Unknown'} (${voucher.voucher?.code ?? 'No code'})');
      }

      setState(() {
        _applicableVouchers = applicableVouchers;
        _isLoading = false;
      });

      AppLogger.info('🎉 Voucher loading completed successfully');

    } catch (e) {
      AppLogger.error('❌ Error loading applicable vouchers: $e');
      setState(() {
        _validationError = 'فشل في تحميل القسائم: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _applyVoucher(ClientVoucherModel clientVoucher) async {
    AppLogger.info('🎯 Applying voucher: ${clientVoucher.voucher?.name ?? 'Unknown'}');

    if (clientVoucher.voucher == null) {
      AppLogger.error('❌ Voucher data is null');
      _showError('بيانات القسيمة غير مكتملة');
      return;
    }

    setState(() {
      _isLoading = true;
      _validationError = null;
    });

    try {
      final voucherProvider = Provider.of<VoucherProvider>(context, listen: false);

      // Convert cart items for discount calculation
      final cartItemsForDiscount = widget.cartItems.map((item) => {
        'productId': item.productId,
        'productName': item.productName,
        'price': item.price,
        'quantity': item.quantity,
        'category': item.category,
      }).toList();

      AppLogger.info('💰 Calculating discount for voucher: ${clientVoucher.voucher!.code}');
      AppLogger.info('   - Voucher type: ${clientVoucher.voucher!.type}');
      AppLogger.info('   - Discount: ${clientVoucher.voucher!.formattedDiscount}');
      AppLogger.info('   - Target: ${clientVoucher.voucher!.targetName}');

      // Calculate discount
      final discountResult = voucherProvider.calculateVoucherDiscount(
        clientVoucher.voucher!,
        cartItemsForDiscount,
      );

      AppLogger.info('📊 Discount calculation result: $discountResult');

      final discountAmount = discountResult['totalDiscount'] as double;
      AppLogger.info('💵 Calculated discount amount: ${discountAmount.toStringAsFixed(2)} ج.م');

      if (discountAmount <= 0) {
        AppLogger.warning('⚠️ Discount amount is zero or negative');
        _showError('هذه القسيمة غير قابلة للتطبيق على المنتجات الحالية');
        return;
      }

      // Apply voucher
      AppLogger.info('✅ Applying voucher with discount: ${discountAmount.toStringAsFixed(2)} ج.م');
      widget.onVoucherApplied(clientVoucher, discountAmount);

      setState(() {
        _isExpanded = false;
        _isLoading = false;
      });

      _showSuccess('تم تطبيق القسيمة بنجاح! وفرت ${discountAmount.toStringAsFixed(2)} ج.م');
      AppLogger.info('🎉 Voucher applied successfully');

    } catch (e) {
      AppLogger.error('❌ Error applying voucher: $e');
      _showError('فشل في تطبيق القسيمة: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _removeVoucher() {
    widget.onVoucherRemoved?.call();
    _showSuccess('تم إزالة القسيمة');
  }

  void _showError(String message) {
    setState(() {
      _validationError = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Voucher header
          _buildVoucherHeader(theme),
          
          // Applied voucher display or voucher selection
          if (widget.appliedVoucher != null)
            _buildAppliedVoucherDisplay(theme)
          else if (_isExpanded)
            _buildVoucherSelection(theme),
        ],
      ),
    );
  }

  Widget _buildVoucherHeader(ThemeData theme) {
    return InkWell(
      onTap: widget.appliedVoucher == null ? () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
        if (_isExpanded && _applicableVouchers.isEmpty) {
          _loadApplicableVouchers();
        }
      } : null,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.local_offer,
              color: theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.appliedVoucher != null ? 'القسيمة المطبقة' : 'القسائم المتاحة',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.appliedVoucher == null)
                    Text(
                      'اضغط لعرض القسائم المتاحة',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
            if (widget.appliedVoucher != null)
              IconButton(
                onPressed: _removeVoucher,
                icon: const Icon(Icons.close),
                color: Colors.red,
                tooltip: 'إزالة القسيمة',
              )
            else
              Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppliedVoucherDisplay(ThemeData theme) {
    final voucher = widget.appliedVoucher!.voucher!;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voucher.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  Text(
                    'خصم: ${widget.discountAmount.toStringAsFixed(2)} ج.م',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoucherSelection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            )
          else if (_validationError != null)
            _buildErrorDisplay(theme)
          else if (_applicableVouchers.isEmpty)
            _buildNoVouchersDisplay(theme)
          else
            _buildVoucherList(theme),
        ],
      ),
    );
  }

  Widget _buildErrorDisplay(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _validationError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.red[800],
              ),
            ),
          ),
          TextButton(
            onPressed: _loadApplicableVouchers,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoVouchersDisplay(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(
            Icons.local_offer_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'لا توجد قسائم متاحة',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          Text(
            'لا توجد قسائم قابلة للتطبيق على المنتجات الحالية',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherList(ThemeData theme) {
    return Column(
      children: _applicableVouchers.map((clientVoucher) {
        return _buildVoucherCard(clientVoucher, theme);
      }).toList(),
    );
  }

  Widget _buildVoucherCard(ClientVoucherModel clientVoucher, ThemeData theme) {
    final voucher = clientVoucher.voucher!;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () => _applyVoucher(clientVoucher),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.local_offer,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voucher.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getVoucherTypeText(voucher),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'ينتهي في: ${voucher.formattedExpirationDate}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.3);
  }

  String _getVoucherTypeText(VoucherModel voucher) {
    switch (voucher.type) {
      case VoucherType.product:
        return 'خصم على منتج محدد - ${voucher.discountPercentage}%';
      case VoucherType.category:
        return 'خصم على فئة محددة - ${voucher.discountPercentage}%';
      default:
        return 'قسيمة خصم - ${voucher.discountPercentage}%';
    }
  }

  String _getVoucherTypeLabel(VoucherModel voucher) {
    switch (voucher.type) {
      case VoucherType.product:
        return 'منتج محدد: ${voucher.targetName}';
      case VoucherType.category:
        return 'فئة: ${voucher.targetName}';
      default:
        return 'قسيمة عامة';
    }
  }

  bool _isVoucherApplicable(ClientVoucherModel clientVoucher) {
    final voucher = clientVoucher.voucher;
    if (voucher == null || !clientVoucher.canBeUsed) return false;

    // Check if voucher applies to any cart items
    for (final item in widget.cartItems) {
      if (voucher.type == VoucherType.product) {
        if (item.productId == voucher.targetId) return true;
      } else if (voucher.type == VoucherType.category) {
        if (item.category == voucher.targetName || item.category == voucher.targetId) return true;
      }
    }
    return false;
  }

  Map<String, dynamic> _calculateDiscount(ClientVoucherModel clientVoucher) {
    final voucher = clientVoucher.voucher!;
    final applicableItems = <Map<String, dynamic>>[];
    double totalDiscount = 0.0;

    for (final item in widget.cartItems) {
      bool isApplicable = false;

      if (voucher.type == VoucherType.product) {
        isApplicable = item.productId == voucher.targetId;
      } else if (voucher.type == VoucherType.category) {
        isApplicable = item.category == voucher.targetName || item.category == voucher.targetId;
      }

      if (isApplicable) {
        final itemTotal = item.price * item.quantity;
        double itemDiscount;

        switch (voucher.discountType) {
          case DiscountType.percentage:
            itemDiscount = itemTotal * (voucher.discountPercentage / 100);
            break;
          case DiscountType.fixedAmount:
            final fixedDiscount = voucher.discountAmount ?? 0.0;
            // Apply fixed discount per item, but don't exceed item price
            final discountPerItem = fixedDiscount > item.price ? item.price : fixedDiscount;
            itemDiscount = discountPerItem * item.quantity;
            break;
        }

        totalDiscount += itemDiscount;

        applicableItems.add({
          'productId': item.productId,
          'productName': item.productName,
          'quantity': item.quantity,
          'price': item.price,
          'discount': itemDiscount,
        });
      }
    }

    return {
      'isApplicable': applicableItems.isNotEmpty,
      'discountAmount': totalDiscount,
      'applicableItems': applicableItems,
    };
  }

  String _getInapplicabilityReason(ClientVoucherModel clientVoucher) {
    final voucher = clientVoucher.voucher!;

    if (!clientVoucher.canBeUsed) {
      if (clientVoucher.isExpired) {
        return 'انتهت صلاحية القسيمة';
      }
      return 'القسيمة غير متاحة للاستخدام';
    }

    if (voucher.type == VoucherType.product) {
      return 'المنتج المطلوب (${voucher.targetName}) غير موجود في السلة';
    } else if (voucher.type == VoucherType.category) {
      return 'لا توجد منتجات من فئة (${voucher.targetName}) في السلة';
    }

    return 'القسيمة غير قابلة للتطبيق على المنتجات الحالية';
  }
}
