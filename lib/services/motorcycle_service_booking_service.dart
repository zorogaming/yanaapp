import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'auth_service.dart';

class MotorcycleServiceBookingService {
  static const String _bookingHistoryKey = "motorcycle_service_bookings_v1";
  static const String _packageChargesKey = "motorcycle_service_package_charges_v1";
  static const String _serviceConfigKey = "motorcycle_service_config_v1";

  Future<List<Map<String, dynamic>>> getBookings({bool adminView = false}) async {
    final remote = await _fetchRemoteBookings(adminView: adminView);
    if (remote != null) {
      if (!adminView) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_bookingHistoryKey, jsonEncode(remote));
      }
      return remote;
    }
    return _getLocalBookings();
  }

  Future<void> saveBooking(Map<String, dynamic> booking) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await _getLocalBookings();
    existing.insert(0, booking);
    await prefs.setString(
      _bookingHistoryKey,
      jsonEncode(existing.take(100).toList()),
    );
    await _postRemoteBooking(booking);
  }

  Future<void> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    await updateBookingAdminDetails(
      bookingId: bookingId,
      status: status,
    );
  }

  Future<void> updateBookingAdminDetails({
    required String bookingId,
    String? status,
    String? completedServiceDate,
    String? serviceDoneKm,
    String? nextServiceDueKm,
  }) async {
    final trimmedBookingId = bookingId.trim();
    if (trimmedBookingId.isEmpty) return;

    final updates = <String, dynamic>{};
    if (status != null && status.trim().isNotEmpty) {
      updates["status"] = status.trim();
    }
    if (completedServiceDate != null) {
      updates["completed_service_date"] = completedServiceDate.trim();
    }
    if (serviceDoneKm != null) {
      updates["service_done_km"] = serviceDoneKm.trim();
    }
    if (nextServiceDueKm != null) {
      updates["next_service_due_km"] = nextServiceDueKm.trim();
    }
    if (updates.isEmpty) return;

    await _postRemoteBookingUpdate(
      bookingId: trimmedBookingId,
      updates: updates,
    );

    final prefs = await SharedPreferences.getInstance();
    final existing = await _getLocalBookings();
    for (final booking in existing) {
      if ((booking["booking_id"] ?? "").toString() == trimmedBookingId) {
        booking.addAll(updates);
        booking["updated_at"] = DateTime.now().toIso8601String();
      }
    }
    await prefs.setString(_bookingHistoryKey, jsonEncode(existing));
  }

  Future<Map<String, double>> getPackageCharges() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString(_packageChargesKey) ?? "").trim();
    final defaults = <String, double>{
      "essential": 699,
      "performance": 1199,
      "ultimate": 1899,
    };
    if (raw.isEmpty) return defaults;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final out = <String, double>{};
        for (final entry in decoded.entries) {
          out[entry.key.toString()] =
              double.tryParse(entry.value.toString()) ?? defaults[entry.key] ?? 0;
        }
        return {...defaults, ...out};
      }
    } catch (_) {}
    return defaults;
  }

  Future<void> savePackageCharges(Map<String, double> charges) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_packageChargesKey, jsonEncode(charges));
  }

  Future<Map<String, dynamic>> getServiceConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString(_serviceConfigKey) ?? "").trim();
    final defaults = <String, dynamic>{
      "pickup_drop_enabled": false,
      "pickup_drop_city": "Jaipur",
    };
    if (raw.isEmpty) return defaults;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return {...defaults, ...decoded.cast<String, dynamic>()};
      }
    } catch (_) {}
    return defaults;
  }

  Future<void> saveServiceConfig(Map<String, dynamic> config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serviceConfigKey, jsonEncode(config));
  }

  Future<List<Map<String, dynamic>>> _getLocalBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString(_bookingHistoryKey) ?? "").trim();
    if (raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  Future<void> _postRemoteBooking(Map<String, dynamic> booking) async {
    final endpoint = Config.motorcycleServiceBookingCreateUrl.trim();
    if (endpoint.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final installId = (prefs.getString("anonymous_install_id") ?? "").trim();
      final userId = (await AuthService().getUserId() ?? "").trim();
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: await _buildHeaders(includeServiceToken: true),
            body: jsonEncode({
              ...booking,
              "install_id": installId,
              "user_id": userId,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode >= 400) {
        return;
      }
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>?> _fetchRemoteBookings({
    required bool adminView,
  }) async {
    final endpoint = Config.motorcycleServiceBookingListUrl.trim();
    if (endpoint.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final installId = (prefs.getString("anonymous_install_id") ?? "").trim();
      final userId = (await AuthService().getUserId() ?? "").trim();
      final query = <String, String>{
        if (!adminView && installId.isNotEmpty) "install_id": installId,
        if (!adminView && userId.isNotEmpty) "user_id": userId,
        if (adminView) "admin": "1",
      };
      final uri = Uri.parse(endpoint).replace(queryParameters: query);
      final response = await http
          .get(
            uri,
            headers: await _buildHeaders(includeServiceToken: adminView),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final items = map["bookings"];
      if (items is! List) return null;
      return items
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _postRemoteBookingUpdate({
    required String bookingId,
    required Map<String, dynamic> updates,
  }) async {
    final endpoint = Config.motorcycleServiceBookingUpdateUrl.trim();
    if (endpoint.isEmpty || bookingId.trim().isEmpty || updates.isEmpty) return;
    try {
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: await _buildHeaders(includeServiceToken: true),
            body: jsonEncode({
              "booking_id": bookingId.trim(),
              ...updates,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode >= 400) {
        return;
      }
    } catch (_) {}
  }

  Future<Map<String, String>> _buildHeaders({
    required bool includeServiceToken,
  }) async {
    final token = await AuthService().getToken();
    return <String, String>{
      "Content-Type": "application/json",
      Config.appHeaderKey: Config.appHeaderValue,
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
      if (includeServiceToken && Config.motorcycleServiceApiToken.trim().isNotEmpty)
        "X-Service-Token": Config.motorcycleServiceApiToken.trim(),
    };
  }
}
