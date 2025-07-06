import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import 'package:smartbiztracker_new/models/purchase_invoice_models.dart';
import 'package:smartbiztracker_new/services/purchase_invoice_service.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/screens/business_owner/purchase_invoice_details_screen.dart';

/// Data class for isolate communication
class IsolateData {
  final String filePath;
  final SendPort sendPort;

  IsolateData({
    required this.filePath,
    required this.sendPort,
  });
}

class ExcelImportScreen extends StatefulWidget {
  const ExcelImportScreen({super.key});

  @override
  State<ExcelImportScreen> createState() => _ExcelImportScreenState();
}

class _ExcelImportScreenState extends State<ExcelImportScreen> {
  final PurchaseInvoiceService _invoiceService = PurchaseInvoiceService();
  final TextEditingController _exchangeRateController = TextEditingController();
  final TextEditingController _profitMarginController = TextEditingController();
  final TextEditingController _supplierNameController = TextEditingController();

  bool _isLoading = false;
  bool _isProcessing = false;
  File? _selectedFile;
  List<Map<String, dynamic>> _extractedData = [];
  Map<String, int> _columnMapping = {};

  // Enhanced processing state
  double _processingProgress = 0.0;
  String _processingStatus = '';
  String _fileFormat = '';
  int _totalRows = 0;
  int _processedRows = 0;

