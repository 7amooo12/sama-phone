import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/models/flask_product_model.dart';

/// Professional PDF Export Service for Comprehensive Reports
/// Provides high-quality PDF generation with Arabic text support and chart rendering
class ProfessionalPdfExportService {
  static const String _fontFamily = 'Cairo';
  static const double _pageMargin = 40.0;
  static const double _headerHeight = 80.0;
  static const double _footerHeight = 40.0;
  
  // PDF Color scheme matching AccountantThemeConfig
  static final PdfColor _primaryGreen = PdfColor.fromHex('#10B981');
  static final PdfColor _secondaryGreen = PdfColor.fromHex('#059669');
  static final PdfColor _accentBlue = PdfColor.fromHex('#3B82F6');
  static final PdfColor _darkBackground = PdfColor.fromHex('#1F2937');
  static final PdfColor _cardBackground = PdfColor.fromHex('#374151');
  static final PdfColor _textPrimary = PdfColor.fromHex('#FFFFFF');
  static final PdfColor _textSecondary = PdfColor.fromHex('#D1D5DB');

  /// Export product analytics report to PDF
  static Future<String> exportProductReport({
    required FlaskProductModel product,
    required Map<String, dynamic> analytics,
    required List<Uint8List> chartImages,
    required String userInfo,
    Function(double)? onProgress,
  }) async {
    try {
      AppLogger.info('🔄 Starting PDF export for product: ${product.name}');
      onProgress?.call(0.1);

      final pdf = pw.Document(
        title: 'تقرير تحليل المنتج - ${product.name}',
        author: 'Sama Business',
        creator: 'Sama Business Professional Reports',
        subject: 'Product Analytics Report',
      );

      // Load Cairo font for Arabic support
      final fontData = await _loadCairoFont();
      onProgress?.call(0.2);

      final font = pw.Font.ttf(fontData);
      final boldFont = pw.Font.ttf(fontData); // In production, load bold variant

      onProgress?.call(0.3);

      // Generate PDF pages
      await _addProductReportPages(
        pdf: pdf,
        product: product,
        analytics: analytics,
        chartImages: chartImages,
        userInfo: userInfo,
        font: font,
        boldFont: boldFont,
        onProgress: (progress) => onProgress?.call(0.3 + (progress * 0.5)),
      );

      onProgress?.call(0.8);

      // Save PDF to file
      final filePath = await _savePdfToFile(
        pdf: pdf,
        fileName: 'product_report_${product.name}_${_getTimestamp()}.pdf',
      );

      onProgress?.call(1.0);
      AppLogger.info('✅ PDF export completed: $filePath');
      return filePath;

    } catch (e) {
      AppLogger.error('❌ PDF export failed: $e');
      rethrow;
    }
  }

  /// Export category analytics report to PDF with enhanced chart integration
  static Future<String> exportCategoryReport({
    required String category,
    required Map<String, dynamic> analytics,
    required List<Uint8List> chartImages,
    required String userInfo,
    Function(double)? onProgress,
    List<FlaskProductModel>? categoryProducts, // Added for product images
  }) async {
    try {
      AppLogger.info('🔄 Starting PDF export for category: $category');
      onProgress?.call(0.1);

      // Validate content before proceeding
      if (!_validatePdfContent(analytics: analytics, chartImages: chartImages)) {
        throw Exception('PDF content validation failed');
      }

      final pdf = pw.Document(
        title: 'تقرير تحليل الفئة - $category',
        author: 'Sama Business',
        creator: 'Sama Business Professional Reports',
        subject: 'Category Analytics Report',
      );

      final fontData = await _loadCairoFont();
      onProgress?.call(0.2);

      final font = pw.Font.ttf(fontData);
      final boldFont = pw.Font.ttf(fontData);

      onProgress?.call(0.3);

      // Process and optimize chart images
      final optimizedChartImages = chartImages
          .map((imageData) => _optimizeImageForPdf(imageData))
          .toList();

      AppLogger.info('📊 Processing ${optimizedChartImages.length} chart images for PDF');

      await _addCategoryReportPages(
        pdf: pdf,
        category: category,
        analytics: analytics,
        chartImages: optimizedChartImages,
        userInfo: userInfo,
        font: font,
        boldFont: boldFont,
        categoryProducts: categoryProducts,
        onProgress: (progress) => onProgress?.call(0.3 + (progress * 0.5)),
      );

      onProgress?.call(0.8);

      final filePath = await _savePdfToFile(
        pdf: pdf,
        fileName: 'category_report_${category}_${_getTimestamp()}.pdf',
      );

      onProgress?.call(1.0);
      AppLogger.info('✅ PDF export completed: $filePath');
      return filePath;

    } catch (e) {
      AppLogger.error('❌ PDF export failed: $e');
      rethrow;
    }
  }

