import 'package:smartbiztracker_new/models/product_model.dart';

/// This adapter class is used to make the new ProductModel
/// compatible with the old ProductModel structure
class ProductModelAdapter {
  // Constructor
  ProductModelAdapter(this.productModel);
  final ProductModel productModel;

  // Static method to create a ProductModel from the old format
  static ProductModel fromLegacyFormat({
    required String id,
    required String name,
    required String description,
    required double price,
    double? discountPrice,
    required String categoryId,
    required String categoryName,
    required bool inStock,
    required int quantity,
    String? imageUrl,
    required DateTime createdAt,
  }) {
    return ProductModel(
      id: id,
      name: name,
      description: description,
      price: price,
      quantity: quantity,
      category: categoryName,
      images: imageUrl != null ? [imageUrl] : [],
      sku: 'SKU-$id',
      isActive: inStock,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      minimumStock: 5,
      reorderPoint: 10,
    );
  }

  // Properties from the old model
  String get id => productModel.id;
  String get name => productModel.name;
  String get description => productModel.description;
  double get price => productModel.price;
  String get categoryId => 'category-${productModel.category}';
  String get categoryName => productModel.category;
  bool get inStock => productModel.quantity > 0;
  int get quantity => productModel.quantity;
  String? get imageUrl =>
      productModel.images.isNotEmpty ? productModel.images.first : null;
  DateTime get createdAt => productModel.createdAt;
  double? get discountPrice => null; // No direct equivalent in new model
}
