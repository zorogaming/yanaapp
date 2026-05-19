import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../widgets/skeletons.dart';

class AdminUserInterestScreen extends StatefulWidget {
  const AdminUserInterestScreen({super.key});

  @override
  State<AdminUserInterestScreen> createState() => _AdminUserInterestScreenState();
}

class _AdminUserInterestScreenState extends State<AdminUserInterestScreen> {
  final AdminService _admin = AdminService();
  bool _loading = true;
  String _error = '';
  int _days = 7;
  List<dynamic> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    final data = await _admin.getUserInterest(days: _days, limit: 150);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (data['ok'] == true) {
        _rows = (data['rows'] as List?) ?? const [];
      } else {
        _rows = const [];
        _error = (data['message'] ?? data['code'] ?? 'User interest API failed').toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      appBar: AppBar(
        title: const Text('User Product Interest'),
        backgroundColor: const Color(0xFF1C1F2E),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
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
                          await _load();
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_error.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent),
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
            child: _loading
                ? const FullPageSkeleton(padding: EdgeInsets.zero)
                : _rows.isEmpty
                    ? const Text('No interest data.', style: TextStyle(color: Colors.white70))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _rows.take(120).map((row) {
                          final map = row is Map ? row : const {};
                          final name = (map['user_name'] ?? '').toString();
                          final email = (map['user_email'] ?? '').toString();
                          final actor = (map['actor_key'] ?? '-').toString();
                          final product = (map['product_name'] ?? 'Product').toString();
                          final productId = (map['product_id'] ?? '-').toString();
                          final views = (map['views'] ?? 0).toString();
                          final page = (map['last_page'] ?? '-').toString();
                          final seen = (map['last_seen'] ?? '-').toString();
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131725),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$product (ID: $productId)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text('User: ${name.isNotEmpty ? name : actor}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                Text('Email: ${email.isNotEmpty ? email : '-'}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                Text('Views/Interest Count: $views', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                Text('Last Page: $page', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                Text('Last Seen: $seen', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
  }
}
