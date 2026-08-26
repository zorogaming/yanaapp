import 'package:firebase_messaging/firebase_messaging.dart';

class CheckoutNotificationSuppressionService {
  CheckoutNotificationSuppressionService._();

  static final CheckoutNotificationSuppressionService instance =
      CheckoutNotificationSuppressionService._();

  int _checkoutDepth = 0;

  bool get isCheckoutActive => _checkoutDepth > 0;

  void enterCheckout() {
    _checkoutDepth++;
  }

  void leaveCheckout() {
    if (_checkoutDepth <= 0) return;
    _checkoutDepth--;
  }

  bool shouldSuppressForegroundAlert(RemoteMessage message) {
    if (!isCheckoutActive) return false;
    final text = _messageText(message);
    if (text.isEmpty) return false;

    final looksLikeOrderCreated =
        text.contains('order_created') ||
        text.contains('order created') ||
        text.contains('created order') ||
        text.contains('new order') ||
        text.contains('order has been created');
    if (!looksLikeOrderCreated) return false;

    return text.contains('order') || text.contains('checkout');
  }

  String _messageText(RemoteMessage message) {
    final parts = <String>[
      message.notification?.title ?? '',
      message.notification?.body ?? '',
      ...message.data.entries.map((entry) => '${entry.key} ${entry.value}'),
    ];
    return parts.join(' ').toLowerCase();
  }
}
