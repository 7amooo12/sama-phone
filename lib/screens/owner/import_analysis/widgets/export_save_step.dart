import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/providers/import_analysis_provider.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';

/// خطوة التصدير والحفظ - الخطوة الرابعة والأخيرة في سير عمل استيراد الحاوية
class ExportSaveStep extends StatefulWidget {
  final ImportAnalysisProvider provider;
  final VoidCallback onBack;
  final VoidCallback onComplete;

  const ExportSaveStep({
    super.key,
    required this.provider,
    required this.onBack,
    required this.onComplete,
  });

  @override
  State<ExportSaveStep> createState() => _ExportSaveStepState();
}

class _ExportSaveStepState extends State<ExportSaveStep> {
  bool _saveToDatabase = true;
  bool _exportPdf = false;
  bool _exportJson = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildSummarySection(),
                  const SizedBox(height: 24),
                  _buildExportOptions(),
                  const SizedBox(height: 24),
                  _buildSuccessMessage(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildActionButtons(),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3);
  }

  /// بناء رأس الخطوة
  Widget _buildStepHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.greenGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
          ),
          child: Icon(
            Icons.save,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الخطوة 4: تصدير وحفظ',
                style: AccountantThemeConfig.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'اختر خيارات التصدير والحفظ للبيانات المعالجة',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: AccountantThemeConfig.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// بناء قسم الملخص
  Widget _buildSummarySection() {
    final items = widget.provider.currentItems;
    final summary = widget.provider.smartSummary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.cardBackground1.withOpacity(0.3),
            AccountantThemeConfig.cardBackground2.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue.withOpacity(0.3)),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ملخص البيانات المعالجة',
            style: AccountantThemeConfig.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'إجمالي العناصر',
                  items.length.toString(),
                  Icons.inventory,
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'إجمالي الكمية',
                  summary?['totals']?['QTY']?.toString() ?? '0',
                  Icons.shopping_cart,
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'إجمالي الكراتين',
                  summary?['totals']?['ctn']?.toString() ?? '0',
                  Icons.inventory_2,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// بناء عنصر ملخص
  Widget _buildSummaryItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: AccountantThemeConfig.glowBorder(color.withOpacity(0.3)),
        boxShadow: AccountantThemeConfig.glowShadows(color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AccountantThemeConfig.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: AccountantThemeConfig.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// بناء خيارات التصدير
  Widget _buildExportOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'خيارات التصدير والحفظ',
          style: AccountantThemeConfig.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        
        // حفظ في قاعدة البيانات
        _buildModernCheckboxTile(
          value: _saveToDatabase,
          onChanged: (value) {
            setState(() {
              _saveToDatabase = value ?? true;
            });
          },
          title: 'حفظ في قاعدة البيانات',
          subtitle: 'حفظ البيانات للوصول إليها لاحقاً',
          icon: Icons.storage,
          color: AccountantThemeConfig.primaryGreen,
        ),

        const SizedBox(height: 12),

        // تصدير PDF
        _buildModernCheckboxTile(
          value: _exportPdf,
          onChanged: (value) {
            setState(() {
              _exportPdf = value ?? false;
            });
          },
          title: 'تصدير تقرير PDF',
          subtitle: 'إنشاء تقرير PDF مفصل',
          icon: Icons.picture_as_pdf,
          color: Colors.red,
        ),

        const SizedBox(height: 12),

        // تصدير JSON
        _buildModernCheckboxTile(
          value: _exportJson,
          onChanged: (value) {
            setState(() {
              _exportJson = value ?? false;
            });
          },
          title: 'تصدير بيانات JSON',
          subtitle: 'تصدير البيانات الخام بصيغة JSON',
          icon: Icons.code,
          color: AccountantThemeConfig.accentBlue,
        ),
      ],
    );
  }

  /// بناء مربع اختيار حديث
  Widget _buildModernCheckboxTile({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.cardBackground1.withOpacity(0.3),
            color.withOpacity(0.1),
          ],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(color.withOpacity(0.3)),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        title: Text(
          title,
          style: AccountantThemeConfig.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: AccountantThemeConfig.white70,
          ),
        ),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        activeColor: color,
        checkColor: Colors.white,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  /// بناء رسالة النجاح
  Widget _buildSuccessMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.primaryGreen.withOpacity(0.2),
            AccountantThemeConfig.primaryGreen.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen.withOpacity(0.5)),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.greenGradient,
              borderRadius: BorderRadius.circular(50),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'جاهز للحفظ والتصدير',
                  style: AccountantThemeConfig.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'تم معالجة البيانات بنجاح وهي جاهزة للحفظ والتصدير',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: AccountantThemeConfig.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// بناء أزرار الإجراءات
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.white70),
            ),
            child: OutlinedButton(
              onPressed: widget.onBack,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: BorderSide.none,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'السابق',
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.greenGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: ElevatedButton(
              onPressed: _performExportAndSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'إكمال',
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// تنفيذ التصدير والحفظ
  Future<void> _performExportAndSave() async {
    try {
      // عرض مؤشر التحميل
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('جاري الحفظ والتصدير...'),
            ],
          ),
        ),
      );

      // تنفيذ العمليات المطلوبة
      if (_saveToDatabase) {
        // حفظ الحاوية في قاعدة البيانات
        if (widget.provider.currentContainerItems.isNotEmpty) {
          await widget.provider.saveContainerBatch();
        }
      }

      if (_exportPdf) {
        // تصدير PDF
        // TODO: تنفيذ تصدير PDF
      }

      if (_exportJson) {
        // تصدير JSON
        // TODO: تنفيذ تصدير JSON
      }

      // إغلاق مؤشر التحميل
      Navigator.pop(context);

      // إكمال العملية
      widget.onComplete();
    } catch (e) {
      // إغلاق مؤشر التحميل
      Navigator.pop(context);

      // عرض رسالة خطأ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في الحفظ والتصدير: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
