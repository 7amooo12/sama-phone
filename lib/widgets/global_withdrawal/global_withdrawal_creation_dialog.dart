import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/global_withdrawal_models.dart';
import '../../providers/global_withdrawal_provider.dart';
import '../../config/accountant_theme_config.dart';
import '../../utils/app_logger.dart';

/// حوار إنشاء طلب سحب عالمي جديد
class GlobalWithdrawalCreationDialog extends StatefulWidget {
  const GlobalWithdrawalCreationDialog({super.key});

  @override
  State<GlobalWithdrawalCreationDialog> createState() => _GlobalWithdrawalCreationDialogState();
}

class _GlobalWithdrawalCreationDialogState extends State<GlobalWithdrawalCreationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final List<WithdrawalRequestItem> _items = [];
  String _selectedStrategy = 'balanced';
  bool _isCreating = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AccountantThemeConfig.cardShadow,
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildContent(),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.add_circle,
              color: AccountantThemeConfig.primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إنشاء طلب سحب عالمي',
                  style: AccountantThemeConfig.headingStyle.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'سيتم البحث تلقائياً في جميع المخازن',
                  style: AccountantThemeConfig.bodyStyle.copyWith(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // سبب الطلب
            Text(
              'سبب الطلب',
              style: AccountantThemeConfig.bodyStyle.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _reasonController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'أدخل سبب طلب السحب...',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال سبب الطلب';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 20),
            
            // استراتيجية التخصيص
            Text(
              'استراتيجية التخصيص',
              style: AccountantThemeConfig.bodyStyle.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<String>(
                value: _selectedStrategy,
                isExpanded: true,
                dropdownColor: const Color(0xFF1A1A2E),
                style: const TextStyle(color: Colors.white),
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                items: const [
                  DropdownMenuItem(
                    value: 'balanced',
                    child: Text('توزيع متوازن'),
                  ),
                  DropdownMenuItem(
                    value: 'priority_based',
                    child: Text('حسب أولوية المخزن'),
                  ),
                  DropdownMenuItem(
                    value: 'highest_stock',
                    child: Text('أعلى مخزون أولاً'),
                  ),
                  DropdownMenuItem(
                    value: 'lowest_stock',
                    child: Text('أقل مخزون أولاً'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedStrategy = value;
                    });
                  }
                },
              ),
            ),
            
            const SizedBox(height: 20),
            
            // عناصر الطلب
            Row(
              children: [
                Text(
                  'عناصر الطلب (${_items.length})',
                  style: AccountantThemeConfig.bodyStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('إضافة منتج'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AccountantThemeConfig.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(100, 36),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // قائمة العناصر
            if (_items.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: Colors.white54,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'لا توجد منتجات مضافة',
                        style: AccountantThemeConfig.bodyStyle.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'اضغط "إضافة منتج" لبدء إضافة المنتجات',
                        style: AccountantThemeConfig.bodyStyle.copyWith(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ...List.generate(_items.length, (index) => _buildItemCard(index)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(
            Icons.inventory,
            color: AccountantThemeConfig.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName ?? item.productId,
                  style: AccountantThemeConfig.bodyStyle.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'الكمية: ${item.quantity}',
                  style: AccountantThemeConfig.bodyStyle.copyWith(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _removeItem(index),
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('إلغاء'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isCreating || _items.isEmpty ? null : _createRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isCreating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 8),
                        Text('جاري الإنشاء...'),
                      ],
                    )
                  : const Text('إنشاء الطلب'),
            ),
          ),
        ],
      ),
    );
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (context) => _ItemAdditionDialog(
        onAdd: (item) {
          setState(() {
            _items.add(item);
          });
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _createRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إضافة منتج واحد على الأقل'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final provider = context.read<GlobalWithdrawalProvider>();
      final request = await provider.createGlobalRequest(
        reason: _reasonController.text.trim(),
        items: _items,
        requestedBy: 'current_user', // يجب الحصول على المستخدم الحالي
        allocationStrategy: _selectedStrategy,
      );

      if (request != null && mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء طلب السحب العالمي بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('خطأ في إنشاء طلب السحب: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إنشاء الطلب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }
}

/// حوار إضافة منتج
class _ItemAdditionDialog extends StatefulWidget {
  final Function(WithdrawalRequestItem) onAdd;

  const _ItemAdditionDialog({required this.onAdd});

  @override
  State<_ItemAdditionDialog> createState() => _ItemAdditionDialogState();
}

class _ItemAdditionDialogState extends State<_ItemAdditionDialog> {
  final _productIdController = TextEditingController();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _productIdController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      title: const Text('إضافة منتج', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _productIdController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'معرف المنتج',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white54),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'الكمية',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white54),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'ملاحظات (اختياري)',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white54),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: _addItem,
          style: ElevatedButton.styleFrom(
            backgroundColor: AccountantThemeConfig.primaryColor,
          ),
          child: const Text('إضافة'),
        ),
      ],
    );
  }

  void _addItem() {
    final productId = _productIdController.text.trim();
    final quantityText = _quantityController.text.trim();

    if (productId.isEmpty || quantityText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى ملء جميع الحقول المطلوبة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final quantity = int.tryParse(quantityText);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال كمية صحيحة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final item = WithdrawalRequestItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      requestId: '',
      productId: productId,
      productName: productId, // سيتم تحديثه لاحقاً
      quantity: quantity,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    widget.onAdd(item);
    Navigator.of(context).pop();
  }
}
