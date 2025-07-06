import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ErrorHistoryScreen extends StatefulWidget {
  const ErrorHistoryScreen({super.key});

  @override
  State<ErrorHistoryScreen> createState() => _ErrorHistoryScreenState();
}

class _ErrorHistoryScreenState extends State<ErrorHistoryScreen> {
  // قائمة الأخطاء المبلغ عنها (يمكن استبدالها بالبيانات الحقيقية من قاعدة البيانات)
  final List<Map<String, dynamic>> _errorReports = [
    {
      'id': '001',
      'title': 'خطأ في تحميل الصفحة الرئيسية',
      'description': 'لا تظهر المنتجات في الصفحة الرئيسية بشكل صحيح',
      'priority': 'عالي',
      'status': 'قيد المراجعة',
      'date': DateTime.now().subtract(const Duration(days: 1)),
      'location': 'الصفحة الرئيسية',
    },
    {
      'id': '002',
      'title': 'مشكلة في عملية الدفع',
      'description': 'تظهر رسالة خطأ عند محاولة إتمام عملية الشراء',
      'priority': 'عاجل',
      'status': 'تم الحل',
      'date': DateTime.now().subtract(const Duration(days: 3)),
      'location': 'صفحة الدفع',
    },
    {
      'id': '003',
      'title': 'بطء في تحميل الصور',
      'description': 'صور المنتجات تستغرق وقتاً طويلاً للتحميل',
      'priority': 'متوسط',
      'status': 'قيد الإصلاح',
      'date': DateTime.now().subtract(const Duration(days: 5)),
      'location': 'صفحة المنتجات',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'تاريخ الأخطاء المبلغ عنها',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF10B981),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.05),
              Colors.black.withOpacity(0.02),
            ],
          ),
        ),
        child: _errorReports.isEmpty ? _buildEmptyState() : _buildErrorsList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF10B981).withOpacity(0.1),
                    const Color(0xFF10B981).withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 64,
                color: Color(0xFF10B981),
              ),
            ).animate().scaleXY(begin: 0.5, end: 1.0, duration: 500.ms),

            const SizedBox(height: 24),

            const Text(
              'لا توجد أخطاء مبلغ عنها',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontFamily: 'Cairo',
              ),
            ).animate().fadeIn(delay: 300.ms),

            const SizedBox(height: 12),

            Text(
              'لم تقم بالإبلاغ عن أي أخطاء حتى الآن',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontFamily: 'Cairo',
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _errorReports.length,
      itemBuilder: (context, index) {
        final error = _errorReports[index];
        return _buildErrorCard(error, index);
      },
    );
  }

  Widget _buildErrorCard(Map<String, dynamic> error, int index) {
    final statusColor = _getStatusColor(error['status']?.toString() ?? '');
    final priorityColor = _getPriorityColor(error['priority']?.toString() ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with ID and date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF10B981),
                        const Color(0xFF10B981).withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'بلاغ #${error['id']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
                Text(
                  _formatDate(error['date'] is DateTime ? error['date'] : DateTime.now()),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Title
            Text(
              error['title']?.toString() ?? 'بلاغ غير محدد',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),

            const SizedBox(height: 8),

            // Description
            Text(
              error['description']?.toString() ?? 'لا يوجد وصف',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontFamily: 'Cairo',
              ),
            ),

            const SizedBox(height: 16),

            // Status and Priority
            Row(
              children: [
                Expanded(
                  child: _buildStatusChip('الحالة', error['status']?.toString() ?? 'غير محدد', statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatusChip('الأولوية', error['priority']?.toString() ?? 'غير محدد', priorityColor),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Location
            Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF10B981),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  error['location']?.toString() ?? 'غير محدد',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: (index * 100).ms).moveY(begin: 20, end: 0);
  }

  Widget _buildStatusChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'قيد المراجعة':
        return Colors.orange;
      case 'قيد الإصلاح':
        return Colors.blue;
      case 'تم الحل':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'عاجل':
        return Colors.red;
      case 'عالي':
        return Colors.orange;
      case 'متوسط':
        return Colors.yellow;
      case 'منخفض':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) {
      return 'اليوم';
    } else if (difference == 1) {
      return 'أمس';
    } else {
      return 'منذ $difference أيام';
    }
  }
}
