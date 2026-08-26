import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/product_model.dart';

class RecentlyViewedService {
  RecentlyViewedService._();

  static final RecentlyViewedService instance = RecentlyViewedService._();
  static const String _key = "recently_viewed_products_v1";
  static const int _limit = 12;

  Future<List<Product>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const <Product>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <Product>[];
      return decoded
          .whereType<Map>()
          .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
          .where((product) => product.id > 0 && product.name.trim().isNotEmpty)
          .toList();
    } catch (_) {
      await prefs.remove(_key);
      return const <Product>[];
    }
  }

  Future<void> add(Product product) async {
    if (product.id <= 0 || product.name.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = await load();
    final next = <Product>[
      product,
      ...current.where((item) => item.id != product.id),
    ].take(_limit).toList();
    await prefs.setString(
      _key,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
  }
}

