import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/accountant_theme_config.dart';

/// CRITICAL PERFORMANCE: Progressive loading widget that shows immediate results
/// while continuing to load additional data in the background
class ProgressiveLoadingWidget extends StatefulWidget {
  final Widget Function(BuildContext context, List<dynamic> loadedData) builder;
  final Future<List<dynamic>> Function() dataLoader;
  final Widget Function(BuildContext context)? placeholderBuilder;
  final Widget Function(BuildContext context, String error)? errorBuilder;
  final int initialBatchSize;
  final Duration batchDelay;
  final String loadingMessage;

  const ProgressiveLoadingWidget({
    super.key,
    required this.builder,
    required this.dataLoader,
    this.placeholderBuilder,
    this.errorBuilder,
    this.initialBatchSize = 5,
    this.batchDelay = const Duration(milliseconds: 100),
    this.loadingMessage = 'جاري التحميل...',
  });

  @override
  State<ProgressiveLoadingWidget> createState() => _ProgressiveLoadingWidgetState();
}

class _ProgressiveLoadingWidgetState extends State<ProgressiveLoadingWidget>
    with TickerProviderStateMixin {
  
  List<dynamic> _loadedData = [];
  List<dynamic> _allData = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentBatch = 0;
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startProgressiveLoading();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  Future<void> _startProgressiveLoading() async {
    try {
      // Load all data first
      _allData = await widget.dataLoader();
      
      if (_allData.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Start progressive display
      await _displayDataProgressively();
      
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _displayDataProgressively() async {
    final totalBatches = (_allData.length / widget.initialBatchSize).ceil();
    
    for (int batch = 0; batch < totalBatches; batch++) {
      final startIndex = batch * widget.initialBatchSize;
      final endIndex = (startIndex + widget.initialBatchSize).clamp(0, _allData.length);
      
      final batchData = _allData.sublist(startIndex, endIndex);
      
      setState(() {
        _loadedData.addAll(batchData);
        _currentBatch = batch + 1;
      });

      // Animate new items
      _fadeController.forward();
      _slideController.forward();
      
      // Reset animations for next batch
      await Future.delayed(const Duration(milliseconds: 50));
      _fadeController.reset();
      _slideController.reset();
      
      // Delay before next batch (except for last batch)
      if (batch < totalBatches - 1) {
        await Future.delayed(widget.batchDelay);
      }
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.errorBuilder?.call(context, _errorMessage) ?? 
        _buildDefaultErrorWidget();
    }

    if (_loadedData.isEmpty && _isLoading) {
      return widget.placeholderBuilder?.call(context) ?? 
        _buildDefaultPlaceholder();
    }

    return Column(
      children: [
        // Main content with progressive loading
        Expanded(
          child: AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: widget.builder(context, _loadedData),
                ),
              );
            },
          ),
        ),
        
        // Loading indicator at bottom
        if (_isLoading)
          _buildProgressIndicator(),
      ],
    );
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.primaryGradient,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              color: Colors.white,
              size: 30,
            ),
          )
            .animate()
            .scale(duration: 600.ms, curve: Curves.elasticOut)
            .then()
            .shimmer(duration: 1000.ms),
          
          const SizedBox(height: 16),
          
          Text(
            widget.loadingMessage,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AccountantThemeConfig.primaryColor,
              fontFamily: 'Cairo',
            ),
          )
            .animate()
            .fadeIn(delay: 300.ms, duration: 600.ms)
            .slideY(begin: 0.3, end: 0),
          
          const SizedBox(height: 8),
          
          Text(
            'جاري تحضير البيانات للعرض...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontFamily: 'Cairo',
            ),
          )
            .animate()
            .fadeIn(delay: 600.ms, duration: 600.ms),
        ],
      ),
    );
  }

  Widget _buildDefaultErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 30,
            ),
          ),
          
          const SizedBox(height: 16),
          
          const Text(
            'حدث خطأ أثناء تحميل البيانات',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.red,
              fontFamily: 'Cairo',
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            _errorMessage,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontFamily: 'Cairo',
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          ElevatedButton(
            onPressed: () {
              setState(() {
                _hasError = false;
                _isLoading = true;
                _loadedData.clear();
                _allData.clear();
                _currentBatch = 0;
              });
              _startProgressiveLoading();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'إعادة المحاولة',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final progress = _allData.isNotEmpty ? _loadedData.length / _allData.length : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              )
                .animate(onPlay: (controller) => controller.repeat())
                .rotate(duration: 1000.ms),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تم تحميل ${_loadedData.length} من ${_allData.length} عنصر',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AccountantThemeConfig.primaryColor,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AccountantThemeConfig.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
