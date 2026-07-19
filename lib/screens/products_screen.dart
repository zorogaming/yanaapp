import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../config.dart';
import '../services/woo_service.dart';
import '../services/data_manager.dart';
import '../models/product_model.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';
import '../widgets/app_cached_image.dart';
import '../widgets/skeletons.dart';
import '../theme/app_theme.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';

// 🎨 Brand Colors (Racing Theme - KTM Inspired)
class RacingColors {
  static const Color primaryRed = Color(0xFFFF4A1C);
  static const Color accentAmber = Color(0xFFFFB547);
  static const Color scaffoldBg = Color(0xFF0B0E17);
  static const Color scaffoldBgSoft = Color(0xFF151B2D);
  static const Color cardBg = Color(0xFF1A2238);
  static const Color panelBg = Color(0xFF111827);
  static const Color textPrimary = Color(0xFFF2F5FF);
  static const Color textMuted = Color(0xFF9CA8C6);
}

class ProductsScreen extends StatefulWidget {
  final int? categoryId;
  final String title;
  final String? initialSearchQuery;

  const ProductsScreen({
    super.key,
    this.categoryId,
    required this.title,
    this.initialSearchQuery,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with SingleTickerProviderStateMixin {
  final WooService api = WooService();
  final DataManager dataManager = DataManager();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  late final AnimationController _cartPulseController;
  final GlobalKey _cartIconKey = GlobalKey();

  List<Product> products = [];
  int currentPage = 1;
  int totalProducts = 0;
  int totalPages = 0;
  bool isLoading = false;
  bool hasMore = true;
  String? searchQuery;
  String? orderBy;
  String order = "desc";

  @override
  void initState() {
    super.initState();
    _cartPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    final initialSearch = widget.initialSearchQuery?.trim() ?? "";
    if (initialSearch.isNotEmpty) {
      searchQuery = initialSearch;
      _searchController.text = initialSearch;
    }
    _searchController.addListener(_handleSearchTextChanged);
    fetchProducts();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoading &&
          hasMore) {
        loadNextPage();
      }
    });
  }

