import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart';
import '../services/data_manager.dart';
import '../services/notification_inbox_service.dart';
import '../services/woo_service.dart';
import '../services/whatsapp_community_popup_service.dart';
import '../theme/app_theme.dart';
import '../widgets/whatsapp_community_popup.dart';
import '../widgets/yana_products_loading_screen.dart';
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
  bool _startupProductsReady = false;
  bool _startupImagesReady = false;
  bool _communityPopupShown = false;
  Timer? _communityPopupTimer;
  final AuthService _authService = AuthService();
  final ValueNotifier<int> _homeRecentlyViewedRefresh = ValueNotifier<int>(0);
  late final List<Widget> screens;
  AppThemePalette get _palette => context.appPalette;
  Uri _whatsappCommunityUri = Uri.parse(
    WhatsAppCommunityPopupService.defaultInviteUrl,
  );
  static const List<String> _tabNames = [
    "home",
    "bag",
    "menu",
    "notifications",
    "orders",
    "profile",
  ];

  @override
  void initState() {
    super.initState();
    screens = [
      HomeScreen(recentlyViewedRefresh: _homeRecentlyViewedRefresh),
      CartScreen(
        onContinueShopping: () {
          setState(() => currentIndex = 0);
        },
      ),
      const MenuScreen(),
      const NotificationInboxScreen(),
      const OrdersScreen(),
      const ProfileScreen(),
    ];
    AnalyticsService.instance.logScreen("tab_home");
    NotificationInboxService.instance.refreshUnreadCount();
    _prepareStartup();
  }

  @override
  void dispose() {
    _communityPopupTimer?.cancel();
    _homeRecentlyViewedRefresh.dispose();
    super.dispose();
  }

  Future<void> _prepareStartup() async {
    final minimumLoaderTime = Future<void>.delayed(
      const Duration(milliseconds: 850),
    );
    final versionLoad = WooService().fetchAppVersion().timeout(
      const Duration(seconds: 4),
    );

    try {
      final rawProducts = await DataManager().getHomeProducts().timeout(
        const Duration(seconds: 10),
        onTimeout: () => <dynamic>[],
      );
      if (!mounted) return;
      setState(() => _startupProductsReady = true);

      final imageUrls = <String>[];
      for (final raw in rawProducts) {
        if (raw is! Map) continue;
        try {
          final imageUrl = Product.fromJson(
            Map<String, dynamic>.from(raw),
          ).image.trim();
          if (imageUrl.toLowerCase().startsWith('http')) {
            imageUrls.add(imageUrl);
          }
        } catch (_) {}
        if (imageUrls.length == 4) break;
      }

      if (imageUrls.isNotEmpty && mounted) {
        await Future.wait<void>(
          imageUrls.map((url) async {
            try {
              await precacheImage(
                CachedNetworkImageProvider(url),
                context,
                onError: (_, __) {},
              );
            } catch (_) {}
          }),
        ).timeout(const Duration(seconds: 7), onTimeout: () => <void>[]);
      }
      if (!mounted) return;
      setState(() => _startupImagesReady = true);
    } catch (_) {
      // Continue into the app if the server or image cache is unavailable.
      if (mounted) {
        setState(() {
          _startupProductsReady = true;
          _startupImagesReady = true;
        });
      }
    }

    await minimumLoaderTime;
    try {
      await versionLoad;
    } catch (_) {
      // App startup should not depend on the version endpoint.
    }
    if (!mounted) return;
    setState(() {
      _startupReady = true;
    });
    _scheduleCommunityPopup();
  }

  void _scheduleCommunityPopup() {
    if (_communityPopupShown || _communityPopupTimer != null) return;
    _communityPopupTimer = Timer(const Duration(seconds: 16), () async {
      final shouldShow = await _loadCommunityPopupConfig();
      if (shouldShow) {
        await _showCommunityPopup();
      }
    });
  }

  Future<bool> _loadCommunityPopupConfig() async {
    try {
      final config = await WhatsAppCommunityPopupService.instance.getConfig();
      _whatsappCommunityUri = Uri.parse(config.inviteUrl);
      return config.enabled;
    } catch (_) {
      return true;
    }
  }

  Future<void> _showCommunityPopup() async {
    if (!mounted || _communityPopupShown) return;
    _communityPopupShown = true;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.62),
      builder: (dialogContext) {
        return WhatsappCommunityPopup(
          onJoinNow: () async {
            Navigator.of(dialogContext).pop();
            await launchUrl(
              _whatsappCommunityUri,
              mode: LaunchMode.externalApplication,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;

    if (!_startupReady) {
      return YanaProductsLoadingScreen(
        dataReady: _startupProductsReady,
        imagesReady: _startupImagesReady,
        accent: palette.accent,
      );
    }

    return Scaffold(
      backgroundColor: palette.background,
      body: IndexedStack(index: currentIndex, children: screens),
      bottomNavigationBar: Container(
        width: double.infinity,
        color: palette.background,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 5, 16, 6),
          child: Consumer<CartProvider>(
            builder: (context, cart, child) {
              return ValueListenableBuilder<int>(
                valueListenable:
                    NotificationInboxService.instance.unreadCountNotifier,
                builder: (context, unreadCount, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF080A08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF343A35)),
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
          if (index == 0) {
            _homeRecentlyViewedRefresh.value++;
          }
          setState(() => currentIndex = index);
          if (index == 3) {
            NotificationInboxService.instance.markAllRead();
          }
          AnalyticsService.instance.logScreen("tab_${_tabNames[index]}");
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected ? palette.accent : Colors.transparent,
                      shape: BoxShape.circle,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: palette.accent.withOpacity(0.16),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      icon,
                      color: isSelected
                          ? palette.onAccent
                          : const Color(0xFFB8B8B8),
                      size: 19,
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -8,
                      top: -5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: palette.accent,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(10),
                          ),
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        child: Text(
                          badgeCount > 99 ? "99+" : badgeCount.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.onAccent,
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
                  color: isSelected ? palette.accent : const Color(0xFFC2C2C2),
                  fontSize: 9.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
