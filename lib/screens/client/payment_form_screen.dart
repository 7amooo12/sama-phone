import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../providers/electronic_payment_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../config/routes.dart';
import '../../models/electronic_payment_model.dart';
import '../../models/payment_account_model.dart';
import '../../services/supabase_storage_service.dart';

/// Payment form screen for clients
class PaymentFormScreen extends StatefulWidget {
  const PaymentFormScreen({super.key});

  @override
  State<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends State<PaymentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  
  ElectronicPaymentMethod? _paymentMethod;
  PaymentAccountModel? _selectedAccount;
  File? _proofImage;
  bool _isLoading = false;
  bool _paymentCompleted = false;

  final ImagePicker _imagePicker = ImagePicker();
  final SupabaseStorageService _storageService = SupabaseStorageService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadArguments();
    });
  }

  void _loadArguments() {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      setState(() {
        _paymentMethod = args['paymentMethod'] as ElectronicPaymentMethod;
        _selectedAccount = args['selectedAccount'] as PaymentAccountModel;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_paymentMethod == null || _selectedAccount == null) {
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
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Account Info Card
                _buildAccountInfoCard(),
                const SizedBox(height: 24),

                // Payment Form
                if (!_paymentCompleted) ...[
                  _buildPaymentForm(),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                ] else ...[
                  _buildProofUploadSection(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountInfoCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _getMethodIcon(),
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedAccount!.accountHolderName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedAccount!.accountNumber,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _copyToClipboard(_selectedAccount!.accountNumber),
                icon: const Icon(
                  Icons.copy,
                  color: Colors.white70,
                ),
                tooltip: 'نسخ رقم الحساب',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تفاصيل الدفعة',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Amount Field
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'المبلغ (ج.م)',
              labelStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.attach_money, color: Colors.white70),
              suffixText: 'ج.م',
              suffixStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _getMethodColor()),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى إدخال المبلغ';
              }
              final amount = double.tryParse(value);
              if (amount == null || amount <= 0) {
                return 'يرجى إدخال مبلغ صحيح';
              }
              if (amount < 10) {
                return 'الحد الأدنى للدفع 10 ج.م';
              }
              if (amount > 10000) {
                return 'الحد الأقصى للدفع 10,000 ج.م';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Notes Field (Optional)
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'ملاحظات (اختياري)',
              labelStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.note, color: Colors.white70),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _getMethodColor()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Main Action Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _handlePaymentAction,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(_getActionIcon()),
            label: Text(
              _getActionText(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _getMethodColor(),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Instructions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: _getMethodColor(),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'تعليمات الدفع',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _getInstructions(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProofUploadSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Color(0xFF10B981),
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                'تم إرسال الدفعة بنجاح',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'يرجى تصوير إثبات الدفع وإرفاقه لتأكيد العملية',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),

          // Image Upload Section
          if (_proofImage == null) ...[
            _buildImageUploadButton(),
          ] else ...[
            _buildImagePreview(),
            const SizedBox(height: 16),
            _buildSubmitButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildImageUploadButton() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getMethodColor().withOpacity(0.3),
            style: BorderStyle.solid,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_upload,
              color: _getMethodColor(),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'اضغط لتصوير إثبات الدفع',
              style: TextStyle(
                color: _getMethodColor(),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'JPG, PNG (حد أقصى 5 ميجا)',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إثبات الدفع',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _proofImage!,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('تغيير الصورة'),
              style: TextButton.styleFrom(
                foregroundColor: _getMethodColor(),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _proofImage = null),
              icon: const Icon(Icons.delete, size: 16),
              label: const Text('حذف'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _submitPayment,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.send),
        label: const Text(
          'إرسال طلب الدفع',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // Helper methods and actions will be added in the next part
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

  IconData _getActionIcon() {
    switch (_paymentMethod!) {
      case ElectronicPaymentMethod.vodafoneCash:
        return Icons.phone;
      case ElectronicPaymentMethod.instaPay:
        return Icons.send;
    }
  }

  String _getActionText() {
    switch (_paymentMethod!) {
      case ElectronicPaymentMethod.vodafoneCash:
        return 'فتح الهاتف للدفع';
      case ElectronicPaymentMethod.instaPay:
        return 'إرسال طلب الدفع';
    }
  }

  String _getInstructions() {
    switch (_paymentMethod!) {
      case ElectronicPaymentMethod.vodafoneCash:
        return '• سيتم فتح تطبيق الهاتف تلقائياً مع كود USSD\n• اتبع التعليمات لإتمام الدفع\n• قم بتصوير إثبات الدفع بعد الانتهاء';
      case ElectronicPaymentMethod.instaPay:
        return '• قم بتحويل المبلغ عبر تطبيق البنك الخاص بك\n• استخدم رقم الحساب المعروض أعلاه\n• قم بتصوير إثبات التحويل';
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ رقم الحساب'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handlePaymentAction() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text);

    if (_paymentMethod == ElectronicPaymentMethod.vodafoneCash) {
      await _launchVodafoneUSSD(amount);
    } else {
      await _processInstapayPayment(amount);
    }
  }

  Future<void> _launchVodafoneUSSD(double amount) async {
    final ussdCode = '*9*7*${_selectedAccount!.accountNumber}*${amount.toInt()}#';
    final uri = Uri(scheme: 'tel', path: ussdCode);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        setState(() {
          _paymentCompleted = true;
        });
      } else {
        _showManualInstructions(ussdCode);
      }
    } catch (e) {
      _showManualInstructions(ussdCode);
    }
  }

  Future<void> _processInstapayPayment(double amount) async {
    setState(() {
      _paymentCompleted = true;
    });
  }

  void _showManualInstructions(String ussdCode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'تعليمات الدفع اليدوي',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اتصل بالرقم التالي من هاتفك:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ussdCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyToClipboard(ussdCode),
                    icon: const Icon(Icons.copy, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _paymentCompleted = true;
              });
            },
            child: const Text('تم الدفع'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        final fileSize = await file.length();

        if (fileSize > 5 * 1024 * 1024) { // 5MB limit
          _showErrorSnackBar('حجم الصورة كبير جداً. الحد الأقصى 5 ميجا');
          return;
        }

        setState(() {
          _proofImage = file;
        });
      }
    } catch (e) {
      _showErrorSnackBar('فشل في تصوير الصورة: $e');
    }
  }

  Future<void> _submitPayment() async {
    if (_proofImage == null) {
      _showErrorSnackBar('يرجى إرفاق إثبات الدفع');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final paymentProvider = Provider.of<ElectronicPaymentProvider>(context, listen: false);

      if (supabaseProvider.user == null) {
        _showErrorSnackBar('يرجى تسجيل الدخول أولاً');
        return;
      }

      // Upload proof image
      final imageUrl = await _storageService.uploadPaymentProof(
        clientId: supabaseProvider.user!.id,
        paymentId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        file: _proofImage!,
      );

      // Create payment record
      final payment = await paymentProvider.createPayment(
        clientId: supabaseProvider.user!.id,
        paymentMethod: _paymentMethod!,
        amount: double.parse(_amountController.text),
        recipientAccountId: _selectedAccount!.id,
        proofImageUrl: imageUrl,
        metadata: {
          'notes': _notesController.text.trim(),
          'account_number': _selectedAccount!.accountNumber,
          'account_holder': _selectedAccount!.accountHolderName,
        },
      );

      if (payment != null) {
        _showSuccessDialog();
      } else {
        _showErrorSnackBar('فشل في إرسال طلب الدفع');
      }
    } catch (e) {
      _showErrorSnackBar('حدث خطأ: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Color(0xFF10B981),
              size: 24,
            ),
            SizedBox(width: 12),
            Text(
              'تم الإرسال بنجاح',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: const Text(
          'تم إرسال طلب الدفع بنجاح. سيتم مراجعته من قبل الإدارة وإضافة الرصيد لمحفظتك عند الموافقة.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
              Navigator.pushReplacementNamed(context, AppRoutes.userWallet);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
            child: const Text('العودة للمحفظة'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
