import 'dart:convert';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/woo_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_cached_image.dart';
import 'products_screen.dart';

class TopCategoryDetailScreen extends StatelessWidget {
  const TopCategoryDetailScreen({
    super.key,
    required this.categoryKey,
    required this.title,
    required this.icon,
  });

  final String categoryKey;
  final String title;
  final IconData icon;

  static const String motorcycleAccessoriesUrl =
      "https://yanaworldwide.store/Yanaapp/motorcycleaccessories.txt";
  static const String ridingGearUrl =
      "https://yanaworldwide.store/Yanaapp/ridinggear.txt";
  static const String luggageTouringUrl =
      "https://yanaworldwide.store/Yanaapp/luggagetouring.txt";
  static const String helmetsAccessoriesUrl =
      "https://yanaworldwide.store/Yanaapp/helmetsaccessories.txt";
  static const String lubricantsUrl =
      "https://yanaworldwide.store/Yanaapp/lubricants.txt";
  static const String topBrandsUrl =
      "https://yanaworldwide.store/Yanaapp/topb.txt";

  static const Map<String, ManualCategoryContent> manualContent = {
    "shop_by_bike": ManualCategoryContent(
      heading: "Shop By Bike",
      description:
          "Yahan aap bike model ke according products, accessories aur fitment details manually add kar sakte ho.",
      points: [
        "Bike wise product recommendations",
        "Model specific accessories",
        "Fitment notes aur important instructions",
      ],
    ),
    "motorcycle_accessories": ManualCategoryContent(
      heading: "Motorcycle Accessories",
      description:
          "Yahan motorcycle accessories ki details, highlights, categories aur product links manually add karo.",
      points: [
        "Crash guards, fog lights, mirrors, mounts",
        "Daily riding accessories",
        "Installation aur compatibility notes",
      ],
    ),
    "riding_gears": ManualCategoryContent(
      heading: "Riding Gears",
      description:
          "Yahan jackets, gloves, pants, shoes aur safety gear related details manually add karo.",
      points: [
        "Jackets, gloves, boots, pants",
        "Size guide aur safety rating details",
        "City ride aur touring gear suggestions",
      ],
    ),
    "luggage_touring": ManualCategoryContent(
      heading: "Luggage & Touring",
      description:
          "Yahan touring luggage, saddle bags, tank bags aur long ride setup details add karo.",
      points: [
        "Saddle bags, tail bags, tank bags",
        "Touring setup recommendations",
        "Mounting aur waterproofing notes",
      ],
    ),
    "helmets_accessories": ManualCategoryContent(
      heading: "Helmets and Accessories",
      description:
          "Yahan helmets, visors, intercoms aur helmet accessories related details manually add karo.",
      points: [
        "Full face, modular, adventure helmets",
        "Visors, pinlock, padding, intercom",
        "Size aur certification details",
      ],
    ),
    "combos": ManualCategoryContent(
      heading: "Lubricants",
      description:
          "Yahan lubricants, oils aur care products ki details manually add karo.",
      points: [
        "Engine oil aur chain lube",
        "Bike wash aur care products",
        "Recommended lubricant notes",
      ],
    ),
    "events": ManualCategoryContent(
      heading: "Top Brands",
      description:
          "Yahan top brands aur brand wise product links txt file se show honge.",
      points: [
        "Featured brands",
        "Brand wise collections",
        "Best selling brand highlights",
      ],
    ),
  };

