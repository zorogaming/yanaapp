import 'package:flutter/material.dart';

import '../services/woo_service.dart';
import '../theme/app_theme.dart';

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
  double _minBilling = 2000;
  List<Map<String, dynamic>> _tx = const [];

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
    final data = await _api.fetchWalletOverview();
    if (!mounted) return;
    if (data == null || data["ok"] != true) {
      setState(() {
        _loading = false;
        _error = "Wallet data load nahi ho paaya.";
      });
      return;
    }
    final txRaw = (data["transactions"] as List?) ?? const [];
    setState(() {
      _loading = false;
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
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
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
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: palette.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Available Balance",
                            style: TextStyle(color: palette.textMuted),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "₹${_balance.toStringAsFixed(2)}",
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Min billing: ₹${_minBilling.toStringAsFixed(0)}",
                            style: TextStyle(color: palette.textMuted),
                          ),
                          if (_banned)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                "Wallet blocked by admin",
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Wallet History",
                      style:
                          TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (_tx.isEmpty)
                      Text(
                        "Abhi tak wallet transactions nahi hain.",
                        style: TextStyle(color: palette.textMuted),
                      )
                    else
                      ..._tx.map((tx) {
                        final amount =
                            double.tryParse((tx["amount"] ?? "0").toString()) ??
                                0;
                        final isCredit = amount >= 0;
                        final meta = (tx["meta"] as Map?) ?? const {};
                        final orderId = (meta["order_id"] ?? "").toString();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: palette.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _txTitle(tx),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "${isCredit ? "+" : ""}₹${amount.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      color: isCredit
                                          ? palette.accent
                                          : Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Balance after: ₹${(double.tryParse((tx["balance_after"] ?? "0").toString()) ?? 0).toStringAsFixed(2)}",
                                style: TextStyle(color: palette.textMuted),
                              ),
                              Text(
                                "Date: ${(tx["created_at"] ?? "-").toString()}",
                                style: TextStyle(color: palette.textMuted),
                              ),
                              if (orderId.isNotEmpty)
                                Text(
                                  "Order ID: #$orderId",
                                  style: TextStyle(color: palette.textMuted),
                                ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
    );
  }
}
