import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'lib/providers/wallet_provider.dart';
import 'lib/utils/accountant_theme_config.dart';

/// Simple test widget to verify wallet management UI improvements
class TestWalletManagementUI extends StatefulWidget {
  const TestWalletManagementUI({super.key});

  @override
  State<TestWalletManagementUI> createState() => _TestWalletManagementUIState();
}

class _TestWalletManagementUIState extends State<TestWalletManagementUI>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isStatisticsExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('إدارة المحافظ - اختبار'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: Column(
          children: [
            // Improved Statistics Cards Section
            _buildImprovedStatisticsCards(),

            // Tab Bar
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.cardGradient,
                borderRadius: BorderRadius.circular(12),
                border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
              ),
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.people_rounded), text: 'العملاء'),
                  Tab(icon: Icon(Icons.engineering_rounded), text: 'العمال'),
                  Tab(icon: Icon(Icons.receipt_long_rounded), text: 'المعاملات'),
                ],
                indicatorColor: AccountantThemeConfig.primaryGreen,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
              ),
            ),

            // Expanded Tab Content (More screen space)
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTestWalletList('client'),
                  _buildTestWalletList('worker'),
                  _buildTestTransactionsList(),
                ],
              ),
            ),
          ],
        ),
      ),
      // No floating action button - removed as requested
    );
  }

  Widget _buildImprovedStatisticsCards() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Clickable Total Balance Card
          GestureDetector(
            onTap: () {
              setState(() {
                _isStatisticsExpanded = !_isStatisticsExpanded;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.greenGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      Text(
                        'إجمالي الأرصدة',
                        style: AccountantThemeConfig.headlineSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      AnimatedRotation(
                        turns: _isStatisticsExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.expand_more_rounded,
                          color: Colors.white.withValues(alpha: 0.8),
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '125,750.00 ج.م',
                    style: AccountantThemeConfig.headlineLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'اضغط لعرض التفاصيل',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Detailed Statistics
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isStatisticsExpanded ? null : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _isStatisticsExpanded ? 1.0 : 0.0,
              child: _isStatisticsExpanded
                  ? Container(
                      margin: const EdgeInsets.only(top: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: 'أرصدة العملاء',
                              value: '85,250.00 ج.م',
                              icon: Icons.people_rounded,
                              color: AccountantThemeConfig.primaryGreen,
                              count: 24,
                              countLabel: 'عميل نشط',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              title: 'أرصدة العمال',
                              value: '40,500.00 ج.م',
                              icon: Icons.engineering_rounded,
                              color: AccountantThemeConfig.accentBlue,
                              count: 12,
                              countLabel: 'عامل نشط',
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    int? count,
    String? countLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: AccountantThemeConfig.glowBorder(color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Icon(Icons.trending_up_rounded, color: AccountantThemeConfig.successGreen, size: 14),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          if (count != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count ${countLabel ?? 'محفظة نشطة'}',
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTestWalletList(String type) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(12),
            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AccountantThemeConfig.primaryGreen,
                child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$type ${index + 1}',
                      style: AccountantThemeConfig.bodyLarge.copyWith(color: Colors.white),
                    ),
                    Text(
                      'الرصيد: ${(1000 + index * 500).toStringAsFixed(2)} ج.م',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: AccountantThemeConfig.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTestTransactionsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 15,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(12),
            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
          ),
          child: Row(
            children: [
              Icon(
                index % 2 == 0 ? Icons.add_circle : Icons.remove_circle,
                color: index % 2 == 0 ? AccountantThemeConfig.successGreen : Colors.red,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'معاملة ${index + 1}',
                      style: AccountantThemeConfig.bodyLarge.copyWith(color: Colors.white),
                    ),
                    Text(
                      '${index % 2 == 0 ? '+' : '-'}${(100 + index * 50).toStringAsFixed(2)} ج.م',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: index % 2 == 0 ? AccountantThemeConfig.successGreen : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
