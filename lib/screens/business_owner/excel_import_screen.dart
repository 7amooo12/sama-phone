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

  // Safety constants to prevent Excel column/row limit errors
  static const int MAX_COLUMNS_TO_SCAN = 100; // Maximum columns to scan for headers
  static const int MAX_ROWS_TO_SCAN_FOR_HEADERS = 50; // Maximum rows to scan for headers
  static const int MAX_ROWS_TO_PROCESS = 10000; // Maximum rows to process for data
  static const int EXCEL_MAX_COLUMNS = 16384; // Excel's actual column limit (XFD)

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
            'النظام يدعم التعرف الذكي على الأعمدة:',
            'يتعرف على أسماء الأعمدة بأي حالة أحرف (كبيرة/صغيرة) وبأشكال مختلفة ومختصرة',
          ),
          _buildInstructionItem(
            'أمثلة على أسماء الأعمدة المدعومة لاسم المنتج:',
            'Product Name, Item, Title, Description, Prod, SKU, Model, Code, اسم المنتج, المنتج, البضاعة',
          ),
          _buildInstructionItem(
            'أمثلة على أسماء الأعمدة المدعومة للكمية:',
            'Quantity, QTY, Pcs, Pieces, Count, Amount, Units, Total, Box, Pack, الكمية, عدد, القطع',
          ),
          _buildInstructionItem(
            'أمثلة على أسماء الأعمدة المدعومة للسعر:',
            'Price, Yuan, RMB, CNY, Cost, Rate, Value, Unit Price, Price (Yuan), السعر, ثمن, التكلفة',
          ),
          _buildInstructionItem(
            'أمثلة على أسماء الأعمدة المدعومة للصورة:',
            'Image, Picture, Photo, Pic, Img, URL, Link, Gallery, صورة, الصورة, رابط الصورة',
          ),
          _buildInstructionItem(
            'مرونة في التعرف على الأعمدة:',
            'النظام يدعم الاختصارات والأشكال المختلفة لأسماء الأعمدة، ويتعامل مع الفواصل والشرطات والمسافات',
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
      } else if (e.toString().contains('Reached Max') || e.toString().contains('XFD') || e.toString().contains('16384')) {
        errorMessage = 'الملف يحتوي على عدد كبير جداً من الأعمدة. يرجى استخدام ملف بأعمدة أقل (الحد الأقصى 100 عمود)';
      } else if (e.toString().contains('Invalid argument')) {
        errorMessage = 'بنية الملف غير صحيحة. يرجى التحقق من تنسيق الملف وإعادة المحاولة';
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

    // Enhanced comprehensive column name variations for flexible fuzzy matching
    // Supports case insensitivity, partial matching, and extensive variations
    final Map<String, List<String>> columnVariations = {
      'product_name': [
        // Complete phrases
        'product name', 'item name', 'product description', 'item description',
        'product title', 'item title', 'goods name', 'merchandise name',
        'article name', 'commodity name', 'product info', 'item info',
        'product details', 'item details', 'part number', 'model number',

        // Single words and abbreviations
        'product', 'item', 'name', 'title', 'label', 'description', 'desc',
        'goods', 'merchandise', 'article', 'commodity', 'material', 'stuff',
        'sku', 'model', 'part', 'code', 'id', 'identifier', 'ref', 'reference',

        // Variations with underscores and concatenations
        'product_name', 'productname', 'item_name', 'itemname', 'product_title',
        'producttitle', 'item_title', 'itemtitle', 'part_number', 'partnumber',
        'model_number', 'modelnumber', 'product_code', 'productcode',
        'item_code', 'itemcode', 'product_id', 'productid', 'item_id', 'itemid',

        // Abbreviated forms
        'prod', 'itm', 'prd', 'pname', 'iname', 'pcode', 'icode', 'pid', 'iid',

        // Arabic variations - comprehensive
        'اسم المنتج', 'المنتج', 'البضاعة', 'السلعة', 'الصنف', 'النوع', 'العنصر',
        'الوصف', 'التسمية', 'الاسم', 'المادة', 'القطعة', 'الموديل', 'العنوان',
        'التفاصيل', 'البيانات', 'المعلومات', 'الكود', 'الرقم المرجعي', 'المرجع',
        'رقم القطعة', 'رقم الموديل', 'كود المنتج', 'معرف المنتج', 'هوية المنتج'
      ],

      'quantity': [
        // Complete phrases
        'quantity', 'total quantity', 'item quantity', 'order quantity',
        'purchase quantity', 'number of items', 'number of pieces',
        'pieces count', 'units count', 'items count', 'ordered quantity',
        'required quantity', 'requested quantity', 'shipped quantity',

        // Single words
        'qty', 'pcs', 'pieces', 'units', 'count', 'amount', 'number', 'num',
        'total', 'sum', 'volume', 'size', 'pack', 'box', 'carton', 'dozen',
        'gross', 'each', 'nos', 'numbers', 'items', 'stock', 'inventory',

        // Abbreviated and symbol forms
        'ea', 'pc', 'unit', 'ct', 'cnt', '#', 'no', 'qnty', 'qtty', 'q',

        // Common Excel column headers
        'column1', 'column2', 'column3', 'column4', 'column5', 'column6',
        'col1', 'col2', 'col3', 'col4', 'col5', 'col6',
        'field1', 'field2', 'field3', 'field4', 'field5', 'field6',

        // Packaging terms
        'package', 'packages', 'bag', 'bags', 'bottle', 'bottles', 'can', 'cans',
        'roll', 'rolls', 'sheet', 'sheets', 'set', 'sets', 'pair', 'pairs',
        'case', 'cases', 'lot', 'lots', 'batch', 'batches',

        // Variations with underscores and dashes
        'quantity_ordered', 'qty_ordered', 'order_qty', 'purchase_qty',
        'item_count', 'piece_count', 'unit_count', 'total_count',
        'quantity-ordered', 'qty-ordered', 'order-qty', 'purchase-qty',
        'item-count', 'piece-count', 'unit-count', 'total-count',

        // Common misspellings and variations
        'quantiy', 'quanity', 'quantitiy', 'qantity', 'quntity',
        'qtyy', 'qtty', 'qnty', 'qntyy',

        // Arabic variations - comprehensive
        'الكمية', 'عدد', 'كمية', 'المقدار', 'العدد', 'الرقم', 'القطع', 'الوحدات',
        'المجموع', 'الإجمالي', 'الحجم', 'الصناديق', 'الكراتين', 'العبوات',
        'الأكياس', 'الزجاجات', 'العلب', 'اللفات', 'الأوراق', 'المجموعات',
        'الأزواج', 'كمية الطلب', 'عدد القطع', 'عدد الوحدات', 'إجمالي الكمية',

        // Chinese variations for international files
        '数量', '总数量', '总量', '件数', '个数', '数目',

        // Other language variations
        'cantidad', 'quantité', 'quantità', 'quantidade', 'menge', 'aantal'
      ],

      'yuan_price': [
        // Complete phrases with currency
        'unit price', 'price per unit', 'unit cost', 'cost per unit',
        'unit price (rmb)', 'unit price (yuan)', 'unit price (cny)',
        'price in yuan', 'cost in yuan', 'yuan price', 'rmb price',
        'cny price', 'chinese yuan price', 'price per piece',

        // Single words
        'price', 'cost', 'rate', 'value', 'amount', 'fee', 'charge',
        'tariff', 'fare', 'toll', 'expense', 'outlay', 'expenditure',
        'payment', 'yuan', 'rmb', 'cny', 'renminbi',

        // Currency and pricing terms
        'unitprice', 'unitcost', 'priceper', 'costper', 'pricing', 'costing',
        'valuation', 'quotation', 'quote', 'estimate', 'budget',

        // Variations with underscores and symbols
        'unit_price', 'unit_cost', 'price_yuan', 'yuan_price', 'rmb_price',
        'cny_price', 'chinese_yuan', 'price_per_unit', 'cost_per_unit',
        'price_per_piece', 'cost_per_piece', 'yuan_cost', 'rmb_cost',

        // Abbreviated forms
        'uprice', 'ucost', 'ppu', 'cpu', 'py', 'cy', 'ry',

        // Arabic variations - comprehensive
        'السعر', 'سعر الوحدة', 'ثمن', 'التكلفة', 'المبلغ', 'القيمة', 'الرسوم',
        'الأجرة', 'النفقة', 'المصروف', 'الدفعة', 'سعر اليوان', 'اليوان الصيني',
        'الرنمينبي', 'سعر القطعة', 'تكلفة الوحدة', 'ثمن الوحدة', 'قيمة الوحدة',
        'مبلغ الوحدة', 'سعر الصرف', 'العملة الصينية', 'التسعير', 'التكلفة',
        'التقييم', 'عرض السعر', 'التقدير', 'الميزانية'
      ],

      'product_image': [
        // Complete phrases
        'product image', 'item image', 'product picture', 'item picture',
        'product photo', 'item photo', 'product photograph', 'item photograph',
        'image url', 'picture url', 'photo url', 'image link', 'picture link',

        // Single words
        'image', 'images', 'picture', 'pictures', 'photo', 'photos', 'pic', 'pics',
        'img', 'photograph', 'snapshot', 'shot', 'figure', 'illustration',
        'graphic', 'visual', 'thumbnail', 'preview', 'gallery', 'media',

        // Technical terms
        'jpeg', 'jpg', 'png', 'gif', 'bmp', 'tiff', 'webp', 'svg',
        'file', 'attachment', 'document', 'resource', 'asset',

        // Variations with underscores
        'product_image', 'productimage', 'item_image', 'itemimage',
        'product_picture', 'productpicture', 'item_picture', 'itempicture',
        'product_photo', 'productphoto', 'item_photo', 'itemphoto',
        'image_url', 'imageurl', 'picture_url', 'pictureurl',
        'photo_url', 'photourl', 'img_url', 'imgurl',

        // Abbreviated forms
        'pimg', 'ppic', 'pphoto', 'iimg', 'ipic', 'iphoto', 'url', 'link',

        // Arabic variations - comprehensive
        'صورة', 'الصورة', 'صور', 'الصور', 'لقطة', 'تصوير', 'رسم', 'مرئي',
        'معرض', 'وسائط', 'ملف مرئي', 'الملف المرئي', 'صورة المنتج', 'صورة العنصر',
        'تصوير المنتج', 'لقطة المنتج', 'رابط الصورة', 'عنوان الصورة',
        'ملف الصورة', 'مرفق الصورة', 'وثيقة مرئية', 'مورد مرئي', 'أصل مرئي'
      ],
    };

    // Enhanced header detection with progress tracking
    int headerRowIndex = -1;
    Map<String, int> columnMapping = {};
    int bestMatchScore = 0;
    Map<String, int> bestMapping = {};

    // Validate sheet structure before processing
    if (!_validateSheetStructure(sheet)) {
      throw Exception('بنية الملف غير صحيحة أو تحتوي على أخطاء');
    }

    final maxRowsToScan = [sheet.maxRows, MAX_ROWS_TO_SCAN_FOR_HEADERS].reduce((a, b) => a < b ? a : b);
    AppLogger.info('بدء البحث عن رؤوس الأعمدة في $maxRowsToScan صف');

    // Scan rows to find the best header match with safe bounds
    for (int rowIndex = 0; rowIndex < maxRowsToScan; rowIndex++) {
      try {
        final row = _getSafeRow(sheet, rowIndex);
        if (row.isEmpty) continue;

        // Debug: Log the row content for first few rows
        if (rowIndex < 5) {
          final rowContent = row.take(10).map((cell) => cell?.value?.toString() ?? '').toList();
          AppLogger.info('الصف ${rowIndex + 1}: ${rowContent.join(' | ')}');
        }

        final potentialMapping = <String, int>{};
        int matchScore = 0;

        // Process each cell in the row with safe column bounds
        final maxColsToScan = [row.length, MAX_COLUMNS_TO_SCAN].reduce((a, b) => a < b ? a : b);
        for (int colIndex = 0; colIndex < maxColsToScan; colIndex++) {
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
                if (similarity >= 0.75) { // 75% similarity threshold for enhanced matching
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
        // FIXED: Now requires quantity column to be detected as well
        if (matchScore > bestMatchScore &&
            potentialMapping.containsKey('product_name') &&
            potentialMapping.containsKey('yuan_price') &&
            potentialMapping.containsKey('quantity')) {
          bestMatchScore = matchScore;
          bestMapping = Map.from(potentialMapping);
          headerRowIndex = rowIndex;
          AppLogger.info('أفضل تطابق حتى الآن في الصف ${rowIndex + 1} بنقاط: $matchScore');
          AppLogger.info('الأعمدة المكتشفة: ${potentialMapping.keys.join(', ')}');
        }

        // Early exit if we found a perfect match
        // FIXED: Ensure all required columns are detected
        if (potentialMapping.containsKey('product_name') &&
            potentialMapping.containsKey('yuan_price') &&
            potentialMapping.containsKey('quantity') &&
            matchScore >= 300) {
          headerRowIndex = rowIndex;
          columnMapping = potentialMapping;
          AppLogger.info('تم العثور على تطابق مثالي في الصف ${rowIndex + 1}');
          AppLogger.info('الأعمدة المكتشفة: ${potentialMapping.keys.join(', ')}');
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
      throw Exception('لم يتم العثور على أعمدة البيانات المطلوبة (اسم المنتج، السعر، والكمية)');
    }

    // FIXED: Validate that all required columns are detected
    if (!columnMapping.containsKey('product_name') ||
        !columnMapping.containsKey('yuan_price') ||
        !columnMapping.containsKey('quantity')) {
      final missingColumns = <String>[];
      if (!columnMapping.containsKey('product_name')) missingColumns.add('اسم المنتج');
      if (!columnMapping.containsKey('yuan_price')) missingColumns.add('السعر');
      if (!columnMapping.containsKey('quantity')) missingColumns.add('الكمية');

      AppLogger.error('أعمدة مفقودة: ${missingColumns.join(', ')}');
      AppLogger.error('الأعمدة المكتشفة: ${columnMapping.keys.join(', ')}');

      // Try to find quantity column by looking for numeric columns
      if (!columnMapping.containsKey('quantity') && headerRowIndex != -1) {
        AppLogger.info('محاولة العثور على عمود الكمية من خلال البحث عن الأعمدة الرقمية...');
        final quantityColumnIndex = _findQuantityColumnByContent(sheet, headerRowIndex);
        if (quantityColumnIndex != -1) {
          columnMapping['quantity'] = quantityColumnIndex;
          AppLogger.info('تم العثور على عمود الكمية في الموضع: $quantityColumnIndex');
          missingColumns.remove('الكمية');
        }
      }

      if (missingColumns.isNotEmpty) {
        final foundColumns = columnMapping.keys.map((key) {
          switch (key) {
            case 'product_name': return 'اسم المنتج';
            case 'yuan_price': return 'السعر';
            case 'quantity': return 'الكمية';
            case 'product_image': return 'صورة المنتج';
            default: return key;
          }
        }).join(', ');

        final errorMessage = 'لم يتم العثور على الأعمدة المطلوبة: ${missingColumns.join(', ')}\n'
                           'الأعمدة المكتشفة: ${foundColumns.isNotEmpty ? foundColumns : 'لا يوجد'}\n'
                           'تأكد من أن ملف الإكسل يحتوي على أعمدة للمنتج والسعر والكمية';
        throw Exception(errorMessage);
      }
    }

    AppLogger.info('تم اكتشاف جميع الأعمدة المطلوبة بنجاح');
    AppLogger.info('خريطة الأعمدة: $columnMapping');

    AppLogger.info('تم العثور على رأس الجدول في الصف ${headerRowIndex + 1}');
    AppLogger.info('تم تحديد الأعمدة: $columnMapping');

    // Enhanced data extraction with performance optimization and safe bounds
    final int maxRowsToProcess = [sheet.maxRows, MAX_ROWS_TO_PROCESS].reduce((a, b) => a < b ? a : b);
    AppLogger.info('بدء استخراج البيانات من الصف ${headerRowIndex + 2} إلى $maxRowsToProcess (محدود بـ $MAX_ROWS_TO_PROCESS)');

    const int batchSize = 100; // Process in batches for better performance
    int totalProcessed = 0;
    int validRows = 0;

    for (int batchStart = headerRowIndex + 1; batchStart < maxRowsToProcess; batchStart += batchSize) {
      final batchEnd = (batchStart + batchSize).clamp(0, maxRowsToProcess);

      // Process batch
      for (int rowIndex = batchStart; rowIndex < batchEnd; rowIndex++) {
        totalProcessed++;

        try {
          final row = _getSafeRow(sheet, rowIndex);
          if (row.isEmpty) {
            skippedRows++;
            continue;
          }

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

          // Enhanced quantity parsing with debugging
          final quantityStr = _getCellValue(row, columnMapping['quantity']);
          AppLogger.info('الصف ${rowIndex + 1}: قراءة الكمية من العمود ${columnMapping['quantity']}: "$quantityStr"');
          final quantity = _parseQuantity(quantityStr);
          AppLogger.info('الصف ${rowIndex + 1}: الكمية المحللة: $quantity');
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

  /// Validate Excel sheet dimensions and structure to prevent column limit errors
  bool _validateSheetStructure(excel.Sheet sheet) {
    try {
      // Check if sheet exists and has data
      if (sheet.maxRows <= 0) {
        AppLogger.warning('الورقة فارغة أو لا تحتوي على صفوف');
        return false;
      }

      // Validate row count is within reasonable limits
      if (sheet.maxRows > MAX_ROWS_TO_PROCESS) {
        AppLogger.warning('عدد الصفوف كبير جداً: ${sheet.maxRows}. سيتم معالجة أول $MAX_ROWS_TO_PROCESS صف فقط');
      }

      // Try to access the first row safely to validate sheet structure
      if (sheet.maxRows > 0) {
        final firstRow = sheet.row(0);
        if (firstRow.length > EXCEL_MAX_COLUMNS) {
          AppLogger.error('عدد الأعمدة يتجاوز الحد الأقصى المسموح: ${firstRow.length}');
          return false;
        }
      }

      AppLogger.info('تم التحقق من بنية الورقة: ${sheet.maxRows} صف');
      return true;
    } catch (e) {
      AppLogger.error('خطأ في التحقق من بنية الورقة: $e');
      return false;
    }
  }

  /// Enhanced cell value cleaning for comprehensive matching
  /// Supports case insensitivity, special character handling, and normalization
  String _cleanCellValue(String value) {
    return value
        .trim()
        .toLowerCase()
        // Normalize whitespace first
        .replaceAll(RegExp(r'\s+'), ' ')
        // Remove special characters but preserve Arabic text, parentheses, and basic punctuation
        .replaceAll(RegExp(r'[^\w\u0600-\u06FF\s()_-]'), '')
        // Replace underscores and hyphens with spaces for better word matching
        .replaceAll(RegExp(r'[_-]'), ' ')
        // Normalize whitespace again after replacements
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Enhanced similarity calculation with comprehensive matching strategies
  /// Supports exact matching, partial matching, word-based matching, and fuzzy matching
  double _calculateAdvancedSimilarity(String text1, String text2) {
    final clean1 = _cleanCellValue(text1);
    final clean2 = _cleanCellValue(text2);

    // Exact match gets highest score
    if (clean1 == clean2) return 1.0;

    // Split into words for advanced matching
    final words1 = clean1.split(' ').where((w) => w.isNotEmpty).toList();
    final words2 = clean2.split(' ').where((w) => w.isNotEmpty).toList();

    // Single word matching with partial support
    if (words2.length == 1) {
      final targetWord = words2.first;
      for (final word in words1) {
        // Exact word match
        if (word == targetWord) return 0.95;

        // Partial matching for abbreviations and variations
        if (word.startsWith(targetWord) && targetWord.length >= 3) {
          return 0.85; // e.g., "prod" matches "product"
        }
        if (targetWord.startsWith(word) && word.length >= 3) {
          return 0.80; // e.g., "qty" matches "quantity"
        }

        // Contains matching for compound words
        if (word.contains(targetWord) && targetWord.length >= 4) {
          return 0.75;
        }
        if (targetWord.contains(word) && word.length >= 4) {
          return 0.75;
        }
      }
    }

    // Multi-word phrase matching
    if (words2.length > 1) {
      int exactMatches = 0;
      int partialMatches = 0;

      for (final targetWord in words2) {
        bool foundMatch = false;
        for (final word in words1) {
          if (word == targetWord) {
            exactMatches++;
            foundMatch = true;
            break;
          } else if ((word.startsWith(targetWord) && targetWord.length >= 3) ||
                     (targetWord.startsWith(word) && word.length >= 3) ||
                     (word.contains(targetWord) && targetWord.length >= 4) ||
                     (targetWord.contains(word) && word.length >= 4)) {
            partialMatches++;
            foundMatch = true;
            break;
          }
        }
      }

      final totalWords = words2.length;
      final matchRatio = (exactMatches + partialMatches * 0.7) / totalWords;

      if (matchRatio >= 0.8) {
        return 0.90 + (exactMatches / totalWords) * 0.05;
      } else if (matchRatio >= 0.5) {
        return 0.70 + matchRatio * 0.15;
      }
    }

    // Fallback to traditional similarity algorithms
    // Contains match (moderate score)
    if (clean1.contains(clean2) || clean2.contains(clean1)) {
      final longer = clean1.length > clean2.length ? clean1 : clean2;
      final shorter = clean1.length <= clean2.length ? clean1 : clean2;
      return 0.60 + (shorter.length / longer.length) * 0.20;
    }

    // Levenshtein similarity
    final levenshteinSim = _calculateSimilarity(clean1, clean2);

    // Jaccard similarity (word-based)
    final jaccardSim = _calculateJaccardSimilarity(clean1, clean2);

    // Weighted combination with threshold
    final combinedSim = (levenshteinSim * 0.6) + (jaccardSim * 0.4);

    // Only return meaningful similarities
    return combinedSim >= 0.3 ? combinedSim : 0.0;
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

  /// Find quantity column by analyzing content for numeric patterns
  int _findQuantityColumnByContent(Worksheet sheet, int headerRowIndex) {
    try {
      final maxColumnsToCheck = [sheet.maxColumns, MAX_COLUMNS_TO_SCAN].reduce((a, b) => a < b ? a : b);
      final maxRowsToCheck = [sheet.maxRows, headerRowIndex + 20].reduce((a, b) => a < b ? a : b);

      for (int colIndex = 0; colIndex < maxColumnsToCheck; colIndex++) {
        int numericCount = 0;
        int totalCount = 0;

        // Check several rows after header to see if this column contains mostly numbers
        for (int rowIndex = headerRowIndex + 1; rowIndex < maxRowsToCheck && totalCount < 10; rowIndex++) {
          final row = _getSafeRow(sheet, rowIndex);
          if (colIndex < row.length) {
            final cellValue = _getCellValue(row, colIndex);
            if (cellValue.isNotEmpty) {
              totalCount++;
              // Check if this looks like a quantity (small positive integer)
              final cleaned = cellValue.replaceAll(RegExp(r'[^\d.]'), '');
              final parsed = double.tryParse(cleaned);
              if (parsed != null && parsed > 0 && parsed <= 9999 && parsed == parsed.round()) {
                numericCount++;
              }
            }
          }
        }

        // If more than 70% of values in this column are valid quantities, consider it a quantity column
        if (totalCount >= 3 && numericCount / totalCount >= 0.7) {
          AppLogger.info('عمود محتمل للكمية في الموضع $colIndex: $numericCount/$totalCount قيم رقمية صحيحة');
          return colIndex;
        }
      }

      return -1;
    } catch (e) {
      AppLogger.error('خطأ في البحث عن عمود الكمية: $e');
      return -1;
    }
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

  /// Safely access Excel row with bounds checking to prevent column limit errors
  List<dynamic> _getSafeRow(excel.Sheet sheet, int rowIndex) {
    try {
      if (rowIndex < 0 || rowIndex >= sheet.maxRows) {
        return [];
      }
      final row = sheet.row(rowIndex);
      // Limit row length to prevent column limit errors
      if (row.length > MAX_COLUMNS_TO_SCAN) {
        return row.take(MAX_COLUMNS_TO_SCAN).toList();
      }
      return row;
    } catch (e) {
      AppLogger.warning('خطأ في الوصول للصف $rowIndex: $e');
      return [];
    }
  }

  /// Get cell value safely from Excel row
  String _getCellValue(List<dynamic> row, int? columnIndex) {
    if (columnIndex == null || columnIndex >= row.length || columnIndex >= MAX_COLUMNS_TO_SCAN) {
      return '';
    }

    try {
      final cell = row[columnIndex];
      if (cell?.value == null) {
        return '';
      }

      return cell!.value.toString().trim();
    } catch (e) {
      AppLogger.warning('خطأ في قراءة الخلية في العمود $columnIndex: $e');
      return '';
    }
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

    // Enhanced comprehensive column name variations for flexible fuzzy matching
    // Supports case insensitivity, partial matching, and extensive variations
    final Map<String, List<String>> columnVariations = {
      'product_name': [
        // Complete phrases
        'product name', 'item name', 'product description', 'item description',
        'product title', 'item title', 'goods name', 'merchandise name',
        'article name', 'commodity name', 'product info', 'item info',
        'product details', 'item details', 'part number', 'model number',

        // Single words and abbreviations
        'product', 'item', 'name', 'title', 'label', 'description', 'desc',
        'goods', 'merchandise', 'article', 'commodity', 'material', 'stuff',
        'sku', 'model', 'part', 'code', 'id', 'identifier', 'ref', 'reference',

        // Variations with underscores and concatenations
        'product_name', 'productname', 'item_name', 'itemname', 'product_title',
        'producttitle', 'item_title', 'itemtitle', 'part_number', 'partnumber',
        'model_number', 'modelnumber', 'product_code', 'productcode',
        'item_code', 'itemcode', 'product_id', 'productid', 'item_id', 'itemid',

        // Abbreviated forms
        'prod', 'itm', 'prd', 'pname', 'iname', 'pcode', 'icode', 'pid', 'iid',

        // Arabic variations
        'اسم المنتج', 'المنتج', 'البضاعة', 'السلعة', 'الصنف', 'النوع', 'العنصر',
        'الوصف', 'التسمية', 'الاسم', 'المادة', 'القطعة', 'الموديل', 'العنوان',
        'التفاصيل', 'البيانات', 'المعلومات', 'الكود', 'الرقم المرجعي', 'المرجع'
      ],

      'quantity': [
        // Complete phrases and single words
        'quantity', 'total quantity', 'item quantity', 'order quantity',
        'purchase quantity', 'number of items', 'number of pieces',
        'pieces count', 'units count', 'items count', 'ordered quantity',
        'required quantity', 'requested quantity', 'shipped quantity',
        'qty', 'pcs', 'pieces', 'units', 'count', 'amount', 'number', 'num',
        'total', 'sum', 'volume', 'size', 'pack', 'box', 'carton', 'dozen',
        'gross', 'each', 'nos', 'numbers', 'items', 'stock', 'inventory',

        // Abbreviated forms
        'ea', 'pc', 'unit', 'ct', 'cnt', '#', 'no', 'qnty', 'qtty', 'q',

        // Common Excel column headers
        'column1', 'column2', 'column3', 'column4', 'column5', 'column6',
        'col1', 'col2', 'col3', 'col4', 'col5', 'col6',
        'field1', 'field2', 'field3', 'field4', 'field5', 'field6',

        // Common misspellings and variations
        'quantiy', 'quanity', 'quantitiy', 'qantity', 'quntity',
        'qtyy', 'qtty', 'qnty', 'qntyy',

        // Arabic variations
        'الكمية', 'عدد', 'كمية', 'المقدار', 'العدد', 'الرقم', 'القطع', 'الوحدات',
        'المجموع', 'الإجمالي', 'الحجم', 'الصناديق', 'الكراتين', 'العبوات',

        // Chinese variations for international files
        '数量', '总数量', '总量', '件数', '个数', '数目',

        // Other language variations
        'cantidad', 'quantité', 'quantità', 'quantidade', 'menge', 'aantal'
      ],

      'yuan_price': [
        // Complete phrases with currency
        'unit price', 'price per unit', 'unit cost', 'cost per unit',
        'unit price (rmb)', 'unit price (yuan)', 'unit price (cny)',
        'price in yuan', 'cost in yuan', 'yuan price', 'rmb price',
        'cny price', 'chinese yuan price', 'price per piece',

        // Single words
        'price', 'cost', 'rate', 'value', 'amount', 'fee', 'charge',
        'yuan', 'rmb', 'cny', 'renminbi', 'pricing', 'costing',

        // Variations with underscores
        'unit_price', 'unit_cost', 'price_yuan', 'yuan_price', 'rmb_price',
        'cny_price', 'chinese_yuan', 'price_per_unit', 'cost_per_unit',

        // Arabic variations
        'السعر', 'سعر الوحدة', 'ثمن', 'التكلفة', 'المبلغ', 'القيمة', 'الرسوم',
        'سعر اليوان', 'اليوان الصيني', 'الرنمينبي', 'سعر القطعة', 'تكلفة الوحدة'
      ],

      'product_image': [
        // Complete phrases and single words
        'product image', 'item image', 'product picture', 'item picture',
        'product photo', 'item photo', 'image url', 'picture url', 'photo url',
        'image', 'images', 'picture', 'pictures', 'photo', 'photos', 'pic', 'pics',
        'img', 'photograph', 'snapshot', 'shot', 'figure', 'illustration',
        'graphic', 'visual', 'thumbnail', 'preview', 'gallery', 'media',

        // Variations with underscores
        'product_image', 'productimage', 'item_image', 'itemimage',
        'image_url', 'imageurl', 'picture_url', 'pictureurl', 'photo_url', 'photourl',

        // Arabic variations
        'صورة', 'الصورة', 'صور', 'الصور', 'لقطة', 'تصوير', 'رسم', 'مرئي',
        'معرض', 'وسائط', 'ملف مرئي', 'صورة المنتج', 'رابط الصورة'
      ],
    };

    // Find header row
    int headerRowIndex = -1;
    Map<String, int> columnMapping = {};

    // Safe header scanning with bounds checking
    final maxRowsToScan = [sheet.maxRows, 50].reduce((a, b) => a < b ? a : b);
    for (int rowIndex = 0; rowIndex < maxRowsToScan; rowIndex++) {
      try {
        final row = sheet.row(rowIndex);
        if (row.isEmpty) continue;

        final potentialMapping = <String, int>{};

        // Safe column scanning with bounds checking
        final maxColsToScan = [row.length, 100].reduce((a, b) => a < b ? a : b);
        for (int colIndex = 0; colIndex < maxColsToScan; colIndex++) {
        final cell = row[colIndex];
        if (cell?.value == null) continue;

        final cellValue = cell!.value.toString().toLowerCase().trim();

        if (cellValue.isNotEmpty) {
          for (final entry in columnVariations.entries) {
            final columnKey = entry.key;
            final variations = entry.value;

            for (final variation in variations) {
              final similarity = _calculateAdvancedSimilarityStatic(cellValue, variation);
              if (similarity >= 0.75) { // 75% similarity threshold for enhanced matching
                potentialMapping[columnKey] = colIndex;
                break;
              }
            }
          }
        }
      }

        // FIXED: Now requires quantity column to be detected as well
        if (potentialMapping.containsKey('product_name') &&
            potentialMapping.containsKey('yuan_price') &&
            potentialMapping.containsKey('quantity')) {
          headerRowIndex = rowIndex;
          columnMapping = potentialMapping;
          break;
        }
      } catch (e) {
        // Skip problematic rows during header scanning
        continue;
      }
    }

    if (headerRowIndex == -1) {
      throw Exception('لم يتم العثور على أعمدة البيانات المطلوبة (اسم المنتج، السعر، والكمية)');
    }

    // FIXED: Validate that all required columns are detected
    if (!columnMapping.containsKey('product_name') ||
        !columnMapping.containsKey('yuan_price') ||
        !columnMapping.containsKey('quantity')) {
      throw Exception('لم يتم العثور على جميع الأعمدة المطلوبة');
    }

    // Extract data from rows after header with safe bounds
    final maxRowsToProcess = [sheet.maxRows, 10000].reduce((a, b) => a < b ? a : b);
    for (int rowIndex = headerRowIndex + 1; rowIndex < maxRowsToProcess; rowIndex++) {
      try {
        final row = sheet.row(rowIndex);
        if (row.isEmpty) continue;

        // Limit row length to prevent column access errors
        final safeRow = row.length > 100 ? row.take(100).toList() : row;

        if (safeRow.isEmpty || safeRow.every((cell) => cell?.value == null || cell!.value.toString().trim().isEmpty)) {
          continue;
        }

        final productName = _getCellValueStatic(safeRow, columnMapping['product_name']);
        final yuanPriceStr = _getCellValueStatic(safeRow, columnMapping['yuan_price']);

        if (productName.isEmpty || yuanPriceStr.isEmpty) {
          continue;
        }

        final yuanPrice = _parsePriceStatic(yuanPriceStr);
        if (yuanPrice <= 0) continue;

        final quantityStr = _getCellValueStatic(safeRow, columnMapping['quantity']);
        final quantity = _parseQuantityStatic(quantityStr);

        final productImage = _getCellValueStatic(safeRow, columnMapping['product_image']);

        extractedData.add({
          'product_name': productName.trim(),
          'quantity': quantity,
          'yuan_price': yuanPrice,
          'product_image': productImage.isNotEmpty ? productImage.trim() : null,
        });

      } catch (e) {
        // Skip problematic rows and continue processing
        continue;
      }
    }

    return extractedData;
  }

  /// Static helper methods for isolate processing
  /// Enhanced static similarity calculation for isolate processing
  /// Supports comprehensive matching strategies including partial and word-based matching
  static double _calculateAdvancedSimilarityStatic(String text1, String text2) {
    // Enhanced cleaning with better normalization
    final clean1 = text1
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\u0600-\u06FF\s()_-]'), '')
        .replaceAll(RegExp(r'[_-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final clean2 = text2
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\u0600-\u06FF\s()_-]'), '')
        .replaceAll(RegExp(r'[_-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Exact match gets highest score
    if (clean1 == clean2) return 1.0;

    // Split into words for advanced matching
    final words1 = clean1.split(' ').where((w) => w.isNotEmpty).toList();
    final words2 = clean2.split(' ').where((w) => w.isNotEmpty).toList();

    // Single word matching with partial support
    if (words2.length == 1) {
      final targetWord = words2.first;
      for (final word in words1) {
        // Exact word match
        if (word == targetWord) return 0.95;

        // Partial matching for abbreviations and variations
        if (word.startsWith(targetWord) && targetWord.length >= 3) {
          return 0.85; // e.g., "prod" matches "product"
        }
        if (targetWord.startsWith(word) && word.length >= 3) {
          return 0.80; // e.g., "qty" matches "quantity"
        }

        // Contains matching for compound words
        if (word.contains(targetWord) && targetWord.length >= 4) {
          return 0.75;
        }
        if (targetWord.contains(word) && word.length >= 4) {
          return 0.75;
        }
      }
    }

    // Multi-word phrase matching
    if (words2.length > 1) {
      int exactMatches = 0;
      int partialMatches = 0;

      for (final targetWord in words2) {
        for (final word in words1) {
          if (word == targetWord) {
            exactMatches++;
            break;
          } else if ((word.startsWith(targetWord) && targetWord.length >= 3) ||
                     (targetWord.startsWith(word) && word.length >= 3) ||
                     (word.contains(targetWord) && targetWord.length >= 4) ||
                     (targetWord.contains(word) && word.length >= 4)) {
            partialMatches++;
            break;
          }
        }
      }

      final totalWords = words2.length;
      final matchRatio = (exactMatches + partialMatches * 0.7) / totalWords;

      if (matchRatio >= 0.8) {
        return 0.90 + (exactMatches / totalWords) * 0.05;
      } else if (matchRatio >= 0.5) {
        return 0.70 + matchRatio * 0.15;
      }
    }

    // Contains match (moderate score)
    if (clean1.contains(clean2) || clean2.contains(clean1)) {
      final longer = clean1.length > clean2.length ? clean1 : clean2;
      final shorter = clean1.length <= clean2.length ? clean1 : clean2;
      return 0.60 + (shorter.length / longer.length) * 0.20;
    }

    // Return 0 for no meaningful match
    return 0.0;
  }

  static String _getCellValueStatic(List<dynamic> row, int? columnIndex) {
    if (columnIndex == null || columnIndex >= row.length || columnIndex >= 100) return '';
    try {
      final cell = row[columnIndex];
      if (cell?.value == null) return '';
      return cell!.value.toString().trim();
    } catch (e) {
      return '';
    }
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
