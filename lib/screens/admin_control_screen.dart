import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../widgets/skeletons.dart';
import 'admin_custom_push_screen.dart';
import 'admin_top_products_analytics_screen.dart';
import 'admin_user_drilldown_screen.dart';
import 'admin_user_interest_screen.dart';

class AdminControlScreen extends StatefulWidget {
  const AdminControlScreen({super.key});

  @override
  State<AdminControlScreen> createState() => _AdminControlScreenState();
}

class _AdminControlScreenState extends State<AdminControlScreen> {
  final AdminService _admin = AdminService();
  final TextEditingController _walletActorController = TextEditingController();
  final TextEditingController _walletUserIdController = TextEditingController();
  final TextEditingController _walletInstallIdController = TextEditingController();
  final TextEditingController _walletAmountController = TextEditingController(
    text: "200",
  );
  final TextEditingController _cashbackSpendController = TextEditingController(
    text: "1000",
  );
  final TextEditingController _cashbackRewardController = TextEditingController(
    text: "50",
  );
  final TextEditingController _flashDealTitleController = TextEditingController(
    text: "Limited Time Offer",
  );
  final TextEditingController _flashDealSubtitleController = TextEditingController();
  final TextEditingController _flashDealEndsAtController = TextEditingController();
  final TextEditingController _flashDealProductIdsController = TextEditingController();
  final TextEditingController _crossSellMaxItemsController = TextEditingController(
    text: "5",
  );
  final TextEditingController _crossSellMapController = TextEditingController();

  bool _loading = true;
  bool _allowed = false;
  bool _busy = false;
  int _minutes = 30;
  int _days = 3;

