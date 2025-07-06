import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/import_analysis_provider.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/widgets/common/custom_loader.dart';

/// شاشة تشخيص معالجة Excel - لتشخيص مشاكل معالجة البيانات
class DebugExcelScreen extends StatefulWidget {
  const DebugExcelScreen({super.key});

  @override
  State<DebugExcelScreen> createState() => _DebugExcelScreenState();
}

class _DebugExcelScreenState extends State<DebugExcelScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'تشخيص معالجة Excel',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AccountantThemeConfig.primaryGreen,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer<ImportAnalysisProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDebugCard(
                  'مسح البيانات',
                  'مسح جميع بيانات الاستيراد المحفوظة',
                  Icons.delete_sweep,
                  Colors.red,
                  () => _clearAllData(provider),
                ),
                const SizedBox(height: 16),
                _buildDebugCard(
                  'رفع ملف Excel',
                  'رفع ملف Excel جديد للتشخيص',
                  Icons.upload_file,
                  AccountantThemeConfig.primaryGreen,
                  () => _uploadFile(provider),
                ),
                const SizedBox(height: 16),
                _buildDebugCard(
                  'تشخيص معالجة Excel',
                  'اختبار معالجة Excel مع بيانات وهمية',
                  Icons.science,
                  Colors.purple,
                  () => _debugExcelProcessing(provider),
                ),
                const SizedBox(height: 16),
                if (provider.isLoading) ...[
                  const CustomLoader(message: 'جاري المعالجة...'),
                  const SizedBox(height: 16),
                ],
                if (provider.currentStatus.isNotEmpty) ...[
                  _buildStatusCard(provider),
                  const SizedBox(height: 16),
                ],
                if (provider.currentBatch != null) ...[
                  _buildBatchInfoCard(provider),
                  const SizedBox(height: 16),
                ],
                if (provider.currentItems.isNotEmpty) ...[
                  _buildItemsDebugCard(provider),
                  const SizedBox(height: 16),
                ],
                if (provider.smartSummary != null) ...[
                  _buildSummaryDebugCard(provider),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDebugCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(ImportAnalysisProvider provider) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'حالة المعالجة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(provider.currentStatus),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: provider.processingProgress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                AccountantThemeConfig.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchInfoCard(ImportAnalysisProvider provider) {
    final batch = provider.currentBatch!;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'معلومات الدفعة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('اسم الملف: ${batch.filename}'),
            Text('حجم الملف: ${(batch.fileSize / 1024).toStringAsFixed(1)} KB'),
            Text('إجمالي العناصر: ${batch.totalItems}'),
            Text('العناصر المعالجة: ${batch.processedItems}'),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsDebugCard(ImportAnalysisProvider provider) {
    final allItems = provider.currentItems;
    // عرض جميع العناصر بدون حدود
    final displayItems = allItems;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'العناصر المستخرجة (${allItems.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'جميع الصفوف: ${allItems.length}',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'عرض جميع العناصر المستخرجة:',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            ...displayItems.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'رقم الصنف: "${item.itemNumber}" | الكمية: ${item.totalQuantity} | كراتين: ${item.cartonCount} | قطع/كرتون: ${item.piecesPerCarton}',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            )),
            if (provider.currentItems.length > 20)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'إجمالي ${provider.currentItems.length} عنصر تم عرضهم جميعاً',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryDebugCard(ImportAnalysisProvider provider) {
    final summary = provider.smartSummary!;
    final totals = summary['totals'] as Map<String, dynamic>?;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'التقرير الذكي',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (totals != null) ...[
              Text('إجمالي الكراتين: ${totals['ctn']}'),
              Text('إجمالي الكمية: ${totals['QTY']}'),
              Text('إجمالي القطع/كرتون: ${totals['pc_ctn']}'),
            ],
            const SizedBox(height: 8),
            Text('العناصر المعالجة: ${summary['total_items_processed']}'),
            Text('العناصر الصحيحة: ${summary['valid_items']}'),
          ],
        ),
      ),
    );
  }

  Future<void> _clearAllData(ImportAnalysisProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد المسح'),
        content: const Text('هل تريد مسح جميع بيانات الاستيراد؟ هذا الإجراء لا يمكن التراجع عنه.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('مسح', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.clearAllImportData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم مسح جميع البيانات')),
        );
      }
    }
  }

  Future<void> _uploadFile(ImportAnalysisProvider provider) async {
    await provider.pickAndProcessFile();
  }

  Future<void> _debugExcelProcessing(ImportAnalysisProvider provider) async {
    await provider.debugExcelProcessing();
  }
}
