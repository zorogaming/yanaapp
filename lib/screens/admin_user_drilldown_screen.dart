import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../widgets/skeletons.dart';

class AdminUserDrilldownScreen extends StatefulWidget {
  const AdminUserDrilldownScreen({super.key});

  @override
  State<AdminUserDrilldownScreen> createState() => _AdminUserDrilldownScreenState();
}

class _AdminUserDrilldownScreenState extends State<AdminUserDrilldownScreen> {
  final AdminService _admin = AdminService();

  bool _loading = true;
  String _error = '';
  int _days = 7;
  List<dynamic> _actors = const [];
  String _selectedActorKey = '';
  String _selectedActorLastPage = '-';
  String _selectedActorEmail = '-';
  int _selectedActorTokens = 0;
  List<dynamic> _timeline = const [];

  @override
  void initState() {
    super.initState();
    _loadActors();
  }

  Future<void> _loadActors() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    final data = await _admin.getActors(days: _days, limit: 120);
    if (!mounted) return;
    if (data['ok'] == true) {
      final actors = (data['actors'] as List?) ?? const [];
      setState(() {
        _actors = actors;
        if (_actors.isEmpty) {
          _selectedActorKey = '';
          _timeline = const [];
          _selectedActorLastPage = '-';
          _selectedActorEmail = '-';
          _selectedActorTokens = 0;
        } else {
          final exists = _actors.any((a) => a is Map && a['actor_key']?.toString() == _selectedActorKey);
          if (!exists) {
            _selectedActorKey = ((_actors.first as Map)['actor_key'] ?? '').toString();
          }
        }
        _loading = false;
      });
      if (_selectedActorKey.isNotEmpty) {
        await _loadActorDetail();
      }
      return;
    }

    setState(() {
      _loading = false;
      _error = (data['message'] ?? data['code'] ?? 'Actors API failed').toString();
    });
  }

  Future<void> _loadActorDetail() async {
    if (_selectedActorKey.isEmpty) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    final data = await _admin.getActorDetail(actorKey: _selectedActorKey, minutes: 24 * 60, limit: 60);
    if (!mounted) return;

    if (data['ok'] == true) {
      final actor = (data['actor'] as Map?) ?? const {};
      setState(() {
        _timeline = (data['rows'] as List?) ?? const [];
        _selectedActorLastPage = (actor['last_page'] ?? '-').toString();
        _selectedActorEmail = (actor['user_email'] ?? '-').toString();
        _selectedActorTokens = int.tryParse((actor['tokens_count'] ?? 0).toString()) ?? 0;
        _loading = false;
      });
      return;
    }

    setState(() {
      _timeline = const [];
      _loading = false;
      _error = (data['message'] ?? data['code'] ?? 'Actor detail API failed').toString();
    });
  }

  Map<String, dynamic> _payloadFromRow(Map map) {
    final raw = map['payload'];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map<String, dynamic>) return parsed;
      } catch (_) {}
    }
    return const {};
  }

  String _detailValue(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final value = payload[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      appBar: AppBar(
        title: const Text('User Drilldown'),
        backgroundColor: const Color(0xFF1C1F2E),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadActors,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_error.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.16),
                border: Border.all(color: Colors.redAccent),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('API Error: $_error', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1F2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Text('Window', style: TextStyle(color: Colors.white70)),
                const SizedBox(width: 10),
                DropdownButton<int>(
                  value: _days,
                  dropdownColor: const Color(0xFF1C1F2E),
                  style: const TextStyle(color: Colors.white),
                  items: const [1, 3, 7, 14, 30]
                      .map((d) => DropdownMenuItem(value: d, child: Text('$d days')))
                      .toList(),
                  onChanged: _loading
                      ? null
                      : (v) async {
                          if (v == null) return;
                          setState(() => _days = v);
                          await _loadActors();
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1F2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: _actors.isEmpty
                ? const Text('No users found.', style: TextStyle(color: Colors.white70))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButton<String>(
                        value: _selectedActorKey.isEmpty ? null : _selectedActorKey,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1C1F2E),
                        style: const TextStyle(color: Colors.white),
                        hint: const Text('Select user/install', style: TextStyle(color: Colors.white70)),
                        items: _actors.map((actor) {
                          final map = actor is Map ? actor : const {};
                          final key = (map['actor_key'] ?? '').toString();
                          final email = (map['user_email'] ?? '-').toString();
                          final page = (map['last_page'] ?? '-').toString();
                          final seen = (map['last_seen'] ?? '-').toString();
                          return DropdownMenuItem(value: key, child: Text('$key | $email | $page | $seen'));
                        }).toList(),
                        onChanged: (v) async {
                          if (v == null) return;
                          setState(() => _selectedActorKey = v);
                          await _loadActorDetail();
                        },
                      ),
                      const SizedBox(height: 8),
                      Text('Current/Last Page: $_selectedActorLastPage', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('Email: $_selectedActorEmail', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('Active Tokens: $_selectedActorTokens', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1F2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recent Timeline', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: FullPageSkeleton(padding: EdgeInsets.zero),
                  ),
                if (!_loading && _timeline.isEmpty)
                  const Text('No events found.', style: TextStyle(color: Colors.white70)),
                if (!_loading)
                  ..._timeline.take(30).map((row) {
                    final map = row is Map ? row : const {};
                    final payload = _payloadFromRow(map);
                    final page = _detailValue(payload, ['screen_name', 'page_url']);
                    final productName = _detailValue(payload, ['product_name']);
                    final productId = _detailValue(payload, ['product_id']);
                    final orderId = _detailValue(payload, ['order_id']);
                    final action = _detailValue(payload, ['action', 'status', 'payment_method']);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131725),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${map['created_at'] ?? '-'} | ${map['event_name'] ?? '-'}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text('Page: $page', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            Text('Product: ${productName != '-' ? productName : productId}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            Text('Order: $orderId', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            Text('Action/Status: $action', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
