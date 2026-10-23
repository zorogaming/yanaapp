import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// Reference artwork bundled locally so the sale banners also work offline.
class SaleBanner extends StatelessWidget {
  const SaleBanner({
    super.key,
    required this.daily,
    required this.enabled,
    required this.onTap,
    this.countdown,
    this.countdownLabel,
  });

  final bool daily;
  final bool enabled;
  final VoidCallback onTap;
  final String? countdown;
  final String? countdownLabel;

  static const _ink = Color(0xFF0D1006);
  static const _gold = Color(0xFFF2C25A);

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      enabled: enabled,
      label: daily ? 'Daily Sale' : 'Big Days Sale',
      child: AspectRatio(
        aspectRatio: 1045 / 630,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final u = constraints.maxWidth / 100;
            final radius = BorderRadius.circular(6.2 * u);
            final foreground = daily ? _ink : Colors.white;
            TextStyle text(
              double size, [
              FontWeight weight = FontWeight.w500,
            ]) => TextStyle(
              fontSize: size * u,
              fontWeight: weight,
              color: foreground,
              height: 1,
              leadingDistribution: TextLeadingDistribution.even,
            );
            Widget label(
              String value,
              double x,
              double y,
              double size, [
              FontWeight weight = FontWeight.w500,
            ]) => Positioned(
              left: x * u,
              top: y * u,
              child: Text(value, style: text(size, weight)),
            );

            // Keep reference proportions stable at accessibility text sizes.
            // The full sale title and status are also exposed through semantics.
            return MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1,
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: daily
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFFC9F76F),
                                    Color(0xFFB9EF55),
                                    Color(0xFF9FE33A),
                                  ],
                                  stops: [0, .55, 1],
                                )
                              : const RadialGradient(
                                  center: Alignment(.76, -.2),
                                  radius: 1.58,
                                  colors: [
                                    Color(0xFF6A4713),
                                    Color(0xFF2A1D0C),
                                    Color(0xFF0C0C0C),
                                  ],
                                  stops: [0, .42, 1],
                                ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (daily ? 58.9 : 56.8) * u,
                      top: 0,
                      bottom: 0,
                      right: 0,
                      child: ExcludeSemantics(
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (rect) => const LinearGradient(
                            colors: [Colors.transparent, Colors.black],
                            stops: [0, .16],
                          ).createShader(rect),
                          child: Image.asset(
                            daily
                                ? 'assets/sale/helmet.jpg'
                                : 'assets/sale/jacket.jpg',
                            fit: BoxFit.cover,
                            alignment: Alignment.centerLeft,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 5.3 * u,
                      top: 5.4 * u,
                      width: (daily ? 6.6 : 9.1) * u,
                      height: 8.6 * u,
                      child: daily
                          ? const FittedBox(
                              child: Icon(Icons.bolt, color: _ink),
                            )
                          : CustomPaint(painter: _SaleCrownPainter()),
                    ),
                    label(
                      daily ? 'Daily Sale' : 'Big Days Sale',
                      daily ? 15.8 : 19,
                      7.2,
                      5.4,
                      FontWeight.w700,
                    ),
                    if (daily) ...[
                      Positioned(
                        left: 5.3 * u,
                        top: 17 * u,
                        child: Text.rich(
                          TextSpan(
                            text: enabled ? '50% ' : 'CLOSED',
                            style: text(enabled ? 14 : 11, FontWeight.w800),
                            children: [
                              if (enabled)
                                TextSpan(
                                  text: 'OFF',
                                  style: text(9.8, FontWeight.w800),
                                ),
                            ],
                          ),
                        ),
                      ),
                      label(countdownLabel ?? 'Ends in', 5.7, 31.6, 4.3),
                      Positioned(
                        left: 5.5 * u,
                        top: 38.8 * u,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < 3; i++) ...[
                              if (i > 0)
                                SizedBox(
                                  width: 5.6 * u,
                                  height: 9.9 * u,
                                  child: Center(
                                    child: Text(
                                      ':',
                                      style: text(5.4, FontWeight.w800),
                                    ),
                                  ),
                                ),
                              _clockBox(u, i, reducedMotion),
                            ],
                          ],
                        ),
                      ),
                    ] else ...[
                      label('Up to', 5.8, 16.3, 4.8, FontWeight.w400),
                      label(
                        enabled ? '70% OFF' : 'CLOSED',
                        5.6,
                        22,
                        11.2,
                        FontWeight.w800,
                      ),
                      label(
                        enabled
                            ? 'On Selected Brands'
                            : 'Currently unavailable',
                        5.8,
                        34.4,
                        4.8,
                        FontWeight.w400,
                      ),
                      Positioned(
                        left: 5.9 * u,
                        top: 43.3 * u,
                        width: 47.6 * u,
                        height: 9.9 * u,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 4 * u),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6 * u),
                            border: Border.all(color: const Color(0xFFCFD94A)),
                            gradient: const LinearGradient(
                              colors: [Color(0x1F96E632), Color(0x0DF5C04A)],
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Explore Deals',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text(4.5, FontWeight.w700),
                                ),
                              ),
                              _DealArrow(
                                animate: enabled && !reducedMotion,
                                size: 6 * u,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (!enabled)
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(color: Color(0x33000000)),
                        ),
                      ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            border: Border.all(
                              color: daily
                                  ? const Color(0xCC96E632)
                                  : const Color(0x4DFFD678),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: enabled ? onTap : null,
                          borderRadius: radius,
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
    );
  }

  Widget _clockBox(double u, int index, bool reducedMotion) {
    final parts = (countdown ?? '--:--:--').split(':');
    final value = index < parts.length ? parts[index] : '--';
    return SizedBox(
      width: 12.3 * u,
      child: Column(
        children: [
          Container(
            width: 12.3 * u,
            height: 9.9 * u,
            alignment: Alignment.center,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: const Color(0xFF080A04),
              borderRadius: BorderRadius.circular(2.4 * u),
            ),
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: reducedMotion ? 0 : 240),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, .3),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Text(
                value,
                key: ValueKey(value),
                style: TextStyle(
                  color: const Color(0xFFA5E61F),
                  fontSize: 5.4 * u,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          SizedBox(height: 2.2 * u),
          Text(
            ['Hours', 'Mins', 'Secs'][index],
            style: TextStyle(color: _ink, fontSize: 2.9 * u, height: 1),
          ),
        ],
      ),
    );
  }
}

