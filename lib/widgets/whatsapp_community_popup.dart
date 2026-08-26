import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class WhatsappCommunityPopup extends StatelessWidget {
  const WhatsappCommunityPopup({super.key, required this.onJoinNow});

  final VoidCallback onJoinNow;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final logoBackdrop = palette.isLight ? const Color(0xFF121212) : palette.surface;
    final titleColor = palette.isLight ? const Color(0xFF101010) : Colors.white;
    final contentColor = palette.isLight ? const Color(0xFF1A1A1A) : Colors.white;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 330),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.accent.withOpacity(0.9), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: palette.accent.withOpacity(0.22),
              blurRadius: 18,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.34),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -8,
              top: -8,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                color: palette.textMuted,
                visualDensity: VisualDensity.compact,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: logoBackdrop,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.border.withOpacity(0.7)),
                  ),
                  child: Image.asset(
                    'assets/icon/icon.png',
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Join Our WhatsApp Community!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                _CommunityBenefit(
                  icon: Icons.local_offer_outlined,
                  label: 'Offers',
                  color: contentColor,
                  accent: palette.accent,
                ),
                const SizedBox(height: 8),
                _CommunityBenefit(
                  icon: Icons.sports_motorsports_outlined,
                  label: 'Gear',
                  color: contentColor,
                  accent: palette.accent,
                ),
                const SizedBox(height: 8),
                _CommunityBenefit(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Chat',
                  color: contentColor,
                  accent: palette.accent,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 44,
                  width: 178,
                  child: ElevatedButton.icon(
                    onPressed: onJoinNow,
                    icon: const Icon(Icons.chat_rounded, size: 19),
                    label: const Text('JOIN NOW'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityBenefit extends StatelessWidget {
  const _CommunityBenefit({
    required this.icon,
    required this.label,
    required this.color,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: color, size: 5),
        const SizedBox(width: 10),
        Icon(icon, color: accent, size: 21),
        const SizedBox(width: 10),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

