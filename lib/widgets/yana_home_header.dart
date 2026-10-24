import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const _lime = Color(0xFFB6F21E);

Widget buildYanaHeader({
  required int cartCount,
  required VoidCallback onWalletTap,
  required VoidCallback onLoginTap,
  required VoidCallback onSignupTap,
  required VoidCallback onCartTap,
  String logoAsset = 'assets/icon/icon.png',
  Widget? signedInActions,
  Key? cartBoxKey,
  Widget? cartIcon,
}) {
  final palette = context.appPalette;
  final isLightTheme = palette.isLight;

  return Container(
    height: 68,
    padding: const EdgeInsets.only(right: 10),
    decoration: const BoxDecoration(
      color: Colors.transparent,
      border: Border(bottom: BorderSide(color: Color(0xFF1C1F1A))),
    ),
    child: Row(
      children: [
        Image.asset(
          logoAsset,
          width: 150,
          height: 52,
          fit: BoxFit.contain,
          color: isLightTheme ? const Color(0xFF11130E) : null,
          colorBlendMode: BlendMode.srcIn,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _IconBox(
                  onTap: onWalletTap,
                  color: palette.accent,
                  borderColor: palette.accent.withOpacity(0.45),
                  glow: true,
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: isLightTheme ? palette.textPrimary : palette.accent,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 6),
                if (signedInActions != null)
                  signedInActions
                else ...[
                  _TextAction(
                    label: 'Login',
                    icon: Icons.person_outline_rounded,
                    color: palette.textPrimary,
                    onTap: onLoginTap,
                  ),
                  Container(width: 1, height: 14, color: palette.border),
                  _TextAction(
                    label: 'Signup',
                    icon: Icons.person_add_alt_1_outlined,
                    color: isLightTheme ? palette.accentStrong : palette.accent,
                    bold: true,
                    onTap: onSignupTap,
                  ),
                ],
                const SizedBox(width: 6),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _IconBox(
                      boxKey: cartBoxKey,
                      onTap: onCartTap,
                      color: palette.surface,
                      borderColor: palette.border,
                      child:
                          cartIcon ??
                          Icon(
                            Icons.shopping_cart,
                            color: palette.textPrimary,
                            size: 19,
                          ),
                    ),
                    if (cartCount > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 17),
                          height: 17,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: _lime,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            cartCount > 9 ? '9+' : '$cartCount',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _IconBox extends StatelessWidget {
  const _IconBox({
    required this.onTap,
    required this.child,
    required this.color,
    required this.borderColor,
    this.glow = false,
    this.boxKey,
  });

  final VoidCallback onTap;
  final Widget child;
  final Color color;
  final Color borderColor;
  final bool glow;
  final Key? boxKey;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        key: boxKey,
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF10150A), Color(0xFF050505)],
          ),
          boxShadow: glow
              ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 10)]
              : null,
        ),
        child: child,
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.bold = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool bold;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
