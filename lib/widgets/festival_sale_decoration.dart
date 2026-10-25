import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Local vector badges: no remote image downloads are needed for festivals.
class FestivalSaleIcon extends StatelessWidget {
  const FestivalSaleIcon({super.key, required this.festivalKey});
  final String festivalKey;

  static const icons = <String, IconData>{
    'sankranti': Icons.kitesurfing,
    'republic_day': Icons.flag_outlined,
    'shivratri': Icons.nightlight_round,
    'holi': Icons.palette_outlined,
    'ugadi': Icons.eco_outlined,
    'eid_fitr': Icons.nights_stay_outlined,
    'baisakhi': Icons.grass,
    'akshaya_tritiya': Icons.diamond_outlined,
    'eid_adha': Icons.star_border_rounded,
    'rakhi': Icons.filter_vintage_outlined,
    'independence_day': Icons.outlined_flag,
    'janmashtami': Icons.music_note_outlined,
    'ganesh': Icons.spa_outlined,
    'onam': Icons.local_florist_outlined,
    'navratri': Icons.auto_awesome,
    'dussehra': Icons.sports_martial_arts,
    'dhanteras': Icons.monetization_on_outlined,
    'diwali': Icons.local_fire_department_outlined,
    'chhath': Icons.wb_sunny_outlined,
    'gurpurab': Icons.temple_hindu_outlined,
    'christmas': Icons.park_outlined,
    'new_year': Icons.celebration_outlined,
  };

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0x3323270C),
      border: Border.all(color: const Color(0xFFF2C25A), width: 1),
    ),
    child: Padding(
      padding: const EdgeInsets.all(2),
      child: FittedBox(
        child: Icon(
          icons[festivalKey] ?? Icons.celebration_outlined,
          color: const Color(0xFFF2C25A),
        ),
      ),
    ),
  );
}

/// Only mounted while the sale is active and motion is enabled.
class ActiveSaleBorder extends StatefulWidget {
  const ActiveSaleBorder({super.key, required this.radius});
  final double radius;
  @override
  State<ActiveSaleBorder> createState() => _ActiveSaleBorderState();
}

class _ActiveSaleBorderState extends State<ActiveSaleBorder>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(painter: _SaleBorderPainter(_controller, widget.radius)),
  );
}

class _SaleBorderPainter extends CustomPainter {
  _SaleBorderPainter(this.animation, this.radius) : super(repaint: animation);
  final Animation<double> animation;
  final double radius;
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = (Offset.zero & size).deflate(1.5);
    final outline = RRect.fromRectAndRadius(
      bounds,
      Radius.circular(math.max(0, radius - 1.5)),
    );
    final shader = SweepGradient(
      colors: const [
        Color(0x337D9D14),
        Color(0xFFC8FF28),
        Colors.white,
        Color(0xFFF2C25A),
        Color(0x337D9D14),
      ],
      stops: const [0, .34, .43, .52, .72],
      transform: GradientRotation(animation.value * math.pi * 2),
    ).createShader(bounds);
    canvas.drawRRect(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..shader = shader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawRRect(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _SaleBorderPainter old) =>
      old.radius != radius || old.animation != animation;
}
