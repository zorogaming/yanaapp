import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/woo_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WooService _api = WooService();
  bool _loading = true;
  String _error = "";
  double _balance = 0;
  bool _banned = false;
  bool _loggedIn = false;
  double _minBilling = 2000;
  List<Map<String, dynamic>> _tx = const [];

  static const Color _green = Color(0xFF168A3A);
  static const Color _red = Color(0xFFD32F2F);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = "";
    });

    final userId = (await AuthService().getUserId() ?? '').trim();
    final data = await _api.fetchWalletOverview();
    if (!mounted) return;

    if (data == null || data["ok"] != true) {
      setState(() {
        _loading = false;
        _error = "Wallet data could not be loaded.";
      });
      return;
    }

    final txRaw = (data["transactions"] as List?) ?? const [];
    setState(() {
      _loading = false;
      _loggedIn = userId.isNotEmpty;
      _balance = double.tryParse((data["balance"] ?? "0").toString()) ?? 0;
      _banned = data["banned"] == true;
      _minBilling =
          double.tryParse((data["min_billing"] ?? "2000").toString()) ?? 2000;
      _tx = txRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    });
  }

  String _txTitle(Map<String, dynamic> tx) {
    final source = (tx["source"] ?? "").toString();
    if (source == "install_bonus") return "Install Bonus";
    if (source == "signup_bonus") return "Welcome Bonus";
    if (source == "admin_credit") return "Admin Credit";
    if (source == "wallet_usage") return "Wallet Used in Order";
    return source.isEmpty ? "Wallet Update" : source.replaceAll("_", " ");
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text("My Wallet"),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: palette.accent))
          : _error.isNotEmpty
              ? Center(
                  child: Text(
                    _error,
                    style: TextStyle(color: palette.textPrimary),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                  children: [
                    _balanceCard(palette),
                    if (!_loggedIn) ...[
                      const SizedBox(height: 12),
                      _loginBonusCard(palette),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      "Wallet History",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_tx.isEmpty)
                      Text(
                        "No wallet transactions yet.",
                        style: TextStyle(color: palette.textMuted),
                      )
                    else
                      ..._tx.map((tx) => _transactionTile(tx, palette)),
                  ],
                ),
    );
  }

  Widget _loginBonusCard(AppThemePalette palette) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.accent.withOpacity(0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Log in and get ₹200 in your wallet!',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'New customers receive a one-time ₹200 welcome bonus after logging in.',
            style: TextStyle(color: palette.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
                if (mounted) await _load();
              },
              child: const Text('Log In & Get ₹200'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceCard(AppThemePalette palette) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(palette.isLight ? 0.05 : 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: palette.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Available Balance",
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "\u20B9${_balance.toStringAsFixed(2)}",
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: palette.surfaceStrong,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: palette.border),
            ),
            child: Text(
              "Minimum billing: \u20B9${_minBilling.toStringAsFixed(0)}",
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (_banned)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                "Wallet blocked by admin",
                style: TextStyle(color: _red, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _transactionTile(Map<String, dynamic> tx, AppThemePalette palette) {
    final amount = double.tryParse((tx["amount"] ?? "0").toString()) ?? 0;
    final isCredit = amount >= 0;
    final meta = (tx["meta"] as Map?) ?? const {};
    final orderId = (meta["order_id"] ?? "").toString();
    final balanceAfter =
        double.tryParse((tx["balance_after"] ?? "0").toString()) ?? 0;
    final amountColor = isCredit ? _green : _red;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: amountColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              isCredit ? Icons.add_rounded : Icons.remove_rounded,
              color: amountColor,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _txTitle(tx),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: palette.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      "${isCredit ? "+" : ""}\u20B9${amount.toStringAsFixed(2)}",
                      style: TextStyle(
                        color: amountColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  "Balance after: \u20B9${balanceAfter.toStringAsFixed(2)}",
                  style: TextStyle(color: palette.textMuted, fontSize: 11),
                ),
                Text(
                  "Date: ${(tx["created_at"] ?? "-").toString()}",
                  style: TextStyle(color: palette.textMuted, fontSize: 11),
                ),
                if (orderId.isNotEmpty)
                  Text(
                    "Order ID: #$orderId",
                    style: TextStyle(color: palette.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
