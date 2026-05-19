import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:provider/provider.dart';
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

  const ProductsScreen({
    super.key,
    this.categoryId,
    required this.title,
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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runAddToBagAnimation({
    required BuildContext startContext,
    required String imageUrl,
  }) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final startBox = startContext.findRenderObject() as RenderBox?;
    final endBox = _cartIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlay == null || startBox == null || endBox == null) {
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
        final dx = (lerpDouble(start.dx, end.dx, t) ?? end.dx) +
            (math.sin(t * math.pi * 1.15) * 14 * (1 - t));
        final dy = (lerpDouble(start.dy, end.dy, t) ?? end.dy) -
            (math.sin(t * math.pi) * 136) -
            (squeezeProgress * 6);
        final opacity =
            t < 0.9 ? 1.0 : (1.0 - ((t - 0.9) / 0.1)).clamp(0.0, 1.0);
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
                            border: Border.all(color: palette.surface, width: 1.5),
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

      final shouldUseCategoryCache = !loadMore &&
          currentPage == 1 &&
          widget.categoryId != null &&
          (searchQuery == null || searchQuery!.trim().isEmpty) &&
          orderBy == null &&
          order == "desc";

      if (shouldUseCategoryCache) {
        final cachedOrFresh =
            await dataManager.getCategoryProducts(widget.categoryId!);
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
        newProducts = result.items.map((e) => Product.fromJson(e)).toList();
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

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 19,
            letterSpacing: 0.4,
          ),
        ),
        backgroundColor: palette.surface,
        iconTheme: IconThemeData(color: palette.textPrimary),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.sort, color: palette.textPrimary),
            color: palette.surface,
            onSelected: (value) {
              if (value == "low_high") {
                changeSort("price", "asc");
              } else if (value == "high_low") {
                changeSort("price", "desc");
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: "low_high",
                child: Text('Price: Low to High',
                    style: TextStyle(color: palette.textPrimary)),
              ),
              PopupMenuItem<String>(
                value: "high_low",
                child: Text('Price: High to Low',
                    style: TextStyle(color: palette.textPrimary)),
              ),
            ],
          ),
          Consumer<CartProvider>(
            builder: (context, cart, child) {
              return IconButton(
                key: _cartIconKey,
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
                            math.sin(progress * math.pi * 4) * 0.12 * (1 - progress);
                        return Transform.rotate(
                          angle: rotation,
                          child: Transform.scale(scale: scale, child: child),
                        );
                      },
                      child: Icon(
                        Icons.shopping_bag_rounded,
                        color: palette.textPrimary,
                      ),
                    ),
                    if (cart.items.isNotEmpty)
                      Positioned(
                        right: -5,
                        top: -5,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                           decoration: BoxDecoration(
                             color: palette.accent,
                             shape: BoxShape.circle,
                           ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            cart.items.length.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                               color: palette.onAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CartScreen(),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
         decoration: BoxDecoration(
           gradient: LinearGradient(
             begin: Alignment.topCenter,
             end: Alignment.bottomCenter,
             colors: [palette.heroEnd, palette.background],
           ),
         ),
        child: Column(
        children: [
          Container(
             color: palette.surface,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: TextField(
              controller: _searchController,
              onSubmitted: searchProducts,
               style: TextStyle(
                 color: palette.textPrimary,
                 fontWeight: FontWeight.w500,
               ),
              decoration: InputDecoration(
                hintText: "Search products, SKU, brand or model...",
                 hintStyle: TextStyle(color: palette.textMuted),
                 prefixIcon:
                     Icon(Icons.search, color: palette.accent),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                         icon: Icon(
                           Icons.clear,
                           color: palette.textMuted,
                         ),
                        onPressed: () {
                          _searchController.clear();
                          searchProducts("");
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                 fillColor: palette.surfaceStrong,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            color: palette.surface,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildSummaryChip(
                  "Total Products: ${totalProducts > 0 ? totalProducts : products.length}",
                ),
                _buildSummaryChip("Total Pages: ${totalPages > 0 ? totalPages : 1}"),
              ],
            ),
          ),
          // Product Grid
          Expanded(
            child: products.isEmpty && isLoading
                ? const ProductsGridSkeleton(
                    padding: EdgeInsets.all(12),
                    childAspectRatio: 0.56,
                  )
                : products.isEmpty && !isLoading
                    ? Center(
                         child: Text("No products found.",
                             style: TextStyle(color: palette.textPrimary)))
                    : GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: products.length + (hasMore ? 1 : 0),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.56,
                        ),
                        itemBuilder: (context, index) {
                          if (index == products.length) {
                            return const ProductCardSkeleton();
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
                                source: source ?? 'products_grid',
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

  Widget _buildSummaryChip(String label) {
    final palette = context.appPalette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.surfaceStrong,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
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
  final void Function(BuildContext buttonContext, String imageUrl)? onAnimateToCart;
  final Future<void> Function(Product product, {String? source})? onToggleWishlist;

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
    final hasImageBadge = badgeLabel != null && badgeLabel!.trim().isNotEmpty;
    final displaySku = product.sku.trim();
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          AspectRatio(
            aspectRatio: 1,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(product: product),
                  ),
                );
              },
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(15)),
                      child: Container(
                        color: palette.surfaceStrong,
                        child: AppCachedImage(
                          url: product.image,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  if (hasImageBadge)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: palette.accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badgeLabel!,
                          style: TextStyle(
                            color: palette.onAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  if (isOutOfStock)
                    Positioned(
                      top: hasImageBadge ? 42 : 10,
                      left: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x44000000),
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.remove_shopping_cart_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "OUT OF STOCK",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Product Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: palette.textPrimary,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (displaySku.isNotEmpty) ...[
                    Text(
                      "SKU: $displaySku",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        "\u20B9${product.price}",
                        style: TextStyle(
                          color: palette.accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      if (product.hasDiscount)
                        Text(
                          "\u20B9${product.regularPrice}",
                          style: TextStyle(
                            color: palette.textMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      if (product.discountPercent > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: palette.accent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            "${product.discountPercent}% OFF",
                            style: TextStyle(
                              color: palette.onAccent,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  // Add to Cart Button - Updated Logic
                  Consumer2<CartProvider, WishlistProvider>(
                    builder: (context, cart, wishlist, child) {
                      bool isInCart =
                          cart.items.any(
                            (item) =>
                                item.id == product.id &&
                                item.variationId == null,
                          );
                      final isWishlisted = wishlist.containsProduct(product.id);
                      return SizedBox(
                        width: double.infinity,
                        height: 35,
                        child: Row(
                          children: [
                            Expanded(
                              child: Builder(
                                builder: (buttonContext) => ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isOutOfStock
                                        ? palette.highlight
                                        : (isInCart
                                              ? palette.surfaceStrong
                                              : palette.accent),
                                    foregroundColor: isOutOfStock
                                        ? Colors.black
                                        : (isInCart
                                              ? palette.textPrimary
                                              : palette.onAccent),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                  ),
                                  onPressed: () {
                                    if (isOutOfStock) {
                                      onToggleWishlist?.call(
                                        product,
                                        source: 'products_grid_out_of_stock',
                                      );
                                      return;
                                    }
                                    final cartProvider = Provider.of<CartProvider>(
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
                                      final snackColor = palette.highlight;
                                      cartProvider.addToCart(
                                        CartItem(
                                          id: product.id,
                                          variationId: null,
                                          name: product.name,
                                          image: product.image,
                                          price: double.tryParse(product.price) ?? 0,
                                          quantity: 1,
                                        ),
                                      );
                                      onAnimateToCart?.call(buttonContext, product.image);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: snackColor,
                                          duration: const Duration(seconds: 1),
                                          content: const Text(
                                            "Added to Bag",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(
                                    isOutOfStock
                                        ? (isWishlisted
                                              ? "Wishlisted"
                                              : "Add to Wishlist")
                                        : (isInCart ? "Go to Bag" : "Add to Bag"),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 35,
                              height: 35,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  backgroundColor: isWishlisted
                                      ? palette.surfaceStrong
                                      : palette.surface,
                                  side: BorderSide(
                                    color: isWishlisted
                                        ? palette.accent
                                        : palette.border,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => onToggleWishlist?.call(product),
                                child: Icon(
                                  isWishlisted
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 17,
                                  color: isWishlisted
                                      ? palette.accent
                                      : palette.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
