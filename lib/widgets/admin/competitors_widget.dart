import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/competitor_product.dart';
import '../../services/competitor_service.dart';

class CompetitorsWidget extends StatefulWidget {
  const CompetitorsWidget({super.key});

  @override
  _CompetitorsWidgetState createState() => _CompetitorsWidgetState();
}

class _CompetitorsWidgetState extends State<CompetitorsWidget> {
  final Map<String, List<CompetitorProduct>> _competitorProducts = {};
  final Map<String, bool> _loadingStates = {};
  final Map<String, String?> _errorMessages = {};
  final Set<String> _expandedCompetitors = {};

  @override
  void initState() {
    super.initState();
    // لا نحمل البيانات تلقائياً، سنحملها عند الضغط على الكارد
  }

  Future<void> _loadSpecificCompetitor(String competitorKey) async {
    try {
      setState(() {
        _loadingStates[competitorKey] = true;
        _errorMessages[competitorKey] = null;
      });

      List<CompetitorProduct> products = [];

      if (competitorKey == 'wadihome') {
        products = await CompetitorService.fetchWadiHomeProducts();
      } else if (competitorKey == 'anarat') {
        products = await CompetitorService.fetchAnaratProducts();
      } else if (competitorKey == 'nawrly') {
        products = await CompetitorService.fetchNawrlyProducts();
      } else if (competitorKey == 'lamaison') {
        products = await CompetitorService.fetchLamaisonProducts();
      }

      if (mounted) {
        setState(() {
          _competitorProducts[competitorKey] = products;
          _loadingStates[competitorKey] = false;
          _expandedCompetitors.add(competitorKey);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessages[competitorKey] = e.toString();
          _loadingStates[competitorKey] = false;
        });
      }
    }
  }

  void _toggleCompetitor(String competitorKey) {
    if (_expandedCompetitors.contains(competitorKey)) {
      setState(() {
        _expandedCompetitors.remove(competitorKey);
      });
    } else {
      if (!_competitorProducts.containsKey(competitorKey)) {
        _loadSpecificCompetitor(competitorKey);
      } else {
        setState(() {
          _expandedCompetitors.add(competitorKey);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'تحليل المنافسين',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Cairo',
          ),
        ),
        backgroundColor: const Color(0xFF10B981),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _competitorProducts.clear();
                _loadingStates.clear();
                _errorMessages.clear();
                _expandedCompetitors.clear();
              });
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCard(),
          const SizedBox(height: 16),
          Text(
            'اضغط على أي منافس لعرض منتجاته',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF10B981),
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 16),
          _buildCompetitorCard('wadihome', 'WadiHome'),
          const SizedBox(height: 16),
          _buildCompetitorCard('anarat', 'انارات'),
          const SizedBox(height: 16),
          _buildCompetitorCard('nawrly', 'نورلي'),
          const SizedBox(height: 16),
          _buildCompetitorCard('lamaison', 'lamaison'),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    int totalProducts = 0;
    int loadedCompetitors = 0;

    _competitorProducts.forEach((key, products) {
      totalProducts += products.length;
      if (products.isNotEmpty) loadedCompetitors++;
    });

