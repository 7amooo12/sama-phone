import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/services/database_service.dart';
import 'package:smartbiztracker_new/widgets/custom_button.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';
import 'package:smartbiztracker_new/widgets/custom_text_field.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:smartbiztracker_new/models/return_model.dart';

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
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
    _reasonController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Submit return
  Future<void> _submitReturn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user != null) {
        final returnReport = ReturnModel(
          id: '', // Will be updated by the database service
          clientId: user.id,
          clientName: user.name,
          productId: '', // This would need a proper value in a real scenario
          productName: _itemNameController.text.trim(),
          quantity: int.parse(_quantityController.text.trim()),
          reason: _reasonController.text.trim(),
          status: ReturnStatus.PENDING,
          returnDate: DateTime.now(),
          refundAmount:
              0.0, // This would need a proper value in a real scenario
          isInspected: false,
          isRefundable: true,
          isResaleable: true,
        );

        await _databaseService.addReturnReport(returnReport);

        if (mounted) {
          setState(() {
            _isSuccess = true;
          });

          // Reset form
          _itemNameController.clear();
          _quantityController.clear();
          _reasonController.clear();

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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                      'تم إرسال المرتجع بنجاح!',
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
                          Icons.assignment_return,
                          size: 48,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'نموذج المرتجع',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'يرجى تعبئة النموذج التالي لإرسال طلب مرتجع',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Return form
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

                      // Reason field
                      const Text(
                        'سبب الإرجاع:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _reasonController,
                        labelText: 'سبب الإرجاع',
                        hintText: 'أدخل سبب الإرجاع',
                        prefixIcon: Icons.description,
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال سبب الإرجاع';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Submit button
                      CustomButton(
                        text: 'إرسال المرتجع',
                        onPressed: _submitReturn,
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
