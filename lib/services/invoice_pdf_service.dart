import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../models/invoice_models.dart';
import '../utils/app_logger.dart';

class InvoicePdfService {
  factory InvoicePdfService() => _instance;
  InvoicePdfService._internal();
  static final InvoicePdfService _instance = InvoicePdfService._internal();

  // Cache for loaded images
  final Map<String, pw.ImageProvider> _imageCache = {};

  // Font cache with fallback support
  pw.Font? _arabicFont;
  pw.Font? _arabicBoldFont;
  pw.Font? _fallbackFont;
  pw.Font? _fallbackBoldFont;
  bool _fontsLoaded = false;
  bool _usingFallbackFonts = false;

  // Updated currency format to use EGP instead of Arabic
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'EGP ',
    decimalDigits: 2,
  );

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy', 'en');

  /// Load fonts for PDF generation with robust fallback mechanism
  Future<void> _loadFonts() async {
    if (_fontsLoaded) return;

    try {
      AppLogger.info('🔤 Loading fonts for PDF generation...');

      // First, try to load Arabic fonts
      await _tryLoadArabicFonts();

      // If Arabic fonts failed, use fallback fonts
      if (_arabicFont == null || _arabicBoldFont == null) {
        AppLogger.warning('⚠️ Arabic fonts not available, using fallback fonts');
        await _loadFallbackFonts();
      }

      _fontsLoaded = true;
      AppLogger.info('✅ Fonts loaded successfully (Arabic: ${!_usingFallbackFonts}, Fallback: $_usingFallbackFonts)');
    } catch (e) {
      AppLogger.error('❌ Failed to load fonts: $e');
      // Continue with default PDF fonts
      _fontsLoaded = true;
    }
  }

  /// Try to load Arabic Cairo fonts
  Future<void> _tryLoadArabicFonts() async {
    try {
      // Check if font files exist and are valid
      final regularFontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      final boldFontData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');

      // Validate font data (basic check for TTF header)
      if (_isValidTTFFont(regularFontData) && _isValidTTFFont(boldFontData)) {
        _arabicFont = pw.Font.ttf(regularFontData);
        _arabicBoldFont = pw.Font.ttf(boldFontData);
        AppLogger.info('✅ Arabic Cairo fonts loaded successfully');
      } else {
        throw Exception('Invalid TTF font files detected');
      }
    } catch (e) {
      AppLogger.warning('⚠️ Failed to load Arabic fonts: $e');
      _arabicFont = null;
      _arabicBoldFont = null;
    }
  }

  /// Load fallback fonts using Google Fonts
  Future<void> _loadFallbackFonts() async {
    try {
      AppLogger.info('📦 Loading fallback fonts...');

      // Use Google Fonts for fallback (supports Arabic)
      final http.Response regularResponse = await http.get(
        Uri.parse('https://fonts.gstatic.com/s/cairo/v30/SLXgc1nY6HkvangtZmpQdkhzfH5lkSs2SgRjCAGMQ1z0hOA-W1Q.ttf'),
        headers: {'User-Agent': 'SAMA-BUSINESS-PDF-Generator/1.0'},
      ).timeout(const Duration(seconds: 10));

      final http.Response boldResponse = await http.get(
        Uri.parse('https://fonts.gstatic.com/s/cairo/v30/SLXgc1nY6HkvangtZmpQdkhzfH5lkSs2SgRjCAGMQ1z0hAc5W1Q.ttf'),
        headers: {'User-Agent': 'SAMA-BUSINESS-PDF-Generator/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (regularResponse.statusCode == 200 && boldResponse.statusCode == 200) {
        _arabicFont = pw.Font.ttf(ByteData.view(regularResponse.bodyBytes.buffer));
        _arabicBoldFont = pw.Font.ttf(ByteData.view(boldResponse.bodyBytes.buffer));
        _usingFallbackFonts = true;
        AppLogger.info('✅ Fallback fonts loaded from Google Fonts');
      } else {
        throw Exception('Failed to download fallback fonts');
      }
    } catch (e) {
      AppLogger.warning('⚠️ Failed to load fallback fonts: $e');
      // Use default PDF fonts as last resort
      _arabicFont = null;
      _arabicBoldFont = null;
      _usingFallbackFonts = true;
    }
  }

  /// Validate if ByteData contains a valid TTF font
  bool _isValidTTFFont(ByteData fontData) {
    try {
      // Check for TTF magic number (0x00010000) or TrueType Collection (0x74746366)
      if (fontData.lengthInBytes < 4) return false;

      final firstFourBytes = fontData.getUint32(0, Endian.big);
      return firstFourBytes == 0x00010000 || // TTF
             firstFourBytes == 0x74746366 || // TTC
             firstFourBytes == 0x4F54544F;   // OTF
    } catch (e) {
      return false;
    }
  }

  /// Get regular font with fallback to null (uses default PDF font)
  pw.Font? _getRegularFont() => _arabicFont;

  /// Get bold font with fallback to null (uses default PDF font)
  pw.Font? _getBoldFont() => _arabicBoldFont;

  /// Generate PDF for invoice
  Future<Uint8List> generateInvoicePdf(Invoice invoice) async {
    try {
      AppLogger.info('إنشاء PDF للفاتورة: ${invoice.id}');

      // Load fonts first (with fallback support)
      await _loadFonts();

      // Pre-load all product images
      await _preloadProductImages(invoice);

      final pdf = pw.Document();

      // Add page with invoice content
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          textDirection: pw.TextDirection.rtl, // Changed to RTL for Arabic support
          theme: _arabicFont != null && _arabicBoldFont != null
              ? pw.ThemeData.withFont(
                  base: _arabicFont!,
                  bold: _arabicBoldFont!,
                )
              : pw.ThemeData.base(), // Use default theme if fonts not available
          build: (pw.Context context) {
            return [
              _buildProfessionalHeader(invoice),
              pw.SizedBox(height: 30),
              _buildInvoiceDetails(invoice),
              pw.SizedBox(height: 20),
              _buildCustomerInfo(invoice),
              pw.SizedBox(height: 25),
              _buildItemsTableWithImages(invoice),
              pw.SizedBox(height: 20),
              _buildTotals(invoice),
              pw.SizedBox(height: 40),
              _buildProfessionalFooter(invoice),
            ];
          },
        ),
      );

      final pdfBytes = await pdf.save();
      AppLogger.info('تم إنشاء PDF بنجاح');
      return pdfBytes;
    } catch (e) {
      AppLogger.error('خطأ في إنشاء PDF: $e');
      rethrow;
    } finally {
      // Clear image cache to free memory
      _clearImageCache();
    }
  }

  /// Clear image cache to free memory
  void _clearImageCache() {
    _imageCache.clear();
    AppLogger.info('🧹 Image cache cleared');
  }

  /// Save PDF to device storage
  Future<String?> savePdfToDevice(Uint8List pdfBytes, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      AppLogger.info('تم حفظ PDF في: ${file.path}');
      return file.path;
    } catch (e) {
      AppLogger.error('خطأ في حفظ PDF: $e');
      return null;
    }
  }

  /// Save and share PDF
  Future<Map<String, dynamic>> saveAndSharePdf(Uint8List pdfBytes, String invoiceId) async {
    try {
      final fileName = 'invoice_${invoiceId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = await savePdfToDevice(pdfBytes, fileName);

      if (filePath != null) {
        return {
          'success': true,
          'filePath': filePath,
          'message': 'PDF saved successfully'
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to save PDF'
        };
      }
    } catch (e) {
      AppLogger.error('Error saving and sharing PDF: $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}'
      };
    }
  }

  /// Build professional PDF header
  pw.Widget _buildProfessionalHeader(Invoice invoice) {
    return pw.Container(
      child: pw.Column(
        children: [
          // Company branding section
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: pw.BoxDecoration(
              gradient: const pw.LinearGradient(
                colors: [PdfColors.blue900, PdfColors.blue700],
              ),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'شركة سما',
                      style: pw.TextStyle(
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        font: _getBoldFont(),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'SAMA BUSINESS',
                      style: pw.TextStyle(
                        fontSize: 18,
                        color: PdfColors.blue100,
                        fontWeight: pw.FontWeight.normal,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Email: samatsock01@gmail.com | Phone: +20 100 066 4780',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.blue200,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'فاتورة',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                          font: _getBoldFont(),
                        ),
                      ),
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build invoice details section
  pw.Widget _buildInvoiceDetails(Invoice invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'رقم الفاتورة',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                  font: _getBoldFont(),
                ),
              ),
              pw.Text(
                'Invoice Number',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                invoice.id,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'تاريخ الفاتورة',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                  font: _getBoldFont(),
                ),
              ),
              pw.Text(
                'Invoice Date',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                _dateFormat.format(invoice.createdAt),
                style: const pw.TextStyle(fontSize: 14),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'الحالة',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                  font: _getBoldFont(),
                ),
              ),
              pw.Text(
                'Status',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: _getStatusColor(invoice.status),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  _getStatusText(invoice.status),
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build customer information section
  pw.Widget _buildCustomerInfo(Invoice invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.blue200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(
                'فاتورة إلى',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                  font: _getBoldFont(),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Text(
                'BILL TO',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildBilingualInfoRow('اسم العميل:', 'Customer Name:', invoice.customerName),
                    if (invoice.customerPhone != null)
                      _buildBilingualInfoRow('الهاتف:', 'Phone:', invoice.customerPhone!),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (invoice.customerEmail != null)
                      _buildBilingualInfoRow('البريد الإلكتروني:', 'Email:', invoice.customerEmail!),
                    if (invoice.customerAddress != null)
                      _buildBilingualInfoRow('العنوان:', 'Address:', invoice.customerAddress!),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build items table with product images
  pw.Widget _buildItemsTableWithImages(Invoice invoice) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Text(
              'الأصناف والخدمات',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
                font: _getBoldFont(),
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Text(
              'ITEMS & SERVICES',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue700,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
          columnWidths: {
            0: const pw.FlexColumnWidth(0.5), // #
            1: const pw.FlexColumnWidth(1),   // Image
            2: const pw.FlexColumnWidth(2.5), // Description
            3: const pw.FlexColumnWidth(1),   // Qty
            4: const pw.FlexColumnWidth(1.5), // Unit Price
            5: const pw.FlexColumnWidth(1.5), // Total
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blue900),
              children: [
                _buildBilingualTableCell('#', '#', isHeader: true, textColor: PdfColors.white),
                _buildBilingualTableCell('صورة', 'IMAGE', isHeader: true, textColor: PdfColors.white),
                _buildBilingualTableCell('الوصف', 'DESCRIPTION', isHeader: true, textColor: PdfColors.white),
                _buildBilingualTableCell('الكمية', 'QTY', isHeader: true, textColor: PdfColors.white),
                _buildBilingualTableCell('سعر الوحدة', 'UNIT PRICE', isHeader: true, textColor: PdfColors.white),
                _buildBilingualTableCell('الإجمالي', 'TOTAL', isHeader: true, textColor: PdfColors.white),
              ],
            ),
            // Data rows with images
            ...invoice.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: index % 2 == 0 ? PdfColors.grey50 : PdfColors.white,
                ),
                children: [
                  _buildTableCell((index + 1).toString()),
                  _buildImageCell(item.productImage),
                  _buildTableCell(item.productName, alignment: pw.Alignment.centerLeft),
                  _buildTableCell(item.quantity.toString()),
                  _buildTableCell(_currencyFormat.format(item.unitPrice)),
                  _buildTableCell(_currencyFormat.format(item.subtotal)),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  /// Build items table (fallback without images)
  pw.Widget _buildItemsTable(Invoice invoice) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ITEMS & SERVICES',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
          columnWidths: {
            0: const pw.FlexColumnWidth(0.5), // #
            1: const pw.FlexColumnWidth(3),   // Description
            2: const pw.FlexColumnWidth(1),   // Qty
            3: const pw.FlexColumnWidth(1.5), // Unit Price
            4: const pw.FlexColumnWidth(1.5), // Total
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blue900),
              children: [
                _buildTableCell('#', isHeader: true, textColor: PdfColors.white),
                _buildTableCell('DESCRIPTION', isHeader: true, textColor: PdfColors.white),
                _buildTableCell('QTY', isHeader: true, textColor: PdfColors.white),
                _buildTableCell('UNIT PRICE', isHeader: true, textColor: PdfColors.white),
                _buildTableCell('TOTAL', isHeader: true, textColor: PdfColors.white),
              ],
            ),
            // Data rows
            ...invoice.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: index % 2 == 0 ? PdfColors.grey50 : PdfColors.white,
                ),
                children: [
                  _buildTableCell((index + 1).toString()),
                  _buildTableCell(item.productName, alignment: pw.Alignment.centerLeft),
                  _buildTableCell(item.quantity.toString()),
                  _buildTableCell(_currencyFormat.format(item.unitPrice)),
                  _buildTableCell(_currencyFormat.format(item.subtotal)),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  /// Build totals section
  pw.Widget _buildTotals(Invoice invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          _buildBilingualTotalRow('المجموع الفرعي:', 'Subtotal:', invoice.subtotal),
          if (invoice.discount > 0)
            _buildBilingualTotalRow('الخصم:', 'Discount:', -invoice.discount, color: PdfColors.red),
          pw.Divider(color: PdfColors.grey400, thickness: 1),
          _buildBilingualTotalRow(
            'المبلغ الإجمالي:',
            'Total Amount:',
            invoice.totalAmount,
            isTotal: true,
          ),
        ],
      ),
    );
  }

  /// Build footer
  pw.Widget _buildFooter(Invoice invoice) {
    return pw.Column(
      children: [
        if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.blue200),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Notes:',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  invoice.notes!,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
        ],
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 10),
        pw.Text(
          'Thank you for your business',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.green800,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'This invoice was generated by Smart Business Tracker',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  /// Helper method to build info rows
  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
          pw.SizedBox(width: 8),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  /// Helper method to build bilingual info rows
  pw.Widget _buildBilingualInfoRow(String arabicLabel, String englishLabel, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(
                arabicLabel,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  font: _getBoldFont(),
                ),
              ),
              pw.SizedBox(width: 5),
              pw.Text(
                englishLabel,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              font: _getRegularFont(),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper method to build image cells for product images
  pw.Widget _buildImageCell(String? imageUrl) {
    final fixedImageUrl = _fixImageUrl(imageUrl);
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      alignment: pw.Alignment.center,
      height: 50,
      child: fixedImageUrl != null
          ? _buildProductImageSync(fixedImageUrl)
          : _buildPlaceholderImage(),
    );
  }

  /// Fix and validate image URL for PDF generation
  String? _fixImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty || imageUrl == 'null') {
      return null;
    }

    // إذا كان URL كاملاً، استخدمه كما هو
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }

    // إذا كان مسار نسبي، أضف المسار الكامل
    if (imageUrl.startsWith('/')) {
      return 'https://samastock.pythonanywhere.com$imageUrl';
    }

    // إذا كان اسم ملف فقط، أضف المسار الكامل
    return 'https://samastock.pythonanywhere.com/static/uploads/$imageUrl';
  }

  /// Build product image synchronously for PDF
  pw.Widget _buildProductImageSync(String imageUrl) {
    // Check if image is cached
    final cachedImage = _imageCache[imageUrl];
    if (cachedImage != null) {
      return pw.Container(
        width: 40,
        height: 40,
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Image(
          cachedImage,
          fit: pw.BoxFit.cover,
        ),
      );
    }

    // Fallback to enhanced placeholder with image indicator
    return pw.Container(
      width: 40,
      height: 40,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.green600, width: 1.5),
        color: PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Container(
            width: 16,
            height: 16,
            decoration: pw.BoxDecoration(
              color: PdfColors.green600,
              borderRadius: pw.BorderRadius.circular(2),
            ),
            child: pw.Center(
              child: pw.Text(
                '📷',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.white,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'صورة',
            style: pw.TextStyle(
              fontSize: 6,
              color: PdfColors.green700,
              fontWeight: pw.FontWeight.bold,
              font: _getRegularFont(),
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build placeholder image when no product image is available
  pw.Widget _buildPlaceholderImage() {
    return pw.Container(
      width: 40,
      height: 40,
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Center(
        child: pw.Text(
          'No\nImage',
          style: const pw.TextStyle(
            fontSize: 8,
            color: PdfColors.grey600,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  /// Pre-load all product images for PDF generation
  Future<void> _preloadProductImages(Invoice invoice) async {
    try {
      AppLogger.info('🖼️ Pre-loading product images for PDF generation...');

      final imageUrls = invoice.items
          .map((item) => _fixImageUrl(item.productImage))
          .where((url) => url != null)
          .cast<String>()
          .toSet(); // Remove duplicates

      if (imageUrls.isEmpty) {
        AppLogger.info('No product images to load');
        return;
      }

      AppLogger.info('Loading ${imageUrls.length} unique product images...');

      for (final imageUrl in imageUrls) {
        try {
          final imageBytes = await _downloadImage(imageUrl);
          if (imageBytes != null) {
            _imageCache[imageUrl] = pw.MemoryImage(imageBytes);
            AppLogger.info('✅ Loaded image: $imageUrl');
          }
        } catch (e) {
          AppLogger.warning('⚠️ Failed to load image $imageUrl: $e');
        }
      }

      AppLogger.info('✅ Pre-loaded ${_imageCache.length} product images');
    } catch (e) {
      AppLogger.error('❌ Error pre-loading images: $e');
    }
  }

  /// Download image from URL
  Future<Uint8List?> _downloadImage(String imageUrl) async {
    try {
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: {
          'User-Agent': 'SAMA-BUSINESS-PDF-Generator/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        AppLogger.warning('Failed to download image: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      AppLogger.error('Error downloading image: $e');
      return null;
    }
  }

  /// Helper method to build table cells
  pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    PdfColor? textColor,
    pw.Alignment? alignment,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      alignment: alignment ?? pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor ?? (isHeader ? PdfColors.blue900 : PdfColors.black),
          font: _getRegularFont(),
        ),
        textAlign: alignment == pw.Alignment.centerLeft
            ? pw.TextAlign.left
            : pw.TextAlign.center,
      ),
    );
  }

  /// Helper method to build bilingual table cells
  pw.Widget _buildBilingualTableCell(
    String arabicText,
    String englishText, {
    bool isHeader = false,
    PdfColor? textColor,
    pw.Alignment? alignment,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      alignment: alignment ?? pw.Alignment.center,
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            arabicText,
            style: pw.TextStyle(
              fontSize: isHeader ? 11 : 9,
              fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: textColor ?? (isHeader ? PdfColors.white : PdfColors.black),
              font: isHeader ? _arabicBoldFont : _arabicFont,
            ),
            textAlign: pw.TextAlign.center,
          ),
          if (isHeader) pw.SizedBox(height: 2),
          pw.Text(
            englishText,
            style: pw.TextStyle(
              fontSize: isHeader ? 9 : 8,
              fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: textColor ?? (isHeader ? PdfColors.white : PdfColors.grey600),
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Helper method to build total rows
  pw.Widget _buildTotalRow(
    String label,
    double amount, {
    bool isTotal = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: isTotal ? 14 : 12,
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
              font: _getRegularFont(),
            ),
          ),
          pw.Text(
            _currencyFormat.format(amount),
            style: pw.TextStyle(
              fontSize: isTotal ? 14 : 12,
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color ?? (isTotal ? PdfColors.green800 : null),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper method to build bilingual total rows
  pw.Widget _buildBilingualTotalRow(
    String arabicLabel,
    String englishLabel,
    double amount, {
    bool isTotal = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                arabicLabel,
                style: pw.TextStyle(
                  fontSize: isTotal ? 14 : 12,
                  fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: color,
                  font: isTotal ? _arabicBoldFont : _arabicFont,
                ),
              ),
              pw.Text(
                englishLabel,
                style: pw.TextStyle(
                  fontSize: isTotal ? 11 : 10,
                  color: color ?? PdfColors.grey600,
                ),
              ),
            ],
          ),
          pw.Text(
            _currencyFormat.format(amount),
            style: pw.TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color ?? (isTotal ? PdfColors.green800 : null),
            ),
          ),
        ],
      ),
    );
  }

  /// Get status text in English
  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'PENDING';
      case 'completed':
        return 'COMPLETED';
      case 'cancelled':
        return 'CANCELLED';
      case 'draft':
        return 'DRAFT';
      default:
        return status.toUpperCase();
    }
  }

  /// Get status color
  PdfColor _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return PdfColors.orange;
      case 'completed':
        return PdfColors.green;
      case 'cancelled':
        return PdfColors.red;
      case 'draft':
        return PdfColors.blue;
      default:
        return PdfColors.grey;
    }
  }

  /// Build professional footer
  pw.Widget _buildProfessionalFooter(Invoice invoice) {
    return pw.Container(
      child: pw.Column(
        children: [
          pw.Divider(color: PdfColors.grey300, thickness: 2),
          pw.SizedBox(height: 20),

          // Thank you message
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'شكراً لثقتكم بنا!',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                    font: _getBoldFont(),
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  'Thank you for your business!',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue700,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'نقدر ثقتكم في شركة سما للأعمال لتلبية احتياجاتكم التجارية.',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.blue700,
                    font: _getRegularFont(),
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  'We appreciate your trust in SAMA BUSINESS for your business needs.',
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.blue600,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Company information
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'شركة سما',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                      font: _getBoldFont(),
                    ),
                  ),
                  pw.Text(
                    'SAMA BUSINESS',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700,
                    ),
                  ),
                  pw.Text(
                    'Professional Business Solutions',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'معلومات التواصل',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                      font: _getBoldFont(),
                    ),
                  ),
                  pw.Text(
                    'Contact Information',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700,
                    ),
                  ),
                  pw.Text(
                    'Email: samatsock01@gmail.com',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Phone: +20 100 066 4780',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 15),

          // Generated by message
          pw.Text(
            'This invoice was generated by SAMA BUSINESS Management System',
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey500,
              fontStyle: pw.FontStyle.italic,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }
}
