import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/models/flask_product_model.dart';
import 'package:smartbiztracker_new/services/flask_api_service.dart';

/// Service for handling QR code scanning and product data extraction
class QRScannerService {
  static final QRScannerService _instance = QRScannerService._internal();
  factory QRScannerService() => _instance;
  QRScannerService._internal();

  MobileScannerController? _controller;
  StreamSubscription<BarcodeCapture>? _scanSubscription;
  bool _isScanning = false;
  bool _isInitialized = false;

  /// Initialize the QR scanner service
  Future<bool> initialize() async {
    try {
      AppLogger.info('🔄 تهيئة خدمة مسح QR...');

      // Initialize mobile scanner controller
      _controller = MobileScannerController();

      _isInitialized = true;
      AppLogger.info('✅ تم تهيئة خدمة مسح QR بنجاح');
      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في تهيئة خدمة مسح QR: $e');
      return false;
    }
  }

  /// Get the mobile scanner controller
  MobileScannerController? get controller => _controller;

  /// Start scanning for QR codes
  Future<void> startScanning(
    Function(String productId, String productName) onProductFound,
    Function(String error)? onError,
  ) async {
    if (!_isInitialized || _controller == null) {
      const error = 'خدمة QR غير مهيأة أو المتحكم غير متاح';
      AppLogger.error('❌ $error');
      onError?.call(error);
      return;
    }

    if (_isScanning) {
      AppLogger.warning('⚠️ المسح قيد التشغيل بالفعل');
      return;
    }

    try {
      _isScanning = true;
      AppLogger.info('🔍 بدء مسح QR...');

      _scanSubscription = _controller!.barcodes.listen((barcodeCapture) async {
        final barcodes = barcodeCapture.barcodes;
        if (barcodes.isNotEmpty) {
          final barcode = barcodes.first;
          final qrData = barcode.rawValue;

          if (qrData != null && qrData.isNotEmpty) {
            AppLogger.info('📱 تم مسح QR: $qrData');

            // Stop scanning while processing
            await _controller!.stop();

            // Process the scanned QR code
            await _processQRCode(qrData, onProductFound, onError);
          }
        }
      });

      await _controller!.start();
    } catch (e) {
      final error = 'خطأ في بدء مسح QR: $e';
      AppLogger.error('❌ $error');
      _isScanning = false;
      onError?.call(error);
    }
  }

  /// Stop scanning
  Future<void> stopScanning() async {
    try {
      _isScanning = false;
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      await _controller?.stop();
      AppLogger.info('⏹️ تم إيقاف مسح QR');
    } catch (e) {
      AppLogger.error('❌ خطأ في إيقاف مسح QR: $e');
    }
  }

  /// Process QR code data (public method)
  Future<void> processQRCode(
    String qrData,
    Function(String productId, String productName) onProductFound,
    Function(String error)? onError,
  ) async {
    await _processQRCode(qrData, onProductFound, onError);
  }

  /// Process the scanned QR code
  Future<void> _processQRCode(
    String qrData,
    Function(String productId, String productName) onProductFound,
    Function(String error)? onError,
  ) async {
    try {
      AppLogger.info('🔄 معالجة بيانات QR: $qrData');

      // Check if it's a valid URL
      if (!_isValidUrl(qrData)) {
        const error = 'QR لا يحتوي على رابط صحيح للمنتج';
        AppLogger.warning('⚠️ $error');
        onError?.call(error);
        return;
      }

      // Extract product ID from URL
      final productId = _extractProductId(qrData);
      if (productId == null) {
        const error = 'لم يتم العثور على معرف المنتج في الرابط';
        AppLogger.warning('⚠️ $error');
        onError?.call(error);
        return;
      }

      AppLogger.info('🆔 معرف المنتج المستخرج: $productId');

      // Get product name from URL and local database
      final productName = await _getProductName(qrData, productId);
      if (productName == null) {
        const error = 'لم يتم العثور على المنتج في قاعدة البيانات';
        AppLogger.warning('⚠️ $error');
        onError?.call(error);
        return;
      }

      AppLogger.info('✅ تم العثور على المنتج: $productName (ID: $productId)');
      onProductFound(productId, productName);

    } catch (e) {
      final error = 'خطأ في معالجة QR: $e';
      AppLogger.error('❌ $error');
      onError?.call(error);
    }
  }

  /// Check if the string is a valid URL
  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Extract product ID from URL
  String? _extractProductId(String url) {
    try {
      // Pattern for URLs like: https://samastock.pythonanywhere.com/store/product/158
      final regex = RegExp(r'/product/(\d+)');
      final match = regex.firstMatch(url);
      return match?.group(1);
    } catch (e) {
      AppLogger.error('❌ خطأ في استخراج معرف المنتج: $e');
      return null;
    }
  }

  /// Get product name from URL and verify with local database
  Future<String?> _getProductName(String url, String productId) async {
    try {
      // First, try to get product name from local Flask API
      final localProduct = await _getProductFromLocalApi(productId);
      if (localProduct != null) {
        AppLogger.info('✅ تم العثور على المنتج في قاعدة البيانات المحلية: ${localProduct.name}');
        return localProduct.name;
      }

      // If not found locally, try to scrape from the URL
      final scrapedName = await _scrapeProductNameFromUrl(url);
      if (scrapedName != null) {
        AppLogger.info('✅ تم استخراج اسم المنتج من الرابط: $scrapedName');
        return scrapedName;
      }

      AppLogger.warning('⚠️ لم يتم العثور على اسم المنتج');
      return null;
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على اسم المنتج: $e');
      return null;
    }
  }

  /// Get product from local Flask API
  Future<FlaskProductModel?> _getProductFromLocalApi(String productId) async {
    try {
      final flaskService = FlaskApiService();
      final products = await flaskService.getProducts();
      
      // Find product by ID
      final product = products.where((p) => p.id.toString() == productId).firstOrNull;
      return product;
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على المنتج من API المحلي: $e');
      return null;
    }
  }

  /// Scrape product name from URL
  Future<String?> _scrapeProductNameFromUrl(String url) async {
    try {
      AppLogger.info('🌐 استخراج اسم المنتج من الرابط: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'SAMA-Business-QR-Scanner/1.0',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        
        // Try different selectors to find product name
        String? productName;
        
        // Try common product name selectors
        final selectors = [
          'h1.product-title',
          'h1.product-name',
          '.product-title',
          '.product-name',
          'h1',
          'title',
        ];

        for (final selector in selectors) {
          final element = document.querySelector(selector);
          if (element != null && element.text.trim().isNotEmpty) {
            productName = element.text.trim();
            break;
          }
        }

        if (productName != null && productName.isNotEmpty) {
          // Clean up the product name
          productName = _cleanProductName(productName);
          AppLogger.info('✅ تم استخراج اسم المنتج: $productName');
          return productName;
        }
      }

      AppLogger.warning('⚠️ لم يتم العثور على اسم المنتج في الصفحة');
      return null;
    } catch (e) {
      AppLogger.error('❌ خطأ في استخراج اسم المنتج من الرابط: $e');
      return null;
    }
  }

  /// Clean up product name
  String _cleanProductName(String name) {
    // Remove common website suffixes and prefixes
    name = name.replaceAll(RegExp(r'\s*-\s*SAMA.*$', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'\s*\|\s*.*$'), '');
    name = name.trim();
    return name;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopScanning();
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    AppLogger.info('🗑️ تم تنظيف موارد خدمة QR');
  }

  /// Check if scanner is currently scanning
  bool get isScanning => _isScanning;

  /// Check if scanner is initialized
  bool get isInitialized => _isInitialized;
}