  // Form validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _exchangeRateController.text = '0.19'; // Default Yuan to EGP rate
    _profitMarginController.text = '0'; // Default profit margin
  }

  @override
  void dispose() {
    _exchangeRateController.dispose();
    _profitMarginController.dispose();
    _supplierNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'استيراد من إكسل',
        showNotificationIcon: false,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_selectedFile == null) {
      return _buildFileSelectionState();
    }

    if (_extractedData.isEmpty) {
      return _buildProcessingState();
    }

    return _buildConfigurationState();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.cardGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AccountantThemeConfig.cardShadows,
            ),
            child: Column(
              children: [
                // Progress indicator
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _processingProgress > 0 ? _processingProgress : null,
                        color: AccountantThemeConfig.primaryGreen,
                        strokeWidth: 4,
                        backgroundColor: Colors.white.withOpacity(0.2),
                      ),
                      if (_processingProgress > 0)
                        Text(
                          '${(_processingProgress * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_fileFormat.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _fileFormat,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _processingStatus.isNotEmpty ? _processingStatus : 'جاري معالجة ملف الإكسل...',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'يرجى الانتظار بينما نقوم بتحليل البيانات',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          if (_processedRows > 0 && _totalRows > 0) ...[
            const SizedBox(height: 12),
            Text(
              'تم معالجة $_processedRows من أصل $_totalRows صف',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.white.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFileSelectionState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: AccountantThemeConfig.primaryCardDecoration,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.greenGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.table_chart,
                    color: Colors.white,
                    size: 48,
                  ),
                ).animate().scale(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                ),
                const SizedBox(height: 16),
                Text(
                  'استيراد فاتورة مشتريات من إكسل',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(
                  delay: const Duration(milliseconds: 200),
                  duration: const Duration(milliseconds: 600),
                ),
                const SizedBox(height: 8),
                Text(
                  'اختر ملف إكسل يحتوي على بيانات المنتجات والأسعار',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(
                  delay: const Duration(milliseconds: 400),
                  duration: const Duration(milliseconds: 600),
                ),
              ],
            ),
          ).animate().slideY(
            begin: -0.3,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
          ),

          const SizedBox(height: 24),

          // File selection area
          _buildFileSelectionArea(),

          const SizedBox(height: 24),

          // Instructions section
          _buildInstructionsSection(),
        ],
      ),
    );
  }

  Widget _buildFileSelectionArea() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
          width: 2,
          style: BorderStyle.solid,
        ),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: Column(
        children: [
          Icon(
            Icons.upload_file,
            size: 64,
            color: AccountantThemeConfig.primaryGreen,
          ).animate().scale(
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
          ),
          const SizedBox(height: 16),
          Text(
            'اختر ملف إكسل',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط هنا لاختيار ملف .xlsx فقط',
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.greenGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open, color: Colors.white),
              label: Text(
                'اختيار ملف',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(
      delay: const Duration(milliseconds: 600),
      duration: const Duration(milliseconds: 800),
    );
  }

  Widget _buildInstructionsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.blueGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'تعليمات مهمة',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInstructionItem(
            'يجب أن يحتوي الملف على الأعمدة التالية:',
            'اسم المنتج، الكمية، السعر بالـ Yuan، صورة المنتج (اختياري)',
          ),
          _buildInstructionItem(
            'أسماء الأعمدة يمكن أن تكون في أي صف:',
            'النظام سيبحث تلقائياً عن أسماء الأعمدة في جميع الصفوف',
          ),
          _buildInstructionItem(
            'الأعمدة المدعومة:',
            'Product Name, Item, Quantity, QTY, Price, Yuan, RMB, Image, Picture',
          ),
          _buildInstructionItem(
            'تنسيق الملف المدعوم:',
            'ملفات .xlsx فقط (Excel 2007 وما بعد). ملفات .xls غير مدعومة حالياً',
          ),
          _buildInstructionItem(
            'حجم الملف:',
            'يمكن معالجة ملفات بأي حجم. الملفات الكبيرة (أكثر من 50 ميجابايت) قد تستغرق وقتاً أطول',
          ),
        ],
      ),
    ).animate().slideX(
      begin: 0.3,
      delay: const Duration(milliseconds: 800),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildInstructionItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AccountantThemeConfig.primaryGreen,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: AccountantThemeConfig.primaryCardDecoration,
            child: Column(
              children: [
                const CircularProgressIndicator(
                  color: AccountantThemeConfig.primaryGreen,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'جاري تحليل ملف الإكسل...',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'البحث عن أعمدة البيانات واستخراج المعلومات',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // File info section
            _buildFileInfoSection(),
            const SizedBox(height: 16),

            // Data preview section
            _buildDataPreviewSection(),
            const SizedBox(height: 16),

            // Configuration form
            _buildConfigurationForm(),
            const SizedBox(height: 24),

            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildFileInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.greenGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
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
                  'تم تحليل الملف بنجاح',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'تم العثور على ${_extractedData.length} منتج',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                Text(
                  'الملف: ${_selectedFile?.path.split('/').last ?? 'غير محدد'}',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().slideX(
      begin: -0.3,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildDataPreviewSection() {
    final previewData = _extractedData.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.blueGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.preview,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'معاينة البيانات',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...previewData.map((item) => _buildPreviewItem(item)).toList(),
          if (_extractedData.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'و ${_extractedData.length - 3} منتج آخر...',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    ).animate().slideX(
      begin: 0.3,
      delay: const Duration(milliseconds: 200),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildPreviewItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          // Product image placeholder
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.image,
              color: AccountantThemeConfig.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['product_name'] ?? 'اسم غير محدد',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'الكمية: ${item['quantity'] ?? 1}',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'السعر: ${item['yuan_price'] ?? 0} ¥',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.orangeGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.settings,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'إعدادات الاستيراد',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Exchange Rate Field
          _buildFormField(
            label: 'سعر الصرف (يوان إلى جنيه)',
            controller: _exchangeRateController,
            hint: '0.19',
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'سعر الصرف مطلوب';
              }
              final rate = double.tryParse(value);
              if (rate == null || rate <= 0) {
                return 'يرجى إدخال سعر صرف صحيح';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Profit Margin Field
          _buildFormField(
            label: 'هامش الربح (%)',
            controller: _profitMarginController,
            hint: '0',
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                final margin = double.tryParse(value);
                if (margin == null || margin < 0 || margin > 1000) {
                  return 'يرجى إدخال هامش ربح صحيح (0-1000%)';
                }
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Supplier Name Field
          _buildFormField(
            label: 'اسم المورد (اختياري)',
            controller: _supplierNameController,
            hint: 'اسم المورد',
            keyboardType: TextInputType.text,
          ),
        ],
      ),
    ).animate().slideY(
      begin: 0.3,
      delay: const Duration(milliseconds: 400),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.cairo(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            textDirection: TextDirection.ltr,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey[600]!, Colors.grey[700]!],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton.icon(
              onPressed: _resetImport,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: Text(
                'إعادة تعيين',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.greenGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _processImport,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.upload, color: Colors.white),
              label: Text(
                _isProcessing ? 'جاري الإنشاء...' : 'إنشاء الفاتورة',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    ).animate().slideY(
      begin: 0.5,
      delay: const Duration(milliseconds: 600),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  /// Pick Excel file from device
  Future<void> _pickFile() async {
    try {
      HapticFeedback.lightImpact();

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = file.path.toLowerCase();

        // Enhanced format validation - Only XLSX is supported
        if (!fileName.endsWith('.xlsx')) {
          if (fileName.endsWith('.xls')) {
            _showErrorSnackBar('ملفات .xls (Excel 97-2003) غير مدعومة حالياً.\nيرجى تحويل الملف إلى تنسيق .xlsx باستخدام Excel أو LibreOffice ثم المحاولة مرة أخرى.');
          } else {
            _showErrorSnackBar('تنسيق الملف غير مدعوم. يرجى اختيار ملف .xlsx فقط');
          }
          return;
        }

        // Get file size for processing optimization
        final fileSize = await file.length();
        final fileSizeMB = fileSize / (1024 * 1024);

        // Check if file exists and is readable
        if (!await file.exists()) {
          _showErrorSnackBar('الملف غير موجود أو لا يمكن الوصول إليه');
          return;
        }

        setState(() {
          _selectedFile = file;
          _isLoading = true;
          _processingProgress = 0.0;
          _processingStatus = _getInitialProcessingStatus(fileSizeMB);
          _fileFormat = '';
        });

        // Process the file with enhanced error handling
        await _processExcelFile(file, fileSizeMB);
      }
    } catch (e) {
      AppLogger.error('خطأ في اختيار الملف: $e');
      _showErrorSnackBar('فشل في اختيار الملف');
    }
  }

  /// Process Excel file and extract data with enhanced format support
  Future<void> _processExcelFile(File file, double fileSizeMB) async {
    try {
      AppLogger.info('بدء معالجة ملف الإكسل: ${file.path}');

      // Detect file format - Only XLSX is supported
      final fileName = file.path.toLowerCase();
      final isXlsx = fileName.endsWith('.xlsx');

      setState(() {
        _fileFormat = isXlsx ? 'Excel 2007+ (.xlsx)' : 'غير محدد';
        _processingStatus = _getProcessingStatusWithSize(fileSizeMB, 'جاري قراءة الملف...');
        _processingProgress = 0.1;
      });

      AppLogger.info('نوع الملف المكتشف: $_fileFormat');

      // Process file in background isolate for better performance
      final extractedData = await _processFileInIsolate(file, fileSizeMB);

      if (extractedData.isEmpty) {
        throw Exception('لم يتم العثور على بيانات صالحة في الملف');
      }

      setState(() {
        _extractedData = extractedData;
        _isLoading = false;
        _processingProgress = 1.0;
        _processingStatus = 'تم استخراج ${extractedData.length} منتج بنجاح!\n'
                           'حجم الملف: ${fileSizeMB.toStringAsFixed(1)} ميجابايت';
      });

      AppLogger.info('تم استخراج ${extractedData.length} منتج من الملف');
      _showSuccessSnackBar('تم تحليل الملف بنجاح! تم العثور على ${extractedData.length} منتج');

    } catch (e) {
      AppLogger.error('خطأ في معالجة ملف الإكسل: $e');
      setState(() {
        _isLoading = false;
        _selectedFile = null;
        _processingProgress = 0.0;
        _processingStatus = 'فشل في المعالجة';
      });

      // Enhanced error messages based on error type
      String errorMessage = 'فشل في معالجة الملف';
      if (e.toString().contains('unsupported')) {
        errorMessage = 'تنسيق الملف غير مدعوم. يرجى استخدام ملفات .xlsx أو .xls';
      } else if (e.toString().contains('corrupted')) {
        errorMessage = 'الملف تالف أو غير قابل للقراءة. يرجى التحقق من سلامة الملف';
      } else if (e.toString().contains('empty')) {
        errorMessage = 'الملف فارغ أو لا يحتوي على بيانات صالحة';
      }

      _showErrorSnackBar(errorMessage);
    }
  }

  /// Process file in background isolate to prevent UI blocking
  Future<List<Map<String, dynamic>>> _processFileInIsolate(File file, double fileSizeMB) async {
    final receivePort = ReceivePort();

    setState(() {
      _processingStatus = _getProcessingStatusWithSize(fileSizeMB, 'جاري معالجة البيانات...');
      _processingProgress = 0.3;
    });

    try {
      await Isolate.spawn(
        _isolateEntryPoint,
        IsolateData(
          filePath: file.path,
          sendPort: receivePort.sendPort,
        ),
      );

      final result = await receivePort.first as Map<String, dynamic>;

      if (result['error'] != null) {
        throw Exception(result['error']);
      }

      setState(() {
        _processingProgress = 0.8;
        _processingStatus = _getProcessingStatusWithSize(fileSizeMB, 'جاري تنظيم البيانات...');
      });

      final data = result['data'];
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('تنسيق البيانات المستلمة غير صحيح');
      }
    } catch (e) {
      receivePort.close();
      rethrow;
    }
  }

  /// Isolate entry point for background processing
  static void _isolateEntryPoint(IsolateData data) async {
    try {
      final file = File(data.filePath);
      final bytes = await file.readAsBytes();

      List<Map<String, dynamic>> extractedData = [];

      // Process .xlsx files using excel package
      final excelFile = excel.Excel.decodeBytes(bytes);

      if (excelFile.tables.isEmpty) {
        throw Exception('الملف لا يحتوي على أوراق عمل');
      }

      final sheetName = excelFile.tables.keys.first;
      final sheet = excelFile.tables[sheetName]!;
      extractedData = _extractDataFromExcelSheet(sheet);

      data.sendPort.send({
        'data': extractedData,
        'error': null,
      });
    } catch (e) {
      data.sendPort.send({
        'data': null,
        'error': e.toString(),
      });
    }
  }

  /// Extract data from Excel sheet with intelligent column detection
  Future<List<Map<String, dynamic>>> _extractDataFromSheet(excel.Sheet sheet) async {
    final List<Map<String, dynamic>> extractedData = [];
    final List<String> processingErrors = [];
    int processedRows = 0;
    int skippedRows = 0;

    // Enhanced column name variations for comprehensive fuzzy matching
    final Map<String, List<String>> columnVariations = {
      'product_name': [
        // English variations
        'product name', 'item no', 'item', 'product description', 'product', 'name',
        'description', 'item name', 'product_name', 'productname', 'item_name',
        'goods', 'merchandise', 'article', 'commodity', 'sku', 'part number',
        'part_number', 'partnumber', 'model', 'title', 'label',
        // Arabic variations
        'اسم المنتج', 'المنتج', 'البضاعة', 'السلعة', 'الصنف', 'النوع', 'العنصر',
        'الوصف', 'التسمية', 'الاسم', 'المادة', 'القطعة', 'الموديل'
      ],
      'quantity': [
        // English variations
        'quantity', 'qty', 'pcs', 'count', 'amount', 'pieces', 'units', 'number',
        'num', 'no', '#', 'total', 'sum', 'volume', 'size', 'pack', 'box',
        'carton', 'dozen', 'gross', 'each', 'ea', 'pc', 'unit',
        // Arabic variations
        'الكمية', 'عدد', 'كمية', 'المقدار', 'العدد', 'الرقم', 'القطع', 'الوحدات',
        'المجموع', 'الإجمالي', 'الحجم', 'الصناديق', 'الكراتين'
      ],
      'yuan_price': [
        // English variations
        'unit price', 'price', 'unit price (rmb)', 'cost', 'yuan', 'rmb', 'cny',
        'unit cost', 'price per unit', 'rate', 'value', 'amount', 'fee', 'charge',
        'tariff', 'fare', 'toll', 'expense', 'outlay', 'expenditure', 'payment',
        'price_yuan', 'yuan_price', 'rmb_price', 'cny_price', 'chinese_yuan',
        // Arabic variations
        'السعر', 'سعر الوحدة', 'ثمن', 'التكلفة', 'المبلغ', 'القيمة', 'الرسوم',
        'الأجرة', 'النفقة', 'المصروف', 'الدفعة', 'سعر اليوان', 'اليوان الصيني'
      ],
      'product_image': [
        // English variations
        'pictures', 'picture', 'pics', 'image', 'images', 'photo', 'photos',
        'img', 'photograph', 'snapshot', 'shot', 'pic', 'figure', 'illustration',
        'graphic', 'visual', 'thumbnail', 'preview', 'gallery', 'media',
        // Arabic variations
        'صورة', 'الصورة', 'صور', 'الصور', 'لقطة', 'تصوير', 'رسم', 'مرئي',
        'معرض', 'وسائط', 'ملف مرئي', 'الملف المرئي'
      ],
    };

    // Enhanced header detection with progress tracking
    int headerRowIndex = -1;
    Map<String, int> columnMapping = {};
    int bestMatchScore = 0;
    Map<String, int> bestMapping = {};

    AppLogger.info('بدء البحث عن رؤوس الأعمدة في ${sheet.maxRows} صف');

    // Scan ALL rows to find the best header match
    for (int rowIndex = 0; rowIndex < sheet.maxRows && rowIndex < 50; rowIndex++) {
      try {
        final row = sheet.row(rowIndex);
        final potentialMapping = <String, int>{};
        int matchScore = 0;

        // Process each cell in the row
        for (int colIndex = 0; colIndex < row.length && colIndex < 20; colIndex++) {
          final cell = row[colIndex];
          if (cell?.value == null) continue;

          final cellValue = _cleanCellValue(cell!.value.toString());

          if (cellValue.isNotEmpty) {
            // Check against all column variations with enhanced matching
            for (final entry in columnVariations.entries) {
              final columnKey = entry.key;
              final variations = entry.value;

              for (final variation in variations) {
                final similarity = _calculateAdvancedSimilarity(cellValue, variation);
                if (similarity >= 0.8) { // 80% similarity threshold
                  potentialMapping[columnKey] = colIndex;
                  matchScore += (similarity * 100).round();
                  AppLogger.info('تطابق عمود: $cellValue ≈ $variation (${(similarity * 100).toStringAsFixed(1)}%)');
                  break;
                }
              }
            }
          }
        }

        // Update best match if this row has better score
        if (matchScore > bestMatchScore &&
            potentialMapping.containsKey('product_name') &&
            potentialMapping.containsKey('yuan_price')) {
          bestMatchScore = matchScore;
          bestMapping = Map.from(potentialMapping);
          headerRowIndex = rowIndex;
          AppLogger.info('أفضل تطابق حتى الآن في الصف ${rowIndex + 1} بنقاط: $matchScore');
        }

        // Early exit if we found a perfect match
        if (potentialMapping.length >= 3 && matchScore >= 300) {
          headerRowIndex = rowIndex;
          columnMapping = potentialMapping;
          break;
        }

      } catch (e) {
        AppLogger.warning('خطأ في معالجة الصف ${rowIndex + 1}: $e');
        continue;
      }
    }

    // Use the best mapping found
    if (headerRowIndex == -1 && bestMapping.isNotEmpty) {
      columnMapping = bestMapping;
      headerRowIndex = 0; // Fallback to first row with best mapping
    }

    if (headerRowIndex == -1) {
      throw Exception('لم يتم العثور على أعمدة البيانات المطلوبة (اسم المنتج والسعر)');
    }

    AppLogger.info('تم العثور على رأس الجدول في الصف ${headerRowIndex + 1}');
    AppLogger.info('تم تحديد الأعمدة: $columnMapping');

    // Enhanced data extraction with performance optimization
    AppLogger.info('بدء استخراج البيانات من الصف ${headerRowIndex + 2} إلى ${sheet.maxRows}');

    const int batchSize = 100; // Process in batches for better performance
    int totalProcessed = 0;
    int validRows = 0;

    for (int batchStart = headerRowIndex + 1; batchStart < sheet.maxRows; batchStart += batchSize) {
      final batchEnd = (batchStart + batchSize).clamp(0, sheet.maxRows);

      // Process batch
      for (int rowIndex = batchStart; rowIndex < batchEnd; rowIndex++) {
        totalProcessed++;

        try {
          final row = sheet.row(rowIndex);

          // Enhanced empty row detection
          if (_isRowEmpty(row)) {
            skippedRows++;
            continue;
          }

          // Extract and validate data
          final productName = _getCellValue(row, columnMapping['product_name']);
          final yuanPriceStr = _getCellValue(row, columnMapping['yuan_price']);

          // Skip rows without essential data
          if (productName.isEmpty || yuanPriceStr.isEmpty) {
            skippedRows++;
            processingErrors.add('الصف ${rowIndex + 1}: بيانات المنتج أو السعر مفقودة');
            continue;
          }

          // Enhanced price parsing with multiple formats
          final yuanPrice = _parsePrice(yuanPriceStr);
          if (yuanPrice <= 0) {
            skippedRows++;
            processingErrors.add('الصف ${rowIndex + 1}: سعر غير صحيح ($yuanPriceStr)');
            continue;
          }

          // Enhanced quantity parsing
          final quantityStr = _getCellValue(row, columnMapping['quantity']);
          final quantity = _parseQuantity(quantityStr);
          if (quantity <= 0 || quantity > 9999) {
            skippedRows++;
            processingErrors.add('الصف ${rowIndex + 1}: كمية غير صحيحة ($quantityStr)');
            continue;
          }

          final productImage = _getCellValue(row, columnMapping['product_image']);

          // Validate product name length and content
          if (productName.length > 200) {
            skippedRows++;
            processingErrors.add('الصف ${rowIndex + 1}: اسم المنتج طويل جداً');
            continue;
          }

          extractedData.add({
            'product_name': productName.trim(),
            'quantity': quantity,
            'yuan_price': yuanPrice,
            'product_image': productImage.isNotEmpty ? productImage.trim() : null,
          });

          validRows++;
          processedRows++;

        } catch (e) {
          skippedRows++;
          final errorMsg = 'الصف ${rowIndex + 1}: خطأ في المعالجة - ${e.toString()}';
          processingErrors.add(errorMsg);
          AppLogger.warning(errorMsg);
          continue;
        }
      }

      // Yield control to prevent UI blocking
      if (batchStart % (batchSize * 5) == 0) {
        await Future.delayed(const Duration(milliseconds: 1));
      }
    }

    // Log processing summary
    AppLogger.info('انتهاء المعالجة: $validRows صف صحيح، $skippedRows صف متخطى من أصل $totalProcessed');
    if (processingErrors.isNotEmpty) {
      AppLogger.warning('أخطاء المعالجة: ${processingErrors.take(10).join(', ')}');
    }

    return extractedData;
  }

  /// Clean cell value for processing
  String _cleanCellValue(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .replaceAll(RegExp(r'[^\w\u0600-\u06FF\s]'), '') // Remove special chars except Arabic
        .trim();
  }

  /// Advanced similarity calculation with multiple algorithms
  double _calculateAdvancedSimilarity(String text1, String text2) {
    final clean1 = _cleanCellValue(text1);
    final clean2 = _cleanCellValue(text2);

    // Exact match
    if (clean1 == clean2) return 1.0;

    // Contains match (high score)
    if (clean1.contains(clean2) || clean2.contains(clean1)) {
      final longer = clean1.length > clean2.length ? clean1 : clean2;
      final shorter = clean1.length > clean2.length ? clean2 : clean1;
      return 0.9 + (shorter.length / longer.length) * 0.1;
    }

    // Levenshtein similarity
    final levenshteinSim = _calculateSimilarity(clean1, clean2);

    // Jaccard similarity (word-based)
    final jaccardSim = _calculateJaccardSimilarity(clean1, clean2);

    // Combined score (weighted average)
    return (levenshteinSim * 0.7) + (jaccardSim * 0.3);
  }

  /// Calculate Jaccard similarity for word-based matching
  double _calculateJaccardSimilarity(String s1, String s2) {
    final words1 = s1.split(' ').where((w) => w.isNotEmpty).toSet();
    final words2 = s2.split(' ').where((w) => w.isNotEmpty).toSet();

    if (words1.isEmpty && words2.isEmpty) return 1.0;
    if (words1.isEmpty || words2.isEmpty) return 0.0;

    final intersection = words1.intersection(words2).length;
    final union = words1.union(words2).length;

    return intersection / union;
  }

  /// Check if Excel row is empty or contains only whitespace
  bool _isRowEmpty(List<dynamic> row) {
    if (row.isEmpty) return true;

    return row.every((cell) {
      if (cell?.value == null) return true;
      final cellValue = cell!.value.toString().trim();
      return cellValue.isEmpty || cellValue == '0' || cellValue.toLowerCase() == 'null';
    });
  }

  /// Enhanced price parsing with multiple format support
  double _parsePrice(String priceStr) {
    if (priceStr.isEmpty) return 0.0;

    // Remove common currency symbols and text
    String cleaned = priceStr
        .toLowerCase()
        .replaceAll(RegExp(r'[^\d.,\-+]'), '') // Keep only digits, dots, commas, signs
        .replaceAll(',', '.') // Normalize decimal separator
        .trim();

    if (cleaned.isEmpty) return 0.0;

    // Handle negative numbers
    bool isNegative = cleaned.startsWith('-');
    if (isNegative) {
      cleaned = cleaned.substring(1);
    }

    // Parse the number
    final parsed = double.tryParse(cleaned) ?? 0.0;
    return isNegative ? -parsed : parsed;
  }

  /// Enhanced quantity parsing with validation
  int _parseQuantity(String quantityStr) {
    if (quantityStr.isEmpty) return 1; // Default quantity

    // Remove non-digit characters except decimal point
    String cleaned = quantityStr.replaceAll(RegExp(r'[^\d.]'), '');

    if (cleaned.isEmpty) return 1;

    // Parse as double first, then convert to int
    final parsed = double.tryParse(cleaned) ?? 1.0;
    return parsed.round().clamp(1, 9999);
  }

  /// Fuzzy string matching for column detection (legacy method)
  bool _fuzzyMatch(String text1, String text2) {
    return _calculateAdvancedSimilarity(text1, text2) >= 0.8;
  }

  /// Calculate string similarity
  double _calculateSimilarity(String s1, String s2) {
    if (s1.isEmpty && s2.isEmpty) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final longer = s1.length > s2.length ? s1 : s2;
    final shorter = s1.length > s2.length ? s2 : s1;

    if (longer.length == 0) return 1.0;

    final editDistance = _levenshteinDistance(longer, shorter);
    return (longer.length - editDistance) / longer.length;
  }

  /// Calculate Levenshtein distance
  int _levenshteinDistance(String s1, String s2) {
    final matrix = List.generate(
      s1.length + 1,
      (i) => List.generate(s2.length + 1, (j) => 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
  }

  /// Get cell value safely from Excel row
  String _getCellValue(List<dynamic> row, int? columnIndex) {
    if (columnIndex == null || columnIndex >= row.length) {
      return '';
    }

    final cell = row[columnIndex];
    if (cell?.value == null) {
      return '';
    }

    return cell!.value.toString().trim();
  }

  /// Reset import process
  void _resetImport() {
    setState(() {
      _selectedFile = null;
      _extractedData.clear();
      _columnMapping.clear();
      _isLoading = false;
      _isProcessing = false;
    });

    _exchangeRateController.text = '0.19';
    _profitMarginController.text = '0';
    _supplierNameController.clear();
  }

  /// Process import and create invoice
  Future<void> _processImport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      HapticFeedback.lightImpact();

      final exchangeRate = double.parse(_exchangeRateController.text);
      final profitMargin = double.tryParse(_profitMarginController.text) ?? 0.0;
      final supplierName = _supplierNameController.text.trim();

      // Convert extracted data to PurchaseInvoiceItem objects
      final List<PurchaseInvoiceItem> invoiceItems = [];

      for (final data in _extractedData) {
        final item = PurchaseInvoiceItem.create(
          productName: data['product_name'] as String,
          productImage: data['product_image'] as String?,
          yuanPrice: data['yuan_price'] as double,
          exchangeRate: exchangeRate,
          profitMarginPercent: profitMargin,
          quantity: data['quantity'] as int,
        );
        invoiceItems.add(item);
      }

      // Create purchase invoice
      final invoice = PurchaseInvoice.create(
        supplierName: supplierName.isNotEmpty ? supplierName : null,
        items: invoiceItems,
        notes: 'تم الاستيراد من ملف إكسل - ${_selectedFile?.path.split('/').last}',
      );

      AppLogger.info('إنشاء فاتورة مشتريات من الاستيراد مع ${invoiceItems.length} منتج');

      final result = await _invoiceService.createPurchaseInvoice(invoice);

      // Check if result is successful (handle both Map and direct success)
      bool isSuccess = false;
      String? errorMessage;

      if (result is Map<String, dynamic>) {
        isSuccess = result['success'] == true;
        errorMessage = result['message']?.toString();
      } else {
        // If service returns the invoice directly, consider it successful
        isSuccess = result != null;
      }

      if (isSuccess) {
        _showSuccessSnackBar('تم إنشاء الفاتورة بنجاح! تم استيراد ${invoiceItems.length} منتج');

        // Navigate to invoice details
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PurchaseInvoiceDetailsScreen(
                invoiceId: invoice.id,
              ),
            ),
          );
        }
      } else {
        throw Exception(errorMessage ?? 'فشل في إنشاء الفاتورة - خطأ غير محدد');
      }

    } catch (e) {
      AppLogger.error('خطأ في معالجة الاستيراد: $e');
      _showErrorSnackBar('فشل في إنشاء الفاتورة: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// Show success message
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AccountantThemeConfig.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Show error message
  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AccountantThemeConfig.dangerRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Extract data from Excel sheet (.xlsx format)
  static List<Map<String, dynamic>> _extractDataFromExcelSheet(excel.Sheet sheet) {
    final List<Map<String, dynamic>> extractedData = [];

    // Column name variations for fuzzy matching
    final Map<String, List<String>> columnVariations = {
      'product_name': [
        'product name', 'item no', 'item', 'product description', 'product', 'name',
        'description', 'item name', 'اسم المنتج', 'المنتج', 'البضاعة', 'السلعة'
      ],
      'quantity': [
        'quantity', 'qty', 'pcs', 'الكمية', 'عدد', 'كمية', 'count', 'amount', 'pieces'
      ],
      'yuan_price': [
        'unit price', 'price', 'unit price (rmb)', 'السعر', 'سعر الوحدة', 'ثمن',
        'cost', 'yuan', 'rmb', 'unit cost', 'price per unit'
      ],
      'product_image': [
        'pictures', 'picture', 'pics', 'صورة', 'الصورة', 'صور', 'image', 'images', 'photo'
      ],
    };

    // Find header row
    int headerRowIndex = -1;
    Map<String, int> columnMapping = {};

    for (int rowIndex = 0; rowIndex < sheet.maxRows && rowIndex < 50; rowIndex++) {
      final row = sheet.row(rowIndex);
      final potentialMapping = <String, int>{};

      for (int colIndex = 0; colIndex < row.length && colIndex < 20; colIndex++) {
        final cell = row[colIndex];
        if (cell?.value == null) continue;

        final cellValue = cell!.value.toString().toLowerCase().trim();

        if (cellValue.isNotEmpty) {
          for (final entry in columnVariations.entries) {
            final columnKey = entry.key;
            final variations = entry.value;

            for (final variation in variations) {
              final similarity = _calculateAdvancedSimilarityStatic(cellValue, variation);
              if (similarity >= 0.8) {
                potentialMapping[columnKey] = colIndex;
                break;
              }
            }
          }
        }
      }

      if (potentialMapping.containsKey('product_name') && potentialMapping.containsKey('yuan_price')) {
        headerRowIndex = rowIndex;
        columnMapping = potentialMapping;
        break;
      }
    }

    if (headerRowIndex == -1) {
      throw Exception('لم يتم العثور على أعمدة البيانات المطلوبة');
    }

    // Extract data from rows after header
    for (int rowIndex = headerRowIndex + 1; rowIndex < sheet.maxRows; rowIndex++) {
      final row = sheet.row(rowIndex);

      if (row.isEmpty || row.every((cell) => cell?.value == null || cell!.value.toString().trim().isEmpty)) {
        continue;
      }

      try {
        final productName = _getCellValueStatic(row, columnMapping['product_name']);
        final yuanPriceStr = _getCellValueStatic(row, columnMapping['yuan_price']);

        if (productName.isEmpty || yuanPriceStr.isEmpty) {
          continue;
        }

        final yuanPrice = _parsePriceStatic(yuanPriceStr);
        if (yuanPrice <= 0) continue;

        final quantityStr = _getCellValueStatic(row, columnMapping['quantity']);
        final quantity = _parseQuantityStatic(quantityStr);

        final productImage = _getCellValueStatic(row, columnMapping['product_image']);

        extractedData.add({
          'product_name': productName.trim(),
          'quantity': quantity,
          'yuan_price': yuanPrice,
          'product_image': productImage.isNotEmpty ? productImage.trim() : null,
        });

      } catch (e) {
        continue;
      }
    }

    return extractedData;
  }

  /// Static helper methods for isolate processing
  static double _calculateAdvancedSimilarityStatic(String text1, String text2) {
    final clean1 = text1
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\u0600-\u06FF\s]'), '')
        .trim();
    final clean2 = text2
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\u0600-\u06FF\s]'), '')
        .trim();

    // Exact match
    if (clean1 == clean2) return 1.0;

    // Contains match (high score)
    if (clean1.contains(clean2) || clean2.contains(clean1)) {
      final longer = clean1.length > clean2.length ? clean1 : clean2;
      final shorter = clean1.length > clean2.length ? clean2 : clean1;
      return 0.9 + (shorter.length / longer.length) * 0.1;
    }

    return 0.0;
  }

  static String _getCellValueStatic(List<dynamic> row, int? columnIndex) {
    if (columnIndex == null || columnIndex >= row.length) return '';
    final cell = row[columnIndex];
    if (cell?.value == null) return '';
    return cell!.value.toString().trim();
  }

  static double _parsePriceStatic(String priceStr) {
    if (priceStr.isEmpty) return 0.0;
    final cleaned = priceStr.replaceAll(RegExp(r'[^\d.,\-+]'), '').replaceAll(',', '.').trim();
    if (cleaned.isEmpty) return 0.0;
    return double.tryParse(cleaned) ?? 0.0;
  }

  static int _parseQuantityStatic(String quantityStr) {
    if (quantityStr.isEmpty) return 1;
    final cleaned = quantityStr.replaceAll(RegExp(r'[^\d.]'), '');
    if (cleaned.isEmpty) return 1;
    final parsed = double.tryParse(cleaned) ?? 1.0;
    return parsed.round().clamp(1, 9999);
  }

  /// Generate initial processing status with file size information
  String _getInitialProcessingStatus(double fileSizeMB) {
    if (fileSizeMB > 50) {
      final estimatedTime = _getEstimatedProcessingTime(fileSizeMB);
      return 'حجم الملف: ${fileSizeMB.toStringAsFixed(1)} ميجابايت\n'
             'قد تستغرق العملية وقتاً أطول\n'
             'الوقت المقدر: $estimatedTime';
    } else {
      return 'بدء المعالجة...\nحجم الملف: ${fileSizeMB.toStringAsFixed(1)} ميجابايت';
    }
  }

  /// Generate processing status with file size information
  String _getProcessingStatusWithSize(double fileSizeMB, String baseStatus) {
    if (fileSizeMB > 50) {
      final estimatedTime = _getEstimatedProcessingTime(fileSizeMB);
      return '$baseStatus\n'
             'حجم الملف: ${fileSizeMB.toStringAsFixed(1)} ميجابايت\n'
             'الوقت المقدر: $estimatedTime';
    } else {
      return '$baseStatus\nحجم الملف: ${fileSizeMB.toStringAsFixed(1)} ميجابايت';
    }
  }

  /// Calculate estimated processing time based on file size
  String _getEstimatedProcessingTime(double fileSizeMB) {
    if (fileSizeMB <= 10) {
      return 'أقل من دقيقة';
    } else if (fileSizeMB <= 25) {
      return '1-2 دقيقة';
    } else if (fileSizeMB <= 50) {
      return '2-3 دقائق';
    } else if (fileSizeMB <= 100) {
      return '3-5 دقائق';
    } else if (fileSizeMB <= 200) {
      return '5-8 دقائق';
    } else {
      return '8-15 دقيقة';
    }
  }
}
