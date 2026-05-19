import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cart_provider.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart';
import '../services/notification_inbox_service.dart';
import '../services/woo_service.dart';
import '../theme/app_theme.dart';
import 'cart_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'menu_screen.dart';
import 'notification_inbox_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int currentIndex = 0;
  bool _startupReady = false;
  final AuthService _authService = AuthService();
  AppThemePalette get _palette => context.appPalette;
  static const List<String> _tabNames = [
    "home",
    "bag",
    "menu",
    "notifications",
    "orders",
    "profile",
  ];

  final List<Widget> screens = const [
    HomeScreen(),
    CartScreen(),
    MenuScreen(),
    NotificationInboxScreen(),
    OrdersScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreen("tab_home");
    NotificationInboxService.instance.refreshUnreadCount();
    _prepareStartup();
  }

  Future<void> _prepareStartup() async {
    try {
      await WooService()
          .fetchAppVersion()
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
    } catch (_) {
      // Fail-open: don't block app navigation on version check errors.
    }

    if (!mounted) return;
    setState(() {
      _startupReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;

    if (!_startupReady) {
      return Scaffold(
        backgroundColor: palette.background,
        body: Center(
          child: CircularProgressIndicator(color: palette.accent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: palette.background,
      body: IndexedStack(
        index: currentIndex,
        children: screens,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        child: Consumer<CartProvider>(
          builder: (context, cart, child) {
            return ValueListenableBuilder<int>(
              valueListenable: NotificationInboxService.instance.unreadCountNotifier,
              builder: (context, unreadCount, _) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    color: palette.accent,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.24),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildNavItem(
                        index: 0,
                        label: "Home",
                        icon: Icons.home_rounded,
                      ),
                      _buildNavItem(
                        index: 1,
                        label: "Bag",
                        icon: Icons.shopping_cart_rounded,
                        badgeCount: cart.itemCount,
                      ),
                      _buildNavItem(
                        index: 2,
                        label: "Menu",
                        icon: Icons.grid_view_rounded,
                      ),
                      _buildNavItem(
                        index: 3,
                        label: "Alerts",
                        icon: Icons.notifications_rounded,
                        badgeCount: currentIndex == 3 ? 0 : unreadCount,
                      ),
                      _buildNavItem(
                        index: 4,
                        label: "Orders",
                        icon: Icons.receipt_long_rounded,
                      ),
                      _buildNavItem(
                        index: 5,
                        label: "Profile",
                        icon: Icons.person_rounded,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    int badgeCount = 0,
  }) {
    final palette = _palette;
    final isSelected = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          if (index == 4) {
            final isLoggedIn = await _authService.isLoggedIn();
            if (!isLoggedIn) {
              if (!mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
              return;
            }
          }
          if (!mounted) return;
          setState(() => currentIndex = index);
          if (index == 3) {
            NotificationInboxService.instance.markAllRead();
          }
          AnalyticsService.instance.logScreen("tab_${_tabNames[index]}");
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.transparent,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.22),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? palette.accent : Colors.black,
                      size: 18,
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -6,
                      top: -5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        child: Text(
                          badgeCount > 99 ? "99+" : badgeCount.toString(),
                          textAlign: TextAlign.center,
                           style: TextStyle(
                             color: palette.accent,
                             fontSize: 8,
                             fontWeight: FontWeight.w700,
                           ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
