import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product_model.dart';
import 'app_sound_service.dart';
import 'notification_inbox_service.dart';
import 'woo_service.dart';

class AIBrainService {
  AIBrainService._();

  static final AIBrainService instance = AIBrainService._();

  static const String _eventsKey = 'ai_brain_recent_events_v1';
  static const String _alertsKey = 'ai_brain_alert_cooldowns_v1';
  static const int _maxEvents = 80;
  static const String _channelId = 'ai_brain_channel';

  final WooService _wooService = WooService();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _notificationReady = false;

  Future<void> recordBehaviorEvent({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final events = await _loadEvents(prefs);
    events.insert(0, <String, dynamic>{
      'type': type.trim(),
      'timestamp_ms': DateTime.now().millisecondsSinceEpoch,
      'payload': payload,
    });
    if (events.length > _maxEvents) {
      events.removeRange(_maxEvents, events.length);
    }
    await prefs.setString(_eventsKey, jsonEncode(events));
    await _evaluateTriggers(events, prefs);
  }

  Future<AIBrainDashboard> getDashboard() async {
    final prefs = await SharedPreferences.getInstance();
    final events = await _loadEvents(prefs);
    final searches = <String>[];
    final viewedProducts = <String>[];
    final viewedIds = <int>[];
    var cartAdds = 0;
    var purchases = 0;
    var repeatInterest = 0;

    for (final event in events) {
      final payload =
          (event['payload'] as Map?)?.cast<String, dynamic>() ?? const {};
      final type = (event['type'] ?? '').toString();
      if (type == 'search') {
        final term =
            (payload['query'] ?? payload['search_term'] ?? '').toString().trim();
        if (term.isNotEmpty && term.toLowerCase() != 'empty' && !searches.contains(term)) {
          searches.add(term);
        }
      }
      if (type == 'product_view' || type == 'repeat_product_interest') {
        final name = (payload['product_name'] ?? '').toString().trim();
        final id = int.tryParse((payload['product_id'] ?? '0').toString()) ?? 0;
        if (name.isNotEmpty && !viewedProducts.contains(name)) {
          viewedProducts.add(name);
        }
        if (id > 0 && !viewedIds.contains(id)) {
          viewedIds.add(id);
        }
      }
      if (type == 'cart_add') cartAdds += 1;
      if (type == 'purchase') purchases += 1;
      if (type == 'repeat_product_interest') repeatInterest += 1;
    }

    final recommendations = await _buildRecommendations(
      searches: searches,
      viewedProducts: viewedProducts,
      viewedIds: viewedIds,
    );

    final summary = _buildSummary(
      searches: searches,
      viewedProducts: viewedProducts,
      cartAdds: cartAdds,
      purchases: purchases,
      repeatInterest: repeatInterest,
      recommendationCount: recommendations.length,
    );

    return AIBrainDashboard(
      intentLabel: summary.intentLabel,
      customerLabel: summary.customerLabel,
      intentDescription: summary.intentDescription,
      nextBestAction: summary.nextBestAction,
      autoPushState: summary.autoPushState,
      recentSearches: searches.take(4).toList(),
      recentViewedProducts: viewedProducts.take(4).toList(),
      recommendations: recommendations,
      metrics: [
        AIBrainMetric(
          title: 'Activity',
          value: '${events.length}',
          subtitle: 'Recent activity from your app journey',
          icon: Icons.bubble_chart_rounded,
          accent: const Color(0xFFFF7A18),
        ),
        AIBrainMetric(
          title: 'Top Focus',
          value: '$repeatInterest',
          subtitle: 'Products you keep coming back to',
          icon: Icons.visibility_rounded,
          accent: const Color(0xFF38BDF8),
        ),
        AIBrainMetric(
          title: 'Saved Picks',
          value: '$cartAdds',
          subtitle: 'Products you have already saved',
          icon: Icons.shopping_cart_checkout_rounded,
          accent: const Color(0xFF22C55E),
        ),
        AIBrainMetric(
          title: 'For You',
          value: '${recommendations.length}',
          subtitle: 'Fresh suggestions for your ride',
          icon: Icons.recommend_rounded,
          accent: const Color(0xFFFACC15),
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _loadEvents(SharedPreferences prefs) async {
    final raw = (prefs.getString(_eventsKey) ?? '').trim();
    if (raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final parsed = jsonDecode(raw);
      if (parsed is List) {
        return parsed.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  Future<List<Product>> _buildRecommendations({
    required List<String> searches,
    required List<String> viewedProducts,
    required List<int> viewedIds,
  }) async {
    final candidates = <String>[
      ...searches,
      ...viewedProducts.map(_extractSearchSeed),
    ].where((e) => e.trim().isNotEmpty).toList();

    for (final query in candidates) {
      try {
        final raw = await _wooService.fetchProducts(
          perPage: 6,
          search: query,
          orderBy: 'date',
          order: 'desc',
        );
        final products = raw
            .whereType<Map>()
            .map((e) => Product.fromJson(e.cast<String, dynamic>()))
            .where((product) => product.id > 0 && !viewedIds.contains(product.id))
            .take(4)
            .toList();
        if (products.isNotEmpty) return products;
      } catch (_) {}
    }

    try {
      final raw = await _wooService.fetchProducts(
        perPage: 4,
        orderBy: 'date',
        order: 'desc',
      );
      return raw
          .whereType<Map>()
          .map((e) => Product.fromJson(e.cast<String, dynamic>()))
          .where((product) => product.id > 0 && !viewedIds.contains(product.id))
          .take(4)
          .toList();
    } catch (_) {
      return const <Product>[];
    }
  }

  _BrainSummary _buildSummary({
    required List<String> searches,
    required List<String> viewedProducts,
    required int cartAdds,
    required int purchases,
    required int repeatInterest,
    required int recommendationCount,
  }) {
    if (repeatInterest > 0) {
      final focus =
          viewedProducts.isNotEmpty ? viewedProducts.first : 'high-intent products';
      return _BrainSummary(
        intentLabel: 'High Purchase Intent',
        customerLabel: 'Ready to Choose',
        intentDescription:
            'You seem to be returning to the same type of product, so this could be the right moment to choose your favorite.',
        nextBestAction: 'Take another look at $focus and compare your best options',
        autoPushState: 'Auto push armed for repeat-interest signal',
      );
    }
    if (cartAdds > purchases) {
      return const _BrainSummary(
        intentLabel: 'Cart Recovery Window',
        customerLabel: 'Almost There',
        intentDescription:
            'Your selected products are still ready for checkout, along with a few useful related picks.',
        nextBestAction: 'Continue to checkout or explore related accessories',
        autoPushState: 'Auto push armed for cart follow-up',
      );
    }
    if (searches.isNotEmpty) {
      return _BrainSummary(
        intentLabel: 'Discovery Mode',
        customerLabel: 'Exploring Options',
        intentDescription:
            'You are exploring multiple options, so fresh matches and alternatives may help you decide faster.',
        nextBestAction:
            'Browse top matches and $recommendationCount suggestions picked for you',
        autoPushState: 'Auto push on for search-based nudges',
      );
    }
    return const _BrainSummary(
      intentLabel: 'Learning Mode',
      customerLabel: 'Getting Started',
      intentDescription:
          'Keep browsing to unlock smarter suggestions tailored to your ride.',
      nextBestAction: 'Explore more products to get sharper recommendations',
      autoPushState: 'Waiting for stronger behavior signals',
    );
  }

  String _extractSearchSeed(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.trim().isNotEmpty)
        .toList();
    return words.take(3).join(' ');
  }

  Future<void> _evaluateTriggers(
    List<Map<String, dynamic>> events,
    SharedPreferences prefs,
  ) async {
    if (events.isEmpty) return;
    final latest = events.first;
    final type = (latest['type'] ?? '').toString();
    final payload =
        (latest['payload'] as Map?)?.cast<String, dynamic>() ?? const {};

    if (type == 'repeat_product_interest') {
      final productName = (payload['product_name'] ?? 'product').toString().trim();
      await _maybeSendAlert(
        prefs: prefs,
        alertKey: 'repeat_interest_${payload['product_id'] ?? productName}',
        cooldown: const Duration(hours: 12),
        title: 'AI Brain Alert',
        body:
            'Strong interest was detected in $productName. An offer or reminder is ready.',
        data: {
          'type': 'ai_brain_repeat_interest',
          'product_id': (payload['product_id'] ?? '').toString(),
        },
      );
      return;
    }

    if (type == 'cart_add') {
      // Do not raise an immediate in-app/local notification on add-to-bag.
      // It makes the bag action feel noisy and unintentionally plays the
      // notification sound during a normal shopping interaction.
      return;
    }

    if (type == 'search') {
      final query = (payload['query'] ?? '').toString().trim();
      final resultsCount =
          int.tryParse((payload['results_count'] ?? '0').toString()) ?? 0;
      if (query.isEmpty || resultsCount > 0) return;
      await _maybeSendAlert(
        prefs: prefs,
        alertKey: 'search_retry_$query',
        cooldown: const Duration(hours: 6),
        title: 'Search Insight',
        body:
            'No exact result was found for $query. The AI brain is preparing alternate recommendations.',
        data: {
          'type': 'ai_brain_search_retry',
          'query': query,
        },
      );
    }
  }

  Future<void> _maybeSendAlert({
    required SharedPreferences prefs,
    required String alertKey,
    required Duration cooldown,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    final cooldowns = <String, dynamic>{};
    final raw = (prefs.getString(_alertsKey) ?? '').trim();
    if (raw.isNotEmpty) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map) {
          cooldowns.addAll(parsed.cast<String, dynamic>());
        }
      } catch (_) {}
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final last = int.tryParse((cooldowns[alertKey] ?? '0').toString()) ?? 0;
    if (now - last < cooldown.inMilliseconds) return;

    cooldowns[alertKey] = now;
    await prefs.setString(_alertsKey, jsonEncode(cooldowns));
    await _showLocalNotification(title: title, body: body);
    await NotificationInboxService.instance.captureLocalAlert(
      title: title,
      body: body,
      source: 'ai_brain',
      data: data,
    );
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    await _ensureNotificationsReady();
    await AppSoundService.instance.playNotificationSound();
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'AI Brain Alerts',
          channelDescription: 'AI generated behavioral alerts and recommendations',
          icon: '@mipmap/ic_launcher_v2',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> _ensureNotificationsReady() async {
    if (_notificationReady) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher_v2'),
    );
    await _notifications.initialize(settings);
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            'AI Brain Alerts',
            description: 'AI generated behavioral alerts and recommendations',
            importance: Importance.max,
          ),
        );
    _notificationReady = true;
  }
}

class AIBrainDashboard {
  const AIBrainDashboard({
    required this.intentLabel,
    required this.customerLabel,
    required this.intentDescription,
    required this.nextBestAction,
    required this.autoPushState,
    required this.recentSearches,
    required this.recentViewedProducts,
    required this.recommendations,
    required this.metrics,
  });

  final String intentLabel;
  final String customerLabel;
  final String intentDescription;
  final String nextBestAction;
  final String autoPushState;
  final List<String> recentSearches;
  final List<String> recentViewedProducts;
  final List<Product> recommendations;
  final List<AIBrainMetric> metrics;
}

class AIBrainMetric {
  const AIBrainMetric({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;
}

class _BrainSummary {
  const _BrainSummary({
    required this.intentLabel,
    required this.customerLabel,
    required this.intentDescription,
    required this.nextBestAction,
    required this.autoPushState,
  });

  final String intentLabel;
  final String customerLabel;
  final String intentDescription;
  final String nextBestAction;
  final String autoPushState;
}
