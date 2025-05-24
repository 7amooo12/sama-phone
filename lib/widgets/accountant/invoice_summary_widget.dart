import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Widget for displaying a summary of invoices
class InvoiceSummaryWidget extends StatelessWidget {
  final Map<String, dynamic> invoiceData;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRefresh;
  final Function(String)? onInvoiceSelected;
  
  const InvoiceSummaryWidget({
    Key? key,
    required this.invoiceData,
    this.isLoading = false,
    this.errorMessage,
    this.onRefresh,
    this.onInvoiceSelected,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'جاري تحميل بيانات الفواتير...',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }
    
    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ: $errorMessage',
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }
    
    if (invoiceData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              color: theme.colorScheme.primary.withOpacity(0.5),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد بيانات فواتير متاحة',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (onRefresh != null)
              ElevatedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('تحديث البيانات'),
              ),
          ],
        ),
      );
    }
    
    // Extract invoice summary data
    final totalInvoices = invoiceData['total'] ?? 0;
    final paidInvoices = invoiceData['paid'] ?? 0;
    final unpaidInvoices = invoiceData['unpaid'] ?? 0;
    final totalAmount = (invoiceData['totalAmount'] ?? 0.0) as double;
    final paidAmount = (invoiceData['paidAmount'] ?? 0.0) as double;
    final unpaidAmount = (invoiceData['unpaidAmount'] ?? 0.0) as double;
    final recentInvoices = invoiceData['recentInvoices'] as List<dynamic>? ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary cards
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                context: context,
                title: 'إجمالي الفواتير',
                value: totalInvoices.toString(),
                subtitle: NumberFormat.currency(locale: 'ar', symbol: 'ج.م.', decimalDigits: 2).format(totalAmount),
                icon: Icons.receipt,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                context: context,
                title: 'مدفوعة',
                value: paidInvoices.toString(),
                subtitle: NumberFormat.currency(locale: 'ar', symbol: 'ج.م.', decimalDigits: 2).format(paidAmount),
                icon: Icons.check_circle,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                context: context,
                title: 'غير مدفوعة',
                value: unpaidInvoices.toString(),
                subtitle: NumberFormat.currency(locale: 'ar', symbol: 'ج.م.', decimalDigits: 2).format(unpaidAmount),
                icon: Icons.pending,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        
        // Recent invoices header
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child: Row(
            children: [
              Text(
                'أحدث الفواتير',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('تحديث'),
              ),
            ],
          ),
        ),
        
        // Recent invoices list
        Expanded(
          child: recentInvoices.isEmpty 
              ? Center(
                  child: Text(
                    'لا توجد فواتير حديثة',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: recentInvoices.length,
                  itemBuilder: (context, index) {
                    final invoice = recentInvoices[index];
                    final invoiceId = invoice['id']?.toString() ?? '';
                    final invoiceNumber = invoice['number']?.toString() ?? 'فاتورة #$invoiceId';
                    final customerName = invoice['customer']?.toString() ?? 'عميل غير معروف';
                    final amount = (invoice['amount'] ?? 0.0) as double;
                    final isPaid = invoice['isPaid'] == true;
                    final dateStr = invoice['date']?.toString() ?? '';
                    DateTime? date;
                    try {
                      date = DateTime.parse(dateStr);
                    } catch (e) {
                      // Use current date if parsing fails
                      date = DateTime.now();
                    }
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () {
                          if (onInvoiceSelected != null) {
                            onInvoiceSelected!(invoiceId);
                          }
                        },
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: isPaid 
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          child: Icon(
                            isPaid ? Icons.receipt : Icons.pending,
                            color: isPaid ? Colors.green : Colors.orange,
                          ),
                        ),
                        title: Text(
                          invoiceNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(customerName),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('yyyy-MM-dd').format(date),
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              NumberFormat.currency(locale: 'ar', symbol: 'ج.م.', decimalDigits: 2).format(amount),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isPaid
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isPaid ? 'مدفوعة' : 'غير مدفوعة',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isPaid ? Colors.green : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
  
  Widget _buildSummaryCard({
    required BuildContext context,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const Spacer(),
                Text(
                  value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
