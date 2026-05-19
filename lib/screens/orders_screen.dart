import 'package:flutter/material.dart';

import '../services/account_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/skeletons.dart';
import 'login_screen.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final AuthService _authService = AuthService();
  List orders = [];
  bool isLoading = true;
  bool _requiresLogin = false;
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    loadOrders();
  }

  Future<void> loadOrders() async {
    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (!isLoggedIn) {
        if (!mounted) return;
        setState(() {
          _requiresLogin = true;
          orders = [];
          isLoading = false;
        });
        return;
      }

      final data = await AccountService().fetchOrders();
      if (!mounted) return;

      setState(() {
        _requiresLogin = false;
        orders = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      debugPrint("Order Load Error: $e");
    }
  }

  bool _isCompletedOrder(dynamic rawOrder) {
    final status = (rawOrder["status"] ?? "").toString().trim().toLowerCase();
    return status == "completed";
  }

  List get _ongoingOrders => orders.where((order) => !_isCompletedOrder(order)).toList();

  List get _completedOrders => orders.where((order) => _isCompletedOrder(order)).toList();

  Color _statusColor(AppThemePalette palette, String status) {
    switch (status.trim().toLowerCase()) {
      case "completed":
        return const Color(0xFF22C55E);
      case "processing":
        return palette.highlight;
      case "pending":
      case "on-hold":
        return palette.accent;
      case "cancelled":
      case "failed":
        return const Color(0xFFEF4444);
      default:
        return palette.textMuted;
    }
  }

  String _statusLabel(String status) {
    final normalized = status.trim().toLowerCase();
    switch (normalized) {
      case "on-hold":
        return "On Hold";
      default:
        if (normalized.isEmpty) return "Unknown";
        return normalized[0].toUpperCase() + normalized.substring(1);
    }
  }

  Future<void> _openLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (!mounted) return;
    setState(() => isLoading = true);
    await loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final visibleOrders = _showCompleted ? _completedOrders : _ongoingOrders;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "My Orders",
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.notifications_none_rounded,
              color: palette.textPrimary,
            ),
          ),
        ],
      ),
      body: isLoading
          ? const FullPageSkeleton()
          : _requiresLogin
              ? _buildLoginState(palette)
              : RefreshIndicator(
                  onRefresh: loadOrders,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 26),
                    children: [
                      _buildSegmentedToggle(palette),
                      const SizedBox(height: 22),
                      if (visibleOrders.isEmpty)
                        _buildEmptyState(palette)
                      else
                        ...visibleOrders.map(
                          (order) => _buildOrderCard(
                            palette,
                            Map<String, dynamic>.from(order),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildLoginState(AppThemePalette palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 52,
              color: palette.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              "Login required to view your orders",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Sign in to see your ongoing and completed orders.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: palette.onAccent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _openLogin,
              child: const Text("Login"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedToggle(AppThemePalette palette) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: palette.surfaceStrong,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSegmentButton(
              palette: palette,
              label: "Ongoing",
              selected: !_showCompleted,
              onTap: () => setState(() => _showCompleted = false),
            ),
          ),
          Expanded(
            child: _buildSegmentButton(
              palette: palette,
              label: "Completed",
              selected: _showCompleted,
              onTap: () => setState(() => _showCompleted = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required AppThemePalette palette,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? palette.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? palette.textPrimary : palette.textMuted,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppThemePalette palette) {
    final title = _showCompleted ? "No Completed Orders!" : "No Ongoing Orders!";
    final subtitle = _showCompleted
        ? "You don't have any completed orders yet."
        : "You don't have any ongoing orders at this time.";

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.55,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.surfaceStrong,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 40,
                color: palette.textMuted.withOpacity(0.75),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(AppThemePalette palette, Map<String, dynamic> order) {
    final status = (order["status"] ?? "").toString();
    final total = (order["total"] ?? "").toString();
    final createdAt = (order["date_created"] ?? "").toString();
    final dateLabel = createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;
    final statusColor = _statusColor(palette, status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Order #${order["id"]}",
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                "Total",
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                "₹$total",
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: palette.onAccent,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(order: order),
                      ),
                    );
                  },
                  child: const Text("View Details"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
