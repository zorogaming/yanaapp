import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'skeletons.dart';

class AppCachedImage extends StatelessWidget {
  const AppCachedImage({
    super.key,
    required this.url,
    required this.fit,
    this.width,
    this.height,
    this.fallbackAsset = "assets/icon/Blank.jpg",
    this.isCircular = false,
    this.radius = 10,
    this.memCacheWidth,
    this.memCacheHeight,
    this.maxWidthDiskCache,
    this.maxHeightDiskCache,
    this.filterQuality = FilterQuality.low,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final String fallbackAsset;
  final bool isCircular;
  final double radius;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final int? maxWidthDiskCache;
  final int? maxHeightDiskCache;
  final FilterQuality filterQuality;

  Widget _shapeWrap(Widget child) {
    if (isCircular) {
      return ClipOval(child: child);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final src = url.trim();
    if (!src.toLowerCase().startsWith("http")) {
      return _shapeWrap(
        Image.asset(
          fallbackAsset,
          fit: fit,
          width: width,
          height: height,
          filterQuality: filterQuality,
        ),
      );
    }

    return _shapeWrap(
      CachedNetworkImage(
        imageUrl: src,
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: memCacheWidth ?? 1400,
        memCacheHeight: memCacheHeight,
        maxWidthDiskCache: maxWidthDiskCache,
        maxHeightDiskCache: maxHeightDiskCache,
        fadeInDuration: const Duration(milliseconds: 120),
        fadeOutDuration: const Duration(milliseconds: 80),
        filterQuality: filterQuality,
        placeholder: (context, _) => SkeletonBox(
          width: width,
          height: height,
          radius: isCircular ? 999 : radius,
        ),
        errorWidget: (context, _, __) => Image.asset(
          fallbackAsset,
          fit: fit,
          width: width,
          height: height,
          filterQuality: filterQuality,
        ),
      ),
    );
  }
}