  /// Export overall business analytics report to PDF
  static Future<String> exportOverallReport({
    required Map<String, dynamic> analytics,
    required List<Uint8List> chartImages,
    required String userInfo,
    Function(double)? onProgress,
  }) async {
    try {
      AppLogger.info('🔄 Starting PDF export for overall analytics');
      onProgress?.call(0.1);

      final pdf = pw.Document(
        title: 'التقرير الشامل للأعمال',
        author: 'Sama Business',
        creator: 'Sama Business Professional Reports',
        subject: 'Overall Business Analytics Report',
      );

      final fontData = await _loadCairoFont();
      onProgress?.call(0.2);

      final font = pw.Font.ttf(fontData);
      final boldFont = pw.Font.ttf(fontData);

      onProgress?.call(0.3);

      await _addOverallReportPages(
        pdf: pdf,
        analytics: analytics,
        chartImages: chartImages,
        userInfo: userInfo,
        font: font,
        boldFont: boldFont,
        onProgress: (progress) => onProgress?.call(0.3 + (progress * 0.5)),
      );

      onProgress?.call(0.8);

      final filePath = await _savePdfToFile(
        pdf: pdf,
        fileName: 'overall_report_${_getTimestamp()}.pdf',
      );

      onProgress?.call(1.0);
      AppLogger.info('✅ PDF export completed: $filePath');
      return filePath;

    } catch (e) {
      AppLogger.error('❌ PDF export failed: $e');
      rethrow;
    }
  }

  /// Share PDF file with native sharing dialog - opens immediately
  static Future<bool> sharePdf(String filePath, {String? customMessage}) async {
    try {
      // Check if file exists before attempting to share
      final file = File(filePath);
      if (!await file.exists()) {
        AppLogger.error('❌ PDF file not found for sharing: $filePath');
        return false;
      }

      AppLogger.info('📤 PDF sharing initiated for: $filePath');

      // Use Share.shareXFiles to open native sharing dialog immediately
      try {
        final fileName = filePath.split(Platform.pathSeparator).last;
        final message = customMessage ?? 'تقرير Sama Business - $fileName\n\nيرجى العثور على التقرير المرفق بصيغة PDF';

        // Open native sharing dialog immediately
        await Share.shareXFiles(
          [XFile(filePath)],
          subject: 'تقرير Sama Business - $fileName',
          text: message,
        );

        AppLogger.info('✅ Native sharing dialog opened successfully');
        return true;

      } catch (shareError) {
        AppLogger.warning('⚠️ Native sharing failed, trying fallback: $shareError');

        // Fallback: Copy to Downloads folder
        try {
          final fileName = filePath.split(Platform.pathSeparator).last;
          final downloadsPath = await _getDownloadsDirectory();
          if (downloadsPath != null) {
            final targetPath = '${downloadsPath.path}${Platform.pathSeparator}$fileName';
            await file.copy(targetPath);
            AppLogger.info('📁 PDF copied to Downloads as fallback: $targetPath');
            return true;
          }
        } catch (copyError) {
          AppLogger.error('❌ Fallback copy also failed: $copyError');
        }

        return false;
      }

    } catch (e) {
      AppLogger.error('❌ Failed to share PDF: $e');
      return false;
    }
  }

