import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/electronic_payment_provider.dart';
import '../../providers/electronic_wallet_provider.dart';
import '../../models/electronic_payment_model.dart';

/// Tab for displaying comprehensive electronic payment statistics
class PaymentStatisticsTab extends StatefulWidget {
  const PaymentStatisticsTab({super.key});

  @override
  State<PaymentStatisticsTab> createState() => _PaymentStatisticsTabState();
}

class _PaymentStatisticsTabState extends State<PaymentStatisticsTab> {
  @override
  Widget build(BuildContext context) {
    return Consumer2<ElectronicPaymentProvider, ElectronicWalletProvider>(
      builder: (context, paymentProvider, walletProvider, child) {
        return RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              paymentProvider.loadStatistics(),
              walletProvider.loadStatistics(),
            ]);
          },
          color: const Color(0xFF10B981),
          backgroundColor: Colors.grey[900],
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Payment Statistics Section
                _buildSectionHeader('إحصائيات المدفوعات', Icons.payment),
                const SizedBox(height: 16),
                _buildPaymentStatistics(paymentProvider),
                
                const SizedBox(height: 32),
                
                // Wallet Statistics Section
                _buildSectionHeader('إحصائيات المحافظ', Icons.account_balance_wallet),
                const SizedBox(height: 16),
                _buildWalletStatistics(walletProvider),
                
                const SizedBox(height: 32),
                
                // Payment Method Breakdown
                _buildSectionHeader('توزيع المدفوعات حسب النوع', Icons.pie_chart),
                const SizedBox(height: 16),
                _buildPaymentMethodBreakdown(paymentProvider),
                
                const SizedBox(height: 32),
                
