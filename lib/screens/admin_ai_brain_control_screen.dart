import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../widgets/skeletons.dart';
import 'admin_custom_push_screen.dart';

class AdminAIBrainControlScreen extends StatefulWidget {
  const AdminAIBrainControlScreen({super.key});

  @override
  State<AdminAIBrainControlScreen> createState() =>
      _AdminAIBrainControlScreenState();
}

class _AdminAIBrainControlScreenState extends State<AdminAIBrainControlScreen> {
  final AdminService _admin = AdminService();

  bool _loading = true;
  bool _allowed = false;
  bool _busy = false;
  int _days = 7;
  String _status = '';
  String _error = '';

  Map<String, dynamic> _overview = const {};
  List<Map<String, dynamic>> _topProducts = const [];
  List<Map<String, dynamic>> _userInterest = const [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final allowed = await AuthService().isPrivilegedAdmin();
    if (!mounted) return;
    if (!allowed) {
      setState(() {
        _allowed = false;
        _loading = false;
      });
      return;
    }

    setState(() {
      _allowed = true;
      _loading = true;
      _error = '';
    });

    await Future.wait([
      _loadOverview(),
      _loadTopProducts(),
      _loadUserInterest(),
    ]);

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadOverview() async {
    final data = await _admin.getOverview();
    if (!mounted) return;
    if (data['ok'] == true) {
      setState(() => _overview = data);
      return;
    }
    setState(() {
      _overview = const {};
      _error = (data['message'] ?? data['code'] ?? 'Overview load failed')
          .toString();
    });
  }

  Future<void> _loadTopProducts() async {
    final data = await _admin.getTopProducts(days: _days, limit: 6);
    if (!mounted) return;
    if (data['ok'] == true) {
      final rows = (data['rows'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      setState(() => _topProducts = rows);
      return;
    }
    setState(() {
      _topProducts = const [];
      _error = (data['message'] ?? data['code'] ?? 'Top products load failed')
          .toString();
    });
  }

  Future<void> _loadUserInterest() async {
    final data = await _admin.getUserInterest(days: _days, limit: 6);
    if (!mounted) return;
    if (data['ok'] == true) {
      final rows = (data['rows'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      setState(() => _userInterest = rows);
      return;
    }
    setState(() {
      _userInterest = const [];
      _error = (data['message'] ?? data['code'] ?? 'Interest load failed')
          .toString();
    });
  }

  Future<void> _runCartAutomation() async {
    setState(() {
      _busy = true;
      _status = '';
      _error = '';
    });
    final data = await _admin.runBulkCart(days: _days);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (data['ok'] == true) {
        final result = (data['result'] as Map?) ?? const {};
        _status =
            'Cart automation completed. Targets: ${result['targets'] ?? 0}, Attempted: ${result['attempted'] ?? 0}, Skipped: ${result['skipped'] ?? 0}';
      } else {
        _error = (data['message'] ?? data['code'] ?? 'Cart automation failed')
            .toString();
      }
    });
    await _bootstrap();
  }

  Future<void> _runRepeatViewAutomation() async {
    setState(() {
      _busy = true;
      _status = '';
      _error = '';
    });
    final data = await _admin.runBulkRepeatViews();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (data['ok'] == true) {
        final result = (data['result'] as Map?) ?? const {};
        _status =
            'Repeat-view automation completed. Targets: ${result['targets'] ?? 0}, Attempted: ${result['attempted'] ?? 0}, Skipped: ${result['skipped'] ?? 0}';
      } else {
        _error = (data['message'] ?? data['code'] ?? 'Repeat-view automation failed')
            .toString();
      }
    });
    await _bootstrap();
  }

  Future<void> _openCustomPush() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminCustomPushScreen()),
    );
  }

  _AdminNextAction _buildNextAction() {
    final topProduct =
        _topProducts.isNotEmpty ? _topProducts.first : const <String, dynamic>{};
    final topInterest =
        _userInterest.isNotEmpty ? _userInterest.first : const <String, dynamic>{};

    final productName = (topProduct['product_name'] ??
            topProduct['name'] ??
            topInterest['product_name'] ??
            'top products')
        .toString();
    final productId =
        (topProduct['product_id'] ?? topProduct['id'] ?? '').toString().trim();
    final views = int.tryParse(
          (topProduct['views'] ?? topProduct['view_count'] ?? '0').toString(),
        ) ??
        0;
    final actorKey =
        (topInterest['actor_key'] ?? topInterest['label'] ?? 'high-interest users')
            .toString();
    final interestName = (topInterest['product_name'] ??
            topInterest['top_product'] ??
            topInterest['interest'] ??
            productName)
        .toString();

    if (_userInterest.isNotEmpty) {
      return _AdminNextAction(
        title: 'Run Repeat-View Campaign',
        why:
            '$interestName is showing the strongest repeat-interest signal in the selected lookback window.',
        audience: 'Users similar to $actorKey who repeatedly viewed $interestName.',
        campaignTitle: 'Still thinking about $interestName?',
        campaignBody:
            'Your shortlisted pick is still available. Take another look and choose the best fit for your ride.',
      );
    }

    if (_topProducts.isNotEmpty && views >= 5) {
      return _AdminNextAction(
        title: 'Create Focused Product Push',
        why:
            '$productName is leading product attention with $views tracked views in the current window.',
        audience: productId.isNotEmpty
            ? 'Users who viewed product ID $productId or related product families.'
            : 'Users interested in $productName and similar products.',
        campaignTitle: '$productName is trending now',
        campaignBody:
            'This popular pick is getting strong attention. Explore it now before the best options move fast.',
      );
    }

    final recentEvents =
        int.tryParse((_overview['events_30m'] ?? '0').toString()) ?? 0;
    if (recentEvents > 0) {
      return const _AdminNextAction(
        title: 'Run Cart Recovery',
        why:
            'There is live platform activity, but product interest is not yet concentrated in one clear winner.',
        audience: 'Recent cart users from the selected lookback window.',
        campaignTitle: 'Your saved items are waiting',
        campaignBody:
            'Complete your checkout and review a few matching add-ons picked for your ride.',
      );
    }

    return const _AdminNextAction(
      title: 'Wait and Monitor',
      why:
          'Current signals are still light, so sending a campaign now may reduce relevance.',
      audience: 'No strong audience cluster yet.',
      campaignTitle: 'Monitor only',
      campaignBody:
          'Refresh this screen after more traffic to unlock a stronger campaign recommendation.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090B13),
      appBar: AppBar(
        title: const Text('AI Brain Control'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loading ? null : _bootstrap,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const FullPageSkeleton()
          : !_allowed
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'This section is available to privileged admins only.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    _shellCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI Brain Automation',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Run behavior-based push workflows, monitor intent signals, and review the product interest layer from one admin surface.',
                            style: TextStyle(color: Colors.white70, height: 1.5),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _statusChip(
                                'Tracked events ${_overview['events_total'] ?? 0}',
                                const Color(0xFFFF8A2B),
                              ),
                              _statusChip(
                                'Events in 30 min ${_overview['events_30m'] ?? 0}',
                                const Color(0xFF38BDF8),
                              ),
                              _statusChip(
                                'Lookback $_days days',
                                const Color(0xFF22C55E),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        final nextAction = _buildNextAction();
                        return _shellCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Next Best Admin Action',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'AI Brain converts current signals into a direct recommendation for the admin team.',
                                style: TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 14),
                              _infoTile(
                                title: 'What To Do Next',
                                subtitle: nextAction.title,
                              ),
                              _infoTile(
                                title: 'Why',
                                subtitle: nextAction.why,
                              ),
                              _infoTile(
                                title: 'Recommended Audience',
                                subtitle: nextAction.audience,
                              ),
                              _infoTile(
                                title: 'Suggested Campaign Copy',
                                subtitle:
                                    'Title: ${nextAction.campaignTitle}\nBody: ${nextAction.campaignBody}',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _shellCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Automation Actions',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Text(
                                'Lookback Days',
                                style: TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(width: 12),
                              DropdownButton<int>(
                                value: _days,
                                dropdownColor: const Color(0xFF161A27),
                                style: const TextStyle(color: Colors.white),
                                underline: const SizedBox.shrink(),
                                items: const [1, 3, 7, 14, 30]
                                    .map(
                                      (d) => DropdownMenuItem(
                                        value: d,
                                        child: Text('$d'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _busy
                                    ? null
                                    : (value) async {
                                        if (value == null) return;
                                        setState(() => _days = value);
                                        await _bootstrap();
                                      },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _busy ? null : _runCartAutomation,
                                icon: const Icon(Icons.shopping_cart_checkout_rounded),
                                label: const Text('Run Cart Recovery'),
                              ),
                              ElevatedButton.icon(
                                onPressed: _busy ? null : _runRepeatViewAutomation,
                                icon: const Icon(Icons.visibility_rounded),
                                label: const Text('Run Repeat-View Push'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _busy ? null : _openCustomPush,
                                icon: const Icon(Icons.campaign_rounded),
                                label: const Text('Open Custom Campaign'),
                              ),
                            ],
                          ),
                          if (_status.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              _status,
                              style: const TextStyle(
                                color: Color(0xFF86EFAC),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _shellCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Top Interest Products',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Products that should feed recommendation and repeat-view campaigns.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 14),
                          if (_topProducts.isEmpty)
                            _emptyState('No top product analytics found in this window.')
                          else
                            ..._topProducts.map(
                              (row) => _infoTile(
                                title: (row['product_name'] ?? row['name'] ?? '-')
                                    .toString(),
                                subtitle:
                                    'Views: ${row['views'] ?? row['view_count'] ?? 0}  |  Product ID: ${row['product_id'] ?? row['id'] ?? '-'}',
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _shellCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'User Intent Signals',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Recent actors and their strongest interest patterns for AI-triggered campaigns.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 14),
                          if (_userInterest.isEmpty)
                            _emptyState('No user interest signals found in this window.')
                          else
                            ..._userInterest.map(
                              (row) => _infoTile(
                                title: (row['actor_key'] ?? row['label'] ?? 'Actor')
                                    .toString(),
                                subtitle:
                                    'Focus: ${(row['product_name'] ?? row['top_product'] ?? row['interest'] ?? '-').toString()}',
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A1217),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF7F1D1D)),
                        ),
                        child: Text(
                          _error,
                          style: const TextStyle(color: Color(0xFFFCA5A5)),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _shellCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF171B28), Color(0xFF111522)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: child,
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.36)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _infoTile({
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70),
      ),
    );
  }
}

class _AdminNextAction {
  const _AdminNextAction({
    required this.title,
    required this.why,
    required this.audience,
    required this.campaignTitle,
    required this.campaignBody,
  });

  final String title;
  final String why;
  final String audience;
  final String campaignTitle;
  final String campaignBody;
}
