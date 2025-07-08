import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/services/manufacturing/manufacturing_tools_search_service.dart';

/// ويدجت البحث والفلترة لأدوات التصنيع
class ManufacturingToolsSearchWidget extends StatefulWidget {
  final ToolSearchCriteria initialCriteria;
  final Function(ToolSearchCriteria) onCriteriaChanged;
  final VoidCallback? onExport;
  final bool showExportButton;
  final String searchHint;

  const ManufacturingToolsSearchWidget({
    super.key,
    required this.initialCriteria,
    required this.onCriteriaChanged,
    this.onExport,
    this.showExportButton = true,
    this.searchHint = 'البحث في الأدوات...',
  });

  @override
  State<ManufacturingToolsSearchWidget> createState() => _ManufacturingToolsSearchWidgetState();
}

class _ManufacturingToolsSearchWidgetState extends State<ManufacturingToolsSearchWidget>
    with TickerProviderStateMixin {
  late TextEditingController _searchController;
  late ToolSearchCriteria _currentCriteria;
  bool _showAdvancedFilters = false;
  late AnimationController _filtersAnimationController;
  late Animation<double> _filtersAnimation;

  // قوائم الخيارات
  final List<String> _stockStatusOptions = ['high', 'medium', 'low', 'critical'];
  final List<String> _unitOptions = ['قطعة', 'كيلو', 'متر', 'لتر', 'جرام'];
  final List<String> _sortOptions = [
    'name',
    'usage_percentage',
    'total_used',
    'remaining_stock',
    'stock_status',
  ];

  @override
  void initState() {
    super.initState();
    _currentCriteria = widget.initialCriteria;
    _searchController = TextEditingController(text: _currentCriteria.searchQuery ?? '');
    _setupAnimations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filtersAnimationController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _filtersAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _filtersAnimation = CurvedAnimation(
      parent: _filtersAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(Colors.white.withOpacity(0.3)),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchHeader(),
          const SizedBox(height: 16),
          _buildSearchBar(),
          const SizedBox(height: 16),
          _buildQuickFilters(),
          if (_showAdvancedFilters) ...[
            const SizedBox(height: 16),
            _buildAdvancedFilters(),
          ],
          const SizedBox(height: 16),
          _buildActionButtons(),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0);
  }

  Widget _buildSearchHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AccountantThemeConfig.accentBlue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.search,
            color: AccountantThemeConfig.accentBlue,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'البحث والفلترة',
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (_currentCriteria.hasActiveFilters)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AccountantThemeConfig.primaryGreen.withOpacity(0.5),
              ),
            ),
            child: Text(
              '${_currentCriteria.activeFiltersCount} فلتر نشط',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: AccountantThemeConfig.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
            decoration: InputDecoration(
              hintText: widget.searchHint,
              hintStyle: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white54,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.white54,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: _clearSearch,
                      icon: Icon(
                        Icons.clear,
                        color: Colors.white54,
                      ),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AccountantThemeConfig.accentBlue),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: _toggleAdvancedFilters,
            icon: Icon(
              _showAdvancedFilters ? Icons.filter_list_off : Icons.filter_list,
              color: _showAdvancedFilters 
                  ? AccountantThemeConfig.primaryGreen 
                  : Colors.white70,
            ),
            tooltip: _showAdvancedFilters ? 'إخفاء الفلاتر المتقدمة' : 'إظهار الفلاتر المتقدمة',
          ),
        ),
      ],
    );
  }

  Widget _buildQuickFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildQuickFilterChip(
          'مخزون عالي',
          _currentCriteria.stockStatuses?.contains('high') == true,
          () => _toggleStockStatusFilter('high'),
          Colors.green,
        ),
        _buildQuickFilterChip(
          'مخزون منخفض',
          _currentCriteria.stockStatuses?.contains('low') == true,
          () => _toggleStockStatusFilter('low'),
          Colors.orange,
        ),
        _buildQuickFilterChip(
          'مخزون حرج',
          _currentCriteria.stockStatuses?.contains('critical') == true,
          () => _toggleStockStatusFilter('critical'),
          Colors.red,
        ),
        _buildQuickFilterChip(
          'متوفر',
          _currentCriteria.isAvailable == true,
          () => _toggleAvailabilityFilter(true),
          AccountantThemeConfig.primaryGreen,
        ),
        _buildQuickFilterChip(
          'غير متوفر',
          _currentCriteria.isAvailable == false,
          () => _toggleAvailabilityFilter(false),
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildQuickFilterChip(String label, bool isSelected, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.5) : Colors.white.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: isSelected ? color : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    ).animate().scale(duration: 200.ms);
  }

  Widget _buildAdvancedFilters() {
    return SizeTransition(
      sizeFactor: _filtersAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'فلاتر متقدمة',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildUsagePercentageFilter(),
            const SizedBox(height: 16),
            _buildDateRangeFilter(),
            const SizedBox(height: 16),
            _buildSortingOptions(),
          ],
        ),
      ),
    );
  }

  Widget _buildUsagePercentageFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'نسبة الاستهلاك (%)',
          style: AccountantThemeConfig.bodySmall.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                style: AccountantThemeConfig.bodySmall.copyWith(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'من',
                  hintStyle: AccountantThemeConfig.bodySmall.copyWith(color: Colors.white54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final percentage = double.tryParse(value);
                  _updateCriteria(_currentCriteria.copyWith(minUsagePercentage: percentage));
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'إلى',
              style: AccountantThemeConfig.bodySmall.copyWith(color: Colors.white70),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                style: AccountantThemeConfig.bodySmall.copyWith(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'إلى',
                  hintStyle: AccountantThemeConfig.bodySmall.copyWith(color: Colors.white54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final percentage = double.tryParse(value);
                  _updateCriteria(_currentCriteria.copyWith(maxUsagePercentage: percentage));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateRangeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'نطاق التاريخ',
          style: AccountantThemeConfig.bodySmall.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _selectDate(true),
                icon: Icon(Icons.calendar_today, size: 16),
                label: Text(
                  _currentCriteria.usageDateFrom != null
                      ? '${_currentCriteria.usageDateFrom!.day}/${_currentCriteria.usageDateFrom!.month}'
                      : 'من تاريخ',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _selectDate(false),
                icon: Icon(Icons.calendar_today, size: 16),
                label: Text(
                  _currentCriteria.usageDateTo != null
                      ? '${_currentCriteria.usageDateTo!.day}/${_currentCriteria.usageDateTo!.month}'
                      : 'إلى تاريخ',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSortingOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ترتيب النتائج',
          style: AccountantThemeConfig.bodySmall.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _currentCriteria.sortBy,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                dropdownColor: AccountantThemeConfig.backgroundColor,
                style: AccountantThemeConfig.bodySmall.copyWith(color: Colors.white),
                items: _sortOptions.map((option) {
                  return DropdownMenuItem(
                    value: option,
                    child: Text(_getSortOptionLabel(option)),
                  );
                }).toList(),
                onChanged: (value) {
                  _updateCriteria(_currentCriteria.copyWith(sortBy: value));
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                _updateCriteria(_currentCriteria.copyWith(
                  sortAscending: !_currentCriteria.sortAscending,
                ));
              },
              icon: Icon(
                _currentCriteria.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (_currentCriteria.hasActiveFilters)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _clearAllFilters,
              icon: Icon(Icons.clear_all),
              label: Text('مسح الفلاتر'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
            ),
          ),
        if (_currentCriteria.hasActiveFilters && widget.showExportButton)
          const SizedBox(width: 12),
        if (widget.showExportButton)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: widget.onExport,
              icon: Icon(Icons.file_download),
              label: Text('تصدير'),
              style: AccountantThemeConfig.primaryButtonStyle,
            ),
          ),
      ],
    );
  }

  void _onSearchChanged(String query) {
    _updateCriteria(_currentCriteria.copyWith(searchQuery: query.isEmpty ? null : query));
  }

  void _clearSearch() {
    _searchController.clear();
    _updateCriteria(_currentCriteria.copyWith(searchQuery: null));
  }

  void _toggleAdvancedFilters() {
    setState(() {
      _showAdvancedFilters = !_showAdvancedFilters;
      if (_showAdvancedFilters) {
        _filtersAnimationController.forward();
      } else {
        _filtersAnimationController.reverse();
      }
    });
  }

  void _toggleStockStatusFilter(String status) {
    final currentStatuses = List<String>.from(_currentCriteria.stockStatuses ?? []);
    if (currentStatuses.contains(status)) {
      currentStatuses.remove(status);
    } else {
      currentStatuses.add(status);
    }
    _updateCriteria(_currentCriteria.copyWith(
      stockStatuses: currentStatuses.isEmpty ? null : currentStatuses,
    ));
  }

  void _toggleAvailabilityFilter(bool isAvailable) {
    final newValue = _currentCriteria.isAvailable == isAvailable ? null : isAvailable;
    _updateCriteria(_currentCriteria.copyWith(isAvailable: newValue));
  }

  void _selectDate(bool isFromDate) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AccountantThemeConfig.primaryGreen,
              surface: AccountantThemeConfig.backgroundColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      if (isFromDate) {
        _updateCriteria(_currentCriteria.copyWith(usageDateFrom: date));
      } else {
        _updateCriteria(_currentCriteria.copyWith(usageDateTo: date));
      }
    }
  }

  void _clearAllFilters() {
    _searchController.clear();
    _updateCriteria(const ToolSearchCriteria());
  }

  void _updateCriteria(ToolSearchCriteria newCriteria) {
    setState(() {
      _currentCriteria = newCriteria;
    });
    widget.onCriteriaChanged(newCriteria);
  }

  String _getSortOptionLabel(String option) {
    switch (option) {
      case 'name':
        return 'الاسم';
      case 'usage_percentage':
        return 'نسبة الاستهلاك';
      case 'total_used':
        return 'إجمالي المستخدم';
      case 'remaining_stock':
        return 'المخزون المتبقي';
      case 'stock_status':
        return 'حالة المخزون';
      default:
        return option;
    }
  }
}

