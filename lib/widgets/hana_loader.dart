import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

const _lime = Color(0xFFC8FF28);
const _logoAsset = 'assets/icon/icon.png';
Color _limeA(double o) => Color.fromRGBO(200, 255, 40, o);

/// App ke upar loader lagata hai. loading=false hone par fade+zoom hoke hat jata hai.
class HanaLoaderOverlay extends StatelessWidget {
  const HanaLoaderOverlay({
    super.key,
    required this.loading,
    required this.progress, // 0.0 - 1.0
    required this.child,
  });

  final bool loading;
  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !loading,
            child: AnimatedOpacity(
              opacity: loading ? 1 : 0,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              child: HanaLoader(progress: progress, exiting: !loading),
            ),
          ),
        ),
      ],
    );
  }
}

class HanaLoader extends StatefulWidget {
  const HanaLoader({super.key, required this.progress, this.exiting = false});
  final double progress;
  final bool exiting;

  @override
  State<HanaLoader> createState() => _HanaLoaderState();
}

class _HanaLoaderState extends State<HanaLoader> with TickerProviderStateMixin {
  // 12 sec ka loop: sab animations (2s, 2.4s, 3s) isme barabar fit hote hain
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  @override
  void didUpdateWidget(HanaLoader old) {
    super.didUpdateWidget(old);
    if (widget.exiting && !old.exiting) {
      // fade khatam hone ke baad animation band (battery bachane ke liye)
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && widget.exiting) _loop.stop();
      });
    } else if (!widget.exiting && old.exiting) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final logoW = (size.width * .38).clamp(0.0, 180.0);
    final meterW = (size.width * .40).clamp(0.0, 190.0);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // dark blurred background
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -.1),
                    radius: 1.0,
                    colors: [Color(0xDB0E1208), Color(0xF2020302)],
                  ),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _loop,
            builder: (context, _) {
              final t = _loop.value * 12; // seconds
              final breath = .5 - .5 * math.cos(2 * math.pi * t / 3);
              return Stack(
                fit: StackFit.expand,
                children: [
                  // lime glow
                  Center(
                    child: Transform.scale(
                      scale: .85 + .25 * breath,
                      child: Opacity(
                        opacity: .5 + .5 * breath,
                        child: Container(
                          width: size.shortestSide * .9,
                          height: size.shortestSide * .9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [_limeA(.32), Colors.transparent],
                              stops: const [0, .65],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // speed lines
                  CustomPaint(painter: _LinesPainter(t), size: Size.infinite),
                  // logo + meter
                  AnimatedScale(
                    scale: widget.exiting ? 1.22 : 1,
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _logo(logoW, t, breath),
                          const SizedBox(height: 20),
                          _meter(meterW),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _logo(double w, double t, double breath) {
    final h = w * 80 / 330;
    final shineP = ((t % 2.4) / 2.4) * 2.0 - 1.0; // -1 -> 1
    final img = Image.asset(
      _logoAsset,
      width: w,
      height: h,
      fit: BoxFit.contain,
    );

    final logo = SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // soft lime glow, sirf logo ki shape ke hisaab se (box nahi banta)
          Positioned.fill(
            child: Opacity(
              opacity: .35 + .25 * breath,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(_lime, BlendMode.srcIn),
                  child: img,
                ),
              ),
            ),
          ),
          // main logo: breathing + shine
          Positioned.fill(
            child: Transform.scale(
              scale: 1 + .035 * breath,
              child: Opacity(
                opacity: .85 + .15 * breath,
                child: ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (r) => LinearGradient(
                    colors: const [
                      Colors.transparent,
                      Color(0xF2FFFFFF),
                      _lime,
                      Colors.transparent,
                    ],
                    stops: const [.38, .48, .53, .63],
                    transform: _Slide(shineP),
                  ).createShader(r),
                  child: img,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // left -> right wipe (intro)
    return AnimatedBuilder(
      animation: _intro,
      child: logo,
      builder: (_, child) => ClipRect(
        clipper: _Wipe(Curves.easeInOutCubic.transform(_intro.value)),
        child: child,
      ),
    );
  }

  Widget _meter(double w) {
    return SizedBox(
      width: w,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: widget.progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 250),
        builder: (_, v, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'LOADING',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2.8,
                    color: Colors.white54,
                  ),
                ),
                Text(
                  '${(v * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                    color: _lime,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Container(
              height: 3,
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                widthFactor: v,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(colors: [_limeA(.2), _lime]),
                    boxShadow: [
                      BoxShadow(
                        color: _limeA(.8),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                      BoxShadow(color: _limeA(.45), blurRadius: 22),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo ke upar se guzarti shine ke liye gradient ko slide karta hai
class _Slide extends GradientTransform {
  const _Slide(this.p);
  final double p;
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * p, 0, 0);
}

/// Intro wipe (glow ko kaate bina)
class _Wipe extends CustomClipper<Rect> {
  const _Wipe(this.t);
  final double t;
  @override
  Rect getClip(Size s) => Rect.fromLTRB(
    -200,
    -200,
    t >= 1 ? s.width + 200 : s.width * t,
    s.height + 200,
  );
  @override
  bool shouldReclip(_Wipe old) => old.t != t;
}

/// Speed lines
class _LinesPainter extends CustomPainter {
  _LinesPainter(this.t);
  final double t;

  // top, delay, period(sec), width, opacity
  static const _lines = <List<double>>[
    [.14, 0.0, 2.4, .46, .5],
    [.27, .9, 3.0, .30, .3],
    [.38, .3, 2.0, .55, .6],
    [.61, 1.4, 2.4, .40, .4],
    [.72, .6, 2.0, .60, .55],
    [.84, 1.8, 3.0, .34, .3],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final l in _lines) {
      final w = size.width * l[3];
      final phase = ((t + l[1]) / l[2]) % 1.0;
      final x = -w + (size.width + w) * phase;
      final rect = Rect.fromLTWH(x, size.height * l[0], w, 1.5);
      canvas.drawRRect(
        RRect.fromRectXY(rect, 1, 1),
        Paint()
          ..shader = LinearGradient(
            colors: [_limeA(0), _limeA(.9 * l[4]), _limeA(0)],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_LinesPainter old) => old.t != t;
}
