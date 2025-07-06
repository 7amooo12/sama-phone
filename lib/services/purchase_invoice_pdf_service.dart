import 'dart:typed_data';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:smartbiztracker_new/models/purchase_invoice_models.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Service for generating professional purchase invoice PDFs with green/teal theme
class PurchaseInvoicePdfService {
  static final PurchaseInvoicePdfService _instance = PurchaseInvoicePdfService._internal();
  factory PurchaseInvoicePdfService() => _instance;
  PurchaseInvoicePdfService._internal();

  // Font cache
  pw.Font? _arabicFont;
  pw.Font? _arabicBoldFont;
  bool _fontsLoaded = false;

  // Clean currency formatters without locale issues
  final NumberFormat _numberFormat = NumberFormat('#,##0.00', 'en_US');
  final NumberFormat _yuanFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: '¥',
    decimalDigits: 2,
  );

  /// Format EGP currency with clean display
  String _formatEgp(double amount) {
    return '${_numberFormat.format(amount)} جنيه';
  }

  /// Load product image from URL or local file path for PDF
  Future<pw.MemoryImage?> _loadProductImage(String? imagePath) async {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return null;
    }

    try {
      AppLogger.info('📷 تحميل صورة المنتج: $imagePath');

      // Check if it's a local file path
      if (_isLocalFilePath(imagePath)) {
        return await _loadLocalImage(imagePath);
      }

      // Handle URL
      final fixedUrl = _fixImageUrl(imagePath);
      if (fixedUrl == null) {
        AppLogger.warning('⚠️ رابط الصورة غير صالح: $imagePath');
        return null;
      }

      return await _loadImageFromUrl(fixedUrl);
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل صورة المنتج: $e');
      return null;
    }
  }

  /// Check if the path is a local file path
  bool _isLocalFilePath(String path) {
    // Check for common local file path patterns
    return path.startsWith('/') ||
           path.startsWith('file://') ||
           path.contains('/cache/') ||
           path.contains('/data/') ||
           (path.contains(':') && !path.startsWith('http'));
  }

  /// Load image from local file path
  Future<pw.MemoryImage?> _loadLocalImage(String filePath) async {
    try {
      // Remove file:// prefix if present
      final cleanPath = filePath.startsWith('file://')
          ? filePath.substring(7)
          : filePath;

      final file = File(cleanPath);

      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        AppLogger.info('✅ تم تحميل الصورة المحلية بنجاح: ${bytes.length} bytes');
        return pw.MemoryImage(bytes);
      } else {
        AppLogger.warning('⚠️ الملف المحلي غير موجود: $cleanPath');
        return null;
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل الصورة المحلية: $e');
      return null;
    }
  }

  /// Load image from URL
  Future<pw.MemoryImage?> _loadImageFromUrl(String imageUrl) async {
    try {
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: {
          'User-Agent': 'SAMA-PURCHASE-PDF-Generator/1.0',
          'Accept': 'image/*',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        AppLogger.info('✅ تم تحميل الصورة من الرابط بنجاح: ${response.bodyBytes.length} bytes');
        return pw.MemoryImage(response.bodyBytes);
      } else {
        AppLogger.warning('⚠️ فشل تحميل الصورة - كود الاستجابة: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل الصورة من الرابط: $e');
      return null;
    }
  }

  /// Fix and validate image URL for PDF generation
  String? _fixImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty || imageUrl == 'null') {
      return null;
    }

    // If it's already a complete URL, use it as is
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }

    // If it's a relative path, add the full path
    if (imageUrl.startsWith('/')) {
      return 'https://samastock.pythonanywhere.com$imageUrl';
    }

    // If it's just a filename, add the full path
    return 'https://samastock.pythonanywhere.com/static/uploads/$imageUrl';
  }

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy', 'ar');

  // Green/Teal color scheme for purchase invoices
  static const PdfColor primaryTeal = PdfColor.fromInt(0xFF14B8A6);
  static const PdfColor secondaryTeal = PdfColor.fromInt(0xFF0F766E);
  static const PdfColor lightTeal = PdfColor.fromInt(0xFF5EEAD4);
  static const PdfColor lightTealBackground = PdfColor.fromInt(0xFFF0FDFA); // Very light teal for backgrounds
  static const PdfColor darkTeal = PdfColor.fromInt(0xFF134E4A);
  static const PdfColor white = PdfColor.fromInt(0xFFFFFFFF);
  static const PdfColor black = PdfColor.fromInt(0xFF000000);
  static const PdfColor grey600 = PdfColor.fromInt(0xFF6B7280);

  /// Load fonts for PDF generation
  Future<void> _loadFonts() async {
    if (_fontsLoaded) return;

    try {
      AppLogger.info('🔤 Loading fonts for purchase invoice PDF...');

      // Load Arabic fonts from Google Fonts
      final regularResponse = await http.get(
        Uri.parse('https://fonts.gstatic.com/s/cairo/v30/SLXgc1nY6HkvangtZmpQdkhzfH5lkSs2SgRjCAGMQ1z0hOA-W1Q.ttf'),
        headers: {'User-Agent': 'SAMA-PURCHASE-PDF-Generator/1.0'},
      ).timeout(const Duration(seconds: 10));

      final boldResponse = await http.get(
        Uri.parse('https://fonts.gstatic.com/s/cairo/v30/SLXgc1nY6HkvangtZmpQdkhzfH5lkSs2SgRjCAGMQ1z0hAc5W1Q.ttf'),
        headers: {'User-Agent': 'SAMA-PURCHASE-PDF-Generator/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (regularResponse.statusCode == 200 && boldResponse.statusCode == 200) {
        _arabicFont = pw.Font.ttf(ByteData.view(regularResponse.bodyBytes.buffer));
        _arabicBoldFont = pw.Font.ttf(ByteData.view(boldResponse.bodyBytes.buffer));
        _fontsLoaded = true;
        AppLogger.info('✅ Fonts loaded successfully');
      }
    } catch (e) {
      AppLogger.warning('⚠️ Failed to load fonts, using default: $e');
      _fontsLoaded = true; // Continue with default fonts
    }
  }

  /// Generate PDF for purchase invoice
  Future<Uint8List> generatePurchaseInvoicePdf(PurchaseInvoice invoice) async {
    try {
      AppLogger.info('إنشاء PDF لفاتورة المشتريات: ${invoice.id}');

      await _loadFonts();

      // Load product images
      AppLogger.info('📷 تحميل صور المنتجات...');
      final Map<String, pw.MemoryImage?> productImages = {};
      for (final item in invoice.items) {
        if (item.productImage != null && item.productImage!.isNotEmpty) {
          productImages[item.id] = await _loadProductImage(item.productImage);
        }
      }
      AppLogger.info('✅ تم تحميل ${productImages.length} صورة منتج');

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          textDirection: pw.TextDirection.rtl,
          theme: _arabicFont != null && _arabicBoldFont != null
              ? pw.ThemeData.withFont(
                  base: _arabicFont!,
                  bold: _arabicBoldFont!,
                )
              : pw.ThemeData.base(),
          build: (pw.Context context) {
            final widgets = <pw.Widget>[
              _buildHeader(invoice),
              pw.SizedBox(height: 30),
              _buildInvoiceDetails(invoice),
              pw.SizedBox(height: 20),
              if (invoice.supplierName?.trim().isNotEmpty == true) ...[
                _buildSupplierInfo(invoice),
                pw.SizedBox(height: 25),
              ],
            ];

            // Add paginated items table
            widgets.addAll(_buildItemsTable(invoice, productImages));

            // Add final sections
            widgets.addAll([
              pw.SizedBox(height: 20),
              _buildCalculationBreakdown(invoice),
              pw.SizedBox(height: 40),
              _buildFooter(invoice),
            ]);

            return widgets;
          },
        ),
      );

      final pdfBytes = await pdf.save();
      AppLogger.info('✅ تم إنشاء PDF فاتورة المشتريات بنجاح');
      return pdfBytes;
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء PDF فاتورة المشتريات: $e');
      rethrow;
    }
  }

  /// Save PDF to device
  Future<String?> savePdfToDevice(Uint8List pdfBytes, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      AppLogger.info('✅ تم حفظ PDF في: ${file.path}');
      return file.path;
    } catch (e) {
      AppLogger.error('❌ خطأ في حفظ PDF: $e');
      return null;
    }
  }

  /// Generate and share purchase invoice PDF
  Future<bool> generateAndSharePurchaseInvoicePdf(PurchaseInvoice invoice) async {
    try {
      AppLogger.info('📤 بدء مشاركة فاتورة المشتريات: ${invoice.id}');

      // Generate PDF
      final pdfBytes = await generatePurchaseInvoicePdf(invoice);

      // Save to temporary directory for sharing
      final tempDir = await getTemporaryDirectory();
      final fileName = 'purchase_invoice_${invoice.id.split('-').last}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      // Check if file exists before sharing
      if (!await file.exists()) {
        AppLogger.error('❌ ملف PDF غير موجود للمشاركة: ${file.path}');
        return false;
      }

      // Prepare sharing message
      final invoiceNumber = invoice.id.split('-').last;
      final supplierName = invoice.supplierName ?? 'غير محدد';
      final totalAmount = _formatEgp(invoice.totalAmount);

      final message = '''فاتورة مشتريات من شركة سما
رقم الفاتورة: #$invoiceNumber
المورد: $supplierName
المبلغ الإجمالي: $totalAmount
التاريخ: ${_dateFormat.format(invoice.createdAt)}

يرجى العثور على فاتورة المشتريات المرفقة بصيغة PDF''';

      // Share using native sharing dialog
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'فاتورة مشتريات #$invoiceNumber - شركة سما',
        text: message,
      );

      AppLogger.info('✅ تم فتح نافذة المشاركة بنجاح');
      return true;

    } catch (e) {
      AppLogger.error('❌ خطأ في مشاركة فاتورة المشتريات: $e');
      return false;
    }
  }

  /// Build professional header with teal theme
  pw.Widget _buildHeader(PurchaseInvoice invoice) {
    return pw.Container(
      width: double.infinity,
      child: pw.Column(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(
              gradient: const pw.LinearGradient(
                colors: [primaryTeal, secondaryTeal],
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
                        color: white,
                        font: _getBoldFont(),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'SAMA BUSINESS',
                      style: pw.TextStyle(
                        fontSize: 18,
                        color: lightTeal,
                        fontWeight: pw.FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: white,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'فاتورة مشتريات',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryTeal,
                          font: _getBoldFont(),
                        ),
                      ),
                      pw.Text(
                        'PURCHASE INVOICE',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: secondaryTeal,
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
  pw.Widget _buildInvoiceDetails(PurchaseInvoice invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: lightTealBackground,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: lightTeal),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildDetailColumn('رقم الفاتورة', 'Invoice Number', invoice.id),
          _buildDetailColumn('تاريخ الفاتورة', 'Invoice Date', _dateFormat.format(invoice.createdAt)),
          _buildDetailColumn('الحالة', 'Status', _getStatusText(invoice.status)),
        ],
      ),
    );
  }

  /// Build supplier information section
  pw.Widget _buildSupplierInfo(PurchaseInvoice invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: lightTealBackground,
        border: pw.Border.all(color: lightTeal),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(
                'معلومات المورد',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryTeal,
                  font: _getBoldFont(),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Text(
                'SUPPLIER INFORMATION',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: secondaryTeal,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'اسم المورد: ${invoice.supplierName ?? 'غير محدد'}',
            style: pw.TextStyle(
              fontSize: 14,
              font: _getRegularFont(),
            ),
          ),
          pw.Text(
            'Supplier Name: ${invoice.supplierName ?? 'Not specified'}',
            style: const pw.TextStyle(
              fontSize: 12,
              color: grey600,
            ),
          ),
        ],
      ),
    );
  }

  /// Build items table with pagination to prevent TooManyPagesException
  List<pw.Widget> _buildItemsTable(PurchaseInvoice invoice, Map<String, pw.MemoryImage?> productImages) {
    const int itemsPerPage = 15; // Limit items per page to prevent overflow
    final List<pw.Widget> widgets = [];

    // Add header section
    widgets.add(
      pw.Row(
        children: [
          pw.Text(
            'تفاصيل المنتجات',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: primaryTeal,
              font: _getBoldFont(),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Text(
            'PRODUCT DETAILS',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: secondaryTeal,
            ),
          ),
        ],
      ),
    );

    widgets.add(pw.SizedBox(height: 12));

    // Split items into chunks to prevent page overflow
    final items = invoice.items;
    for (int i = 0; i < items.length; i += itemsPerPage) {
      final endIndex = (i + itemsPerPage).clamp(0, items.length);
      final pageItems = items.sublist(i, endIndex);

      // Add page break if not first page
      if (i > 0) {
        widgets.add(pw.NewPage());
        widgets.add(pw.SizedBox(height: 20));
      }

      // Build table for this page
      widgets.add(
        pw.Table(
          border: pw.TableBorder.all(color: lightTeal, width: 1),
          columnWidths: {
            0: const pw.FlexColumnWidth(0.4), // #
            1: const pw.FlexColumnWidth(0.8), // Product Image
            2: const pw.FlexColumnWidth(1.8), // Product Name
            3: const pw.FlexColumnWidth(0.8), // Quantity
            4: const pw.FlexColumnWidth(1.0), // RMB Price
            5: const pw.FlexColumnWidth(1.0), // Exchange Rate
            6: const pw.FlexColumnWidth(1.0), // Profit %
            7: const pw.FlexColumnWidth(1.2), // Unit Price
            8: const pw.FlexColumnWidth(1.4), // Total Price
          },
          children: [
            // Header row (repeat on each page)
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: primaryTeal),
              children: [
                _buildTableHeader('#'),
                _buildTableHeader('صورة\nImage'),
                _buildTableHeader('اسم المنتج\nProduct Name'),
                _buildTableHeader('الكمية\nQuantity'),
                _buildTableHeader('سعر الريمنبي\nRMB Price'),
                _buildTableHeader('سعر الصرف\nExchange Rate'),
                _buildTableHeader('الربح\nProfit %'),
                _buildTableHeader('سعر الوحدة\nUnit Price'),
                _buildTableHeader('إجمالي السعر\nTotal Price'),
              ],
            ),
            // Data rows for this page
            ...pageItems.asMap().entries.map((entry) {
              final pageIndex = entry.key;
              final globalIndex = i + pageIndex;
              final item = entry.value;
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: pageIndex % 2 == 0 ? lightTealBackground : white,
                ),
                children: [
                  _buildTableCell((globalIndex + 1).toString()),
                  _buildImageTableCell(productImages[item.id]),
                  _buildTableCell(item.productName, alignment: pw.Alignment.centerLeft),
                  _buildTableCell(item.quantity.toString()),
                  _buildTableCell(_yuanFormat.format(item.yuanPrice)),
                  _buildTableCell(item.exchangeRate.toStringAsFixed(2)),
                  _buildTableCell(
                    item.profitMarginPercent == 0.0
                        ? '0% (لا ربح)'
                        : '${item.profitMarginPercent.toStringAsFixed(1)}%'
                  ),
                  _buildTableCell(_formatEgp(item.finalEgpPrice)),
                  _buildTableCell(_formatEgp(item.totalPrice)),
                ],
              );
            }),
          ],
        ),
      );

      // Add page info if multiple pages
      if (items.length > itemsPerPage) {
        final currentPage = (i ~/ itemsPerPage) + 1;
        final totalPages = (items.length / itemsPerPage).ceil();
        widgets.add(pw.SizedBox(height: 10));
        widgets.add(
          pw.Text(
            'صفحة $currentPage من $totalPages - Page $currentPage of $totalPages',
            style: const pw.TextStyle(fontSize: 10, color: grey600),
            textAlign: pw.TextAlign.center,
          ),
        );
      }
    }

    return widgets;
  }

  /// Build calculation breakdown section
  pw.Widget _buildCalculationBreakdown(PurchaseInvoice invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: lightTealBackground,
        border: pw.Border.all(color: lightTeal),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'تفصيل الحسابات - Calculation Breakdown',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: primaryTeal,
              font: _getBoldFont(),
            ),
          ),
          pw.SizedBox(height: 12),
          _buildCalculationRow('إجمالي الكمية:', 'Total Quantity:', '${invoice.totalQuantity} قطعة'),
          _buildCalculationRow('إجمالي الريمنبي:', 'Total RMB:', _yuanFormat.format(invoice.totalYuanAmount)),
          _buildCalculationRow('متوسط سعر الصرف:', 'Avg Exchange Rate:', invoice.averageExchangeRate.toStringAsFixed(2)),
          _buildCalculationRow(
            'إجمالي الربح:',
            'Total Profit:',
            invoice.totalProfitAmount == 0.0
                ? 'لا يوجد ربح - No profit'
                : _formatEgp(invoice.totalProfitAmount)
          ),
          pw.Divider(color: primaryTeal, thickness: 1),
          _buildCalculationRow(
            'المبلغ الإجمالي:',
            'Total Amount:',
            _formatEgp(invoice.totalAmount),
            isTotal: true,
          ),
        ],
      ),
    );
  }

  /// Build footer
  pw.Widget _buildFooter(PurchaseInvoice invoice) {
    return pw.Column(
      children: [
        if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: lightTealBackground,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: lightTeal),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ملاحظات - Notes:',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    font: _getBoldFont(),
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
        pw.Divider(color: lightTeal),
        pw.SizedBox(height: 10),
        pw.Text(
          'شكراً لتعاملكم معنا - Thank you for your business',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: primaryTeal,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'تم إنشاء هذه الفاتورة بواسطة نظام إدارة الأعمال سما',
          style: const pw.TextStyle(fontSize: 10, color: grey600),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  // Helper methods
  pw.Widget _buildDetailColumn(String arabicLabel, String englishLabel, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          arabicLabel,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: primaryTeal,
            font: _getBoldFont(),
          ),
        ),
        pw.Text(
          englishLabel,
          style: pw.TextStyle(
            fontSize: 10,
            color: secondaryTeal,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: darkTeal,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTableHeader(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: white,
          font: _getBoldFont(),
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildTableCell(String text, {pw.Alignment? alignment}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9),
        textAlign: alignment == pw.Alignment.centerLeft ? pw.TextAlign.left : pw.TextAlign.center,
      ),
    );
  }

  /// Build table cell with product image
  pw.Widget _buildImageTableCell(pw.MemoryImage? image) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Center(
        child: image != null
            ? pw.Container(
                width: 40,
                height: 40,
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: lightTeal, width: 1),
                ),
                child: pw.Image(
                  image,
                  fit: pw.BoxFit.cover,
                  width: 40,
                  height: 40,
                ),
              )
            : pw.Container(
                width: 40,
                height: 40,
                decoration: pw.BoxDecoration(
                  color: lightTealBackground,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: lightTeal, width: 1),
                ),
                child: pw.Center(
                  child: pw.Text(
                    '📦',
                    style: const pw.TextStyle(fontSize: 16),
                  ),
                ),
              ),
      ),
    );
  }

  pw.Widget _buildCalculationRow(String arabicLabel, String englishLabel, String value, {bool isTotal = false}) {
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
                  color: isTotal ? primaryTeal : black,
                  font: isTotal ? _getBoldFont() : _getRegularFont(),
                ),
              ),
              pw.Text(
                englishLabel,
                style: pw.TextStyle(
                  fontSize: isTotal ? 12 : 10,
                  color: isTotal ? secondaryTeal : grey600,
                ),
              ),
            ],
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isTotal ? primaryTeal : black,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'قيد الانتظار';
      case 'completed':
        return 'مكتملة';
      case 'cancelled':
        return 'ملغية';
      default:
        return status;
    }
  }

  pw.Font? _getBoldFont() => _arabicBoldFont;
  pw.Font? _getRegularFont() => _arabicFont;
}
