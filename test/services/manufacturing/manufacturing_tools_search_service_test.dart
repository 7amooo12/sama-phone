import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/models/manufacturing/production_batch.dart';
import 'package:smartbiztracker_new/services/manufacturing/manufacturing_tools_search_service.dart';

void main() {
  group('ManufacturingToolsSearchService', () {
    late ManufacturingToolsSearchService searchService;
    late List<ToolUsageAnalytics> testAnalytics;

    setUp(() {
      searchService = ManufacturingToolsSearchService();
      testAnalytics = [
        ToolUsageAnalytics(
          toolId: 1,
          toolName: 'مطرقة كبيرة',
          unit: 'قطعة',
          quantityUsedPerUnit: 1.0,
          totalQuantityUsed: 10.0,
          remainingStock: 5.0,
          initialStock: 15.0,
          usagePercentage: 66.7,
          stockStatus: 'medium',
          usageHistory: [
            ToolUsageEntry(
              id: 1,
              batchId: 1,
              quantityUsed: 5.0,
              usageDate: DateTime(2024, 1, 1),
            ),
            ToolUsageEntry(
              id: 2,
              batchId: 2,
              quantityUsed: 5.0,
              usageDate: DateTime(2024, 1, 15),
            ),
          ],
        ),
        ToolUsageAnalytics(
          toolId: 2,
          toolName: 'مفك صغير',
          unit: 'قطعة',
          quantityUsedPerUnit: 2.0,
          totalQuantityUsed: 20.0,
          remainingStock: 2.0,
          initialStock: 22.0,
          usagePercentage: 90.9,
          stockStatus: 'low',
          usageHistory: [
            ToolUsageEntry(
              id: 3,
              batchId: 1,
              quantityUsed: 10.0,
              usageDate: DateTime(2024, 1, 5),
            ),
            ToolUsageEntry(
              id: 4,
              batchId: 3,
              quantityUsed: 10.0,
              usageDate: DateTime(2024, 1, 20),
            ),
          ],
        ),
        ToolUsageAnalytics(
          toolId: 3,
          toolName: 'منشار كهربائي',
          unit: 'قطعة',
          quantityUsedPerUnit: 0.5,
          totalQuantityUsed: 5.0,
          remainingStock: 15.0,
          initialStock: 20.0,
          usagePercentage: 25.0,
          stockStatus: 'high',
          usageHistory: [
            ToolUsageEntry(
              id: 5,
              batchId: 2,
              quantityUsed: 5.0,
              usageDate: DateTime(2024, 1, 10),
            ),
          ],
        ),
      ];
    });

    group('searchToolUsageAnalytics', () {
      test('should return all items when no criteria provided', () {
        // Arrange
        const criteria = ToolSearchCriteria();

        // Act
        final result = searchService.searchToolUsageAnalytics(testAnalytics, criteria);

        // Assert
        expect(result.items.length, equals(3));
        expect(result.totalCount, equals(3));
        expect(result.filteredCount, equals(3));
        expect(result.isFiltered, isFalse);
      });

      test('should filter by search query', () {
        // Arrange
        const criteria = ToolSearchCriteria(searchQuery: 'مطرقة');

        // Act
        final result = searchService.searchToolUsageAnalytics(testAnalytics, criteria);

        // Assert
        expect(result.items.length, equals(1));
        expect(result.items.first.toolName, contains('مطرقة'));
        expect(result.isFiltered, isTrue);
      });

      test('should filter by stock status', () {
        // Arrange
        const criteria = ToolSearchCriteria(stockStatuses: ['low']);

        // Act
        final result = searchService.searchToolUsageAnalytics(testAnalytics, criteria);

        // Assert
        expect(result.items.length, equals(1));
        expect(result.items.first.stockStatus, equals('low'));
      });

      test('should filter by usage percentage range', () {
        // Arrange
        const criteria = ToolSearchCriteria(
          minUsagePercentage: 50.0,
          maxUsagePercentage: 80.0,
        );

        // Act
        final result = searchService.searchToolUsageAnalytics(testAnalytics, criteria);

        // Assert
        expect(result.items.length, equals(1));
        expect(result.items.first.usagePercentage, greaterThanOrEqualTo(50.0));
        expect(result.items.first.usagePercentage, lessThanOrEqualTo(80.0));
      });

      test('should filter by date range', () {
        // Arrange
        final criteria = ToolSearchCriteria(
          usageDateFrom: DateTime(2024, 1, 1),
          usageDateTo: DateTime(2024, 1, 10),
        );

        // Act
        final result = searchService.searchToolUsageAnalytics(testAnalytics, criteria);

        // Assert
        expect(result.items.length, greaterThan(0));
        for (final item in result.items) {
          if (item.usageHistory.isNotEmpty) {
            final firstUsage = item.usageHistory.first.usageDate;
            expect(firstUsage.isAfter(DateTime(2023, 12, 31)), isTrue);
            expect(firstUsage.isBefore(DateTime(2024, 1, 11)), isTrue);
          }
        }
      });

      test('should sort by name ascending', () {
        // Arrange
        const criteria = ToolSearchCriteria(
          sortBy: 'name',
          sortAscending: true,
        );

        // Act
        final result = searchService.searchToolUsageAnalytics(testAnalytics, criteria);

        // Assert
        expect(result.items.length, equals(3));
        expect(result.items[0].toolName, equals('مطرقة كبيرة'));
        expect(result.items[1].toolName, equals('مفك صغير'));
        expect(result.items[2].toolName, equals('منشار كهربائي'));
      });

      test('should sort by usage percentage descending', () {
        // Arrange
        const criteria = ToolSearchCriteria(
          sortBy: 'usage_percentage',
          sortAscending: false,
        );

        // Act
        final result = searchService.searchToolUsageAnalytics(testAnalytics, criteria);

        // Assert
        expect(result.items.length, equals(3));
        expect(result.items[0].usagePercentage, greaterThan(result.items[1].usagePercentage));
        expect(result.items[1].usagePercentage, greaterThan(result.items[2].usagePercentage));
      });

      test('should combine multiple filters', () {
        // Arrange
        const criteria = ToolSearchCriteria(
          searchQuery: 'مفك',
          stockStatuses: ['low'],
          minUsagePercentage: 80.0,
        );

        // Act
        final result = searchService.searchToolUsageAnalytics(testAnalytics, criteria);

        // Assert
        expect(result.items.length, equals(1));
        expect(result.items.first.toolName, contains('مفك'));
        expect(result.items.first.stockStatus, equals('low'));
        expect(result.items.first.usagePercentage, greaterThanOrEqualTo(80.0));
      });

      test('should calculate aggregations correctly', () {
        // Arrange
        const criteria = ToolSearchCriteria();

        // Act
        final result = searchService.searchToolUsageAnalytics(testAnalytics, criteria);

        // Assert
        expect(result.aggregations['tools_count'], equals(3));
        expect(result.aggregations['total_quantity_used'], equals(35.0));
        
        final avgUsage = result.aggregations['average_usage_percentage'] as double;
        expect(avgUsage, closeTo(60.87, 0.1));
        
        final statusDistribution = result.aggregations['status_distribution'] as Map<String, int>;
        expect(statusDistribution['medium'], equals(1));
        expect(statusDistribution['low'], equals(1));
        expect(statusDistribution['high'], equals(1));
      });
    });

    group('searchRequiredTools', () {
      late List<RequiredToolItem> testTools;

      setUp(() {
        testTools = [
          RequiredToolItem(
            toolId: 1,
            toolName: 'مسامير حديد',
            unit: 'كيلو',
            quantityPerUnit: 0.5,
            totalQuantityNeeded: 10.0,
            availableStock: 8.0,
            shortfall: 2.0,
            isAvailable: false,
            availabilityStatus: 'partial',
          ),
          RequiredToolItem(
            toolId: 2,
            toolName: 'غراء خشب',
            unit: 'لتر',
            quantityPerUnit: 0.1,
            totalQuantityNeeded: 2.0,
            availableStock: 5.0,
            shortfall: 0.0,
            isAvailable: true,
            availabilityStatus: 'available',
          ),
        ];
      });

      test('should filter by availability', () {
        // Arrange
        const criteria = ToolSearchCriteria(isAvailable: true);

        // Act
        final result = searchService.searchRequiredTools(testTools, criteria);

        // Assert
        expect(result.items.length, equals(1));
        expect(result.items.first.isAvailable, isTrue);
      });

      test('should filter by search query', () {
        // Arrange
        const criteria = ToolSearchCriteria(searchQuery: 'غراء');

        // Act
        final result = searchService.searchRequiredTools(testTools, criteria);

        // Assert
        expect(result.items.length, equals(1));
        expect(result.items.first.toolName, contains('غراء'));
      });

      test('should calculate aggregations for required tools', () {
        // Arrange
        const criteria = ToolSearchCriteria();

        // Act
        final result = searchService.searchRequiredTools(testTools, criteria);

        // Assert
        expect(result.aggregations['total_quantity_needed'], equals(12.0));
        expect(result.aggregations['total_available_stock'], equals(13.0));
        expect(result.aggregations['total_shortfall'], equals(2.0));
        expect(result.aggregations['available_tools_count'], equals(1));
        expect(result.aggregations['unavailable_tools_count'], equals(1));
        expect(result.aggregations['availability_percentage'], equals(50.0));
      });
    });

    group('ToolSearchCriteria', () {
      test('should detect active filters correctly', () {
        // Arrange & Act
        const emptyCriteria = ToolSearchCriteria();
        const criteriaWithSearch = ToolSearchCriteria(searchQuery: 'test');
        const criteriaWithFilters = ToolSearchCriteria(
          stockStatuses: ['high'],
          minUsagePercentage: 50.0,
        );

        // Assert
        expect(emptyCriteria.hasActiveFilters, isFalse);
        expect(emptyCriteria.activeFiltersCount, equals(0));
        
        expect(criteriaWithSearch.hasActiveFilters, isTrue);
        expect(criteriaWithSearch.activeFiltersCount, equals(1));
        
        expect(criteriaWithFilters.hasActiveFilters, isTrue);
        expect(criteriaWithFilters.activeFiltersCount, equals(2));
      });

      test('should copy with modifications correctly', () {
        // Arrange
        const original = ToolSearchCriteria(
          searchQuery: 'original',
          stockStatuses: ['high'],
        );

        // Act
        final modified = original.copyWith(
          searchQuery: 'modified',
          minUsagePercentage: 50.0,
        );

        // Assert
        expect(modified.searchQuery, equals('modified'));
        expect(modified.stockStatuses, equals(['high'])); // unchanged
        expect(modified.minUsagePercentage, equals(50.0)); // new
      });
    });

    group('ToolSearchResults', () {
      test('should calculate filter ratio correctly', () {
        // Arrange
        const criteria = ToolSearchCriteria(searchQuery: 'test');
        final results = ToolSearchResults(
          items: [testAnalytics.first],
          totalCount: 3,
          filteredCount: 1,
          criteria: criteria,
        );

        // Assert
        expect(results.filterRatio, closeTo(0.33, 0.01));
        expect(results.isFiltered, isTrue);
      });
    });
  });
}
