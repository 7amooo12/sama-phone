import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/widgets/common/elegant_search_bar.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';

class SearchFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final List<String> categories;
  final String selectedCategory;
  final List<String> sortOptions;
  final String selectedSortOption;
  final Function(String) onSearchChanged;
  final Function(String) onCategorySelected;
  final Function(String) onSortOptionSelected;

  const SearchFilterBar({
    Key? key,
    required this.searchController,
    required this.categories,
    required this.selectedCategory,
    required this.sortOptions,
    required this.selectedSortOption,
    required this.onSearchChanged,
    required this.onCategorySelected,
    required this.onSortOptionSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GlassSearchBar(
      controller: searchController,
      hintText: 'البحث عن منتج...',
      accentColor: StyleSystem.primaryColor,
      onChanged: onSearchChanged,
    );
  }
} 