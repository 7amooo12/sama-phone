import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:smartbiztracker_new/services/qr_scanner_service.dart';
import 'package:smartbiztracker_new/screens/shared/quick_access_screen.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/widgets/shared/professional_progress_loader.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartbiztracker_new/config/routes.dart';

/// QR Scanner Screen for scanning product QR codes
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final QRScannerService _scannerService = QRScannerService();

  bool _isProcessing = false;
  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    try {
      final success = await _scannerService.initialize();
      if (success) {
        setState(() {
          _isInitialized = true;
        });
      } else {
        setState(() {
          _error = 'فشل في تهيئة الكاميرا. يرجى التحقق من أذونات الكاميرا.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'خطأ في تهيئة الكاميرا: ${e.toString()}';
      });
    }
  }

  @override
  void dispose() {
    _scannerService.dispose();
    super.dispose();
  }

  void _startScanning() {
    _scannerService.startScanning(
      (productId, productName) {
        if (!_isProcessing) {
          _onProductFound(productId, productName);
        }
      },
      (error) {
        if (mounted && !_isProcessing) {
          setState(() {
            _error = error;
            _isProcessing = false;
          });
          // Resume scanning after error
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && !_isProcessing) {
              setState(() {
                _error = null;
              });
              _startScanning();
            }
          });
        }
      },
    );
  }

  void _onProductFound(String productId, String productName) async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      // Stop scanning
      await _scannerService.stopScanning();
      
      // Navigate to Quick Access screen
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.quickAccess,
          arguments: {
            'productId': productId,
            'productName': productName,
          },
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _error = 'خطأ في معالجة QR: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.luxuryBlack,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'مسح QR للمنتجات',
        style: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      backgroundColor: AccountantThemeConfig.darkBlueBlack,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        if (_isInitialized && !_isProcessing)
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () async {
              await _scannerService.controller?.toggleTorch();
            },
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _buildErrorView();
    }

    if (!_isInitialized) {
      return const Center(
        child: ProfessionalProgressLoader(
          message: 'جاري تهيئة الكاميرا...',
        ),
      );
    }

    return Stack(
      children: [
        // Mobile Scanner View
        MobileScanner(
          controller: _scannerService.controller,
          onDetect: (barcodeCapture) {
            if (!_isProcessing) {
              final barcodes = barcodeCapture.barcodes;
              if (barcodes.isNotEmpty) {
                final barcode = barcodes.first;
                final qrData = barcode.rawValue;
                if (qrData != null && qrData.isNotEmpty) {
                  // Process the QR data through the scanner service
                  _scannerService.processQRCode(qrData, _onProductFound, (error) {
                    if (mounted && !_isProcessing) {
                      setState(() {
                        _error = error;
                        _isProcessing = false;
                      });
                    }
                  });
                }
              }
            }
          },
        ),

        // Instructions overlay
        Positioned(
          bottom: 100,
          left: 20,
          right: 20,
          child: _buildInstructions(),
        ),

        // Processing overlay
        if (_isProcessing)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: const Center(
              child: ProfessionalProgressLoader(
                message: 'جاري معالجة QR...',
              ),
            ),
          ),

        // Error overlay
        if (_error != null && !_isProcessing)
          Positioned(
            top: 100,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AccountantThemeConfig.warningOrange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: AccountantThemeConfig.cardShadows,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error!,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AccountantThemeConfig.cardShadows,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AccountantThemeConfig.warningOrange,
            ),
            const SizedBox(height: 16),
            Text(
              'خطأ في الكاميرا',
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AccountantThemeConfig.cardBackground2,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'إلغاء',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                    });
                    _initializeScanner();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AccountantThemeConfig.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'إعادة المحاولة',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.qr_code_scanner,
            color: AccountantThemeConfig.primaryGreen,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            'وجه الكاميرا نحو QR المنتج',
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'سيتم فتح صفحة الوصول السريع تلقائياً عند مسح QR صحيح',
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
