/// ودجت البحث في المخازن
/// Widget for warehouse search functionality

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/warehouse_search_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/models/warehouse_search_models.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/widgets/warehouse/warehouse_search_results_widget.dart';

class WarehouseSearchWidget extends StatefulWidget {
  const WarehouseSearchWidget({super.key});

  @override
  State<WarehouseSearchWidget> createState() => _WarehouseSearchWidgetState();
}

class _WarehouseSearchWidgetState extends State<WarehouseSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onFocusChange);
    _initializeSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChange);
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isSearchFocused = _searchFocusNode.hasFocus;
    });
  }

  Future<void> _initializeSearch() async {
    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final searchProvider = Provider.of<WarehouseSearchProvider>(context, listen: false);
      
      final currentUser = supabaseProvider.user;
      if (currentUser != null) {
        await searchProvider.initialize(currentUser.id);
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تهيئة البحث: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WarehouseSearchProvider>(
      builder: (context, searchProvider, child) {
        return Container(
          decoration: const BoxDecoration(
            gradient: AccountantThemeConfig.mainBackgroundGradient,
          ),
          child: Column(
            children: [
              // شريط البحث
              _buildSearchBar(searchProvider),
              
              // النتائج
              Expanded(
                child: _buildSearchContent(searchProvider),
              ),
            ],
          ),
        );
      },
    );
  }

  /// بناء شريط البحث
  Widget _buildSearchBar(WarehouseSearchProvider searchProvider) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isSearchFocused 
              ? AccountantThemeConfig.primaryGreen
              : Colors.white.withValues(alpha: 0.1),
          width: _isSearchFocused ? 2 : 1,
        ),
        boxShadow: _isSearchFocused
            ? AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen)
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            // أيقونة البحث
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: _isSearchFocused
                    ? AccountantThemeConfig.greenGradient
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.search,
                color: _isSearchFocused
                    ? Colors.white
                    : AccountantThemeConfig.primaryGreen,
                size: 24,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // حقل البحث
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textDirection: TextDirection.rtl,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'البحث عن المنتج أو الفئة...',
                  hintStyle: GoogleFonts.cairo(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (query) {
                  searchProvider.setSearchQuery(query);
                },
                onSubmitted: (query) {
                  searchProvider.searchImmediately();
                },
              ),
            ),
            
            // مؤشر التحميل أو زر المسح
            if (searchProvider.isSearching)
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(left: 8),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AccountantThemeConfig.primaryGreen,
                  ),
                ),
              )
            else if (_searchController.text.isNotEmpty)
              IconButton(
                onPressed: () {
                  _searchController.clear();
                  searchProvider.setSearchQuery('');
                  _searchFocusNode.unfocus();
                },
                icon: Icon(
                  Icons.clear,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 20,
                ),
                tooltip: 'مسح البحث',
              ),
          ],
        ),
      ),
    );
  }

  /// بناء محتوى البحث
  Widget _buildSearchContent(WarehouseSearchProvider searchProvider) {
    if (searchProvider.isLoading) {
      return _buildLoadingState();
    }

    if (searchProvider.error != null) {
      return _buildErrorState(searchProvider);
    }

    if (searchProvider.searchQuery.isEmpty) {
      return _buildInitialState();
    }

    if (searchProvider.searchQuery.length < 2) {
      return _buildMinimumCharactersState();
    }

    if (searchProvider.isEmpty) {
      return _buildEmptyResultsState(searchProvider);
    }

    return WarehouseSearchResultsWidget(
      searchResults: searchProvider.searchResults!,
      onLoadMore: searchProvider.hasMore ? searchProvider.loadMoreResults : null,
      isLoadingMore: searchProvider.isLoadingMore,
    );
  }

  /// بناء حالة التحميل
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              AccountantThemeConfig.primaryGreen,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'جاري تهيئة البحث...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// بناء حالة الخطأ
  Widget _buildErrorState(WarehouseSearchProvider searchProvider) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: AccountantThemeConfig.primaryCardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: AccountantThemeConfig.warningOrange,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'خطأ في البحث',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              searchProvider.error!,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _initializeSearch(),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: Text(
                'إعادة المحاولة',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// بناء الحالة الأولية
  Widget _buildInitialState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: AccountantThemeConfig.primaryCardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.greenGradient,
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.search,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ابدأ بكتابة اسم المنتج أو الفئة',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'يمكنك البحث عن المنتجات حسب الاسم أو الفئة أو رقم SKU',
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// بناء حالة الحد الأدنى من الأحرف
  Widget _buildMinimumCharactersState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: AccountantThemeConfig.primaryCardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.keyboard,
              color: AccountantThemeConfig.accentBlue,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'اكتب حرفين على الأقل للبحث',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'الحد الأدنى للبحث هو حرفان',
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// بناء حالة عدم وجود نتائج
  Widget _buildEmptyResultsState(WarehouseSearchProvider searchProvider) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: AccountantThemeConfig.primaryCardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              color: Colors.white.withValues(alpha: 0.5),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد نتائج للبحث',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'لم يتم العثور على منتجات أو فئات تطابق "${searchProvider.searchQuery}"',
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'اقتراحات:',
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AccountantThemeConfig.primaryGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• تأكد من صحة الإملاء\n• جرب كلمات مختلفة\n• استخدم كلمات أقل تحديداً',
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: Colors.white60,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
