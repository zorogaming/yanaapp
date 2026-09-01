import 'dart:convert';

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
      backgroundColor:
          palette.isLight ? const Color(0xFFF1F3F6) : palette.background,
      body: Column(
        children: [
          _TopCategoryHomeHeader(title: title),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
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
                                child: Icon(
                                  icon,
                                  color: palette.onAccent,
                                  size: 30,
                                ),
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
          ),
        ],
      ),
    );
  }
}

class _TopCategoryHomeHeader extends StatelessWidget {
  const _TopCategoryHomeHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        MediaQuery.of(context).padding.top + 10,
        12,
        10,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: "Back",
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: palette.textPrimary,
            ),
            style: IconButton.styleFrom(
              backgroundColor: palette.surface,
              side: BorderSide(color: palette.border),
              fixedSize: const Size(42, 42),
              minimumSize: const Size(42, 42),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Select category to view products",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class TopCategoryInlineSection extends StatelessWidget {
  const TopCategoryInlineSection({
    super.key,
    required this.categoryKey,
    required this.title,
    required this.icon,
    this.onClose,
  });

  final String categoryKey;
  final String title;
  final IconData icon;
  final VoidCallback? onClose;

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
        onClose: onClose,
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
      child: Stack(
        children: [
          Row(
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
                child: Padding(
                  padding: EdgeInsets.only(right: onClose == null ? 0 : 30),
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
              ),
            ],
          ),
          if (onClose != null)
            Positioned(
              top: -7,
              right: -7,
              child: IconButton(
                tooltip: "Close",
                onPressed: onClose,
                icon: Icon(
                  Icons.close_rounded,
                  color: palette.textPrimary,
                  size: 18,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: palette.surface.withOpacity(0.88),
                  minimumSize: const Size(30, 30),
                  fixedSize: const Size(30, 30),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
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
    this.onClose,
  });

  final String sourceUrl;
  final String cacheKeyPrefix;
  final String emptyMessage;
  final VoidCallback? onClose;

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
            onClose: widget.onClose,
            child: Column(
              children: List.generate(
                3,
                (index) => Container(
                  height: 178,
                  margin: EdgeInsets.only(bottom: index == 2 ? 0 : 12),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.border),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
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
            onClose: widget.onClose,
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
          onClose: widget.onClose,
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
      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
        boxShadow: const [],
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
                      fontSize: 17,
                      letterSpacing: 0,
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
                  color: const Color(0xFFE8F0FF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFC8D8FF)),
                ),
                child: Text(
                  "${models.length} items",
                  style: TextStyle(
                    color: const Color(0xFF2B63D9),
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
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = models.length <= 4 ? 2 : 3;
                const gap = 10.0;
                final cardWidth =
                    (constraints.maxWidth - (gap * (columns - 1))) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final model in models)
                      _buildModelBox(
                        context,
                        model,
                        palette,
                        width: cardWidth,
                        height: columns == 2 ? 144 : 132,
                      ),
                  ],
                );
              },
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
        color: palette.isLight ? const Color(0xFFF5F7FA) : palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
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
                  color: const Color(0xFF2B63D9),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
    );
  }

  Widget _buildModelBox(
    BuildContext context,
    MotorcycleAccessoryTab model,
    AppThemePalette palette, {
    required double width,
    required double height,
  }) {
    final hasImage = model.imageUrl.trim().toLowerCase().startsWith("http");
    final categoryId = model.categoryId;
    return SizedBox(
      width: width,
      height: height,
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
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.border),
              boxShadow: const [],
            ),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: palette.isLight
                          ? const Color(0xFFF6F7F9)
                          : palette.background.withOpacity(0.34),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: hasImage
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AppCachedImage(
                              url: model.imageUrl,
                              fit: BoxFit.contain,
                            ),
                          )
                        : Icon(
                            Icons.two_wheeler_rounded,
                            color: const Color(0xFF2B63D9).withOpacity(0.72),
                            size: 30,
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
                      fontSize: width > 130 ? 12 : 10.8,
                      height: 1.08,
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
    VoidCallback? onClose,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [],
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: onClose == null ? 0 : 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [child],
            ),
          ),
          if (onClose != null)
            Positioned(
              top: -7,
              right: -7,
              child: IconButton(
                tooltip: "Close",
                onPressed: onClose,
                icon: Icon(
                  Icons.close_rounded,
                  color: palette.textPrimary,
                  size: 18,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: palette.surface.withOpacity(0.88),
                  minimumSize: const Size(30, 30),
                  fixedSize: const Size(30, 30),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
        ],
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
