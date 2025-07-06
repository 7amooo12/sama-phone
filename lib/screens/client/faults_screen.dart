import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/services/database_service.dart';
import 'package:smartbiztracker_new/widgets/custom_button.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';
import 'package:smartbiztracker_new/widgets/custom_text_field.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:smartbiztracker_new/models/fault_model.dart';

class FaultsScreen extends StatefulWidget {
  const FaultsScreen({super.key});

  @override
  State<FaultsScreen> createState() => _FaultsScreenState();
}

class _FaultsScreenState extends State<FaultsScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _faultTypeController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSuccess = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantityController.dispose();
    _faultTypeController.dispose();
    _detailsController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Submit fault report
  Future<void> _submitFault() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user != null) {
        final fault = FaultModel(
          id: '', // Will be updated by the database service
          title: _itemNameController.text.trim(),
          description: _detailsController.text.trim(),
          reporterId: user.id,
          reportedBy: user.name, // Add the required reportedBy parameter
          assignedTo: '', // Empty initially, will be assigned by admin
          createdAt: DateTime.now(),
          status: FaultStatus.newStatus,
          category: _faultTypeController.text.trim(),
          priority: FaultPriority.medium,
          attachments: [], // Add required attachments parameter
          isResolved: false, // Add required isResolved parameter
          location: '', // Add required location parameter
          metadata: {
            'clientName': user.name,
            'quantity': int.parse(_quantityController.text.trim()),
          },
        );

        await _databaseService.addFaultReport(fault);

        setState(() {
          _isSuccess = true;
        });

        // Reset form
        _itemNameController.clear();
        _quantityController.clear();
        _faultTypeController.clear();
        _detailsController.clear();

        // Show success animation
        _animationController.forward();

        // Reset animation after delay
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _isSuccess = false;
            });
            _animationController.reset();
          }
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Stack(
        children: [
          // Success animation
          if (_isSuccess)
            Container(
              color: Colors.black45,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Success animation
                    SizedBox(
                      height: 200,
                      width: 200,
                      child: Lottie.network(
                        'https://assets3.lottiefiles.com/packages/lf20_s9lvjzlf.json',
                        controller: _animationController,
                        repeat: false,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Success message
                    const Text(
                      'تم إرسال بلاغ العطل بنجاح!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Form
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.build,
                          size: 48,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'نموذج الإبلاغ عن عطل',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'يرجى تعبئة النموذج التالي للإبلاغ عن عطل في أحد المنتجات',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Fault form
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Item name field
                      const Text(
                        'اسم المنتج:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _itemNameController,
                        labelText: 'اسم المنتج',
                        hintText: 'أدخل اسم المنتج',
                        prefixIcon: Icons.shopping_bag,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال اسم المنتج';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Quantity field
                      const Text(
                        'الكمية:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _quantityController,
                        labelText: 'الكمية',
                        hintText: 'أدخل الكمية',
                        prefixIcon: Icons.numbers,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال الكمية';
                          }

                          final qty = int.tryParse(value);
                          if (qty == null || qty <= 0) {
                            return 'يرجى إدخال كمية صحيحة';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Fault type field
                      const Text(
                        'نوع العطل:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _faultTypeController,
                        labelText: 'نوع العطل',
                        hintText: 'أدخل نوع العطل',
                        prefixIcon: Icons.error_outline,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال نوع العطل';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Details field
                      const Text(
                        'تفاصيل إضافية:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _detailsController,
                        labelText: 'تفاصيل إضافية',
                        hintText: 'أدخل تفاصيل إضافية عن العطل',
                        prefixIcon: Icons.description,
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال تفاصيل العطل';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Submit button
                      CustomButton(
                        text: 'إرسال بلاغ العطل',
                        onPressed: _submitFault,
                        isLoading: _isLoading,
                        icon: Icons.send,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Loading indicator
          if (_isLoading) const CustomLoader(),
        ],
      ),
    );
  }
}
