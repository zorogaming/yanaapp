import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_sound_service.dart';
import 'woo_service.dart';

class InterestCouponOffer {
  const InterestCouponOffer({
    required this.code,
    required this.productId,
    required this.productName,
    required this.minAmount,
    required this.discountPercent,
  });

  final String code;
  final int productId;
  final String productName;
  final double minAmount;
  final double discountPercent;
}

class CouponService {
  CouponService._();
  static final CouponService instance = CouponService._();

  static const String _pendingCouponKey = 'pending_coupon_code';
  static const String _pendingCouponAtKey = 'pending_coupon_received_at';
  static const String _usedCouponsKey = 'used_coupon_codes';
  static const String _productViewCountsKey = 'interest_coupon_view_counts';
  static const String _productCouponsKey = 'interest_coupon_product_codes';
  static const String _shownProductsKey = 'interest_coupon_shown_products';
  static const String _lastCartReminderDateKey =
      'interest_coupon_last_cart_reminder_date';
  static const String _lastFailedReminderAtKey =
      'interest_coupon_last_failed_reminder_at';
  static const int _viewThreshold = 3;
  static const double interestCouponMinAmount = 1000.0;
  static const double interestCouponPercent = 2.0;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;
  final ValueNotifier<String?> latestCouponNotifier = ValueNotifier<String?>(
    null,
  );

  Future<bool> captureFromNotificationData(Map<String, dynamic> data) async {
    final raw = (data['coupon_code'] ?? data['coupon'] ?? '').toString().trim();
    if (raw.isEmpty) return false;

    final code = raw.toUpperCase();
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getStringList(_usedCouponsKey) ?? const [];
    if (used.contains(code)) return false;

    final existing = (prefs.getString(_pendingCouponKey) ?? '')
        .trim()
        .toUpperCase();
    if (existing == code) return false;

    await prefs.setString(_pendingCouponKey, code);
    await prefs.setInt(
      _pendingCouponAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    latestCouponNotifier.value = code;
    return true;
  }

  Future<InterestCouponOffer?> recordProductViewAndMaybeOffer({
    required WooService api,
    required int productId,
    required String productName,
  }) async {
    if (productId <= 0) return null;

    final prefs = await SharedPreferences.getInstance();
    final counts = _decodeStringIntMap(prefs.getString(_productViewCountsKey));
    final productKey = productId.toString();
    final nextCount = (counts[productKey] ?? 0) + 1;
    counts[productKey] = nextCount;
    await prefs.setString(_productViewCountsKey, jsonEncode(counts));
    if (nextCount < _viewThreshold) return null;

    final shown = prefs.getStringList(_shownProductsKey) ?? const [];
    if (shown.contains(productKey)) return null;

    final productCoupons = _decodeStringStringMap(
      prefs.getString(_productCouponsKey),
    );
    var code = (productCoupons[productKey] ?? '').trim().toUpperCase();
    if (code.isEmpty) {
      final created = await api.ensureInterestCoupon(
        productId: productId,
        productName: productName,
      );
      code = (created?['coupon'] ?? '').toString().trim().toUpperCase();
      if (code.isEmpty) return null;
      productCoupons[productKey] = code;
      await prefs.setString(_productCouponsKey, jsonEncode(productCoupons));
    }

    await _savePendingCoupon(code, prefs: prefs);
    await prefs.setStringList(
      _shownProductsKey,
      {...shown, productKey}.toList(),
    );

    return InterestCouponOffer(
      code: code,
      productId: productId,
      productName: productName,
      minAmount: interestCouponMinAmount,
      discountPercent: interestCouponPercent,
    );
  }

  Future<void> showCartReminderIfNeeded({
    required double cartTotal,
    required int itemCount,
    String? productName,
  }) async {
    if (itemCount <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    if (prefs.getString(_lastCartReminderDateKey) == today) return;

    final code = (prefs.getString(_pendingCouponKey) ?? '')
        .trim()
        .toUpperCase();
    if (code.isEmpty) return;

    final remaining = interestCouponMinAmount - cartTotal;
    final title = 'Your bag is waiting';
    final body = remaining <= 0
        ? 'Use 2% coupon $code on your cart before checkout.'
        : 'Add ₹${remaining.ceil()} more to use your 2% coupon $code.';
    await _showLocalNotification(
      id: 22001,
      title: title,
      body: productName?.trim().isNotEmpty == true
          ? '$body $productName'
          : body,
    );
    await prefs.setString(_lastCartReminderDateKey, today);
  }

  Future<void> showOrderFailedCouponReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final code = (prefs.getString(_pendingCouponKey) ?? '')
        .trim()
        .toUpperCase();
    if (code.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final last = prefs.getInt(_lastFailedReminderAtKey) ?? 0;
    if (now - last < const Duration(minutes: 5).inMilliseconds) return;

    await _showLocalNotification(
      id: 22002,
      title: 'Coupon is still available',
      body: 'You can still use 2% coupon $code on cart amount ₹1000+.',
    );
    await prefs.setInt(_lastFailedReminderAtKey, now);
  }

  Future<String?> getPendingCouponCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = (prefs.getString(_pendingCouponKey) ?? '').trim();
    if (code.isEmpty) return null;
    return code;
  }

  Future<void> clearPendingCoupon() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingCouponKey);
    await prefs.remove(_pendingCouponAtKey);
    latestCouponNotifier.value = null;
  }

  Future<bool> isCouponUsed(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return false;
    if (_isInterestCouponCode(normalized)) return false;
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getStringList(_usedCouponsKey) ?? const [];
    return used.contains(normalized);
  }

  Future<void> markCouponUsed(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return;
    if (_isInterestCouponCode(normalized)) return;

    final prefs = await SharedPreferences.getInstance();
    final used = (prefs.getStringList(_usedCouponsKey) ?? <String>[])
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toList();

    if (!used.contains(normalized)) {
      used.insert(0, normalized);
    }
    if (used.length > 100) {
      used.removeRange(100, used.length);
    }
    await prefs.setStringList(_usedCouponsKey, used);

    final pending = (prefs.getString(_pendingCouponKey) ?? '')
        .trim()
        .toUpperCase();
    if (pending == normalized) {
      await clearPendingCoupon();
    }
  }

  Future<void> _savePendingCoupon(
    String code, {
    SharedPreferences? prefs,
  }) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return;

    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    await resolvedPrefs.setString(_pendingCouponKey, normalized);
    await resolvedPrefs.setInt(
      _pendingCouponAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    latestCouponNotifier.value = normalized;
  }

  Map<String, int> _decodeStringIntMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, int>{};
      return decoded.map(
        (key, value) =>
            MapEntry(key.toString(), int.tryParse(value.toString()) ?? 0),
      );
    } catch (_) {
      return <String, int>{};
    }
  }

  Map<String, String> _decodeStringStringMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, String>{};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return <String, String>{};
    }
  }

  String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  bool _isInterestCouponCode(String code) {
    return code.trim().toUpperCase().startsWith('YANA2P');
  }

  Future<void> _ensureLocalNotificationsInitialized() async {
    if (_notificationsInitialized) return;
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher_v2',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(settings);
    const channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    _notificationsInitialized = true;
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await _ensureLocalNotificationsInitialized();
    await AppSoundService.instance.playNotificationSound();
    await _localNotifications.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'This channel is used for important notifications.',
          icon: '@mipmap/ic_launcher_v2',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
