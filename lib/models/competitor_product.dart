class CompetitorProduct {

  CompetitorProduct({
    required this.id,
    required this.title,
    required this.handle,
    required this.bodyHtml,
    required this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.vendor,
    required this.productType,
    required this.tags,
    required this.variants,
    required this.images,
    required this.options,
  });

  factory CompetitorProduct.fromJson(Map<String, dynamic> json) {
    return CompetitorProduct(
      id: (json['id'] as int?) ?? 0,
      title: (json['title'] as String?) ?? '',
      handle: (json['handle'] as String?) ?? '',
      bodyHtml: (json['body_html'] as String?) ?? '',
      publishedAt: (json['published_at'] as String?) ?? '',
      createdAt: (json['created_at'] as String?) ?? '',
      updatedAt: (json['updated_at'] as String?) ?? '',
      vendor: (json['vendor'] as String?) ?? '',
      productType: (json['product_type'] as String?) ?? '',
      tags: List<String>.from((json['tags'] as Iterable?) ?? []),
      variants: (json['variants'] as List<dynamic>?)
          ?.map((v) => CompetitorVariant.fromJson(v as Map<String, dynamic>))
          .toList() ?? [],
      images: (json['images'] as List<dynamic>?)
          ?.map((i) => CompetitorImage.fromJson(i as Map<String, dynamic>))
          .toList() ?? [],
      options: (json['options'] as List<dynamic>?)
          ?.map((o) => CompetitorOption.fromJson(o as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
  final int id;
  final String title;
  final String handle;
  final String bodyHtml;
  final String publishedAt;
  final String createdAt;
  final String updatedAt;
  final String vendor;
  final String productType;
  final List<String> tags;
  final List<CompetitorVariant> variants;
  final List<CompetitorImage> images;
  final List<CompetitorOption> options;

  String get price {
    if (variants.isNotEmpty) {
      return variants.first.price;
    }
    return '0.00';
  }

  String get imageUrl {
    if (images.isNotEmpty) {
      return images.first.src;
    }
    return '';
  }

  String get formattedPrice {
    try {
      final double priceValue = double.parse(price);
      return '${priceValue.toStringAsFixed(0)} جنيه';
    } catch (e) {
      return '$price جنيه';
    }
  }
}

class CompetitorVariant {

  CompetitorVariant({
    required this.id,
    required this.title,
    this.option1,
    this.option2,
    this.option3,
    this.sku,
    required this.requiresShipping,
    required this.taxable,
    required this.available,
    required this.price,
    required this.grams,
    required this.compareAtPrice,
    required this.position,
    required this.productId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CompetitorVariant.fromJson(Map<String, dynamic> json) {
    return CompetitorVariant(
      id: (json['id'] as int?) ?? 0,
      title: (json['title'] as String?) ?? '',
      option1: json['option1'] as String?,
      option2: json['option2'] as String?,
      option3: json['option3'] as String?,
      sku: json['sku'] as String?,
      requiresShipping: (json['requires_shipping'] as bool?) ?? false,
      taxable: (json['taxable'] as bool?) ?? false,
      available: (json['available'] as bool?) ?? false,
      price: json['price']?.toString() ?? '0.00',
      grams: (json['grams'] as int?) ?? 0,
      compareAtPrice: json['compare_at_price']?.toString() ?? '0.00',
      position: (json['position'] as int?) ?? 0,
      productId: (json['product_id'] as int?) ?? 0,
      createdAt: (json['created_at'] as String?) ?? '',
      updatedAt: (json['updated_at'] as String?) ?? '',
    );
  }
  final int id;
  final String title;
  final String? option1;
  final String? option2;
  final String? option3;
  final String? sku;
  final bool requiresShipping;
  final bool taxable;
  final bool available;
  final String price;
  final int grams;
  final String compareAtPrice;
  final int position;
  final int productId;
  final String createdAt;
  final String updatedAt;
}

class CompetitorImage {

  CompetitorImage({
    required this.id,
    required this.createdAt,
    required this.position,
    required this.updatedAt,
    required this.productId,
    required this.variantIds,
    required this.src,
    required this.width,
    required this.height,
  });

  factory CompetitorImage.fromJson(Map<String, dynamic> json) {
    return CompetitorImage(
      id: (json['id'] as int?) ?? 0,
      createdAt: (json['created_at'] as String?) ?? '',
      position: (json['position'] as int?) ?? 0,
      updatedAt: (json['updated_at'] as String?) ?? '',
      productId: (json['product_id'] as int?) ?? 0,
      variantIds: List<int>.from((json['variant_ids'] as Iterable?) ?? []),
      src: (json['src'] as String?) ?? '',
      width: (json['width'] as int?) ?? 0,
      height: (json['height'] as int?) ?? 0,
    );
  }
  final int id;
  final String createdAt;
  final int position;
  final String updatedAt;
  final int productId;
  final List<int> variantIds;
  final String src;
  final int width;
  final int height;
}

class CompetitorOption {

  CompetitorOption({
    required this.name,
    required this.position,
    required this.values,
  });

  factory CompetitorOption.fromJson(Map<String, dynamic> json) {
    return CompetitorOption(
      name: (json['name'] as String?) ?? '',
      position: (json['position'] as int?) ?? 0,
      values: List<String>.from((json['values'] as Iterable?) ?? []),
    );
  }
  final String name;
  final int position;
  final List<String> values;
}
