import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/account_service.dart';
import '../theme/app_theme.dart';
import '../widgets/skeletons.dart';
import 'account_details_screen.dart';
import 'address_screen.dart';
import 'admin_control_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_home_popup_screen.dart';
import 'admin_update_notification_screen.dart';
import 'admin_user_credits_screen.dart';
import 'bike_garage_screen.dart';
import 'bug_report_screen.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';
import 'main_navigation.dart';
import 'orders_screen.dart';
import 'signup_screen.dart';
import 'wishlist_screen.dart';

class RacingColors {
  static const Color primaryRed = Color(0xFFFF3D00);
  static const Color cardBg = Color(0xFF1C1F2E);
  static const Color scaffoldBg = Color(0xFF0D0F1A);
  static const Color white = Colors.white;
  static const Color white70 = Color(0xB3FFFFFF);
  static const Color grey = Color(0xFF9E9E9E);
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final AccountService _accountService = AccountService();

  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isLoggedIn = false;
  int? customerId;
  bool biometricEnabled = false;
  bool biometricAvailable = false;
  bool canAccessAdmin = false;
  String _addressPreview = "No address added";

  @override
  void initState() {
    super.initState();
    checkLogin();
    loadBiometricSettings();
  }

  Future<void> loadBiometricSettings() async {
    final prefs = await SharedPreferences.getInstance();
    var available = false;
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      final enrolled = (await _localAuth.getAvailableBiometrics()).isNotEmpty;
      available = canCheck && isSupported && enrolled;
    } on PlatformException {
      available = false;
    } catch (_) {
      available = false;
    }

    if (!available && (prefs.getBool('biometric_enabled') ?? false)) {
      await prefs.setBool('biometric_enabled', false);
    }