  static RemoteCategorySource? remoteSourceFor(String categoryKey) {
    switch (categoryKey) {
      case "motorcycle_accessories":
        return const RemoteCategorySource(
          sourceUrl: motorcycleAccessoriesUrl,
          cacheKeyPrefix: "motorcycle_accessories_tabs",
          emptyMessage: "motorcycleaccessories.txt me data add karo.",
        );
      case "riding_gears":
        return const RemoteCategorySource(
          sourceUrl: ridingGearUrl,
          cacheKeyPrefix: "riding_gears_tabs",
          emptyMessage: "ridinggear.txt me data add karo.",
        );
      case "luggage_touring":
        return const RemoteCategorySource(
          sourceUrl: luggageTouringUrl,
          cacheKeyPrefix: "luggage_touring_tabs",
          emptyMessage: "luggagetouring.txt me data add karo.",
        );
      case "helmets_accessories":
        return const RemoteCategorySource(
          sourceUrl: helmetsAccessoriesUrl,
          cacheKeyPrefix: "helmets_accessories_tabs",
          emptyMessage: "helmetsaccessories.txt me data add karo.",
        );
      case "combos":
        return const RemoteCategorySource(
          sourceUrl: lubricantsUrl,
          cacheKeyPrefix: "lubricants_tabs",
          emptyMessage: "lubricants.txt me data add karo.",
        );
      case "events":
        return const RemoteCategorySource(
          sourceUrl: topBrandsUrl,
          cacheKeyPrefix: "top_brands_tabs",
          emptyMessage: "topb.txt me data add karo.",
        );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final content = manualContent[categoryKey] ??
        ManualCategoryContent(
          heading: title,
          description: "Yahan is category ki details manually add karo.",
          points: const [],
        );
    final remoteSource = remoteSourceFor(categoryKey);

    return Scaffold(
      backgroundColor: palette.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _TopCategoryHomeHeader(title: title),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (remoteSource != null)
                  MotorcycleAccessoriesRemoteTabs(
                    sourceUrl: remoteSource.sourceUrl,
                    cacheKeyPrefix: remoteSource.cacheKeyPrefix,
                    emptyMessage: remoteSource.emptyMessage,
                  ),
                if (remoteSource == null) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: palette.accent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(icon, color: palette.onAccent, size: 30),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          content.heading,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          content.description,
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 14,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (remoteSource == null && content.points.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    "Details",
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...content.points.map(
                    (point) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: palette.surfaceSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: palette.accent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              point,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 14,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotorcycleAccessoriesTabs(
    BuildContext context,
    AppThemePalette palette,
  ) {
    return FutureBuilder<List<MotorcycleAccessoryTab>>(
      future: _fetchMotorcycleAccessoryTabs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildMotorcycleTabsShell(
            palette: palette,
            child: SizedBox(
              height: 230,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, __) => Container(
                  width: 145,
                  decoration: BoxDecoration(
                    color: palette.surface.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          );
        }

        final items = sortMotorcycleTabsByPhotos(
          snapshot.data ?? const <MotorcycleAccessoryTab>[],
        );
        if (items.isEmpty) {
          return _buildMotorcycleTabsShell(
            palette: palette,
            child: Text(
              "motorcycleaccessories.txt me data add karo.",
              style: TextStyle(
                color: Colors.white.withOpacity(0.92),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        return _buildMotorcycleTabsShell(
          palette: palette,
          child: SizedBox(
            height: 245,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                return _buildMotorcycleAccessoryCard(context, items[index]);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildMotorcycleTabsShell({
    required AppThemePalette palette,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF8328F5),
            Color(0xFFA35DF7),
            Color(0xFFC798FA),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [child],
      ),
    );
  }

  Widget _buildMotorcycleAccessoryCard(
    BuildContext context,
    MotorcycleAccessoryTab item,
  ) {
    return SizedBox(
      width: 150,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.children.isNotEmpty
              ? () => _showModelsSheet(context, item)
              : item.link.isEmpty
                  ? null
                  : () => _openLink(item.link),
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AppCachedImage(
                      url: item.imageUrl,
                      height: 132,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6B6B6B),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.children.isNotEmpty
                        ? "${item.children.length} Models"
                        : item.link.isEmpty
                            ? "View Details"
                            : "View Store",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF2C2C2C),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<List<MotorcycleAccessoryTab>> _fetchMotorcycleAccessoryTabs() async {
    try {
      final response = await http
          .get(Uri.parse(motorcycleAccessoriesUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return const [];
      return parseMotorcycleAccessoryTabs(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
    } catch (_) {
      return const [];
    }
  }

  Future<void> _openLink(String rawUrl) async {
    final value = rawUrl.trim();
    final uri = Uri.tryParse(
      value.startsWith("/")
          ? "https://yanaworldwide.store$value"
          : value,
    );
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showModelsSheet(BuildContext context, MotorcycleAccessoryTab item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _MotorcycleModelsSheet(item: item),
    );
  }
}

class _TopCategoryHomeHeader extends StatelessWidget {
  const _TopCategoryHomeHeader({required this.title});

  final String title;

  static const List<String> _bannerUrls = [
    "https://yanaworldwide.store/wp-content/uploads/slider-1.jpg",
    "https://yanaworldwide.store/wp-content/uploads/slider-2.jpg",
    "https://yanaworldwide.store/wp-content/uploads/slider-3.jpg",
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 8,
        16,
        16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette.heroStart, palette.heroEnd, palette.background],
          begin: Alignment.topLeft,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 168,
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: palette.border),
                    boxShadow: [
                      BoxShadow(
                        color: palette.accent.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    "assets/icon/icon.png",
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.account_balance_wallet_outlined,
                color: palette.accent,
                size: 19,
              ),
              const SizedBox(width: 16),
              Text(
                "Login",
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  "|",
                  style: TextStyle(
                    color: palette.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                "Signup",
                style: TextStyle(
                  color: palette.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.shopping_cart_rounded,
                color: palette.textPrimary,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(palette.isLight ? 0.08 : 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Icon(Icons.search_rounded, color: palette.accent),
                ),
                Expanded(
                  child: Text(
                    "Search parts, SKU, model, brand...",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: palette.accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: palette.onAccent,
                      size: 21,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: palette.accent.withOpacity(0.78),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.accent.withOpacity(0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CarouselSlider(
                options: CarouselOptions(
                  height: 180,
                  autoPlay: true,
                  viewportFraction: 1.0,
                  autoPlayInterval: const Duration(seconds: 4),
                ),
                items: _bannerUrls.map((url) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      AppCachedImage(url: url, fit: BoxFit.cover),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.06),
                              Colors.transparent,
                              Colors.black.withOpacity(0.10),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TopCategoryInlineSection extends StatelessWidget {
  const TopCategoryInlineSection({
    super.key,
    required this.categoryKey,
    required this.title,
    required this.icon,
  });

  final String categoryKey;
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final content = TopCategoryDetailScreen.manualContent[categoryKey] ??
        ManualCategoryContent(
          heading: title,
          description: "Yahan is category ki details manually add karo.",
          points: const [],
        );
    final remoteSource = TopCategoryDetailScreen.remoteSourceFor(categoryKey);

    if (remoteSource != null) {
      return MotorcycleAccessoriesRemoteTabs(
        sourceUrl: remoteSource.sourceUrl,
        cacheKeyPrefix: remoteSource.cacheKeyPrefix,
        emptyMessage: remoteSource.emptyMessage,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: palette.accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: palette.onAccent, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content.heading,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MotorcycleAccessoriesRemoteTabs extends StatefulWidget {
  const MotorcycleAccessoriesRemoteTabs({
    super.key,
    required this.sourceUrl,
    required this.cacheKeyPrefix,
    required this.emptyMessage,
  });

  final String sourceUrl;
  final String cacheKeyPrefix;
  final String emptyMessage;

  @override
  State<MotorcycleAccessoriesRemoteTabs> createState() =>
      _MotorcycleAccessoriesRemoteTabsState();
}

class _MotorcycleAccessoriesRemoteTabsState
    extends State<MotorcycleAccessoriesRemoteTabs> {
  static final Map<String, Future<List<MotorcycleAccessoryTab>>> _tabsFutures =
      <String, Future<List<MotorcycleAccessoryTab>>>{};

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return FutureBuilder<List<MotorcycleAccessoryTab>>(
      future: _tabsFutures[widget.cacheKeyPrefix] ??=
          _fetchMotorcycleAccessoryTabs(
        sourceUrl: widget.sourceUrl,
        cacheKeyPrefix: widget.cacheKeyPrefix,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShell(
            palette: palette,
            child: SizedBox(
              height: 216,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, __) => Container(
                  width: 145,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          );
        }

        final items = sortMotorcycleTabsByPhotos(
          snapshot.data ?? const <MotorcycleAccessoryTab>[],
        );
        if (items.isEmpty) {
          return _buildShell(
            palette: palette,
            child: Text(
              widget.emptyMessage,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        return _buildShell(
          palette: palette,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < items.length; index++)
                _buildBrandModelsSection(
                  context,
                  items[index],
                  palette,
                  isLast: index == items.length - 1,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBrandModelsSection(
    BuildContext context,
    MotorcycleAccessoryTab item,
    AppThemePalette palette, {
    required bool isLast,
  }) {
    final models = sortMotorcycleTabsByPhotos(item.children);
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(palette.isLight ? 0.08 : 0.22),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildBrandAvatar(item, palette),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: palette.accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  "${models.length} items",
                  style: TextStyle(
                    color: palette.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (models.isEmpty)
            Text(
              "Models txt file me add karo.",
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            SizedBox(
              height: 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: models.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  return _buildModelBox(context, models[index], palette);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBrandAvatar(MotorcycleAccessoryTab item, AppThemePalette palette) {
    final imageUrl = item.imageUrl.trim();
    final hasImage = imageUrl.trim().toLowerCase().startsWith("http");
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: palette.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.accent.withOpacity(0.22)),
      ),
      child: hasImage
          ? ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: AppCachedImage(
                url: imageUrl,
                fit: BoxFit.cover,
              ),
            )
          : Center(
              child: Text(
                item.title.isEmpty ? "?" : item.title.substring(0, 1),
                style: TextStyle(
                  color: palette.accent,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
    );
  }

  Widget _buildModelBox(
    BuildContext context,
    MotorcycleAccessoryTab model,
    AppThemePalette palette,
  ) {
    final hasImage = model.imageUrl.trim().toLowerCase().startsWith("http");
    final categoryId = model.categoryId;
    return SizedBox(
      width: 112,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: categoryId != null
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductsScreen(
                        categoryId: categoryId,
                        title: model.title,
                      ),
                    ),
                  );
                }
              : model.link.isEmpty
                  ? null
                  : () => _openLink(model.link),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(
                    palette.isLight ? 0.06 : 0.18,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: palette.surfaceSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: hasImage
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AppCachedImage(
                              url: model.imageUrl,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            Icons.two_wheeler_rounded,
                            color: palette.accent.withOpacity(0.82),
                            size: 34,
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(7, 0, 7, 6),
                  child: Text(
                    model.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 11.5,
                      height: 1.04,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildShell({
    required AppThemePalette palette,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.heroStart,
            palette.heroEnd,
            palette.surfaceSoft,
          ],
        ),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [child],
      ),
    );
  }

  static Future<List<MotorcycleAccessoryTab>> _fetchMotorcycleAccessoryTabs({
    required String sourceUrl,
    required String cacheKeyPrefix,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();
    final cacheKey =
        "${cacheKeyPrefix}_${packageInfo.version}_${packageInfo.buildNumber}";
    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        final decoded = jsonDecode(cached);
        if (decoded is List) {
          return sortMotorcycleTabsByPhotos(
            decoded
              .whereType<Map>()
              .map((item) => MotorcycleAccessoryTab.fromMap(item))
              .where((item) => item.isValid)
              .toList(),
          );
        }
      } catch (_) {
        await prefs.remove(cacheKey);
      }
    }

    try {
      final response = await http
          .get(Uri.parse(sourceUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return const [];
      final txtItems = parseMotorcycleAccessoryTabs(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      if (txtItems.isEmpty) return txtItems;

      final categories = await WooService().fetchAllCategories();
      final items = sortMotorcycleTabsByPhotos(
        applyWordPressCategoryImages(txtItems, categories),
      );
      await prefs.setString(
        cacheKey,
        jsonEncode(items.map((item) => item.toMap()).toList()),
      );
      return items;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _openLink(String rawUrl) async {
    final value = rawUrl.trim();
    final uri = Uri.tryParse(
      value.startsWith("/")
          ? "https://yanaworldwide.store$value"
          : value,
    );
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class ManualCategoryContent {
  const ManualCategoryContent({
    required this.heading,
    required this.description,
    required this.points,
  });

  final String heading;
  final String description;
  final List<String> points;
}

class RemoteCategorySource {
  const RemoteCategorySource({
    required this.sourceUrl,
    required this.cacheKeyPrefix,
    required this.emptyMessage,
  });

  final String sourceUrl;
  final String cacheKeyPrefix;
  final String emptyMessage;
}

class MotorcycleAccessoryTab {
  const MotorcycleAccessoryTab({
    required this.title,
    required this.imageUrl,
    required this.link,
    this.categoryId,
    this.children = const <MotorcycleAccessoryTab>[],
  });

  factory MotorcycleAccessoryTab.fromMap(Map item) {
    final rawChildren = item["children"] ?? item["models"] ?? item["items"];
    final rawCategoryId = item["categoryId"] ??
        item["category_id"] ??
        item["category"] ??
        item["id"] ??
        item["term_id"];
    return MotorcycleAccessoryTab(
      title: (item["title"] ?? item["name"] ?? "").toString().trim(),
      imageUrl: (item["image"] ?? item["imageUrl"] ?? item["image_url"] ?? "")
          .toString()
          .trim(),
      link: (item["link"] ?? item["url"] ?? item["href"] ?? "")
          .toString()
          .trim(),
      categoryId: _parseCategoryId(rawCategoryId),
      children: rawChildren is List
          ? rawChildren
              .whereType<Map>()
              .map((child) => MotorcycleAccessoryTab.fromMap(child))
              .where((child) => child.isValid)
              .toList()
          : const <MotorcycleAccessoryTab>[],
    );
  }

  final String title;
  final String imageUrl;
  final String link;
  final int? categoryId;
  final List<MotorcycleAccessoryTab> children;

  bool get isValid => title.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      "title": title,
      "image": imageUrl,
      "link": link,
      if (categoryId != null) "category_id": categoryId,
      "children": children.map((child) => child.toMap()).toList(),
    };
  }
}

int? _parseCategoryId(dynamic value) {
  if (value is int && value > 0) return value;
  final parsed = int.tryParse((value ?? "").toString().trim());
  return parsed != null && parsed > 0 ? parsed : null;
}

List<MotorcycleAccessoryTab> parseMotorcycleAccessoryTabs(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return const [];

  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((item) => MotorcycleAccessoryTab.fromMap(item))
          .where((item) => item.isValid)
          .toList();
    }
  } catch (_) {
    // Plain text format is also supported.
  }

  final items = <MotorcycleAccessoryTab>[];
  MotorcycleAccessoryTab? currentGroup;
  final currentChildren = <MotorcycleAccessoryTab>[];

  void flushGroup() {
    final group = currentGroup;
    if (group == null) return;
    items.add(
      MotorcycleAccessoryTab(
        title: group.title,
        imageUrl: group.imageUrl,
        link: group.link,
        categoryId: group.categoryId,
        children: List<MotorcycleAccessoryTab>.from(currentChildren),
      ),
    );
    currentGroup = null;
    currentChildren.clear();
  }

  for (final rawLine in const LineSplitter().convert(raw)) {
    final value = rawLine.trim();
    if (value.isEmpty || value.startsWith("#")) continue;

    final isChildLine = rawLine.startsWith(" ") || rawLine.startsWith("\t");
    final item = _parseMotorcycleAccessoryLine(value);
    if (item == null) continue;

    if (isChildLine && currentGroup != null) {
      currentChildren.add(item);
      continue;
    }

    flushGroup();
    currentGroup = item;
  }

  flushGroup();
  return items;
}

MotorcycleAccessoryTab? _parseMotorcycleAccessoryLine(String value) {
  final parts = value.contains("|") ? value.split("|") : value.split(",");
  final item = MotorcycleAccessoryTab(
    title: parts[0].trim(),
    imageUrl: parts.length > 1 ? parts[1].trim() : "",
    link: parts.length > 2 ? parts[2].trim() : "",
    categoryId: parts.length > 3 ? _parseCategoryId(parts[3]) : null,
  );
  return item.isValid ? item : null;
}

List<MotorcycleAccessoryTab> applyWordPressCategoryImages(
  List<MotorcycleAccessoryTab> items,
  List<Map<String, dynamic>> categories,
) {
  if (items.isEmpty || categories.isEmpty) return items;

  final byKey = <String, Map<String, dynamic>>{};
  for (final category in categories) {
    final name = (category["name"] ?? "").toString();
    final slug = (category["slug"] ?? "").toString();
    for (final key in [
      _normalizeCategoryKey(name),
      _normalizeCategoryKey(slug),
    ]) {
      if (key.isEmpty) continue;
      byKey.putIfAbsent(key, () => category);
    }
  }

  return items.map((item) => _withWordPressCategoryImage(item, byKey)).toList();
}

List<MotorcycleAccessoryTab> sortMotorcycleTabsByPhotos(
  List<MotorcycleAccessoryTab> items,
) {
  final normalized = items
      .map(
        (item) => MotorcycleAccessoryTab(
          title: item.title,
          imageUrl: item.imageUrl,
          link: item.link,
          categoryId: item.categoryId,
          children: sortMotorcycleTabsByPhotos(item.children),
        ),
      )
      .toList();
  return [
    ...normalized.where(_hasDisplayImage),
    ...normalized.where((item) => !_hasDisplayImage(item)),
  ];
}

bool _hasDisplayImage(MotorcycleAccessoryTab item) {
  return item.imageUrl.trim().toLowerCase().startsWith("http");
}

MotorcycleAccessoryTab _withWordPressCategoryImage(
  MotorcycleAccessoryTab item,
  Map<String, Map<String, dynamic>> categoryByKey,
) {
  final children = item.children
      .map((child) => _withWordPressCategoryImage(child, categoryByKey))
      .toList();
  final category = categoryByKey[_normalizeCategoryKey(item.title)];
  final categoryImage = _categoryImageUrl(category);
  final resolvedImage = item.imageUrl.trim().toLowerCase().startsWith("http")
      ? item.imageUrl
      : categoryImage;
  final categoryId = item.categoryId ?? _categoryId(category);

  return MotorcycleAccessoryTab(
    title: item.title,
    imageUrl: resolvedImage,
    link: item.link,
    categoryId: categoryId,
    children: children,
  );
}

int? _categoryId(Map<String, dynamic>? category) {
  if (category == null) return null;
  return _parseCategoryId(category["id"] ?? category["term_id"]);
}

String _categoryImageUrl(Map<String, dynamic>? category) {
  if (category == null) return "";
  final image = category["image"];
  if (image is Map && image["src"] != null) {
    final src = image["src"].toString().trim();
    if (src.toLowerCase().startsWith("http")) return src;
  }
  return "";
}

String _normalizeCategoryKey(String value) {
  return value
      .toLowerCase()
      .replaceAll("&", "and")
      .replaceAll(RegExp(r"[^a-z0-9]+"), " ")
      .trim()
      .replaceAll(RegExp(r"\s+"), " ");
}

class _MotorcycleModelsSheet extends StatelessWidget {
  const _MotorcycleModelsSheet({required this.item});

  final MotorcycleAccessoryTab item;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      constraints: const BoxConstraints(maxHeight: 520),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: palette.textPrimary),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
              itemCount: item.children.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final child = item.children[index];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.border),
                  ),
                  child: Text(
                    child.title,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
