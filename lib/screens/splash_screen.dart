import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
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
  late Animation<double> _exitOverlayScaleAnimation;
  late Animation<double> _exitOverlayOpacityAnimation;
  late Animation<double> _taglineOpacityAnimation;
  late Animation<double> _taglineSlideAnimation;
  Timer? _startupFallbackTimer;
  bool _didNavigate = false;
  late final DateTime _startedAt;
  AudioPlayer? _splashAudioPlayer;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();

    _controller = AnimationController(
      vsync: this,
      duration: _minimumSplashDuration,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.72, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 42,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.12, end: 0.96)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 24,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.96, end: 2.15)
            .chain(CurveTween(curve: Curves.easeInExpo)),
        weight: 24,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(2.15),
        weight: 10,
      ),
    ]).animate(_controller);

    _exitOverlayScaleAnimation = Tween<double>(begin: 0.0, end: 18.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.76, 1.0, curve: Curves.easeInExpo),
      ),
    );

    _exitOverlayOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.82, 1.0, curve: Curves.easeIn),
      ),
    );

    _taglineOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 28,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 56,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 16,
      ),
    ]).animate(_controller);

    _taglineSlideAnimation = Tween<double>(begin: 18.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.12, 0.48, curve: Curves.easeOutCubic),
      ),
    );

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 94,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 6,
      ),
    ]).animate(_controller);

    _controller.forward();
    _playSplashSound();
    _startupFallbackTimer = Timer(
      _startupFallbackDelay,
      _navigateToFallbackDestination,
    );
    Future.microtask(checkLogin);
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
    const splashBackground = Colors.black;
    final splashTextColor = Colors.white.withOpacity(0.82);

    return Scaffold(
      backgroundColor: splashBackground,
      body: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: SizedBox(
              width: 240,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: Center(
                      child: Image.asset(
                        "assets/icon/icon.png",
                        width: 180,
                        height: 180,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return Opacity(
                        opacity: _taglineOpacityAnimation.value,
                        child: Transform.translate(
                          offset: Offset(0, _taglineSlideAnimation.value),
                          child: SizedBox(
                            width: double.infinity,
                            child: Text(
                              "Gears up. Ride ahead.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: splashTextColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Opacity(
                opacity: _exitOverlayOpacityAnimation.value,
                child: Transform.scale(
                  scale: _exitOverlayScaleAnimation.value,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: splashBackground,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
