import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/product_model.dart';

class WishlistService {
  WishlistService._();

  static const String _wishlistKey = 'app_wishlist_items_v1';
  static final WishlistService instance = WishlistService._();

  Future<List<Product>> loadWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_wishlistKey) ?? const <String>[];
    final products = <Product>[];
    for (final raw in rawItems) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          products.add(Product.fromJson(decoded));
        } else if (decoded is Map) {
          products.add(Product.fromJson(Map<String, dynamic>.from(decoded)));
        }
      } catch (_) {
        // Ignore malformed entries and keep the rest.
      }
    }
    return products;
  }

  Future<void> saveWishlist(List<Product> products) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = products
        .map((product) => jsonEncode(product.toJson()))
        .toList(growable: false);
    await prefs.setStringList(_wishlistKey, encoded);
  }
}
