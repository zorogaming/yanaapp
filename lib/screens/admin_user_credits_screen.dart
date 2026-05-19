import 'package:flutter/material.dart';

import '../services/admin_service.dart';

class AdminUserCreditsScreen extends StatefulWidget {
  const AdminUserCreditsScreen({super.key});

  @override
  State<AdminUserCreditsScreen> createState() => _AdminUserCreditsScreenState();
}

class _AdminUserCreditsScreenState extends State<AdminUserCreditsScreen> {
  final AdminService _admin = AdminService();
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  String _error = '';
  Map<String, dynamic> _summary = const {};
  List<dynamic> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    final data = await _admin.getWalletUserCredits(
      limit: 150,
      q: _searchController.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (data['ok'] == true) {
        _summary = (data['summary'] as Map?)?.cast<String, dynamic>() ?? const {};
        _rows = (data['rows'] as List?) ?? const [];
      } else {
        _error = (data['message'] ?? data['code'] ?? 'Failed to load user credits').toString();
      }
    });
  }

  String _money(dynamic v) {
    final d = double.tryParse((v ?? 0).toString()) ?? 0;
    return d.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Credits')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search user/install/actor',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _load,
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(_error, style: const TextStyle(color: Colors.red)),
            ),
          if (_summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  Chip(label: Text('Wallets: ${_summary['total_wallets'] ?? 0}')),
                  Chip(label: Text('Balance: ${_money(_summary['total_balance'])}')),
                  Chip(label: Text('Banned: ${_summary['total_banned'] ?? 0}')),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? const Center(child: Text('No records found'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          itemCount: _rows.length,
                          itemBuilder: (context, index) {
                            final map = (_rows[index] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (map['actor_key'] ?? '-').toString(),
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 8),
                                    Text('App User ID: ${map['user_id'] ?? 0} | WP User ID: ${map['wp_user_id'] ?? 0}'),
                                    Text('Install ID: ${(map['install_id'] ?? '').toString()}'),
                                    Text('WP Name: ${(map['wp_user_name'] ?? '').toString()}'),
                                    Text('WP Email: ${(map['wp_user_email'] ?? '').toString()}'),
                                    const SizedBox(height: 6),
                                    Text('Balance: ${_money(map['balance'])}'),
                                    Text('Credited: ${_money(map['credit_total'])} | Debited: ${_money(map['debit_total'])}'),
                                    Text('TX Count: ${map['tx_count'] ?? 0} | Banned: ${map['banned'] == true ? 'Yes' : 'No'}'),
                                    Text('Merged: ${map['is_merged'] == true ? 'Yes' : 'No'} -> ${(map['merged_to_actor'] ?? '').toString()}'),
                                    Text('Updated: ${(map['updated_at'] ?? '').toString()}'),
                                    Text('Last TX: ${(map['last_tx_at'] ?? '').toString()}'),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

