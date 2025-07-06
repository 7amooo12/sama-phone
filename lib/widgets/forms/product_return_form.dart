import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/widgets/custom_text_field.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart' as intl;

class ProductReturnForm extends StatefulWidget {

  const ProductReturnForm({
    super.key,
    required this.onSubmit,
    this.isLoading = false,
  });
  final Function(Map<String, dynamic>) onSubmit;
  final bool isLoading;

  @override
  State<ProductReturnForm> createState() => _ProductReturnFormState();
}

class _ProductReturnFormState extends State<ProductReturnForm> {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _orderNumberController = TextEditingController();
  final _reasonController = TextEditingController();
  final _phoneController = TextEditingController();
  final _datePurchasedController = TextEditingController();
  final List<XFile> _productImages = [];
  
  DateTime? _selectedDate;
  bool _hasReceipt = false;
  bool _termsAccepted = false;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _productNameController.dispose();
    _orderNumberController.dispose();
    _reasonController.dispose();
    _phoneController.dispose();
    _datePurchasedController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ar', 'SA'),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _datePurchasedController.text = intl.DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 720,
        imageQuality: 80,
      );
      
    if (pickedFile != null) {
        setState(() {
        _productImages.add(pickedFile);
        });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _productImages.removeAt(index);
    });
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      if (!_termsAccepted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى الموافقة على سياسة الإرجاع أولاً')),
        );
        return;
      }
      
      final returnData = {
        'product_name': _productNameController.text,
        'order_number': _orderNumberController.text,
        'date_purchased': _datePurchasedController.text,
        'reason': _reasonController.text,
        'phone': _phoneController.text,
        'has_receipt': _hasReceipt,
        'terms_accepted': _termsAccepted,
        'product_images': _productImages,
      };
      
      widget.onSubmit(returnData);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(StyleSystem.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            // Header - تحسين الاستايل
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF10B981),
                    const Color(0xFF10B981).withOpacity(0.8),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(StyleSystem.radiusLarge),
                  topRight: Radius.circular(StyleSystem.radiusLarge),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: const Row(
                children: [
                  Icon(
                    Icons.assignment_return_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'نموذج إرجاع المنتج',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
              ],
            ),
            ),
          
            // Form fields
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // اسم المنتج
                  CustomTextField(
                    controller: _productNameController,
                    labelText: 'اسم المنتج',
                    hintText: 'أدخل اسم المنتج المراد إرجاعه',
                    prefixIcon: Icons.shopping_bag_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى إدخال اسم المنتج';
                      }
                      return null;
                    },
                  ).animate().fadeIn(duration: 300.ms).moveX(begin: 20, end: 0),
                  
                  const SizedBox(height: 16),
                  
                  // رقم الطلب (اختياري)
                  CustomTextField(
                    controller: _orderNumberController,
                    labelText: 'رقم الطلب (اختياري)',
                    hintText: 'أدخل رقم الطلب الخاص بك إن وجد',
                    prefixIcon: Icons.confirmation_number_outlined,
                    validator: (value) {
                      // Order number is now optional - no validation required
                      return null;
                    },
                  ).animate().fadeIn(duration: 300.ms, delay: 100.ms).moveX(begin: 20, end: 0),
                  
                  const SizedBox(height: 16),
                  
                  // تاريخ الشراء
                  GestureDetector(
                    onTap: _selectDate,
                    child: AbsorbPointer(
                      child: CustomTextField(
                        controller: _datePurchasedController,
                        labelText: 'تاريخ الشراء',
                        hintText: 'حدد تاريخ شراء المنتج',
                        prefixIcon: Icons.calendar_today,
                        suffixIcon: Icons.arrow_drop_down,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى تحديد تاريخ الشراء';
                          }
                          return null;
                        },
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: 300.ms).moveX(begin: 20, end: 0),
                  
                  const SizedBox(height: 16),
                  
                  // سبب الإرجاع
                  CustomTextField(
                    controller: _reasonController,
                    labelText: 'سبب الإرجاع',
                    hintText: 'اشرح سبب إرجاع المنتج',
                    maxLines: 3,
                    prefixIcon: Icons.description_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى شرح سبب الإرجاع';
                      }
                      return null;
                    },
                  ).animate().fadeIn(duration: 300.ms, delay: 500.ms).moveX(begin: 20, end: 0),
                  
                  const SizedBox(height: 16),
                
                  // رقم الهاتف
                CustomTextField(
                    controller: _phoneController,
                    labelText: 'رقم الهاتف',
                    hintText: 'أدخل رقم هاتفك للتواصل',
                    prefixIcon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                        return 'يرجى إدخال رقم الهاتف';
                    }
                    return null;
                  },
                  ).animate().fadeIn(duration: 300.ms, delay: 600.ms).moveX(begin: 20, end: 0),

                  const SizedBox(height: 24),

                  // صور المنتج
                  Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                      const Text(
                        'صور المنتج',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(StyleSystem.radiusMedium),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                          border: Border.all(
                            color: const Color(0xFF10B981).withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _productImages.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _productImages.length) {
                              return Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: InkWell(
                  onTap: _pickImage,
                  child: Container(
                                    width: 100,
                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(StyleSystem.radiusSmall),
                                      border: Border.all(
                                        color: const Color(0xFF10B981).withOpacity(0.3),
                                        width: 1.5,
                                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                                          Icons.add_a_photo_rounded,
                                          color: Colors.white,
                        ),
                                        SizedBox(height: 4),
                        Text(
                                          'إضافة صورة',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'Cairo',
                                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                                ),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                          child: Stack(
                            children: [
                                  Container(
                                  width: 100,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(StyleSystem.radiusSmall),
                                      image: DecorationImage(
                                        image: FileImage(File(_productImages[index].path)),
                                  fit: BoxFit.cover,
                                      ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: InkWell(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 300.ms, delay: 700.ms),
                
                  const SizedBox(height: 24),
                
                  // الإيصال - تحسين الاستايل
                  SwitchListTile(
                    value: _hasReceipt,
                    onChanged: (value) {
                      setState(() {
                        _hasReceipt = value;
                      });
                    },
                    title: const Text(
                      'لدي إيصال الشراء',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Cairo',
                        fontSize: 16,
                      ),
                    ),
                    activeColor: const Color(0xFF10B981),
                    contentPadding: EdgeInsets.zero,
                  ).animate().fadeIn(duration: 300.ms, delay: 800.ms),

                      const SizedBox(height: 16),
                      
                  // الموافقة على الشروط - تحسين الاستايل
                      CheckboxListTile(
                        value: _termsAccepted,
                        onChanged: (value) {
                          setState(() {
                        _termsAccepted = value ?? false;
                          });
                        },
                    title: const Text(
                      'أوافق على سياسة الإرجاع والاستبدال',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Cairo',
                        fontSize: 14,
                      ),
                    ),
                    activeColor: const Color(0xFF10B981),
                    checkColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                  ).animate().fadeIn(duration: 300.ms, delay: 900.ms),

                  const SizedBox(height: 24),

                  // زر الإرسال - تحسين الاستايل
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF10B981),
                          const Color(0xFF10B981).withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(StyleSystem.radiusMedium),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: widget.isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(StyleSystem.radiusMedium),
                        ),
                      ),
                      child: widget.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'إرسال طلب الإرجاع',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              fontFamily: 'Cairo',
                            ),
                          ),
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: 1000.ms).moveY(begin: 10, end: 0),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
} 