class Product {
  final int id;
  final String name;
  final String price;
  final String regularPrice;
  final String salePrice;
  final String image;
  final List<String> galleryImages;
  final String description;
  final String shortDescription;
  final String type;
  final String sku;
  final String slug;
  final String permalink;
  final String stockStatus;
  final bool isInStock;
  final bool priceDropped;
  final double? previousPrice;
  final double averageRating;
  final int ratingCount;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.regularPrice,
    required this.salePrice,
    required this.image,
    required this.galleryImages,
    required this.description,
    required this.shortDescription,
    required this.type,
    required this.sku,
    required this.slug,
    required this.permalink,
    required this.stockStatus,
    required this.isInStock,
    this.priceDropped = false,
    this.previousPrice,
    this.averageRating = 0,
    this.ratingCount = 0,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final imagesList = <String>[];
    if (json['images'] is List) {
      for (final img in json['images']) {
        if (img is Map && img['src'] != null) {
          imagesList.add(img['src'].toString());
        } else if (img is String && img.trim().isNotEmpty) {
          imagesList.add(img.trim());
        }
      }
    }

    final stockStatus = json['stock_status']?.toString().toLowerCase() ?? "";
    final inStockRaw = json['in_stock'];
    final parsedInStock = _parseBoolValue(inStockRaw);
    final isInStock = parsedInStock ??
        (stockStatus.isEmpty
            ? true
            : stockStatus == "instock" || stockStatus == "onbackorder");

    final effectivePrice = json['price']?.toString().trim().isNotEmpty == true
        ? json['price']?.toString() ?? "0"
        : json['sale_price']?.toString() ??
              json['regular_price']?.toString() ??
              "0";

    return Product(
      id: _parseIntValue(json['id']),
      name: json['name']?.toString() ?? "",
      price: effectivePrice,
      regularPrice: json['regular_price']?.toString() ?? "",
      salePrice: json['sale_price']?.toString() ?? "",
      image: imagesList.isNotEmpty ? imagesList.first : "",
      galleryImages: imagesList,
      description: json['description']?.toString() ?? "",
      shortDescription: json['short_description']?.toString() ?? "",
      type: json['type']?.toString() ?? "simple",
      sku: json['sku']?.toString() ?? "",
      slug: json['slug']?.toString() ?? "",
      permalink: json['permalink']?.toString() ?? "",
      stockStatus: stockStatus,
      isInStock: isInStock,
      priceDropped: json['price_drop'] == true ||
          json['_yana_price_drop'] == true ||
          json['priceDropped'] == true,
      previousPrice: _parseMoneyValue(
        json['previous_price'] ?? json['_yana_previous_price'],
      ),
      averageRating: _parseMoneyValue(json['average_rating']) ?? 0,
      ratingCount: _parseIntValue(json['rating_count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'regular_price': regularPrice,
      'sale_price': salePrice,
      'description': description,
      'short_description': shortDescription,
      'type': type,
      'sku': sku,
      'slug': slug,
      'permalink': permalink,
      'stock_status': stockStatus,
      'in_stock': isInStock,
      'price_drop': priceDropped,
      if (previousPrice != null) 'previous_price': previousPrice,
      'average_rating': averageRating.toStringAsFixed(1),
      'rating_count': ratingCount,
      'images': [
        for (final imageUrl in galleryImages) {'src': imageUrl},
      ],
    };
  }

  double? _parseMoney(String value) {
    return _parseMoneyValue(value);
  }

  static double? _parseMoneyValue(dynamic value) {
    final normalized = (value ?? "").toString().replaceAll(",", "").trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  static int _parseIntValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse((value ?? "").toString().trim()) ?? 0;
  }

  static bool? _parseBoolValue(dynamic value) {
    if (value is bool) return value;
    final normalized = (value ?? "").toString().trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (normalized == "true" || normalized == "1" || normalized == "yes") {
      return true;
    }
    if (normalized == "false" || normalized == "0" || normalized == "no") {
      return false;
    }
    return null;
  }

  double? get priceValue => _parseMoney(price);
  double? get regularPriceValue => _parseMoney(regularPrice);
  double? get salePriceValue => _parseMoney(salePrice);

  bool get hasDiscount {
    final mrp = regularPriceValue;
    final current = priceValue;
    return mrp != null && current != null && mrp > current && current > 0;
  }

  int get discountPercent {
    final mrp = regularPriceValue;
    final current = priceValue;
    if (mrp == null || current == null || mrp <= current || mrp <= 0) return 0;
    return (((mrp - current) / mrp) * 100).round();
  }
}
