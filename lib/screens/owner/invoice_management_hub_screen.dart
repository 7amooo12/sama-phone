import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/config/routes.dart';

/// Professional Invoice Management Hub Screen
/// Serves as a navigation hub for accessing both Purchase and Sales invoice functionality
/// Features sophisticated UI design with SAMA branding and AccountantThemeConfig styling
class InvoiceManagementHubScreen extends StatefulWidget {
  const InvoiceManagementHubScreen({super.key});

  @override
  State<InvoiceManagementHubScreen> createState() => _InvoiceManagementHubScreenState();
}

class _InvoiceManagementHubScreenState extends State<InvoiceManagementHubScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: AccountantThemeConfig.longAnimationDuration,
      vsync: this,
    );
    _slideController = AnimationController(
      duration: AccountantThemeConfig.animationDuration,
      vsync: this,
    );
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width >= 768;
    final isMobile = screenSize.width < 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header - fixed size
              _buildHeader(context, isMobile),

              // Main content - flexible
              _buildNavigationHub(context, isTablet, isMobile),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the professional header with SAMA branding
  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      child: Column(
        children: [
          // SAMA Logo and Title (without back button)
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    AccountantThemeConfig.primaryGreen,
                    AccountantThemeConfig.secondaryGreen,
                  ],
                ).createShader(bounds),
                child: Text(
                  'SAMA',
                  style: GoogleFonts.cairo(
                    fontSize: isMobile ? 24 : 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'إدارة الفواتير',
                style: GoogleFonts.cairo(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ).animate(controller: _fadeController).fadeIn(
            duration: 600.ms,
            curve: Curves.easeOutCubic,
          ).slideY(
            begin: -0.3,
            duration: 600.ms,
            curve: Curves.easeOutCubic,
          ),

          SizedBox(height: isMobile ? 16 : 20),

          // Welcome message - simplified for better space management
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 20,
              vertical: isMobile ? 12 : 16
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.greenGradient,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white,
                    size: isMobile ? 16 : 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'اختر نوع الفاتورة المطلوبة',
                    style: GoogleFonts.cairo(
                      fontSize: isMobile ? 13 : 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ).animate(controller: _fadeController).fadeIn(
            delay: const Duration(milliseconds: 200),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
          ).slideY(
            begin: 0.3,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }

  /// Build the main navigation hub with invoice type cards
  Widget _buildNavigationHub(BuildContext context, bool isTablet, bool isMobile) {
    return Flexible(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 20,
          vertical: isMobile ? 8 : 12,
        ),
        child: Column(
          children: [
            Expanded(
              flex: 8, // Give more space to the main content
              child: isTablet
                  ? _buildTabletLayout(context)
                  : _buildMobileLayout(context, isMobile),
            ),

            // Footer with additional info - reduced space
            Flexible(
              flex: 1,
              child: _buildFooter(context, isMobile),
            ),
          ],
        ),
      ),
    );
  }

  /// Build tablet layout with side-by-side cards
  Widget _buildTabletLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildInvoiceCard(
            context: context,
            title: 'فاتورة مشتريات',
            subtitle: 'إدارة فواتير المشتريات والموردين',
            icon: Icons.shopping_cart_rounded,
            gradient: AccountantThemeConfig.greenGradient,
            onTap: () => _navigateToPurchaseInvoices(context),
            delay: 0,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildInvoiceCard(
            context: context,
            title: 'فاتورة مبيعات',
            subtitle: 'عرض وإدارة فواتير المبيعات',
            icon: Icons.point_of_sale_rounded,
            gradient: AccountantThemeConfig.blueGradient,
            onTap: () => _navigateToSalesInvoices(context),
            delay: 200,
          ),
        ),
      ],
    );
  }

  /// Build mobile layout with stacked cards
  Widget _buildMobileLayout(BuildContext context, bool isMobile) {
    return Column(
      children: [
        Expanded(
          child: _buildInvoiceCard(
            context: context,
            title: 'فاتورة مشتريات',
            subtitle: 'إدارة فواتير المشتريات والموردين',
            icon: Icons.shopping_cart_rounded,
            gradient: AccountantThemeConfig.greenGradient,
            onTap: () => _navigateToPurchaseInvoices(context),
            delay: 0,
            isMobile: isMobile,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: _buildInvoiceCard(
            context: context,
            title: 'فاتورة مبيعات',
            subtitle: 'عرض وإدارة فواتير المبيعات',
            icon: Icons.point_of_sale_rounded,
            gradient: AccountantThemeConfig.blueGradient,
            onTap: () => _navigateToSalesInvoices(context),
            delay: 200,
            isMobile: isMobile,
          ),
        ),
      ],
    );
  }

  /// Build professional invoice card with sophisticated styling
  Widget _buildInvoiceCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required LinearGradient gradient,
    required VoidCallback onTap,
    required int delay,
    bool isMobile = false,
  }) {
    return Flexible(
      child: Container(
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: AccountantThemeConfig.cardShadows,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon with gradient background
                  Container(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AccountantThemeConfig.glowShadows(
                        gradient.colors.first,
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: isMobile ? 28 : 32,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(height: isMobile ? 12 : 16),

                  // Title
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: isMobile ? 6 : 8),

                  // Subtitle
                  Text(
                    subtitle,
                    style: GoogleFonts.cairo(
                      fontSize: isMobile ? 12 : 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.8),
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: isMobile ? 12 : 16),

                  // Action indicator
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: isMobile ? 6 : 8
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'اضغط للدخول',
                          style: GoogleFonts.cairo(
                            fontSize: isMobile ? 11 : 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: isMobile ? 10 : 12,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ).animate(controller: _slideController).fadeIn(
        delay: Duration(milliseconds: delay),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
      ).slideY(
        begin: 0.3,
        delay: Duration(milliseconds: delay),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
      ).scale(
        begin: const Offset(0.8, 0.8),
        delay: Duration(milliseconds: delay),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  /// Build footer with additional information
  Widget _buildFooter(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AccountantThemeConfig.primaryGreen,
            size: isMobile ? 14 : 16,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'اختر نوع الفاتورة المطلوبة',
              style: GoogleFonts.cairo(
                fontSize: isMobile ? 11 : 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ).animate(controller: _fadeController).fadeIn(
      delay: const Duration(milliseconds: 400),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    ).slideY(
      begin: 0.2,
      delay: const Duration(milliseconds: 400),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  /// Navigate to Purchase Invoices Screen
  void _navigateToPurchaseInvoices(BuildContext context) {
    Navigator.of(context).pushNamed('/business-owner/purchase-invoices');
  }

  /// Navigate to Sales Invoices (Store Invoices) Screen
  void _navigateToSalesInvoices(BuildContext context) {
    // Navigate to business owner store invoices screen
    Navigator.of(context).pushNamed('/business-owner/store-invoices');
  }
}
