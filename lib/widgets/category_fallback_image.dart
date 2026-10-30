import 'package:flutter/material.dart';

const String categoryFallbackAsset =
    'assets/category_fallback/category_bike.webp';

class CategoryFallbackImage extends StatelessWidget {
  const CategoryFallbackImage({super.key, this.fit = BoxFit.contain});

  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      categoryFallbackAsset,
      fit: fit,
      filterQuality: FilterQuality.low,
    );
  }
}
