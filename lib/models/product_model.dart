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
  final String stockStatus;
  final bool isInStock;

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
    required this.stockStatus,
    required this.isInStock,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final imagesList = <String>[];
    if (json['images'] is List) {
      for (final img in json['images']) {
        if (img is Map && img['src'] != null) {
          imagesList.add(img['src'].toString());
        }
      }
    }

    final stockStatus = json['stock_status']?.toString().toLowerCase() ?? "";
    final inStockRaw = json['in_stock'];
    final isInStock = inStockRaw is bool
        ? inStockRaw
        : stockStatus.isEmpty
            ? true
            : stockStatus == "instock" || stockStatus == "onbackorder";

    final effectivePrice =
        json['price']?.toString().trim().isNotEmpty == true
            ? json['price']?.toString() ?? "0"
            : json['sale_price']?.toString() ??
                json['regular_price']?.toString() ??
                "0";

    return Product(
      id: json['id'] ?? 0,
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
      stockStatus: stockStatus,
      isInStock: isInStock,
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
      'stock_status': stockStatus,
      'in_stock': isInStock,
      'images': [
        for (final imageUrl in galleryImages)
          {'src': imageUrl},
      ],
    };
  }

  double? _parseMoney(String value) {
    final normalized = value.replaceAll(",", "").trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
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