    if (!mounted) return;
    setState(() {
      biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      biometricAvailable = available;
    });
  }

  Future<void> checkLogin() async {
    final loggedIn = await AuthService().isLoggedIn();

    if (!loggedIn) {
      if (!mounted) return;
      setState(() {
        isLoggedIn = false;
        isLoading = false;
      });
      return;
    }

    if (!mounted) return;
    final isPrivileged = await AuthService().isPrivilegedAdmin();
    if (!mounted) return;
    setState(() {
      isLoggedIn = true;
      canAccessAdmin = isPrivileged;
    });
    await loadProfile();
  }

  Future<void> loadProfile() async {
    final token = await AuthService().getToken();

    final response = await http.get(
      Uri.parse('https://yanaworldwide.store/wp-json/wp/v2/users/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final isPrivileged = await AuthService().isPrivilegedAdmin();
      String addressPreview = "No address added";
      final customer = await _accountService.fetchCustomer();
      final billing = (customer["billing"] as Map<String, dynamic>?) ?? {};
      final parts = <String>[
        (billing["address_1"] ?? "").toString().trim(),
        (billing["city"] ?? "").toString().trim(),
        (billing["state"] ?? "").toString().trim(),
        (billing["postcode"] ?? "").toString().trim(),
      ].where((e) => e.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        addressPreview = parts.join(", ");
      }

      setState(() {
        userData = data;
        customerId = data['id'];
        _addressPreview = addressPreview;
        canAccessAdmin = isPrivileged;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value && !biometricAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometric is not available on this device'),
        ),
      );
      return;
    }

    if (value) {
      bool authenticated = false;
      try {
        authenticated = await _localAuth.authenticate(
          localizedReason: 'Confirm to enable fingerprint login',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
            useErrorDialogs: true,
          ),
        );
      } on PlatformException {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric is not available on this device'),
          ),
        );
        return;
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric authentication failed')),
        );
        return;
      }

      if (!authenticated) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fingerprint verification failed')),
        );
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', value);

    if (!mounted) return;
    setState(() {
      biometricEnabled = value;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value ? 'Fingerprint Enabled' : 'Fingerprint Disabled'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('My Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: isLoading
          ? const FullPageSkeleton()
          : isLoggedIn
          ? _buildProfileContent()
          : _buildLoginSignupOptions(),
    );
  }

  Widget _buildLoginSignupOptions() {
    final palette = context.appPalette;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(24),
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
                color: palette.textPrimary.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: palette.isLight ? const Color(0xFF121212) : palette.surface,
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.all(14),
                child: Image.asset(
                  "assets/icon/icon.png",
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome Back!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Login ya signup karke orders, address aur preferences manage karo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: palette.textMuted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        ).then((_) => checkLogin());
                      },
                      child: const Text('LOGIN'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SignupScreen()),
                        );
                      },
                      child: const Text('SIGNUP'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent() {
    final palette = context.appPalette;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _buildProfileHero(),
        const SizedBox(height: 18),
        _buildSectionLabel('Account'),
        _buildMenuTile(
          Icons.shopping_bag_outlined,
          'Orders',
          const OrdersScreen(),
          subtitle: 'Track your purchases and reorder faster',
        ),
        _buildMenuTile(
          Icons.favorite_border_rounded,
          'Wishlist',
          const WishlistScreen(),
          subtitle: 'Your saved products in one place',
        ),
        _buildMenuTile(
          Icons.location_on_outlined,
          'Addresses',
          const AddressScreen(),
          subtitle: _addressPreview,
        ),
        _buildMenuTile(
          Icons.person_outline,
          'Account Details',
          AccountDetailsScreen(customerId: customerId ?? 0),
          subtitle: 'Manage your name, email and profile details',
        ),
        _buildMenuTile(
          Icons.lock_outline,
          'Change Password',
          const ChangePasswordScreen(),
          subtitle: 'Change password directly inside the app',
        ),
        const SizedBox(height: 18),
        _buildSectionLabel('Preferences'),
        _buildThemePreferenceCard(),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: palette.border),
          ),
          child: SwitchListTile(
            activeColor: palette.accent,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(
              'Enable Fingerprint Login',
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              biometricAvailable
                  ? 'Use biometric at app launch/login'
                  : 'Biometric not available on this device',
              style: TextStyle(color: palette.textMuted, fontSize: 12),
            ),
            value: biometricEnabled,
            onChanged: _toggleBiometric,
          ),
        ),
        const SizedBox(height: 18),
        _buildSectionLabel('Support'),
        _buildMenuTile(
          Icons.two_wheeler_outlined,
          'Bike Garage',
          const BikeGarageScreen(),
          subtitle: 'Add your bike for personalized suggestions',
        ),
        _buildMenuTile(
          Icons.bug_report_outlined,
          'Report a Bug',
          const BugReportScreen(),
          subtitle: 'Share issue details with screenshot',
        ),
        if (canAccessAdmin) ...[
          const SizedBox(height: 18),
          _buildSectionLabel('Admin Tools'),
          _buildMenuTile(
            Icons.dashboard_customize_outlined,
            'Admin Dashboard',
            const AdminDashboardScreen(),
            subtitle: 'Live admin overview and quick actions',
          ),
          _buildMenuTile(
            Icons.admin_panel_settings_outlined,
            'Admin Control',
            const AdminControlScreen(),
            subtitle: 'Authorized admin access',
          ),
          _buildMenuTile(
            Icons.notifications_active_outlined,
            'Home Popup',
            const AdminHomePopupScreen(),
            subtitle: 'Home screen dismissible popup trigger karo',
          ),
          _buildMenuTile(
            Icons.system_update_alt_outlined,
            'Update for Customers',
            const AdminUpdateNotificationScreen(),
            subtitle: 'Customer app update ko yahin se control karo',
          ),
          _buildMenuTile(
            Icons.account_balance_wallet_outlined,
            'User Credits',
            const AdminUserCreditsScreen(),
            subtitle: 'Admin-only wallet credits watch',
          ),
        ],
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            await AuthService().logout();

            if (!mounted) return;
            setState(() {
              isLoggedIn = false;
              userData = null;
              canAccessAdmin = false;
            });

            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MainNavigation()),
              (route) => false,
            );
          },
          icon: Icon(Icons.logout_rounded, color: palette.accent),
          label: Text(
            'Logout',
            style: TextStyle(
              color: palette.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            side: BorderSide(color: palette.accent.withOpacity(0.25)),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHero() {
    final palette = context.appPalette;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette.heroStart, palette.heroEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.textPrimary.withOpacity(0.08),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: palette.isLight ? const Color(0xFF121212) : palette.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(12),
            child: Image.asset("assets/icon/icon.png", fit: BoxFit.contain),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${userData?['name'] ?? 'User'}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${userData?['email'] ?? ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.textMuted,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildInfoChip(Icons.local_shipping_outlined, 'Orders'),
                    _buildInfoChip(Icons.palette_outlined, 'Themes'),
                    if (canAccessAdmin)
                      _buildInfoChip(
                        Icons.admin_panel_settings_outlined,
                        'Admin',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    final palette = context.appPalette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(0.65),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: palette.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    final palette = context.appPalette;

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        label,
        style: TextStyle(
          color: palette.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildThemePreferenceCard() {
    final palette = context.appPalette;
    final themeController = context.watch<AppThemeController>();

    return InkWell(
      onTap: _showThemePicker,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: palette.surfaceStrong,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.palette_outlined, color: palette.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Theme',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Current: ${themeController.currentThemeLabel}',
                    style: TextStyle(color: palette.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: palette.textMuted,
            ),
          ],
        ),
      ),
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
                    'Aap kabhi bhi theme switch kar sakte ho. Existing logic same rahega.',
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
                isSelected ? Icons.check_rounded : Icons.arrow_forward_rounded,
                color: isSelected ? optionPalette.onAccent : optionPalette.textPrimary,
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

  Widget _buildMenuTile(
    IconData icon,
    String title,
    Widget screen, {
    String? subtitle,
  }) {
    final palette = context.appPalette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => screen),
          ).then((_) => loadProfile());
        },
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: palette.surfaceStrong,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: palette.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: palette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