/// حوار تصدير تقارير أدوات التصنيع
class ManufacturingToolsExportDialog extends StatefulWidget {
  final Function(String format, Map<String, dynamic> options)? onExport;

  const ManufacturingToolsExportDialog({
    super.key,
    this.onExport,
  });

  @override
  State<ManufacturingToolsExportDialog> createState() => _ManufacturingToolsExportDialogState();
}

class _ManufacturingToolsExportDialogState extends State<ManufacturingToolsExportDialog> {
  String _selectedFormat = 'csv';
  bool _includeAnalytics = true;
  bool _includeGapAnalysis = true;
  bool _includeForecast = true;
  bool _includeHistory = false;
  bool _includeCharts = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AccountantThemeConfig.backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.file_download,
              color: AccountantThemeConfig.primaryGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'تصدير التقرير',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تنسيق الملف',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildFormatSelector(),
            const SizedBox(height: 20),
            Text(
              'محتوى التقرير',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildContentOptions(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'إلغاء',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _exportReport,
          icon: Icon(Icons.download),
          label: Text('تصدير'),
          style: AccountantThemeConfig.primaryButtonStyle,
        ),
      ],
    );
  }

  Widget _buildFormatSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildFormatOption('csv', 'CSV', Icons.table_chart),
          ),
          Expanded(
            child: _buildFormatOption('json', 'JSON', Icons.code),
          ),
          Expanded(
            child: _buildFormatOption('pdf', 'PDF', Icons.picture_as_pdf),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatOption(String format, String label, IconData icon) {
    final isSelected = _selectedFormat == format;

    return GestureDetector(
      onTap: () => setState(() => _selectedFormat = format),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AccountantThemeConfig.primaryGreen.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: AccountantThemeConfig.primaryGreen.withOpacity(0.5)) : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AccountantThemeConfig.primaryGreen : Colors.white70,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: isSelected ? AccountantThemeConfig.primaryGreen : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentOptions() {
    return Column(
      children: [
        _buildContentOption(
          'تحليلات استخدام الأدوات',
          'بيانات الاستهلاك والمخزون',
          _includeAnalytics,
          (value) => setState(() => _includeAnalytics = value),
          Icons.analytics,
        ),
        _buildContentOption(
          'تحليل فجوة الإنتاج',
          'مقارنة الإنتاج الحالي بالهدف',
          _includeGapAnalysis,
          (value) => setState(() => _includeGapAnalysis = value),
          Icons.trending_up,
        ),
        _buildContentOption(
          'توقعات الأدوات المطلوبة',
          'الأدوات اللازمة لإكمال الإنتاج',
          _includeForecast,
          (value) => setState(() => _includeForecast = value),
          Icons.psychology,
        ),
        _buildContentOption(
          'تاريخ الاستخدام',
          'سجل استخدام الأدوات التفصيلي',
          _includeHistory,
          (value) => setState(() => _includeHistory = value),
          Icons.history,
        ),
        if (_selectedFormat == 'pdf')
          _buildContentOption(
            'الرسوم البيانية',
            'مخططات وإحصائيات بصرية',
            _includeCharts,
            (value) => setState(() => _includeCharts = value),
            Icons.bar_chart,
          ),
      ],
    );
  }

  Widget _buildContentOption(
    String title,
    String description,
    bool value,
    Function(bool) onChanged,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: value ? AccountantThemeConfig.primaryGreen : Colors.white54,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AccountantThemeConfig.primaryGreen,
            activeTrackColor: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  void _exportReport() {
    final options = {
      'include_analytics': _includeAnalytics,
      'include_gap_analysis': _includeGapAnalysis,
      'include_forecast': _includeForecast,
      'include_history': _includeHistory,
      'include_charts': _includeCharts,
    };

    widget.onExport?.call(_selectedFormat, options);
    Navigator.pop(context);
  }
}