  @override
  void dispose() {
    _cartPulseController.dispose();
    _scrollController.dispose();
    _searchController.removeListener(_handleSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _runAddToBagAnimation({
    required BuildContext startContext,
    required String imageUrl,
  }) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final startBox = startContext.findRenderObject() as RenderBox?;
    final endBox =
        _cartIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (startBox == null || endBox == null) {
      _cartPulseController.forward(from: 0);
      return;
    }

    final start = startBox.localToGlobal(startBox.size.center(Offset.zero));
    final end = endBox.localToGlobal(endBox.size.center(Offset.zero));
    final palette = context.appPalette;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1080),
    );
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOutCubicEmphasized,
    );

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) {
        final t = animation.value;
        final squeezeProgress = ((t - 0.76) / 0.24).clamp(0.0, 1.0);
        final size = lerpDouble(62, 16, t) ?? 24;
        final dx =
            (lerpDouble(start.dx, end.dx, t) ?? end.dx) +
            (math.sin(t * math.pi * 1.15) * 14 * (1 - t));
        final dy =
            (lerpDouble(start.dy, end.dy, t) ?? end.dy) -
            (math.sin(t * math.pi) * 136) -
            (squeezeProgress * 6);
        final opacity = t < 0.9
            ? 1.0
            : (1.0 - ((t - 0.9) / 0.1)).clamp(0.0, 1.0);
        final glowSize = size + 20;
        final iconSize = lerpDouble(18, 8, t) ?? 12;
        final scaleBoost = 1 + (math.sin(t * math.pi) * 0.16);
        final squeezeScale = lerpDouble(1.0, 0.38, squeezeProgress) ?? 1.0;
        final endFlash = ((t - 0.82) / 0.18).clamp(0.0, 1.0);
        final trailOpacity = (1 - t).clamp(0.0, 1.0);

        return Positioned(
          left: dx - (size / 2),
          top: dy - (size / 2),
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Transform.rotate(
                angle: (1 - t) * 0.75,
                child: Transform.scale(
                  scale: scaleBoost * squeezeScale,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: -(size * 0.38),
                        top: size * 0.18,
                        child: Opacity(
                          opacity: trailOpacity * 0.32,
                          child: Container(
                            width: size * 0.34,
                            height: size * 0.34,
                            decoration: BoxDecoration(
                              color: palette.accent.withOpacity(0.85),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -(size * 0.2),
                        top: -(size * 0.12),
                        child: Opacity(
                          opacity: trailOpacity * 0.2,
                          child: Container(
                            width: size * 0.22,
                            height: size * 0.22,
                            decoration: BoxDecoration(
                              color: palette.highlight.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -(glowSize - size) / 2,
                        top: -(glowSize - size) / 2,
                        child: Container(
                          width: glowSize,
                          height: glowSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: palette.accent.withOpacity(0.34),
                                blurRadius: 28,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: -(glowSize - size) / 2,
                        top: -(glowSize - size) / 2,
                        child: Opacity(
                          opacity: endFlash * 0.9,
                          child: Container(
                            width: glowSize + (18 * endFlash),
                            height: glowSize + (18 * endFlash),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: palette.highlight.withOpacity(0.75),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          color: palette.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: palette.accent, width: 2.2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 16,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(4),
                        child: imageUrl.isNotEmpty
                            ? ClipOval(
                                child: AppCachedImage(
                                  url: imageUrl,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(
                                Icons.shopping_bag_rounded,
                                color: palette.accent,
                                size: size * 0.48,
                              ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: iconSize * 1.9,
                          height: iconSize * 1.9,
                          decoration: BoxDecoration(
                            color: palette.accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: palette.surface,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.shopping_bag_rounded,
                            color: palette.onAccent,
                            size: iconSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    controller.addListener(entry.markNeedsBuild);
    await controller.forward();
    entry.remove();
    controller.dispose();
    if (mounted) {
      _cartPulseController.forward(from: 0);
    }
  }

  Future<void> _toggleWishlistForProduct(
    Product product, {
    String source = 'products_grid',
  }) async {
    final wishlist = context.read<WishlistProvider>();
    final added = await wishlist.toggle(product, source: source);
    if (!mounted) return;
    final palette = context.appPalette;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: palette.highlight,
        duration: const Duration(seconds: 1),
        content: Text(
          added ? "Added to Wishlist" : "Removed from Wishlist",
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> fetchProducts({bool loadMore = false}) async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      List<Product> newProducts = [];
      int nextTotalProducts = 0;
      int nextTotalPages = 0;

      final shouldUseCategoryCache =
          !loadMore &&
          currentPage == 1 &&
          widget.categoryId != null &&
          (searchQuery == null || searchQuery!.trim().isEmpty) &&
          orderBy == null &&
          order == "desc";

      if (shouldUseCategoryCache) {
        final cachedOrFresh = await dataManager.getCategoryProducts(
          widget.categoryId!,
        );
        newProducts = cachedOrFresh.map((e) => Product.fromJson(e)).toList();
      } else {
        final trimmedSearch = searchQuery?.trim() ?? "";
        final result = trimmedSearch.isNotEmpty
            ? await api.searchProductsSmart(
                query: trimmedSearch,
                page: currentPage,
                categoryId: widget.categoryId,
                orderBy: orderBy,
                order: order,
              )
            : await api.fetchProductsWithMeta(
                page: currentPage,
                categoryId: widget.categoryId,
                search: searchQuery,
                orderBy: orderBy,
                order: order,
              );
        final annotatedItems = await dataManager.annotateProductsWithPriceDrops(
          result.items,
        );
        newProducts = annotatedItems.map((e) => Product.fromJson(e)).toList();
        nextTotalProducts = result.totalProducts;
        nextTotalPages = result.totalPages;
      }

      setState(() {
        if (loadMore) {
          products.addAll(newProducts);
        } else {
          products = newProducts;
        }
        totalProducts = nextTotalProducts;
        totalPages = nextTotalPages;
        isLoading = false;
        hasMore = totalPages > 0
            ? currentPage < totalPages
            : newProducts.length >= 10;
      });
    } catch (e) {
      setState(() => isLoading = false);
      print("Error fetching products: $e");
    }
  }

  void loadNextPage() {
    if (!isLoading && hasMore) {
      currentPage++;
      fetchProducts(loadMore: true);
    }
  }

  void changeSort(String newOrderBy, String newOrder) {
    setState(() {
      orderBy = newOrderBy;
      order = newOrder;
      currentPage = 1;
      totalProducts = 0;
      totalPages = 0;
      hasMore = true;
      products = [];
    });
    fetchProducts();
  }

  void searchProducts(String value) {
    final trimmed = value.trim();
    setState(() {
      searchQuery = trimmed;
      currentPage = 1;
      totalProducts = 0;
      totalPages = 0;
      hasMore = true;
      products = [];
    });
    fetchProducts();
  }

  String _storeHomeUrl() {
    final uri = Uri.parse(Config.baseUrl);
    return "${uri.scheme}://${uri.host}";
  }

  String _slugify(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9]+"), "-")
        .replaceAll(RegExp(r"(^-|-$)"), "");
  }

  Future<void> _shareCategory() async {
    final categoryUrl =
        "${_storeHomeUrl()}/product-category/${_slugify(widget.title)}/";
    final message =
        "Check this category on YANA Worldwide:\n${widget.title}\n$categoryUrl";

    await Share.share(message, subject: widget.title);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchHeader(palette),
            _buildControlsBar(palette),
            Expanded(
              child: products.isEmpty && isLoading
                  ? ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: 6,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                      ),
                      itemBuilder: (_, __) => const ProductListSkeleton(),
                    )
                  : products.isEmpty && !isLoading
                      ? Center(
                          child: Text(
                            "No products found.",
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          padding: EdgeInsets.zero,
                          itemCount: products.length + (hasMore ? 1 : 0),
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: palette.border,
                          ),
                          itemBuilder: (context, index) {
                            if (index == products.length) {
                              return const ProductListSkeleton();
                            }
                            final product = products[index];
                            return ProductCard(
                              product: product,
                              onAnimateToCart: (buttonContext, imageUrl) {
                                _runAddToBagAnimation(
                                  startContext: buttonContext,
                                  imageUrl: imageUrl,
                                );
                              },
                              onToggleWishlist: (selectedProduct, {source}) {
                                return _toggleWishlistForProduct(
                                  selectedProduct,
                                  source: source ?? 'products_list',
                                );
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(AppThemePalette palette) {
    final headerColor =
        palette.isLight ? palette.surfaceStrong : palette.surface;
    return Container(
      color: headerColor,
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 14),
      child: Row(
        children: [
          IconButton(
            tooltip: "Back",
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            color: palette.textPrimary,
          ),
           Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: palette.surfaceSoft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: palette.accent.withOpacity(0.58),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.accent.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onSubmitted: searchProducts,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: widget.title,
                  hintStyle: TextStyle(
                    color: palette.textMuted,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: palette.accent,
                    size: 23,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 42,
                    minHeight: 42,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          tooltip: "Clear",
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          icon: Icon(
                            Icons.close_rounded,
                            color: palette.textMuted,
                            size: 20,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            searchProducts("");
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.fromLTRB(0, 11, 14, 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Consumer<CartProvider>(
            builder: (context, cart, child) {
              return IconButton(
                key: _cartIconKey,
                tooltip: "Cart",
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedBuilder(
                      animation: _cartPulseController,
                      builder: (context, child) {
                        final progress = Curves.elasticOut.transform(
                          _cartPulseController.value.clamp(0.0, 1.0),
                        );
                        final scale = 1 + (0.24 * progress);
                        final rotation =
                            math.sin(progress * math.pi * 4) *
                            0.12 *
                            (1 - progress);
                        return Transform.rotate(
                          angle: rotation,
                          child: Transform.scale(scale: scale, child: child),
                        );
                      },
                      child: Icon(
                        Icons.shopping_cart_rounded,
                        color: palette.textPrimary,
                        size: 30,
                      ),
                    ),
                    if (cart.items.isNotEmpty)
                      Positioned(
                        right: -8,
                        top: -8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: palette.highlight,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: headerColor,
                              width: 1.6,
                            ),
                          ),
                          child: Text(
                            cart.items.length > 99
                                ? "99+"
                                : cart.items.length.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: palette.highlight.computeLuminance() > 0.45
                                  ? Colors.black
                                  : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlsBar(AppThemePalette palette) {
    return Container(
      width: double.infinity,
      color: palette.surface,
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          PopupMenuButton<String>(
            color: palette.surface,
            onSelected: (value) {
              if (value == "low_high") {
                changeSort("price", "asc");
              } else if (value == "high_low") {
                changeSort("price", "desc");
              }
            },
            itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: "low_high",
                child: Text('Price: Low to High'),
              ),
              PopupMenuItem<String>(
                value: "high_low",
                child: Text('Price: High to Low'),
              ),
            ],
            child: _buildControlChip(
              palette: palette,
              label: "Sort",
              icon: Icons.keyboard_arrow_down_rounded,
            ),
          ),
          if (widget.categoryId != null)
            InkWell(
              onTap: _shareCategory,
              borderRadius: BorderRadius.circular(12),
              child: _buildControlChip(
                palette: palette,
                label: "Share",
                icon: Icons.share_rounded,
              ),
            ),
          _buildSummaryChip(
            "${totalProducts > 0 ? totalProducts : products.length} products",
          ),
        ],
      ),
    );
  }

  Widget _buildControlChip({
    required AppThemePalette palette,
    required String label,
    required IconData icon,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: palette.textPrimary.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 7),
          Icon(icon, color: palette.textPrimary, size: 21),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label) {
    final palette = context.appPalette;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: palette.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 💡 EXTRACTED WIDGET: ProductCard (Updated)
// ==========================================
class ProductCard extends StatelessWidget {
  final Product product;
  final String? badgeLabel;
  final void Function(BuildContext buttonContext, String imageUrl)?
  onAnimateToCart;
  final Future<void> Function(Product product, {String? source})?
  onToggleWishlist;

  const ProductCard({
    super.key,
    required this.product,
    this.badgeLabel,
    this.onAnimateToCart,
    this.onToggleWishlist,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final isOutOfStock = !product.isInStock;
    final displaySku = product.sku.trim();
    final description = _stripHtml(product.shortDescription);
    final paymentText = isOutOfStock
        ? "Currently unavailable"
        : "Pay with EMI";
    return Material(
      color: palette.surface,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 118,
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 0.92,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: palette.surfaceSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(6),
                              child: AppCachedImage(
                                url: product.image,
                                fit: BoxFit.contain,
                                radius: 10,
                              ),
                            ),
                          ),
                          if (product.priceDropped)
                            Positioned(
                              left: 5,
                              top: 5,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.success,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "DROP",
                                  style: TextStyle(
                                    color: palette.success.computeLuminance() >
                                            0.45
                                        ? Colors.black
                                        : Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          if (isOutOfStock)
                            Positioned.fill(
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: palette.surface.withOpacity(0.78),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.textPrimary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "OUT OF STOCK",
                                    style: TextStyle(
                                      color:
                                          palette.textPrimary.computeLuminance() >
                                                  0.45
                                              ? Colors.black
                                              : Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Consumer2<CartProvider, WishlistProvider>(
                      builder: (context, cart, wishlist, child) {
                        final isInCart = cart.items.any(
                          (item) =>
                              item.id == product.id && item.variationId == null,
                        );
                        return Builder(
                          builder: (buttonContext) => SizedBox(
                            width: double.infinity,
                            height: 34,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isOutOfStock
                                    ? palette.surfaceSoft
                                    : isInCart
                                        ? palette.surfaceStrong
                                        : palette.accent,
                                foregroundColor: isOutOfStock
                                    ? palette.textMuted
                                    : isInCart
                                        ? palette.textPrimary
                                        : palette.onAccent,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                if (isOutOfStock) {
                                  onToggleWishlist?.call(
                                    product,
                                    source: 'products_list_out_of_stock',
                                  );
                                  return;
                                }
                                final cartProvider =
                                    Provider.of<CartProvider>(
                                  context,
                                  listen: false,
                                );
                                final alreadyInCart = cartProvider.items.any(
                                  (item) =>
                                      item.id == product.id &&
                                      item.variationId == null,
                                );

                                if (alreadyInCart) {
                                  Future.microtask(() {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const CartScreen(),
                                      ),
                                    );
                                  });
                                } else {
                                  cartProvider.addToCart(
                                    CartItem(
                                      id: product.id,
                                      variationId: null,
                                      name: product.name,
                                      image: product.image,
                                      price:
                                          double.tryParse(product.price) ?? 0,
                                      quantity: 1,
                                    ),
                                  );
                                  onAnimateToCart?.call(
                                    buttonContext,
                                    product.image,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: palette.highlight,
                                      duration: const Duration(seconds: 1),
                                      content: Text(
                                        "Added to Bag",
                                        style: TextStyle(
                                          color: palette.highlight
                                                      .computeLuminance() >
                                                  0.45
                                              ? Colors.black
                                              : Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                isOutOfStock
                                    ? "Wishlist"
                                    : isInCart
                                        ? "Go to Bag"
                                        : "Add to Bag",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Consumer<WishlistProvider>(
                  builder: (context, wishlist, child) {
                    final isWishlisted = wishlist.containsProduct(product.id);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                product.name,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 15.6,
                                  height: 1.16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: "Wishlist",
                              onPressed: () => onToggleWishlist?.call(product),
                              icon: Icon(
                                isWishlisted
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: isWishlisted
                                    ? palette.highlight
                                    : palette.textMuted.withOpacity(0.62),
                                size: 27,
                              ),
                              style: IconButton.styleFrom(
                                minimumSize: const Size(30, 30),
                                fixedSize: const Size(30, 30),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            _buildRatingPill(product, palette),
                            const SizedBox(width: 7),
                            if (product.ratingCount > 0)
                              Flexible(
                                child: Text(
                                  "(${product.ratingCount})",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.textMuted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                "Assured",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.accentStrong,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 7,
                          runSpacing: 4,
                          children: [
                            if (product.discountPercent > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.arrow_downward_rounded,
                                    color: palette.success,
                                    size: 24,
                                  ),
                                  Text(
                                    "${product.discountPercent}%",
                                    style: TextStyle(
                                      color: palette.success,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            if (product.hasDiscount)
                              Text(
                                "\u20B9${product.regularPrice}",
                                style: TextStyle(
                                  color: palette.textMuted,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  decoration: TextDecoration.lineThrough,
                                  decorationThickness: 2,
                                ),
                              ),
                            Text(
                              "\u20B9${product.price}",
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 22,
                                height: 1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        if (product.priceDropped)
                          Text(
                            "WOW! price dropped recently",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.accentStrong,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                        else if (description.isNotEmpty)
                          Text(
                            description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.accentStrong,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isOutOfStock
                                ? palette.surfaceSoft
                                : palette.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isOutOfStock
                                  ? palette.border
                                  : palette.accent.withOpacity(0.34),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isOutOfStock
                                    ? Icons.info_outline_rounded
                                    : Icons.payments_rounded,
                                color: isOutOfStock
                                    ? palette.textMuted
                                    : palette.accent,
                                size: 15,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: isOutOfStock
                                    ? Text(
                                        paymentText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: palette.textMuted,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      )
                                    : Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(text: paymentText),
                                            const TextSpan(text: "  "),
                                            TextSpan(
                                              text: "20% Now, Rest COD",
                                              style: TextStyle(
                                                color: palette.accentStrong,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: palette.textPrimary,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (displaySku.isNotEmpty) ...[
                                  Flexible(
                                    child: _buildSpecChip(
                                      "SKU: $displaySku",
                                      palette,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                _buildPremiumChip(palette),
                                const SizedBox(width: 6),
                                _buildStockChip(isOutOfStock, palette),
                              ],
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildRatingPill(
    Product product,
    AppThemePalette palette,
  ) {
    final rating = _resolvedProductRating(product);
    final ratingColor =
        palette.success.computeLuminance() > 0.18 ? palette.success : palette.accent;
    final onRatingColor =
        ratingColor.computeLuminance() > 0.45 ? Colors.black : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: ratingColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              color: onRatingColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 3),
          Icon(Icons.star_rounded, color: onRatingColor, size: 13),
        ],
      ),
    );
  }

  static double _resolvedProductRating(Product product) {
    final realRating = product.averageRating;
    if (realRating >= 1 && realRating <= 5) {
      return double.parse(realRating.toStringAsFixed(1));
    }

    final seed = product.id <= 0 ? product.name.hashCode.abs() : product.id.abs();
    final tenthSteps = seed % 11;
    return 4.0 + (tenthSteps / 10);
  }

  static Widget _buildSpecChip(String label, AppThemePalette palette) {
    final clean = label.trim();
    if (clean.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        clean,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: palette.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static Widget _buildPremiumChip(AppThemePalette palette) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: palette.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: palette.accent.withOpacity(0.34)),
      ),
      alignment: Alignment.center,
      child: Text(
        "Premium",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: palette.accentStrong,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  static String _stripHtml(String value) {
    return value
        .replaceAll(RegExp(r"<[^>]*>"), " ")
        .replaceAll(RegExp(r"&[^;]+;"), " ")
        .replaceAll(RegExp(r"\s+"), " ")
        .trim();
  }

  static Widget _buildStockChip(bool isOutOfStock, AppThemePalette palette) {
    final stockColor = isOutOfStock ? Colors.redAccent : palette.success;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: stockColor.withOpacity(0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: stockColor.withOpacity(0.55)),
      ),
      alignment: Alignment.center,
      child: Text(
        isOutOfStock ? "Out of stock" : "In Stock",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: stockColor,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class ProductListSkeleton extends StatelessWidget {
  const ProductListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      color: palette.surface,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 118, height: 128, radius: 12),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(
                  width: double.infinity,
                  height: 18,
                  radius: 6,
                ),
                const SizedBox(height: 8),
                const SkeletonBox(width: 160, height: 18, radius: 6),
                const SizedBox(height: 12),
                const SkeletonBox(width: 92, height: 22, radius: 5),
                const SizedBox(height: 10),
                const SkeletonBox(width: 210, height: 24, radius: 6),
                const SizedBox(height: 10),
                const SkeletonBox(width: 180, height: 16, radius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
