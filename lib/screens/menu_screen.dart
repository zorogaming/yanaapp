import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'ai_brain_screen.dart';
import 'bike_garage_screen.dart';
import 'motorcycle_service_station_screen.dart';
import 'policy_pages_screen.dart';
import 'ride_community_screen.dart';
import 'riding_groups_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadAdminState();
  }

  Future<void> _loadAdminState() async {
    final isAdmin = await AuthService().isPrivilegedAdmin();
    if (!mounted) return;
    setState(() {
      _isAdmin = isAdmin;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          "Main Menu",
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: palette.textPrimary),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [palette.heroStart, palette.heroEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: palette.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Explore more",
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Tools, riding community, support and policy pages in one place.",
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildSectionCard(
            context,
            title: "Quick Access",
            children: [
              _buildActionTile(
                icon: Icons.palette_outlined,
                title: "App Theme",
                subtitle:
                    "Switch theme anytime, even without login.",
                onTap: _showThemePicker,
              ),
              _buildDivider(palette),
              _buildTile(
                icon: Icons.psychology_alt_rounded,
                title: "AI Brain",
                screen: const AIBrainScreen(),
              ),
              _buildDivider(palette),
              _buildTile(
                icon: Icons.groups_rounded,
                title: "Riding Groups",
                screen: const RidingGroupsScreen(),
              ),
              _buildDivider(palette),
              _buildTile(
                icon: Icons.route_rounded,
                title: "Riding Events",
                screen: const RideCommunityScreen(),
              ),
              _buildDivider(palette),
              _buildTile(
                icon: Icons.two_wheeler_outlined,
                title: "Bike Garage",
                screen: const BikeGarageScreen(),
              ),
              if (_isAdmin) ...[
                _buildDivider(palette),
                _buildTile(
                  icon: Icons.admin_panel_settings_rounded,
                  title: "Admin Service Bookings",
                  screen: const MotorcycleServiceAdminScreen(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            context,
            title: "Support & Policies",
            children: [
              _buildTile(
                icon: Icons.phone_in_talk_outlined,
                title: "Contact Us",
                screen: const ContactUsPage(),
              ),
              _buildDivider(palette),
              _buildTile(
                icon: Icons.privacy_tip_outlined,
                title: "Privacy Policy",
                screen: const PrivacyPolicyPage(),
              ),
              _buildDivider(palette),
              _buildTile(
                icon: Icons.gavel_outlined,
                title: "Terms & Conditions",
                screen: const TermsAndConditionsPage(),
              ),
              _buildDivider(palette),
              _buildTile(
                icon: Icons.receipt_long_outlined,
                title: "Refunds & Cancellations",
                screen: const RefundsAndCancellationsPage(),
              ),
              _buildDivider(palette),
              _buildTile(
                icon: Icons.assignment_return_outlined,
                title: "Return Policy",
                screen: const ReturnPolicyPage(),
              ),
              _buildDivider(palette),
              _buildTile(
                icon: Icons.local_shipping_outlined,
                title: "Shipping Policy",
                screen: const ShippingPolicyPage(),
              ),
              _buildDivider(palette),
              _buildTile(
                icon: Icons.schedule_outlined,
                title: "Delivery Timeline",
                screen: const DeliveryTimelinePage(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final palette = context.appPalette;
    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceStrong,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Text(
              title,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDivider(AppThemePalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Divider(height: 1, color: palette.border),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required Widget screen,
  }) {
    return _buildActionTile(
      icon: icon,
      title: title,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        );
      },
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final palette = context.appPalette;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
        ),
        child: Icon(icon, color: palette.accent, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 14.5,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 12,
              ),
            ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 22,
        color: palette.accent,
      ),
      onTap: onTap,
    );
  }

  Future<void> _showThemePicker() async {
    final themeController = context.read<AppThemeController>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final palette = Theme.of(sheetContext).extension<AppThemePalette>() ??
            AppThemes.midnightPalette;
        final screenHeight = MediaQuery.of(sheetContext).size.height;

        return SafeArea(
          child: SizedBox(
            height: screenHeight * 0.78,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Choose Theme',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Aap bina login ke bhi theme change kar sakte ho.',
                    style: TextStyle(color: palette.textMuted),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: AppThemes.allModes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, index) {
                        final mode = AppThemes.allModes[index];
                        return _buildThemeOptionTile(
                          mode: mode,
                          controller: themeController,
                          sheetContext: sheetContext,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeOptionTile({
    required AppThemeMode mode,
    required AppThemeController controller,
    BuildContext? sheetContext,
  }) {
    final optionPalette = AppThemes.paletteFor(mode);
    final isSelected = controller.mode == mode;

    return InkWell(
      onTap: () async {
        final navigator = Navigator.of(sheetContext ?? context);
        navigator.pop();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (!mounted) return;
        await controller.setTheme(mode);
      },
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [optionPalette.heroStart, optionPalette.heroEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? optionPalette.accent : optionPalette.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    optionPalette.label,
                    style: TextStyle(
                      color: optionPalette.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _themeDescription(mode),
                    style: TextStyle(
                      color: optionPalette.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildColorDot(optionPalette.accent),
                      _buildColorDot(optionPalette.highlight),
                      _buildColorDot(optionPalette.surface),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isSelected
                    ? optionPalette.accent
                    : optionPalette.surface.withOpacity(0.72),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSelected
                    ? Icons.check_rounded
                    : Icons.arrow_forward_rounded,
                color: isSelected
                    ? optionPalette.onAccent
                    : optionPalette.textPrimary,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _themeDescription(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.midnight:
        return 'Dark premium storefront look';
      case AppThemeMode.cherryRed:
        return 'Dark storefront with cherry red accents';
      case AppThemeMode.cherryBlue:
        return 'Dark storefront with blue accents';
      case AppThemeMode.facebookBlue:
        return 'Deep social blue storefront with bold premium contrast';
      case AppThemeMode.cherryGreen:
        return 'Dark storefront with green accents';
      case AppThemeMode.cherryYellow:
        return 'Dark storefront with yellow accents';
      case AppThemeMode.cherryPink:
        return 'Dark storefront with pink accents';
      case AppThemeMode.blushRed:
        return 'Light storefront with soft red accents';
      case AppThemeMode.skyBlue:
        return 'Light storefront with airy blue accents';
      case AppThemeMode.mintGreen:
        return 'Light storefront with fresh green accents';
      case AppThemeMode.rosePink:
        return 'Light storefront with rose pink accents';
      case AppThemeMode.white:
        return 'Clean light storefront with soft warm accents';
    }
  }

  Widget _buildColorDot(Color color) {
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
