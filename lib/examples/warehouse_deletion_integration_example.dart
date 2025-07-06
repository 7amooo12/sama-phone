import 'package:flutter/material.dart';
import '../models/warehouse_model.dart';
import '../widgets/warehouse/warehouse_deletion_dialog.dart';
import '../utils/warehouse_deletion_test.dart';
import '../utils/app_logger.dart';

/// مثال على كيفية دمج حوار حذف المخزن المحسن
class WarehouseDeletionIntegrationExample extends StatefulWidget {
  const WarehouseDeletionIntegrationExample({super.key});

  @override
  State<WarehouseDeletionIntegrationExample> createState() => _WarehouseDeletionIntegrationExampleState();
}

class _WarehouseDeletionIntegrationExampleState extends State<WarehouseDeletionIntegrationExample> {
  bool _isTestingCompilation = false;
  bool _compilationTestPassed = false;

  @override
  void initState() {
    super.initState();
    _runCompilationTest();
  }

  Future<void> _runCompilationTest() async {
    setState(() {
      _isTestingCompilation = true;
    });

    try {
      final result = await testCompilation();
      setState(() {
        _compilationTestPassed = result;
      });
    } catch (e) {
      AppLogger.error('خطأ في اختبار التجميع: $e');
      setState(() {
        _compilationTestPassed = false;
      });
    } finally {
      setState(() {
        _isTestingCompilation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مثال دمج حذف المخزن'),
        backgroundColor: Colors.blue.shade800,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // حالة اختبار التجميع
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'حالة اختبار التجميع',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (_isTestingCompilation) ...[
                      const Row(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 16),
                          Text('جاري اختبار التجميع...'),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Icon(
                            _compilationTestPassed ? Icons.check_circle : Icons.error,
                            color: _compilationTestPassed ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _compilationTestPassed 
                                ? 'اختبار التجميع نجح - جميع الأنواع متاحة'
                                : 'فشل في اختبار التجميع',
                            style: TextStyle(
                              color: _compilationTestPassed ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // مثال على استخدام حوار الحذف
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'مثال على استخدام حوار حذف المخزن',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    // زر لاختبار المخزن المشكل
                    ElevatedButton.icon(
                      onPressed: _compilationTestPassed ? _showDeletionDialogForProblematicWarehouse : null,
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('اختبار حذف المخزن المشكل'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // زر لاختبار مخزن تجريبي
                    ElevatedButton.icon(
                      onPressed: _compilationTestPassed ? _showDeletionDialogForTestWarehouse : null,
                      icon: const Icon(Icons.science),
                      label: const Text('اختبار مخزن تجريبي'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    const Text(
                      'ملاحظة: هذا مثال توضيحي لكيفية استخدام حوار حذف المخزن المحسن. في التطبيق الحقيقي، ستحصل على بيانات المخزن من قاعدة البيانات.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // معلومات التنفيذ
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'كيفية التنفيذ في التطبيق الحقيقي',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. استبدل حوار التأكيد القديم بـ WarehouseDeletionDialog\n'
                      '2. مرر كائن WarehouseModel للحوار\n'
                      '3. الحوار سيحلل العوامل المانعة تلقائياً\n'
                      '4. المستخدم يمكنه إدارة الطلبات والمخزون\n'
                      '5. الحذف يتم فقط بعد حل جميع المشاكل',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    
                    // زر لتشغيل الاختبار الشامل
                    ElevatedButton.icon(
                      onPressed: _compilationTestPassed ? _runComprehensiveTest : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('تشغيل الاختبار الشامل'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeletionDialogForProblematicWarehouse() {
    // إنشاء مخزن تجريبي بالمعرف المشكل
    final problematicWarehouse = WarehouseModel(
      id: '77510647-5f3b-49e9-8a8a-bcd8e77eaecd',
      name: 'المخزن المشكل (2 طلب نشط)',
      address: 'عنوان تجريبي',
      description: 'هذا هو المخزن الذي يحتوي على طلبين نشطين يمنعان الحذف',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now(),
    );

    showDialog(
      context: context,
      builder: (context) => WarehouseDeletionDialog(
        warehouse: problematicWarehouse,
      ),
    );
  }

  void _showDeletionDialogForTestWarehouse() {
    // إنشاء مخزن تجريبي
    final testWarehouse = WarehouseModel(
      id: 'test-warehouse-id',
      name: 'مخزن تجريبي',
      address: 'عنوان تجريبي',
      description: 'مخزن للاختبار',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      updatedAt: DateTime.now(),
    );

    showDialog(
      context: context,
      builder: (context) => WarehouseDeletionDialog(
        warehouse: testWarehouse,
      ),
    );
  }

  Future<void> _runComprehensiveTest() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جاري تشغيل الاختبار الشامل...'),
          backgroundColor: Colors.blue,
        ),
      );

      await testWarehouseDeletionFunctionality();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إكمال الاختبار الشامل بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في الاختبار الشامل: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// دالة مساعدة لإظهار حوار حذف المخزن
void showWarehouseDeletionDialog(BuildContext context, WarehouseModel warehouse) {
  showDialog(
    context: context,
    builder: (context) => WarehouseDeletionDialog(
      warehouse: warehouse,
    ),
  );
}

/// مثال على كيفية استبدال حوار التأكيد القديم
class OldVsNewDeletionExample {
  // الطريقة القديمة (لا تستخدم)
  static void showOldDeletionDialog(BuildContext context, WarehouseModel warehouse) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المخزن'),
        content: Text('هل أنت متأكد من حذف المخزن "${warehouse.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // محاولة الحذف مباشرة - قد تفشل بسبب القيود
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // الطريقة الجديدة (استخدم هذه)
  static void showNewDeletionDialog(BuildContext context, WarehouseModel warehouse) {
    showDialog(
      context: context,
      builder: (context) => WarehouseDeletionDialog(
        warehouse: warehouse,
      ),
    );
  }
}
