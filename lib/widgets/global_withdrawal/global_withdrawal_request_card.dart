import 'package:flutter/material.dart';
import '../../models/global_withdrawal_models.dart';
import '../../config/accountant_theme_config.dart';

/// بطاقة عرض طلب السحب العالمي
class GlobalWithdrawalRequestCard extends StatelessWidget {
  final GlobalWithdrawalRequest request;
  final VoidCallback? onTap;
  final VoidCallback? onProcess;

  const GlobalWithdrawalRequestCard({
    super.key,
    required this.request,
    this.onTap,
    this.onProcess,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadow,
        border: Border.all(
          color: Color(int.parse(request.processingStatusColor.substring(1), radix: 16) + 0xFF000000)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 12),
                _buildContent(),
                const SizedBox(height: 12),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // أيقونة نوع الطلب
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: request.isGlobalRequest 
                ? AccountantThemeConfig.primaryColor.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            request.isGlobalRequest ? Icons.public : Icons.warehouse,
            color: request.isGlobalRequest 
                ? AccountantThemeConfig.primaryColor
                : Colors.grey,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        
        // معلومات الطلب
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'طلب سحب',
                    style: AccountantThemeConfig.bodyStyle.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (request.isGlobalRequest) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AccountantThemeConfig.primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'عالمي',
                        style: TextStyle(
                          color: AccountantThemeConfig.primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'بواسطة: ${request.requesterName ?? 'غير معروف'}',
                style: AccountantThemeConfig.bodyStyle.copyWith(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        
        // حالة الطلب
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(request.status).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _getStatusColor(request.status).withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            _getStatusText(request.status),
            style: TextStyle(
              color: _getStatusColor(request.status),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // سبب الطلب
        if (request.reason.isNotEmpty) ...[
          Text(
            'السبب: ${request.reason}',
            style: AccountantThemeConfig.bodyStyle.copyWith(
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
        ],
        
        // معلومات المعالجة
        if (request.isGlobalRequest) ...[
          _buildProcessingInfo(),
          const SizedBox(height: 8),
        ],
        
        // معلومات العناصر
        Row(
          children: [
            _buildInfoChip(
              icon: Icons.inventory,
              label: '${request.items.length} منتج',
              color: Colors.blue,
            ),
            const SizedBox(width: 8),
            if (request.isAutoProcessed) ...[
              _buildInfoChip(
                icon: Icons.auto_awesome,
                label: 'معالجة تلقائية',
                color: Colors.purple,
              ),
              const SizedBox(width: 8),
            ],
            if (request.warehousesInvolved.isNotEmpty) ...[
              _buildInfoChip(
                icon: Icons.warehouse,
                label: '${request.warehousesInvolved.length} مخزن',
                color: Colors.orange,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildProcessingInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(int.parse(request.processingStatusColor.substring(1), radix: 16) + 0xFF000000)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Color(int.parse(request.processingStatusColor.substring(1), radix: 16) + 0xFF000000)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getProcessingIcon(request.processingStatus),
                color: Color(int.parse(request.processingStatusColor.substring(1), radix: 16) + 0xFF000000),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                request.processingStatusText,
                style: TextStyle(
                  color: Color(int.parse(request.processingStatusColor.substring(1), radix: 16) + 0xFF000000),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          if (request.isAutoProcessed) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildProgressBar(
                    'المعالجة',
                    request.processingPercentage,
                    request.processingSuccess ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${request.totalProcessed}/${request.totalRequested}',
                  style: AccountantThemeConfig.bodyStyle.copyWith(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBar(String label, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label (${percentage.toStringAsFixed(1)}%)',
          style: AccountantThemeConfig.bodyStyle.copyWith(
            fontSize: 10,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage / 100,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        // تاريخ الإنشاء
        Icon(
          Icons.access_time,
          size: 14,
          color: Colors.white54,
        ),
        const SizedBox(width: 4),
        Text(
          _formatDate(request.createdAt),
          style: AccountantThemeConfig.bodyStyle.copyWith(
            fontSize: 12,
            color: Colors.white54,
          ),
        ),
        
        const Spacer(),
        
        // أزرار الإجراءات
        if (onProcess != null) ...[
          ElevatedButton.icon(
            onPressed: onProcess,
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text('معالجة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
        
        // سهم التفاصيل
        Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Colors.white54,
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'في الانتظار';
      case 'approved':
        return 'موافق عليه';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  IconData _getProcessingIcon(GlobalProcessingStatus status) {
    switch (status) {
      case GlobalProcessingStatus.notGlobal:
        return Icons.inventory;
      case GlobalProcessingStatus.pending:
        return Icons.pending;
      case GlobalProcessingStatus.processing:
        return Icons.sync;
      case GlobalProcessingStatus.completed:
        return Icons.check_circle;
      case GlobalProcessingStatus.failed:
        return Icons.error;
    }
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
}
