import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'forgot_password_screen.dart';
import '../theme/app_theme.dart';
import 'main_navigation.dart';

// 🎨 Brand Colors
class RacingColors {
  static const Color primaryRed = Color(0xFFFF3D00);
  static const Color accentGold = Color(0xFFFFD700);
  static const Color cardBg = Color(0xFF1C1F2E);
  static const Color scaffoldBg = Color(0xFF0D0F1A);
  static const Color white = Colors.white;
  static const Color white70 = Color(0xB3FFFFFF);
  static const Color white30 = Color(0x4DFFFFFF);
  static const Color grey = Color(0xFF9E9E9E);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService auth = AuthService();
  final LocalAuthentication _localAuth = LocalAuthentication();

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool _isPasswordVisible = false;
  bool isBiometricAvailable = false;
  bool isBiometricEnabled = false;
  bool hasSavedSession = false;

  @override
  void initState() {
    super.initState();
    checkBiometric();
  }

  Future<void> checkBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await auth.getToken();
    var available = false;
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final enrolled = (await _localAuth.getAvailableBiometrics()).isNotEmpty;
      available = canCheck && isDeviceSupported && enrolled;
    } on PlatformException {
      available = false;
    } catch (_) {
      available = false;
    }

    if (!available && (prefs.getBool("biometric_enabled") ?? false)) {
      await prefs.setBool("biometric_enabled", false);
    }

    if (!mounted) return;

    setState(() {
      isBiometricAvailable = available;
      isBiometricEnabled = prefs.getBool("biometric_enabled") ?? false;
      hasSavedSession = token != null && token.isNotEmpty;
    });
  }

  Future<void> authenticateWithBiometric() async {
    if (!isBiometricAvailable || !isBiometricEnabled) {
      return;
    }
    try {
      final token = await auth.getToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No saved login session found. Please login once."),
          ),
        );
        return;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: "Authenticate to login",
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (authenticated && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigation()),
          (route) => false,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Biometric verification cancelled")),
        );
      }
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Biometric authentication not available")),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Biometric authentication failed")),
      );
    }
  }

  Future<void> login() async {
    if (usernameController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter username & password")),
      );
      return;
    }

    setState(() => isLoading = true);

    final result = await auth.login(
      usernameController.text.trim(),
      passwordController.text.trim(),
    );

    setState(() => isLoading = false);

    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await auth.syncFcmTopicForCurrentUser();

      // 🔥 Ask user before enabling biometric
      if (isBiometricAvailable &&
          !(prefs.getBool("biometric_enabled") ?? false)) {
        bool? enable = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Enable Fingerprint?"),
            content: const Text(
                "Do you want to enable fingerprint login for faster access?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("No"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Yes"),
              ),
            ],
          ),
        );

        if (enable == true) {
          try {
            final verified = await _localAuth.authenticate(
              localizedReason: "Verify to enable biometric login",
              options: const AuthenticationOptions(
                biometricOnly: true,
                stickyAuth: true,
                useErrorDialogs: true,
              ),
            );
            await prefs.setBool("biometric_enabled", verified);
            if (mounted && !verified) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Biometric verification required to enable")),
              );
            }
          } on PlatformException {
            await prefs.setBool("biometric_enabled", false);
          }
        }
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigation()),
          (route) => false,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Login Failed"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> openForgotPassword() async {
    await Navigator.pushNamed(context, ForgotPasswordScreen.routeName);
  }

  InputDecoration _buildInputDecoration(
    String label,
    IconData icon,
    AppThemePalette palette,
  ) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: palette.textMuted),
      prefixIcon: Icon(icon, color: palette.accent),
      filled: true,
      fillColor: palette.surface,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: palette.accent, width: 1.8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: palette.border),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          "Login",
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    colors: [palette.heroStart, palette.heroEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
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
                  children: [
                    Image.asset(
                      "assets/icon/icon.png",
                      width: 74,
                      height: 74,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      "Welcome back",
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Login to continue with your orders, cart and account.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: palette.surfaceStrong,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: usernameController,
                      style: TextStyle(color: palette.textPrimary),
                      cursorColor: palette.accent,
                      decoration: _buildInputDecoration(
                        "Username / Email",
                        Icons.person_outline,
                        palette,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: passwordController,
                      style: TextStyle(color: palette.textPrimary),
                      cursorColor: palette.accent,
                      obscureText: !_isPasswordVisible,
                      decoration: _buildInputDecoration(
                        "Password",
                        Icons.lock_outline,
                        palette,
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: palette.textMuted,
                          ),
                          onPressed: () {
                            setState(
                              () => _isPasswordVisible = !_isPasswordVisible,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: openForgotPassword,
                        child: Text(
                          "Forgot Password?",
                          style: TextStyle(
                            color: palette.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.accent,
                        foregroundColor: palette.onAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                      onPressed: isLoading ? null : login,
                      child: isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: palette.onAccent,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Log In",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              if (isBiometricAvailable && isBiometricEnabled && hasSavedSession)
                Column(
                  children: [
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: palette.border),
                      ),
                      child: Column(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.fingerprint_rounded,
                              size: 48,
                              color: palette.accent,
                            ),
                            onPressed: authenticateWithBiometric,
                          ),
                          Text(
                            "Login with Fingerprint",
                            style: TextStyle(color: palette.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Back",
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
