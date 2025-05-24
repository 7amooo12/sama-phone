/// Base chart data class for all chart data models
class ChartData {
  /// Creates a chart data point
  const ChartData({
    required this.name,
    required this.value,
    this.label,
  });

  /// Simplified constructor with positional parameters (for backwards compatibility)
  ChartData.simple(this.name, this.value) : label = null;

  /// The name/label for the chart item
  final String name;

  /// The numeric value for the chart item
  final double value;

  /// An optional additional label
  final String? label;
}

/// Chart data model for waste tracking
class WasteChartData extends ChartData {
  /// Creates a waste chart data point
  const WasteChartData({
    required super.name,
    required super.value,
    super.label,
  });

  /// Simplified constructor with positional parameters (for backwards compatibility)
  WasteChartData.simple(super.name, super.value) : super.simple();
}

/// Chart data model for productivity tracking
class ProductivityChartData extends ChartData {
  /// Creates a productivity chart data point
  const ProductivityChartData({
    required super.name,
    required super.value,
    super.label,
  });

  /// Simplified constructor with positional parameters (for backwards compatibility)
  ProductivityChartData.simple(super.name, super.value) : super.simple();
}

/// Chart data model for return tracking
class ReturnChartData extends ChartData {
  /// Creates a return chart data point
  const ReturnChartData({
    required super.name,
    required super.value,
    super.label,
  });

  /// Simplified constructor with positional parameters (for backwards compatibility)
  ReturnChartData.simple(super.name, super.value) : super.simple();
}

/// Chart data model for order tracking
class OrderChartData extends ChartData {
  /// Creates an order chart data point
  const OrderChartData({
    required super.name,
    required super.value,
    super.label,
  });

  /// Simplified constructor with positional parameters (for backwards compatibility)
  OrderChartData.simple(super.name, super.value) : super.simple();
}

class ChartDataPoint {
  const ChartDataPoint({
    required this.name,
    required this.value,
    this.label,
  });
  final String name;
  final double value;
  final String? label;
}

class SalesChartData extends ChartDataPoint {
  const SalesChartData({
    required super.name,
    required super.value,
    super.label,
  });
}

class RevenueChartData extends ChartDataPoint {
  const RevenueChartData({
    required super.name,
    required super.value,
    super.label,
  });
}

class PerformanceChartData extends ChartDataPoint {
  const PerformanceChartData({
    required super.name,
    required super.value,
    super.label,
  });
}

class WastageChartData extends ChartDataPoint {
  const WastageChartData({
    required super.name,
    required super.value,
    super.label,
  });
}
