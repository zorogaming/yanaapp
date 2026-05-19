import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../widgets/skeletons.dart';
import 'admin_ai_brain_control_screen.dart';
import 'admin_control_screen.dart';
import 'admin_custom_push_screen.dart';
import 'admin_home_popup_screen.dart';
import 'admin_ride_community_control_screen.dart';
import 'admin_update_notification_screen.dart';
import 'admin_user_credits_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminService _admin = AdminService();

  bool _loading = true;
  bool _allowed = false;
  String _error = '';
  int _activeMinutes = 30;

  Map<String, dynamic> _overview = const {};
  Map<String, dynamic> _walletSummary = const {};
  Map<String, dynamic> _updateState = const {};
  List<Map<String, dynamic>> _liveRows = const [];

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
      _loadLive(),
      _loadWalletSummary(),
      _loadUpdateState(),
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

  Future<void> _loadLive() async {
    final data = await _admin.getLive(
      minutes: _activeMinutes,
      limit: 80,
      includePayload: true,
    );
    if (!mounted) return;
    if (data['ok'] == true) {
      final rows = (data['rows'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => row.cast<String, dynamic>())
          .toList();
      setState(() => _liveRows = rows);
      return;
    }
    setState(() {
      _liveRows = const [];
      _error =
          (data['message'] ?? data['code'] ?? 'Live activity load failed')
              .toString();
    });
  }

  Future<void> _loadWalletSummary() async {
    final data = await _admin.getWalletUserCredits(limit: 60);
    if (!mounted) return;
    if (data['ok'] == true) {
      setState(() {
        _walletSummary =
            (data['summary'] as Map?)?.cast<String, dynamic>() ?? const {};
      });
      return;
    }
    setState(() {
      _walletSummary = const {};
      _error =
          (data['message'] ?? data['code'] ?? 'Wallet summary load failed')
              .toString();
    });
  }

  Future<void> _loadUpdateState() async {
    final data = await _admin.getAppUpdateConfig();
    if (!mounted) return;
    if (data['ok'] == true) {
      setState(() {
        _updateState =
            (data['state'] as Map?)?.cast<String, dynamic>() ?? const {};
      });
      return;
    }
    setState(() {
      _updateState = const {};
      _error =
          (data['message'] ?? data['code'] ?? 'Update state load failed')
              .toString();
    });
  }

  double _money(dynamic value) {
    return double.tryParse((value ?? 0).toString()) ?? 0;
  }

  List<Map<String, dynamic>> get _activeUsers {
    final byActor = <String, Map<String, dynamic>>{};
    final lastProduct = <String, String>{};
    final lastSearch = <String, String>{};

    for (final row in _liveRows) {
      final actorKey = _actorKey(row);
      if (actorKey.isEmpty) continue;
      final payload = _payloadMap(row);
      final eventName = (row['event_name'] ?? '').toString();

      byActor.putIfAbsent(actorKey, () {
        return {
          'actor_key': actorKey,
          'label': _actorLabel(row),
          'subtitle': _actorSubtitle(row),
          'current_page': _currentPage(eventName, row, payload),
          'event_name': eventName,
          'seen_at': (row['created_at'] ?? '').toString(),
        };
      });

      if (!lastProduct.containsKey(actorKey) &&
          (eventName == 'product_view' || eventName == 'view_item')) {
        final productName = (payload['product_name'] ?? '').toString().trim();
        final productId = (row['product_id'] ?? 0).toString();
        lastProduct[actorKey] = productName.isNotEmpty
            ? productName
            : (productId != '0' ? 'Product #$productId' : '-');
      }

      if (!lastSearch.containsKey(actorKey) && eventName == 'search') {
        final term = _searchTerm(payload);
        if (term.isNotEmpty) {
          lastSearch[actorKey] = term;
        }
      }
    }

    return byActor.values.map((item) {
      final actorKey = (item['actor_key'] ?? '').toString();
      return {
        ...item,
        'last_product': lastProduct[actorKey] ?? '-',
        'last_search': lastSearch[actorKey] ?? '-',
      };
    }).toList();
  }

  Map<String, dynamic> _payloadMap(Map<String, dynamic> row) {
    final raw = (row['payload'] ?? '').toString().trim();
    if (raw.isEmpty) return const {};
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) return parsed;
      if (parsed is Map) {
        return parsed.cast<String, dynamic>();
      }
    } catch (_) {}
    return const {};
  }

  String _actorKey(Map<String, dynamic> row) {
    final userId = int.tryParse((row['user_id'] ?? 0).toString()) ?? 0;
    final installId = (row['install_id'] ?? '').toString().trim();
    if (userId > 0) return 'u:$userId';
    if (installId.isNotEmpty) return 'g:$installId';
    return '';
  }

  String _actorLabel(Map<String, dynamic> row) {
    final userId = int.tryParse((row['user_id'] ?? 0).toString()) ?? 0;
    return userId > 0 ? 'User #$userId' : 'Guest User';
  }

  String _actorSubtitle(Map<String, dynamic> row) {
    final installId = (row['install_id'] ?? '').toString().trim();
    return installId.isNotEmpty ? installId : _actorKey(row);
  }

  String _searchTerm(Map<String, dynamic> payload) {
    for (final key in const ['search_term', 'query', 'keyword', 'term']) {
      final value = (payload[key] ?? '').toString().trim();
      if (value.isNotEmpty && value.toLowerCase() != 'empty') return value;
    }
    return '';
  }

  String _currentPage(
    String eventName,
    Map<String, dynamic> row,
    Map<String, dynamic> payload,
  ) {
    final screenName = (payload['screen_name'] ?? '').toString().trim();
    if (screenName.isNotEmpty) return screenName;
    final pageUrl = (payload['page_url'] ?? '').toString().trim();
    if (pageUrl.isNotEmpty) return pageUrl;
    final productName = (payload['product_name'] ?? '').toString().trim();
    if ((eventName == 'product_view' || eventName == 'view_item') &&
        productName.isNotEmpty) {
      return productName;
    }
    final productId = int.tryParse((row['product_id'] ?? 0).toString()) ?? 0;
    if ((eventName == 'product_view' || eventName == 'view_item') &&
        productId > 0) {
      return 'product/$productId';
    }
    return eventName;
  }

  Future<void> _openScreen(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    await _bootstrap();
  }

  Widget _shellCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(18),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF171B28), Color(0xFF111522)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _metricCard({
    required String label,
    required String value,
    required String hint,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6A00).withOpacity(0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.bolt_rounded, color: Color(0xFFFFB36B)),
            ),
            const SizedBox(width: 14),
            Expanded(
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
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(icon, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeUsers = _activeUsers;
    final walletCount = (_walletSummary['total_wallets'] ?? 0).toString();
    final walletBalance = _money(_walletSummary['total_balance']).toStringAsFixed(
      2,
    );
    final updateActive = _updateState['active'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFF090B13),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
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
                      'Ye section sirf admin ko dikhaya jayega.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _bootstrap,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _shellCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Yana Command Center',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Live activity, wallet signals, update state aur admin shortcuts ek hi mobile dashboard me.',
                              style: TextStyle(
                                color: Colors.white70,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _statusChip(
                                  'Live window $_activeMinutes min',
                                  const Color(0xFFFF8A2B),
                                ),
                                _statusChip(
                                  updateActive ? 'Update Active' : 'Update Inactive',
                                  updateActive
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                ),
                                _statusChip(
                                  'Server ${(_overview['server_time'] ?? '-').toString()}',
                                  const Color(0xFF60A5FA),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final crossAxisCount = width > 900
                              ? 4
                              : width > 560
                                  ? 2
                                  : 1;
                          final aspectRatio = width > 560 ? 1.1 : 1.45;
                          return GridView.count(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: aspectRatio,
                            children: [
                              _metricCard(
                                label: 'Tracked Events',
                                value: '${_overview['events_total'] ?? 0}',
                                hint: 'All captured events',
                                accent: const Color(0xFFFF7A1A),
                              ),
                              _metricCard(
                                label: 'Events in 30 Min',
                                value: '${_overview['events_30m'] ?? 0}',
                                hint: 'Recent platform motion',
                                accent: const Color(0xFFFACC15),
                              ),
                              _metricCard(
                                label: 'Wallet Users',
                                value: walletCount,
                                hint: 'Tracked wallets',
                                accent: const Color(0xFF34D399),
                              ),
                              _metricCard(
                                label: 'Wallet Balance',
                                value: 'INR $walletBalance',
                                hint: 'Current total balance',
                                accent: const Color(0xFF60A5FA),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _shellCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(
                              'Admin Actions',
                              'Existing tools ko polished mobile hub me group kiya gaya hai.',
                            ),
                            const SizedBox(height: 14),
                            _actionTile(
                              icon: Icons.arrow_forward_ios_rounded,
                              title: 'AI Brain Control',
                              subtitle: 'Behavior push automation aur AI signal tools',
                              onTap: () => _openScreen(
                                const AdminAIBrainControlScreen(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _actionTile(
                              icon: Icons.arrow_forward_ios_rounded,
                              title: 'Ride Community Control',
                              subtitle:
                                  'Approvals, rankings, rewards, memories aur ride alerts',
                              onTap: () => _openScreen(
                                const AdminRideCommunityControlScreen(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _actionTile(
                              icon: Icons.arrow_forward_ios_rounded,
                              title: 'Custom Push Campaign',
                              subtitle: 'Selected users ya audience ko push bhejo',
                              onTap: () => _openScreen(
                                const AdminCustomPushScreen(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _actionTile(
                              icon: Icons.arrow_forward_ios_rounded,
                              title: 'Home Popup',
                              subtitle: 'Dismissible home popup send ya manage karo',
                              onTap: () => _openScreen(
                                const AdminHomePopupScreen(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _actionTile(
                              icon: Icons.arrow_forward_ios_rounded,
                              title: 'Update for Customers',
                              subtitle: 'Customer update flow activate ya manage karo',
                              onTap: () => _openScreen(
                                const AdminUpdateNotificationScreen(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _actionTile(
                              icon: Icons.arrow_forward_ios_rounded,
                              title: 'Wallet and Admin Control',
                              subtitle: 'Wallet settings, credit, ban aur bulk tools',
                              onTap: () => _openScreen(
                                const AdminControlScreen(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _actionTile(
                              icon: Icons.arrow_forward_ios_rounded,
                              title: 'User Credits Explorer',
                              subtitle: 'Wallet users, credits, debits aur status dekho',
                              onTap: () => _openScreen(
                                const AdminUserCreditsScreen(),
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
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(
                                  width: MediaQuery.of(context).size.width > 420
                                      ? MediaQuery.of(context).size.width - 140
                                      : MediaQuery.of(context).size.width - 64,
                                  child: _sectionTitle(
                                    'Live Active Users',
                                    'Current page, last product aur last search snapshot.',
                                  ),
                                ),
                                DropdownButton<int>(
                                  value: _activeMinutes,
                                  dropdownColor: const Color(0xFF161A27),
                                  style: const TextStyle(color: Colors.white),
                                  underline: const SizedBox.shrink(),
                                  items: const [15, 30, 60, 120]
                                      .map(
                                        (m) => DropdownMenuItem(
                                          value: m,
                                          child: Text('$m min'),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) async {
                                    if (value == null) return;
                                    setState(() => _activeMinutes = value);
                                    await _loadLive();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (activeUsers.isEmpty)
                              _emptyState('Abhi recent active users data nahi mila.')
                            else
                              ...activeUsers.take(12).map(_activeUserTile),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _shellCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(
                              'System Snapshot',
                              'Update notice aur wallet state ka quick view.',
                            ),
                            const SizedBox(height: 14),
                            _infoRow(
                              'Update status',
                              updateActive ? 'Active' : 'Inactive',
                              highlight: updateActive,
                            ),
                            _infoRow(
                              'Update title',
                              (_updateState['title'] ?? '-').toString(),
                            ),
                            _infoRow(
                              'Latest version',
                              (_updateState['latest_version'] ?? '-').toString(),
                            ),
                            _infoRow(
                              'Min version',
                              (_updateState['min_version'] ?? '-').toString(),
                            ),
                            _infoRow(
                              'Force update',
                              _updateState['force_update'] == true ? 'Yes' : 'No',
                            ),
                            _infoRow(
                              'Wallet users',
                              walletCount,
                            ),
                            _infoRow(
                              'Blocked wallets',
                              '${_walletSummary['total_banned'] ?? 0}',
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
                ),
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

  Widget _activeUserTile(Map<String, dynamic> row) {
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
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A1A).withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.person_rounded,
                  color: Color(0xFFFFB36B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (row['label'] ?? '-').toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (row['subtitle'] ?? '-').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                (row['seen_at'] ?? '-').toString(),
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _miniLine('Current page', (row['current_page'] ?? '-').toString()),
          _miniLine('Last product', (row['last_product'] ?? '-').toString()),
          _miniLine('Last search', (row['last_search'] ?? '-').toString()),
        ],
      ),
    );
  }

  Widget _miniLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Colors.white60,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: highlight ? const Color(0xFF86EFAC) : Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
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
