import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/accountant_theme_config.dart';
import '../../providers/treasury_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/electronic_wallet_provider.dart';
import '../../models/treasury_models.dart';
import '../../widgets/treasury/treasury_connection_painter.dart';
import '../../widgets/treasury/main_treasury_vault_widget.dart';
import '../../widgets/treasury/sub_treasury_card_widget.dart';
import '../../widgets/treasury/client_wallets_summary_card.dart';
import '../../widgets/treasury/electronic_wallets_summary_card.dart';
import '../../widgets/treasury/create_treasury_modal.dart';
import '../../services/ui_performance_optimizer.dart';
import '../../widgets/treasury/new_treasury_highlight_animation.dart';
import '../../widgets/treasury/exchange_rate_settings_modal.dart';
import '../treasury_control/treasury_control_screen.dart';

class TreasuryManagementScreen extends StatefulWidget {
  const TreasuryManagementScreen({super.key});

  @override
  State<TreasuryManagementScreen> createState() => _TreasuryManagementScreenState();
}

class _TreasuryManagementScreenState extends State<TreasuryManagementScreen>
    with TickerProviderStateMixin {

  // Animation controllers
  late AnimationController _connectionAnimation;
  late AnimationController _particleAnimation;

  // Scroll controller for dynamic connection lines
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  // State variables
  bool _isConnectionMode = false;
  bool _isConnectionManagementMode = false;
  String? _selectedTreasuryId;
  final NewTreasuryCreationNotifier _newTreasuryNotifier = NewTreasuryCreationNotifier();

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _connectionAnimation = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _particleAnimation = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    // Add scroll listener for dynamic connection lines
    _scrollController.addListener(_onScroll);

    // Initialize treasury provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TreasuryProvider>().initialize();
    });
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  @override
  void dispose() {
    _connectionAnimation.dispose();
    _particleAnimation.dispose();
    _scrollController.dispose();
    _newTreasuryNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Consumer<TreasuryProvider>(
                  builder: (context, treasuryProvider, child) {
                    if (treasuryProvider.isLoading) {
                      return _buildLoadingWidget();
                    }

                    if (treasuryProvider.error != null) {
                      return _buildErrorWidget(treasuryProvider.error!);
                    }

                    return _buildTreasuryLayout(treasuryProvider);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }



  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AccountantThemeConfig.primaryGreen),
          ),
          SizedBox(height: 16),
          Text(
            'جاري تحميل بيانات الخزنة...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const Spacer(),
          // Enhanced Statistics summary with all balance components - Optimized for performance
          UIPerformanceOptimizer.cachedWidget(
            cacheKey: 'treasury_header_stats',
            customExpiry: const Duration(seconds: 30), // Cache for 30 seconds
            builder: () => Consumer3<TreasuryProvider, WalletProvider, ElectronicWalletProvider>(
              builder: (context, treasuryProvider, walletProvider, electronicWalletProvider, child) {
                if (treasuryProvider.statistics != null) {
                  // Calculate component balances
                  final mainTreasuryBalance = treasuryProvider.statistics!.mainTreasuryBalance;
                  final treasuryBalance = treasuryProvider.statistics!.totalBalanceEgp;
                  final clientWalletBalance = walletProvider.totalClientBalance;
                  final electronicWalletBalance = electronicWalletProvider.totalBalance;

                  // Calculate total balance including all components
                  final totalBalance = treasuryBalance + clientWalletBalance + electronicWalletBalance;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.cardGradient,
                    borderRadius: BorderRadius.circular(12),
                    border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
                    boxShadow: AccountantThemeConfig.cardShadows,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Total balance header
                      Text(
                        'إجمالي الرصيد الكامل',
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: AccountantThemeConfig.white70,
                        ),
                      ),
                      Text(
                        '${totalBalance.toStringAsFixed(2)} ج.م',
                        style: AccountantThemeConfig.headlineSmall.copyWith(
                          color: AccountantThemeConfig.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Balance breakdown
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildBalanceComponent(
                            'الخزائن',
                            treasuryBalance,
                            AccountantThemeConfig.accentBlue,
                          ),
                          _buildBalanceComponent(
                            'المحافظ',
                            clientWalletBalance,
                            AccountantThemeConfig.primaryGreen,
                          ),
                          _buildBalanceComponent(
                            'الإلكترونية',
                            electronicWalletBalance,
                            Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          ),
          const SizedBox(width: 12),
          // Exchange Rate Settings Button
          _buildExchangeRateSettingsButton(),
        ],
      ),
    );
  }

  Widget _buildBalanceComponent(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: AccountantThemeConfig.white70,
            fontSize: 10,
          ),
        ),
        Text(
          '${amount.toStringAsFixed(0)} ج.م',
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildExchangeRateSettingsButton() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.accentBlue,
            AccountantThemeConfig.accentBlue.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: _showExchangeRateSettings,
          child: const Icon(
            Icons.settings_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  void _showExchangeRateSettings() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ExchangeRateSettingsModal(),
    );
  }

  Widget _buildTreasuryLayout(TreasuryProvider treasuryProvider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 768;
        final isDesktop = constraints.maxWidth > 1200;
        
        return Stack(
          children: [
            // Connection lines layer
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_connectionAnimation, _particleAnimation]),
                builder: (context, child) {
                  return CustomPaint(
                    painter: TreasuryConnectionPainter(
                      treasuries: treasuryProvider.treasuryVaults,
                      connections: treasuryProvider.connections,
                      connectionAnimation: _connectionAnimation.value,
                      particleAnimation: _particleAnimation.value,
                      isConnectionMode: _isConnectionMode,
                      selectedTreasuryId: _selectedTreasuryId,
                      scrollOffset: _scrollOffset,
                    ),
                  );
                },
              ),
            ),

            // Treasury vaults layer
            SingleChildScrollView(
              controller: _scrollController,
              padding: _getResponsivePadding(isTablet, isDesktop),
              child: Column(
                children: [
                  // Wallet Summary Cards - Professional Side-by-Side Layout (moved to top)
                  // These cards are now positioned at the top of the treasury hierarchy
                  Container(
                    width: double.infinity,
                    child: _buildWalletSummaryCards(isTablet, isDesktop),
                  ),

                  SizedBox(height: _getResponsiveSpacing(isTablet, isDesktop)),

                  // Main Treasury Vault (moved below wallet cards)
                  if (treasuryProvider.mainTreasury != null)
                    Center(
                      child: SizedBox(
                        width: constraints.maxWidth * (isDesktop ? 0.7 : isTablet ? 0.8 : 0.9),
                        child: MainTreasuryVaultWidget(
                          treasury: treasuryProvider.mainTreasury!,
                          allTreasuries: treasuryProvider.treasuryVaults,
                          onTap: () => _handleTreasuryTap(treasuryProvider.mainTreasury!.id),
                          onLongPress: () => _handleTreasuryLongPress(treasuryProvider.mainTreasury!.id),
                          isSelected: _selectedTreasuryId == treasuryProvider.mainTreasury!.id,
                          isConnectionMode: _isConnectionMode,
                        ),
                      ),
                    ),

                  SizedBox(height: _getResponsiveSpacing(isTablet, isDesktop) * 0.75),

                  // Sub-treasuries grid
                  if (treasuryProvider.subTreasuries.isNotEmpty)
                    _buildSubTreasuriesGrid(
                      treasuryProvider.subTreasuries,
                      treasuryProvider,
                      isTablet,
                      isDesktop,
                    ),

                  // Empty state for sub-treasuries
                  if (treasuryProvider.subTreasuries.isEmpty)
                    _buildEmptySubTreasuriesState(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubTreasuriesGrid(
    List<TreasuryVault> subTreasuries,
    TreasuryProvider treasuryProvider,
    bool isTablet,
    bool isDesktop,
  ) {
    return _buildSubTreasuriesTreeLayout(subTreasuries, treasuryProvider, isTablet, isDesktop);
  }

  Widget _buildSubTreasuriesTreeLayout(
    List<TreasuryVault> subTreasuries,
    TreasuryProvider treasuryProvider,
    bool isTablet,
    bool isDesktop,
  ) {
    if (subTreasuries.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final cardWidth = _getCardWidth(screenWidth, isTablet, isDesktop);
        // Use compact height system specifically for sub-treasury cards
        final cardHeight = _getSubTreasuryCardHeight(isTablet, isDesktop);

        // Calculate tree layout positions
        final positions = _calculateTreePositions(
          subTreasuries.length,
          screenWidth,
          cardWidth,
          cardHeight,
          isTablet,
          isDesktop,
        );

        return SizedBox(
          height: _calculateTreeHeight(subTreasuries.length, cardHeight),
          child: Stack(
            children: subTreasuries.asMap().entries.map((entry) {
              final index = entry.key;
              final treasury = entry.value;
              final position = positions[index];

              return Positioned(
                left: position.dx,
                top: position.dy,
                child: SizedBox(
                  width: cardWidth,
                  height: cardHeight,
                  child: ListenableBuilder(
                    listenable: _newTreasuryNotifier,
                    builder: (context, child) {
                      return NewTreasuryHighlightAnimation(
                        isNewTreasury: _newTreasuryNotifier.isNewTreasury(treasury.id),
                        onAnimationComplete: () {
                          // Animation completed for this treasury
                        },
                        child: SubTreasuryCardWidget(
                          treasury: treasury,
                          allTreasuries: treasuryProvider.treasuryVaults,
                          onTap: () => _handleTreasuryTap(treasury.id),
                          onLongPress: () => _handleTreasuryLongPress(treasury.id),
                          isSelected: _selectedTreasuryId == treasury.id,
                          isConnectionMode: _isConnectionMode,
                          isConnectionManagementMode: _isConnectionManagementMode,
                          connections: treasuryProvider.getConnectionsForTreasury(treasury.id),
                          onConnectionRemove: _handleConnectionRemove,
                        ),
                      );
                    },
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildEmptySubTreasuriesState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_rounded,
            size: 80,
            color: AccountantThemeConfig.white60,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد خزائن فرعية',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: AccountantThemeConfig.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط على زر + لإنشاء خزنة فرعية جديدة',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.white60,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build wallet summary cards with professional side-by-side layout
  /// These cards are displayed horizontally with proper spacing and larger dimensions for better content display
  Widget _buildWalletSummaryCards(bool isTablet, bool isDesktop) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final spacing = _getResponsiveSpacing(isTablet, isDesktop);

        // Increased card height for better content accommodation
        final cardHeight = _getResponsiveCardHeight(isTablet, isDesktop);

        // Calculate responsive card width with increased dimensions for better text display
        final availableWidth = screenWidth - (spacing * 2); // Account for left and right spacing
        final minCardWidth = isDesktop ? 380.0 : isTablet ? 320.0 : 280.0; // Increased minimum widths
        final maxCardWidth = isDesktop ? 550.0 : isTablet ? 450.0 : 380.0; // Increased maximum widths

        return Container(
          width: double.infinity,
          height: cardHeight,
          padding: EdgeInsets.symmetric(horizontal: spacing / 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Client Wallets Summary Card - Left Side
              Expanded(
                flex: 1,
                child: Container(
                  height: cardHeight,
                  constraints: BoxConstraints(
                    minWidth: minCardWidth,
                    maxWidth: maxCardWidth,
                  ),
                  margin: EdgeInsets.only(right: spacing / 2),
                  child: ClientWalletsSummaryCard(
                    onTap: () => _handleWalletSummaryTap('client_wallets'),
                    onLongPress: () => _handleWalletSummaryLongPress('client_wallets'),
                    isSelected: _selectedTreasuryId == 'client_wallets',
                    isConnectionMode: _isConnectionMode,
                  ),
                ),
              ),

              // Spacing between cards
              SizedBox(width: spacing),

              // Electronic Wallets Summary Card - Right Side
              Expanded(
                flex: 1,
                child: Container(
                  height: cardHeight,
                  constraints: BoxConstraints(
                    minWidth: minCardWidth,
                    maxWidth: maxCardWidth,
                  ),
                  margin: EdgeInsets.only(left: spacing / 2),
                  child: ElectronicWalletsSummaryCard(
                    onTap: () => _handleWalletSummaryTap('electronic_wallets'),
                    onLongPress: () => _handleWalletSummaryLongPress('electronic_wallets'),
                    isSelected: _selectedTreasuryId == 'electronic_wallets',
                    isConnectionMode: _isConnectionMode,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }



  /// Get the tree level for wallet summary cards in the treasury hierarchy
  /// Wallet summaries are positioned at level 1 (between main treasury at level 0 and sub-treasuries at level 2+)
  int _getWalletSummaryTreeLevel() {
    return 1; // Level 1 in the treasury tree hierarchy
  }

  double _getCardWidth(double screenWidth, bool isTablet, bool isDesktop) {
    // Optimized card width percentages for more compact layout while maintaining readability
    if (isDesktop) {
      // Desktop: 1200px+ - Reduced from 28% to 24% for more compact design
      return screenWidth * 0.24;
    } else if (isTablet) {
      // Tablet: 768px-1199px - Reduced from 38% to 32% for more compact design
      return screenWidth * 0.32;
    } else {
      // Mobile: <768px - Reduced from 48% to 42% for more compact design
      return screenWidth * 0.42;
    }
  }

  /// Get responsive padding based on screen size
  EdgeInsets _getResponsivePadding(bool isTablet, bool isDesktop) {
    if (isDesktop) {
      return const EdgeInsets.all(32);
    } else if (isTablet) {
      return const EdgeInsets.all(24);
    } else {
      return const EdgeInsets.all(16);
    }
  }

  /// Get responsive spacing based on screen size
  double _getResponsiveSpacing(bool isTablet, bool isDesktop) {
    if (isDesktop) {
      return 40.0;
    } else if (isTablet) {
      return 30.0;
    } else {
      return 20.0;
    }
  }

  /// Get responsive card height for wallet summary cards based on screen size
  double _getResponsiveCardHeight(bool isTablet, bool isDesktop) {
    if (isDesktop) {
      return 200.0; // Increased from 140 to 200 for desktop
    } else if (isTablet) {
      return 180.0; // Increased from 140 to 180 for tablet
    } else {
      return 160.0; // Increased from 140 to 160 for mobile
    }
  }

  /// Get responsive card height specifically for sub-treasury cards (more compact)
  double _getSubTreasuryCardHeight(bool isTablet, bool isDesktop) {
    if (isDesktop) {
      return 120.0; // Compact height for desktop sub-treasury cards
    } else if (isTablet) {
      return 120.0; // Compact height for tablet sub-treasury cards
    } else {
      return 120.0; // Compact height for mobile sub-treasury cards
    }
  }

  List<Offset> _calculateTreePositions(
    int count,
    double screenWidth,
    double cardWidth,
    double cardHeight,
    bool isTablet,
    bool isDesktop,
  ) {
    final positions = <Offset>[];
    final verticalSpacing = cardHeight + _getResponsiveSpacing(isTablet, isDesktop);
    final horizontalMargin = cardWidth * 0.05;

    if (count == 0) return positions;

    // Calculate positions based on a proper tree structure
    for (int i = 0; i < count; i++) {
      double x, y;

      if (count == 1) {
        // Single treasury: center it
        x = screenWidth * 0.5 - cardWidth / 2;
        y = 0;
      } else if (count == 2) {
        // Two treasuries: left and right
        if (i == 0) {
          x = screenWidth * 0.3 - cardWidth / 2; // Left position
          y = 0;
        } else {
          x = screenWidth * 0.7 - cardWidth / 2; // Right position
          y = 0;
        }
      } else if (count == 3) {
        // Three treasuries: top center, bottom left, bottom right
        if (i == 0) {
          x = screenWidth * 0.5 - cardWidth / 2; // Top center
          y = 0;
        } else if (i == 1) {
          x = screenWidth * 0.25 - cardWidth / 2; // Bottom left
          y = verticalSpacing;
        } else {
          x = screenWidth * 0.75 - cardWidth / 2; // Bottom right
          y = verticalSpacing;
        }
      } else if (count == 4) {
        // Four treasuries: 2x2 grid
        final row = i ~/ 2;
        final col = i % 2;
        x = screenWidth * (col == 0 ? 0.25 : 0.75) - cardWidth / 2;
        y = row * verticalSpacing;
      } else {
        // Five or more treasuries: use a more complex grid layout
        _calculateGridPosition(i, count, screenWidth, cardWidth, verticalSpacing, positions);
        continue;
      }

      // Ensure cards don't go outside screen bounds
      x = x.clamp(horizontalMargin, screenWidth - cardWidth - horizontalMargin);

      positions.add(Offset(x, y));
    }

    return positions;
  }

  void _calculateGridPosition(
    int index,
    int totalCount,
    double screenWidth,
    double cardWidth,
    double verticalSpacing,
    List<Offset> positions,
  ) {
    final horizontalMargin = cardWidth * 0.05;

    // For 5+ treasuries, use a dynamic grid approach
    // Calculate optimal columns based on screen width and card count
    int columns = _calculateOptimalColumns(totalCount, screenWidth, cardWidth);

    final row = index ~/ columns;
    final col = index % columns;

    // Calculate horizontal spacing to distribute cards evenly
    final availableWidth = screenWidth - (2 * horizontalMargin);
    final totalCardWidth = columns * cardWidth;
    final totalSpacing = availableWidth - totalCardWidth;
    final spacingBetweenCards = totalSpacing / (columns + 1);

    final x = horizontalMargin + spacingBetweenCards + (col * (cardWidth + spacingBetweenCards));
    final y = row * verticalSpacing;

    // Ensure cards don't go outside screen bounds
    final clampedX = x.clamp(horizontalMargin, screenWidth - cardWidth - horizontalMargin);

    positions.add(Offset(clampedX, y));
  }

  int _calculateOptimalColumns(int totalCount, double screenWidth, double cardWidth) {
    final horizontalMargin = cardWidth * 0.05;
    final availableWidth = screenWidth - (2 * horizontalMargin);

    // Calculate maximum possible columns based on screen width
    final maxColumns = (availableWidth / (cardWidth * 1.1)).floor(); // 1.1 for spacing

    // For different counts, choose optimal column layout
    if (totalCount <= 3) return totalCount;
    if (totalCount == 4) return 2;
    if (totalCount <= 6) return 3;
    if (totalCount <= 8) return 4;

    // For larger counts, use maximum columns but cap at 4 for readability
    return maxColumns.clamp(2, 4);
  }

  double _calculateTreeHeight(int count, double cardHeight) {
    if (count == 0) return 0;
    if (count == 1) return cardHeight;
    if (count <= 2) return cardHeight; // Single row for 2 treasuries
    if (count <= 3) return cardHeight * 2; // Two rows for 3 treasuries
    if (count == 4) return cardHeight * 2; // Two rows for 4 treasuries

    // For 5+ treasuries, calculate based on grid layout
    final columns = _calculateOptimalColumns(count, 1000, 200); // Use default values for calculation
    final rows = (count / columns).ceil();
    final verticalSpacing = cardHeight + 40; // Spacing between rows
    return rows * cardHeight + (rows - 1) * 40; // Total height with spacing
  }



  Widget _buildErrorWidget(String error) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.dangerRed),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AccountantThemeConfig.dangerRed,
            ),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: AccountantThemeConfig.dangerRed,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<TreasuryProvider>().initialize(),
              style: AccountantThemeConfig.primaryButtonStyle,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Connection management mode toggle button
        FloatingActionButton(
          heroTag: 'connection_management',
          onPressed: _toggleConnectionManagementMode,
          backgroundColor: _isConnectionManagementMode
              ? AccountantThemeConfig.dangerRed
              : AccountantThemeConfig.warningOrange,
          child: Icon(
            _isConnectionManagementMode ? Icons.close_rounded : Icons.link_off_rounded,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 12),

        // Connection mode toggle button
        FloatingActionButton(
          heroTag: 'connection_mode',
          onPressed: _toggleConnectionMode,
          backgroundColor: _isConnectionMode
              ? AccountantThemeConfig.dangerRed
              : AccountantThemeConfig.accentBlue,
          child: Icon(
            _isConnectionMode ? Icons.close_rounded : Icons.link_rounded,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 12),

        // Add treasury button
        FloatingActionButton(
          heroTag: 'add_treasury',
          onPressed: _showCreateTreasuryModal,
          backgroundColor: AccountantThemeConfig.primaryGreen,
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  void _handleTreasuryTap(String treasuryId) {
    if (_isConnectionMode) {
      if (_selectedTreasuryId == null) {
        // Select first treasury
        setState(() {
          _selectedTreasuryId = treasuryId;
        });
      } else if (_selectedTreasuryId == treasuryId) {
        // Deselect if same treasury
        setState(() {
          _selectedTreasuryId = null;
        });
      } else {
        // Create connection
        _createConnection(_selectedTreasuryId!, treasuryId);
      }
    }
  }

  void _handleTreasuryLongPress(String treasuryId) {
    // Navigate to treasury control screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TreasuryControlScreen(
          treasuryId: treasuryId,
          treasuryType: 'treasury',
        ),
      ),
    );
  }

  void _toggleConnectionMode() {
    setState(() {
      _isConnectionMode = !_isConnectionMode;
      _isConnectionManagementMode = false; // Disable management mode when entering connection mode
      _selectedTreasuryId = null;
    });
  }

  void _toggleConnectionManagementMode() {
    setState(() {
      _isConnectionManagementMode = !_isConnectionManagementMode;
      _isConnectionMode = false; // Disable connection mode when entering management mode
      _selectedTreasuryId = null;
    });
  }

  void _handleWalletSummaryTap(String walletType) {
    if (_isConnectionMode) {
      if (_selectedTreasuryId == null) {
        // Select wallet summary
        setState(() {
          _selectedTreasuryId = walletType;
        });
      } else if (_selectedTreasuryId == walletType) {
        // Deselect if same wallet type
        setState(() {
          _selectedTreasuryId = null;
        });
      } else {
        // Check if we can create a connection
        if (_canCreateWalletConnection(_selectedTreasuryId!, walletType)) {
          // Create connection between wallet summary and treasury or another wallet
          _createWalletConnection(_selectedTreasuryId!, walletType);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'لا يمكن إنشاء هذا الاتصال',
                style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } else {
      // Normal tap - navigate to wallet control screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TreasuryControlScreen(
            treasuryId: walletType,
            treasuryType: walletType,
          ),
        ),
      );
    }
  }

  void _handleWalletSummaryLongPress(String walletType) {
    // Navigate to wallet summary control screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TreasuryControlScreen(
          treasuryId: walletType,
          treasuryType: walletType,
        ),
      ),
    );
  }

  bool _canCreateWalletConnection(String sourceId, String targetId) {
    // Allow connections between wallet summaries and treasury vaults
    // Prevent connections between the same wallet types
    if (sourceId == targetId) return false;

    // Allow connections between different wallet types
    if ((sourceId == 'client_wallets' && targetId == 'electronic_wallets') ||
        (sourceId == 'electronic_wallets' && targetId == 'client_wallets')) {
      return true;
    }

    // Allow connections between wallet summaries and sub-treasuries
    final isSourceWallet = sourceId == 'client_wallets' || sourceId == 'electronic_wallets';
    final isTargetWallet = targetId == 'client_wallets' || targetId == 'electronic_wallets';

    if (isSourceWallet != isTargetWallet) {
      return true; // One is wallet, one is treasury
    }

    return false;
  }

  void _createWalletConnection(String sourceId, String targetId) {
    // For now, use the existing connection dialog
    // This will be enhanced later to support wallet-specific connections
    showDialog(
      context: context,
      builder: (context) => _ConnectionAmountDialog(
        sourceTreasuryId: sourceId,
        targetTreasuryId: targetId,
        onConnectionCreated: () {
          setState(() {
            _selectedTreasuryId = null;
            _isConnectionMode = false;
          });
        },
      ),
    );
  }

  void _handleConnectionRemove(String connectionId) {
    showDialog(
      context: context,
      builder: (context) => _ConnectionRemovalDialog(
        connectionId: connectionId,
        onConnectionRemoved: () {
          setState(() {
            // Refresh the UI after connection removal
          });
        },
      ),
    );
  }

  void _showCreateTreasuryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateTreasuryModal(
        onTreasuryCreated: (String treasuryId) {
          // Mark the newly created treasury for highlight animation
          _newTreasuryNotifier.markTreasuryAsNew(treasuryId);
        },
      ),
    );
  }

  void _createConnection(String sourceTreasuryId, String targetTreasuryId) {
    showDialog(
      context: context,
      builder: (context) => _ConnectionAmountDialog(
        sourceTreasuryId: sourceTreasuryId,
        targetTreasuryId: targetTreasuryId,
        onConnectionCreated: () {
          setState(() {
            _selectedTreasuryId = null;
            _isConnectionMode = false;
          });
          // Note: TreasuryProvider.createConnection already refreshes data automatically
        },
      ),
    );
  }
}

class _ConnectionAmountDialog extends StatefulWidget {
  final String sourceTreasuryId;
  final String targetTreasuryId;
  final VoidCallback onConnectionCreated;

  const _ConnectionAmountDialog({
    required this.sourceTreasuryId,
    required this.targetTreasuryId,
    required this.onConnectionCreated,
  });

  @override
  State<_ConnectionAmountDialog> createState() => _ConnectionAmountDialogState();
}

class _ConnectionAmountDialogState extends State<_ConnectionAmountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TreasuryProvider>(
      builder: (context, treasuryProvider, child) {
        final sourceTreasury = treasuryProvider.treasuryVaults
            .firstWhere((t) => t.id == widget.sourceTreasuryId);
        final targetTreasury = treasuryProvider.treasuryVaults
            .firstWhere((t) => t.id == widget.targetTreasuryId);

    return AlertDialog(
      backgroundColor: Colors.transparent,
      content: Container(
        width: 400,
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'إنشاء اتصال خزنة',
                  style: AccountantThemeConfig.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Source treasury info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.cardGradient,
                    borderRadius: BorderRadius.circular(12),
                    border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
                  ),
                  child: Row(
                    children: [
                      Text(sourceTreasury.currencyFlag, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sourceTreasury.name,
                              style: AccountantThemeConfig.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'الرصيد: ${sourceTreasury.balance.toStringAsFixed(2)} ${sourceTreasury.currencySymbol}',
                              style: AccountantThemeConfig.bodySmall.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Arrow
                Icon(
                  Icons.arrow_downward_rounded,
                  color: AccountantThemeConfig.primaryGreen,
                  size: 32,
                ),

                const SizedBox(height: 12),

                // Target treasury info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.cardGradient,
                    borderRadius: BorderRadius.circular(12),
                    border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
                  ),
                  child: Row(
                    children: [
                      Text(targetTreasury.currencyFlag, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              targetTreasury.name,
                              style: AccountantThemeConfig.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'الرصيد: ${targetTreasury.balance.toStringAsFixed(2)} ${targetTreasury.currencySymbol}',
                              style: AccountantThemeConfig.bodySmall.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Amount input
                TextFormField(
                  controller: _amountController,
                  style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AccountantThemeConfig.primaryGreen, width: 2),
                    ),
                    labelText: 'المبلغ المراد نقله',
                    suffixText: sourceTreasury.currencySymbol,
                    prefixIcon: const Icon(Icons.currency_exchange_rounded, color: Colors.white70),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال المبلغ';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'يرجى إدخال مبلغ صحيح';
                    }
                    if (amount > sourceTreasury.balance) {
                      return 'المبلغ أكبر من الرصيد المتاح';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        child: Text(
                          'إلغاء',
                          style: AccountantThemeConfig.bodyMedium.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createConnection,
                        style: AccountantThemeConfig.primaryButtonStyle,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('إنشاء الاتصال'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
      },
    );
  }

  Future<void> _createConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = double.parse(_amountController.text);

      // Actually create the connection using TreasuryProvider
      await context.read<TreasuryProvider>().createConnection(
        sourceTreasuryId: widget.sourceTreasuryId,
        targetTreasuryId: widget.targetTreasuryId,
        connectionAmount: amount,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onConnectionCreated();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إنشاء الاتصال بنجاح (${amount.toStringAsFixed(2)} ج.م)',
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: AccountantThemeConfig.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'فشل في إنشاء الاتصال: $e',
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: AccountantThemeConfig.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

class _ConnectionRemovalDialog extends StatefulWidget {
  final String connectionId;
  final VoidCallback onConnectionRemoved;

  const _ConnectionRemovalDialog({
    required this.connectionId,
    required this.onConnectionRemoved,
  });

  @override
  State<_ConnectionRemovalDialog> createState() => _ConnectionRemovalDialogState();
}

class _ConnectionRemovalDialogState extends State<_ConnectionRemovalDialog> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.transparent,
      content: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(20),
          border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.dangerRed),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_rounded,
              color: AccountantThemeConfig.dangerRed,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'إزالة الاتصال',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'هل أنت متأكد من إزالة هذا الاتصال؟ سيتم إرجاع الأموال إلى الخزنة المصدر.',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AccountantThemeConfig.white70,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'إلغاء',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _removeConnection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AccountantThemeConfig.dangerRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'إزالة',
                            style: AccountantThemeConfig.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeConnection() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Actually remove the connection using TreasuryProvider
      final treasuryProvider = Provider.of<TreasuryProvider>(context, listen: false);
      await treasuryProvider.removeConnection(widget.connectionId);

      if (mounted) {
        Navigator.pop(context);
        widget.onConnectionRemoved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إزالة الاتصال بنجاح',
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: AccountantThemeConfig.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'فشل في إزالة الاتصال: $e',
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: AccountantThemeConfig.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
