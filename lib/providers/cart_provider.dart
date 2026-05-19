import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';
import '../services/analytics_service.dart';

class CartProvider extends ChangeNotifier {
  List<CartItem> _items = [];

  List<CartItem> get items => _items;

  int get itemCount => _items.length;

  double get total =>
      _items.fold(0, (sum, item) => sum + item.price * item.quantity);

  CartProvider() {
    loadCart();
  }

  void addToCart(CartItem item) {
    int index = _items.indexWhere(
        (e) => e.id == item.id && e.variationId == item.variationId);

    if (index >= 0) {
      _items[index].quantity += item.quantity;
    } else {
      _items.add(item);
    }

    saveCart();
    AnalyticsService.instance.logAddToCart(
      productId: item.id,
      productName: item.name,
      quantity: item.quantity,
      price: item.price,
    );
    notifyListeners();
  }

  void removeItem(int id, {int? variationId}) {
    final removed = _items.where((e) => e.id == id && e.variationId == variationId);
    _items.removeWhere((e) => e.id == id && e.variationId == variationId);
    for (final item in removed) {
      AnalyticsService.instance.logPaymentStatus(
        orderId: null,
        status: "removed_from_cart",
        paymentMethod: "cart_action",
        amount: item.price * item.quantity,
      );
    }

    saveCart();
    notifyListeners();
  }

  void increaseQty(int id, {int? variationId}) {
    int index =
        _items.indexWhere((e) => e.id == id && e.variationId == variationId);

    if (index >= 0) {
      _items[index].quantity++;
      saveCart();
      notifyListeners();
    }
  }

  void decreaseQty(int id, {int? variationId}) {
    int index =
        _items.indexWhere((e) => e.id == id && e.variationId == variationId);

    if (index >= 0 && _items[index].quantity > 1) {
      _items[index].quantity--;
      saveCart();
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    saveCart();
    notifyListeners();
  }

  Future<void> saveCart() async {
    final prefs = await SharedPreferences.getInstance();

    prefs.setString(
      "cart",
      jsonEncode(_items.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> loadCart() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString("cart");

    if (data != null) {
      List decoded = jsonDecode(data);

      _items = decoded.map((e) => CartItem.fromJson(e)).toList();

      notifyListeners();
    }
  }
}
