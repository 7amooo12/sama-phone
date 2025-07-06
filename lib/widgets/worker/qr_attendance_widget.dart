/// QR Attendance Widget for Worker Dashboard
/// 
/// This widget provides a secure, time-limited QR code generation system
/// for worker attendance tracking with AccountantThemeConfig styling.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/qr_token_service.dart';
import '../../providers/supabase_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/attendance_models.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';

class QRAttendanceWidget extends StatefulWidget {
  const QRAttendanceWidget({super.key});

  @override
  State<QRAttendanceWidget> createState() => _QRAttendanceWidgetState();
}

class _QRAttendanceWidgetState extends State<QRAttendanceWidget>
    with TickerProviderStateMixin {
  final QRTokenService _qrTokenService = QRTokenService();
  
  // Animation controllers
  late AnimationController _countdownController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  
  // Animations
  late Animation<double> _countdownAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;
  
  // State variables
  String? _qrData;
  bool _isGenerating = false;
  String? _errorMessage;
  Timer? _countdownTimer;
  int _remainingSeconds = 20;
  
  // Widget states
  QRWidgetState _currentState = QRWidgetState.initial;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  @override
  void dispose() {
    _countdownController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _initializeAnimations() {
    // Countdown animation (20 seconds)
    _countdownController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    
    _countdownAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _countdownController,
      curve: Curves.linear,
    ));
    
    // Color animation for countdown ring
    _colorAnimation = ColorTween(
      begin: AccountantThemeConfig.primaryGreen,
      end: Colors.red,
    ).animate(CurvedAnimation(
      parent: _countdownController,
      curve: Curves.easeInOut,
    ));
    
    // Fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    // Scale animation
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
  }

  Future<void> _generateQRCode() async {
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final user = supabaseProvider.user;
    
    if (user == null) {
      _setError('المستخدم غير مسجل الدخول');
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _currentState = QRWidgetState.loading;
    });

    try {
      AppLogger.info('🔄 Generating QR code for worker: ${user.id}');
      
      // Generate QR token
      final qrData = await _qrTokenService.generateQRToken(user.id);
      
      setState(() {
        _qrData = qrData;
        _isGenerating = false;
        _remainingSeconds = 20;
        _currentState = QRWidgetState.active;
      });
      
      // Start animations
      await _fadeController.forward();
      await _scaleController.forward();
      
      // Start countdown
      _startCountdown();
      
      AppLogger.info('✅ QR code generated successfully');
      
    } catch (e) {
      AppLogger.error('❌ Error generating QR code: $e');
      _setError(e.toString());
    }
  }

  void _startCountdown() {
    _countdownController.forward();
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
      });
      
      if (_remainingSeconds <= 0) {
        _expireQRCode();
      }
    });
  }

  void _expireQRCode() {
    _countdownTimer?.cancel();
    _countdownController.reset();
    _fadeController.reverse();
    
    setState(() {
      _currentState = QRWidgetState.expired;
      _qrData = null;
      _remainingSeconds = 20;
    });
  }

  void _setError(String error) {
    setState(() {
      _isGenerating = false;
      _errorMessage = error;
      _currentState = QRWidgetState.error;
    });
  }

  void _resetWidget() {
    _countdownTimer?.cancel();
    _countdownController.reset();
    _fadeController.reset();
    _scaleController.reset();
    
    setState(() {
      _qrData = null;
      _errorMessage = null;
      _remainingSeconds = 20;
      _currentState = QRWidgetState.initial;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildContent(),
          const SizedBox(height: 32),
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              AccountantThemeConfig.primaryGreen,
              AccountantThemeConfig.accentBlue,
            ],
          ).createShader(bounds),
          child: Text(
            'رمز الحضور والانصراف',
            style: AccountantThemeConfig.headlineLarge.copyWith(
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'امسح الرمز للحضور أو الانصراف',
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildContent() {
    switch (_currentState) {
      case QRWidgetState.initial:
      case QRWidgetState.expired:
        return _buildInitialState();
      case QRWidgetState.loading:
        return _buildLoadingState();
      case QRWidgetState.active:
        return _buildActiveState();
      case QRWidgetState.error:
        return _buildErrorState();
    }
  }

  Widget _buildInitialState() {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AccountantThemeConfig.cardGradient,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Icon(
        Icons.qr_code_2_rounded,
        size: 120,
        color: Colors.white.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AccountantThemeConfig.cardGradient,
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AccountantThemeConfig.primaryGreen,
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'جاري إنشاء الرمز...',
              style: AccountantThemeConfig.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveState() {
    return AnimatedBuilder(
      animation: Listenable.merge([_fadeAnimation, _scaleAnimation, _countdownAnimation, _colorAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Countdown ring
                SizedBox(
                  width: 320,
                  height: 320,
                  child: CircularProgressIndicator(
                    value: _countdownAnimation.value,
                    strokeWidth: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getCountdownColor(),
                    ),
                  ),
                ),

                // QR Code container
                Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: AccountantThemeConfig.glowShadows(_getCountdownColor()),
                  ),
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: QrImageView(
                        data: _qrData!,
                        version: QrVersions.auto,
                        size: 260,
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                      ),
                    ),
                  ),
                ),

                // Countdown text overlay
                Positioned(
                  bottom: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getCountdownColor().withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _getCountdownColor().withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      '$_remainingSeconds ثانية',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Colors.red.withValues(alpha: 0.2),
            Colors.red.withValues(alpha: 0.1),
          ],
        ),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: AccountantThemeConfig.glowShadows(Colors.red),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _errorMessage ?? 'حدث خطأ غير متوقع',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    String buttonText;
    VoidCallback? onPressed;

    switch (_currentState) {
      case QRWidgetState.initial:
        buttonText = 'إنشاء رمز الحضور';
        onPressed = _generateQRCode;
        break;
      case QRWidgetState.loading:
        buttonText = 'جاري الإنشاء...';
        onPressed = null;
        break;
      case QRWidgetState.active:
        buttonText = 'امسح الرمز للحضور/الانصراف';
        onPressed = null;
        break;
      case QRWidgetState.expired:
        buttonText = 'إعادة إنشاء الرمز';
        onPressed = _generateQRCode;
        break;
      case QRWidgetState.error:
        buttonText = 'إعادة المحاولة';
        onPressed = _resetWidget;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton(
        onPressed: onPressed,
        style: _getButtonStyle(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Text(
            buttonText,
            style: AccountantThemeConfig.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  ButtonStyle _getButtonStyle() {
    switch (_currentState) {
      case QRWidgetState.initial:
      case QRWidgetState.expired:
        return AccountantThemeConfig.primaryButtonStyle.copyWith(
          backgroundColor: MaterialStateProperty.all(AccountantThemeConfig.primaryGreen),
          shadowColor: MaterialStateProperty.all(AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3)),
          elevation: MaterialStateProperty.all(8),
        );
      case QRWidgetState.loading:
        return AccountantThemeConfig.primaryButtonStyle.copyWith(
          backgroundColor: MaterialStateProperty.all(Colors.white.withValues(alpha: 0.3)),
          shadowColor: MaterialStateProperty.all(Colors.transparent),
          elevation: MaterialStateProperty.all(0),
        );
      case QRWidgetState.active:
        return AccountantThemeConfig.primaryButtonStyle.copyWith(
          backgroundColor: MaterialStateProperty.all(Colors.white.withValues(alpha: 0.3)),
          shadowColor: MaterialStateProperty.all(Colors.transparent),
          elevation: MaterialStateProperty.all(0),
        );
      case QRWidgetState.error:
        return AccountantThemeConfig.dangerButtonStyle.copyWith(
          backgroundColor: MaterialStateProperty.all(Colors.red),
          shadowColor: MaterialStateProperty.all(Colors.red.withValues(alpha: 0.3)),
          elevation: MaterialStateProperty.all(8),
        );
    }
  }

  Color _getCountdownColor() {
    if (_remainingSeconds > 15) {
      return AccountantThemeConfig.primaryGreen;
    } else if (_remainingSeconds > 10) {
      return Colors.amber;
    } else {
      return Colors.red;
    }
  }
}

enum QRWidgetState {
  initial,
  loading,
  active,
  expired,
  error,
}
