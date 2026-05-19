import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../config.dart';

class AccountService {
  final String baseUrl = "https://yanaworldwide.store";

  // 🔥 Yaha apni WooCommerce REST keys daalni hain
  final String consumerKey = "ck_5fc6596a487b93c1e0794aecd0fd3cd0fb2414c0";
  final String consumerSecret = "cs_e6c14fe4412ccae3ce507857d87feeb74a649633";

  Future<List> fetchOrders() async {
    try {
      final userId = await AuthService().getUserId();
      final customerId = int.tryParse(userId ?? "");
      if (customerId == null) {
        print("User not logged in");
        return [];
      }

      print("Customer ID: $customerId");

      final response = await http.get(
        Uri.parse(
          "$baseUrl/wp-json/wc/v3/orders?customer=$customerId&consumer_key=$consumerKey&consumer_secret=$consumerSecret",
        ),
        headers: {
          Config.appHeaderKey: Config.appHeaderValue,
        },
      );

      print("ORDER RESPONSE: ${response.body}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Order API Error: ${response.body}");
        return [];
      }
    } catch (e) {
      print("Order Fetch Exception: $e");
      return [];
    }
  }
}


