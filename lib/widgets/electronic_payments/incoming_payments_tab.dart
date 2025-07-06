import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/electronic_payment_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../models/electronic_payment_model.dart';
import '../../utils/app_logger.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/formatters.dart';
import '../../widgets/accountant/modern_widgets.dart';

/// Tab for displaying and managing incoming electronic payments
class IncomingPaymentsTab extends StatefulWidget {
  const IncomingPaymentsTab({super.key});

  @override
  State<IncomingPaymentsTab> createState() => _IncomingPaymentsTabState();
}

class _IncomingPaymentsTabState extends State<IncomingPaymentsTab>
    with TickerProviderStateMixin {
  late TabController _statusTabController;

  @override
  void initState() {
    super.initState();
    _statusTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _statusTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ElectronicPaymentProvider>(
      builder: (context, paymentProvider, child) {
        return Container(
          decoration: const BoxDecoration(
            gradient: AccountantThemeConfig.mainBackgroundGradient,
          ),
          child: Column(
            children: [
              // Add top spacing to replace removed statistics cards
              const SizedBox(height: AccountantThemeConfig.defaultPadding),

              // Modern Payment Method Filter Tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AccountantThemeConfig.defaultPadding),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.cardGradient,
                  borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                  border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
                  boxShadow: AccountantThemeConfig.cardShadows,
                ),
                child: TabBar(
                  controller: _statusTabController,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.pending_actions_rounded, size: 20),
                      text: 'قيد المراجعة',
                    ),
                    Tab(
                      icon: Icon(Icons.check_circle_rounded, size: 20),
                      text: 'مقبولة',
                    ),
                    Tab(
                      icon: Icon(Icons.cancel_rounded, size: 20),
                      text: 'مرفوضة',
                    ),
                  ],
                  indicator: BoxDecoration(
                    gradient: AccountantThemeConfig.greenGradient,
                    borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                    boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(4),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: AccountantThemeConfig.bodyMedium,
                ),
              ),

              const SizedBox(height: AccountantThemeConfig.defaultPadding),

              // Payment Method Sections with smooth animations
              Expanded(
                child: TabBarView(
                  controller: _statusTabController,
                  children: [
                    _buildPaymentsList(
                      paymentProvider.getPaymentsByStatus(ElectronicPaymentStatus.pending),
                      'قيد المراجعة',
                    ),
                    _buildPaymentsList(
                      paymentProvider.getPaymentsByStatus(ElectronicPaymentStatus.approved),
                      'مقبولة',
                    ),
                    _buildPaymentsList(
                      paymentProvider.getPaymentsByStatus(ElectronicPaymentStatus.rejected),
                      'مرفوضة',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }





  Widget _buildPaymentsList(List<ElectronicPaymentModel> payments, String statusTitle) {
    if (payments.isEmpty) {
      return ModernAccountantWidgets.buildEmptyState(
        icon: Icons.payment_outlined,
        title: 'لا توجد مدفوعات $statusTitle',
        subtitle: 'سيتم عرض المدفوعات هنا عند توفرها',
      );
    }

    // Group payments by method
    final vodafonePayments = payments
        .where((p) => p.paymentMethod == ElectronicPaymentMethod.vodafoneCash)
        .toList();
    final instapayPayments = payments
        .where((p) => p.paymentMethod == ElectronicPaymentMethod.instaPay)
        .toList();

    return RefreshIndicator(
      onRefresh: () async {
        final paymentProvider = Provider.of<ElectronicPaymentProvider>(context, listen: false);
        await paymentProvider.loadAllPayments();
      },
      color: AccountantThemeConfig.primaryGreen,
      backgroundColor: AccountantThemeConfig.cardBackground1,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vodafone Cash Section
            if (vodafonePayments.isNotEmpty) ...[
              _buildModernPaymentMethodSection(
                'فودافون كاش',
                vodafonePayments,
                const Color(0xFFE60012),
                Icons.phone_android_rounded,
              ),
              const SizedBox(height: AccountantThemeConfig.largePadding),
            ],

            // InstaPay Section
            if (instapayPayments.isNotEmpty) ...[
              _buildModernPaymentMethodSection(
                'إنستاباي',
                instapayPayments,
                const Color(0xFF1E88E5),
                Icons.credit_card_rounded,
              ),
            ],

            // Show message if no payments for any method
            if (vodafonePayments.isEmpty && instapayPayments.isEmpty) ...[
              const SizedBox(height: 100),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModernPaymentMethodSection(
    String title,
    List<ElectronicPaymentModel> payments,
    Color color,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Modern Section Header
        ModernAccountantWidgets.buildSectionHeader(
          title: title,
          icon: icon,
          iconColor: color,
          actionText: '${payments.length} مدفوعة',
        ),

        const SizedBox(height: AccountantThemeConfig.defaultPadding),

        // Payment Cards with animations
        ...payments.asMap().entries.map((entry) {
          final index = entry.key;
          final payment = entry.value;
          return AnimatedContainer(
            duration: Duration(milliseconds: 800 + (index * 100)),
            curve: Curves.easeInOut,
            child: _buildModernPaymentCard(payment, color),
          );
        }),
      ],
    );
  }

  Widget _buildModernPaymentCard(ElectronicPaymentModel payment, Color methodColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: AccountantThemeConfig.defaultPadding),
      padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
        border: AccountantThemeConfig.glowBorder(methodColor),
        boxShadow: AccountantThemeConfig.glowShadows(methodColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modern Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [methodColor.withOpacity(0.2), methodColor.withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                  border: Border.all(color: methodColor.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    payment.paymentMethodIcon,
                    style: AccountantThemeConfig.headlineMedium.copyWith(
                      fontSize: 20,
                      color: methodColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AccountantThemeConfig.defaultPadding),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.clientName ?? 'عميل غير معروف',
                      style: AccountantThemeConfig.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      payment.paymentMethodDisplayName,
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: methodColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getStatusColor(payment.status).withOpacity(0.2),
                      _getStatusColor(payment.status).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getStatusColor(payment.status).withOpacity(0.4)),
                ),
                child: Text(
                  payment.statusDisplayName,
                  style: AccountantThemeConfig.labelMedium.copyWith(
                    color: _getStatusColor(payment.status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AccountantThemeConfig.defaultPadding),

          // Modern Payment Details
          _buildModernDetailRow('المبلغ', payment.formattedAmount, Icons.attach_money_rounded, AccountantThemeConfig.primaryGreen),
          _buildModernDetailRow('الحساب المستلم', payment.recipientAccountHolderName ?? 'غير محدد', Icons.account_circle_rounded, AccountantThemeConfig.accentBlue),
          _buildModernDetailRow('رقم الحساب', payment.recipientAccountNumber ?? 'غير محدد', Icons.credit_card_rounded, AccountantThemeConfig.accentBlue),
          _buildModernDetailRow('تاريخ الطلب', _formatDate(payment.createdAt), Icons.access_time_rounded, AccountantThemeConfig.neutralColor),

          if (payment.adminNotes != null && payment.adminNotes!.isNotEmpty) ...[
            const SizedBox(height: AccountantThemeConfig.smallPadding),
            _buildModernDetailRow('ملاحظات الإدارة', payment.adminNotes!, Icons.note_rounded, AccountantThemeConfig.warningOrange),
          ],

          const SizedBox(height: AccountantThemeConfig.defaultPadding),

          // Modern Action Buttons
          if (payment.status == ElectronicPaymentStatus.pending) ...[
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AccountantThemeConfig.greenGradient,
                      borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                      boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _showApprovalDialog(payment, true),
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text('قبول', style: AccountantThemeConfig.labelLarge),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AccountantThemeConfig.defaultPadding),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AccountantThemeConfig.dangerRed, AccountantThemeConfig.dangerRed.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                      boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.dangerRed),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _showApprovalDialog(payment, false),
                      icon: const Icon(Icons.cancel_rounded, size: 18),
                      label: Text('رفض', style: AccountantThemeConfig.labelLarge),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Modern View Proof Button
          if (payment.proofImageUrl != null) ...[
            const SizedBox(height: AccountantThemeConfig.defaultPadding),
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [methodColor.withOpacity(0.1), methodColor.withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                  border: Border.all(color: methodColor.withOpacity(0.3)),
                ),
                child: OutlinedButton.icon(
                  onPressed: () => _showProofImage(payment.proofImageUrl!),
                  icon: Icon(Icons.image_rounded, size: 18, color: methodColor),
                  label: Text(
                    'عرض إثبات الدفع',
                    style: AccountantThemeConfig.labelLarge.copyWith(color: methodColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernDetailRow(String label, String value, IconData icon, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: AccountantThemeConfig.smallPadding),
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 16,
            ),
          ),
          const SizedBox(width: AccountantThemeConfig.defaultPadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ElectronicPaymentStatus status) {
    switch (status) {
      case ElectronicPaymentStatus.pending:
        return AccountantThemeConfig.pendingColor;
      case ElectronicPaymentStatus.approved:
        return AccountantThemeConfig.completedColor;
      case ElectronicPaymentStatus.rejected:
        return AccountantThemeConfig.canceledColor;
    }
  }

  String _formatDate(DateTime date) {
    // Convert to local time if UTC to ensure proper timezone handling
    final localDate = date.isUtc ? date.toLocal() : date;

    // Use the standard formatter for consistent date/time display across the app
    return Formatters.formatDateTime(localDate);
  }

  void _showApprovalDialog(ElectronicPaymentModel payment, bool approve) {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text(
                approve ? 'قبول الدفعة' : 'رفض الدفعة',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'العميل: ${payment.clientName ?? 'غير محدد'}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  Text(
                    'المبلغ: ${payment.amount.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  Text(
                    'طريقة الدفع: ${payment.paymentMethod == ElectronicPaymentMethod.vodafoneCash ? 'فودافون كاش' : 'إنستاباي'}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  Text(
                    'الحساب المستلم: ${payment.recipientAccountHolderName ?? 'غير محدد'}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  Text(
                    'رقم الحساب: ${payment.recipientAccountNumber ?? 'غير محدد'}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Cairo',
                    ),
                  ),

                  // Show balance validation only for approval
                  if (approve) ...[
                    const SizedBox(height: 16),
                    FutureBuilder<Map<String, dynamic>>(
                      future: Provider.of<ElectronicPaymentProvider>(context, listen: false)
                          .validateClientWalletBalance(payment.clientId, payment.amount),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[900]?.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[700]!),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.blue,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'جاري التحقق من رصيد العميل...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[900]?.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red[700]!),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.error, color: Colors.red, size: 16),
                                    SizedBox(width: 8),
                                    Text(
                                      'خطأ في التحقق من الرصيد',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'تعذر التحقق من رصيد العميل',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final validation = snapshot.data!;
                        final isValid = validation['isValid'] as bool;
                        final currentBalance = validation['currentBalance'] as double;
                        final remainingBalance = validation['remainingBalance'] as double;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isValid
                                ? Colors.green[900]?.withOpacity(0.3)
                                : Colors.red[900]?.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isValid ? Colors.green[700]! : Colors.red[700]!,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isValid ? Icons.check_circle : Icons.error,
                                    color: isValid ? Colors.green : Colors.red,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isValid ? 'رصيد العميل كافي' : 'رصيد العميل غير كافي',
                                    style: TextStyle(
                                      color: isValid ? Colors.green : Colors.red,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'الرصيد الحالي: ${currentBalance.toStringAsFixed(2)} ج.م',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                              if (isValid) ...[
                                Text(
                                  'الرصيد بعد الخصم: ${remainingBalance.toStringAsFixed(2)} ج.م',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Cairo',
                    ),
                    decoration: InputDecoration(
                      labelText: approve ? 'ملاحظات (اختياري)' : 'سبب الرفض',
                      labelStyle: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Cairo',
                      ),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
                if (approve) ...[
                  // For approval, check balance validation
                  FutureBuilder<Map<String, dynamic>>(
                    future: Provider.of<ElectronicPaymentProvider>(context, listen: false)
                        .validateClientWalletBalance(payment.clientId, payment.amount),
                    builder: (context, snapshot) {
                      final isValid = snapshot.hasData && (snapshot.data!['isValid'] as bool);

                      return ElevatedButton(
                        onPressed: isValid
                            ? () => _processApproval(payment, approve, notesController.text)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isValid ? const Color(0xFF10B981) : Colors.grey[600],
                        ),
                        child: const Text(
                          'قبول',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      );
                    },
                  ),
                ] else ...[
                  // For rejection, no validation needed
                  ElevatedButton(
                    onPressed: () => _processApproval(payment, approve, notesController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text(
                      'رفض',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _processApproval(ElectronicPaymentModel payment, bool approve, String notes) async {
    Navigator.of(context).pop();

    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final paymentProvider = Provider.of<ElectronicPaymentProvider>(context, listen: false);

    if (supabaseProvider.user == null) {
      _showErrorMessage('خطأ في المصادقة. يرجى تسجيل الدخول مرة أخرى.');
      return;
    }

    // Show loading indicator
    _showLoadingDialog();

    try {
      final success = await paymentProvider.updatePaymentStatus(
        paymentId: payment.id,
        status: approve ? ElectronicPaymentStatus.approved : ElectronicPaymentStatus.rejected,
        approvedBy: supabaseProvider.user!.id,
        adminNotes: notes.trim().isEmpty ? null : notes.trim(),
      );

      // Hide loading dialog
      if (mounted) Navigator.of(context).pop();

      if (success) {
        _showSuccessMessage(approve ? 'تم اعتماد الدفعة بنجاح' : 'تم رفض الدفعة');
      } else {
        _showErrorMessage('فشل في معالجة الدفعة. يرجى المحاولة مرة أخرى.');
      }
    } catch (e) {
      // Hide loading dialog
      if (mounted) Navigator.of(context).pop();

      AppLogger.error('❌ Payment processing error', e);
      _showErrorMessage('حدث خطأ أثناء معالجة الدفعة: ${e.toString()}');
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
          decoration: AccountantThemeConfig.primaryCardDecoration,
          child: ModernAccountantWidgets.buildModernLoader(
            message: 'جاري معالجة الدفعة...',
            color: AccountantThemeConfig.primaryGreen,
          ),
        ),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: AccountantThemeConfig.defaultPadding),
            Expanded(
              child: Text(
                message,
                style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AccountantThemeConfig.completedColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_rounded, color: Colors.white, size: 20),
            const SizedBox(width: AccountantThemeConfig.defaultPadding),
            Expanded(
              child: Text(
                message,
                style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AccountantThemeConfig.dangerRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showProofImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          decoration: AccountantThemeConfig.primaryCardDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modern Header
              Container(
                padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.blueGradient,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AccountantThemeConfig.largeBorderRadius),
                    topRight: Radius.circular(AccountantThemeConfig.largeBorderRadius),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.image_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: AccountantThemeConfig.defaultPadding),
                    Text(
                      'إثبات الدفع',
                      style: AccountantThemeConfig.headlineSmall,
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              // Modern Image Container
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.cardGradient,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(AccountantThemeConfig.largeBorderRadius),
                      bottomRight: Radius.circular(AccountantThemeConfig.largeBorderRadius),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return ModernAccountantWidgets.buildModernLoader(
                          message: 'جاري تحميل الصورة...',
                          color: AccountantThemeConfig.primaryGreen,
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return ModernAccountantWidgets.buildEmptyState(
                          icon: Icons.error_outline_rounded,
                          title: 'فشل في تحميل الصورة',
                          subtitle: 'تعذر عرض إثبات الدفع',
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
