/// تشغيل تشخيص وإصلاح أذن الصرف المحول
/// Run Dispatch Release Order Diagnostic and Fix

import 'package:flutter/material.dart';
import 'dispatch_release_order_diagnostic.dart';

void main() {
  runApp(const DispatchDiagnosticApp());
}

class DispatchDiagnosticApp extends StatelessWidget {
  const DispatchDiagnosticApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تشخيص أذون الصرف المحولة',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Cairo',
      ),
      home: const DiagnosticScreen(),
    );
  }
}

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  bool _isRunning = false;
  String _diagnosticResults = '';
  DiagnosticReport? _lastReport;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تشخيص أذون الصرف المحولة'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تشخيص المشكلة',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('أذن الصرف المحول: WRO-DISPATCH-07ba6659-4a68-4019-8e35-5f9609ec0d98'),
                    const Text('المشكلة: توقف معالجة الخصم الذكي بعد التحقق من صحة البيانات'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isRunning ? null : _runDiagnostic,
                            child: _isRunning
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      SizedBox(width: 8),
                                      Text('جاري التشخيص...'),
                                    ],
                                  )
                                : const Text('تشغيل التشخيص الشامل'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isRunning ? null : _attemptFix,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text('محاولة الإصلاح التلقائي'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_lastReport != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _lastReport!.overallSuccess ? Icons.check_circle : Icons.error,
                            color: _lastReport!.overallSuccess ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'حالة التشخيص: ${_lastReport!.overallSuccess ? "نجح" : "فشل"}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildStatusIndicator('الطلب الأصلي موجود', _lastReport!.originalDispatchExists),
                      _buildStatusIndicator('أذن الصرف قابل للاسترجاع', _lastReport!.releaseOrderRetrievable),
                      _buildStatusIndicator('المخزون متوفر', _lastReport!.inventoryAvailable),
                      _buildStatusIndicator('الخصم الذكي يعمل', _lastReport!.intelligentDeductionWorks),
                      _buildStatusIndicator('المعالجة مكتملة', _lastReport!.processingCompleted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تفاصيل التشخيص',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            _diagnosticResults.isEmpty 
                                ? 'لم يتم تشغيل التشخيص بعد'
                                : _diagnosticResults,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            status ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: status ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Future<void> _runDiagnostic() async {
    setState(() {
      _isRunning = true;
      _diagnosticResults = 'جاري تشغيل التشخيص الشامل...\n';
    });

    try {
      final report = await DispatchReleaseOrderDiagnostic.runComprehensiveDiagnostic();
      
      setState(() {
        _lastReport = report;
        _diagnosticResults = report.summary;
        _isRunning = false;
      });

      if (report.overallSuccess) {
        _showSuccessDialog('تم التشخيص بنجاح', 'جميع الفحوصات نجحت. النظام يعمل بشكل صحيح.');
      } else {
        _showErrorDialog('تم اكتشاف مشاكل', 'تم اكتشاف مشاكل في النظام. راجع التفاصيل أدناه.');
      }

    } catch (e) {
      setState(() {
        _diagnosticResults = 'خطأ في التشخيص: $e';
        _isRunning = false;
      });
      _showErrorDialog('خطأ في التشخيص', 'حدث خطأ أثناء تشغيل التشخيص: $e');
    }
  }

  Future<void> _attemptFix() async {
    setState(() {
      _isRunning = true;
      _diagnosticResults = 'جاري محاولة الإصلاح التلقائي...\n';
    });

    try {
      final success = await DispatchReleaseOrderDiagnostic.attemptAutomaticFix();
      
      setState(() {
        _diagnosticResults += success 
            ? '\n✅ تم الإصلاح بنجاح!'
            : '\n❌ فشل في الإصلاح التلقائي';
        _isRunning = false;
      });

      if (success) {
        _showSuccessDialog('تم الإصلاح بنجاح', 'تم إصلاح المشكلة وإكمال معالجة أذن الصرف.');
        // إعادة تشغيل التشخيص للتأكد
        await _runDiagnostic();
      } else {
        _showErrorDialog('فشل في الإصلاح', 'لم يتم إصلاح المشكلة تلقائياً. قد تحتاج تدخل يدوي.');
      }

    } catch (e) {
      setState(() {
        _diagnosticResults += '\nخطأ في الإصلاح: $e';
        _isRunning = false;
      });
      _showErrorDialog('خطأ في الإصلاح', 'حدث خطأ أثناء محاولة الإصلاح: $e');
    }
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }
}
