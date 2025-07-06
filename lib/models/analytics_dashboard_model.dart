class AnalyticsDashboardModel { // Optional for backward compatibility

  const AnalyticsDashboardModel({
    required this.users,
    required this.products,
    required this.sales,
    this.inventory,
  });

  factory AnalyticsDashboardModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsDashboardModel(
      users: UserStats.fromJson(json['users'] as Map<String, dynamic>),
      products: ProductStats.fromJson(json['products'] as Map<String, dynamic>),
      sales: SalesStats.fromJson(json['sales'] as Map<String, dynamic>),
      inventory: json['inventory'] != null ? InventoryStats.fromJson(json['inventory'] as Map<String, dynamic>) : null,
    );
  }
  final UserStats users;
  final ProductStats products;
  final SalesStats sales;
  final InventoryStats? inventory;
}

class UserStats {

  const UserStats({
    required this.total,
    required this.active,
    required this.pending,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      total: json['total'] as int,
      active: json['active'] as int,
      pending: json['pending'] as int,
    );
  }
  final int total;
  final int active;
  final int pending;
}

class ProductStats {

  const ProductStats({
    required this.total,
    required this.visible,
    required this.outOfStock,
    required this.featured,
  });

  factory ProductStats.fromJson(Map<String, dynamic> json) {
    return ProductStats(
      total: json['total'] as int,
      visible: json['visible'] as int,
      outOfStock: json['out_of_stock'] as int,
      featured: json['featured'] as int,
    );
  }
  final int total;
  final int visible;
  final int outOfStock;
  final int featured;
}

class SalesStats {

  const SalesStats({
    required this.totalInvoices,
    required this.completedInvoices,
    required this.pendingInvoices,
    required this.totalAmount,
    required this.daily,
    required this.byCategory,
  });

  factory SalesStats.fromJson(Map<String, dynamic> json) {
    return SalesStats(
      totalInvoices: json['total_invoices'] as int,
      completedInvoices: json['completed_invoices'] as int,
      pendingInvoices: json['pending_invoices'] as int,
      totalAmount: json['total_amount'] as double,
      daily: (json['daily'] as List)
          .map((e) => DailySales.fromJson(e as Map<String, dynamic>))
          .toList(),
      byCategory: (json['by_category'] as List)
          .map((e) => CategorySales.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
  final int totalInvoices;
  final int completedInvoices;
  final int pendingInvoices;
  final double totalAmount;
  final List<DailySales> daily;
  final List<CategorySales> byCategory;
}

class DailySales {

  const DailySales({required this.date, required this.sales});

  factory DailySales.fromJson(Map<String, dynamic> json) {
    return DailySales(
      date: json['date'] as String,
      sales: json['sales'] as double,
    );
  }
  final String date;
  final double sales;
}

class CategorySales {

  const CategorySales({required this.category, required this.sales});

  factory CategorySales.fromJson(Map<String, dynamic> json) {
    return CategorySales(
      category: json['category'] as String,
      sales: json['sales'] as double,
    );
  }
  final String category;
  final double sales;
}

class InventoryStats {

  const InventoryStats({required this.movement});

  factory InventoryStats.fromJson(Map<String, dynamic> json) {
    return InventoryStats(
      movement: MovementStats.fromJson(json['movement'] as Map<String, dynamic>),
    );
  }
  final MovementStats movement;
}

class MovementStats {

  const MovementStats({
    required this.additions,
    required this.reductions,
    required this.totalQuantityChange,
  });

  factory MovementStats.fromJson(Map<String, dynamic> json) {
    return MovementStats(
      additions: json['additions'] as int,
      reductions: json['reductions'] as int,
      totalQuantityChange: json['total_quantity_change'] as int,
    );
  }
  final int additions;
  final int reductions;
  final int totalQuantityChange;
}