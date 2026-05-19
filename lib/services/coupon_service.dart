import 'package:shared_preferences/shared_preferences.dart';

class CouponService {
  CouponService._();
  static final CouponService instance = CouponService._();

  static const String _pendingCouponKey = 'pending_coupon_code';
  static const String _pendingCouponAtKey = 'pending_coupon_received_at';
  static const String _usedCouponsKey = 'used_coupon_codes';

  Future<bool> captureFromNotificationData(Map<String, dynamic> data) async {
    final raw = (data['coupon_code'] ?? data['coupon'] ?? '').toString().trim();
    if (raw.isEmpty) return false;

    final code = raw.toUpperCase();
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getStringList(_usedCouponsKey) ?? const [];
    if (used.contains(code)) return false;

    final existing = (prefs.getString(_pendingCouponKey) ?? '').trim().toUpperCase();
    if (existing == code) return false;

    await prefs.setString(_pendingCouponKey, code);
    await prefs.setInt(
      _pendingCouponAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    return true;
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
  }

  Future<bool> isCouponUsed(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getStringList(_usedCouponsKey) ?? const [];
    return used.contains(normalized);
  }

  Future<void> markCouponUsed(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return;

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

    final pending = (prefs.getString(_pendingCouponKey) ?? '').trim().toUpperCase();
    if (pending == normalized) {
      await clearPendingCoupon();
    }
  }
}
