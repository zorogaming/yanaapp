import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../widgets/skeletons.dart';

class AdminTopProductsAnalyticsScreen extends StatefulWidget {
  const AdminTopProductsAnalyticsScreen({super.key});

  @override
  State<AdminTopProductsAnalyticsScreen> createState() => _AdminTopProductsAnalyticsScreenState();
}

class _AdminTopProductsAnalyticsScreenState extends State<AdminTopProductsAnalyticsScreen> {
  final AdminService _admin = AdminService();
  bool _loading = true;
  String _error = '';
  int _days = 30;
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
    final data = await _admin.getTopProducts(days: _days, limit: 120);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (data['ok'] == true) {
        _rows = (data['rows'] as List?) ?? const [];
      } else {
        _rows = const [];
        _error = (data['message'] ?? data['code'] ?? 'Top products API failed').toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      appBar: AppBar(
        title: const Text('Top Products Analytics'),
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
                  items: const [7, 15, 30, 60, 90]
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
                    ? const Text('No product analytics yet.', style: TextStyle(color: Colors.white70))
                    : Column(
                        children: _rows.asMap().entries.map((entry) {
                          final rank = entry.key + 1;
                          final map = entry.value is Map ? entry.value as Map : const {};
                          final name = (map['product_name'] ?? 'Product').toString();
                          final productId = (map['product_id'] ?? '-').toString();
                          final sold = (map['sold_qty'] ?? 0).toString();
                          final views = (map['views'] ?? 0).toString();
                          final revenue = (map['net_revenue'] ?? 0).toString();
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131725),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 24,
                                  alignment: Alignment.center,
                                  child: Text('$rank', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('$name (ID: $productId)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      Text('Sold Qty: $sold', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                      Text('App Views: $views', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                      Text('Net Revenue: $revenue', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                    ],
                                  ),
                                ),
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
