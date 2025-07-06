import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartbiztracker_new/providers/worker_attendance_provider.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// ماسح QR احترافي لحضور العمال
class ProfessionalQRScannerWidget extends StatefulWidget {
  final Function(String qrData)? onQRDetected;
  final VoidCallback? onError;
  final bool showControls;
  final bool showInstructions;

  const ProfessionalQRScannerWidget({
    super.key,
    this.onQRDetected,
    this.onError,
    this.showControls = true,
    this.showInstructions = true,
  });

  @override
  State<ProfessionalQRScannerWidget> createState() => _ProfessionalQRScannerWidgetState();
}

class _ProfessionalQRScannerWidgetState extends State<ProfessionalQRScannerWidget>
    with TickerProviderStateMixin {
  late AnimationController _scanAnimationController;
  late AnimationController _pulseAnimationController;
  late MobileScannerController _mobileScannerController;
  String? _lastScannedCode;
  DateTime? _lastScanTime;
  bool _flashEnabled = false;
  bool _isProcessing = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    // Initialize animation controllers
    _scanAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Initialize mobile scanner controller
    _mobileScannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    AppLogger.info('📱 تم تهيئة متحكمات QR Scanner بنجاح');
  }

  @override
  void dispose() {
    _isDisposed = true;

    // Dispose animation controllers
    _scanAnimationController.dispose();
    _pulseAnimationController.dispose();

    // Dispose mobile scanner controller
    _mobileScannerController.dispose();

    AppLogger.info('🗑️ تم تنظيف موارد QR Scanner');
    super.dispose();
  }

  void _onQRDetected(BarcodeCapture capture) {
    if (_isProcessing || !mounted || _isDisposed) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final qrData = barcode.rawValue;

    if (qrData == null || qrData.isEmpty) return;

    // تجنب المسح المتكرر
    final now = DateTime.now();
    if (_lastScannedCode == qrData &&
        _lastScanTime != null &&
        now.difference(_lastScanTime!) < const Duration(seconds: 3)) {
      return;
    }

    _lastScannedCode = qrData;
    _lastScanTime = now;

    if (!mounted || _isDisposed) return;

    setState(() {
      _isProcessing = true;
    });

    AppLogger.info('📱 تم اكتشاف QR: ${qrData.substring(0, 20)}...');

    // معالجة QR بشكل آمن
    _processQRSafely(qrData);
  }

  void _processQRSafely(String qrData) async {
    try {
      if (widget.onQRDetected != null && mounted && !_isDisposed) {
        await widget.onQRDetected!(qrData);
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في معالجة QR: $e');
      if (widget.onError != null && mounted && !_isDisposed) {
        widget.onError!();
      }
    } finally {
      // إعادة تعيين حالة المعالجة بعد 3 ثوان
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && !_isDisposed) {
          setState(() {
            _isProcessing = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkerAttendanceProvider>(
      builder: (BuildContext context, WorkerAttendanceProvider provider, Widget? child) {

        return Container(
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.mainBackgroundGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // ماسح الكاميرا
                MobileScanner(
                  controller: _mobileScannerController,
                  onDetect: _onQRDetected,
                ),

                // طبقة التحكم والتوجيه
                _buildOverlay(provider),

                // أزرار التحكم
                if (widget.showControls)
                  _buildControlButtons(provider),

                // التعليمات
                if (widget.showInstructions)
                  _buildInstructions(),

                // مؤشر المعالجة
                if (provider.isProcessing || _isProcessing)
                  _buildProcessingOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.mainBackgroundGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AccountantThemeConfig.greenGradient,
                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'جاري تهيئة الكاميرا...',
              style: AccountantThemeConfig.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay(WorkerAttendanceProvider provider) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.3),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.3),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: Center(
        child: _buildScanningFrame(),
      ),
    );
  }

  Widget _buildScanningFrame() {
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen,
          width: 3,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // زوايا الإطار
          ..._buildCorners(),
          
          // خط المسح المتحرك
          AnimatedBuilder(
            animation: _scanAnimationController,
            builder: (context, child) {
              return Positioned(
                top: _scanAnimationController.value * 220,
                left: 10,
                right: 10,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AccountantThemeConfig.primaryGreen,
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCorners() {
    const cornerSize = 30.0;
    const cornerThickness = 4.0;
    
    return [
      // الزاوية العلوية اليسرى
      Positioned(
        top: -2,
        left: -2,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AccountantThemeConfig.primaryGreen, width: cornerThickness),
              left: BorderSide(color: AccountantThemeConfig.primaryGreen, width: cornerThickness),
            ),
          ),
        ),
      ),
      // الزاوية العلوية اليمنى
      Positioned(
        top: -2,
        right: -2,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AccountantThemeConfig.primaryGreen, width: cornerThickness),
              right: BorderSide(color: AccountantThemeConfig.primaryGreen, width: cornerThickness),
            ),
          ),
        ),
      ),
      // الزاوية السفلية اليسرى
      Positioned(
        bottom: -2,
        left: -2,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AccountantThemeConfig.primaryGreen, width: cornerThickness),
              left: BorderSide(color: AccountantThemeConfig.primaryGreen, width: cornerThickness),
            ),
          ),
        ),
      ),
      // الزاوية السفلية اليمنى
      Positioned(
        bottom: -2,
        right: -2,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AccountantThemeConfig.primaryGreen, width: cornerThickness),
              right: BorderSide(color: AccountantThemeConfig.primaryGreen, width: cornerThickness),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildControlButtons(WorkerAttendanceProvider provider) {
    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // زر الفلاش
          _buildControlButton(
            icon: _flashEnabled ? Icons.flash_on : Icons.flash_off,
            onTap: () async {
              if (!_isDisposed && mounted) {
                try {
                  await _mobileScannerController.toggleTorch();
                  setState(() {
                    _flashEnabled = !_flashEnabled;
                  });
                } catch (e) {
                  AppLogger.error('❌ خطأ في تبديل الفلاش: $e');
                }
              }
            },
            isActive: _flashEnabled,
          ),

          // زر تبديل الكاميرا
          _buildControlButton(
            icon: Icons.flip_camera_ios,
            onTap: () async {
              if (!_isDisposed && mounted) {
                try {
                  await _mobileScannerController.switchCamera();
                } catch (e) {
                  AppLogger.error('❌ خطأ في تبديل الكاميرا: $e');
                }
              }
            },
            isActive: false,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isActive,
  }) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isActive 
            ? AccountantThemeConfig.greenGradient 
            : LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.4),
                ],
              ),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Icon(
            icon,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Positioned(
      top: 50,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseAnimationController.value * 0.1),
                  child: Icon(
                    Icons.qr_code_scanner,
                    color: AccountantThemeConfig.primaryGreen,
                    size: 32,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              'وجه الكاميرا نحو رمز QR الخاص بالعامل',
              style: AccountantThemeConfig.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'سيتم تسجيل الحضور تلقائياً عند مسح الرمز',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(20),
            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
            boxShadow: AccountantThemeConfig.cardShadows,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AccountantThemeConfig.greenGradient,
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'جاري معالجة رمز QR...',
                style: AccountantThemeConfig.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'يرجى الانتظار',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