                // Recent Activity
                _buildSectionHeader('النشاط الأخير', Icons.history),
                const SizedBox(height: 16),
                _buildRecentActivity(paymentProvider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF10B981), size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentStatistics(ElectronicPaymentProvider paymentProvider) {
    return Column(
      children: [
        // First Row
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'إجمالي المدفوعات',
                paymentProvider.payments.length.toString(),
                Icons.payment,
                const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'قيد المراجعة',
                paymentProvider.pendingPaymentsCount.toString(),
                Icons.pending_actions,
                const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Second Row
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'مقبولة',
                paymentProvider.approvedPaymentsCount.toString(),
                Icons.check_circle,
                const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'مرفوضة',
                paymentProvider.rejectedPaymentsCount.toString(),
                Icons.cancel,
                const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Third Row
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'إجمالي المبلغ المقبول',
                '${paymentProvider.totalApprovedAmount.toStringAsFixed(0)} ج.م',
                Icons.attach_money,
                const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'متوسط المبلغ',
                paymentProvider.approvedPaymentsCount > 0
                    ? '${(paymentProvider.totalApprovedAmount / paymentProvider.approvedPaymentsCount).toStringAsFixed(0)} ج.م'
                    : '0 ج.م',
                Icons.trending_up,
                const Color(0xFF8B5CF6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWalletStatistics(ElectronicWalletProvider walletProvider) {
    return Column(
      children: [
        // First Row
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'إجمالي المحافظ',
                walletProvider.totalWallets.toString(),
                Icons.account_balance_wallet,
                const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'المحافظ النشطة',
                walletProvider.activeWalletsCount.toString(),
                Icons.check_circle,
                const Color(0xFF10B981),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Second Row
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'فودافون كاش',
                walletProvider.vodafoneWalletsCount.toString(),
                Icons.phone_android,
                const Color(0xFFE60012),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'إنستاباي',
                walletProvider.instapayWalletsCount.toString(),
                Icons.credit_card,
                const Color(0xFF1E88E5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Third Row
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'إجمالي الأرصدة',
                '${walletProvider.totalBalance.toStringAsFixed(0)} ج.م',
                Icons.account_balance,
                const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'إجمالي المعاملات',
                walletProvider.totalTransactions.toString(),
                Icons.swap_horiz,
                const Color(0xFF8B5CF6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentMethodBreakdown(ElectronicPaymentProvider paymentProvider) {
    final vodafonePayments = paymentProvider.payments
        .where((p) => p.paymentMethod == ElectronicPaymentMethod.vodafoneCash)
        .toList();
    final instapayPayments = paymentProvider.payments
        .where((p) => p.paymentMethod == ElectronicPaymentMethod.instaPay)
        .toList();

    final vodafoneAmount = vodafonePayments
        .where((p) => p.status == ElectronicPaymentStatus.approved)
        .fold<double>(0.0, (sum, payment) => sum + payment.amount);
    final instapayAmount = instapayPayments
        .where((p) => p.status == ElectronicPaymentStatus.approved)
        .fold<double>(0.0, (sum, payment) => sum + payment.amount);

    return Column(
      children: [
        // Vodafone Cash Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE60012).withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Row(
                children: [
                  Icon(Icons.phone_android, color: Color(0xFFE60012), size: 24),
                  SizedBox(width: 12),
                  Text(
                    'فودافون كاش',
                    style: TextStyle(
                      color: Color(0xFFE60012),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMethodStatItem(
                      'عدد المدفوعات',
                      vodafonePayments.length.toString(),
                    ),
                  ),
                  Expanded(
                    child: _buildMethodStatItem(
                      'المبلغ المقبول',
                      '${vodafoneAmount.toStringAsFixed(0)} ج.م',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMethodStatItem(
                      'قيد المراجعة',
                      vodafonePayments
                          .where((p) => p.status == ElectronicPaymentStatus.pending)
                          .length
                          .toString(),
                    ),
                  ),
                  Expanded(
                    child: _buildMethodStatItem(
                      'مرفوضة',
                      vodafonePayments
                          .where((p) => p.status == ElectronicPaymentStatus.rejected)
                          .length
                          .toString(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // InstaPay Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E88E5).withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Row(
                children: [
                  Icon(Icons.credit_card, color: Color(0xFF1E88E5), size: 24),
                  SizedBox(width: 12),
                  Text(
                    'إنستاباي',
                    style: TextStyle(
                      color: Color(0xFF1E88E5),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMethodStatItem(
                      'عدد المدفوعات',
                      instapayPayments.length.toString(),
                    ),
                  ),
                  Expanded(
                    child: _buildMethodStatItem(
                      'المبلغ المقبول',
                      '${instapayAmount.toStringAsFixed(0)} ج.م',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMethodStatItem(
                      'قيد المراجعة',
                      instapayPayments
                          .where((p) => p.status == ElectronicPaymentStatus.pending)
                          .length
                          .toString(),
                    ),
                  ),
                  Expanded(
                    child: _buildMethodStatItem(
                      'مرفوضة',
                      instapayPayments
                          .where((p) => p.status == ElectronicPaymentStatus.rejected)
                          .length
                          .toString(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(ElectronicPaymentProvider paymentProvider) {
    final recentPayments = paymentProvider.payments
        .take(5)
        .toList();

    if (recentPayments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.history, color: Colors.white24, size: 48),
              SizedBox(height: 16),
              Text(
                'لا توجد مدفوعات حديثة',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: recentPayments.asMap().entries.map((entry) {
          final index = entry.key;
          final payment = entry.value;
          final isLast = index == recentPayments.length - 1;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: isLast ? null : const Border(
                bottom: BorderSide(color: Colors.white10),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getPaymentMethodColor(payment.paymentMethod).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      payment.paymentMethodIcon,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.clientName ?? 'عميل غير معروف',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        payment.paymentMethodDisplayName,
                        style: TextStyle(
                          color: _getPaymentMethodColor(payment.paymentMethod),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      payment.formattedAmount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(payment.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        payment.statusDisplayName,
                        style: TextStyle(
                          color: _getStatusColor(payment.status),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMethodStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(ElectronicPaymentStatus status) {
    switch (status) {
      case ElectronicPaymentStatus.pending:
        return const Color(0xFFF59E0B);
      case ElectronicPaymentStatus.approved:
        return const Color(0xFF10B981);
      case ElectronicPaymentStatus.rejected:
        return const Color(0xFFEF4444);
    }
  }

  Color _getPaymentMethodColor(ElectronicPaymentMethod method) {
    switch (method) {
      case ElectronicPaymentMethod.vodafoneCash:
        return const Color(0xFFE60012);
      case ElectronicPaymentMethod.instaPay:
        return const Color(0xFF1E88E5);
    }
  }
}