  /// Get Downloads directory (fallback for sharing)
  static Future<Directory?> _getDownloadsDirectory() async {
    try {
      if (Platform.isAndroid) {
        // Try to get external storage directory
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final downloadsDir = Directory('${externalDir.path}/Download');
          if (await downloadsDir.exists()) {
            return downloadsDir;
          }
        }
      }
      return null;
    } catch (e) {
      AppLogger.warning('⚠️ Could not access Downloads directory: $e');
      return null;
    }
  }

  /// Enhanced widget capture for PDF inclusion with better error handling
  static Future<Uint8List> captureWidgetAsImage(
    GlobalKey key, {
    double pixelRatio = 3.0,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      AppLogger.info('📸 Capturing widget as image with pixel ratio: $pixelRatio');

      // Wait for the widget to be rendered
      await Future.delayed(const Duration(milliseconds: 100));

      final context = key.currentContext;
      if (context == null) {
        throw Exception('Widget context is null - widget may not be mounted');
      }

      final RenderRepaintBoundary? boundary =
          context.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('RenderRepaintBoundary not found - ensure widget is wrapped with RepaintBoundary');
      }

      // Check if boundary needs painting
      if (boundary.debugNeedsPaint) {
        AppLogger.warning('⚠️ Boundary needs painting, waiting...');
        await Future.delayed(const Duration(milliseconds: 200));
      }

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to convert image to byte data');
      }

      final imageBytes = byteData.buffer.asUint8List();
      AppLogger.info('✅ Widget captured successfully: ${imageBytes.length} bytes');

      return imageBytes;
    } catch (e) {
      AppLogger.error('❌ Failed to capture widget as image: $e');
      rethrow;
    }
  }

  /// Capture multiple widgets as images for charts
  static Future<List<Uint8List>> captureMultipleWidgets(
    List<GlobalKey> keys, {
    double pixelRatio = 3.0,
    Function(int, int)? onProgress,
  }) async {
    final List<Uint8List> images = [];

    for (int i = 0; i < keys.length; i++) {
      try {
        onProgress?.call(i, keys.length);
        final imageData = await captureWidgetAsImage(keys[i], pixelRatio: pixelRatio);
        images.add(imageData);
        AppLogger.info('📊 Captured chart ${i + 1}/${keys.length}');
      } catch (e) {
        AppLogger.error('❌ Failed to capture chart ${i + 1}: $e');
        // Continue with other charts instead of failing completely
      }
    }

    AppLogger.info('✅ Captured ${images.length}/${keys.length} charts successfully');
    return images;
  }

  /// Download product image from URL for PDF inclusion
  static Future<Uint8List?> _downloadProductImage(String imageUrl) async {
    try {
      AppLogger.info('📸 Downloading product image: $imageUrl');

      final response = await http.get(
        Uri.parse(imageUrl),
        headers: {
          'User-Agent': 'SAMA-BUSINESS-PDF-Generator/1.0',
          'Accept': 'image/*',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        AppLogger.info('✅ Successfully downloaded image (${response.bodyBytes.length} bytes)');
        return response.bodyBytes;
      } else {
        AppLogger.warning('⚠️ Failed to download image: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      AppLogger.error('❌ Error downloading product image: $e');
      return null;
    }
  }

  /// Fix and validate image URL for PDF generation
  static String? _fixImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty || imageUrl == 'null') {
      return null;
    }

    // If URL is complete, use as is
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }

    // If relative path, add full path
    if (imageUrl.startsWith('/')) {
      return 'https://samastock.pythonanywhere.com$imageUrl';
    }

    // If just filename, add full path
    return 'https://samastock.pythonanywhere.com/static/uploads/$imageUrl';
  }

  /// Load product image for PDF inclusion
  static Future<Uint8List?> _loadProductImageForPdf(FlaskProductModel product) async {
    try {
      if (product.imageUrl == null || product.imageUrl!.isEmpty) {
        return null;
      }

      final fixedUrl = _fixImageUrl(product.imageUrl!);
      if (fixedUrl == null) {
        return null;
      }

      return await _downloadProductImage(fixedUrl);
    } catch (e) {
      AppLogger.error('❌ Failed to load product image for PDF: $e');
      return null;
    }
  }

  // Private helper methods
  static Future<ByteData> _loadCairoFont() async {
    try {
      // Try to load Cairo font from assets for proper Arabic text rendering
      final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      AppLogger.info('✅ Cairo font loaded successfully for PDF generation');
      return fontData;
    } catch (e) {
      AppLogger.warning('⚠️ Cairo font not found, attempting fallback fonts');

      // Try alternative font paths
      try {
        return await rootBundle.load('assets/fonts/Cairo.ttf');
      } catch (e2) {
        try {
          return await rootBundle.load('fonts/Cairo-Regular.ttf');
        } catch (e3) {
          AppLogger.error('❌ No Arabic fonts found, using system default');
          // Create a minimal font data for fallback
          return ByteData.view(Uint8List(0).buffer);
        }
      }
    }
  }

  /// Optimize PDF for file size while maintaining quality
  static pw.Document _createOptimizedPdfDocument({
    required String title,
    required String author,
    required String subject,
  }) {
    return pw.Document(
      title: title,
      author: author,
      creator: 'Sama Business Professional Reports v1.0',
      subject: subject,
      keywords: 'تقارير, تحليلات, Sama Business',
      producer: 'Sama Business PDF Engine',
      compress: true, // Enable compression for smaller file sizes
      // version: PdfVersion.pdf_1_7, // Use modern PDF version - commented out due to import issues
    );
  }

  /// Validate PDF content before generation with enhanced chart validation
  static bool _validatePdfContent({
    required Map<String, dynamic> analytics,
    required List<Uint8List> chartImages,
  }) {
    // Check if analytics data is valid
    if (analytics.isEmpty) {
      AppLogger.warning('⚠️ PDF validation: Analytics data is empty');
      return false;
    }

    // Enhanced chart images validation
    for (int i = 0; i < chartImages.length; i++) {
      final imageData = chartImages[i];
      if (imageData.isEmpty) {
        AppLogger.warning('⚠️ PDF validation: Chart image $i is empty');
        return false;
      }

      // Check minimum image size (should be at least 1KB for quality)
      if (imageData.length < 1024) {
        AppLogger.warning('⚠️ PDF validation: Chart image $i is too small (${imageData.length} bytes)');
        return false; // Changed to false to prevent corrupted charts
      }

      // Validate PNG header to ensure image integrity
      if (!_isValidPngImage(imageData)) {
        AppLogger.warning('⚠️ PDF validation: Chart image $i is not a valid PNG');
        return false;
      }
    }

    AppLogger.info('✅ PDF content validation passed with ${chartImages.length} valid charts');
    return true;
  }

  /// Validate PNG image header
  static bool _isValidPngImage(Uint8List imageData) {
    if (imageData.length < 8) return false;

    // PNG signature: 89 50 4E 47 0D 0A 1A 0A
    final pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    for (int i = 0; i < 8; i++) {
      if (imageData[i] != pngSignature[i]) {
        return false;
      }
    }
    return true;
  }

  /// Optimize image quality for PDF inclusion
  static Uint8List _optimizeImageForPdf(Uint8List imageData) {
    try {
      // For now, return the original image data
      // In a production environment, you might want to:
      // 1. Compress images to optimal size
      // 2. Convert to appropriate format (PNG/JPEG)
      // 3. Ensure proper DPI (300 DPI for print quality)

      AppLogger.info('📸 Image optimized for PDF: ${imageData.length} bytes');
      return imageData;
    } catch (e) {
      AppLogger.error('❌ Failed to optimize image: $e');
      return imageData;
    }
  }

  static String _getTimestamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }

  static Future<String> _savePdfToFile({
    required pw.Document pdf,
    required String fileName,
  }) async {
    try {
      // Get the app's documents directory
      final directory = await getApplicationDocumentsDirectory();

      // Sanitize the filename to remove invalid characters
      final sanitizedFileName = _sanitizeFileName(fileName);

      // Create the full file path using platform-appropriate path separator
      final filePath = '${directory.path}${Platform.pathSeparator}$sanitizedFileName';

      // Ensure the directory exists (in case of nested paths)
      final file = File(filePath);
      final parentDir = file.parent;

      if (!await parentDir.exists()) {
        AppLogger.info('📁 Creating directory: ${parentDir.path}');
        await parentDir.create(recursive: true);
      }

      // Generate PDF bytes
      final pdfBytes = await pdf.save();

      // Write the PDF file
      await file.writeAsBytes(pdfBytes);

      AppLogger.info('✅ PDF saved successfully: $filePath');
      return file.path;

    } catch (e) {
      AppLogger.error('❌ Failed to save PDF file: $e');

      // Try fallback with simplified filename
      try {
        final directory = await getApplicationDocumentsDirectory();
        final fallbackFileName = 'report_${_getTimestamp()}.pdf';
        final fallbackPath = '${directory.path}${Platform.pathSeparator}$fallbackFileName';
        final fallbackFile = File(fallbackPath);

        await fallbackFile.writeAsBytes(await pdf.save());
        AppLogger.info('✅ PDF saved with fallback name: $fallbackPath');
        return fallbackFile.path;

      } catch (fallbackError) {
        AppLogger.error('❌ Fallback PDF save also failed: $fallbackError');
        rethrow;
      }
    }
  }

  /// Sanitize filename to remove invalid characters for file system
  static String _sanitizeFileName(String fileName) {
    // Remove or replace invalid characters for file names
    String sanitized = fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_') // Replace invalid chars with underscore
        .replaceAll(RegExp(r'\s+'), '_') // Replace spaces with underscore
        .replaceAll(RegExp(r'_{2,}'), '_') // Replace multiple underscores with single
        .replaceAll(RegExp(r'^_+|_+$'), ''); // Remove leading/trailing underscores

    // Ensure the filename is not empty and has reasonable length
    if (sanitized.isEmpty) {
      sanitized = 'report_${_getTimestamp()}';
    }

    // Limit filename length (most filesystems support 255 chars, but let's be safe)
    if (sanitized.length > 200) {
      final extension = sanitized.substring(sanitized.lastIndexOf('.'));
      sanitized = '${sanitized.substring(0, 200 - extension.length)}$extension';
    }

    AppLogger.info('📝 Sanitized filename: "$fileName" -> "$sanitized"');
    return sanitized;
  }

  // Page generation methods
  static Future<void> _addProductReportPages({
    required pw.Document pdf,
    required FlaskProductModel product,
    required Map<String, dynamic> analytics,
    required List<Uint8List> chartImages,
    required String userInfo,
    required pw.Font font,
    required pw.Font boldFont,
    Function(double)? onProgress,
  }) async {
    onProgress?.call(0.1);

    // Page 1: Cover and Product Overview
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(_pageMargin),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPdfHeader(
                title: 'تقرير تحليل المنتج',
                subtitle: product.name,
                userInfo: userInfo,
                font: font,
                boldFont: boldFont,
              ),
              pw.SizedBox(height: 30),
              _buildProductOverviewSection(product, analytics, font, boldFont),
              pw.Spacer(),
              _buildPdfFooter(font),
            ],
          );
        },
      ),
    );

    onProgress?.call(0.5);

    // Page 2: Analytics and Charts
    if (chartImages.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(_pageMargin),
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('التحليلات والمخططات', font, boldFont),
                pw.SizedBox(height: 20),
                ...chartImages.map((imageData) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 20),
                  child: pw.Image(pw.MemoryImage(imageData)),
                )),
                pw.Spacer(),
                _buildPdfFooter(font),
              ],
            );
          },
        ),
      );
    }

    onProgress?.call(1.0);
  }

  // PDF Layout Helper Methods
  static pw.Widget _buildPdfHeader({
    required String title,
    required String subtitle,
    required String userInfo,
    required pw.Font font,
    required pw.Font boldFont,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [_primaryGreen, _secondaryGreen],
        ),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Sama Business',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 24,
                  color: _textPrimary,
                ),
              ),
              pw.Text(
                '${DateTime.now().year}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().day.toString().padLeft(2, '0')} - ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 12,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            title,
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 20,
              color: _textPrimary,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            subtitle,
            style: pw.TextStyle(
              font: font,
              fontSize: 16,
              color: _textSecondary,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'تم إنشاؤه بواسطة: $userInfo',
            style: pw.TextStyle(
              font: font,
              fontSize: 10,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfFooter(pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _primaryGreen, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Sama Business - نظام إدارة الأعمال الذكي',
            style: pw.TextStyle(
              font: font,
              fontSize: 10,
              color: _textSecondary,
            ),
          ),
          pw.Text(
            'صفحة 1',
            style: pw.TextStyle(
              font: font,
              fontSize: 10,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionHeader(
    String title,
    pw.Font font,
    pw.Font boldFont,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: _cardBackground,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _primaryGreen, width: 1),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          font: boldFont,
          fontSize: 18,
          color: _textPrimary,
        ),
      ),
    );
  }

  static pw.Widget _buildProductOverviewSection(
    FlaskProductModel product,
    Map<String, dynamic> analytics,
    pw.Font font,
    pw.Font boldFont,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: _cardBackground,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _accentBlue, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'معلومات المنتج',
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 16,
              color: _textPrimary,
            ),
          ),
          pw.SizedBox(height: 15),
          _buildInfoRow('اسم المنتج:', product.name, font, boldFont),
          _buildInfoRow('الفئة:', product.category, font, boldFont),
          _buildInfoRow('السعر:', '${product.finalPrice} ج.م', font, boldFont),
          _buildInfoRow('الكمية المتاحة:', '${product.stockQuantity}', font, boldFont),
          if (analytics.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'إحصائيات الأداء',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 16,
                color: _textPrimary,
              ),
            ),
            pw.SizedBox(height: 10),
            ...analytics.entries.map((entry) =>
              _buildInfoRow('${entry.key}:', '${entry.value}', font, boldFont),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildInfoRow(
    String label,
    String value,
    pw.Font font,
    pw.Font boldFont,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                font: font,
                fontSize: 12,
                color: _textSecondary,
              ),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              value,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 12,
                color: _textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _addCategoryReportPages({
    required pw.Document pdf,
    required String category,
    required Map<String, dynamic> analytics,
    required List<Uint8List> chartImages,
    required String userInfo,
    required pw.Font font,
    required pw.Font boldFont,
    List<FlaskProductModel>? categoryProducts,
    Function(double)? onProgress,
  }) async {
    onProgress?.call(0.1);

    // Page 1: Category Overview
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(_pageMargin),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPdfHeader(
                title: 'تقرير تحليل الفئة',
                subtitle: category,
                userInfo: userInfo,
                font: font,
                boldFont: boldFont,
              ),
              pw.SizedBox(height: 30),
              _buildCategoryOverviewSection(category, analytics, font, boldFont),
              pw.Spacer(),
              _buildPdfFooter(font),
            ],
          );
        },
      ),
    );

    onProgress?.call(0.5);

    // Page 2: Enhanced Charts and Analytics
    if (chartImages.isNotEmpty) {
      AppLogger.info('📊 Adding ${chartImages.length} charts to category PDF');

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(_pageMargin),
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('تحليلات الفئة والمخططات', font, boldFont),
                pw.SizedBox(height: 20),

                // Enhanced chart display with better layout
                ...chartImages.asMap().entries.map((entry) {
                  final index = entry.key;
                  final imageData = entry.value;

                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 25),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _accentBlue, width: 1),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      children: [
                        // Chart title
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.all(10),
                          decoration: pw.BoxDecoration(
                            color: _primaryGreen,
                            borderRadius: const pw.BorderRadius.only(
                              topLeft: pw.Radius.circular(8),
                              topRight: pw.Radius.circular(8),
                            ),
                          ),
                          child: pw.Text(
                            'مخطط ${index + 1} - تحليل الفئة',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 12,
                              color: _textPrimary,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        // Chart image with proper sizing
                        pw.Container(
                          padding: const pw.EdgeInsets.all(15),
                          child: pw.Center(
                            child: pw.Image(
                              pw.MemoryImage(imageData),
                              fit: pw.BoxFit.contain,
                              width: 450, // Fixed width for consistency
                              height: 300, // Fixed height for consistency
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                pw.Spacer(),
                _buildPdfFooter(font),
              ],
            );
          },
        ),
      );
    }

    // Page 3: Product Images (if available)
    if (categoryProducts != null && categoryProducts.isNotEmpty) {
      onProgress?.call(0.7);
      await _addProductImagesPage(
        pdf: pdf,
        products: categoryProducts,
        font: font,
        boldFont: boldFont,
        title: 'منتجات الفئة - $category',
      );
    }

    onProgress?.call(1.0);
  }

  static Future<void> _addOverallReportPages({
    required pw.Document pdf,
    required Map<String, dynamic> analytics,
    required List<Uint8List> chartImages,
    required String userInfo,
    required pw.Font font,
    required pw.Font boldFont,
    Function(double)? onProgress,
  }) async {
    onProgress?.call(0.1);

    // Page 1: Business Overview
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(_pageMargin),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPdfHeader(
                title: 'التقرير الشامل للأعمال',
                subtitle: 'نظرة عامة على الأداء',
                userInfo: userInfo,
                font: font,
                boldFont: boldFont,
              ),
              pw.SizedBox(height: 30),
              _buildOverallAnalyticsSection(analytics, font, boldFont),
              pw.Spacer(),
              _buildPdfFooter(font),
            ],
          );
        },
      ),
    );

    onProgress?.call(0.5);

    // Page 2: Charts and Detailed Analytics
    if (chartImages.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(_pageMargin),
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('المخططات والتحليلات التفصيلية', font, boldFont),
                pw.SizedBox(height: 20),
                ...chartImages.map((imageData) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 20),
                  child: pw.Image(pw.MemoryImage(imageData)),
                )),
                pw.Spacer(),
                _buildPdfFooter(font),
              ],
            );
          },
        ),
      );
    }

    onProgress?.call(1.0);
  }

  /// Add product images page to PDF
  static Future<void> _addProductImagesPage({
    required pw.Document pdf,
    required List<FlaskProductModel> products,
    required pw.Font font,
    required pw.Font boldFont,
    required String title,
  }) async {
    try {
      AppLogger.info('📸 Adding product images page with ${products.length} products');

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(_pageMargin),
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(title, font, boldFont),
                pw.SizedBox(height: 20),

                // Product grid layout
                pw.Wrap(
                  spacing: 15,
                  runSpacing: 15,
                  children: products.map((product) { // Display ALL products without limitation
                    return pw.Container(
                      width: 160,
                      height: 200,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: _accentBlue, width: 1),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        children: [
                          // Product image - actual image or placeholder
                          pw.Container(
                            width: 140,
                            height: 100,
                            margin: const pw.EdgeInsets.all(10),
                            decoration: pw.BoxDecoration(
                              color: _cardBackground,
                              borderRadius: pw.BorderRadius.circular(6),
                            ),
                            child: pw.Center(
                              child: pw.Column(
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  pw.Icon(
                                    pw.IconData(0xe3f4), // Icons.image
                                    size: 24,
                                    color: _textSecondary,
                                  ),
                                  pw.SizedBox(height: 4),
                                  pw.Text(
                                    'صورة المنتج',
                                    style: pw.TextStyle(
                                      font: font,
                                      fontSize: 8,
                                      color: _textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Product details
                          pw.Expanded(
                            child: pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    product.name,
                                    style: pw.TextStyle(
                                      font: boldFont,
                                      fontSize: 10,
                                      color: _textPrimary,
                                    ),
                                    maxLines: 2,
                                    overflow: pw.TextOverflow.clip,
                                  ),
                                  pw.SizedBox(height: 4),
                                  pw.Text(
                                    '${product.finalPrice} ج.م',
                                    style: pw.TextStyle(
                                      font: font,
                                      fontSize: 9,
                                      color: _primaryGreen,
                                    ),
                                  ),
                                  pw.Text(
                                    'الكمية: ${product.stockQuantity}',
                                    style: pw.TextStyle(
                                      font: font,
                                      fontSize: 8,
                                      color: _textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                pw.Spacer(),
                _buildPdfFooter(font),
              ],
            );
          },
        ),
      );
    } catch (e) {
      AppLogger.error('❌ Failed to add product images page: $e');
    }
  }

  static pw.Widget _buildCategoryOverviewSection(
    String category,
    Map<String, dynamic> analytics,
    pw.Font font,
    pw.Font boldFont,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: _cardBackground,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _accentBlue, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'تحليل الفئة',
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 16,
              color: _textPrimary,
            ),
          ),
          pw.SizedBox(height: 15),
          _buildInfoRow('اسم الفئة:', category, font, boldFont),
          if (analytics.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'إحصائيات الأداء',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 16,
                color: _textPrimary,
              ),
            ),
            pw.SizedBox(height: 10),
            ...analytics.entries.map((entry) =>
              _buildInfoRow('${entry.key}:', '${entry.value}', font, boldFont),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildOverallAnalyticsSection(
    Map<String, dynamic> analytics,
    pw.Font font,
    pw.Font boldFont,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: _cardBackground,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _accentBlue, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'نظرة عامة على الأعمال',
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 16,
              color: _textPrimary,
            ),
          ),
          pw.SizedBox(height: 15),
          if (analytics.isNotEmpty) ...[
            ...analytics.entries.map((entry) =>
              _buildInfoRow('${entry.key}:', '${entry.value}', font, boldFont),
            ),
          ] else ...[
            pw.Text(
              'لا توجد بيانات متاحة حالياً',
              style: pw.TextStyle(
                font: font,
                fontSize: 12,
                color: _textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
