import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/import_analysis_provider.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/widgets/common/custom_loader.dart';

/// قسم رفع الملفات مع مؤشر التقدم والإلغاء
/// يدعم السحب والإفلات مع التحقق من صحة الملفات
class FileUploadSection extends StatefulWidget {
  const FileUploadSection({super.key});

  @override
  State<FileUploadSection> createState() => _FileUploadSectionState();
}

class _FileUploadSectionState extends State<FileUploadSection>
    with TickerProviderStateMixin {
  late AnimationController _uploadAnimationController;
  late AnimationController _progressAnimationController;
  
  bool _isDragOver = false;

  @override
  void initState() {
    super.initState();
    
    _uploadAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _uploadAnimationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _uploadAnimationController.dispose();
    _progressAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ImportAnalysisProvider>(
      builder: (context, provider, child) {
        return Container(
          margin: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildUploadCard(provider),
              if (provider.isProcessing) ...[
                const SizedBox(height: 16),
                _buildProgressCard(provider),
              ],
            ],
          ),
        );
      },
    );
  }

  /// بناء بطاقة الرفع
  Widget _buildUploadCard(ImportAnalysisProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: _isDragOver
            ? Border.all(
                color: AccountantThemeConfig.primaryGreen,
                width: 2,
              )
            : AccountantThemeConfig.glowBorder(
                AccountantThemeConfig.primaryGreen.withOpacity(0.3),
              ),
      ),
      child: Column(
        children: [
          // أيقونة الرفع المتحركة
          AnimatedBuilder(
            animation: _uploadAnimationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -10 * _uploadAnimationController.value),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.mainBackgroundGradient,
                    shape: BoxShape.circle,
                    boxShadow: AccountantThemeConfig.glowShadows(
                      AccountantThemeConfig.primaryGreen,
                    ),
                  ),
                  child: const Icon(
                    Icons.cloud_upload_outlined,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          // العنوان والوصف
          Text(
            'رفع ملف قائمة التعبئة',
            style: AccountantThemeConfig.headlineMedium.copyWith(
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'اختر ملف Excel (.xlsx, .xls) أو CSV لبدء التحليل',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          // أزرار الرفع
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: provider.isProcessing ? null : () {
                  provider.uploadFile();
                },
                style: AccountantThemeConfig.primaryButtonStyle.copyWith(
                  padding: MaterialStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                icon: const Icon(Icons.file_upload),
                label: const Text('اختيار ملف'),
              ),
              
              const SizedBox(width: 16),
              
              OutlinedButton.icon(
                onPressed: () => _showSupportedFormats(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AccountantThemeConfig.primaryGreen,
                  side: BorderSide(
                    color: AccountantThemeConfig.primaryGreen,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.help_outline),
                label: const Text('الأنواع المدعومة'),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // معلومات الحد الأقصى للحجم
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AccountantThemeConfig.primaryGreen,
                ),
                const SizedBox(width: 8),
                Text(
                  'الحد الأقصى للحجم: ${provider.userSettings?.maxFileSizeMb ?? 50} ميجابايت',
                  style: TextStyle(
                    fontSize: 12,
                    color: AccountantThemeConfig.primaryGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.3);
  }

  /// بناء بطاقة التقدم
  Widget _buildProgressCard(ImportAnalysisProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(
          AccountantThemeConfig.accentBlue,
        ),
      ),
      child: Column(
        children: [
          // حالة المعالجة
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AccountantThemeConfig.accentBlue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  provider.currentStatus,
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // شريط التقدم
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'التقدم',
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '${(provider.processingProgress * 100).toInt()}%',
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AccountantThemeConfig.accentBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: provider.processingProgress,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AccountantThemeConfig.accentBlue,
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // زر الإلغاء
          TextButton.icon(
            onPressed: () {
              // TODO: تنفيذ إلغاء المعالجة
              provider.clearData();
            },
            style: TextButton.styleFrom(
              foregroundColor: AccountantThemeConfig.dangerRed,
            ),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('إلغاء'),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.3);
  }

  /// عرض الأنواع المدعومة
  void _showSupportedFormats(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'الأنواع المدعومة',
          style: AccountantThemeConfig.headlineMedium,
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFormatItem(
              'Excel 2007+',
              '.xlsx',
              Icons.table_chart,
              'الأكثر استخداماً',
            ),
            const SizedBox(height: 12),
            _buildFormatItem(
              'Excel 97-2003',
              '.xls',
              Icons.table_chart_outlined,
              'إصدار قديم',
            ),
            const SizedBox(height: 12),
            _buildFormatItem(
              'CSV',
              '.csv',
              Icons.text_snippet,
              'ملف نصي مفصول بفواصل',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'حسناً',
              style: TextStyle(
                color: AccountantThemeConfig.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء عنصر نوع الملف
  Widget _buildFormatItem(
    String name,
    String extension,
    IconData icon,
    String description,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.primaryGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AccountantThemeConfig.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AccountantThemeConfig.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AccountantThemeConfig.primaryGreen,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        extension,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
