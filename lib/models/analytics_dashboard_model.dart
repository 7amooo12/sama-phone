class AnalyticsDashboardModel {
  final UserStats users;
  final ProductStats products;
  final SalesStats sales;
  final InventoryStats? inventory; // Optional for backward compatibility

  const AnalyticsDashboardModel({
    required this.users,
    required this.products,
    required this.sales,
    this.inventory,
  });

  factory AnalyticsDashboardModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsDashboardModel(
      users: UserStats.fromJson(json['users']),
      products: ProductStats.fromJson(json['products']),
      sales: SalesStats.fromJson(json['sales']),
      inventory: json['inventory'] != null ? InventoryStats.fromJson(json['inventory']) : null,
    );
  }
}

class UserStats {
  final int total;
  final int active;
  final int pending;

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
}

class ProductStats {
  final int total;
  final int visible;
  final int outOfStock;
  final int featured;

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
}

class SalesStats {
  final int totalInvoices;
  final int completedInvoices;
  final int pendingInvoices;
  final double totalAmount;
  final List<DailySales> daily;
  final List<CategorySales> byCategory;

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
}

class DailySales {
  final String date;
  final double sales;

  const DailySales({required this.date, required this.sales});

  factory DailySales.fromJson(Map<String, dynamic> json) {
    return DailySales(
      date: json['date'] as String,
      sales: json['sales'] as double,
    );
  }
}

class CategorySales {
  final String category;
  final double sales;

  const CategorySales({required this.category, required this.sales});

  factory CategorySales.fromJson(Map<String, dynamic> json) {
    return CategorySales(
      category: json['category'] as String,
      sales: json['sales'] as double,
    );
  }
}

class InventoryStats {
  final MovementStats movement;

  const InventoryStats({required this.movement});

  factory InventoryStats.fromJson(Map<String, dynamic> json) {
    return InventoryStats(
      movement: MovementStats.fromJson(json['movement']),
    );
  }
}

class MovementStats {
  final int additions;
  final int reductions;
  final int totalQuantityChange;

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
} 