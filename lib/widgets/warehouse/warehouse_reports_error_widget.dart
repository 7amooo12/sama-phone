import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/services/warehouse_reports_error_handler.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Enhanced error widget for warehouse reports with retry mechanisms
class WarehouseReportsErrorWidget extends StatefulWidget {
  final dynamic error;
  final String operationName;
  final VoidCallback onRetry;
  final VoidCallback? onCancel;
  final Map<String, dynamic>? context;

  const WarehouseReportsErrorWidget({
    super.key,
    required this.error,
    required this.operationName,
    required this.onRetry,
    this.onCancel,
    this.context,
  });

  @override
  State<WarehouseReportsErrorWidget> createState() => _WarehouseReportsErrorWidgetState();
}

class _WarehouseReportsErrorWidgetState extends State<WarehouseReportsErrorWidget>
    with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));

    // Log the error
    final errorReport = WarehouseReportsErrorHandler.createErrorReport(
      widget.error,
      widget.operationName,
      widget.context,
    );
    AppLogger.error('📊 خطأ في تقارير المخازن: ${errorReport['error_message']}');
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _shakeError() {
    _shakeController.forward().then((_) {
      _shakeController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userMessage = WarehouseReportsErrorHandler.getUserFriendlyMessage(
      widget.error,
      widget.operationName,
    );
    final suggestions = WarehouseReportsErrorHandler.getRecoverySuggestions(
      widget.error,
      widget.operationName,
    );
    final isRetryable = WarehouseReportsErrorHandler.isRetryableError(widget.error);

    return Container(
      decoration: const BoxDecoration(
        gradient: AccountantThemeConfig.mainBackgroundGradient,
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeAnimation.value, 0),
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.cardGradient,
                  borderRadius: BorderRadius.circular(20),
                  border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.warningOrange),
                  boxShadow: [
                    ...AccountantThemeConfig.cardShadows,
                    BoxShadow(
                      color: AccountantThemeConfig.warningOrange.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Error Icon
                    _buildErrorIcon(isRetryable),
                    
                    const SizedBox(height: 24),
                    
                    // Error Title
                    Text(
                      'حدث خطأ في ${widget.operationName}',
                      style: AccountantThemeConfig.headlineSmall.copyWith(
                        color: AccountantThemeConfig.warningOrange,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // User-friendly message
                    Text(
                      userMessage,
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Recovery suggestions
                    if (suggestions.isNotEmpty) _buildSuggestions(suggestions),
                    
                    const SizedBox(height: 24),
                    
                    // Action buttons
                    _buildActionButtons(isRetryable),
                    
                    const SizedBox(height: 16),
                    
                    // Details toggle
                    _buildDetailsToggle(),
                    
                    // Error details (if shown)
                    if (_showDetails) _buildErrorDetails(),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.8, 0.8)),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorIcon(bool isRetryable) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.warningOrange,
            AccountantThemeConfig.dangerRed,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AccountantThemeConfig.warningOrange.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        isRetryable ? Icons.refresh_rounded : Icons.error_outline_rounded,
        color: Colors.white,
        size: 40,
      ),
    );
  }

  Widget _buildSuggestions(List<String> suggestions) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اقتراحات للحل:',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...suggestions.take(3).map((suggestion) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.arrow_left_rounded,
                  color: Colors.white.withOpacity(0.7),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    suggestion,
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isRetryable) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Retry button
        if (isRetryable) ...[
          ElevatedButton.icon(
            onPressed: () {
              _shakeError();
              widget.onRetry();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          if (widget.onCancel != null) const SizedBox(width: 16),
        ],
        
        // Cancel button
        if (widget.onCancel != null)
          TextButton.icon(
            onPressed: widget.onCancel,
            icon: const Icon(Icons.close_rounded),
            label: const Text('إلغاء'),
            style: TextButton.styleFrom(
              foregroundColor: AccountantThemeConfig.warningOrange,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildDetailsToggle() {
    return TextButton.icon(
      onPressed: () {
        setState(() {
          _showDetails = !_showDetails;
        });
      },
      icon: Icon(
        _showDetails ? Icons.expand_less_rounded : Icons.expand_more_rounded,
        size: 18,
      ),
      label: Text(_showDetails ? 'إخفاء التفاصيل' : 'عرض التفاصيل'),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white.withOpacity(0.7),
        textStyle: AccountantThemeConfig.bodySmall,
      ),
    );
  }

  Widget _buildErrorDetails() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تفاصيل الخطأ:',
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.error.toString(),
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white.withOpacity(0.7),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
