import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/waste_model.dart' as waste_models;
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/services/database_service.dart';
import 'package:smartbiztracker_new/widgets/custom_button.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';
import 'package:smartbiztracker_new/widgets/custom_text_field.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:smartbiztracker_new/widgets/common/material_wrapper.dart';

class WasteScreen extends StatefulWidget {
  const WasteScreen({super.key});

  @override
  State<WasteScreen> createState() => _WasteScreenState();
}

class _WasteScreenState extends State<WasteScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<waste_models.WasteModel>? _wasteData;
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchWasteData();
    });
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantityController.dispose();
    _detailsController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Fetch waste data
  Future<void> _fetchWasteData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Store auth provider before async operation
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user != null) {
        _databaseService.getAllWasteReports().listen((data) {
          // Filter waste by current worker
          final workerWaste =
              data.where((waste) => waste.workerId == user.id).toList();

          if (mounted) {
            setState(() {
              _wasteData = workerWaste;
              _isLoading = false;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Submit waste report
  Future<void> _submitWaste() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Store auth provider and ScaffoldMessenger before async operation
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final user = authProvider.user;

      if (user != null) {
        await _databaseService.addWasteReport(
          workerId: user.id,
          workerName: user.name,
          itemName: _itemNameController.text.trim(),
          quantity: int.parse(_quantityController.text.trim()),
          details: _detailsController.text.trim(),
        );

        if (mounted) {
          setState(() {
            _isSuccess = true;
          });

          // Reset form
          _itemNameController.clear();
          _quantityController.clear();
          _detailsController.clear();

          // Show success animation
          _animationController.forward();

          // Refresh data
          _fetchWasteData();

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
    return MaterialWrapper(
      child: GestureDetector(
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
                        'تم تسجيل الهالك بنجاح!',
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

            // Main content
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
                            Icons.delete_outline,
                            size: 48,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'تسجيل الهالك',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'يرجى تعبئة النموذج التالي لتسجيل الهالك من المنتجات',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Waste form
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

                        // Details field
                        const Text(
                          'التفاصيل:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          controller: _detailsController,
                          labelText: 'التفاصيل',
                          hintText: 'أدخل تفاصيل الهالك',
                          prefixIcon: Icons.description,
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى إدخال تفاصيل الهالك';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Submit button
                        CustomButton(
                          text: 'تسجيل الهالك',
                          onPressed: _submitWaste,
                          isLoading: _isLoading,
                          icon: Icons.send,
                          backgroundColor: Colors.red.shade700,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Waste history
                  if (_wasteData != null && _wasteData!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'سجل الهالك:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimationLimiter(
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _wasteData!.length,
                            itemBuilder: (context, index) {
                              final waste = _wasteData![index];
                              final dateFormat =
                                  DateFormat('yyyy/MM/dd - hh:mm a');

                              return AnimationConfiguration.staggeredList(
                                position: index,
                                duration: const Duration(milliseconds: 375),
                                child: SlideAnimation(
                                  verticalOffset: 50.0,
                                  child: FadeInAnimation(
                                    child: Card(
                                      elevation: 2,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Colors.red.shade700,
                                          child: Text(
                                            waste.quantity.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          waste.itemName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'التاريخ: ${dateFormat.format(waste.createdAt)}'),
                                            Text('التفاصيل: ${waste.details}'),
                                          ],
                                        ),
                                        isThreeLine: true,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Loading indicator
            if (_isLoading) const CustomLoader(),
          ],
        ),
      ),
    );
  }
}
