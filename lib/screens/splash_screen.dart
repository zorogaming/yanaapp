import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'main_navigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final AuthService auth = AuthService();
  static const Duration _minimumSplashDuration = Duration(seconds: 3);
  static const Duration _startupFallbackDelay = Duration(seconds: 8);

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _textSlideAnimation;
  late Animation<double> _logoFloatAnimation;
  late Animation<double> _ringSpinAnimation;
  Timer? _startupFallbackTimer;
  bool _didNavigate = false;
  late final DateTime _startedAt;
  String _appVersionLabel = "";
  AudioPlayer? _splashAudioPlayer;

  final Color ktmOrange = const Color(0xFFFF6600);
  final Color ktmBlack = const Color(0xFF000000);

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _glowAnimation = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.12, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _textSlideAnimation = Tween<double>(begin: 26, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _logoFloatAnimation = Tween<double>(begin: 18, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.82, curve: Curves.easeOutBack),
      ),
    );

    _ringSpinAnimation = Tween<double>(begin: -0.08, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
    _playSplashSound();
    _startupFallbackTimer = Timer(
      _startupFallbackDelay,
      _navigateToFallbackDestination,
    );
    _loadAppVersion();
    Future.microtask(checkLogin);
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        final version = packageInfo.version.trim();
        _appVersionLabel = version.isEmpty ? "" : "App v$version";
      });
    } catch (_) {
      // Version text is optional on splash.
    }
  }

  Future<void> _playSplashSound() async {
    try {
      final player = AudioPlayer();
      _splashAudioPlayer = player;
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(1.0);
      final bytes = await rootBundle.load('assets/Yana.mp3');
      await player.play(
        BytesSource(bytes.buffer.asUint8List()),
      );
    } catch (_) {
      // Splash audio should never block app startup.
    }
  }

  Future<void> checkLogin() async {
    try {
      await _determineDestination();
    } catch (_) {
      goToHome();
    }
  }

  Future<void> _determineDestination() async {
    final token = await auth.getToken();
    if (token == null || token.isEmpty) {
      goToHome();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final biometricEnabled = prefs.getBool("biometric_enabled") ?? false;
    if (biometricEnabled) {
      goToLogin();
      return;
    }

    goToHome();
  }

  void goToHome() {
    _navigateOnce(const MainNavigation());
  }

  void goToLogin() {
    _navigateOnce(const LoginScreen());
  }

  Future<void> _navigateToFallbackDestination() async {
    if (!mounted || _didNavigate) return;

    try {
      final token = await auth.getToken();
      if (token == null || token.isEmpty) {
        goToHome();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final biometricEnabled = prefs.getBool("biometric_enabled") ?? false;
      if (biometricEnabled) {
        goToLogin();
        return;
      }
    } catch (_) {
      // If local state read fails, do not leave the user blocked on splash.
    }

    goToHome();
  }

  Future<void> _navigateOnce(Widget screen) async {
    if (!mounted || _didNavigate) return;
    _didNavigate = true;
    _startupFallbackTimer?.cancel();

    final elapsed = DateTime.now().difference(_startedAt);
    final remaining = _minimumSplashDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  void dispose() {
    _startupFallbackTimer?.cancel();
    _controller.dispose();
    _splashAudioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ktmBlack,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.18),
                  radius: 1.0,
                  colors: [
                    ktmOrange.withOpacity(0.18),
                    const Color(0xFF12060A),
                    ktmBlack,
                  ],
                  stops: const [0.0, 0.42, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: -90,
            right: -50,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ktmOrange.withOpacity(0.10),
                ),
              ),
            ),
          ),
          Positioned(
            left: -70,
            bottom: 110,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.translate(
                    offset: Offset(0, _logoFloatAnimation.value),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 250,
                          height: 250,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 170 + (26 * _glowAnimation.value),
                                height: 170 + (26 * _glowAnimation.value),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      ktmOrange.withOpacity(0.34 * _glowAnimation.value),
                                      ktmOrange.withOpacity(0.08 * _glowAnimation.value),
                                      Colors.transparent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: ktmOrange.withOpacity(
                                        0.30 * _glowAnimation.value,
                                      ),
                                      blurRadius: 42,
                                      spreadRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              Transform.rotate(
                                angle: _ringSpinAnimation.value,
                                child: Container(
                                  width: 184,
                                  height: 184,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.09),
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                              Transform.rotate(
                                angle: -_ringSpinAnimation.value * 1.8,
                                child: Container(
                                  width: 214,
                                  height: 214,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: ktmOrange.withOpacity(0.20),
                                      width: 1.1,
                                    ),
                                  ),
                                ),
                              ),
                              Transform.scale(
                                scale: _scaleAnimation.value,
                                child: Container(
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.12),
                                    ),
                                  ),
                                  child: Image.asset(
                                    "assets/icon/icon.png",
                                    width: 118,
                                    height: 118,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(0, _textSlideAnimation.value),
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: Column(
                              children: [
                                const Text(
                                  "Welcome Rider",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 31,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.8,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "Gears up. Ride ahead.",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.70),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_appVersionLabel.isNotEmpty)
            Positioned(
              right: 16,
              bottom: 12,
              child: Text(
                _appVersionLabel,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
