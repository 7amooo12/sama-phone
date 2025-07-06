import 'package:flutter/material.dart';
import '../../services/warehouse_deletion_fix_service.dart';
import '../../config/accountant_theme_config.dart';
import '../../utils/app_logger.dart';

/// حوار إصلاح مشكلة حذف المخزن
class WarehouseDeletionFixDialog extends StatefulWidget {
  final String warehouseId;
  final String warehouseName;

  const WarehouseDeletionFixDialog({
    super.key,
    required this.warehouseId,
    required this.warehouseName,
  });

  @override
  State<WarehouseDeletionFixDialog> createState() => _WarehouseDeletionFixDialogState();
}

class _WarehouseDeletionFixDialogState extends State<WarehouseDeletionFixDialog> {
  final WarehouseDeletionFixService _fixService = WarehouseDeletionFixService();
  
  bool _isLoading = false;
  bool _isFixing = false;
  WarehouseDeletionCheck? _deletionCheck;
  List<WarehouseRequestInfo> _requests = [];
  WarehouseFixResult? _fixResult;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final check = await _fixService.checkWarehouseDeletion(widget.warehouseId);
      final requests = await _fixService.getWarehouseRequests(widget.warehouseId);
      
      setState(() {
        _deletionCheck = check;
        _requests = requests;
      });
    } catch (e) {
      AppLogger.error('خطأ في تحميل بيانات المخزن: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AccountantThemeConfig.cardShadow,
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildContent(),
            ),
            _buildFooter(),
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
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.warning,
              color: Colors.red,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إصلاح مشكلة حذف المخزن',
                  style: AccountantThemeConfig.headingStyle.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'المخزن: ${widget.warehouseName}',
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

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'جاري تحليل المخزن...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_deletionCheck != null) ...[
            _buildDeletionStatus(),
            const SizedBox(height: 20),
          ],
          
          if (_requests.isNotEmpty) ...[
            _buildRequestsList(),
            const SizedBox(height: 20),
          ],
          
          if (_fixResult != null) ...[
            _buildFixResult(),
          ],
        ],
      ),
    );
  }

  Widget _buildDeletionStatus() {
    final check = _deletionCheck!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: check.canDelete 
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: check.canDelete 
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                check.canDelete ? Icons.check_circle : Icons.error,
                color: check.canDelete ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                check.canDelete ? 'يمكن حذف المخزن' : 'لا يمكن حذف المخزن',
                style: AccountantThemeConfig.bodyStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: check.canDelete ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          
          if (!check.canDelete) ...[
            const SizedBox(height: 12),
            Text(
              'السبب: ${check.blockingReason}',
              style: AccountantThemeConfig.bodyStyle.copyWith(
                color: Colors.red,
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          _buildStatusGrid(check),
        ],
      ),
    );
  }

  Widget _buildStatusGrid(WarehouseDeletionCheck check) {
    return Row(
      children: [
        Expanded(
          child: _buildStatusItem(
            'طلبات نشطة',
            '${check.activeRequests}',
            Icons.pending_actions,
            check.activeRequests > 0 ? Colors.red : Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatusItem(
            'منتجات بمخزون',
            '${check.inventoryItems}',
            Icons.inventory,
            check.inventoryItems > 0 ? Colors.orange : Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatusItem(
            'معاملات حديثة',
            '${check.recentTransactions}',
            Icons.history,
            Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: AccountantThemeConfig.bodyStyle.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        Text(
          label,
          style: AccountantThemeConfig.bodyStyle.copyWith(
            fontSize: 12,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRequestsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الطلبات المرتبطة (${_requests.length})',
          style: AccountantThemeConfig.bodyStyle.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _requests.length,
            itemBuilder: (context, index) {
              final request = _requests[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    Icon(
                      request.isGlobal ? Icons.public : Icons.warehouse,
                      color: request.isGlobal 
                          ? AccountantThemeConfig.primaryColor
                          : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${request.typeText} - ${request.statusText}',
                            style: AccountantThemeConfig.bodyStyle.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${request.requestTypeText} - ${request.reason}',
                            style: AccountantThemeConfig.bodyStyle.copyWith(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!request.isGlobal) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'يحتاج تحويل',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFixResult() {
    final result = _fixResult!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: result.success 
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: result.success 
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.error,
                color: result.success ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                result.success ? 'تم الإصلاح بنجاح' : 'فشل في الإصلاح',
                style: AccountantThemeConfig.bodyStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: result.success ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          Text(
            result.message,
            style: AccountantThemeConfig.bodyStyle,
          ),
          
          if (result.stepsPerformed.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'الخطوات المنفذة:',
              style: AccountantThemeConfig.bodyStyle.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...result.stepsPerformed.map((step) => Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.check, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step,
                      style: AccountantThemeConfig.bodyStyle.copyWith(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
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
              onPressed: _isFixing ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('إغلاق'),
            ),
          ),
          const SizedBox(width: 12),
          
          if (_deletionCheck?.canDelete == true) ...[
            Expanded(
              child: ElevatedButton(
                onPressed: _isFixing ? null : _deleteWarehouse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('حذف المخزن'),
              ),
            ),
          ] else ...[
            Expanded(
              child: ElevatedButton(
                onPressed: _isFixing ? null : _performComprehensiveFix,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AccountantThemeConfig.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isFixing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 8),
                          Text('جاري الإصلاح...'),
                        ],
                      )
                    : const Text('إصلاح وحذف'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _deleteWarehouse() async {
    final result = await _fixService.safeDeleteWarehouse(widget.warehouseId);
    
    if (mounted) {
      if (result.success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف المخزن بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في حذف المخزن: ${result.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _performComprehensiveFix() async {
    setState(() {
      _isFixing = true;
    });

    try {
      final result = await _fixService.comprehensiveWarehouseFix(widget.warehouseId);
      
      setState(() {
        _fixResult = result;
      });

      if (result.success && mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إصلاح وحذف المخزن بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('خطأ في الإصلاح الشامل: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الإصلاح: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFixing = false;
        });
      }
    }
  }
}
