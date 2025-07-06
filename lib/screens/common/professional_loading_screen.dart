import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/services/initialization_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Professional loading screen that handles heavy initialization tasks
/// Uses SAMA branding and AccountantThemeConfig styling for production-ready appearance
class ProfessionalLoadingScreen extends StatefulWidget {
  final VoidCallback onInitializationComplete;
  
  const ProfessionalLoadingScreen({
    super.key,
    required this.onInitializationComplete,
  });

  @override
  State<ProfessionalLoadingScreen> createState() => _ProfessionalLoadingScreenState();
}

class _ProfessionalLoadingScreenState extends State<ProfessionalLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _progressController;
  late AnimationController _textController;
  
  String _currentTask = 'تهيئة التطبيق...';
  double _progress = 0.0;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startInitialization();
  }

  void _initializeAnimations() {
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Start logo animation
    _logoController.repeat(reverse: true);
    _textController.forward();
  }

  Future<void> _startInitialization() async {
    try {
      AppLogger.info('🚀 Starting professional app initialization...');
      
      final initService = InitializationService();
      
      await initService.initializeApp(
        onProgress: (progress, task) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _currentTask = task;
            });
            _progressController.animateTo(progress);
          }
        },
      );

      AppLogger.info('✅ App initialization completed successfully');
      
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _currentTask = 'مرحباً بك في SAMA';
          _progress = 1.0;
        });
        
        // Wait for final animation then complete
        await Future.delayed(const Duration(milliseconds: 1000));
        widget.onInitializationComplete();
      }
    } catch (e) {
      AppLogger.error('❌ Initialization failed: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _currentTask = 'حدث خطأ في التهيئة';
        });
        
        // Still complete to avoid blocking the app
        await Future.delayed(const Duration(milliseconds: 2000));
        widget.onInitializationComplete();
      }
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _progressController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.luxuryBlack,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AccountantThemeConfig.luxuryBlack,
              AccountantThemeConfig.darkBlueBlack,
              AccountantThemeConfig.deepBlueBlack,
            ],
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top spacer
                const Spacer(flex: 2),

                // SAMA Logo with professional animation
                _buildSAMALogo(),

                const SizedBox(height: 60),

                // Loading progress section
                _buildLoadingSection(),

                const Spacer(flex: 3),

                // Bottom branding
                _buildBottomBranding(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSAMALogo() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        return Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                Colors.transparent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                blurRadius: 30 + (_logoController.value * 20),
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  Colors.white,
                  AccountantThemeConfig.primaryGreen,
                  Colors.white,
                ],
                stops: [0.0, 0.5 + (_logoController.value * 0.3), 1.0],
              ).createShader(bounds),
              child: const Text(
                'SAMA',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 4.0,
                  fontFamily: 'Cairo',
                  shadows: [
                    Shadow(
                      color: Colors.green,
                      blurRadius: 15,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          // Progress bar
          Container(
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.2),
            ),
            child: AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _progressController.value,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: LinearGradient(
                        colors: [
                          AccountantThemeConfig.primaryGreen,
                          AccountantThemeConfig.accentBlue,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Current task text
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _currentTask,
              key: ValueKey(_currentTask),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1.5,
                fontFamily: 'Cairo',
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 16),

          // Progress percentage
          Text(
            '${(_progress * 100).toInt()}%',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AccountantThemeConfig.primaryGreen,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBranding() {
    return Column(
      children: [
        Text(
          'شركة سما',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.8),
            fontFamily: 'Cairo',
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'نظام إدارة الأعمال المتطور',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.6),
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }
}
