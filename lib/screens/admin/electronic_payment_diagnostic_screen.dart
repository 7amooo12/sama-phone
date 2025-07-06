import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/electronic_payment_validator.dart';
import '../../utils/app_logger.dart';
import '../../widgets/loading_widget.dart';

class ElectronicPaymentDiagnosticScreen extends StatefulWidget {
  const ElectronicPaymentDiagnosticScreen({super.key});

  @override
  State<ElectronicPaymentDiagnosticScreen> createState() => _ElectronicPaymentDiagnosticScreenState();
}

class _ElectronicPaymentDiagnosticScreenState extends State<ElectronicPaymentDiagnosticScreen> {
  final ElectronicPaymentValidator _validator = ElectronicPaymentValidator();
  
  bool _isRunning = false;
  Map<String, dynamic>? _validationResults;
  String? _validationReport;

  @override
  void initState() {
    super.initState();
    _runDiagnostic();
  }

  Future<void> _runDiagnostic() async {
    setState(() {
      _isRunning = true;
      _validationResults = null;
      _validationReport = null;
    });

    try {
      AppLogger.info('🔍 Starting electronic payment system diagnostic...');
      
      final results = await _validator.runCompleteValidation();
      final report = _validator.generateValidationReport(results);
      
      setState(() {
        _validationResults = results;
        _validationReport = report;
        _isRunning = false;
      });

      AppLogger.info('✅ Diagnostic completed');
    } catch (e) {
      AppLogger.error('❌ Diagnostic failed: $e');
      setState(() {
        _isRunning = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Diagnostic failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createDefaultAccounts() async {
    try {
      AppLogger.info('🔧 Creating default payment accounts...');
      
      final success = await _validator.createDefaultPaymentAccounts();
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Default payment accounts created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Re-run diagnostic
        await _runDiagnostic();
      } else {
        throw Exception('Failed to create default accounts');
      }
    } catch (e) {
      AppLogger.error('❌ Failed to create default accounts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create default accounts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyReportToClipboard() {
    if (_validationReport != null) {
      Clipboard.setData(ClipboardData(text: _validationReport!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report copied to clipboard'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Electronic Payment Diagnostic'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRunning ? null : _runDiagnostic,
          ),
          if (_validationReport != null)
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: _copyReportToClipboard,
            ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isRunning) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LoadingWidget(),
            SizedBox(height: 16),
            Text('Running diagnostic...'),
          ],
        ),
      );
    }

    if (_validationResults == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            const Text('Failed to run diagnostic'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _runDiagnostic,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusCard(theme),
          const SizedBox(height: 16),
          _buildDatabaseValidationCard(theme),
          const SizedBox(height: 16),
          _buildServiceValidationCard(theme),
          const SizedBox(height: 16),
          _buildDataValidationCard(theme),
          const SizedBox(height: 16),
          _buildRecommendationsCard(theme),
          const SizedBox(height: 16),
          _buildActionsCard(theme),
          if (_validationReport != null) ...[
            const SizedBox(height: 16),
            _buildReportCard(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    final status = _validationResults!['overall_status'] as String;
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (status) {
      case 'healthy':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'System Healthy';
        break;
      case 'functional_with_warnings':
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        statusText = 'Functional with Warnings';
        break;
      case 'database_only':
        statusColor = Colors.blue;
        statusIcon = Icons.info;
        statusText = 'Database Only';
        break;
      case 'broken':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'System Broken';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
        statusText = 'Unknown Status';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              statusIcon,
              size: 48,
              color: statusColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall Status',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusText,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatabaseValidationCard(ThemeData theme) {
    final dbValidation = _validationResults!['database_validation'] as Map<String, dynamic>;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Database Validation',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildValidationItem(
              'Payment Accounts Table',
              dbValidation['payment_accounts_exists'] as bool,
            ),
            _buildValidationItem(
              'Electronic Payments Table',
              dbValidation['electronic_payments_exists'] as bool,
            ),
            if ((dbValidation['errors'] as List).isNotEmpty) ...[
              const SizedBox(height: 8),
              ...((dbValidation['errors'] as List<String>).map((error) => 
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '• $error',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServiceValidationCard(ThemeData theme) {
    final serviceValidation = _validationResults!['service_validation'] as Map<String, dynamic>;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Service Validation',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildValidationItem(
              'Can Fetch Accounts',
              serviceValidation['can_fetch_accounts'] as bool,
            ),
            _buildValidationItem(
              'Can Fetch Payments',
              serviceValidation['can_fetch_payments'] as bool,
            ),
            _buildValidationItem(
              'Can Fetch Statistics',
              serviceValidation['can_fetch_statistics'] as bool,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataValidationCard(ThemeData theme) {
    final dataValidation = _validationResults!['data_validation'] as Map<String, dynamic>;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data Validation',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildDataItem('Payment Accounts', (dataValidation['account_count'] as num?)?.toInt() ?? 0),
            _buildDataItem('Electronic Payments', (dataValidation['payment_count'] as num?)?.toInt() ?? 0),
            _buildDataItem('Orphaned Payments', (dataValidation['orphaned_payments'] as num?)?.toInt() ?? 0),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard(ThemeData theme) {
    final recommendations = _validationResults!['recommendations'] as List<String>;
    
    if (recommendations.isEmpty) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommendations',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...recommendations.map((recommendation) => 
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  recommendation,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(ThemeData theme) {
    final dataValidation = _validationResults!['data_validation'] as Map<String, dynamic>;
    final accountCount = dataValidation['account_count'] as int;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (accountCount == 0)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _createDefaultAccounts,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Default Payment Accounts'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _runDiagnostic,
                icon: const Icon(Icons.refresh),
                label: const Text('Re-run Diagnostic'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Full Report',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: _copyReportToClipboard,
                  tooltip: 'Copy to clipboard',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Text(
                _validationReport!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationItem(String label, bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(
            isValid ? Icons.check_circle : Icons.error,
            color: isValid ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildDataItem(String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: count > 0 ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
