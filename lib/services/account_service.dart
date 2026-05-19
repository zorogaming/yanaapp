import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'auth_service.dart';

class AccountService {
  Map<String, String> _wcHeaders({bool json = false}) {
    return {
      Config.appHeaderKey: Config.appHeaderValue,
      if (json) "Content-Type": "application/json",
    };
  }

  Uri _buildUri(String endpoint, Map<String, String> params) {
    final defaultParams = {
      "consumer_key": Config.consumerKey,
      "consumer_secret": Config.consumerSecret,
    };

    return Uri.parse(
      "${Config.baseUrl}$endpoint",
    ).replace(queryParameters: {...defaultParams, ...params});
  }

  Future<List> fetchOrders() async {
    final userId = await AuthService().getUserId();
    final userEmail = (await AuthService().getUserEmail() ?? "")
        .trim()
        .toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final installId = (prefs.getString("anonymous_install_id") ?? "").trim();
    final ordersById = <int, Map<String, dynamic>>{};

    if (userId != null && userId.isNotEmpty) {
      try {
        final response = await http.get(
          _buildUri("orders", {
            "customer": userId,
            "per_page": "50",
            "orderby": "date",
            "order": "desc",
          }),
          headers: _wcHeaders(),
        );

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is List) {
            for (final raw in decoded) {
              if (raw is! Map) continue;
              final order = Map<String, dynamic>.from(raw);
              final orderId = int.tryParse((order["id"] ?? "").toString());
              if (orderId != null && orderId > 0) {
                ordersById[orderId] = order;
              }
            }
          }
        }
      } catch (_) {
        // Fallback matching below still gives guest-compatible order history.
      }
    }

    if (userEmail.isEmpty && installId.isEmpty) {
      return ordersById.values.toList();
    }

    for (var page = 1; page <= 3; page++) {
      try {
        final response = await http.get(
          _buildUri("orders", {
            "per_page": "100",
            "page": page.toString(),
            "orderby": "date",
            "order": "desc",
          }),
          headers: _wcHeaders(),
        );
        if (response.statusCode != 200) break;

        final decoded = jsonDecode(response.body);
        if (decoded is! List || decoded.isEmpty) break;

        for (final raw in decoded) {
          if (raw is! Map) continue;
          final order = Map<String, dynamic>.from(raw);
          if (!_matchesOrder(order, userId: userId, userEmail: userEmail, installId: installId)) {
            continue;
          }
          final orderId = int.tryParse((order["id"] ?? "").toString());
          if (orderId != null && orderId > 0) {
            ordersById[orderId] = order;
          }
        }
      } catch (_) {
        break;
      }
    }

    final orders = ordersById.values.toList();
    orders.sort((a, b) {
      final aDate = DateTime.tryParse((a["date_created"] ?? "").toString());
      final bDate = DateTime.tryParse((b["date_created"] ?? "").toString());
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return orders;
  }

  bool _matchesOrder(
    Map<String, dynamic> order, {
    required String? userId,
    required String userEmail,
    required String installId,
  }) {
    final orderCustomerId = (order["customer_id"] ?? "").toString().trim();
    if (userId != null && userId.isNotEmpty && orderCustomerId == userId) {
      return true;
    }

    final billing = order["billing"];
    if (billing is Map) {
      final billingEmail = (billing["email"] ?? "").toString().trim().toLowerCase();
      if (userEmail.isNotEmpty && billingEmail == userEmail) {
        return true;
      }
    }

    if (installId.isEmpty) return false;

    final metaData = order["meta_data"];
    if (metaData is! List) return false;
    for (final raw in metaData) {
      if (raw is! Map) continue;
      final key = (raw["key"] ?? "").toString().trim();
      final value = (raw["value"] ?? "").toString().trim();
      if (key == "app_install_id" && value == installId) {
        return true;
      }
    }
    return false;
  }

  Future<Map<String, dynamic>> fetchCustomer() async {
    final userId = await AuthService().getUserId();
    if (userId == null || userId.isEmpty) return {};

    final response = await http.get(
      _buildUri("customers/$userId", {}),
      headers: _wcHeaders(),
    );

    if (response.statusCode != 200) return {};
    return jsonDecode(response.body);
  }

  Future<void> updateAddress(Map<String, dynamic> data) async {
    final userId = await AuthService().getUserId();
    if (userId == null || userId.isEmpty) return;

    await http.put(
      _buildUri("customers/$userId", {}),
      headers: _wcHeaders(json: true),
      body: jsonEncode(data),
    );
  }
}
