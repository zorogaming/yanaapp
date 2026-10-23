import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_cached_image.dart';
import 'sale_banner.dart';

/// Shared visual language for the motorcycle storefront.
class StorefrontCard extends StatelessWidget {
  const StorefrontCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.colors,
    this.borderColor,
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final List<Color>? colors;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final p = context.appPalette;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors ?? [p.surfaceStrong, p.surface, p.background],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor ?? p.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class StorefrontCategory extends StatelessWidget {
  const StorefrontCategory({
    super.key,
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.imageUrl,
  });
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final p = context.appPalette;
    return Semantics(
      selected: selected,
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: selected
                          ? [p.accent.withValues(alpha: .33), p.background]
                          : [p.surfaceStrong, p.background],
                    ),
                    border: Border.all(
                      color: selected
                          ? p.accent
                          : p.textMuted.withValues(alpha: .5),
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: p.accent.withValues(alpha: .20),
                              blurRadius: 17,
                            ),
                          ]
                        : [],
                  ),
                  child: imageUrl != null && imageUrl!.isNotEmpty
                      ? ClipOval(
                          child: AppCachedImage(
                            url: imageUrl!,
                            fit: BoxFit.contain,
                          ),
                        )
                      : Icon(
                          icon,
                          color: selected ? p.accent : p.textPrimary,
                          size: 30,
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 10,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StorefrontSaleCard extends StatelessWidget {
  const StorefrontSaleCard({
    super.key,
    required this.daily,
    required this.enabled,
    required this.onTap,
    this.countdown,
    this.countdownLabel,
    this.imageUrl,
  });
  final bool daily;
  final bool enabled;
  final VoidCallback onTap;
  final String? countdown;
  final String? countdownLabel;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) => SaleBanner(
    daily: daily,
    enabled: enabled,
    onTap: onTap,
    countdown: countdown,
    countdownLabel: countdownLabel,
  );
}
class StorefrontBenefits extends StatelessWidget {
  const StorefrontBenefits({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.appPalette;
    const benefits = [
      (Icons.local_shipping_outlined, 'Fixed Shipping', '\u{20B9}200'),
      (Icons.verified_user_outlined, '100% Genuine', 'Products'),
      (Icons.inventory_2_outlined, 'Easy Order', 'Tracking'),
      (Icons.lock_outline, 'Secure', 'Payments'),
    ];
    return Row(
      children: benefits
          .map(
            (item) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Icon(item.$1, color: p.accent, size: 23),
                      const SizedBox(width: 4),
                      Text(
                        '${item.$2}\n${item.$3}',
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 9,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class StorefrontServiceCard extends StatelessWidget {
  const StorefrontServiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.appPalette;
    return StorefrontCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: p.accent,
            child: Icon(icon, color: p.onAccent, size: 23),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 10,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.textMuted,
                    fontSize: 9,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 3),
          CircleAvatar(
            radius: 12,
            backgroundColor: p.accent,
            child: Icon(
              Icons.arrow_forward_rounded,
              color: p.onAccent,
              size: 15,
            ),
          ),
        ],
      ),
    );
  }
}
