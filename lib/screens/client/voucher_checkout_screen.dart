import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../providers/voucher_cart_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../providers/voucher_provider.dart';
import '../../models/voucher_model.dart';
import '../../models/client_voucher_model.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';
import '../../widgets/common/custom_loader.dart';
import 'order_success_screen.dart';

/// Voucher checkout screen for completing voucher orders
/// Handles voucher order submission with comprehensive order details
class VoucherCheckoutScreen extends StatefulWidget {
  const VoucherCheckoutScreen({
    super.key,
    required this.voucherCartSummary,
    this.voucher,
  });

  final Map<String, dynamic> voucherCartSummary;
  final VoucherModel? voucher;

  @override
  State<VoucherCheckoutScreen> createState() => _VoucherCheckoutScreenState();
}

class _VoucherCheckoutScreenState extends State<VoucherCheckoutScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isSubmitting = false;
  String? _error;

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} ج.م';
  }

  double _getDoubleValue(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.luxuryBlack,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            _buildVoucherSummary(),
            _buildOrderSummary(),
            _buildSubmitSection(),
            // Add bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: AccountantThemeConfig.luxuryBlack,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'إتمام طلب القسيمة',
          style: AccountantThemeConfig.headlineMedium.copyWith(
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: AccountantThemeConfig.mainBackgroundGradient,
          ),
          child: Stack(
            children: [
              Positioned(
                right: 20,
                top: 60,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.greenGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_offer,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'طلب قسيمة',
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoucherSummary() {
    final voucher = widget.voucher;
    if (voucher == null) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
          gradient: AccountantThemeConfig.greenGradient,
          boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_offer,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voucher.name,
                        style: AccountantThemeConfig.headlineSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'خصم ${voucher.discountPercentage}%',
                        style: AccountantThemeConfig.bodyLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'السعر الأصلي:',
                        style: AccountantThemeConfig.bodyLarge.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        _formatCurrency(_getDoubleValue(widget.voucherCartSummary['totalOriginalPrice'])),
                        style: AccountantThemeConfig.bodyLarge.copyWith(
                          color: Colors.white70,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إجمالي التوفير:',
                        style: AccountantThemeConfig.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${(widget.voucherCartSummary['totalSavings'] ?? 0).toStringAsFixed(2)} ج.م',
                        style: AccountantThemeConfig.headlineSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: AccountantThemeConfig.primaryCardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ملخص الطلب النهائي',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow(
              'عدد المنتجات:',
              '${widget.voucherCartSummary['itemCount'] ?? 0} منتج',
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              'الكمية الإجمالية:',
              '${widget.voucherCartSummary['totalQuantity'] ?? 0} قطعة',
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              'السعر الأصلي:',
              _formatCurrency(_getDoubleValue(widget.voucherCartSummary['totalOriginalPrice'])),
              isOriginal: true,
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              'الخصم (${widget.voucherCartSummary['discountPercentage'] ?? 0}%):',
              '- ${_formatCurrency(_getDoubleValue(widget.voucherCartSummary['totalSavings']))}',
              isDiscount: true,
            ),
            const Divider(color: Colors.white24, height: 24),
            _buildSummaryRow(
              'المبلغ النهائي:',
              _formatCurrency(_getDoubleValue(widget.voucherCartSummary['totalDiscountedPrice'])),
              isFinal: true,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.greenGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.savings,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'وفرت ${_formatCurrency(_getDoubleValue(widget.voucherCartSummary['totalSavings']))}',
                    style: AccountantThemeConfig.headlineSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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

  Widget _buildSummaryRow(String label, String value, {bool isOriginal = false, bool isDiscount = false, bool isFinal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AccountantThemeConfig.bodyLarge.copyWith(
            color: isOriginal ? Colors.grey : Colors.white,
            decoration: isOriginal ? TextDecoration.lineThrough : null,
          ),
        ),
        Text(
          value,
          style: AccountantThemeConfig.bodyLarge.copyWith(
            color: isDiscount
                ? AccountantThemeConfig.primaryGreen
                : isFinal
                    ? AccountantThemeConfig.primaryGreen
                    : isOriginal
                        ? Colors.grey
                        : Colors.white,
            fontWeight: isFinal ? FontWeight.bold : FontWeight.normal,
            fontSize: isFinal ? 18 : 16,
            decoration: isOriginal ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.dangerRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AccountantThemeConfig.dangerRed),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AccountantThemeConfig.dangerRed,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: AccountantThemeConfig.bodyLarge.copyWith(
                          color: AccountantThemeConfig.dangerRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.greenGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
              ),
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitVoucherOrder,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.shopping_cart_checkout, color: Colors.white),
                label: Text(
                  _isSubmitting ? 'جاري إرسال الطلب...' : 'تأكيد طلب القسيمة',
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitVoucherOrder() async {
    // Prevent multiple simultaneous submissions
    if (_isSubmitting) {
      AppLogger.warning('⚠️ Order submission already in progress, ignoring duplicate request');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      // Enhanced null safety checks for providers
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final voucherCartProvider = Provider.of<VoucherCartProvider>(context, listen: false);

      if (supabaseProvider == null) {
        AppLogger.error('❌ SupabaseProvider is null');
        throw Exception('خطأ في النظام. يرجى إعادة تشغيل التطبيق.');
      }

      if (voucherCartProvider == null) {
        AppLogger.error('❌ VoucherCartProvider is null');
        throw Exception('خطأ في سلة القسائم. يرجى العودة إلى قائمة القسائم.');
      }

      final user = supabaseProvider.user;
      if (user == null) {
        AppLogger.error('❌ User is null - authentication required');
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      // Validate user data
      if (user.id.isEmpty) {
        AppLogger.error('❌ User ID is empty');
        throw Exception('معرف المستخدم غير صالح. يرجى تسجيل الدخول مرة أخرى.');
      }

      AppLogger.info('✅ User authenticated: ${user.id}');

      // Validate widget parameters and cart summary
      if (widget.voucherCartSummary.isEmpty) {
        AppLogger.error('❌ Voucher cart summary is empty');
        throw Exception('بيانات سلة القسائم غير متوفرة. يرجى العودة إلى سلة القسائم.');
      }

      AppLogger.info('📊 Cart summary keys: ${widget.voucherCartSummary.keys.toList()}');

      // Enhanced client voucher ID resolution with comprehensive fallback mechanisms
      String? clientVoucherId;
      AppLogger.info('🔍 Starting client voucher ID resolution...');

      // Primary: Get from cart summary with enhanced null safety
      try {
        final cartSummary = widget.voucherCartSummary;
        if (cartSummary.containsKey('clientVoucherId')) {
          final rawClientVoucherId = cartSummary['clientVoucherId'];
          if (rawClientVoucherId != null) {
            clientVoucherId = rawClientVoucherId.toString();
            if (clientVoucherId.isNotEmpty && clientVoucherId != 'null') {
              AppLogger.info('✅ Client voucher ID found in cart summary: $clientVoucherId');
            } else {
              AppLogger.warning('⚠️ Client voucher ID in cart summary is empty or null string');
              clientVoucherId = null;
            }
          } else {
            AppLogger.warning('⚠️ Client voucher ID in cart summary is null');
          }
        } else {
          AppLogger.warning('⚠️ clientVoucherId key not found in cart summary');
        }
      } catch (e) {
        AppLogger.warning('⚠️ Error getting client voucher ID from cart summary: $e');
        clientVoucherId = null;
      }

      // Fallback 1: Get from voucher cart provider with enhanced null safety
      if (clientVoucherId == null || clientVoucherId.isEmpty) {
        try {
          final providerClientVoucherId = voucherCartProvider.clientVoucherId;
          if (providerClientVoucherId != null && providerClientVoucherId.isNotEmpty && providerClientVoucherId != 'null') {
            clientVoucherId = providerClientVoucherId;
            AppLogger.info('✅ Client voucher ID found in provider: $clientVoucherId');
          } else {
            AppLogger.warning('⚠️ Client voucher ID is null/empty in provider: $providerClientVoucherId');
          }
        } catch (e) {
          AppLogger.warning('⚠️ Error getting client voucher ID from provider: $e');
        }
      }

      // Fallback 2: Search for active client voucher assignment
      if (clientVoucherId == null || clientVoucherId.isEmpty) {
        final voucherArg = widget.voucher;
        final appliedVoucher = voucherCartProvider.appliedVoucher;
        final targetVoucher = voucherArg ?? appliedVoucher;

        if (targetVoucher != null) {
          AppLogger.warning('⚠️ Attempting to find client voucher assignment for voucher: ${targetVoucher.id}');

          try {
            final voucherProvider = Provider.of<VoucherProvider>(context, listen: false);

            // Force reload client vouchers to get latest data
            AppLogger.info('🔄 Reloading client vouchers for user: ${user.id}');
            await voucherProvider.loadClientVouchers(user.id);

            // Find matching active client voucher
            final matchingClientVoucher = voucherProvider.clientVouchers.firstWhere(
              (cv) => cv.voucherId == targetVoucher.id && cv.status == ClientVoucherStatus.active,
              orElse: () => throw Exception('لم يتم العثور على تعيين قسيمة صالح للمستخدم'),
            );

            clientVoucherId = matchingClientVoucher.id;
            AppLogger.info('✅ Found matching client voucher: $clientVoucherId');

            // Update provider with found client voucher ID
            voucherCartProvider.setClientVoucherId(clientVoucherId);

          } catch (e) {
            AppLogger.error('❌ Failed to find client voucher assignment: $e');

            // Additional debugging: List all available client vouchers
            try {
              final voucherProvider = Provider.of<VoucherProvider>(context, listen: false);
              AppLogger.info('📋 Available client vouchers for debugging:');
              for (final cv in voucherProvider.clientVouchers) {
                AppLogger.info('   - Client Voucher ID: ${cv.id}, Voucher ID: ${cv.voucherId}, Status: ${cv.status}');
              }
            } catch (debugError) {
              AppLogger.error('❌ Error listing client vouchers for debugging: $debugError');
            }
          }
        } else {
          AppLogger.error('❌ No voucher available for client voucher ID lookup');
        }
      }

      // Final validation with enhanced error reporting
      if (clientVoucherId == null || clientVoucherId.isEmpty) {
        AppLogger.error('❌ CRITICAL: Client voucher ID is null or empty after all fallback attempts');
        AppLogger.error('📊 Debug info:');
        AppLogger.error('   - User ID: ${user.id}');
        AppLogger.error('   - Applied voucher: ${voucherCartProvider.appliedVoucher?.id}');
        AppLogger.error('   - Voucher argument: ${widget.voucher?.id}');
        AppLogger.error('   - Cart summary keys: ${widget.voucherCartSummary.keys.toList()}');

        throw Exception('معرف القسيمة غير متوفر. يرجى العودة إلى قائمة القسائم واختيار القسيمة مرة أخرى.');
      }

      AppLogger.info('✅ Client voucher ID resolved successfully: $clientVoucherId');

      // Comprehensive voucher cart validation
      AppLogger.info('🔍 Validating voucher cart data...');

      if (voucherCartProvider.isEmpty) {
        AppLogger.error('❌ Voucher cart is empty');
        throw Exception('سلة القسائم فارغة. يرجى إضافة منتجات قبل إتمام الطلب.');
      }

      if (voucherCartProvider.itemCount <= 0) {
        AppLogger.error('❌ Voucher cart item count is zero or negative: ${voucherCartProvider.itemCount}');
        throw Exception('لا توجد منتجات في سلة القسائم. يرجى إضافة منتجات قبل إتمام الطلب.');
      }

      // Validate voucher is still active with null safety
      final appliedVoucher = voucherCartProvider.appliedVoucher;
      if (appliedVoucher != null) {
        if (!appliedVoucher.isValid) {
          AppLogger.error('❌ Applied voucher is not valid: ${appliedVoucher.id}');
          throw Exception('القسيمة المطبقة غير صالحة أو منتهية الصلاحية.');
        }
        AppLogger.info('✅ Applied voucher is valid: ${appliedVoucher.name}');
      } else {
        AppLogger.warning('⚠️ No applied voucher found in provider');
      }

      // Validate cart totals
      final totalOriginalPrice = voucherCartProvider.totalOriginalPrice;
      final totalDiscountedPrice = voucherCartProvider.totalDiscountedPrice;
      final totalSavings = voucherCartProvider.totalSavings;

      if (totalOriginalPrice <= 0) {
        AppLogger.error('❌ Invalid total original price: $totalOriginalPrice');
        throw Exception('إجمالي السعر الأصلي غير صالح. يرجى إعادة تحديث سلة القسائم.');
      }

      if (totalDiscountedPrice < 0) {
        AppLogger.error('❌ Invalid total discounted price: $totalDiscountedPrice');
        throw Exception('إجمالي السعر بعد الخصم غير صالح. يرجى إعادة تحديث سلة القسائم.');
      }

      if (totalSavings < 0) {
        AppLogger.error('❌ Invalid total savings: $totalSavings');
        throw Exception('إجمالي التوفير غير صالح. يرجى إعادة تحديث سلة القسائم.');
      }

      AppLogger.info('✅ Voucher cart validation passed');

      // Enhanced voucher order creation with comprehensive logging
      AppLogger.info('🚀 Starting voucher order creation...');
      AppLogger.info('📊 Order details:');
      AppLogger.info('   - Client ID: ${user.id}');
      AppLogger.info('   - Client Name: ${user.name.isNotEmpty ? user.name : user.email.split('@').first}');
      AppLogger.info('   - Client Email: ${user.email}');
      AppLogger.info('   - Client Phone: ${user.phone.isNotEmpty ? user.phone : (user.phoneNumber ?? '')}');
      AppLogger.info('   - Client Voucher ID: $clientVoucherId');
      AppLogger.info('   - Cart Items Count: ${voucherCartProvider.itemCount}');
      AppLogger.info('   - Total Original Price: ${voucherCartProvider.totalOriginalPrice}');
      AppLogger.info('   - Total Discounted Price: ${voucherCartProvider.totalDiscountedPrice}');
      AppLogger.info('   - Total Savings: ${voucherCartProvider.totalSavings}');

      String? orderId;
      try {
        // Validate user data before order creation
        final clientName = user.name.isNotEmpty ? user.name : user.email.split('@').first;
        final clientEmail = user.email ?? '';
        final clientPhone = user.phone.isNotEmpty ? user.phone : (user.phoneNumber ?? '');

        if (clientName.isEmpty) {
          AppLogger.error('❌ Client name is empty');
          throw Exception('اسم العميل غير متوفر. يرجى تحديث بيانات الملف الشخصي.');
        }

        if (clientEmail.isEmpty) {
          AppLogger.error('❌ Client email is empty');
          throw Exception('البريد الإلكتروني غير متوفر. يرجى تحديث بيانات الملف الشخصي.');
        }

        AppLogger.info('📝 Creating voucher order with validated data...');
        orderId = await voucherCartProvider.createVoucherOrder(
          clientId: user.id,
          clientName: clientName,
          clientEmail: clientEmail,
          clientPhone: clientPhone,
          clientVoucherId: clientVoucherId,
        );

        if (orderId != null && orderId.isNotEmpty) {
          AppLogger.info('✅ Voucher order created successfully with ID: $orderId');
        } else {
          AppLogger.error('❌ Voucher order creation returned null or empty');
          AppLogger.error('❌ Provider error: ${voucherCartProvider.error}');
          throw Exception(voucherCartProvider.error ?? 'فشل في إنشاء الطلب. يرجى المحاولة مرة أخرى.');
        }
      } catch (orderCreationError) {
        AppLogger.error('❌ Exception during voucher order creation: $orderCreationError');
        AppLogger.error('❌ Stack trace: ${StackTrace.current}');
        rethrow;
      }

      if (orderId != null && orderId.isNotEmpty) {
        // Navigate to order success screen (consistent with regular checkout)
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OrderSuccessScreen(orderId: orderId!),
            ),
          );
        }
      } else {
        // Order creation failed - provide detailed error information
        final providerError = voucherCartProvider.error;
        AppLogger.error('❌ Order creation failed - Provider error: $providerError');

        if (providerError != null && providerError.isNotEmpty) {
          throw Exception(providerError);
        } else {
          throw Exception('فشل في إنشاء الطلب. يرجى التحقق من الاتصال بالإنترنت والمحاولة مرة أخرى.');
        }
      }
    } catch (e) {
      AppLogger.error('❌ Error submitting voucher order: $e');

      // Provide user-friendly error messages
      String userFriendlyError;
      final errorMessage = e.toString();

      if (errorMessage.contains('معرف القسيمة غير متوفر')) {
        userFriendlyError = 'معرف القسيمة غير متوفر. يرجى العودة إلى قائمة القسائم واختيار القسيمة مرة أخرى.';
      } else if (errorMessage.contains('يجب تسجيل الدخول')) {
        userFriendlyError = 'انتهت جلسة تسجيل الدخول. يرجى تسجيل الدخول مرة أخرى.';
      } else if (errorMessage.contains('لم يتم العثور على تعيين قسيمة صالح')) {
        userFriendlyError = 'هذه القسيمة غير متاحة أو منتهية الصلاحية. يرجى اختيار قسيمة أخرى.';
      } else if (errorMessage.contains('network') || errorMessage.contains('connection')) {
        userFriendlyError = 'مشكلة في الاتصال بالإنترنت. يرجى التحقق من الاتصال والمحاولة مرة أخرى.';
      } else {
        userFriendlyError = 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى أو الاتصال بالدعم الفني.';
      }

      setState(() {
        _error = userFriendlyError;
      });

      // Show snackbar with action buttons for better UX
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFriendlyError),
            backgroundColor: AccountantThemeConfig.dangerRed,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'العودة للرئيسية',
              textColor: Colors.white,
              onPressed: () {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/client',
                  (route) => false, // Clear entire navigation stack
                );
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
