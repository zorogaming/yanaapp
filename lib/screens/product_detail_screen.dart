import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/cart_item.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';
import '../services/analytics_service.dart';
import '../services/woo_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_cached_image.dart';
import '../widgets/skeletons.dart';
import 'cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with TickerProviderStateMixin {
  final WooService api = WooService();
  final PageController _pageController = PageController();
  static const double _snapmintUpfrontPercent = 0.08;
  static const String _supportPhone = "919166666554";

  int quantity = 1;
  int _currentPage = 0;
  List variations = [];
  Map? selectedVariation;
  bool isLoadingVariation = false;
  List<String> productImages = [];
  late final AnimationController _cartIconAnimController;
  late final AnimationController _addToCartAnimController;
  final GlobalKey _cartIconKey = GlobalKey();
  bool _growthLoading = false;
  bool _cashbackEnabled = false;
  double _cashbackSpendAmount = 1000.0;
  double _cashbackRewardAmount = 50.0;
  bool _crossSellEnabled = false;
  int _crossSellMaxItems = 5;
  bool _flashDealEnabled = false;
  String _flashDealTitle = "";
  String _flashDealSubtitle = "";
  DateTime? _flashDealEndsAt;
  Set<int> _flashDealProductIds = const <int>{};
  List<Product> _crossSellProducts = const <Product>[];
  Duration _flashDealRemaining = Duration.zero;
  Timer? _flashDealTimer;

  @override
  void initState() {
    super.initState();
    _cartIconAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _addToCartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    AnalyticsService.instance.logScreen("product_detail");
    AnalyticsService.instance.logProductView(
      productId: widget.product.id,
      productName: widget.product.name,
      price: widget.product.price,
    );
    _initializeImages();
    _loadGrowthConfig();

    if (widget.product.type == "variable") {
      loadVariations();
    }
  }

  void _initializeImages() {
    final uniqueImages = <String>{};
    if (widget.product.image.isNotEmpty) {
      uniqueImages.add(widget.product.image);
    }
    uniqueImages.addAll(
      widget.product.galleryImages.where((image) => image.isNotEmpty),
    );
    productImages = uniqueImages.toList();
  }

  @override
  void dispose() {
    _cartIconAnimController.dispose();
    _addToCartAnimController.dispose();
    _pageController.dispose();
    _flashDealTimer?.cancel();
    super.dispose();
  }

  Future<void> loadVariations() async {
    setState(() => isLoadingVariation = true);

    try {
      final data = await api.fetchVariations(widget.product.id);
      setState(() {
        variations = data;
        isLoadingVariation = false;
      });
    } catch (e) {
      setState(() => isLoadingVariation = false);
      print("Error loading variations: $e");
    }
  }

  Future<void> _loadGrowthConfig() async {
    setState(() => _growthLoading = true);
    try {
      final data = await api.fetchGrowthConfig();
      if (data == null) {
        if (!mounted) return;
        setState(() => _growthLoading = false);
        await _loadFallbackCrossSellProducts();
        return;
      }

      final cashbackRaw = data["cashback"];
      final cashback = cashbackRaw is Map
          ? Map<String, dynamic>.from(cashbackRaw)
          : const <String, dynamic>{};
      final crossSellRaw = data["cross_sell"];
      final crossSell = crossSellRaw is Map
          ? Map<String, dynamic>.from(crossSellRaw)
          : const <String, dynamic>{};
      final flashDealRaw = data["flash_deal"];
      final flashDeal = flashDealRaw is Map
          ? Map<String, dynamic>.from(flashDealRaw)
          : const <String, dynamic>{};

      final flashIds = _parseIntList(flashDeal["product_ids"]);
      final endsAt = DateTime.tryParse((flashDeal["ends_at"] ?? "").toString());

      final productMapRaw = crossSell["product_map"];
      final productMap = productMapRaw is Map
          ? Map<String, dynamic>.from(productMapRaw)
          : const <String, dynamic>{};
      final configuredProductIds = _parseIntList(
        productMap[widget.product.id.toString()],
      );

      List<Product> suggestions = const <Product>[];
      if (crossSell["enabled"] == true && configuredProductIds.isNotEmpty) {
        suggestions = await _loadConfiguredCrossSellProducts(
          configuredProductIds,
          maxItems:
              int.tryParse((crossSell["max_items"] ?? "5").toString()) ?? 5,
        );
      } else {
        suggestions = await _loadFallbackCrossSellProducts(returnProducts: true);
      }

      if (!mounted) return;
      setState(() {
        _cashbackEnabled = cashback["enabled"] == true;
        _cashbackSpendAmount =
            double.tryParse((cashback["spend_amount"] ?? "1000").toString()) ??
            1000.0;
        _cashbackRewardAmount =
            double.tryParse((cashback["cashback_amount"] ?? "50").toString()) ??
            50.0;
        _crossSellEnabled = crossSell["enabled"] == true || suggestions.isNotEmpty;
        _crossSellMaxItems =
            int.tryParse((crossSell["max_items"] ?? "5").toString()) ?? 5;
        _flashDealEnabled = flashDeal["enabled"] == true;
        _flashDealTitle = (flashDeal["title"] ?? "Flash Deal").toString().trim();
        _flashDealSubtitle =
            (flashDeal["subtitle"] ?? "Limited time offer").toString().trim();
        _flashDealEndsAt = endsAt;
        _flashDealProductIds = flashIds.toSet();
        _crossSellProducts = suggestions;
        _growthLoading = false;
      });
      _startFlashDealTimerIfNeeded();
    } catch (_) {
      if (!mounted) return;
      setState(() => _growthLoading = false);
      await _loadFallbackCrossSellProducts();
    }
  }

  Future<List<Product>> _loadConfiguredCrossSellProducts(
    List<int> productIds, {
    int maxItems = 5,
  }) async {
    final items = await api.fetchProductsByIds(productIds, limit: maxItems);
    return items
        .map((item) => Product.fromJson(item))
        .where((item) => item.id != widget.product.id)
        .take(maxItems)
        .toList();
  }

  Future<List<Product>> _loadFallbackCrossSellProducts({
    bool returnProducts = false,
  }) async {
    final suggestions = <Product>[];
    final seenIds = <int>{widget.product.id};

    for (final term in _fallbackCrossSellTerms()) {
      final items = await api.fetchProducts(
        perPage: 6,
        search: term,
      );
      for (final raw in items) {
        if (raw is! Map<String, dynamic>) continue;
        final product = Product.fromJson(raw);
        if (!product.isInStock || seenIds.contains(product.id)) continue;
        seenIds.add(product.id);
        suggestions.add(product);
        if (suggestions.length >= 5) {
          if (returnProducts) return suggestions;
          if (!mounted) return suggestions;
          setState(() {
            _crossSellEnabled = true;
            _crossSellProducts = suggestions;
          });
          return suggestions;
        }
      }
    }

    if (!returnProducts && mounted) {
      setState(() {
        _crossSellEnabled = suggestions.isNotEmpty;
        _crossSellProducts = suggestions;
      });
    }
    return suggestions;
  }

  List<String> _fallbackCrossSellTerms() {
    final name = widget.product.name.toLowerCase();
    if (name.contains("helmet")) {
      return const ["visor", "gloves", "helmet spoiler", "helmet lock"];
    }
    if (name.contains("glove")) {
      return const ["helmet", "riding jacket", "visor"];
    }
    if (name.contains("fog")) {
      return const ["switch", "wiring", "mount", "clamp"];
    }
    if (name.contains("brake")) {
      return const ["lever", "disc", "caliper", "oil"];
    }
    return const ["helmet", "gloves", "visor", "mobile holder"];
  }

  List<int> _parseIntList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .where((e) => e > 0)
          .toList();
    }
    if (raw is String) {
      return raw
          .split(',')
          .map((e) => int.tryParse(e.trim()) ?? 0)
          .where((e) => e > 0)
          .toList();
    }
    return const <int>[];
  }

  bool get _showFlashDeal {
    if (!_flashDealEnabled) return false;
    if (_flashDealEndsAt == null) return false;
    if (!_flashDealProductIds.contains(widget.product.id)) return false;
    return _flashDealRemaining.inSeconds > 0;
  }

  void _startFlashDealTimerIfNeeded() {
    _flashDealTimer?.cancel();
    final endsAt = _flashDealEndsAt;
    if (endsAt == null) return;

    void update() {
      final remaining = endsAt.difference(DateTime.now());
      if (!mounted) return;
      setState(() {
        _flashDealRemaining = remaining.isNegative ? Duration.zero : remaining;
      });
    }

    update();
    _flashDealTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_flashDealRemaining.inSeconds <= 0) {
        _flashDealTimer?.cancel();
      }
      update();
    });
  }

  void _openImageViewer(int initialIndex) {
    if (productImages.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ProductImageViewer(
          images: productImages,
          initialIndex: initialIndex,
          productName: widget.product.name,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 999999);
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final cart = Provider.of<CartProvider>(context);
    final isInCart = cart.items.any(
      (item) =>
          item.id == widget.product.id &&
          item.variationId == selectedVariation?["id"],
    );

    final finalPrice = _selectedCurrentPrice();
    final snapmintUpfront = finalPrice * _snapmintUpfrontPercent;
    final displaySku = _resolveCurrentSku();
    final isCurrentSelectionInStock = _isCurrentSelectionInStock();
    final stockLabel = _currentStockLabel();
    final accentColor = palette.accent;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          widget.product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: palette.textPrimary),
        elevation: 0,
        actions: [
          Consumer<WishlistProvider>(
            builder: (context, wishlist, child) {
              final isWishlisted = wishlist.containsProduct(widget.product.id);
              return IconButton(
                onPressed: () => _toggleWishlist(wishlist: wishlist),
                icon: Icon(
                  isWishlisted
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isWishlisted ? palette.accent : palette.textPrimary,
                ),
                tooltip: isWishlisted ? "Wishlisted" : "Add to Wishlist",
              );
            },
          ),
          Consumer<CartProvider>(
            builder: (context, cart, child) {
              return IconButton(
                key: _cartIconKey,
                icon: AnimatedBuilder(
                  animation: _cartIconAnimController,
                  builder: (context, child) {
                    final progress = Curves.elasticOut.transform(
                      _cartIconAnimController.value.clamp(0.0, 1.0),
                    );
                    final scale = 1 + (0.3 * progress);
                    final rotation =
                        math.sin(progress * math.pi * 4) * 0.12 * (1 - progress);
                    return Transform.rotate(
                      angle: rotation,
                      child: Transform.scale(scale: scale, child: child),
                    );
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.shopping_bag_rounded),
                      if (cart.items.isNotEmpty)
                        Positioned(
                          right: -5,
                          top: -5,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              cart.items.length.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
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
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImageGallery(accentColor, palette),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProductSummary(
                          context: context,
                          finalPrice: finalPrice,
                          displaySku: displaySku,
                          stockLabel: stockLabel,
                          isCurrentSelectionInStock: isCurrentSelectionInStock,
                        ),
                        const SizedBox(height: 16),
                        _buildPurchaseOptions(context),
                        const SizedBox(height: 16),
                        _buildOfferCard(
                          title: "Snapmint Offer",
                          lines: [
                            "Pay \u20B9${_formatRupees(snapmintUpfront)} now. Rest in 0% interest EMIs",
                            "UPI & Cards accepted, online approval in 2 minute",
                          ],
                          bgColor: palette.surface,
                          borderColor: palette.border,
                          titleColor: accentColor,
                          icon: Icons.credit_score_outlined,
                        ),
                        const SizedBox(height: 16),
                        if (_showFlashDeal) ...[
                          _buildFlashDealCard(),
                          const SizedBox(height: 16),
                        ],
                        if (_cashbackEnabled &&
                            _cashbackSpendAmount > 0 &&
                            _cashbackRewardAmount > 0) ...[
                          _buildCashbackCard(finalPrice),
                          const SizedBox(height: 16),
                        ],
                        if (_growthLoading)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: SkeletonBox(height: 170, radius: 20),
                          )
                        else if (_crossSellEnabled &&
                            _crossSellProducts.isNotEmpty) ...[
                          _buildCrossSellSection(),
                          const SizedBox(height: 16),
                        ],
                        _buildInquiryCard(),
                        const SizedBox(height: 16),
                        _buildDescriptionCard(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildBottomBar(
            context: context,
            cart: cart,
            isInCart: isInCart,
            isCurrentSelectionInStock: isCurrentSelectionInStock,
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(Color accentColor, AppThemePalette palette) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final galleryMaxWidth = availableWidth >= 900
            ? 760.0
            : (availableWidth >= 700 ? 680.0 : availableWidth);

        return Container(
      height: 360,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.heroStart, palette.heroEnd],
        ),
      ),
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: productImages.isEmpty ? 1 : productImages.length,
            onPageChanged: (page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemBuilder: (context, index) {
              final imageUrl = productImages.isEmpty ? "" : productImages[index];
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: galleryMaxWidth),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 42),
                    child: GestureDetector(
                      onTap:
                          imageUrl.isEmpty ? null : () => _openImageViewer(index),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: palette.border),
                          boxShadow: [
                            BoxShadow(
                              color: palette.textPrimary.withValues(alpha: 0.10),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: AppCachedImage(
                                  url: imageUrl.startsWith("http") ? imageUrl : "",
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            if (imageUrl.isNotEmpty)
                              Positioned(
                                right: 14,
                                bottom: 14,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.58),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.zoom_in_rounded,
                                    color: Colors.white,
                                    size: 18,
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
          ),
          if (productImages.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(productImages.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: _currentPage == index ? 18 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color:
                          _currentPage == index ? palette.highlight : palette.border,
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
        );
      },
    );
  }

  Widget _buildProductSummary({
    required BuildContext context,
    required double finalPrice,
    required String displaySku,
    required String stockLabel,
    required bool isCurrentSelectionInStock,
  }) {
    final theme = Theme.of(context);
    final palette = context.appPalette;
    final accentColor = palette.accent;
    final regularPrice = _selectedRegularPrice();
    final discountPercent = _selectedDiscountPercent();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.product.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.2,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "OUR PRICE",
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w700,
                        color: palette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                     Text(
                        "\u20B9${finalPrice.toStringAsFixed(2)}",
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (regularPrice != null) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              "MRP ₹${regularPrice.toStringAsFixed(2)}",
                              style: TextStyle(
                                color: palette.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            if (discountPercent > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.accentStrong,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  "$discountPercent% OFF",
                                  style: TextStyle(
                                    color: palette.onAccent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                  ],
                ),
              ),
              _buildStatusChip(
                label: stockLabel,
                bgColor: isCurrentSelectionInStock
                    ? palette.surfaceStrong
                    : palette.surfaceSoft,
                textColor: isCurrentSelectionInStock
                    ? palette.accent
                    : palette.accentStrong,
                borderColor: isCurrentSelectionInStock
                    ? palette.accent.withValues(alpha: 0.24)
                    : palette.accentStrong.withValues(alpha: 0.24),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (displaySku.isNotEmpty)
                _buildMetaChip(
                  icon: Icons.qr_code_2_rounded,
                  label: "SKU: $displaySku",
                  color: accentColor,
                ),
              _buildMetaChip(
                icon: Icons.inventory_2_outlined,
                label: "Product ID: ${widget.product.id}",
                color: palette.textPrimary,
              ),
              _buildMetaChip(
                icon: Icons.verified_outlined,
                label: "Secure checkout ready",
                color: palette.highlight,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseOptions(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appPalette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Purchase Options",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          if (widget.product.type == "variable") ...[
            const SizedBox(height: 14),
            isLoadingVariation
                ? const SkeletonBox(height: 52, radius: 12)
                : DropdownButtonFormField<Map>(
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    dropdownColor: palette.surface,
                    iconEnabledColor: palette.textPrimary,
                    decoration: InputDecoration(
                      labelText: "Select Variation",
                      labelStyle: TextStyle(color: palette.accent),
                      filled: true,
                      fillColor: palette.surfaceStrong,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFFD1D5DB),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: palette.accent),
                      ),
                    ),
                    value: selectedVariation,
                    items: variations.map((variation) {
                      final attributes = (variation["attributes"] as List)
                          .map((attr) => attr["option"].toString())
                          .join(" / ");
                      final variationPrice =
                          variation["price"]?.toString() ?? "0";
                      final variationInStock = _isVariationInStock(variation);
                      final label = variationInStock
                          ? "$attributes - \u20B9$variationPrice"
                          : "$attributes - Out of Stock";

                      return DropdownMenuItem<Map>(
                        value: variation,
                        child: Text(label),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedVariation = value;
                      });
                    },
                  ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Quantity",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: palette.textMuted,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Adjust before adding to cart",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: palette.surfaceStrong,
                  border: Border.all(color: palette.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.remove,
                        size: 20,
                        color: palette.textPrimary,
                      ),
                      onPressed: () {
                        if (quantity > 1) {
                          setState(() => quantity--);
                        }
                      },
                    ),
                    Text(
                      quantity.toString(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.add,
                        size: 20,
                        color: palette.accent,
                      ),
                      onPressed: _isCurrentSelectionInStock()
                          ? () {
                              setState(() => quantity++);
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.appPalette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Description",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Html(data: widget.product.description),
        ],
      ),
    );
  }

  Widget _buildInquiryCard() {
    final palette = context.appPalette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: _openProductInquiryOnWhatsApp,
            icon: const Icon(Icons.chat_outlined, size: 18),
            label: const Text("Inquiry on WhatsApp"),
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.highlight,
              side: BorderSide(color: palette.highlight.withOpacity(0.35)),
              backgroundColor: palette.surfaceStrong,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Reply may sometimes take between 1 to 4 hours.",
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashbackCard(double currentPrice) {
    final palette = context.appPalette;
    final eligible = currentPrice >= _cashbackSpendAmount;
    final remaining = (_cashbackSpendAmount - currentPrice).clamp(
      0,
      _cashbackSpendAmount,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: eligible ? palette.surfaceSoft : palette.surfaceStrong,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: eligible
              ? palette.accent.withValues(alpha: 0.28)
              : palette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: eligible
                      ? palette.accent.withValues(alpha: 0.12)
                      : palette.highlight.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: eligible ? palette.accent : palette.accentStrong,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Wallet Cashback Rule",
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "₹${_cashbackSpendAmount.toStringAsFixed(0)} spend → ₹${_cashbackRewardAmount.toStringAsFixed(0)} wallet cashback",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            eligible
                ? "Ye product price abhi rule qualify karta hai. Cashback repeat purchase ko push karega."
                : "Sirf ₹${remaining.toStringAsFixed(0)} aur add karne par cashback unlock ho jayega.",
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: palette.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashDealCard() {
    final palette = context.appPalette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette.accentStrong, palette.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: palette.accent.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
            children: [
              Icon(Icons.local_fire_department_rounded, color: palette.onAccent),
              const SizedBox(width: 8),
              Text(
                "Flash Deal",
                style: TextStyle(
                  color: palette.onAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _flashDealTitle.isEmpty ? "Limited Time Offer" : _flashDealTitle,
            style: TextStyle(
              color: palette.onAccent,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (_flashDealSubtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _flashDealSubtitle,
              style: TextStyle(
                color: palette.onAccent.withValues(alpha: 0.86),
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: palette.onAccent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.onAccent.withValues(alpha: 0.24)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, color: palette.onAccent, size: 18),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(_flashDealRemaining),
                  style: TextStyle(
                    color: palette.onAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrossSellSection() {
    final palette = context.appPalette;
    final visibleProducts = _crossSellProducts.take(_crossSellMaxItems).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Customers Also Bought",
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Aapke current product ke saath ye accessories bhi add hoti hain.",
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 214,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: visibleProducts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final suggested = visibleProducts[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(product: suggested),
                      ),
                    );
                  },
                  child: Container(
                    width: 132,
                    decoration: BoxDecoration(
                      color: palette.surfaceStrong,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: palette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                          child: SizedBox(
                            height: 96,
                            width: double.infinity,
                            child: AppCachedImage(
                              url: suggested.image,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                suggested.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    "\u20B9${suggested.price}",
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (suggested.hasDiscount)
                                    Text(
                                      "\u20B9${suggested.regularPrice}",
                                      style: TextStyle(
                                        color: palette.textMuted,
                                        fontSize: 11,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  if (suggested.discountPercent > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE53935),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        "${suggested.discountPercent}% OFF",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildBottomBar({
    required BuildContext context,
    required CartProvider cart,
    required bool isInCart,
    required bool isCurrentSelectionInStock,
  }) {
    final palette = context.appPalette;
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;

    return Consumer<WishlistProvider>(
      builder: (context, wishlist, child) {
        final isWishlisted = wishlist.containsProduct(widget.product.id);
        return Container(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            14 + (safeBottom > 0 ? safeBottom : 8),
          ),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border(top: BorderSide(color: palette.border)),
            boxShadow: [
              BoxShadow(
                blurRadius: 20,
                color: Colors.black.withOpacity(0.08),
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Builder(
                  builder: (buttonContext) => AnimatedBuilder(
                    animation: _addToCartAnimController,
                    builder: (context, child) {
                      final progress = _addToCartAnimController.value;
                      final scale = 1 - (0.08 * math.sin(progress * math.pi));
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCurrentSelectionInStock
                            ? palette.surfaceStrong
                            : palette.highlight,
                        foregroundColor: isCurrentSelectionInStock
                            ? palette.textPrimary
                            : Colors.black,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: isCurrentSelectionInStock
                          ? () {
                              _handleAddToCart(cart, startContext: buttonContext);
                            }
                          : () => _toggleWishlist(
                                wishlist: wishlist,
                                source: 'product_detail_out_of_stock',
                              ),
                      child: Text(
                        isCurrentSelectionInStock
                            ? (isInCart ? "GO TO BAG" : "ADD TO BAG")
                            : (isWishlisted
                                  ? "WISHLISTED"
                                  : "ADD TO WISHLIST"),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCurrentSelectionInStock
                        ? palette.accent
                        : palette.surfaceStrong,
                    foregroundColor: isCurrentSelectionInStock
                        ? palette.onAccent
                        : palette.textPrimary,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: isCurrentSelectionInStock
                      ? () {
                          if (_handleAddToCart(cart, isBuyNow: true)) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CartScreen(),
                              ),
                            );
                          }
                        }
                      : _openProductInquiryOnWhatsApp,
                  child: Text(
                    isCurrentSelectionInStock ? "BUY NOW" : "WHATSAPP",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isCurrentSelectionInStock
                          ? palette.onAccent
                          : palette.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _runAddToBagAnimation({
    required BuildContext startContext,
    required String imageUrl,
  }) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final startBox = startContext.findRenderObject() as RenderBox?;
    final endBox = _cartIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (startBox == null || endBox == null) {
      _playCartIconAnimation();
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
        final size = lerpDouble(64, 16, t) ?? 24;
        final dx = (lerpDouble(start.dx, end.dx, t) ?? end.dx) +
            (math.sin(t * math.pi * 1.15) * 14 * (1 - t));
        final dy = (lerpDouble(start.dy, end.dy, t) ?? end.dy) -
            (math.sin(t * math.pi) * 142) -
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
      _playCartIconAnimation();
    }
  }

  bool _handleAddToCart(
    CartProvider cart, {
    bool isBuyNow = false,
    BuildContext? startContext,
  }) {
    if (widget.product.type == "variable" && selectedVariation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a variation")),
      );
      return false;
    }

    if (!_isCurrentSelectionInStock()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This product is out of stock")),
      );
      return false;
    }

    final finalPrice = _selectedCurrentPrice();

    cart.addToCart(
      CartItem(
        id: widget.product.id,
        variationId: selectedVariation?["id"],
        name: widget.product.name,
        image: selectedVariation != null && selectedVariation!["image"] != null
            ? selectedVariation!["image"]["src"]
            : (productImages.isNotEmpty ? productImages.first : ""),
        price: finalPrice,
        quantity: quantity,
      ),
    );

    final animationStartContext = startContext;
    if (animationStartContext != null) {
      unawaited(
        _runAddToBagAnimation(
          startContext: animationStartContext,
          imageUrl: selectedVariation != null && selectedVariation!["image"] != null
              ? selectedVariation!["image"]["src"]
              : (productImages.isNotEmpty ? productImages.first : ""),
        ),
      );
    } else {
      _playCartIconAnimation();
    }

    if (!isBuyNow) {
      final palette = context.appPalette;
      final snackColor = palette.highlight;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: snackColor,
          content: Text(
            "Added to Bag",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    return true;
  }

  void _playCartIconAnimation() {
    _cartIconAnimController.forward(from: 0);
    _addToCartAnimController.forward(from: 0);
  }

  Future<void> _toggleWishlist({
    required WishlistProvider wishlist,
    String source = 'product_detail',
  }) async {
    final added = await wishlist.toggle(widget.product, source: source);
    if (!mounted) return;
    final palette = context.appPalette;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: palette.highlight,
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

  String _resolveCurrentSku() {
    final variationSku = selectedVariation?["sku"]?.toString().trim() ?? "";
    if (variationSku.isNotEmpty) {
      return variationSku;
    }
    return widget.product.sku.trim();
  }

  Future<void> _openProductInquiryOnWhatsApp() async {
    final sku = _resolveCurrentSku();
    final priceText = selectedVariation != null
        ? selectedVariation!["price"]?.toString().trim() ?? widget.product.price
        : widget.product.price;
    final message = Uri.encodeComponent(
      "Hello Yanaworldwide Support,\n"
      "I want to inquire about this product.\n\n"
      "Product: ${widget.product.name}\n"
      "SKU: ${sku.isEmpty ? "N/A" : sku}\n"
      "Product ID: ${widget.product.id}\n"
      "Price: \u20B9$priceText\n\n"
      "Please note: reply may sometimes take between 1 to 4 hours.",
    );
    final uri = Uri.parse("https://wa.me/$_supportPhone?text=$message");
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  bool _isCurrentSelectionInStock() {
    if (selectedVariation != null) {
      return _isVariationInStock(selectedVariation);
    }
    return widget.product.isInStock;
  }

  bool _isVariationInStock(Map? variation) {
    if (variation == null) {
      return false;
    }

    final variationStockStatus =
        variation["stock_status"]?.toString().toLowerCase() ?? "";
    final inStockRaw = variation["in_stock"];
    if (inStockRaw is bool) {
      return inStockRaw;
    }

    return variationStockStatus == "instock" ||
        variationStockStatus == "onbackorder";
  }

  String _currentStockLabel() {
    return _isCurrentSelectionInStock() ? "In Stock" : "Out of Stock";
  }

  double _selectedCurrentPrice() {
    if (selectedVariation != null) {
      return double.tryParse(selectedVariation!["price"].toString()) ??
          (widget.product.priceValue ?? 0);
    }
    return widget.product.priceValue ?? 0;
  }

  double? _selectedRegularPrice() {
    if (selectedVariation != null) {
      final raw = (selectedVariation!["regular_price"] ?? "").toString().trim();
      final parsed = double.tryParse(raw);
      final current = _selectedCurrentPrice();
      if (parsed != null && parsed > current) return parsed;
      return null;
    }
    final mrp = widget.product.regularPriceValue;
    final current = widget.product.priceValue;
    if (mrp != null && current != null && mrp > current) return mrp;
    return null;
  }

  int _selectedDiscountPercent() {
    final mrp = _selectedRegularPrice();
    final current = _selectedCurrentPrice();
    if (mrp == null || mrp <= current || mrp <= 0) return 0;
    return (((mrp - current) / mrp) * 100).round();
  }

  String _formatRupees(double amount) {
    return amount.ceil().toString();
  }

  BoxDecoration _panelDecoration() {
    final palette = context.appPalette;
    final isLight = Theme.of(context).brightness == Brightness.light;
    return BoxDecoration(
      color: palette.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: palette.border),
      boxShadow: [
        BoxShadow(
          color: isLight
              ? palette.textPrimary.withValues(alpha: 0.08)
              : Colors.black.withOpacity(0.16),
          blurRadius: isLight ? 18 : 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  Widget _buildStatusChip({
    required String label,
    required Color bgColor,
    required Color textColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final palette = context.appPalette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surfaceStrong,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildOfferCard({
    required String title,
    required List<String> lines,
    required Color bgColor,
    required Color borderColor,
    required Color titleColor,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: titleColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: titleColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: titleColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  line,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: context.appPalette.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ),
        ],
      ),
    );
  }
}

class _ProductImageViewer extends StatefulWidget {
  const _ProductImageViewer({
    required this.images,
    required this.initialIndex,
    required this.productName,
  });

  final List<String> images;
  final int initialIndex;
  final String productName;

  @override
  State<_ProductImageViewer> createState() => _ProductImageViewerState();
}

class _ProductImageViewerState extends State<_ProductImageViewer> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
    _controller = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                final imageUrl = widget.images[index];
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  boundaryMargin: const EdgeInsets.all(24),
                  child: Center(
                    child: AppCachedImage(
                      url: imageUrl,
                      fit: BoxFit.contain,
                      radius: 0,
                      fallbackAsset: "assets/icon/Blank.jpg",
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 12,
              right: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  tooltip: "Close",
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.images.length > 1) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(widget.images.length, (index) {
                        final isActive = _currentIndex == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: isActive ? 18 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.white : Colors.white38,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
