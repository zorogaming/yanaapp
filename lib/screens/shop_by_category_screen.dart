import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/cart_provider.dart';
import '../services/woo_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_cached_image.dart';
import 'cart_screen.dart';
import 'products_screen.dart';
import 'search_result_screen.dart';
import 'top_category_detail_screen.dart';

class ShopByCategoryScreen extends StatefulWidget {
  const ShopByCategoryScreen({
    super.key,
    this.title = "All Categories",
    this.sourceUrl = defaultSourceUrl,
    this.cacheKeyPrefix = "shop_by_category_cat_txt",
  });

  static const String defaultSourceUrl = "https://yanaworldwide.store/cat.txt";

  final String title;
  final String sourceUrl;
  final String cacheKeyPrefix;

  @override
  State<ShopByCategoryScreen> createState() => _ShopByCategoryScreenState();
}

class _ShopByCategoryScreenState extends State<ShopByCategoryScreen> {
  late Future<List<MotorcycleAccessoryTab>> _categoriesFuture;

  int _selectedIndex = 0;

  String get _cacheKey => "${widget.cacheKeyPrefix}_cache";
  String get _versionKey => "${widget.cacheKeyPrefix}_version";

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _loadCategories(
      sourceUrl: widget.sourceUrl,
      cacheKey: _cacheKey,
      versionKey: _versionKey,
    );
  }

  Future<void> _refresh() async {
    final nextFuture = _loadCategories(
      sourceUrl: widget.sourceUrl,
      cacheKey: _cacheKey,
      versionKey: _versionKey,
    );
    setState(() {
      _selectedIndex = 0;
      _categoriesFuture = nextFuture;
    });
    await nextFuture;
  }

  static Future<List<MotorcycleAccessoryTab>> _loadCategories({
    required String sourceUrl,
    required String cacheKey,
    required String versionKey,
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(cacheKey);
    final cachedVersion = (prefs.getString(versionKey) ?? "").trim();
    final currentVersion = (await WooService().fetchAppVersion())?.trim() ?? "";

    final canUseCache = !forceRefresh &&
        cached != null &&
        cached.trim().isNotEmpty &&
        (currentVersion.isEmpty || cachedVersion == currentVersion);

    if (canUseCache) {
      try {
        final decoded = jsonDecode(cached);
        if (decoded is List) {
          final cachedItems = decoded
              .whereType<Map>()
              .map((item) => MotorcycleAccessoryTab.fromMap(item))
              .where((item) => item.isValid)
              .toList();
          if (cachedItems.isNotEmpty) return cachedItems;
        }
      } catch (_) {
        await prefs.remove(cacheKey);
        await prefs.remove(versionKey);
      }
    }

    try {
      final response = await http
          .get(Uri.parse(sourceUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        return _decodeCachedCategories(cached);
      }

      final parsed = parseMotorcycleAccessoryTabs(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      if (parsed.isEmpty) return _decodeCachedCategories(cached);

      final wordpressCategories = await WooService().fetchAllCategories();
      final items = sortMotorcycleTabsByPhotos(
        applyWordPressCategoryImages(parsed, wordpressCategories),
      );
      await prefs.setString(
        cacheKey,
        jsonEncode(items.map((item) => item.toMap()).toList()),
      );
      await prefs.setString(versionKey, currentVersion);
      return items;
    } catch (_) {
      return _decodeCachedCategories(cached);
    }
  }

  static List<MotorcycleAccessoryTab> _decodeCachedCategories(String? cached) {
    if (cached == null || cached.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(cached);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => MotorcycleAccessoryTab.fromMap(item))
          .where((item) => item.isValid)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  void _openCategory(MotorcycleAccessoryTab item) {
    final categoryId = item.categoryId;
    if (categoryId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductsScreen(
            categoryId: categoryId,
            title: item.title,
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultScreen(searchQuery: item.title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            _CategoryHeader(
              title: widget.title,
              onBack: () => Navigator.maybePop(context),
              onSearch: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SearchResultScreen(searchQuery: ""),
                  ),
                );
              },
              onCart: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                );
              },
            ),
            Expanded(
              child: FutureBuilder<List<MotorcycleAccessoryTab>>(
                future: _categoriesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: palette.accent,
                      ),
                    );
                  }

                  final categories = snapshot.data ?? const [];
                  if (categories.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      color: palette.accent,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 160),
                          Center(
                            child: Text(
                              "Categories load nahi ho payi.",
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final safeIndex =
                      _selectedIndex.clamp(0, categories.length - 1).toInt();
                  final selected = categories[safeIndex];
                  final children = selected.children;

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    color: palette.accent,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 94,
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: categories.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              thickness: 1,
                              color: palette.border,
                              indent: 11,
                              endIndent: 9,
                            ),
                            itemBuilder: (context, index) {
                              final item = categories[index];
                              return _RailCategoryTile(
                                item: item,
                                isSelected: index == safeIndex,
                                onTap: () {
                                  setState(() => _selectedIndex = index);
                                },
                              );
                            },
                          ),
                        ),
                        Container(width: 1, color: palette.border),
                        Expanded(
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
                            children: [
                              Text(
                                selected.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 22,
                                  height: 1.08,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (children.isEmpty)
                                _CategoryGridCard(
                                  item: selected,
                                  onTap: () => _openCategory(selected),
                                )
                              else
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    const gap = 18.0;
                                    final columns =
                                        constraints.maxWidth < 320 ? 2 : 3;
                                    final width =
                                        (constraints.maxWidth - gap * (columns - 1)) /
                                            columns;
                                    return Wrap(
                                      spacing: gap,
                                      runSpacing: 26,
                                      children: [
                                        for (final child in children)
                                          SizedBox(
                                            width: width,
                                            child: _CategoryGridCard(
                                              item: child,
                                              onTap: () => _openCategory(child),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.title,
    required this.onBack,
    required this.onSearch,
    required this.onCart,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onCart;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      height: 86,
      padding: const EdgeInsets.fromLTRB(8, 10, 18, 8),
      color: palette.background,
      child: Row(
        children: [
          IconButton(
            tooltip: "Back",
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            color: palette.textPrimary,
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 24,
                letterSpacing: 0,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            tooltip: "Search",
            onPressed: onSearch,
            icon: const Icon(Icons.search_rounded),
            color: palette.textPrimary,
          ),
          const SizedBox(width: 4),
          Consumer<CartProvider>(
            builder: (context, cart, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: "Cart",
                    onPressed: onCart,
                    icon: const Icon(Icons.shopping_cart_rounded),
                    color: palette.textPrimary,
                  ),
                  if (cart.itemCount > 0)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: palette.accent,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: palette.background, width: 1.4),
                        ),
                        child: Text(
                          cart.itemCount > 99 ? "99+" : cart.itemCount.toString(),
                          style: TextStyle(
                            color: palette.onAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
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
}

class _RailCategoryTile extends StatelessWidget {
  const _RailCategoryTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final MotorcycleAccessoryTab item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imageUrl.trim().toLowerCase().startsWith("http");
    final palette = context.appPalette;
    return Material(
      color: isSelected ? palette.surfaceSoft : palette.surface,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            if (isSelected)
              Positioned(
                left: 0,
                top: 12,
                bottom: 12,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: palette.accent,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 13, 8, 13),
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 50,
                    decoration: BoxDecoration(
                      color:
                          isSelected ? palette.surfaceStrong : palette.surfaceSoft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? palette.accent.withOpacity(0.38)
                            : palette.border,
                      ),
                    ),
                    child: hasImage
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: AppCachedImage(
                              url: item.imageUrl,
                              fit: BoxFit.contain,
                            ),
                          )
                        : Icon(
                            _iconForTitle(item.title),
                            color: palette.accent,
                            size: 28,
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? palette.accent : palette.textMuted,
                      fontSize: 12,
                      height: 1.08,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryGridCard extends StatelessWidget {
  const _CategoryGridCard({
    required this.item,
    required this.onTap,
  });

  final MotorcycleAccessoryTab item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imageUrl.trim().toLowerCase().startsWith("http");
    final palette = context.appPalette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: palette.border),
                ),
                child: hasImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AppCachedImage(
                          url: item.imageUrl,
                          fit: BoxFit.contain,
                        ),
                      )
                    : Icon(
                        _iconForTitle(item.title),
                        color: palette.accent,
                        size: 34,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 13,
                height: 1.08,
                letterSpacing: 0,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconForTitle(String rawTitle) {
  final title = rawTitle.toLowerCase();
  if (title.contains("helmet")) return Icons.sports_motorsports_rounded;
  if (title.contains("light")) return Icons.lightbulb_rounded;
  if (title.contains("luggage") || title.contains("bag")) {
    return Icons.luggage_rounded;
  }
  if (title.contains("oil") || title.contains("lubricant")) {
    return Icons.oil_barrel_rounded;
  }
  if (title.contains("gear") || title.contains("jacket")) {
    return Icons.health_and_safety_rounded;
  }
  if (title.contains("electronic") || title.contains("gps")) {
    return Icons.settings_input_component_rounded;
  }
  if (title.contains("combo") || title.contains("offer")) {
    return Icons.local_offer_rounded;
  }
  return Icons.two_wheeler_rounded;
}

