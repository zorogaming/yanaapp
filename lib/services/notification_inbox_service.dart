import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationInboxItem {
  const NotificationInboxItem({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAtMs,
    required this.source,
    required this.data,
  });

  final String id;
  final String title;
  final String body;
  final int receivedAtMs;
  final String source;
  final Map<String, String> data;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'received_at_ms': receivedAtMs,
      'source': source,
      'data': data,
    };
  }

  static NotificationInboxItem? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final id = (raw['id'] ?? '').toString().trim();
    final title = (raw['title'] ?? '').toString();
    final body = (raw['body'] ?? '').toString();
    final receivedAtMs = int.tryParse((raw['received_at_ms'] ?? '0').toString()) ?? 0;
    final source = (raw['source'] ?? '').toString();
    final dataRaw = raw['data'];
    final data = <String, String>{};
    if (dataRaw is Map) {
      for (final entry in dataRaw.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty) continue;
        data[key] = entry.value?.toString() ?? '';
      }
    }
    if (id.isEmpty || title.isEmpty || body.isEmpty || receivedAtMs <= 0) {
      return null;
    }
    return NotificationInboxItem(
      id: id,
      title: title,
      body: body,
      receivedAtMs: receivedAtMs,
      source: source,
      data: data,
    );
  }
}

class NotificationInboxService {
  NotificationInboxService._();
  static final NotificationInboxService instance = NotificationInboxService._();

  static const String _inboxKey = 'notification_inbox_items_v1';
  static const String _lastReadAtMsKey = 'notification_inbox_last_read_at_ms';
  static const int _maxItems = 200;
  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> inboxChangeNotifier = ValueNotifier<int>(0);

  Future<void> captureFromRemoteMessage(
    RemoteMessage message, {
    required String source,
  }) async {
    final title =
        message.notification?.title?.trim().isNotEmpty == true
            ? message.notification!.title!.trim()
            : (message.data['title']?.toString().trim().isNotEmpty == true
                ? message.data['title'].toString().trim()
                : 'New update');
    final body =
        message.notification?.body?.trim().isNotEmpty == true
            ? message.notification!.body!.trim()
            : (message.data['body']?.toString().trim().isNotEmpty == true
                ? message.data['body'].toString().trim()
                : 'You have a new message.');
    final sentAtMs =
        message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
    final id = _messageId(message, sentAtMs, title, body);
    await _storeItem(
      NotificationInboxItem(
        id: id,
        title: title,
        body: body,
        receivedAtMs: sentAtMs,
        source: source,
        data: _stringifyData(message.data),
      ),
    );
    await refreshUnreadCount();
  }

  Future<List<NotificationInboxItem>> getItems() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_inboxKey) ?? const [];
    final items = <NotificationInboxItem>[];
    for (final raw in rawList) {
      try {
        final decoded = jsonDecode(raw);
        final item = NotificationInboxItem.fromJson(decoded);
        if (item != null) {
          items.add(item);
        }
      } catch (_) {
        // Ignore malformed rows.
      }
    }
    return items;
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_inboxKey);
    await prefs.setInt(_lastReadAtMsKey, DateTime.now().millisecondsSinceEpoch);
    unreadCountNotifier.value = 0;
    _notifyInboxChanged();
  }

  Future<void> markAllRead() async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getItems();
    final latestMs = items.isNotEmpty
        ? items.map((e) => e.receivedAtMs).reduce((a, b) => a > b ? a : b)
        : DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(_lastReadAtMsKey, latestMs);
    unreadCountNotifier.value = 0;
  }

  Future<int> getUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    final lastReadAt = prefs.getInt(_lastReadAtMsKey) ?? 0;
    final items = await getItems();
    return items.where((e) => e.receivedAtMs > lastReadAt).length;
  }

  Future<void> refreshUnreadCount() async {
    final unread = await getUnreadCount();
    unreadCountNotifier.value = unread;
  }

  Future<void> captureLocalAlert({
    required String title,
    required String body,
    required String source,
    Map<String, String> data = const <String, String>{},
  }) async {
    final sentAtMs = DateTime.now().millisecondsSinceEpoch;
    await _storeItem(
      NotificationInboxItem(
        id: '$sentAtMs|$title|$body|$source',
        title: title,
        body: body,
        receivedAtMs: sentAtMs,
        source: source,
        data: data,
      ),
    );
    await refreshUnreadCount();
  }

  Future<void> _storeItem(NotificationInboxItem item) async {
    final items = await getItems();
    final exists = items.any((existing) => existing.id == item.id);
    if (exists) return;

    items.insert(0, item);
    if (items.length > _maxItems) {
      items.removeRange(_maxItems, items.length);
    }

    final prefs = await SharedPreferences.getInstance();
    final encoded = items.map((e) => jsonEncode(e.toJson())).toList(growable: false);
    await prefs.setStringList(_inboxKey, encoded);
    _notifyInboxChanged();
  }

  void _notifyInboxChanged() {
    inboxChangeNotifier.value++;
  }

  String _messageId(RemoteMessage message, int sentAtMs, String title, String body) {
    final direct = message.messageId?.trim() ?? '';
    if (direct.isNotEmpty) return direct;

    final type = message.data['type']?.toString().trim() ?? '';
    final coupon = message.data['coupon_code']?.toString().trim() ?? '';
    return '$sentAtMs|$title|$body|$type|$coupon';
  }

  Map<String, String> _stringifyData(Map<String, dynamic> data) {
    final out = <String, String>{};
    for (final entry in data.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;
      out[key] = entry.value?.toString() ?? '';
    }
    return out;
  }
}
