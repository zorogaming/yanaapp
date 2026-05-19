import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final base = palette.isLight ? palette.surfaceStrong : palette.surfaceSoft;
    final shine = palette.isLight
        ? Color.lerp(base, palette.accent, 0.18) ?? base
        : Color.lerp(base, palette.accent, 0.28) ?? base;
    final edge = palette.isLight
        ? Color.lerp(base, palette.surface, 0.45) ?? base
        : Color.lerp(base, palette.background, 0.25) ?? base;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final v = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment(-1.6 + (v * 2.8), -0.2),
              end: Alignment(-0.6 + (v * 2.8), 0.2),
              colors: [
                edge,
                shine,
                edge,
              ],
              stops: const [0.1, 0.5, 0.9],
            ).createShader(rect);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = 12,
    this.color = const Color(0xFF2A2F44),
  });

  final double? width;
  final double? height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final cardColor = palette.isLight ? palette.surface : palette.surfaceStrong;
    final borderColor = palette.isLight
        ? palette.border
        : palette.border.withOpacity(0.85);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Expanded(child: SkeletonBox(radius: 12)),
            SizedBox(height: 8),
            SkeletonBox(height: 12, width: 130, radius: 8),
            SizedBox(height: 6),
            SkeletonBox(height: 12, width: 80, radius: 8),
            SizedBox(height: 10),
            SkeletonBox(height: 34, radius: 10),
          ],
        ),
      ),
    );
  }
}

class ProductsGridSkeleton extends StatelessWidget {
  const ProductsGridSkeleton({
    super.key,
    this.count = 6,
    this.padding = const EdgeInsets.all(12),
    this.childAspectRatio = 0.56,
    this.crossAxisSpacing = 12,
    this.mainAxisSpacing = 12,
    this.physics,
  });

  final int count;
  final EdgeInsetsGeometry padding;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      physics: physics ?? const NeverScrollableScrollPhysics(),
      itemCount: count,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (_, __) => const ProductCardSkeleton(),
    );
  }
}

class FullPageSkeleton extends StatelessWidget {
  const FullPageSkeleton({
    super.key,
    this.padding = const EdgeInsets.all(16),
  });

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: const [
        SkeletonBox(height: 22, width: 180, radius: 8),
        SizedBox(height: 14),
        SkeletonBox(height: 140, radius: 14),
        SizedBox(height: 12),
        SkeletonBox(height: 16, width: 220, radius: 8),
        SizedBox(height: 8),
        SkeletonBox(height: 16, width: 160, radius: 8),
        SizedBox(height: 14),
        SkeletonBox(height: 84, radius: 12),
        SizedBox(height: 10),
        SkeletonBox(height: 84, radius: 12),
        SizedBox(height: 10),
        SkeletonBox(height: 84, radius: 12),
      ],
    );
  }
}
