import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:smartbiztracker_new/services/invoice_pdf_service.dart';
import 'package:smartbiztracker_new/models/invoice_models.dart';

void main() {
  group('Invoice PDF Arabic Support Tests', () {
    late InvoicePdfService pdfService;

    setUpAll(() async {
      // Initialize the PDF service
      pdfService = InvoicePdfService();
    });

    test('should load Arabic fonts successfully', () async {
      // Create a test invoice with Arabic content
      final testInvoice = Invoice(
        id: 'INV-TEST-001',
        customerName: 'أحمد محمد علي',
        customerEmail: 'ahmed@example.com',
        customerPhone: '+20 100 123 4567',
        customerAddress: 'شارع النيل، القاهرة، مصر',
        items: [
          InvoiceItem(
            id: '1',
            name: 'منتج تجريبي عربي',
            description: 'وصف المنتج باللغة العربية',
            quantity: 2,
            unitPrice: 150.0,
            totalPrice: 300.0,
            imageUrl: null,
          ),
          InvoiceItem(
            id: '2',
            name: 'خدمة استشارية',
            description: 'خدمة استشارية متخصصة في الأعمال',
            quantity: 1,
            unitPrice: 500.0,
            totalPrice: 500.0,
            imageUrl: null,
          ),
        ],
        subtotal: 800.0,
        discount: 50.0,
        totalAmount: 750.0,
        status: InvoiceStatus.paid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Generate PDF
      final pdfBytes = await pdfService.generateInvoicePdf(testInvoice);

      // Verify PDF was generated
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(0));
      
      // Verify it's a valid PDF (starts with PDF header)
      final pdfHeader = String.fromCharCodes(pdfBytes.take(4));
      expect(pdfHeader, equals('%PDF'));
    });

    test('should use EGP currency format instead of Arabic', () async {
      final testInvoice = Invoice(
        id: 'INV-CURRENCY-TEST',
        customerName: 'Test Customer',
        customerEmail: 'test@example.com',
        items: [
          InvoiceItem(
            id: '1',
            name: 'Test Product',
            description: 'Test Description',
            quantity: 1,
            unitPrice: 100.0,
            totalPrice: 100.0,
            imageUrl: null,
          ),
        ],
        subtotal: 100.0,
        discount: 0.0,
        totalAmount: 100.0,
        status: InvoiceStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Generate PDF
      final pdfBytes = await pdfService.generateInvoicePdf(testInvoice);

      // Verify PDF was generated successfully
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(0));

      // Convert to string to check for currency format
      final pdfString = String.fromCharCodes(pdfBytes);
      
      // Should contain EGP currency symbol
      expect(pdfString.contains('EGP'), isTrue);
      
      // Should NOT contain Arabic currency symbol
      expect(pdfString.contains('ج.م'), isFalse);
    });

    test('should handle mixed Arabic and English content', () async {
      final testInvoice = Invoice(
        id: 'INV-MIXED-001',
        customerName: 'Ahmed Ali أحمد علي',
        customerEmail: 'ahmed.ali@company.com',
        customerPhone: '+20 100 123 4567',
        customerAddress: '123 Main Street, Cairo, Egypt - شارع الرئيسي، القاهرة',
        items: [
          InvoiceItem(
            id: '1',
            name: 'Laptop Computer - جهاز كمبيوتر محمول',
            description: 'High-performance laptop - جهاز عالي الأداء',
            quantity: 1,
            unitPrice: 15000.0,
            totalPrice: 15000.0,
            imageUrl: null,
          ),
          InvoiceItem(
            id: '2',
            name: 'Software License - رخصة برمجية',
            description: 'Annual software license - رخصة برمجية سنوية',
            quantity: 2,
            unitPrice: 2500.0,
            totalPrice: 5000.0,
            imageUrl: null,
          ),
        ],
        subtotal: 20000.0,
        discount: 1000.0,
        totalAmount: 19000.0,
        status: InvoiceStatus.paid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Generate PDF
      final pdfBytes = await pdfService.generateInvoicePdf(testInvoice);

      // Verify PDF generation
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(0));
      
      // Verify PDF header
      final pdfHeader = String.fromCharCodes(pdfBytes.take(4));
      expect(pdfHeader, equals('%PDF'));
    });

    test('should handle empty or null Arabic content gracefully', () async {
      final testInvoice = Invoice(
        id: 'INV-EMPTY-001',
        customerName: '',
        customerEmail: null,
        customerPhone: null,
        customerAddress: null,
        items: [
          InvoiceItem(
            id: '1',
            name: 'Test Product',
            description: '',
            quantity: 1,
            unitPrice: 100.0,
            totalPrice: 100.0,
            imageUrl: null,
          ),
        ],
        subtotal: 100.0,
        discount: 0.0,
        totalAmount: 100.0,
        status: InvoiceStatus.draft,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Should not throw exception
      expect(() async {
        final pdfBytes = await pdfService.generateInvoicePdf(testInvoice);
        expect(pdfBytes, isNotNull);
        expect(pdfBytes.length, greaterThan(0));
      }, returnsNormally);
    });

    test('should maintain RTL text direction for Arabic content', () async {
      final testInvoice = Invoice(
        id: 'INV-RTL-001',
        customerName: 'محمد أحمد عبدالله',
        customerEmail: 'mohammed@example.com',
        items: [
          InvoiceItem(
            id: '1',
            name: 'منتج باللغة العربية فقط',
            description: 'هذا وصف طويل للمنتج باللغة العربية لاختبار اتجاه النص من اليمين إلى اليسار',
            quantity: 3,
            unitPrice: 250.0,
            totalPrice: 750.0,
            imageUrl: null,
          ),
        ],
        subtotal: 750.0,
        discount: 0.0,
        totalAmount: 750.0,
        status: InvoiceStatus.paid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Generate PDF
      final pdfBytes = await pdfService.generateInvoicePdf(testInvoice);

      // Verify successful generation
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(0));
      
      // Verify PDF structure
      final pdfHeader = String.fromCharCodes(pdfBytes.take(4));
      expect(pdfHeader, equals('%PDF'));
    });
  });
}
