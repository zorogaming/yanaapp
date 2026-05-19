import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../services/analytics_service.dart';
import '../services/wishlist_service.dart';

class WishlistProvider extends ChangeNotifier {
  WishlistProvider() {
    _load();
  }

  final List<Product> _wishlist = [];
  bool _isLoaded = false;

  List<Product> get items => List<Product>.unmodifiable(_wishlist);
  bool get isLoaded => _isLoaded;
  bool containsProduct(int productId) => _wishlist.any((p) => p.id == productId);

  Future<void> _load() async {
    final products = await WishlistService.instance.loadWishlist();
    _wishlist
      ..clear()
      ..addAll(products);
    _isLoaded = true;
    notifyListeners();
  }

  Future<bool> toggle(
    Product product, {
    String source = 'app',
  }) async {
    final alreadyInWishlist = containsProduct(product.id);
    if (alreadyInWishlist) {
      _wishlist.removeWhere((p) => p.id == product.id);
    } else {
      _wishlist.add(product);
    }
    await WishlistService.instance.saveWishlist(_wishlist);
    notifyListeners();
    final added = !alreadyInWishlist;
    await AnalyticsService.instance.logWishlistAction(
      productId: product.id,
      productName: product.name,
      price: product.priceValue ?? 0,
      stockStatus: product.stockStatus,
      inStock: product.isInStock,
      added: added,
      source: source,
    );
    return added;
  }
}
