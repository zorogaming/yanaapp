import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/admin_service.dart';

class AdminCustomPushScreen extends StatefulWidget {
  const AdminCustomPushScreen({super.key});

  @override
  State<AdminCustomPushScreen> createState() => _AdminCustomPushScreenState();
}

class _AdminCustomPushScreenState extends State<AdminCustomPushScreen> {
  static const String _lastCouponCodeKey = 'admin_last_campaign_coupon_code';
  final AdminService _admin = AdminService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _deepLinkController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _couponController = TextEditingController();
  final TextEditingController _actorKeysController = TextEditingController();
  final TextEditingController _productIdController = TextEditingController();
  final TextEditingController _scheduleAtController = TextEditingController();

  bool _loading = false;
  String _targetMode = 'selected';
  String _audienceFilter = 'any';
  String _scheduleMode = 'now';
  int _lookbackDays = 7;
  String _status = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadSavedCouponCode();
  }

  Future<void> _loadSavedCouponCode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = (prefs.getString(_lastCouponCodeKey) ?? '').trim().toUpperCase();
    if (!mounted || saved.isEmpty) return;
    _couponController.text = saved;
  }

  Future<void> _saveCouponCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCouponCodeKey, normalized);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _deepLinkController.dispose();
    _imageUrlController.dispose();
    _couponController.dispose();
    _actorKeysController.dispose();
    _productIdController.dispose();
    _scheduleAtController.dispose();
    super.dispose();
  }

  Future<void> _runCampaign() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final actorKeys = _actorKeysController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final productId = int.tryParse(_productIdController.text.trim()) ?? 0;
    final scheduleAt = _scheduleAtController.text.trim();
    final typedCouponCode = _couponController.text.trim().toUpperCase();
    String effectiveCouponCode = typedCouponCode;

    if (effectiveCouponCode.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      effectiveCouponCode = (prefs.getString(_lastCouponCodeKey) ?? '')
          .trim()
          .toUpperCase();
    }

    if (title.isEmpty || body.isEmpty) {
      setState(() => _error = 'Title and body required.');
      return;
    }
    if (_targetMode == 'selected' && actorKeys.isEmpty) {
      setState(() => _error = 'Selected target needs actor keys.');
      return;
    }
    if (_audienceFilter == 'product' && productId <= 0) {
      setState(() => _error = 'Product ID required for product filter.');
      return;
    }
    if (_scheduleMode == 'later' && scheduleAt.isEmpty) {
      setState(() => _error = 'Schedule date/time required.');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
      _status = '';
    });

    final data = await _admin.sendCustomCampaign(
      title: title,
      body: body,
      targetMode: _targetMode,
      actorKeys: actorKeys,
      audienceFilter: _audienceFilter,
      lookbackDays: _lookbackDays,
      productId: productId > 0 ? productId : null,
      deepLink: _deepLinkController.text.trim(),
      imageUrl: _imageUrlController.text.trim(),
      couponCode: effectiveCouponCode,
      scheduleMode: _scheduleMode,
      scheduleAt: scheduleAt,
    );

    if (!mounted) return;
    final responseCouponCode = (data['coupon_code'] ?? effectiveCouponCode)
        .toString()
        .trim()
        .toUpperCase();
    setState(() {
      _loading = false;
      if (data['ok'] == true) {
        if (responseCouponCode.isNotEmpty) {
          _couponController.text = responseCouponCode;
        }
        if (data['scheduled'] == true) {
          _status = 'Campaign scheduled at ${data['scheduled_at'] ?? '-'}';
        } else {
          final result = (data['result'] as Map?) ?? const {};
          _status = 'Campaign sent. Targets: ${result['targets'] ?? 0}, Attempted: ${result['attempted'] ?? 0}';
        }
      } else {
        _error = (data['message'] ?? data['code'] ?? 'Campaign API failed').toString();
      }
    });

    if (data['ok'] == true && responseCouponCode.isNotEmpty) {
      await _saveCouponCode(responseCouponCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      appBar: AppBar(
        title: const Text('Custom Push Campaign'),
        backgroundColor: const Color(0xFF1C1F2E),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_error.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent),
              ),
              child: Text('API Error: $_error', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
          if (_status.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.greenAccent),
              ),
              child: Text(_status, style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
            ),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Targeting', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                DropdownButton<String>(
                  value: _targetMode,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1C1F2E),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Users')),
                    DropdownMenuItem(value: 'selected', child: Text('Selected Users')),
                    DropdownMenuItem(value: 'guest_only', child: Text('Guest Only')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _targetMode = v);
                  },
                ),
                const SizedBox(height: 8),
                if (_targetMode == 'selected')
                  TextField(
                    controller: _actorKeysController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Actor keys (comma separated)',
                      hintText: 'u:23,g:guest_abc',
                      labelStyle: TextStyle(color: Colors.white70),
                      hintStyle: TextStyle(color: Colors.white38),
                      border: OutlineInputBorder(),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Audience Filter', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                DropdownButton<String>(
                  value: _audienceFilter,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1C1F2E),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'any', child: Text('Any Audience')),
                    DropdownMenuItem(value: 'cart', child: Text('Cart Users')),
                    DropdownMenuItem(value: 'product', child: Text('Viewed Product X')),
                    DropdownMenuItem(value: 'repeat_views', child: Text('3+ Repeat Views')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _audienceFilter = v);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButton<int>(
                  value: _lookbackDays,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1C1F2E),
                  style: const TextStyle(color: Colors.white),
                  items: const [1, 3, 7, 14, 30]
                      .map((d) => DropdownMenuItem(value: d, child: Text('Lookback: $d days')))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _lookbackDays = v);
                  },
                ),
                if (_audienceFilter == 'product') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _productIdController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Product ID',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Message', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                TextField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bodyController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Body',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _deepLinkController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Deep Link (optional)',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _imageUrlController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Image URL (optional)',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _couponController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Coupon Code (optional)',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Schedule', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                DropdownButton<String>(
                  value: _scheduleMode,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1C1F2E),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'now', child: Text('Send Now')),
                    DropdownMenuItem(value: 'later', child: Text('Schedule for Later')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _scheduleMode = v);
                  },
                ),
                if (_scheduleMode == 'later') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _scheduleAtController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Schedule At (YYYY-MM-DD HH:MM)',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loading ? null : _runCampaign,
            child: Text(_loading ? 'Please wait...' : 'Run Campaign'),
          ),
        ],
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
}
