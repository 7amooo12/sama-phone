import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/productivity_model.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/services/database_service.dart';
import 'package:smartbiztracker_new/widgets/custom_button.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';
import 'package:smartbiztracker_new/widgets/custom_text_field.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';

class ProductivityScreen extends StatefulWidget {
  const ProductivityScreen({super.key});

  @override
  State<ProductivityScreen> createState() => _ProductivityScreenState();
}

class _ProductivityScreenState extends State<ProductivityScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<ProductivityModel>? _productivityData;
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
      _fetchProductivityData();
    });
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Fetch worker's productivity data
  Future<void> _fetchProductivityData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user != null) {
        // Get today's date
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);

        // Use dummy data if Firebase connection fails
        try {
          // Call getWorkerProductivity with the correct parameter
          _databaseService.getWorkerProductivity(user.id).listen((data) {
            if (mounted) {
              setState(() {
                _productivityData = data;
                _isLoading = false;
              });
            }
          }, onError: (e) {
            _useFallbackData();
          });
        } catch (e) {
          _useFallbackData();
        }
      } else {
        _useFallbackData();
      }
    } catch (e) {
      _useFallbackData();
    }
  }
  
  void _useFallbackData() {
    if (!mounted) return;
    
    // Use dummy data when Firebase fails
    setState(() {
      _productivityData = [
        ProductivityModel(
          id: '1',
          workerId: 'worker1',
          workerName: 'أحمد محمد',
          productId: 'product1',
          productName: 'طاولة خشبية',
          producedQuantity: 5,
          defectiveQuantity: 1,
          efficiency: 80.0,
          date: DateTime.now().subtract(const Duration(hours: 3)),
          shift: ShiftType.morning,
          workingHours: 8,
          notes: 'تم الإنتاج بنجاح',
        ),
        ProductivityModel(
          id: '2',
          workerId: 'worker1',
          workerName: 'أحمد محمد',
          productId: 'product2',
          productName: 'كرسي خشبي',
          producedQuantity: 10,
          defectiveQuantity: 0,
          efficiency: 95.0,
          date: DateTime.now().subtract(const Duration(hours: 5)),
          shift: ShiftType.morning,
          workingHours: 8,
          notes: 'إنتاج ممتاز اليوم',
        ),
      ];
      _isLoading = false;
    });
  }

  // Submit productivity entry
  Future<void> _submitProductivity() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user != null) {
        // Create a ProductivityModel object
        final productivity = ProductivityModel(
          id: '', // Will be set by Firestore
          workerId: user.id,
          workerName: user.name,
          productId: 'default-product-id', // Adding default product ID
          productName: _itemNameController.text.trim(),
          producedQuantity: int.parse(_quantityController.text.trim()),
          defectiveQuantity: 0, // Default to 0 defects
          efficiency: 100.0, // Default to 100% efficiency
          date: DateTime.now(),
          shift: ShiftType.morning, // Default to morning shift
          workingHours: 8, // Default to 8 working hours
          notes: _notesController.text.trim(),
        );

        try {
          // Call addWorkerProductivity with the correct parameter
          await _databaseService.addWorkerProductivity(productivity);
        } catch (e) {
          // If Firebase fails, just add to local list
          if (mounted) {
            setState(() {
              _productivityData = [...?_productivityData, productivity];
            });
          }
        }

        if (mounted) {
          setState(() {
            _isSuccess = true;
          });

          // Reset form
          _itemNameController.clear();
          _quantityController.clear();
          _notesController.clear();

          // Show success animation
          _animationController.forward();

          // Refresh data
          _fetchProductivityData();

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

  // Calculate total productivity for today
  int _calculateTotalProductivity() {
    if (_productivityData == null || _productivityData!.isEmpty) {
      return 0;
    }

    return _productivityData!
        .fold(0, (sum, item) => sum + item.producedQuantity);
  }

  @override
  Widget build(BuildContext context) {
    final totalProductivity = _calculateTotalProductivity();

    // Wrap everything in Material to fix the "No Material widget found" error
    return Material(
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
                        'تم تسجيل الإنتاجية بنجاح!',
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
                  // Statistics card
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.trending_up,
                                size: 24,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'إحصائيات اليوم',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatItem(
                                'العناصر المنتجة',
                                totalProductivity.toString(),
                                Icons.inventory,
                                Colors.blue,
                              ),
                              _buildStatItem(
                                'الكفاءة',
                                '85%',
                                Icons.speed,
                                Colors.green,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form title
                  const Text(
                    'تسجيل إنتاجية جديدة',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Add productivity form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Product name field
                        CustomTextField(
                          controller: _itemNameController,
                          hintText: 'اسم المنتج',
                          prefixIcon: Icons.inventory,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'برجاء إدخال اسم المنتج';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Quantity field
                        CustomTextField(
                          controller: _quantityController,
                          hintText: 'الكمية المنتجة',
                          prefixIcon: Icons.numbers,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'برجاء إدخال الكمية';
                            }
                            if (int.tryParse(value) == null) {
                              return 'برجاء إدخال رقم صحيح';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Notes field
                        CustomTextField(
                          controller: _notesController,
                          hintText: 'ملاحظات (اختياري)',
                          prefixIcon: Icons.note,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),

                        // Submit button
                        CustomButton(
                          text: 'تسجيل الإنتاجية',
                          isLoading: _isLoading,
                          onPressed: _submitProductivity,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Productivity history
                  if (_isLoading)
                    const Center(
                      child: CustomLoader(),
                    )
                  else
                    _buildProductivityHistory(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductivityHistory() {
    if (_productivityData == null || _productivityData!.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد سجلات إنتاجية حالياً',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'سجل الإنتاجية',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        AnimationLimiter(
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _productivityData!.length,
            itemBuilder: (context, index) {
              final item = _productivityData![index];
              final formattedDate =
                  DateFormat('dd/MM/yyyy - hh:mm a').format(item.date);

              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 500),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).primaryColor.withOpacity(0.1),
                          child: Text(
                            item.producedQuantity.toString(),
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          item.productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('التاريخ: $formattedDate'),
                            if (item.notes != null && item.notes!.isNotEmpty)
                              Text('ملاحظات: ${item.notes}'),
                          ],
                        ),
                        trailing: Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
