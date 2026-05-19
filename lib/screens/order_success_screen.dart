import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import '../theme/app_theme.dart';

class OrderSuccessScreen extends StatefulWidget {
  final int orderId;

  const OrderSuccessScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen> {
  AudioPlayer? _audioPlayer;

  @override
  void initState() {
    super.initState();
    _playSuccessSound();
  }

  Future<void> _playSuccessSound() async {
    try {
      final player = AudioPlayer();
      _audioPlayer = player;
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(1.0);
      final bytes = await rootBundle.load('assets/ordersound.mp3');
      await player.play(
        BytesSource(bytes.buffer.asUint8List()),
      );
    } catch (_) {
      // Ignore audio errors so order success UI still opens instantly.
    }
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final isLight = palette.isLight;
    final successColor = palette.success;
    final panelColor = isLight ? const Color(0xFF0F0624) : palette.surface;
    final panelTextColor = Colors.white;
    final secondaryTextColor = Colors.white.withOpacity(0.78);

    return Scaffold(
      backgroundColor: palette.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              palette.background,
              Color.lerp(palette.background, palette.surfaceSoft, 0.55) ??
                  palette.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Success',
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: panelColor,
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isLight ? 0.14 : 0.28),
                          blurRadius: 28,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                        child: Padding(
                      padding: const EdgeInsets.fromLTRB(26, 24, 26, 18),
                      child: Column(
                        children: [
                          const Spacer(),
                          _SuccessArt(
                            accentColor: successColor,
                            iconColor: panelTextColor,
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Order Placed',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: successColor,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Your order has been placed successfully and is now being prepared.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 14,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                              ),
                            ),
                            child: Text(
                              'Order ID: #${widget.orderId}',
                              style: TextStyle(
                                color: panelTextColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.popUntil(
                                  context,
                                  (route) => route.isFirst,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF111111),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              icon: const Icon(
                                Icons.shopping_cart_checkout_rounded,
                                size: 20,
                              ),
                              label: const Text(
                                'Continue Shopping',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessArt extends StatelessWidget {
  final Color accentColor;
  final Color iconColor;

  const _SuccessArt({
    required this.accentColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 12,
            left: 42,
            child: Icon(Icons.auto_awesome_rounded, color: iconColor, size: 26),
          ),
          Positioned(
            top: 0,
            right: 34,
            child: Icon(Icons.auto_awesome_rounded, color: iconColor, size: 44),
          ),
          Positioned(
            top: 68,
            left: 12,
            child: Icon(Icons.auto_awesome_rounded, color: iconColor, size: 38),
          ),
          Positioned(
            top: 70,
            right: 10,
            child: Icon(Icons.add_rounded, color: iconColor, size: 34),
          ),
          Container(
            width: 142,
            height: 142,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor.withOpacity(0.24),
                width: 1.6,
              ),
            ),
          ),
          Icon(
            Icons.thumb_up_alt_outlined,
            color: iconColor,
            size: 118,
          ),
        ],
      ),
    );
  }
}
