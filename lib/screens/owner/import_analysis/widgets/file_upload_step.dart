import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/providers/import_analysis_provider.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/widgets/common/custom_loader.dart';

/// خطوة رفع ومعالجة الملف - الخطوة الثانية في سير عمل استيراد الحاوية
class FileUploadStep extends StatefulWidget {
  final ImportAnalysisProvider provider;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const FileUploadStep({
    super.key,
    required this.provider,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<FileUploadStep> createState() => _FileUploadStepState();
}

class _FileUploadStepState extends State<FileUploadStep> {
  bool _isFileSelected = false;
  String? _selectedFileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(),
          const SizedBox(height: 24),
          Expanded(
            child: widget.provider.isLoading
                ? _buildProcessingView()
                : _buildUploadView(),
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
            gradient: AccountantThemeConfig.blueGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
          ),
          child: const Icon(
            Icons.upload_file,
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
                'الخطوة 2: رفع ومعالجة الملف',
                style: AccountantThemeConfig.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'اختر ملف Excel الخاص بقائمة التعبئة للمعالجة',
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

  /// بناء واجهة الرفع
  Widget _buildUploadView() {
    return Column(
      children: [
        Expanded(
          child: _isFileSelected
              ? _buildFileSelectedView()
              : _buildDropZone(),
        ),
        if (widget.provider.errorMessage?.isNotEmpty == true) ...[
          const SizedBox(height: 16),
          _buildErrorMessage(),
        ],
      ],
    );
  }

  /// بناء منطقة السحب والإفلات
  Widget _buildDropZone() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.cardBackground1.withOpacity(0.3),
            AccountantThemeConfig.accentBlue.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: InkWell(
        onTap: _selectFile,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.blueGradient,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
                ),
                child: const Icon(
                  Icons.cloud_upload,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'اسحب وأفلت ملف Excel هنا',
                style: AccountantThemeConfig.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'أو انقر لاختيار الملف',
                style: AccountantThemeConfig.bodyLarge.copyWith(
                  color: AccountantThemeConfig.white70,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.cardBackground1.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue.withOpacity(0.3)),
                ),
                child: Text(
                  'يدعم: .xlsx, .xls, .csv',
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: AccountantThemeConfig.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().scale(duration: 400.ms);
  }

  /// بناء واجهة الملف المحدد
  Widget _buildFileSelectedView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.cardBackground1.withOpacity(0.3),
            AccountantThemeConfig.primaryGreen.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.greenGradient,
              borderRadius: BorderRadius.circular(50),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: Icon(
              Icons.check_circle,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'تم اختيار الملف بنجاح',
            style: AccountantThemeConfig.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFileName ?? '',
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: AccountantThemeConfig.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _selectFile,
                icon: const Icon(Icons.refresh),
                label: const Text('اختيار ملف آخر'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[100],
                  foregroundColor: Colors.grey[700],
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _processFile,
                icon: const Icon(Icons.play_arrow),
                label: const Text('بدء المعالجة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AccountantThemeConfig.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().scale(duration: 400.ms);
  }

  /// بناء واجهة المعالجة
  Widget _buildProcessingView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CustomLoader(
          message: 'جاري معالجة الملف...',
          size: 60,
        ),
        const SizedBox(height: 24),
        Text(
          widget.provider.currentStatus,
          style: AccountantThemeConfig.bodyLarge.copyWith(
            color: Colors.grey[700],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: widget.provider.processingProgress,
            child: Container(
              decoration: BoxDecoration(
                color: AccountantThemeConfig.primaryGreen,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(widget.provider.processingProgress * 100).toInt()}%',
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// بناء رسالة الخطأ
  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.provider.errorMessage ?? '',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء أزرار الإجراءات
  Widget _buildActionButtons() {
    final canProceed = (widget.provider.currentBatch != null &&
                       widget.provider.currentItems.isNotEmpty) ||
                      (widget.provider.currentContainerBatch != null &&
                       widget.provider.currentContainerItems.isNotEmpty);

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
              gradient: canProceed
                  ? AccountantThemeConfig.greenGradient
                  : LinearGradient(colors: [Colors.grey[600]!, Colors.grey[500]!]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: canProceed
                  ? AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen)
                  : [],
            ),
            child: ElevatedButton(
              onPressed: canProceed ? widget.onNext : null,
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
                    'التالي',
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward,
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

  /// اختيار الملف
  Future<void> _selectFile() async {
    try {
      await widget.provider.pickFile();
      if (widget.provider.selectedFile != null) {
        setState(() {
          _isFileSelected = true;
          _selectedFileName = widget.provider.selectedFile!.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في اختيار الملف: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// معالجة الملف
  Future<void> _processFile() async {
    if (widget.provider.selectedFile != null) {
      // Use the new container import processing method
      await widget.provider.processContainerImportFile();
    }
  }
}