    return Card(
      elevation: 2,
      color: isDark ? Colors.grey.shade900 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.grey.shade900,
                    Colors.grey.shade800,
                  ]
                : [
                    const Color(0xFF10B981).withOpacity(0.1),
                    const Color(0xFF10B981).withOpacity(0.05),
                  ],
          ),
          border: isDark
              ? Border.all(color: const Color(0xFF10B981).withOpacity(0.3))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem(
                'المنافسين المحملين',
                '$loadedCompetitors',
                Icons.store,
                const Color(0xFF10B981),
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: isDark ? Colors.grey[600] : Colors.grey[300],
            ),
            Expanded(
              child: _buildStatItem(
                'إجمالي المنتجات',
                '$totalProducts',
                Icons.inventory,
                const Color(0xFF10B981),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : Colors.grey[600],
            fontWeight: FontWeight.w500,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }

  Widget _buildCompetitorCard(String key, String name) {
    final products = _competitorProducts[key] ?? [];
    final isLoading = _loadingStates[key] ?? false;
    final errorMessage = _errorMessages[key];
    final isExpanded = _expandedCompetitors.contains(key);

    // Different colors for different competitors
    List<Color> gradientColors;
    Color badgeColor;
    IconData competitorIcon;

    if (key == 'wadihome') {
      gradientColors = [
        const Color(0xFF10B981),
        const Color(0xFF059669),
        const Color(0xFF047857),
      ];
      badgeColor = const Color(0xFF10B981);
      competitorIcon = Icons.store;
    } else if (key == 'anarat') {
      gradientColors = [
        const Color(0xFF3B82F6),
        const Color(0xFF2563EB),
        const Color(0xFF1D4ED8),
      ];
      badgeColor = const Color(0xFF3B82F6);
      competitorIcon = Icons.lightbulb;
    } else if (key == 'nawrly') {
      gradientColors = [
        const Color(0xFFF59E0B),
        const Color(0xFFD97706),
        const Color(0xFFB45309),
      ];
      badgeColor = const Color(0xFFF59E0B);
      competitorIcon = Icons.wb_incandescent;
    } else if (key == 'lamaison') {
      gradientColors = [
        const Color(0xFF8B5CF6),
        const Color(0xFF7C3AED),
        const Color(0xFF6D28D9),
      ];
      badgeColor = const Color(0xFF8B5CF6);
      competitorIcon = Icons.home_filled;
    } else {
      gradientColors = [
        const Color(0xFF6B7280),
        const Color(0xFF4B5563),
        const Color(0xFF374151),
      ];
      badgeColor = const Color(0xFF6B7280);
      competitorIcon = Icons.business;
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: Column(
          children: [
            // Header - Clickable
            InkWell(
              onTap: () => _toggleCompetitor(key),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        competitorIcon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            isLoading
                                ? 'جاري التحميل...'
                                : products.isNotEmpty
                                    ? '${products.length} منتج'
                                    : 'اضغط لعرض المنتجات',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'منافس',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.white,
                          size: 24,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Content Area - Only show when expanded
            if (isExpanded)
              Container(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade900
                    : Colors.white,
                child: _buildCompetitorContent(key, products, isLoading, errorMessage),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompetitorContent(String key, List<CompetitorProduct> products, bool isLoading, String? errorMessage) {
    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'جاري تحميل منتجات $key...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'قد يستغرق هذا بضع ثوانٍ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'خطأ في تحميل البيانات',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadSpecificCompetitor(key),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                ),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text(
            'لا توجد منتجات متاحة',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // عرض معلومات إجمالية
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory, color: Colors.green[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'إجمالي المنتجات: ${products.length}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
        ),
        // عرض جميع المنتجات
        Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: products.length, // عرض جميع المنتجات
            itemBuilder: (context, index) {
              return _buildProductCard(products[index]);
            },
          ),
        ),
      ],
    );
  }



  void _showImageDialog(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(
                      Icons.error,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCompetitorBadgeColor(CompetitorProduct product) {
    // Determine competitor based on vendor or other product properties
    if (product.vendor.toLowerCase().contains('wadi') ||
        product.vendor.toLowerCase().contains('home')) {
      return Colors.orange;
    } else if (product.vendor.toLowerCase().contains('انارات') ||
               product.vendor.toLowerCase().contains('anarat')) {
      return Colors.purple;
    } else if (product.vendor.toLowerCase().contains('نورلي') ||
               product.vendor.toLowerCase().contains('nawrly')) {
      return Colors.deepOrange;
    } else if (product.vendor.toLowerCase().contains('lamaison')) {
      return Colors.pink;
    }
    return Colors.grey;
  }

  Widget _buildProductCard(CompetitorProduct product) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.grey[50]!,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (product.imageUrl.isNotEmpty) {
                          _showImageDialog(product.imageUrl, product.title);
                        }
                      },
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: product.imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: product.imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                    size: 32,
                                  ),
                                ),
                              )
                            : Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                  size: 32,
                                ),
                              ),
                      ),
                    ),
                    // Competitor badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getCompetitorBadgeColor(product).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'منافس',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Zoom icon
                    if (product.imageUrl.isNotEmpty)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.zoom_in,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Product Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.vendor,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[600],
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            product.formattedPrice,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                        if (product.variants.isNotEmpty && product.variants.first.available)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'متاح',
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
