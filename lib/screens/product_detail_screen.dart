import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models/cart_item.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';
import '../services/analytics_service.dart';
import '../services/recently_viewed_service.dart';
import '../services/woo_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_cached_image.dart';
import '../widgets/skeletons.dart';
import 'cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _SnapmintFeature extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SnapmintFeature({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF005B67), size: 17),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF496971),
              fontSize: 10,
              height: 1.15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with TickerProviderStateMixin {
  final WooService api = WooService();
  final PageController _pageController = PageController();
  static const double _snapmintUpfrontPercent = 0.25;
  static const double _snapmintNineMonthFactor = 1.07613;
  static const String _supportPhone = "919166666554";

  int quantity = 1;
  int _currentPage = 0;
  List variations = [];
  Map? selectedVariation;
  bool isLoadingVariation = false;
  List<String> productImages = [];
  late final AnimationController _cartIconAnimController;
  late final AnimationController _cartIdleAnimController;
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
  int _watchingCount = 5;
  Timer? _watchingTimer;
  Timer? _cartIdleStartTimer;
  Timer? _cartIdleStopTimer;
  static const int _maxWatchingCount = 11;

  @override
  void initState() {
    super.initState();
    _cartIconAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _cartIdleAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
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
    _saveRecentlyViewedProduct();
    _initializeImages();
    _initializeWatchingCount();
    _scheduleCartIdleAnimation();
    _loadGrowthConfig();

    if (widget.product.type == "variable") {
      loadVariations();
    }
  }

  Future<void> _saveRecentlyViewedProduct() async {
    try {
      await RecentlyViewedService.instance.add(widget.product);
    } catch (_) {
      // Recently viewed should never block the product detail screen.
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
    _cartIdleStartTimer?.cancel();
    _cartIdleStopTimer?.cancel();
    _cartIconAnimController.dispose();
    _cartIdleAnimController.dispose();
    _addToCartAnimController.dispose();
    _pageController.dispose();
    _flashDealTimer?.cancel();
    _watchingTimer?.cancel();
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
        suggestions = await _loadFallbackCrossSellProducts(
          returnProducts: true,
        );
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
        _crossSellEnabled =
            crossSell["enabled"] == true || suggestions.isNotEmpty;
        _crossSellMaxItems =
            int.tryParse((crossSell["max_items"] ?? "5").toString()) ?? 5;
        _flashDealEnabled = flashDeal["enabled"] == true;
        _flashDealTitle = (flashDeal["title"] ?? "Flash Deal")
            .toString()
            .trim();
        _flashDealSubtitle = (flashDeal["subtitle"] ?? "Limited time offer")
            .toString()
            .trim();
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
      final items = await api.fetchProducts(perPage: 6, search: term);
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

  Future<void> _shareProduct() async {
    final productUrl =
        "${_storeHomeUrl()}/product/${_slugify(widget.product.name)}/";
    final priceText = widget.product.price.trim().isEmpty
        ? ""
        : "\nPrice: ₹${widget.product.price}";
    final message =
        "Check this product on YANA Worldwide:\n${widget.product.name}$priceText\n$productUrl";

    await Share.share(message, subject: widget.product.name);
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
      backgroundColor: palette.isLight ? const Color(0xFFF1F1F1) : palette.background,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFlipkartHeader(cart),
                  _buildImageGallery(accentColor, palette),
                  if (_showFlashDeal) _buildFlashDealCard(),
                  Container(
                    color: palette.surface,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPurchaseOptions(context),
                        const SizedBox(height: 10),
                        _buildProductSummary(
                          context: context,
                          finalPrice: finalPrice,
                          displaySku: displaySku,
                          stockLabel: stockLabel,
                          isCurrentSelectionInStock: isCurrentSelectionInStock,
                        ),
                        const SizedBox(height: 12),
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
                        _buildSectionGap(),
                        _buildPartialCodOfferCard(finalPrice),
                        _buildSectionGap(),
                        if (_cashbackEnabled &&
                            _cashbackSpendAmount > 0 &&
                            _cashbackRewardAmount > 0) ...[
                          _buildCashbackCard(finalPrice),
                          _buildSectionGap(),
                        ],
                        if (_growthLoading)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: SkeletonBox(height: 170, radius: 20),
                          )
                        else if (_crossSellEnabled &&
                            _crossSellProducts.isNotEmpty) ...[
                          _buildCrossSellSection(),
                          _buildSectionGap(),
                        ],
                        _buildInquiryCard(),
                        _buildSectionGap(),
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

  Widget _buildAssuredBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF2F6BFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flash_on_rounded, color: Color(0xFFFFD43B), size: 13),
          Text(
            "Assured",
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionGap() {
    return Column(
      children: [
        const SizedBox(height: 14),
        Divider(height: 1, thickness: 1, color: context.appPalette.border),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildFlipkartHeader(CartProvider cart) {
    final palette = context.appPalette;
    return SafeArea(
      bottom: false,
      child: Container(
        color: palette.surface,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: Icon(Icons.arrow_back_rounded, color: palette.textPrimary),
                  style: IconButton.styleFrom(
                    fixedSize: const Size(38, 38),
                    minimumSize: const Size(38, 38),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const Spacer(),
                Consumer<WishlistProvider>(
                  builder: (context, wishlist, child) {
                    final isWishlisted =
                        wishlist.containsProduct(widget.product.id);
                    return IconButton(
                      onPressed: () => _toggleWishlist(wishlist: wishlist),
                      icon: Icon(
                        isWishlisted
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isWishlisted ? palette.accent : palette.textPrimary,
                      ),
                    );
                  },
                ),
                IconButton(
                  onPressed: _shareProduct,
                  icon: Icon(Icons.share_rounded, color: palette.textPrimary),
                ),
                IconButton(
                  key: _cartIconKey,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    );
                  },
                  icon: AnimatedBuilder(
                    animation: Listenable.merge([
                      _cartIconAnimController,
                      _cartIdleAnimController,
                    ]),
                    builder: (context, child) {
                      final tapProgress = Curves.elasticOut.transform(
                        _cartIconAnimController.value.clamp(0.0, 1.0),
                      );
                      final idleProgress = Curves.easeInOut.transform(
                        _cartIdleAnimController.value.clamp(0.0, 1.0),
                      );
                      return Transform.scale(
                        scale: 1 + (0.25 * tapProgress) + (0.12 * idleProgress),
                        child: child,
                      );
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            color: palette.textPrimary),
                        if (cart.items.isNotEmpty)
                          Positioned(
                            right: -7,
                            top: -7,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                cart.items.length.toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
          color: palette.surface,
          width: double.infinity,
          child: Column(
            children: [
              SizedBox(
                height: 310,
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
                        final imageUrl = productImages.isEmpty
                            ? ""
                            : productImages[index];
                        return Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: galleryMaxWidth),
                            child: GestureDetector(
                              onTap: imageUrl.isEmpty
                                  ? null
                                  : () => _openImageViewer(index),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(36, 8, 36, 30),
                                child: AppCachedImage(
                                url: imageUrl.startsWith("http") ? imageUrl : "",
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (widget.product.discountPercent > 0)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4545),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "-${widget.product.discountPercent}% OFF",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    if (productImages.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(productImages.length, (index) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: _currentPage == index ? 20 : 7,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: _currentPage == index
                                    ? accentColor
                                    : Colors.white.withOpacity(0.62),
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
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
    final rating = _resolvedProductRating();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.zero,
      color: palette.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.product.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.28,
              fontSize: 14.5,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "Excellent",
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildAssuredBadge(),
            ],
          ),
          const SizedBox(height: 8),
          _buildWatchingNowRow(),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "\u20B9${finalPrice.toStringAsFixed(2)}",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
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
          const SizedBox(height: 14),
          _buildProductMetaLine(displaySku: displaySku),
        ],
      ),
    );
  }

  Widget _buildPurchaseOptions(BuildContext context) {
    final palette = context.appPalette;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.zero,
      decoration: const BoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.product.type == "variable") ...[
            Text(
              "select variant",
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            isLoadingVariation
                ? const SkeletonBox(height: 42, radius: 0)
                : DropdownButtonFormField<Map>(
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    dropdownColor: palette.surface,
                    iconEnabledColor: palette.textPrimary,
                    decoration: InputDecoration(
                      labelText: "Variant",
                      labelStyle: TextStyle(color: palette.textMuted),
                      filled: true,
                      fillColor: palette.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(0),
                        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(0),
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
          const SizedBox(height: 8),
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
                      "Adjust before checkout",
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
                  color: palette.surface,
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                  borderRadius: BorderRadius.circular(0),
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
                      icon: Icon(Icons.add, size: 20, color: palette.accent),
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
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 0),
      color: palette.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Product Description",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded, color: palette.textMuted),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            decoration: BoxDecoration(
              color:
                  palette.isLight ? const Color(0xFFFAFAFA) : palette.surfaceStrong,
              border: Border.all(color: palette.border),
            ),
            child: Html(data: widget.product.description),
          ),
        ],
      ),
    );
  }

  Widget _buildInquiryCard() {
    final palette = context.appPalette;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.zero,
      color: palette.surface,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Color(0xFF16A34A),
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Have a question?",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Reply may take 1 to 4 hours.",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _openProductInquiryOnWhatsApp,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF16A34A),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              "WhatsApp",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
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
      padding: EdgeInsets.zero,
      color: palette.surface,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Bank & Wallet Offers",
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      eligible ? "Cashback unlocked" : "Add more to unlock",
                      style: TextStyle(
                        color: eligible ? palette.accent : palette.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.textMuted),
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

  Widget _buildPartialCodOfferCard(double currentPrice) {
    final palette = context.appPalette;
    final payNow = currentPrice * 0.20;
    final payOnDelivery = math.max(0.0, currentPrice - payNow);

    return InkWell(
      onTap: () => _showPartialCodInfoDialog(
        payNow: payNow,
        payOnDelivery: payOnDelivery,
      ),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: palette.isLight ? const Color(0xFFFBFDFF) : palette.surfaceStrong,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFB8D4FF)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.payments_outlined,
                color: Color(0xFF2B63D9),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Pay 20% now, rest on delivery",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "\u20B9${_formatRupees(payNow)} online • \u20B9${_formatRupees(payOnDelivery)} Cash on Delivery",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF2B63D9)),
          ],
        ),
      ),
    );
  }

  Future<void> _showPartialCodInfoDialog({
    required double payNow,
    required double payOnDelivery,
  }) async {
    final palette = context.appPalette;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(
            "20% Advance + Cash on Delivery",
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPopupMetaLine("Pay online now", "\u20B9${_formatRupees(payNow)}"),
              const SizedBox(height: 10),
              _buildPopupMetaLine(
                "Pay on delivery",
                "\u20B9${_formatRupees(payOnDelivery)}",
              ),
              const SizedBox(height: 12),
              Text(
                "Pay only 20% online to confirm your order. The remaining amount will be collected as Cash on Delivery.",
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFlashDealCard() {
    final palette = context.appPalette;
    final saleLabel = _flashDealTitle.trim().isEmpty
        ? "FLASH SALE"
        : _flashDealTitle.trim().toUpperCase();
    final saleCaption = _flashDealSubtitle.trim().isEmpty
        ? "Ends in"
        : _flashDealSubtitle.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      color: palette.isLight ? const Color(0xFF101724) : palette.surfaceStrong,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6A1A),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: Colors.white, size: 14),
                const SizedBox(width: 5),
                Text(
                  saleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              saleCaption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.72),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          Text(
            _formatDuration(_flashDealRemaining).replaceAll(":", "  :  "),
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrossSellSection() {
    final palette = context.appPalette;
    final visibleProducts = _crossSellProducts
        .take(_crossSellMaxItems)
        .toList();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.zero,
      color: palette.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Customers Also Bought",
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                "View all",
                style: TextStyle(
                  color: palette.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded, color: palette.accent, size: 18),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            "Frequently added with this product",
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 205,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: visibleProducts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
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
                    width: 124,
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: palette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.zero,
                          child: SizedBox(
                            height: 98,
                            width: double.infinity,
                            child: Container(
                              color: palette.isLight
                                  ? const Color(0xFFF7F7F7)
                                  : palette.surfaceStrong,
                              padding: const EdgeInsets.all(8),
                              child: AppCachedImage(
                                url: suggested.image,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
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
                                    fontSize: 11.5,
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
                                      color: palette.textPrimary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
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
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        "${suggested.discountPercent}% OFF",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
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
        final emiFrom = _selectedCurrentPrice() * _snapmintUpfrontPercent;
        return Container(
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            10 + (safeBottom > 0 ? safeBottom : 8),
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
              Builder(
                builder: (buttonContext) => AnimatedBuilder(
                    animation: _addToCartAnimController,
                    builder: (context, child) {
                      final progress = _addToCartAnimController.value;
                      final scale = 1 - (0.08 * math.sin(progress * math.pi));
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: SizedBox(
                      width: 58,
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.textPrimary,
                          side: BorderSide(color: palette.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(2),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      onPressed: isCurrentSelectionInStock
                          ? () {
                              _handleAddToCart(
                                cart,
                                startContext: buttonContext,
                              );
                            }
                          : () => _toggleWishlist(
                              wishlist: wishlist,
                              source: 'product_detail_out_of_stock',
                            ),
                        child: Icon(
                          isCurrentSelectionInStock
                              ? Icons.add_shopping_cart_rounded
                              : (isWishlisted
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded),
                          size: 28,
                        ),
                      ),
                    ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Builder(
                  builder: (buttonContext) => OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.textPrimary,
                      side: BorderSide(color: palette.border),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onPressed: isCurrentSelectionInStock
                        ? () => _showSnapmintOfferSheet(
                              cart: cart,
                              startContext: buttonContext,
                            )
                        : null,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Pay With EMI",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          "Pay ₹${_formatRupees(emiFrom)} now",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            color: palette.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCurrentSelectionInStock
                        ? const Color(0xFFFFD814)
                        : palette.surfaceStrong,
                    foregroundColor: isCurrentSelectionInStock
                        ? Colors.black
                        : palette.textPrimary,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
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
                    isCurrentSelectionInStock ? "Buy Now" : "WhatsApp",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isCurrentSelectionInStock
                          ? Colors.black
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
    final endBox =
        _cartIconKey.currentContext?.findRenderObject() as RenderBox?;
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
        final dx =
            (lerpDouble(start.dx, end.dx, t) ?? end.dx) +
            (math.sin(t * math.pi * 1.15) * 14 * (1 - t));
        final dy =
            (lerpDouble(start.dy, end.dy, t) ?? end.dy) -
            (math.sin(t * math.pi) * 142) -
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
    final variationAttributes = <String, String>{};
    final rawAttributes = selectedVariation?["attributes"];
    if (rawAttributes is List) {
      for (final rawAttribute in rawAttributes) {
        if (rawAttribute is! Map) continue;
        final name = (rawAttribute["name"] ?? "").toString().trim();
        final option = (rawAttribute["option"] ?? "").toString().trim();
        if (name.isNotEmpty && option.isNotEmpty) {
          variationAttributes[name] = option;
        }
      }
    }

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
        variationAttributes: variationAttributes,
      ),
    );

    final animationStartContext = startContext;
    if (animationStartContext != null) {
      unawaited(
        _runAddToBagAnimation(
          startContext: animationStartContext,
          imageUrl:
              selectedVariation != null && selectedVariation!["image"] != null
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
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
    return true;
  }

  Future<void> _showSnapmintOfferSheet({
    required CartProvider cart,
    required BuildContext startContext,
  }) async {
    if (widget.product.type == "variable" && selectedVariation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a variation")),
      );
      return;
    }

    if (!_isCurrentSelectionInStock()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This product is out of stock")),
      );
      return;
    }

    final productAmount = _selectedCurrentPrice() * quantity;
    final upfrontAmount = productAmount * _snapmintUpfrontPercent;
    final restAmount = productAmount - upfrontAmount;
    final threeMonthEmi = restAmount / 3;
    final sixMonthEmi = restAmount / 6;
    final nineMonthEmi = (restAmount * _snapmintNineMonthFactor) / 9;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(10),
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: const Color(0xFFEAFBFF),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 8, 8),
                  child: Row(
                    children: [
                      const Spacer(),
                      const Icon(
                        Icons.bolt_rounded,
                        color: Color(0xFF94D82D),
                        size: 25,
                      ),
                      const Text(
                        "snapmint",
                        style: TextStyle(
                          color: Color(0xFF005B67),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF005B67),
                        ),
                      ),
                    ],
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: "Pay only "),
                      TextSpan(
                        text: "\u20B9${_formatRupees(upfrontAmount)}",
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    color: Color(0xFF005B67),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  "as downpayment now",
                  style: TextStyle(
                    color: Color(0xFF005B67),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 26),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SnapmintFeature(
                        icon: Icons.percent,
                        label: "0% Interest\nInstallments",
                      ),
                      _SnapmintFeature(
                        icon: Icons.money_off_csred_rounded,
                        label: "0 Extra\nCost",
                      ),
                      _SnapmintFeature(
                        icon: Icons.credit_card_rounded,
                        label: "UPI & Cards\naccepted",
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE4E7EA)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Total Order Value",
                          style: TextStyle(
                            color: Color(0xFF6C747A),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        "\u20B9${_formatRupees(productAmount)}",
                        style: const TextStyle(
                          color: Color(0xFF233238),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "& pay the rest in...",
                  style: TextStyle(
                    color: Color(0xFF005B67),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSnapmintPlanCard(
                          option: "OPTION 01",
                          amount: "\u20B9${_formatRupees(threeMonthEmi)}",
                          months: "x 3 months",
                          badge: "0% EMI",
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSnapmintPlanCard(
                          option: "OPTION 02",
                          amount: "\u20B9${_formatRupees(sixMonthEmi)}",
                          months: "x 6 months",
                          badge: "0% EMI",
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSnapmintPlanCard(
                          option: "OPTION 03",
                          amount: "\u20B9${_formatRupees(nineMonthEmi)}",
                          months: "x 9 months",
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDDF7FF),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(22),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Select snapmint on the payment screen",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF005B67),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD814),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            if (_handleAddToCart(
                              cart,
                              isBuyNow: true,
                              startContext: startContext,
                            )) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CartScreen(),
                                ),
                              );
                            }
                          },
                          child: const Text(
                            "Continue with Snapmint",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSnapmintPlanCard({
    required String option,
    required String amount,
    required String months,
    String? badge,
  }) {
    return Column(
      children: [
        Text(
          option,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF719097),
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 18),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(7, 19, 7, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD9DEE2)),
              ),
              child: Column(
                children: [
                  Text(
                    amount,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF005B67),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFFE6ECEF)),
                      ),
                    ),
                    child: Text(
                      months,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF005B67),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Positioned(
                top: -12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB8F11A),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Color(0xFF005B67),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
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

  double _resolvedProductRating() {
    final realRating = widget.product.averageRating;
    if (realRating >= 1 && realRating <= 5) {
      return double.parse(realRating.toStringAsFixed(1));
    }

    final seed = widget.product.id <= 0
        ? widget.product.name.hashCode.abs()
        : widget.product.id.abs();
    final tenthSteps = seed % 11;
    return 4.0 + (tenthSteps / 10);
  }

  void _initializeWatchingCount() {
    _watchingCount = _stableProductNumber(
      min: 5,
      max: _maxWatchingCount,
      salt: "watching",
    );
    _watchingTimer?.cancel();
    _watchingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted || _watchingCount >= _maxWatchingCount) return;
      setState(() {
        _watchingCount = math.min(_maxWatchingCount, _watchingCount + 1);
      });
    });
  }

  int _stableProductNumber({
    required int min,
    required int max,
    required String salt,
  }) {
    final seedSource =
        "${widget.product.id}-${widget.product.sku}-${widget.product.name}-$salt";
    final seed = seedSource.hashCode.abs();
    return min + (seed % (max - min + 1));
  }

  Widget _buildWatchingNowRow() {
    final palette = context.appPalette;
    final alertColor = palette.isLight
        ? const Color(0xFFE53935)
        : const Color(0xFFFF6B6B);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.remove_red_eye_outlined,
          size: 15,
          color: alertColor,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: [
                TextSpan(
                  text: "$_watchingCount people",
                  style: TextStyle(
                    color: alertColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: " are viewing this product",
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _scheduleCartIdleAnimation() {
    _cartIdleStartTimer?.cancel();
    _cartIdleStopTimer?.cancel();
    _cartIdleAnimController.stop();
    _cartIdleAnimController.value = 0;

    _cartIdleStartTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      _cartIdleAnimController.repeat(reverse: true);
      _cartIdleStopTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        _cartIdleAnimController.stop();
        _cartIdleAnimController.value = 0;
      });
    });
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

  Widget _buildProductMetaLine({required String displaySku}) {
    final palette = context.appPalette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: palette.isLight ? const Color(0xFFF8F8F8) : palette.surfaceStrong,
        border: Border(
          top: BorderSide(color: palette.border),
          bottom: BorderSide(color: palette.border),
        ),
      ),
      child: Row(
        children: [
          if (displaySku.isNotEmpty) ...[
            Expanded(
              flex: 4,
              child: _buildMetaLineItem(
                icon: Icons.qr_code_2_rounded,
                text: "SKU: $displaySku",
              ),
            ),
            _buildMetaDivider(),
          ],
          Expanded(
            flex: 3,
            child: _buildMetaLineItem(
              icon: Icons.inventory_2_outlined,
              text: "ID: ${widget.product.id}",
              onTap: () => _showProductMetaPopup(displaySku: displaySku),
            ),
          ),
          _buildMetaDivider(),
          Expanded(
            flex: 4,
            child: _buildMetaLineItem(
              icon: Icons.verified_user_outlined,
              text: "Secure Checkout",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaLineItem({
    required IconData icon,
    required String text,
    VoidCallback? onTap,
  }) {
    final palette = context.appPalette;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: onTap == null ? palette.textMuted : palette.accent),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: onTap == null ? palette.textMuted : palette.accent,
            ),
          ),
        ),
      ],
    );
    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: content,
      ),
    );
  }

  Future<void> _showProductMetaPopup({required String displaySku}) async {
    final palette = context.appPalette;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(
            "Product Details",
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPopupMetaLine("Product ID", widget.product.id.toString()),
              const SizedBox(height: 10),
              _buildPopupMetaLine(
                "SKU",
                displaySku.isEmpty ? "N/A" : displaySku,
              ),
              const SizedBox(height: 10),
              _buildPopupMetaLine("Checkout", "Secure checkout ready"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPopupMetaLine(String label, String value) {
    final palette = context.appPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        SelectableText(
          value,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildMetaDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        "|",
        style: TextStyle(
          color: context.appPalette.border,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
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
    final palette = context.appPalette;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.zero,
      color: palette.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: titleColor.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: titleColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  lines.join(" • "),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: palette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: palette.textMuted),
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
