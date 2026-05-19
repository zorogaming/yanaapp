import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'auth_service.dart';

class AdminService {
  static final Uri _root = Uri.parse(Config.baseUrl);
  static String get _siteBase => "${_root.scheme}://${_root.host}";
  static String get _base => "$_siteBase/wp-json/yana-admin/v1";
  static String get _publicBase => "$_siteBase/wp-json/wp/v1";

  Future<String> _ensureInstallId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = (prefs.getString("anonymous_install_id") ?? "").trim();
    if (existing.isNotEmpty) {
      return existing;
    }

    final random = Random.secure();
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final suffix = List.generate(
      8,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    final installId =
        "guest_${DateTime.now().millisecondsSinceEpoch}_$suffix";
    await prefs.setString("anonymous_install_id", installId);
    return installId;
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthService().getToken();
    return {
      "Content-Type": "application/json",
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    };
  }

  Future<Map<String, dynamic>> getOverview() async {
    final res = await http.get(
      Uri.parse("$_base/overview"),
      headers: await _headers(),
    );
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> getLive({
    int minutes = 30,
    int limit = 80,
    bool includePayload = false,
  }) async {
    final res = await http.get(
      Uri.parse(
        "$_base/live?minutes=$minutes&limit=$limit&include_payload=$includePayload",
      ),
      headers: await _headers(),
    );
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> runBulkCart({int days = 3}) async {
    final res = await http.post(
      Uri.parse("$_base/bulk/cart"),
      headers: await _headers(),
      body: jsonEncode({"days": days}),
    );
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> runBulkRepeatViews() async {
    final res = await http.post(
      Uri.parse("$_base/bulk/repeat-views"),
      headers: await _headers(),
      body: "{}",
    );
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> getActors({int days = 7, int limit = 100}) async {
    final res = await http.get(
      Uri.parse("$_base/actors?days=$days&limit=$limit"),
      headers: await _headers(),
    );
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> getActorDetail({
    required String actorKey,
    int minutes = 1440,
    int limit = 40,
  }) async {
    final encoded = Uri.encodeQueryComponent(actorKey);
    final res = await http.get(
      Uri.parse("$_base/actor?actor_key=$encoded&minutes=$minutes&limit=$limit"),
      headers: await _headers(),
    );
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> sendCustomPush({
    required String actorKey,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final res = await http.post(
      Uri.parse("$_base/push/custom"),
      headers: await _headers(),
      body: jsonEncode({
        "actor_key": actorKey,
        "title": title,
        "body": body,
        "data": data ?? const <String, dynamic>{},
      }),
    );
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> sendCustomCampaign({
    required String title,
    required String body,
    required String targetMode,
    required String audienceFilter,
    required int lookbackDays,
    List<String> actorKeys = const [],
    int? productId,
    String deepLink = "",
    String imageUrl = "",
    String couponCode = "",
    String scheduleMode = "now",
    String scheduleAt = "",
  }) async {
    final res = await http.post(
      Uri.parse("$_base/push/campaign"),
      headers: await _headers(),
      body: jsonEncode({
        "title": title,
        "body": body,
        "target_mode": targetMode,
        "actor_keys": actorKeys,
        "audience_filter": audienceFilter,
        "lookback_days": lookbackDays,
        "product_id": productId ?? 0,
        "deep_link": deepLink,
        "image_url": imageUrl,
        "coupon_code": couponCode,
        "schedule_mode": scheduleMode,
        "schedule_at": scheduleAt,
      }),
    );
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> getUserInterest({int days = 7, int limit = 100}) async {
    final res = await http.get(
      Uri.parse("$_base/insights/user-interest?days=$days&limit=$limit"),
      headers: await _headers(),
    );
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> getTopProducts({int days = 30, int limit = 100}) async {
    final res = await http.get(
      Uri.parse("$_base/insights/top-products?days=$days&limit=$limit"),
      headers: await _headers(),
    );
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> getAppUpdateConfig() async {
    final res = await http.get(
      Uri.parse("$_base/app-update"),
      headers: await _headers(),
    );
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> triggerAppUpdate({
    required String title,
    required String message,
    required String url,
    String minVersion = "",
    String latestVersion = "",
    bool forceUpdate = false,
  }) async {
    final res = await http.post(
      Uri.parse("$_base/app-update"),
      headers: await _headers(),
      body: jsonEncode({
        "action": "activate",
        "title": title,
        "message": message,
        "url": url,
        "min_version": minVersion,
        "latest_version": latestVersion,
        "force_update": forceUpdate,
      }),
    );
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> deactivateAppUpdate() async {
    final res = await http.post(
      Uri.parse("$_base/app-update"),
      headers: await _headers(),
      body: jsonEncode({"action": "deactivate"}),
    );
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> getPublicAppUpdateStatus() async {
    final res = await http.get(Uri.parse("$_publicBase/app-update-status"));
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> getGatewayConfig() async {
    final res = await http.get(
      Uri.parse("$_base/gateway/config"),
      headers: await _headers(),
    );
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> setGatewayConfig({
    required bool cashfreeEnabled,
    required bool payuEnabled,
  }) async {
    final res = await http.post(
      Uri.parse("$_base/gateway/config"),
      headers: await _headers(),
      body: jsonEncode({
        "cashfree_enabled": cashfreeEnabled,
        "payu_enabled": payuEnabled,
      }),
    );
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> getPublicGatewayStatus() async {
    final res = await http.get(Uri.parse("$_publicBase/gateway-status"));
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> getHomePopupConfig() async {
    final res = await http.get(
      Uri.parse("$_base/home-popup"),
      headers: await _headers(),
    );
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> triggerHomePopup({
    required String title,
    required String message,
    String buttonText = "Okay",
    String actionUrl = "",
  }) async {
    final res = await http.post(
      Uri.parse("$_base/home-popup"),
      headers: await _headers(),
      body: jsonEncode({
        "action": "activate",
        "title": title,
        "message": message,
        "button_text": buttonText,
        "action_url": actionUrl,
      }),
    );
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> deactivateHomePopup() async {
    final res = await http.post(
      Uri.parse("$_base/home-popup"),
      headers: await _headers(),
      body: jsonEncode({"action": "deactivate"}),
    );
    return _parseJson(res);
  }

  Future<void> acknowledgeHomePopup({
    required String campaignId,
    required String action,
  }) async {
    final normalizedCampaignId = campaignId.trim();
    if (normalizedCampaignId.isEmpty) return;

    final installId = await _ensureInstallId();
    final userId = (await AuthService().getUserId() ?? "").trim();

    try {
      await http.post(
        Uri.parse("$_publicBase/home-popup-ack"),
        headers: const {
          "Content-Type": "application/json",
          Config.appHeaderKey: Config.appHeaderValue,
          "Cache-Control": "no-cache, no-store, must-revalidate",
          "Pragma": "no-cache",
        },
        body: jsonEncode({
          "campaign_id": normalizedCampaignId,
          "action": action.trim().isEmpty ? "close" : action.trim(),
          "install_id": installId,
          "user_id": userId,
        }),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      // Fail-open: local suppression still applies even if ack fails.
    }
  }

  Future<Map<String, dynamic>> getPublicHomePopupStatus() async {
    final installId = await _ensureInstallId();
    final userId = (await AuthService().getUserId() ?? "").trim();
    final query = <String, String>{
      "t": DateTime.now().millisecondsSinceEpoch.toString(),
      if (installId.isNotEmpty) "install_id": installId,
      if (userId.isNotEmpty) "user_id": userId,
    };
    final uri = Uri.parse(
      "$_publicBase/home-popup-status",
    ).replace(queryParameters: query);
    final res = await http.get(
      uri,
      headers: const {
        "Cache-Control": "no-cache, no-store, must-revalidate",
        "Pragma": "no-cache",
      },
    );
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> getWalletConfig() async {
    final res = await http.get(
      Uri.parse("$_base/wallet/config"),
      headers: await _headers(),
    );
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> setWalletConfig({
    required bool enabled,
    required double signupBonus,
    required double minBilling,
  }) async {
    final res = await http.post(
      Uri.parse("$_base/wallet/config"),
      headers: await _headers(),
      body: jsonEncode({
        "enabled": enabled,
        "signup_bonus": signupBonus,
        "min_billing": minBilling,
      }),
    );
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> creditWallet({
    String? actorKey,
    int? userId,
    String? installId,
    required double amount,
  }) async {
    final payload = <String, dynamic>{
      "amount": amount,
    };
    if (actorKey != null && actorKey.trim().isNotEmpty) {
      payload["actor_key"] = actorKey.trim();
    }
    if (userId != null && userId > 0) {
      payload["user_id"] = userId;
    }
    if (installId != null && installId.trim().isNotEmpty) {
      payload["install_id"] = installId.trim();
    }
    final res = await http.post(
      Uri.parse("$_base/wallet/credit"),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> setWalletBan({
    String? actorKey,
    int? userId,
    String? installId,
    required bool banned,
  }) async {
    final payload = <String, dynamic>{
      "banned": banned,
    };
    if (actorKey != null && actorKey.trim().isNotEmpty) {
      payload["actor_key"] = actorKey.trim();
    }
    if (userId != null && userId > 0) {
      payload["user_id"] = userId;
    }
    if (installId != null && installId.trim().isNotEmpty) {
      payload["install_id"] = installId.trim();
    }
    final res = await http.post(
      Uri.parse("$_base/wallet/ban"),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> getWalletUserCredits({
    int limit = 100,
    String q = "",
  }) async {
    final safeLimit = limit < 20 ? 20 : (limit > 500 ? 500 : limit);
    final encodedQ = Uri.encodeQueryComponent(q.trim());
    final res = await http.get(
      Uri.parse("$_base/wallet/user-credits?limit=$safeLimit&q=$encodedQ"),
      headers: await _headers(),
    );
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> getGrowthConfig() async {
    final res = await http.get(
      Uri.parse("$_base/growth/config"),
      headers: await _headers(),
    );
    return _parseJson(res);
  }

  Future<Map<String, dynamic>> setGrowthConfig({
    required bool cashbackEnabled,
    required double cashbackSpendAmount,
    required double cashbackRewardAmount,
    required bool flashDealEnabled,
    required String flashDealTitle,
    required String flashDealSubtitle,
    required String flashDealEndsAt,
    required List<int> flashDealProductIds,
    required bool crossSellEnabled,
    required int crossSellMaxItems,
    required Map<String, List<int>> crossSellProductMap,
  }) async {
    final res = await http.post(
      Uri.parse("$_base/growth/config"),
      headers: await _headers(),
      body: jsonEncode({
        "cashback": {
          "enabled": cashbackEnabled,
          "spend_amount": cashbackSpendAmount,
          "cashback_amount": cashbackRewardAmount,
        },
        "flash_deal": {
          "enabled": flashDealEnabled,
          "title": flashDealTitle,
          "subtitle": flashDealSubtitle,
          "ends_at": flashDealEndsAt,
          "product_ids": flashDealProductIds,
        },
        "cross_sell": {
          "enabled": crossSellEnabled,
          "max_items": crossSellMaxItems,
          "product_map": crossSellProductMap,
        },
      }),
    );
    return _parseJson(res);
  }

  Map<String, dynamic> _parseJson(http.Response res) {
    try {
      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic>) return data;
      return {"ok": false, "message": "Invalid response format"};
    } catch (_) {
      return {
        "ok": false,
        "message": "HTTP ${res.statusCode}: ${res.body}",
      };
    }
  }
}
