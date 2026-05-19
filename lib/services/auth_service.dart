import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'analytics_service.dart';

class AuthService {
  final String baseUrl = "https://yanaworldwide.store";
  static const String _fcmTopicKey = "fcm_user_topic";
  static const String _fcmAdminTopicKey = "fcm_admin_topic";
  static const String _adminOrdersTopic = "admin_orders";
  static const String _lastLoginIdentifierKey = "last_login_identifier";
  static const String privilegedAdminEmail = "rahat@gmail.com";

  Future<Map<String, dynamic>?> login(String username, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/wp-json/jwt-auth/v1/token"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": username,
        "password": password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();

      final token = data["token"]?.toString();
      final resolvedUserId = _resolveUserId(data, token);

      if (token != null && token.isNotEmpty) {
        await prefs.setString("jwt_token", token);
      }
      await prefs.setString(
        _lastLoginIdentifierKey,
        username.trim().toLowerCase(),
      );
      if (resolvedUserId != null && resolvedUserId.isNotEmpty) {
        await prefs.setString("user_id", resolvedUserId);
      }
      await _syncNotificationTopics(resolvedUserId);
      await AnalyticsService.instance.initIdentity(userId: resolvedUserId);

      return data;
    }

    return null;
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("jwt_token");
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUserId = prefs.getString("user_id");
    if (savedUserId != null && savedUserId.isNotEmpty) return savedUserId;

    final token = prefs.getString("jwt_token");
    final fallbackUserId = _extractUserIdFromToken(token);
    if (fallbackUserId != null && fallbackUserId.isNotEmpty) {
      await prefs.setString("user_id", fallbackUserId);
    }
    return fallbackUserId;
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  Future<String?> getUserEmail() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return null;

