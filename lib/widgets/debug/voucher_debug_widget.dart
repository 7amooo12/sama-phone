import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';

/// Debug widget for voucher functionality
/// Used for development and testing purposes
class VoucherDebugWidget extends StatelessWidget {
  final String? voucherId;
  final Map<String, dynamic>? voucherData;
  final VoidCallback? onRefresh;

  const VoucherDebugWidget({
    super.key,
    this.voucherId,
    this.voucherData,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.warningOrange),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.bug_report_rounded,
                color: AccountantThemeConfig.warningOrange,
                size: 24,
              ),
              const SizedBox(width: AccountantThemeConfig.smallPadding),
              Text(
                'Voucher Debug Info',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: AccountantThemeConfig.warningOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (onRefresh != null)
                IconButton(
                  onPressed: onRefresh,
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: AccountantThemeConfig.warningOrange,
                  ),
                  tooltip: 'Refresh Debug Data',
                ),
            ],
          ),
          
          const SizedBox(height: AccountantThemeConfig.defaultPadding),
          
          // Voucher ID
          if (voucherId != null) ...[
            _buildDebugRow('Voucher ID', voucherId!),
            const SizedBox(height: AccountantThemeConfig.smallPadding),
          ],
          
          // Voucher Data
          if (voucherData != null) ...[
            Text(
              'Voucher Data:',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AccountantThemeConfig.smallPadding),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AccountantThemeConfig.smallPadding),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Text(
                _formatVoucherData(voucherData!),
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: Colors.white70,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                'No voucher data available',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          
          const SizedBox(height: AccountantThemeConfig.defaultPadding),
          
          // Debug Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showDebugDialog(context),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Debug Info'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AccountantThemeConfig.accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: AccountantThemeConfig.smallPadding),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _exportDebugData(context),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Export'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AccountantThemeConfig.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  String _formatVoucherData(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    data.forEach((key, value) {
      buffer.writeln('$key: $value');
    });
    return buffer.toString();
  }

  void _showDebugDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardBackground1,
        title: Text(
          'Debug Information',
          style: AccountantThemeConfig.headlineSmall.copyWith(color: Colors.white),
        ),
        content: Text(
          'This is a debug widget for voucher functionality.\n\n'
          'Voucher ID: ${voucherId ?? 'N/A'}\n'
          'Data Available: ${voucherData != null ? 'Yes' : 'No'}\n'
          'Environment: Debug Mode',
          style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Close',
              style: TextStyle(color: AccountantThemeConfig.primaryGreen),
            ),
          ),
        ],
      ),
    );
  }

  void _exportDebugData(BuildContext context) {
    // Simulate export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Debug data exported to console'),
        backgroundColor: AccountantThemeConfig.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    // Print debug data to console
    print('=== VOUCHER DEBUG DATA ===');
    print('Voucher ID: $voucherId');
    print('Voucher Data: $voucherData');
    print('========================');
  }
}
