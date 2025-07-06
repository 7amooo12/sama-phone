import 'package:flutter/material.dart';
import '../../models/client_voucher_model.dart';

/// Widget for displaying cart summary with voucher discounts
class CartSummaryWidget extends StatelessWidget {

  const CartSummaryWidget({
    super.key,
    required this.subtotal,
    required this.discountAmount,
    required this.finalTotal,
    this.appliedVoucher,
    this.onRemoveVoucher,
    this.isProcessing = false,
  });
  final double subtotal;
  final double discountAmount;
  final double finalTotal;
  final ClientVoucherModel? appliedVoucher;
  final VoidCallback? onRemoveVoucher;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ملخص الطلب',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Subtotal
            _buildSummaryRow(
              'المجموع الفرعي',
              '${subtotal.toStringAsFixed(2)} ريال',
              isSubtotal: true,
            ),
            
            // Applied Voucher Section
            if (appliedVoucher != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_offer, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'قسيمة مطبقة: ${appliedVoucher!.voucher?.name ?? 'قسيمة'}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (onRemoveVoucher != null && !isProcessing)
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red, size: 20),
                            onPressed: onRemoveVoucher,
                            tooltip: 'إزالة القسيمة',
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'الخصم',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '-${discountAmount.toStringAsFixed(2)} ريال',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            // Discount row (when voucher is applied)
            if (discountAmount > 0 && appliedVoucher == null)
              _buildSummaryRow(
                'الخصم',
                '-${discountAmount.toStringAsFixed(2)} ريال',
                isDiscount: true,
              ),
            
            const Divider(thickness: 2),
            
            // Final Total
            _buildSummaryRow(
              'المجموع النهائي',
              '${finalTotal.toStringAsFixed(2)} ريال',
              isFinal: true,
            ),
            
            // Savings Highlight
            if (discountAmount > 0) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.withOpacity(0.1), Colors.green.withOpacity(0.2)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.savings, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '🎉 تهانينا! لقد وفرت',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${discountAmount.toStringAsFixed(2)} ريال',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Processing indicator
            if (isProcessing) ...[
              const SizedBox(height: 16),
              const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('جاري المعالجة...'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isSubtotal = false,
    bool isDiscount = false,
    bool isFinal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isFinal ? 16 : 14,
              fontWeight: isFinal ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? Colors.green : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isFinal ? 18 : 14,
              fontWeight: isFinal ? FontWeight.bold : FontWeight.w500,
              color: isDiscount ? Colors.green : (isFinal ? Colors.black : null),
            ),
          ),
        ],
      ),
    );
  }
}

/// Extension to provide formatted currency display
extension CurrencyFormat on double {
  String get formattedCurrency => '${toStringAsFixed(2)} جنيه';
}

/// Helper class for cart calculations
class CartCalculations {

  CartCalculations({
    required this.subtotal,
    required this.discountAmount,
  }) : finalTotal = subtotal - discountAmount,
       savingsPercentage = subtotal > 0 ? (discountAmount / subtotal) * 100 : 0;
  final double subtotal;
  final double discountAmount;
  final double finalTotal;
  final double savingsPercentage;

  bool get hasDiscount => discountAmount > 0;
  
  String get formattedSavingsPercentage => '${savingsPercentage.toStringAsFixed(1)}%';
  
  Map<String, dynamic> toJson() => {
    'subtotal': subtotal,
    'discount_amount': discountAmount,
    'final_total': finalTotal,
    'savings_percentage': savingsPercentage,
  };
}

/// Widget for displaying detailed breakdown
class DetailedCartSummary extends StatelessWidget {

  const DetailedCartSummary({
    super.key,
    required this.calculations,
    this.appliedVoucher,
    this.applicableItems = const [],
    this.onRemoveVoucher,
  });
  final CartCalculations calculations;
  final ClientVoucherModel? appliedVoucher;
  final List<Map<String, dynamic>> applicableItems;
  final VoidCallback? onRemoveVoucher;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: ExpansionTile(
        title: const Text('تفاصيل الحساب'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Items breakdown
                if (applicableItems.isNotEmpty) ...[
                  const Text(
                    'المنتجات المشمولة بالخصم:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...applicableItems.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(item['name'] ?? 'منتج')),
                        Text('${item['discount']?.toStringAsFixed(2) ?? '0.00'} ريال'),
                      ],
                    ),
                  )),
                  const Divider(),
                ],
                
                // Voucher details
                if (appliedVoucher?.voucher != null) ...[
                  const Text(
                    'تفاصيل القسيمة:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow('الاسم', appliedVoucher!.voucher!.name),
                  _buildDetailRow('النوع', _getVoucherTypeText(appliedVoucher!.voucher!)),
                  _buildDetailRow('الخصم', '${calculations.discountAmount.toStringAsFixed(2)} ريال'),
                  _buildDetailRow('نسبة التوفير', calculations.formattedSavingsPercentage),
                  const Divider(),
                ],
                
                // Final summary
                CartSummaryWidget(
                  subtotal: calculations.subtotal,
                  discountAmount: calculations.discountAmount,
                  finalTotal: calculations.finalTotal,
                  appliedVoucher: appliedVoucher,
                  onRemoveVoucher: onRemoveVoucher,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _getVoucherTypeText(dynamic voucher) {
    // This would need to be implemented based on your voucher model
    return 'خصم'; // Placeholder
  }
}