  Map<String, dynamic> _overview = const {};
  List<dynamic> _rows = const [];
  bool _walletEnabled = true;
  double _walletSignupBonus = 200;
  double _walletMinBilling = 2000;
  bool _cashbackEnabled = false;
  double _cashbackSpendAmount = 1000;
  double _cashbackRewardAmount = 50;
  bool _flashDealEnabled = false;
  bool _crossSellEnabled = false;
  String _status = '';
  String _apiError = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _walletActorController.dispose();
    _walletUserIdController.dispose();
    _walletInstallIdController.dispose();
    _walletAmountController.dispose();
    _cashbackSpendController.dispose();
    _cashbackRewardController.dispose();
    _flashDealTitleController.dispose();
    _flashDealSubtitleController.dispose();
    _flashDealEndsAtController.dispose();
    _flashDealProductIdsController.dispose();
    _crossSellMaxItemsController.dispose();
    _crossSellMapController.dispose();
    super.dispose();
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
    });

    await Future.wait([
      _loadOverview(),
      _loadLive(),
      _loadWalletConfig(),
      _loadGrowthConfig(),
    ]);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadOverview() async {
    final data = await _admin.getOverview();
    if (!mounted) return;
    setState(() {
      if (data['ok'] == true) {
        _overview = data;
        _apiError = '';
      } else {
        _overview = const {};
        _apiError = (data['message'] ?? data['code'] ?? 'Overview API failed').toString();
      }
    });
  }

  Future<void> _loadLive() async {
    final data = await _admin.getLive(minutes: _minutes, limit: 80);
    if (!mounted) return;
    setState(() {
      if (data['ok'] == true) {
        _rows = (data['rows'] as List?) ?? const [];
        _apiError = '';
      } else {
        _rows = const [];
        _apiError = (data['message'] ?? data['code'] ?? 'Live API failed').toString();
      }
    });
  }

  Future<void> _loadWalletConfig() async {
    final data = await _admin.getWalletConfig();
    if (!mounted) return;
    if (data['ok'] == true) {
      final settings = (data['settings'] as Map?) ?? const {};
      setState(() {
        _walletEnabled = settings['enabled'] == true;
        _walletSignupBonus =
            double.tryParse((settings['signup_bonus'] ?? "200").toString()) ??
            200;
        _walletMinBilling =
            double.tryParse((settings['min_billing'] ?? "2000").toString()) ??
            2000;
      });
    }
  }

  Future<void> _loadGrowthConfig() async {
    final data = await _admin.getGrowthConfig();
    if (!mounted || data['ok'] != true) return;
    final settings = (data['settings'] as Map?)?.cast<String, dynamic>() ?? const {};
    final cashback = (settings['cashback'] as Map?)?.cast<String, dynamic>() ?? const {};
    final flashDeal = (settings['flash_deal'] as Map?)?.cast<String, dynamic>() ?? const {};
    final crossSell = (settings['cross_sell'] as Map?)?.cast<String, dynamic>() ?? const {};
    final productMap = (crossSell['product_map'] as Map?)?.cast<String, dynamic>() ?? const {};

    final mapLines = productMap.entries.map((entry) {
      final ids = (entry.value is List)
          ? (entry.value as List).map((e) => e.toString()).join(',')
          : entry.value.toString();
      return '${entry.key}:$ids';
    }).join('\n');

    setState(() {
      _cashbackEnabled = cashback['enabled'] == true;
      _cashbackSpendAmount =
          double.tryParse((cashback['spend_amount'] ?? '1000').toString()) ?? 1000;
      _cashbackRewardAmount =
          double.tryParse((cashback['cashback_amount'] ?? '50').toString()) ?? 50;
      _flashDealEnabled = flashDeal['enabled'] == true;
      _crossSellEnabled = crossSell['enabled'] == true;
      _cashbackSpendController.text = _cashbackSpendAmount.toStringAsFixed(0);
      _cashbackRewardController.text = _cashbackRewardAmount.toStringAsFixed(0);
      _flashDealTitleController.text =
          (flashDeal['title'] ?? 'Limited Time Offer').toString();
      _flashDealSubtitleController.text = (flashDeal['subtitle'] ?? '').toString();
      _flashDealEndsAtController.text = (flashDeal['ends_at'] ?? '').toString();
      _flashDealProductIdsController.text = ((flashDeal['product_ids'] as List?) ?? const [])
          .map((e) => e.toString())
          .join(',');
      _crossSellMaxItemsController.text =
          (crossSell['max_items'] ?? 5).toString();
      _crossSellMapController.text = mapLines;
    });
  }

  Future<void> _runBulkCart() async {
    setState(() {
      _busy = true;
      _status = '';
    });
    final data = await _admin.runBulkCart(days: _days);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (data['ok'] == true) {
        final result = (data['result'] as Map?) ?? const {};
        _status =
            'Cart campaign done. Targets: ${result['targets'] ?? 0}, Attempted: ${result['attempted'] ?? 0}, Skipped: ${result['skipped'] ?? 0}';
        _apiError = '';
      } else {
        _status = '';
        _apiError = (data['message'] ?? data['code'] ?? 'Bulk cart API failed').toString();
      }
    });
    await _loadOverview();
  }

  Future<void> _runBulkRepeatViews() async {
    setState(() {
      _busy = true;
      _status = '';
    });
    final data = await _admin.runBulkRepeatViews();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (data['ok'] == true) {
        final result = (data['result'] as Map?) ?? const {};
        _status =
            'Repeat-view campaign done. Targets: ${result['targets'] ?? 0}, Attempted: ${result['attempted'] ?? 0}, Skipped: ${result['skipped'] ?? 0}';
        _apiError = '';
      } else {
        _status = '';
        _apiError = (data['message'] ?? data['code'] ?? 'Bulk repeat API failed').toString();
      }
    });
    await _loadOverview();
  }

  Future<void> _saveWalletConfig() async {
    setState(() {
      _busy = true;
      _status = '';
    });
    final data = await _admin.setWalletConfig(
      enabled: _walletEnabled,
      signupBonus: _walletSignupBonus,
      minBilling: _walletMinBilling,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (data['ok'] == true) {
        _status = 'Wallet settings updated successfully.';
        _apiError = '';
      } else {
        _apiError =
            (data['message'] ?? data['code'] ?? 'Wallet config API failed')
                .toString();
      }
    });
    await _loadWalletConfig();
  }

  Future<void> _walletAddBalance() async {
    final actorKey = _walletActorController.text.trim();
    final userId = int.tryParse(_walletUserIdController.text.trim()) ?? 0;
    final installId = _walletInstallIdController.text.trim();
    final amount = double.tryParse(_walletAmountController.text.trim()) ?? 0;
    if ((actorKey.isEmpty && userId <= 0 && installId.isEmpty) || amount <= 0) {
      setState(() => _apiError = 'Enter actor key or user/install identity with amount.');
      return;
    }
    setState(() {
      _busy = true;
      _status = '';
    });
    final data = await _admin.creditWallet(
      actorKey: actorKey.isNotEmpty ? actorKey : null,
      userId: userId > 0 ? userId : null,
      installId: installId.isNotEmpty ? installId : null,
      amount: amount,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (data['ok'] == true) {
        _status = 'Wallet credited. New balance: ${data['balance'] ?? 0}';
        _apiError = '';
      } else {
        _apiError =
            (data['message'] ?? data['code'] ?? 'Wallet credit API failed')
                .toString();
      }
    });
  }

  Future<void> _walletSetBan(bool banned) async {
    final actorKey = _walletActorController.text.trim();
    final userId = int.tryParse(_walletUserIdController.text.trim()) ?? 0;
    final installId = _walletInstallIdController.text.trim();
    if (actorKey.isEmpty && userId <= 0 && installId.isEmpty) {
      setState(() => _apiError = 'Enter actor key or user/install identity first.');
      return;
    }
    setState(() {
      _busy = true;
      _status = '';
    });
    final data = await _admin.setWalletBan(
      actorKey: actorKey.isNotEmpty ? actorKey : null,
      userId: userId > 0 ? userId : null,
      installId: installId.isNotEmpty ? installId : null,
      banned: banned,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (data['ok'] == true) {
        _status = banned ? 'Wallet blocked.' : 'Wallet unblocked.';
        _apiError = '';
      } else {
        _apiError =
            (data['message'] ?? data['code'] ?? 'Wallet ban API failed')
                .toString();
      }
    });
  }

  List<int> _parseProductIdList(String raw) {
    return raw
        .split(',')
        .map((e) => int.tryParse(e.trim()) ?? 0)
        .where((e) => e > 0)
        .toList();
  }

  Map<String, List<int>> _parseCrossSellMap(String raw) {
    final map = <String, List<int>>{};
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || !trimmed.contains(':')) continue;
      final parts = trimmed.split(':');
      if (parts.length < 2) continue;
      final key = parts.first.trim();
      final ids = _parseProductIdList(parts.sublist(1).join(':'));
      if (key.isEmpty || ids.isEmpty) continue;
      map[key] = ids;
    }
    return map;
  }

  Future<void> _saveGrowthConfig() async {
    final cashbackSpend =
        double.tryParse(_cashbackSpendController.text.trim()) ?? 0;
    final cashbackReward =
        double.tryParse(_cashbackRewardController.text.trim()) ?? 0;
    final flashDealProductIds = _parseProductIdList(
      _flashDealProductIdsController.text,
    );
    final crossSellMaxItems =
        int.tryParse(_crossSellMaxItemsController.text.trim()) ?? 5;
    final crossSellMap = _parseCrossSellMap(_crossSellMapController.text);

    setState(() {
      _busy = true;
      _status = '';
    });
    final data = await _admin.setGrowthConfig(
      cashbackEnabled: _cashbackEnabled,
      cashbackSpendAmount: cashbackSpend,
      cashbackRewardAmount: cashbackReward,
      flashDealEnabled: _flashDealEnabled,
      flashDealTitle: _flashDealTitleController.text.trim(),
      flashDealSubtitle: _flashDealSubtitleController.text.trim(),
      flashDealEndsAt: _flashDealEndsAtController.text.trim(),
      flashDealProductIds: flashDealProductIds,
      crossSellEnabled: _crossSellEnabled,
      crossSellMaxItems: crossSellMaxItems,
      crossSellProductMap: crossSellMap,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (data['ok'] == true) {
        _status = 'Growth config updated successfully.';
        _apiError = '';
      } else {
        _apiError =
            (data['message'] ?? data['code'] ?? 'Growth config API failed')
                .toString();
      }
    });
    await _loadGrowthConfig();
  }

  Widget _metricCard(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1F2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      appBar: AppBar(
        title: const Text('Admin Control'),
        backgroundColor: const Color(0xFF1C1F2E),
        actions: [
          IconButton(onPressed: _loading || _busy ? null : _bootstrap, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const FullPageSkeleton()
          : !_allowed
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Access denied. Only authorized admin user can use this section.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (_apiError.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: Text('API Error: $_apiError', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                    Row(
                      children: [
                        _metricCard('Events Total', '${_overview['events_total'] ?? 0}'),
                        const SizedBox(width: 8),
                        _metricCard('Events 30m', '${_overview['events_30m'] ?? 0}'),
                        const SizedBox(width: 8),
                        _metricCard('Tokens', '${_overview['tokens_total'] ?? 0}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Admin Tools', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AdminUserDrilldownScreen()),
                                  );
                                },
                                icon: const Icon(Icons.person_search),
                                label: const Text('User Drilldown'),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AdminCustomPushScreen()),
                                  );
                                },
                                icon: const Icon(Icons.campaign),
                                label: const Text('Custom Push'),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AdminUserInterestScreen()),
                                  );
                                },
                                icon: const Icon(Icons.insights),
                                label: const Text('User Interest'),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AdminTopProductsAnalyticsScreen()),
                                  );
                                },
                                icon: const Icon(Icons.bar_chart),
                                label: const Text('Top Products Analytics'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Wallet Controls', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          SwitchListTile(
                            value: _walletEnabled,
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _walletEnabled = v),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Wallet Enabled', style: TextStyle(color: Colors.white)),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: _walletSignupBonus.toStringAsFixed(0),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'Install Bonus',
                                    labelStyle: TextStyle(color: Colors.white70),
                                  ),
                                  onChanged: (v) {
                                    final parsed = double.tryParse(v);
                                    if (parsed != null) {
                                      _walletSignupBonus = parsed;
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  initialValue: _walletMinBilling.toStringAsFixed(0),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'Min Billing',
                                    labelStyle: TextStyle(color: Colors.white70),
                                  ),
                                  onChanged: (v) {
                                    final parsed = double.tryParse(v);
                                    if (parsed != null) {
                                      _walletMinBilling = parsed;
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _busy ? null : _saveWalletConfig,
                            child: const Text('Save Wallet Settings'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _walletActorController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Actor Key (optional: u:123 / g:install_id)',
                              labelStyle: TextStyle(color: Colors.white70),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _walletUserIdController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'User ID (optional)',
                                    labelStyle: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _walletInstallIdController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'Install ID (optional)',
                                    labelStyle: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _walletAmountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'Amount',
                                    labelStyle: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _busy ? null : _walletAddBalance,
                                child: const Text('Add'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: _busy ? null : () => _walletSetBan(true),
                                child: const Text('Block Wallet'),
                              ),
                              OutlinedButton(
                                onPressed: _busy ? null : () => _walletSetBan(false),
                                child: const Text('Unblock Wallet'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Growth Boosters', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          SwitchListTile(
                            value: _cashbackEnabled,
                            onChanged: _busy ? null : (v) => setState(() => _cashbackEnabled = v),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Enable Cashback Rule', style: TextStyle(color: Colors.white)),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _cashbackSpendController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'Spend Amount',
                                    labelStyle: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _cashbackRewardController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'Cashback Amount',
                                    labelStyle: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            value: _flashDealEnabled,
                            onChanged: _busy ? null : (v) => setState(() => _flashDealEnabled = v),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Enable Flash Deal', style: TextStyle(color: Colors.white)),
                          ),
                          TextField(
                            controller: _flashDealTitleController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Flash Deal Title',
                              labelStyle: TextStyle(color: Colors.white70),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _flashDealSubtitleController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Flash Deal Subtitle',
                              labelStyle: TextStyle(color: Colors.white70),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _flashDealEndsAtController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Ends At (2026-03-31T23:59:59)',
                              labelStyle: TextStyle(color: Colors.white70),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _flashDealProductIdsController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Flash Deal Product IDs',
                              hintText: '101,205,330',
                              labelStyle: TextStyle(color: Colors.white70),
                              hintStyle: TextStyle(color: Colors.white38),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            value: _crossSellEnabled,
                            onChanged: _busy ? null : (v) => setState(() => _crossSellEnabled = v),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Enable Cross-sell / Upsell', style: TextStyle(color: Colors.white)),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _crossSellMaxItemsController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'Max Suggested Items',
                                    labelStyle: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _crossSellMapController,
                            maxLines: 6,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Product-wise Mapping',
                              hintText: '1001:2001,2002,2003\n1002:3001,3002',
                              labelStyle: TextStyle(color: Colors.white70),
                              hintStyle: TextStyle(color: Colors.white38),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Mapping format: current_product_id:suggested_id_1,suggested_id_2',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _busy ? null : _saveGrowthConfig,
                            child: const Text('Save Growth Settings'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Bulk Campaigns', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Text('Lookback Days', style: TextStyle(color: Colors.white70)),
                              const SizedBox(width: 10),
                              DropdownButton<int>(
                                value: _days,
                                dropdownColor: const Color(0xFF1C1F2E),
                                style: const TextStyle(color: Colors.white),
                                items: const [1, 3, 5, 7, 14, 30].map((d) => DropdownMenuItem(value: d, child: Text('$d'))).toList(),
                                onChanged: _busy
                                    ? null
                                    : (v) {
                                        if (v == null) return;
                                        setState(() => _days = v);
                                      },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton(onPressed: _busy ? null : _runBulkCart, child: const Text('Run Cart Campaign')),
                              ElevatedButton(onPressed: _busy ? null : _runBulkRepeatViews, child: const Text('Run Repeat-Views Campaign')),
                            ],
                          ),
                          if (_status.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(_status, style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Live Events', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Text('Minutes', style: TextStyle(color: Colors.white70)),
                              const SizedBox(width: 10),
                              DropdownButton<int>(
                                value: _minutes,
                                dropdownColor: const Color(0xFF1C1F2E),
                                style: const TextStyle(color: Colors.white),
                                items: const [10, 30, 60, 120, 240].map((m) => DropdownMenuItem(value: m, child: Text('$m'))).toList(),
                                onChanged: (v) async {
                                  if (v == null) return;
                                  setState(() => _minutes = v);
                                  await _loadLive();
                                },
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(onPressed: _loadLive, child: const Text('Refresh')),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_rows.isEmpty)
                            const Text('No events in selected window.', style: TextStyle(color: Colors.white70))
                          else
                            ..._rows.take(25).map((row) {
                              final map = row is Map ? row : const {};
                              final eventName = (map['event_name'] ?? '-').toString();
                              final createdAt = (map['created_at'] ?? '-').toString();
                              final userId = (map['user_id'] ?? '').toString();
                              final installId = (map['install_id'] ?? '').toString();
                              final actor = userId.isNotEmpty && userId != '0' ? 'u:$userId' : 'g:$installId';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131725),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(eventName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 2),
                                          Text('$actor | $createdAt', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                  ],
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
