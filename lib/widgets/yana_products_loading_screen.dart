import 'package:flutter/material.dart';
import 'hana_loader.dart';

class YanaProductsLoadingScreen extends StatelessWidget {
  const YanaProductsLoadingScreen({
    super.key,
    required this.dataReady,
    required this.imagesReady,
    required this.accent,
    this.dataLabel = 'PRODUCTS',
    this.imageLabel = 'IMAGES',
    this.loadingTitle,
  });

  final bool dataReady;
  final bool imagesReady;
  final Color accent;
  final String dataLabel;
  final String imageLabel;
  final String? loadingTitle;

  @override
  Widget build(BuildContext context) {
    final progress = (dataReady ? 0.5 : 0.0) + (imagesReady ? 0.5 : 0.0);
    return Scaffold(
      backgroundColor: const Color(0xFF050705),
      body: Semantics(
        label: loadingTitle ?? 'Loading store',
        value: '${(progress * 100).round()}%',
        child: HanaLoader(progress: progress),
      ),
    );
  }
}
