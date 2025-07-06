import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product_model.dart';
import '../../utils/accountant_theme_config.dart';

class QuantitySelectionDialog extends StatefulWidget {
  final ProductModel product;
  final Function(int quantity) onQuantitySelected;

  const QuantitySelectionDialog({
    super.key,
    required this.product,
    required this.onQuantitySelected,
  });

  @override
  State<QuantitySelectionDialog> createState() => _QuantitySelectionDialogState();
}

class _QuantitySelectionDialogState extends State<QuantitySelectionDialog> {
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final FocusNode _quantityFocusNode = FocusNode();
  int _selectedQuantity = 1;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _quantityController.addListener(_onQuantityChanged);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _quantityFocusNode.dispose();
    super.dispose();
  }

  void _onQuantityChanged() {
    final text = _quantityController.text;
    if (text.isEmpty) {
      setState(() {
        _selectedQuantity = 0;
        _errorMessage = 'يرجى إدخال الكمية';
      });
      return;
    }

    final quantity = int.tryParse(text);
    if (quantity == null || quantity <= 0) {
      setState(() {
        _selectedQuantity = 0;
        _errorMessage = 'يرجى إدخال كمية صحيحة';
      });
      return;
    }

    if (quantity > widget.product.quantity) {
      setState(() {
        _selectedQuantity = quantity;
        _errorMessage = 'الكمية المطلوبة تتجاوز المتاح (${widget.product.quantity} قطعة)';
      });
      return;
    }

    setState(() {
      _selectedQuantity = quantity;
      _errorMessage = null;
    });
  }

  void _incrementQuantity() {
    if (_selectedQuantity < widget.product.quantity) {
      setState(() {
        _selectedQuantity++;
        _quantityController.text = _selectedQuantity.toString();
      });
    }
  }

  void _decrementQuantity() {
    if (_selectedQuantity > 1) {
      setState(() {
        _selectedQuantity--;
        _quantityController.text = _selectedQuantity.toString();
      });
    }
  }

  void _addAllQuantity() {
    setState(() {
      _selectedQuantity = widget.product.quantity;
      _quantityController.text = _selectedQuantity.toString();
    });
  }

  void _confirmSelection() {
    if (_errorMessage == null && _selectedQuantity > 0) {
      widget.onQuantitySelected(_selectedQuantity);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAvailable = widget.product.quantity > 0;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: AccountantThemeConfig.primaryCardDecoration,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AccountantThemeConfig.greenGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.shopping_cart_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إضافة للسلة',
                          style: AccountantThemeConfig.headlineSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.product.name,
                          style: AccountantThemeConfig.bodyMedium.copyWith(
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Stock Information
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: isAvailable 
                      ? AccountantThemeConfig.greenGradient
                      : AccountantThemeConfig.redGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAvailable ? Icons.inventory_2 : Icons.warning,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isAvailable 
                          ? 'متوفر: ${widget.product.quantity} قطعة'
                          : 'غير متوفر',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              if (!isAvailable) ...[
                const SizedBox(height: 16),
                Text(
                  'عذراً، هذا المنتج غير متوفر حالياً',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: AccountantThemeConfig.dangerRed,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                const SizedBox(height: 24),

                // Quantity Input Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الكمية المطلوبة',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quantity Controls
                    Row(
                      children: [
                        // Decrement Button
                        Container(
                          decoration: BoxDecoration(
                            gradient: _selectedQuantity > 1 
                                ? AccountantThemeConfig.blueGradient
                                : AccountantThemeConfig.cardGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            onPressed: _selectedQuantity > 1 ? _decrementQuantity : null,
                            icon: const Icon(Icons.remove, color: Colors.white),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Quantity Input Field
                        Expanded(
                          child: TextFormField(
                            controller: _quantityController,
                            focusNode: _quantityFocusNode,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textAlign: TextAlign.center,
                            style: AccountantThemeConfig.bodyLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AccountantThemeConfig.cardBackground1,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AccountantThemeConfig.primaryGreen,
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AccountantThemeConfig.dangerRed,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Increment Button
                        Container(
                          decoration: BoxDecoration(
                            gradient: _selectedQuantity < widget.product.quantity 
                                ? AccountantThemeConfig.greenGradient
                                : AccountantThemeConfig.cardGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            onPressed: _selectedQuantity < widget.product.quantity 
                                ? _incrementQuantity 
                                : null,
                            icon: const Icon(Icons.add, color: Colors.white),
                          ),
                        ),
                      ],
                    ),

                    // Error Message
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: AccountantThemeConfig.dangerRed,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 24),

                // Add All Quantity Button
                if (widget.product.quantity > 1)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addAllQuantity,
                      icon: const Icon(Icons.select_all),
                      label: Text('إضافة كل الكمية (${widget.product.quantity} قطعة)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AccountantThemeConfig.primaryGreen,
                        side: BorderSide(color: AccountantThemeConfig.primaryGreen),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white30),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: _errorMessage == null && _selectedQuantity > 0
                              ? AccountantThemeConfig.greenGradient
                              : AccountantThemeConfig.cardGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _errorMessage == null && _selectedQuantity > 0 
                              ? _confirmSelection 
                              : null,
                          icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                          label: const Text(
                            'إضافة للسلة',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