    try {
      final decoded = JwtDecoder.decode(token);
      final dynamic rawEmail =
          decoded["user_email"] ??
          decoded["email"] ??
          (decoded["data"] is Map && (decoded["data"] as Map)["user"] is Map
              ? ((decoded["data"] as Map)["user"] as Map)["email"]
              : null);
      if (rawEmail == null) {
        return _fetchUserEmailFromProfileApi(token);
      }
      final value = rawEmail.toString().trim();
      if (value.isEmpty) {
        return _fetchUserEmailFromProfileApi(token);
      }
      return value;
    } catch (_) {
      return _fetchUserEmailFromProfileApi(token);
    }
  }

  Future<bool> isPrivilegedAdmin() async {
    final token = await getToken();
    if (token != null && token.isNotEmpty && _tokenHasAdminRole(token)) {
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastIdentifier =
        (prefs.getString(_lastLoginIdentifierKey) ?? "").trim().toLowerCase();
    if (lastIdentifier == privilegedAdminEmail) return true;

    final email = await getUserEmail();
    if (email == null || email.trim().isEmpty) return false;
    return email.trim().toLowerCase() == privilegedAdminEmail;
  }

  bool _tokenHasAdminRole(String token) {
    try {
      final decoded = JwtDecoder.decode(token);
      final roles = <String>{};
      void absorb(dynamic value) {
        if (value == null) return;
        if (value is String) {
          final v = value.trim().toLowerCase();
          if (v.isNotEmpty) roles.add(v);
          return;
        }
        if (value is Iterable) {
          for (final item in value) {
            absorb(item);
          }
          return;
        }
        if (value is Map) {
          for (final entry in value.entries) {
            final key = entry.key.toString().trim().toLowerCase();
            if (key.isNotEmpty) roles.add(key);
            absorb(entry.value);
          }
        }
      }

      absorb(decoded["role"]);
      absorb(decoded["roles"]);
      if (decoded["data"] is Map) {
        final data = decoded["data"] as Map;
        absorb(data["role"]);
        absorb(data["roles"]);
        if (data["user"] is Map) {
          final user = data["user"] as Map;
          absorb(user["role"]);
          absorb(user["roles"]);
          absorb(user["capabilities"]);
        }
      }

      return roles.contains("administrator") ||
          roles.contains("shop_manager") ||
          roles.contains("manage_options");
    } catch (_) {
      return false;
    }
  }

  Future<String?> _fetchUserEmailFromProfileApi(String token) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/wp-json/wp/v2/users/me"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;
      final email = (body["email"] ?? "").toString().trim();
      return email.isEmpty ? null : email;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    await _unsubscribeCurrentTopics();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await AnalyticsService.instance.initIdentity(userId: null);
  }

  Future<bool> changePassword({
    required String newPassword,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/wp-json/wp/v2/users/me"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "password": newPassword,
        }),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<String?> requestPasswordReset(String userLogin) async {
    final identifier = userLogin.trim();
    if (identifier.isEmpty) {
      return "Please enter your email or username.";
    }

    try {
      final response = await http.post(
        Uri.parse(Config.forgotPasswordApiUrl),
        headers: {
          "Content-Type": "application/json",
          "X-Reset-Token": Config.forgotPasswordToken,
          Config.appHeaderKey: Config.appHeaderValue,
        },
        body: jsonEncode({
          "login": identifier,
        }),
      );

      final bodyText = response.body.toLowerCase();
      Map<String, dynamic>? payload;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        }
      } catch (_) {
        payload = null;
      }

      final message = (payload?["message"] ?? "").toString().trim();
      final messageLower = message.toLowerCase();
      final success =
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (messageLower.contains("password reset link sent") ||
              messageLower.contains("password reset email") ||
              messageLower.contains("reset link sent"));

      if (success) {
        return null;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        return "Password reset service is not authorized right now.";
      }

      if (response.statusCode == 404 ||
          messageLower.contains("account not found") ||
          bodyText.contains("account not found")) {
        return "No account was found with that email or username.";
      }

      if (response.statusCode >= 500) {
        return "Server is not responding for password reset right now. Please try again in a moment.";
      }

      if (messageLower.contains("invalid email") ||
          messageLower.contains("invalid username") ||
          messageLower.contains("not registered") ||
          messageLower.contains("unknown username") ||
          messageLower.contains("no account found") ||
          bodyText.contains("invalid email") ||
          bodyText.contains("invalid username")) {
        return "No account was found with that email or username.";
      }

      if (message.isNotEmpty) {
        return message;
      }

      return "We couldn't send the password reset email right now. Please check your email or username and try again.";
    } catch (_) {
      return "Unable to connect to the server. Please try again.";
    }
  }

  Future<void> syncFcmTopicForCurrentUser() async {
    final userId = await getUserId();
    await _syncNotificationTopics(userId);
  }

  Future<void> _syncNotificationTopics(String? userId) async {
    if (userId != null && userId.isNotEmpty) {
      await _subscribeUserTopic(userId);
    } else {
      await _unsubscribeUserTopic();
    }

    final shouldReceiveAdminOrders = await isPrivilegedAdmin();
    if (shouldReceiveAdminOrders) {
      await _subscribeAdminTopic();
    } else {
      await _unsubscribeAdminTopic();
    }
  }

  Future<void> _subscribeUserTopic(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final oldTopic = prefs.getString(_fcmTopicKey);
    final newTopic = "user_$userId";

    try {
      if (oldTopic != null &&
          oldTopic.isNotEmpty &&
          oldTopic != newTopic) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(oldTopic);
      }
      await FirebaseMessaging.instance.subscribeToTopic(newTopic);
      await prefs.setString(_fcmTopicKey, newTopic);
    } catch (_) {
      // FCM topic sync should not block auth flow.
    }
  }

  Future<void> _unsubscribeUserTopic() async {
    final prefs = await SharedPreferences.getInstance();
    final oldTopic = prefs.getString(_fcmTopicKey);
    if (oldTopic == null || oldTopic.isEmpty) return;
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(oldTopic);
    } catch (_) {
      // Ignore unsubscribe failures.
    }
    await prefs.remove(_fcmTopicKey);
  }

  Future<void> _subscribeAdminTopic() async {
    final prefs = await SharedPreferences.getInstance();
    final oldTopic = prefs.getString(_fcmAdminTopicKey);
    if (oldTopic == _adminOrdersTopic) {
      return;
    }

    try {
      if (oldTopic != null && oldTopic.isNotEmpty && oldTopic != _adminOrdersTopic) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(oldTopic);
      }
      await FirebaseMessaging.instance.subscribeToTopic(_adminOrdersTopic);
      await prefs.setString(_fcmAdminTopicKey, _adminOrdersTopic);
    } catch (_) {
      // Admin topic sync should not block auth flow.
    }
  }

  Future<void> _unsubscribeAdminTopic() async {
    final prefs = await SharedPreferences.getInstance();
    final oldTopic = prefs.getString(_fcmAdminTopicKey);
    if (oldTopic == null || oldTopic.isEmpty) return;
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(oldTopic);
    } catch (_) {
      // Ignore unsubscribe failures.
    }
    await prefs.remove(_fcmAdminTopicKey);
  }

  Future<void> _unsubscribeCurrentTopics() async {
    await _unsubscribeUserTopic();
    await _unsubscribeAdminTopic();
  }

  String? _resolveUserId(Map<String, dynamic> data, String? token) {
    final raw =
        data["user_id"] ??
        data["id"] ??
        data["userId"] ??
        (data["data"] is Map ? (data["data"] as Map)["user_id"] : null) ??
        (data["data"] is Map && (data["data"] as Map)["user"] is Map
            ? ((data["data"] as Map)["user"] as Map)["id"]
            : null);
    if (raw != null) {
      final value = raw.toString();
      if (value.isNotEmpty && value != "null") return value;
    }
    return _extractUserIdFromToken(token);
  }

  String? _extractUserIdFromToken(String? token) {
    if (token == null || token.isEmpty) return null;

    try {
      final decoded = JwtDecoder.decode(token);
      final dynamic id =
          decoded["user_id"] ??
          decoded["id"] ??
          (decoded["data"] is Map ? (decoded["data"] as Map)["user_id"] : null) ??
          (decoded["data"] is Map && (decoded["data"] as Map)["user"] is Map
              ? ((decoded["data"] as Map)["user"] as Map)["id"]
              : null) ??
          decoded["sub"];
      if (id == null) return null;
      final value = id.toString();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }
}
