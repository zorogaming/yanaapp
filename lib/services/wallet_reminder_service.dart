import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_sound_service.dart';
import 'woo_service.dart';

class WalletReminderService {
  WalletReminderService._();
  static final WalletReminderService instance = WalletReminderService._();

  static const String _lastReminderAtKey = 'wallet_balance_last_reminder_at';
  static const Duration _minReminderGap = Duration(days: 3);
  static const double _minReminderBalance = 50.0;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;

  Future<void> checkRemoteAndShowIfDue() async {
    if (!await _canRemindByTime()) return;
    final data = await WooService().fetchWalletOverview();
    if (data == null || data['ok'] != true) return;

    final balance = double.tryParse((data['balance'] ?? '0').toString()) ?? 0.0;
    final banned = data['banned'] == true;
    final minBilling =
        double.tryParse((data['min_billing'] ?? '2000').toString()) ?? 2000.0;
    await showIfDue(balance: balance, banned: banned, minBilling: minBilling);
  }

  Future<void> showIfDue({
    required double balance,
    required bool banned,
    required double minBilling,
  }) async {
    if (banned || balance < _minReminderBalance) return;
    if (!await _canRemindByTime()) return;

    await _showLocalNotification(
      title: 'Wallet balance available',
      body:
          'You have ₹${balance.toStringAsFixed(0)} in your wallet. Use it on orders above ₹${minBilling.toStringAsFixed(0)}.',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _lastReminderAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<bool> _canRemindByTime() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastReminderAtKey) ?? 0;
    if (last <= 0) return true;
    final elapsed = DateTime.now().millisecondsSinceEpoch - last;
    return elapsed >= _minReminderGap.inMilliseconds;
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
    required String title,
    required String body,
  }) async {
    await _ensureLocalNotificationsInitialized();
    await AppSoundService.instance.playNotificationSound();
    await _localNotifications.show(
      23001,
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
