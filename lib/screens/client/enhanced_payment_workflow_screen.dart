import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../providers/electronic_payment_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../models/electronic_payment_model.dart';
import '../../models/payment_account_model.dart';
import '../../services/supabase_storage_service.dart';
import '../../utils/app_logger.dart';

/// Enhanced Two-Step Electronic Payment Workflow Screen
/// Step 1: Payment Initiation with confirmation
/// Step 2: Proof Upload with camera/gallery options
/// Step 3: Complete submission with success feedback
class EnhancedPaymentWorkflowScreen extends StatefulWidget {

  const EnhancedPaymentWorkflowScreen({
    super.key,
    required this.paymentMethod,
    required this.selectedAccount,
  });
  final ElectronicPaymentMethod paymentMethod;
  final PaymentAccountModel selectedAccount;

  @override
  State<EnhancedPaymentWorkflowScreen> createState() => _EnhancedPaymentWorkflowScreenState();
}

class _EnhancedPaymentWorkflowScreenState extends State<EnhancedPaymentWorkflowScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Workflow state
  int _currentStep = 0;
  bool _isLoading = false;
  String? _error;
  
  // Payment data
  ElectronicPaymentModel? _createdPayment;
  File? _proofImage;
  
  // Services
  final ImagePicker _imagePicker = ImagePicker();
  final SupabaseStorageService _storageService = SupabaseStorageService();
  
  // Animation controllers
  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: CustomAppBar(
          title: _getStepTitle(),
          backgroundColor: Colors.black,
        ),
        body: Column(
          children: [
            // Progress Indicator
            _buildProgressIndicator(),
            
            // Main Content
            Expanded(
              child: _buildStepContent(),
            ),
          ],
        ),
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'إرسال الدفعة';
      case 1:
        return 'رفع إثبات الدفع';
      case 2:
        return 'تأكيد الإرسال';
      default:
        return 'الدفع الإلكتروني';
    }
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Step indicators
          Row(
            children: [
              _buildStepIndicator(0, 'إرسال', Icons.send),
              Expanded(child: _buildProgressLine(0)),
              _buildStepIndicator(1, 'إثبات', Icons.camera_alt),
              Expanded(child: _buildProgressLine(1)),
              _buildStepIndicator(2, 'تأكيد', Icons.check_circle),
            ],
          ),
          const SizedBox(height: 16),
          
          // Progress bar
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: (_currentStep + _progressAnimation.value) / 3,
                backgroundColor: Colors.grey[800],
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                minHeight: 4,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, IconData icon) {
    final isActive = step <= _currentStep;
    final isCompleted = step < _currentStep;
    
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted 
                ? const Color(0xFF10B981)
                : isActive 
                    ? const Color(0xFF10B981).withValues(alpha: 0.2)
                    : Colors.grey[800],
            border: Border.all(
              color: isActive ? const Color(0xFF10B981) : Colors.grey[600]!,
              width: 2,
            ),
          ),
          child: Icon(
            isCompleted ? Icons.check : icon,
            color: isActive ? const Color(0xFF10B981) : Colors.grey[400],
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[400],
            fontSize: 12,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }

  Widget _buildProgressLine(int step) {
    final isCompleted = step < _currentStep;
    
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFF10B981) : Colors.grey[800],
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildStepContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }
    
    if (_error != null) {
      return _buildErrorState();
    }
    
    switch (_currentStep) {
      case 0:
        return _buildPaymentInitiationStep();
      case 1:
        return _buildProofUploadStep();
      case 2:
        return _buildConfirmationStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
          ),
          SizedBox(height: 16),
          Text(
            'جاري المعالجة...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _error = null;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text(
                'إعادة المحاولة',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInitiationStep() {
    return SingleChildScrollView(
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
            _buildPaymentForm(),
            const SizedBox(height: 32),
            
            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handlePaymentInitiation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _getPaymentActionText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPaymentActionText() {
    return widget.paymentMethod == ElectronicPaymentMethod.vodafoneCash
        ? 'إرسال عبر فودافون كاش'
        : 'إرسال عبر إنستاباي';
  }

  Widget _buildAccountInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.paymentMethod == ElectronicPaymentMethod.vodafoneCash
                      ? const Color(0xFFE60012).withValues(alpha: 0.2)
                      : const Color(0xFF1E88E5).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.paymentMethod == ElectronicPaymentMethod.vodafoneCash
                      ? Icons.phone_android
                      : Icons.credit_card,
                  color: widget.paymentMethod == ElectronicPaymentMethod.vodafoneCash
                      ? const Color(0xFFE60012)
                      : const Color(0xFF1E88E5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.paymentMethod == ElectronicPaymentMethod.vodafoneCash
                          ? 'فودافون كاش'
                          : 'إنستاباي',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    Text(
                      widget.selectedAccount.accountHolderName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Account Number with Copy Button
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'رقم الحساب',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.selectedAccount.accountNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _copyToClipboard(widget.selectedAccount.accountNumber),
                  icon: const Icon(
                    Icons.copy,
                    color: Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'تفاصيل الدفعة',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 16),

        // Amount Field
        TextFormField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
          decoration: InputDecoration(
            labelText: 'المبلغ (ج.م)',
            labelStyle: const TextStyle(color: Colors.white70, fontFamily: 'Cairo'),
            prefixIcon: const Icon(Icons.attach_money, color: Color(0xFF10B981)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[600]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[600]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF10B981)),
            ),
            filled: true,
            fillColor: Colors.grey[900],
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'يرجى إدخال المبلغ';
            }
            final amount = double.tryParse(value);
            if (amount == null || amount <= 0) {
              return 'يرجى إدخال مبلغ صحيح';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Notes Field
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
          decoration: InputDecoration(
            labelText: 'ملاحظات (اختياري)',
            labelStyle: const TextStyle(color: Colors.white70, fontFamily: 'Cairo'),
            prefixIcon: const Icon(Icons.note, color: Color(0xFF10B981)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[600]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[600]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF10B981)),
            ),
            filled: true,
            fillColor: Colors.grey[900],
          ),
        ),
      ],
    );
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

  Future<void> _handlePaymentInitiation() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text);

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Step 1: Launch payment method
      if (widget.paymentMethod == ElectronicPaymentMethod.vodafoneCash) {
        await _launchVodafoneUSSD(amount);
      } else {
        await _processInstapayPayment(amount);
      }

      // Step 2: Create payment record
      await _createPaymentRecord(amount);

      // Step 3: Move to next step
      await _moveToNextStep();
    } catch (e) {
      setState(() {
        _error = 'حدث خطأ أثناء إرسال الدفعة: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _launchVodafoneUSSD(double amount) async {
    try {
      final accountNumber = widget.selectedAccount.accountNumber;
      final ussdCode = '*9*7*$accountNumber*${amount.toInt()}#';
      final uri = Uri(scheme: 'tel', path: ussdCode);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        AppLogger.info('✅ Launched Vodafone Cash USSD: $ussdCode');
      } else {
        throw Exception('لا يمكن فتح تطبيق الهاتف');
      }
    } catch (e) {
      AppLogger.error('❌ Error launching Vodafone USSD: $e');
      throw Exception('فشل في فتح فودافون كاش: $e');
    }
  }

  Future<void> _processInstapayPayment(double amount) async {
    try {
      // Show InstaPay instructions dialog
      await _showInstapayInstructionsDialog(amount);
    } catch (e) {
      AppLogger.error('❌ Error processing InstaPay payment: $e');
      throw Exception('فشل في معالجة دفعة إنستاباي: $e');
    }
  }

  Future<void> _showInstapayInstructionsDialog(double amount) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'تعليمات الدفع عبر إنستاباي',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Cairo',
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'يرجى إتباع الخطوات التالية:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 16),
                _buildInstructionStep('1', 'افتح تطبيق البنك الخاص بك'),
                _buildInstructionStep('2', 'اختر خدمة إنستاباي'),
                _buildInstructionStep('3', 'أدخل رقم الحساب: ${widget.selectedAccount.accountNumber}'),
                _buildInstructionStep('4', 'أدخل المبلغ: ${amount.toStringAsFixed(2)} ج.م'),
                _buildInstructionStep('5', 'أكمل عملية التحويل'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: const Text(
                    'بعد إتمام التحويل، اضغط "تم الدفع" للانتقال لخطوة رفع إثبات الدفع',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 14,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'تم الدفع',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInstructionStep(String number, String instruction) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              instruction,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createPaymentRecord(double amount) async {
    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final paymentProvider = Provider.of<ElectronicPaymentProvider>(context, listen: false);

      if (supabaseProvider.user == null) {
        throw Exception('يرجى تسجيل الدخول أولاً');
      }

      // Create payment record without proof image first
      _createdPayment = await paymentProvider.createPayment(
        clientId: supabaseProvider.user!.id,
        paymentMethod: widget.paymentMethod,
        amount: amount,
        recipientAccountId: widget.selectedAccount.id,
        metadata: {
          'notes': _notesController.text.trim(),
          'account_number': widget.selectedAccount.accountNumber,
          'account_holder': widget.selectedAccount.accountHolderName,
          'workflow_step': 'payment_sent',
        },
      );

      AppLogger.info('✅ Created payment record: ${_createdPayment!.id}');
    } catch (e) {
      AppLogger.error('❌ Error creating payment record: $e');
      throw Exception('فشل في إنشاء سجل الدفعة: $e');
    }
  }

  Future<void> _moveToNextStep() async {
    setState(() {
      _currentStep++;
      _isLoading = false;
    });

    // Animate progress
    _progressAnimationController.forward();

    // Reset animation for next step
    await Future.delayed(const Duration(milliseconds: 800));
    _progressAnimationController.reset();
  }

  Widget _buildProofUploadStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Success message
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF10B981),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تم إرسال الدفعة بنجاح!',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      Text(
                        'رقم المعاملة: ${_createdPayment?.id.substring(0, 8)}...',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 14,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Instructions
          const Text(
            'رفع إثبات الدفع',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'يرجى رفع صورة واضحة لإثبات عملية التحويل',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 24),

          // Image preview or upload options
          if (_proofImage != null) ...[
            _buildImagePreview(),
            const SizedBox(height: 16),
          ],

          // Upload options
          _buildUploadOptions(),
          const SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentStep--;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'السابق',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _proofImage != null ? _handleProofSubmission : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'إرسال الإثبات',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF10B981)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Image.file(
              _proofImage!,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _proofImage = null;
                    });
                  },
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadOptions() {
    return Column(
      children: [
        // Camera option
        _buildUploadOption(
          icon: Icons.camera_alt,
          title: 'التقاط صورة',
          subtitle: 'استخدم الكاميرا لتصوير إثبات الدفع',
          onTap: () => _pickImage(ImageSource.camera),
        ),
        const SizedBox(height: 12),

        // Gallery option
        _buildUploadOption(
          icon: Icons.photo_library,
          title: 'اختيار من المعرض',
          subtitle: 'اختر صورة موجودة من معرض الصور',
          onTap: () => _pickImage(ImageSource.gallery),
        ),
      ],
    );
  }

  Widget _buildUploadOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[700]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF10B981),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
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
      _showErrorSnackBar('فشل في اختيار الصورة: $e');
    }
  }

  Future<void> _handleProofSubmission() async {
    if (_proofImage == null || _createdPayment == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final paymentProvider = Provider.of<ElectronicPaymentProvider>(context, listen: false);

      // Upload proof image
      final imageUrl = await _storageService.uploadPaymentProof(
        clientId: supabaseProvider.user!.id,
        paymentId: _createdPayment!.id,
        file: _proofImage!,
      );

      if (imageUrl == null) {
        throw Exception('فشل في رفع الصورة');
      }

      // Update payment with proof image
      _createdPayment = await paymentProvider.updatePaymentProof(
        paymentId: _createdPayment!.id,
        proofImageUrl: imageUrl,
      );

      // Move to confirmation step
      await _moveToNextStep();
    } catch (e) {
      setState(() {
        _error = 'فشل في رفع إثبات الدفع: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildConfirmationStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Success animation
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFF10B981),
                size: 80,
              ),
            ),
            const SizedBox(height: 32),

            // Success message
            const Text(
              'تم إرسال طلب الدفع بنجاح!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'سيتم مراجعة طلبك من قبل الإدارة وإشعارك بالنتيجة',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 32),

            // Payment details
            if (_createdPayment != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('رقم المعاملة', _createdPayment!.id.substring(0, 8)),
                    _buildDetailRow('المبلغ', '${_createdPayment!.amount.toStringAsFixed(2)} ج.م'),
                    _buildDetailRow('طريقة الدفع', widget.paymentMethod == ElectronicPaymentMethod.vodafoneCash ? 'فودافون كاش' : 'إنستاباي'),
                    _buildDetailRow('الحالة', 'قيد المراجعة'),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

            // Action buttons
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'العودة للرئيسية',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      // Navigate to payment history or status screen
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF10B981)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'عرض حالة الطلب',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 16,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontFamily: 'Cairo',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
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
