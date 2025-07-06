import 'package:flutter/material.dart';
import '../../utils/accountant_theme_config.dart';
import 'treasury_skeleton_loader.dart';

/// Loading state manager for treasury screens
class TreasuryLoadingManager extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final TreasuryLoadingType loadingType;
  final int itemCount;
  final String? loadingMessage;

  const TreasuryLoadingManager({
    super.key,
    required this.isLoading,
    required this.child,
    this.loadingType = TreasuryLoadingType.general,
    this.itemCount = 3,
    this.loadingMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return child;

    return _buildLoadingState();
  }

  Widget _buildLoadingState() {
    switch (loadingType) {
      case TreasuryLoadingType.treasuryVaults:
        return _buildSkeletonList(TreasurySkeletonLoader.treasuryVaultCard);
      case TreasuryLoadingType.transactions:
        return _buildSkeletonList(TreasurySkeletonLoader.transactionListItem);
      case TreasuryLoadingType.statistics:
        return _buildStatisticsLoading();
      case TreasuryLoadingType.auditLogs:
        return _buildSkeletonList(TreasurySkeletonLoader.auditLogItem);
      case TreasuryLoadingType.wallets:
        return _buildSkeletonList(TreasurySkeletonLoader.walletCard);
      case TreasuryLoadingType.general:
        return _buildGeneralLoading();
    }
  }

  Widget _buildSkeletonList(Widget Function() skeletonBuilder) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) => skeletonBuilder(),
    );
  }

  Widget _buildStatisticsLoading() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
        ),
        itemCount: 4,
        itemBuilder: (context, index) => TreasurySkeletonLoader.statisticsCard(),
      ),
    );
  }

  Widget _buildGeneralLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AccountantThemeConfig.primaryGreen),
            strokeWidth: 3,
          ),
          if (loadingMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              loadingMessage!,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Types of loading states for treasury screens
enum TreasuryLoadingType {
  general,
  treasuryVaults,
  transactions,
  statistics,
  auditLogs,
  wallets,
}

/// Progressive loading widget with stages
class TreasuryProgressiveLoader extends StatefulWidget {
  final List<TreasuryLoadingStage> stages;
  final Widget child;
  final VoidCallback? onComplete;

  const TreasuryProgressiveLoader({
    super.key,
    required this.stages,
    required this.child,
    this.onComplete,
  });

  @override
  State<TreasuryProgressiveLoader> createState() => _TreasuryProgressiveLoaderState();
}

class _TreasuryProgressiveLoaderState extends State<TreasuryProgressiveLoader>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  int _currentStageIndex = 0;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _startLoading();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _startLoading() async {
    for (int i = 0; i < widget.stages.length; i++) {
      setState(() {
        _currentStageIndex = i;
      });

      _progressController.reset();
      _progressController.forward();

      await widget.stages[i].loadingFunction();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    setState(() {
      _isComplete = true;
    });

    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_isComplete) return widget.child;

    final currentStage = widget.stages[_currentStageIndex];
    final progress = (_currentStageIndex + 1) / widget.stages.length;

    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.mainBackgroundGradient,
      ),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                currentStage.icon,
                color: AccountantThemeConfig.primaryGreen,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                currentStage.title,
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                currentStage.description,
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: AccountantThemeConfig.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(AccountantThemeConfig.primaryGreen),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_currentStageIndex + 1)} من ${widget.stages.length}',
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: AccountantThemeConfig.white60,
                ),
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return CircularProgressIndicator(
                    value: _progressAnimation.value,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(AccountantThemeConfig.primaryGreen),
                    strokeWidth: 3,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading stage for progressive loader
class TreasuryLoadingStage {
  final String title;
  final String description;
  final IconData icon;
  final Future<void> Function() loadingFunction;

  const TreasuryLoadingStage({
    required this.title,
    required this.description,
    required this.icon,
    required this.loadingFunction,
  });
}

/// Overlay loading widget
class TreasuryOverlayLoader extends StatelessWidget {
  final bool isVisible;
  final String? message;
  final bool canDismiss;
  final VoidCallback? onDismiss;

  const TreasuryOverlayLoader({
    super.key,
    required this.isVisible,
    this.message,
    this.canDismiss = false,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Material(
      color: Colors.black.withValues(alpha: 0.7),
      child: InkWell(
        onTap: canDismiss ? onDismiss : null,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.cardGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AccountantThemeConfig.primaryGreen),
                  strokeWidth: 3,
                ),
                if (message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    message!,
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (canDismiss) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: onDismiss,
                    child: Text(
                      'إلغاء',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: AccountantThemeConfig.accentBlue,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