class _DealArrow extends StatefulWidget {
  const _DealArrow({required this.animate, required this.size});
  final bool animate;
  final double size;
  @override
  State<_DealArrow> createState() => _DealArrowState();
}

class _DealArrowState extends State<_DealArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _DealArrow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) {
      if (widget.animate) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: Icon(
      Icons.arrow_right_alt_rounded,
      color: SaleBanner._gold,
      size: widget.size,
    ),
    builder: (context, child) => Transform.translate(
      offset: Offset(
        Curves.easeInOut.transform(_controller.value) * widget.size * .15,
        0,
      ),
      child: child,
    ),
  );
}

class _SaleCrownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 28, size.height / 24);
    final path = Path()
      ..moveTo(2, 18)
      ..lineTo(0, 5)
      ..lineTo(7, 11)
      ..lineTo(14, 2)
      ..lineTo(21, 11)
      ..lineTo(28, 5)
      ..lineTo(26, 18)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFD978), Color(0xFFE8A93A)],
        ).createShader(const Rect.fromLTWH(0, 0, 28, 24)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2, 20.5, 24, 2.5),
        const Radius.circular(1.2),
      ),
      Paint()..color = SaleBanner._gold,
    );
  }

  @override
  bool shouldRepaint(covariant _SaleCrownPainter oldDelegate) => false;
}
