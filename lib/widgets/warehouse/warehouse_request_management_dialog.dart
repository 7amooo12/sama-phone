import 'package:flutter/material.dart';
import '../../models/warehouse_deletion_models.dart';
import '../../services/warehouse_service.dart';
import '../../config/accountant_theme_config.dart';
import '../../utils/app_logger.dart';

/// حوار إدارة طلبات المخزن النشطة
class WarehouseRequestManagementDialog extends StatefulWidget {
  final String warehouseId;
  final List<WarehouseRequestSummary> activeRequests;
  final VoidCallback? onRequestsUpdated;

  const WarehouseRequestManagementDialog({
    super.key,
    required this.warehouseId,
    required this.activeRequests,
    this.onRequestsUpdated,
  });

  @override
  State<WarehouseRequestManagementDialog> createState() => _WarehouseRequestManagementDialogState();
}

class _WarehouseRequestManagementDialogState extends State<WarehouseRequestManagementDialog> {
  final WarehouseService _warehouseService = WarehouseService();
  List<WarehouseRequestSummary> _requests = [];
  bool _isLoading = false;
  Set<String> _processingRequests = {};

  @override
  void initState() {
    super.initState();
    _requests = List.from(widget.activeRequests);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AccountantThemeConfig.cardShadow,
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildRequestsList(),
            ),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.assignment,
              color: Colors.orange,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إدارة الطلبات النشطة',
                  style: AccountantThemeConfig.headingStyle.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_requests.length} طلب نشط',
                  style: AccountantThemeConfig.bodyStyle.copyWith(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'لا توجد طلبات نشطة',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'تم إكمال أو إلغاء جميع الطلبات',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final request = _requests[index];
        return _buildRequestCard(request);
      },
    );
  }

  Widget _buildRequestCard(WarehouseRequestSummary request) {
    final isProcessing = _processingRequests.contains(request.id);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(int.parse(request.statusColor.substring(1), radix: 16) + 0xFF000000)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // نوع الطلب
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(int.parse(request.statusColor.substring(1), radix: 16) + 0xFF000000)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    request.typeText,
                    style: TextStyle(
                      color: Color(int.parse(request.statusColor.substring(1), radix: 16) + 0xFF000000),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // حالة الطلب
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(int.parse(request.statusColor.substring(1), radix: 16) + 0xFF000000)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Color(int.parse(request.statusColor.substring(1), radix: 16) + 0xFF000000)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    request.statusText,
                    style: TextStyle(
                      color: Color(int.parse(request.statusColor.substring(1), radix: 16) + 0xFF000000),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // عمر الطلب
                if (request.isOld) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'قديم',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 12),
            
            // تفاصيل الطلب
            if (request.reason.isNotEmpty) ...[
              Text(
                'السبب: ${request.reason}',
                style: AccountantThemeConfig.bodyStyle.copyWith(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'طلب من: ${request.requesterName}',
                        style: AccountantThemeConfig.bodyStyle.copyWith(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'تاريخ الطلب: ${_formatDate(request.createdAt)}',
                        style: AccountantThemeConfig.bodyStyle.copyWith(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // أزرار الإجراءات
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (request.status == 'pending') ...[
                      _buildActionButton(
                        icon: Icons.check,
                        label: 'موافقة',
                        color: Colors.green,
                        onPressed: isProcessing ? null : () => _approveRequest(request),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _buildActionButton(
                      icon: Icons.close,
                      label: 'إلغاء',
                      color: Colors.red,
                      onPressed: isProcessing ? null : () => _cancelRequest(request),
                    ),
                  ],
                ),
              ],
            ),
            
            if (isProcessing) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 32,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('إغلاق', style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _requests.isEmpty ? null : _cancelAllRequests,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('إلغاء جميع الطلبات', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return 'منذ ${difference.inDays} يوم';
    } else if (difference.inHours > 0) {
      return 'منذ ${difference.inHours} ساعة';
    } else {
      return 'منذ ${difference.inMinutes} دقيقة';
    }
  }

  Future<void> _approveRequest(WarehouseRequestSummary request) async {
    setState(() {
      _processingRequests.add(request.id);
    });

    try {
      // Implement request approval logic
      await Future.delayed(const Duration(seconds: 1)); // Placeholder
      
      setState(() {
        _requests.removeWhere((r) => r.id == request.id);
      });
      
      widget.onRequestsUpdated?.call();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم الموافقة على الطلب'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('خطأ في الموافقة على الطلب: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في الموافقة على الطلب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _processingRequests.remove(request.id);
      });
    }
  }

  Future<void> _cancelRequest(WarehouseRequestSummary request) async {
    setState(() {
      _processingRequests.add(request.id);
    });

    try {
      // Implement request cancellation logic
      await Future.delayed(const Duration(seconds: 1)); // Placeholder
      
      setState(() {
        _requests.removeWhere((r) => r.id == request.id);
      });
      
      widget.onRequestsUpdated?.call();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إلغاء الطلب'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('خطأ في إلغاء الطلب: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إلغاء الطلب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _processingRequests.remove(request.id);
      });
    }
  }

  Future<void> _cancelAllRequests() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الإلغاء'),
        content: Text('هل أنت متأكد من إلغاء جميع الطلبات النشطة (${_requests.length} طلب)؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('نعم، إلغاء الجميع', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Cancel all requests
        for (final request in _requests) {
          await _cancelRequest(request);
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
