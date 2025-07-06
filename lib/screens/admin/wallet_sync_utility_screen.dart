import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/electronic_payment_provider.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../utils/app_logger.dart';

/// Utility screen for syncing electronic wallets with payment accounts
class WalletSyncUtilityScreen extends StatefulWidget {
  const WalletSyncUtilityScreen({super.key});

  @override
  State<WalletSyncUtilityScreen> createState() => _WalletSyncUtilityScreenState();
}

class _WalletSyncUtilityScreenState extends State<WalletSyncUtilityScreen> {
  bool _isLoading = false;
  String? _result;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[900],
        appBar: const CustomAppBar(
          title: 'مزامنة المحافظ الإلكترونية',
          backgroundColor: Colors.grey,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.sync,
                      size: 48,
                      color: Color(0xFF10B981),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'مزامنة المحافظ الإلكترونية',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'هذه الأداة تقوم بمزامنة المحافظ الإلكترونية مع حسابات الدفع لضمان ظهورها كخيارات دفع للعملاء',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontFamily: 'Cairo',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Sync Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _performSync,
                icon: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync),
                label: Text(
                  _isLoading ? 'جاري المزامنة...' : 'بدء المزامنة',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Cairo',
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Result Display
              if (_result != null || _error != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _error != null ? Colors.red[900] : Colors.green[900],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _error != null ? Colors.red[700]! : Colors.green[700]!,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _error != null ? Icons.error : Icons.check_circle,
                            color: _error != null ? Colors.red[400] : Colors.green[400],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _error != null ? 'خطأ في المزامنة' : 'تمت المزامنة بنجاح',
                            style: TextStyle(
                              color: _error != null ? Colors.red[400] : Colors.green[400],
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error ?? _result!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[900]?.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[700]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[400],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'تعليمات',
                          style: TextStyle(
                            color: Colors.blue[400],
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '• تأكد من تشغيل قاعدة البيانات قبل بدء المزامنة\n'
                      '• هذه العملية تقوم بإنشاء حسابات دفع للمحافظ الإلكترونية الجديدة\n'
                      '• بعد المزامنة، ستظهر المحافظ الجديدة كخيارات دفع للعملاء\n'
                      '• يمكن تشغيل هذه العملية عدة مرات بأمان',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontFamily: 'Cairo',
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _performSync() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
    });

    try {
      final paymentProvider = Provider.of<ElectronicPaymentProvider>(context, listen: false);
      await paymentProvider.syncAllElectronicWalletsWithPaymentAccounts();
      
      setState(() {
        _result = 'تمت مزامنة المحافظ الإلكترونية بنجاح. يمكن للعملاء الآن رؤية المحافظ الجديدة كخيارات دفع.';
        _isLoading = false;
      });

      // Show success snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت المزامنة بنجاح'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('❌ Error in wallet sync utility: $e');
      setState(() {
        _error = 'فشل في مزامنة المحافظ: $e';
        _isLoading = false;
      });

      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في المزامنة: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }
}
