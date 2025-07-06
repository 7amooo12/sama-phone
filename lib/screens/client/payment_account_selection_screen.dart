import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/electronic_payment_provider.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../config/routes.dart';
import '../../models/electronic_payment_model.dart';
import '../../models/payment_account_model.dart';

/// Payment account selection screen for clients
class PaymentAccountSelectionScreen extends StatefulWidget {
  const PaymentAccountSelectionScreen({super.key});

  @override
  State<PaymentAccountSelectionScreen> createState() => _PaymentAccountSelectionScreenState();
}

class _PaymentAccountSelectionScreenState extends State<PaymentAccountSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  ElectronicPaymentMethod? _paymentMethod;
  List<PaymentAccountModel> _accounts = [];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadArguments();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  void _loadArguments() {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _paymentMethod = args['paymentMethod'] as ElectronicPaymentMethod;
      _loadAccounts();
    }
  }

  void _loadAccounts() {
    final paymentProvider = Provider.of<ElectronicPaymentProvider>(context, listen: false);
    
    if (_paymentMethod == ElectronicPaymentMethod.vodafoneCash) {
      _accounts = paymentProvider.vodafoneAccounts;
    } else if (_paymentMethod == ElectronicPaymentMethod.instaPay) {
      _accounts = paymentProvider.instapayAccounts;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_paymentMethod == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: CustomAppBar(
          title: _getMethodDisplayName(),
          backgroundColor: Colors.black,
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(),
                const SizedBox(height: 32),

                // Instructions
                _buildInstructions(),
                const SizedBox(height: 24),

                // Account List
                _buildAccountList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getMethodColor(),
            _getMethodColor().withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _getMethodIcon(),
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getMethodDisplayName(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'اختر الحساب المناسب للدفع',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Color(0xFF10B981),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'تعليمات',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '• اسحب يميناً على الحساب المطلوب للاختيار\n• تأكد من صحة رقم الحساب قبل المتابعة\n• ستحتاج لتصوير إثبات الدفع بعد التحويل',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountList() {
    if (_accounts.isEmpty) {
      return _buildNoAccountsCard();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الحسابات المتاحة (${_accounts.length})',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...(_accounts.map((account) => _buildAccountCard(account)).toList()),
      ],
    );
  }

  Widget _buildAccountCard(PaymentAccountModel account) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Dismissible(
        key: Key(account.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                _getMethodColor().withOpacity(0.1),
                _getMethodColor(),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
              SizedBox(height: 4),
              Text(
                'اختيار',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        confirmDismiss: (direction) async {
          _selectAccount(account);
          return false; // Don't actually dismiss
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: _getMethodColor().withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getMethodColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getMethodColor().withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    _getMethodIcon(),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.accountHolderName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account.maskedAccountNumber,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getMethodColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getMethodColor().withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.swipe_left,
                      color: _getMethodColor(),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'اسحب',
                      style: TextStyle(
                        color: _getMethodColor(),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoAccountsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            size: 48,
            color: Colors.white24,
          ),
          const SizedBox(height: 16),
          const Text(
            'لا توجد حسابات متاحة',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'لا توجد حسابات ${_getMethodDisplayName()} متاحة حالياً',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _selectAccount(PaymentAccountModel account) {
    Navigator.pushNamed(
      context,
      AppRoutes.enhancedPaymentWorkflow,
      arguments: {
        'paymentMethod': _paymentMethod,
        'selectedAccount': account,
      },
    );
  }

  String _getMethodDisplayName() {
    switch (_paymentMethod!) {
      case ElectronicPaymentMethod.vodafoneCash:
        return 'فودافون كاش';
      case ElectronicPaymentMethod.instaPay:
        return 'إنستاباي';
    }
  }

  String _getMethodIcon() {
    switch (_paymentMethod!) {
      case ElectronicPaymentMethod.vodafoneCash:
        return '🟥';
      case ElectronicPaymentMethod.instaPay:
        return '🟦';
    }
  }

  Color _getMethodColor() {
    switch (_paymentMethod!) {
      case ElectronicPaymentMethod.vodafoneCash:
        return const Color(0xFFE53E3E);
      case ElectronicPaymentMethod.instaPay:
        return const Color(0xFF3182CE);
    }
  }
}
