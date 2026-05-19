import 'dart:convert';
import 'dart:math';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'ai_brain_service.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  static const String _anonymousIdKey = "anonymous_install_id";
  static const String _watchCountPrefix = "watch_count_";
  static const String _watchStartPrefix = "watch_start_";
  static const int _watchWindowMs = 30 * 60 * 1000;
  static const String _fcmTokenKey = "fcm_token";
  static const String _appVersionKey = "app_version";

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  Future<void> initIdentity({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedUserId = userId?.trim();
    final hasUser = normalizedUserId != null && normalizedUserId.isNotEmpty;

    final anonymousId =
        prefs.getString(_anonymousIdKey) ?? _buildAnonymousInstallId();
    if (!prefs.containsKey(_anonymousIdKey)) {
      await prefs.setString(_anonymousIdKey, anonymousId);
    }

    await _analytics.setUserProperty(name: "install_id", value: anonymousId);
    await _analytics.setUserProperty(name: "is_logged_in", value: "$hasUser");

    if (hasUser) {
      await _analytics.setUserId(id: normalizedUserId);
      await _analytics.setUserProperty(
        name: "customer_type",
        value: "logged_in",
      );
    } else {
      await _analytics.setUserId(id: anonymousId);
      await _analytics.setUserProperty(
        name: "customer_type",
        value: "guest",
      );
    }
    await _sendAppEvent(
      eventName: "identity_sync",
      payload: {
        "user_id": normalizedUserId,
        "install_id": anonymousId,
        "is_logged_in": hasUser,
      },
    );
  }

  Future<void> setAppVersion(String version) async {
    final normalized = _sanitize(version, fallback: "");
    if (normalized.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appVersionKey, normalized);
    await _analytics.setUserProperty(name: "app_version", value: normalized);
  }

  Future<void> logScreen(String screenName) async {
    final normalizedScreen = _sanitize(screenName, fallback: "unknown_screen");
    await _analytics.logScreenView(
      screenName: normalizedScreen,
    );
    await _sendAppEvent(
      eventName: "page_view",
      payload: {
        "screen_name": normalizedScreen,
        "page_url": normalizedScreen,
        "action": "view_page",
      },
    );
    await AIBrainService.instance.recordBehaviorEvent(
      type: "page_view",
      payload: {
        "screen_name": normalizedScreen,
        "page_url": normalizedScreen,
      },
    );
  }

  Future<void> logAppLifecycle({
    required String eventName,
    String page = "app",
  }) async {
    await _sendAppEvent(
      eventName: _sanitize(eventName, fallback: "app_event"),
      payload: {
        "screen_name": _sanitize(page, fallback: "app"),
        "page_url": _sanitize(page, fallback: "app"),
        "action": _sanitize(eventName, fallback: "app_event"),
      },
    );
  }

  Future<void> logSearch({
    required String query,
    required int resultsCount,
    String source = "app",
  }) async {
    await _analytics.logSearch(
      searchTerm: _sanitize(query, fallback: "empty"),
      parameters: {
        "results_count": resultsCount,
        "source": _sanitize(source),
      },
    );
    await _sendAppEvent(
      eventName: "search",
      payload: {
        "search_term": _sanitize(query, fallback: "empty"),
        "query": _sanitize(query, fallback: "empty"),
        "results_count": resultsCount,
        "source": _sanitize(source),
      },
    );
    await AIBrainService.instance.recordBehaviorEvent(
      type: "search",
      payload: {
        "query": _sanitize(query, fallback: "empty"),
        "search_term": _sanitize(query, fallback: "empty"),
        "results_count": resultsCount,
        "source": _sanitize(source),
      },
    );
  }

  Future<void> logProductView({
    required int productId,
    required String productName,
    required String price,
    String currency = "INR",
  }) async {
    final amount = double.tryParse(price) ?? 0.0;
    await _analytics.logViewItem(
      currency: currency,
      value: amount,
      items: [
        AnalyticsEventItem(
          itemId: productId.toString(),
          itemName: _sanitize(productName),
          price: amount,
          currency: currency,
        ),
      ],
    );
    await _sendAppEvent(
      eventName: "product_view",
      payload: {
        "product_id": productId,
        "product_name": _sanitize(productName),
        "page_url": "product/$productId",
        "action": "view_product",
        "price": amount,
        "currency": currency,
      },
    );
    await AIBrainService.instance.recordBehaviorEvent(
      type: "product_view",
      payload: {
        "product_id": productId,
        "product_name": _sanitize(productName),
        "price": amount,
        "currency": currency,
      },
    );
    await _trackRepeatWatch(productId: productId, productName: productName);
  }

  Future<void> logAddToCart({
    required int productId,
    required String productName,
    required int quantity,
    required double price,
    String currency = "INR",
  }) async {
    await _analytics.logAddToCart(
      currency: currency,
      value: price * quantity,
      items: [
        AnalyticsEventItem(
          itemId: productId.toString(),
          itemName: _sanitize(productName),
          quantity: quantity,
          price: price,
          currency: currency,
        ),
      ],
    );
    await _sendAppEvent(
      eventName: "cart_add",
      payload: {
        "product_id": productId,
        "product_name": _sanitize(productName),
        "page_url": "cart",
        "action": "add_to_cart",
        "quantity": quantity,
        "price": price,
        "currency": currency,
      },
    );
    await AIBrainService.instance.recordBehaviorEvent(
      type: "cart_add",
      payload: {
        "product_id": productId,
        "product_name": _sanitize(productName),
        "quantity": quantity,
        "price": price,
        "currency": currency,
      },
    );
  }

  Future<void> logWishlistAction({
    required int productId,
    required String productName,
    required double price,
    required String stockStatus,
    required bool inStock,
    required bool added,
    String source = "app",
    String currency = "INR",
  }) async {
    final eventName = added ? "wishlist_add" : "wishlist_remove";
    await _analytics.logEvent(
      name: eventName,
      parameters: {
        "product_id": productId.toString(),
        "product_name": _sanitize(productName),
        "price": price,
        "currency": currency,
        "stock_status": _sanitize(stockStatus, fallback: inStock ? "instock" : "outofstock"),
        "in_stock": inStock ? "1" : "0",
        "source": _sanitize(source),
      },
    );
    await _sendAppEvent(
      eventName: eventName,
      payload: {
        "product_id": productId,
        "product_name": _sanitize(productName),
        "page_url": "product/$productId",
        "action": added ? "add_to_wishlist" : "remove_from_wishlist",
        "price": price,
        "currency": currency,
        "stock_status": _sanitize(
          stockStatus,
          fallback: inStock ? "instock" : "outofstock",
        ),
        "in_stock": inStock,
        "source": _sanitize(source),
        "interest_type": "wishlist",
      },
    );
    await AIBrainService.instance.recordBehaviorEvent(
      type: eventName,
      payload: {
        "product_id": productId,
        "product_name": _sanitize(productName),
        "price": price,
        "currency": currency,
        "stock_status": _sanitize(
          stockStatus,
          fallback: inStock ? "instock" : "outofstock",
        ),
        "in_stock": inStock,
        "source": _sanitize(source),
        "interest_type": "wishlist",
      },
    );
  }

  Future<void> logBeginCheckout({
    required int itemsCount,
    required double value,
    String currency = "INR",
  }) async {
    await _analytics.logBeginCheckout(
      currency: currency,
      value: value,
      items: [
        AnalyticsEventItem(
          itemId: "cart",
          itemName: "checkout",
          quantity: itemsCount,
          price: value,
          currency: currency,
        ),
      ],
    );
    await _sendAppEvent(
      eventName: "begin_checkout",
      payload: {
        "items_count": itemsCount,
        "value": value,
        "currency": currency,
      },
    );
    await AIBrainService.instance.recordBehaviorEvent(
      type: "begin_checkout",
      payload: {
        "items_count": itemsCount,
        "value": value,
        "currency": currency,
      },
    );
  }

  Future<void> logPaymentStatus({
    required int? orderId,
    required String status,
    required String paymentMethod,
    required double amount,
    String currency = "INR",
  }) async {
    await _analytics.logEvent(
      name: "payment_status",
      parameters: {
        "order_id": orderId ?? 0,
        "status": _sanitize(status),
        "payment_method": _sanitize(paymentMethod),
        "amount": amount,
        "currency": currency,
      },
    );
    await _sendAppEvent(
      eventName: "payment_status",
      payload: {
        "order_id": orderId,
        "status": _sanitize(status),
        "payment_method": _sanitize(paymentMethod),
        "amount": amount,
        "currency": currency,
      },
    );
  }

  Future<void> logPurchase({
    required int orderId,
    required double amount,
    String currency = "INR",
  }) async {
    await _analytics.logPurchase(
      transactionId: orderId.toString(),
      value: amount,
      currency: currency,
    );
    await _sendAppEvent(
      eventName: "purchase",
      payload: {
        "order_id": orderId,
        "amount": amount,
        "currency": currency,
      },
    );
    await AIBrainService.instance.recordBehaviorEvent(
      type: "purchase",
      payload: {
        "order_id": orderId,
        "amount": amount,
        "currency": currency,
      },
    );
  }

  Future<void> registerPushToken({
    required String token,
    required String platform,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fcmTokenKey, token);
    await _sendAppEvent(
      eventName: "push_token_update",
      payload: {
        "fcm_token": token,
        "platform": _sanitize(platform, fallback: "android"),
      },
    );
  }

  Future<void> logHomePopupEvent({
    required String action,
    required String campaignId,
    String title = "",
    String buttonText = "",
    String actionUrl = "",
  }) async {
    final normalizedCampaignId = _sanitize(campaignId, fallback: "");
    if (normalizedCampaignId.isEmpty) return;

    await _sendAppEvent(
      eventName: "home_popup_${_sanitize(action, fallback: "view")}",
      payload: {
        "campaign_id": normalizedCampaignId,
        "title": _sanitize(title, fallback: "Important Update"),
        "button_text": _sanitize(buttonText, fallback: ""),
        "action_url": actionUrl.trim(),
      },
    );
  }

  String _buildAnonymousInstallId() {
    final random = Random.secure();
    final suffix = List.generate(
      8,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return "guest_${DateTime.now().millisecondsSinceEpoch}_$suffix";
  }

  Future<void> _trackRepeatWatch({
    required int productId,
    required String productName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final startKey = "$_watchStartPrefix$productId";
    final countKey = "$_watchCountPrefix$productId";

    final start = prefs.getInt(startKey) ?? now;
    var count = prefs.getInt(countKey) ?? 0;
    final withinWindow = (now - start) <= _watchWindowMs;

    if (!withinWindow) {
      count = 0;
      await prefs.setInt(startKey, now);
    }

    count += 1;
    await prefs.setInt(countKey, count);
    if (count >= 3) {
      await _analytics.logEvent(
        name: "repeat_product_interest",
        parameters: {
          "product_id": productId,
          "product_name": _sanitize(productName),
          "views_in_30m": count,
        },
      );
      await _sendAppEvent(
        eventName: "repeat_product_interest",
        payload: {
          "product_id": productId,
          "product_name": _sanitize(productName),
          "views_in_30m": count,
        },
      );
      await AIBrainService.instance.recordBehaviorEvent(
        type: "repeat_product_interest",
        payload: {
          "product_id": productId,
          "product_name": _sanitize(productName),
          "views_in_30m": count,
        },
      );
    }
  }

  Future<void> _sendAppEvent({
    required String eventName,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final installId = prefs.getString(_anonymousIdKey) ?? "";
      final userId = prefs.getString("user_id");
      final token = prefs.getString(_fcmTokenKey);
      var appVersion = (prefs.getString(_appVersionKey) ?? "").trim();
      if (appVersion.isEmpty) {
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = _sanitize(packageInfo.version, fallback: "");
        if (appVersion.isNotEmpty) {
          await prefs.setString(_appVersionKey, appVersion);
        }
      }
      final base = Uri.parse(Config.baseUrl);
      final enrichedPayload = <String, dynamic>{
        ...payload,
        if (appVersion.isNotEmpty) "app_version": appVersion,
      };
      final body = <String, dynamic>{
        "event_name": _sanitize(eventName),
        "install_id": installId,
        "user_id": userId,
        "fcm_token": token,
        "platform": "android",
        "app_version": appVersion,
        "product_id": enrichedPayload["product_id"],
        "order_id": enrichedPayload["order_id"],
        "event_time": DateTime.now().toUtc().toIso8601String(),
        "payload": enrichedPayload,
      };

      final hosts = <String>{
        base.host,
        if (base.host.startsWith("www.")) base.host.substring(4),
        if (!base.host.startsWith("www.")) "www.${base.host}",
      };
      final roots = <Uri>[];
      for (final host in hosts) {
        roots.add(Uri.parse("${base.scheme}://$host/wp-json/wp/v1/app-event"));
        roots.add(Uri.parse("${base.scheme}://$host/wp-json/yana/v1/app-event"));
      }

      for (final url in roots) {
        final res = await http
            .post(
              url,
              headers: {
                "Content-Type": "application/json",
                Config.appHeaderKey: Config.appHeaderValue,
              },
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 10));
        if (res.statusCode >= 200 && res.statusCode < 300) {
          return;
        }
      }
    } catch (_) {
      // Analytics pipeline should never block app UX.
    }
  }

  String _sanitize(String value, {String fallback = "na"}) {
    final cleaned = value.trim().replaceAll(RegExp(r"\s+"), " ");
    if (cleaned.isEmpty) return fallback;
    return cleaned.length > 90 ? cleaned.substring(0, 90) : cleaned;
  }
}
