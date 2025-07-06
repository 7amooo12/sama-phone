import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/logger.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class LogsViewerScreen extends StatefulWidget {
  const LogsViewerScreen({super.key});

  @override
  State<LogsViewerScreen> createState() => _LogsViewerScreenState();
}

class _LogsViewerScreenState extends State<LogsViewerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _logs = '';
  String _errorLogs = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final logs = await AppLogger.getLogs();
      final errorLogs = await AppLogger.getErrorLogs();

      if (mounted) {
        setState(() {
          _logs = logs;
          _errorLogs = errorLogs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _logs = 'Error loading logs: $e';
          _errorLogs = 'Error loading error logs: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _shareLogs(bool errorLogs) async {
    try {
      if (errorLogs) {
        // Share error logs functionality would need to be implemented
        AppLogger.info('Share error logs requested');
      } else {
        // Share logs functionality would need to be implemented
        AppLogger.info('Share logs requested');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing logs: $e')),
      );
    }
  }

  Future<void> _clearLogs(bool errorLogs) async {
    try {
      final bool success;
      if (errorLogs) {
        success = await AppLogger.clearErrorLogFile();
      } else {
        success = await AppLogger.clearLogFile();
      }

      if (success) {
        _loadLogs();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم مسح السجلات بنجاح')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل في مسح السجلات')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing logs: $e')),
      );
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ السجلات إلى الحافظة')),
    );
  }

  Future<void> _getLogDetails() async {
    try {
      final normalLogPath = await AppLogger.getLogFilePath();
      final errorLogPath = await AppLogger.getErrorLogFilePath();

      String details = '';

      final normalLogFile = File(normalLogPath);
      final normalLogSize = await normalLogFile.length();
      details += 'سجلات العادية:\n';
      details += 'المسار: $normalLogPath\n';
      details += 'الحجم: ${(normalLogSize / 1024).toStringAsFixed(2)} KB\n\n';
    
      final errorLogFile = File(errorLogPath);
      final errorLogSize = await errorLogFile.length();
      details += 'سجلات الأخطاء:\n';
      details += 'المسار: $errorLogPath\n';
      details += 'الحجم: ${(errorLogSize / 1024).toStringAsFixed(2)} KB\n';
    
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تفاصيل ملفات السجلات'),
          content: Text(details),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('موافق'),
            ),
            TextButton(
              onPressed: () => _copyToClipboard(details),
              child: const Text('نسخ'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting log details: $e')),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مشاهدة السجلات'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'السجلات العادية'),
            Tab(text: 'سجلات الأخطاء'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'تفاصيل السجلات',
            onPressed: _getLogDetails,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث السجلات',
            onPressed: _loadLogs,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'clear_normal':
                  _showClearConfirmation(false);
                  break;
                case 'clear_error':
                  _showClearConfirmation(true);
                  break;
                case 'share_normal':
                  _shareLogs(false);
                  break;
                case 'share_error':
                  _shareLogs(true);
                  break;
                case 'copy_normal':
                  _copyToClipboard(_logs);
                  break;
                case 'copy_error':
                  _copyToClipboard(_errorLogs);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_normal',
                child: Text('مسح السجلات العادية'),
              ),
              const PopupMenuItem(
                value: 'clear_error',
                child: Text('مسح سجلات الأخطاء'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'share_normal',
                child: Text('مشاركة السجلات العادية'),
              ),
              const PopupMenuItem(
                value: 'share_error',
                child: Text('مشاركة سجلات الأخطاء'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'copy_normal',
                child: Text('نسخ السجلات العادية'),
              ),
              const PopupMenuItem(
                value: 'copy_error',
                child: Text('نسخ سجلات الأخطاء'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLogView(_logs, false),
                _buildLogView(_errorLogs, true),
              ],
            ),
    );
  }

  Widget _buildLogView(String logs, bool isError) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: isError ? Colors.red.withOpacity(0.05) : Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: isError ? Colors.red.withOpacity(0.3) : StyleSystem.primaryColor.withOpacity(0.3),
                ),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  logs.isEmpty ? (isError ? 'لا توجد أخطاء مسجلة' : 'لا توجد سجلات') : logs,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: isError ? Colors.red.shade800 : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () => _shareLogs(isError),
                icon: const Icon(Icons.share),
                label: const Text('مشاركة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StyleSystem.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showClearConfirmation(isError),
                icon: const Icon(Icons.delete_outline),
                label: const Text('مسح'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isError ? Colors.red : StyleSystem.primaryColor,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _copyToClipboard(isError ? _errorLogs : _logs),
                icon: const Icon(Icons.copy),
                label: const Text('نسخ'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: StyleSystem.primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showClearConfirmation(bool isError) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('مسح ${isError ? 'سجلات الأخطاء' : 'السجلات العادية'}'),
        content: Text('هل أنت متأكد من مسح ${isError ? 'سجلات الأخطاء' : 'السجلات العادية'}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearLogs(isError);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('مسح'),
          ),
        ],
      ),
    );
  }
}