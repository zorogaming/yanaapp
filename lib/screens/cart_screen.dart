import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart_item.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';
import '../services/data_manager.dart';
import '../services/recently_viewed_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_cached_image.dart';
import 'checkout_screen.dart';
import 'product_detail_screen.dart';
import 'wishlist_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key, this.onContinueShopping});

  final VoidCallback? onContinueShopping;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Future<List<Product>>? _suggestionsFuture;
  String _suggestionsKey = "";
  late final Future<List<Product>> _recentlyViewedFuture;

  @override
  void initState() {
    super.initState();
    _recentlyViewedFuture = RecentlyViewedService.instance.load();
  }

  Future<List<Product>> _loadSuggestions(Set<int> cartProductIds) async {
    final dataManager = DataManager();
    final cartDetails = await dataManager.api.fetchProductsByIds(
      cartProductIds.toList(),
      limit: cartProductIds.length,
    );

    final categoryIds = <int>{};
    for (final product in cartDetails) {
      final categories = product["categories"];
      if (categories is! List) continue;
      for (final category in categories) {
        if (category is! Map) continue;
        final id = int.tryParse((category["id"] ?? "").toString()) ?? 0;
        if (id > 0) categoryIds.add(id);
      }
    }

    final products = <Product>[];
    final seenIds = <int>{};

    void addRawProducts(Iterable<dynamic> rawItems, {int? perCategoryLimit}) {
      var addedForCategory = 0;
      for (final item in rawItems.whereType<Map>()) {
        if (perCategoryLimit != null && addedForCategory >= perCategoryLimit) {
          break;
        }
        try {
          final product = Product.fromJson(Map<String, dynamic>.from(item));
          if (cartProductIds.contains(product.id) || !seenIds.add(product.id)) {
            continue;
          }
          products.add(product);
          addedForCategory++;
        } catch (_) {}
      }
    }

    if (categoryIds.isNotEmpty) {
      for (final categoryId in categoryIds.take(5)) {
        final categoryItems = await dataManager.getCategoryProducts(categoryId);
        addRawProducts(categoryItems, perCategoryLimit: 2);
      }
    } else {
      final rawItems = await dataManager.getBestSellingProducts();
      addRawProducts(rawItems);
    }
    return products.take(10).toList();
  }

  Future<List<Product>> _suggestionsForCart(Set<int> cartProductIds) {
    final key = cartProductIds.toList()..sort();
    final nextKey = key.join(",");
    if (_suggestionsFuture == null || _suggestionsKey != nextKey) {
      _suggestionsKey = nextKey;
      _suggestionsFuture = _loadSuggestions(cartProductIds);
    }
    return _suggestionsFuture!;
  }

  Product _productFromCartItem(CartItem item) {
    final price = item.price.toStringAsFixed(0);
    return Product(
      id: item.id,
      name: item.name,
      price: price,
      regularPrice: price,
      salePrice: "",
      image: item.image,
      galleryImages: item.image.trim().isEmpty ? const [] : [item.image],
      description: "",
      shortDescription: "",
      type: "simple",
      sku: "",
      stockStatus: "instock",
      isInStock: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    final palette = context.appPalette;
    final pageBg = palette.background;
    final cardBorder = palette.border;
    final cardSurface = palette.surface;
    final softSurface = palette.surfaceStrong;
    final darkText = palette.textPrimary;
    final mutedText = palette.textMuted;
    final actionBlue = palette.accent;
    final priceGreen = palette.success;
    final orderColor = palette.highlight;
    final orderTextColor =
        orderColor.computeLuminance() > 0.45 ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: Text(
          "My Cart",
          style: TextStyle(
            color: darkText,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: cardSurface,
        surfaceTintColor: cardSurface,
        elevation: 0.5,
        shadowColor: Colors.black12,
        iconTheme: IconThemeData(color: darkText),
        actions: [
          Consumer<WishlistProvider>(
            builder: (context, wishlist, child) {
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'Wishlist',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WishlistScreen(),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.favorite_border_rounded,
                        color: darkText,
                      ),
                    ),
                    if (wishlist.items.isNotEmpty)
                      Positioned(
                        right: 2,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: actionBlue,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            wishlist.items.length.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
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
      body: Consumer2<CartProvider, WishlistProvider>(
        builder: (context, cart, wishlist, child) {
          if (cart.items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Your bag is empty",
                      style: TextStyle(
                        color: mutedText,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: widget.onContinueShopping ??
                          () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                      icon: Icon(Icons.storefront_rounded, color: actionBlue),
                      label: Text(
                        'Continue Shopping',
                        style: TextStyle(
                          color: darkText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: cardSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: softSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          color: actionBlue,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'} in your bag",
                              style: TextStyle(
                                color: darkText,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "Delivery and checkout details are kept ready.",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: mutedText, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WishlistScreen(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          foregroundColor: actionBlue,
                        ),
                        icon: Icon(
                          Icons.favorite_rounded,
                          size: 16,
                        ),
                        label: Text(
                          "Wishlist ${wishlist.items.isEmpty ? '' : '(${wishlist.items.length})'}"
                              .trim(),
                          style: TextStyle(
                            color: actionBlue,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.only(top: 2, bottom: 12 + safeBottom),
                  cacheExtent: 360,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  itemCount: cart.items.length + 2,
                  itemBuilder: (context, index) {
                    if (index == cart.items.length) {
                      return _buildCartSuggestions(
                        context: context,
                        cart: cart,
                        cartProductIds: cart.items.map((item) => item.id).toSet(),
                        cardBorder: cardBorder,
                        cardSurface: cardSurface,
                        softSurface: softSurface,
                        darkText: darkText,
                        mutedText: mutedText,
                        actionBlue: actionBlue,
                        priceGreen: priceGreen,
                      );
                    }
                    if (index == cart.items.length + 1) {
                      return _buildRecentlyViewedProducts(
                        context: context,
                        cart: cart,
                        cardBorder: cardBorder,
                        cardSurface: cardSurface,
                        softSurface: softSurface,
                        darkText: darkText,
                        mutedText: mutedText,
                        actionBlue: actionBlue,
                        priceGreen: priceGreen,
                      );
                    }
                    final item = cart.items[index];

                    return Dismissible(
                      key: Key("${item.id}-${item.variationId}"),
                      background: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) {
                        cart.removeItem(item.id, variationId: item.variationId);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                        decoration: BoxDecoration(
                          color: cardSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: cardBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProductDetailScreen(
                                          product: _productFromCartItem(item),
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 94,
                                    height: 104,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: softSurface,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: AppCachedImage(
                                        url: item.image,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: darkText,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                          height: 1.25,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        "In stock  |  Fast delivery available",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: priceGreen,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      Row(
                                        children: [
                                          Text(
                                            "\u20B9${item.price.toStringAsFixed(0)}",
                                            style: TextStyle(
                                              color: darkText,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 17,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              "Total \u20B9${(item.price * item.quantity).toStringAsFixed(0)}",
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: mutedText,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 9),
                                      Container(
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: softSurface,
                                          border: Border.all(color: cardBorder),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 7,
                                              ),
                                              constraints:
                                                  const BoxConstraints(),
                                              icon: Icon(
                                                Icons.remove,
                                                color: mutedText,
                                                size: 15,
                                              ),
                                              onPressed: () => cart.decreaseQty(
                                                item.id,
                                                variationId: item.variationId,
                                              ),
                                            ),
                                            Container(
                                              constraints: const BoxConstraints(
                                                minWidth: 34,
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                "Qty ${item.quantity}",
                                                style: TextStyle(
                                                  color: darkText,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 7,
                                              ),
                                              constraints:
                                                  const BoxConstraints(),
                                              icon: Icon(
                                                Icons.add,
                                                color: actionBlue,
                                                size: 15,
                                              ),
                                              onPressed: () => cart.increaseQty(
                                                item.id,
                                                variationId: item.variationId,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(height: 1, color: cardBorder),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: () => cart.removeItem(
                                      item.id,
                                      variationId: item.variationId,
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: mutedText,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      "Remove",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: () {
                                      wishlist.toggle(
                                        _productFromCartItem(item),
                                        source: "cart",
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: mutedText,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                    ),
                                    icon: Icon(
                                      wishlist.containsProduct(item.id)
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      wishlist.containsProduct(item.id)
                                          ? "Saved"
                                          : "Save for later",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const CheckoutScreen(),
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: actionBlue,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.flash_on_rounded,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      "Buy now",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  10,
                  10,
                  10,
                  10 + (safeBottom > 0 ? safeBottom : 6),
                ),
                decoration: BoxDecoration(
                  color: cardSurface,
                  border: Border(top: BorderSide(color: cardBorder)),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 14,
                      color: Colors.black.withOpacity(0.10),
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "\u20B9${cart.total.toStringAsFixed(0)}",
                            style: TextStyle(
                              color: darkText,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'}",
                            style: TextStyle(
                              color: mutedText,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onContinueShopping ??
                          () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                      style: TextButton.styleFrom(
                        foregroundColor: actionBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text(
                        "Continue Shopping",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 148,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: orderColor,
                          foregroundColor: orderTextColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CheckoutScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "Place order",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCartSuggestions({
    required BuildContext context,
    required CartProvider cart,
    required Set<int> cartProductIds,
    required Color cardBorder,
    required Color cardSurface,
    required Color softSurface,
    required Color darkText,
    required Color mutedText,
    required Color actionBlue,
    required Color priceGreen,
  }) {
    return FutureBuilder<List<Product>>(
      future: _suggestionsForCart(cartProductIds),
      builder: (context, snapshot) {
        final products = (snapshot.data ?? const <Product>[])
            .where((product) => !cartProductIds.contains(product.id))
            .take(8)
            .toList();

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: SizedBox(height: 202),
          );
        }

        if (products.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          decoration: BoxDecoration(
            color: cardSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.add_shopping_cart_rounded,
                    color: priceGreen,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    "You may also like this",
                    style: TextStyle(
                      color: darkText,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 202,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.hardEdge,
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _buildSuggestionCard(
                      context: context,
                      cart: cart,
                      product: product,
                      cardBorder: cardBorder,
                      cardSurface: cardSurface,
                      softSurface: softSurface,
                      darkText: darkText,
                      mutedText: mutedText,
                      actionBlue: actionBlue,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentlyViewedProducts({
    required BuildContext context,
    required CartProvider cart,
    required Color cardBorder,
    required Color cardSurface,
    required Color softSurface,
    required Color darkText,
    required Color mutedText,
    required Color actionBlue,
    required Color priceGreen,
  }) {
    return FutureBuilder<List<Product>>(
      future: _recentlyViewedFuture,
      builder: (context, snapshot) {
        final products = (snapshot.data ?? const <Product>[]).take(8).toList();

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: SizedBox(height: 202),
          );
        }

        if (products.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          decoration: BoxDecoration(
            color: cardSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    color: actionBlue,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    "Recently viewed",
                    style: TextStyle(
                      color: darkText,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 202,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.hardEdge,
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _buildSuggestionCard(
                      context: context,
                      cart: cart,
                      product: product,
                      cardBorder: cardBorder,
                      cardSurface: cardSurface,
                      softSurface: softSurface,
                      darkText: darkText,
                      mutedText: mutedText,
                      actionBlue: actionBlue,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuggestionCard({
    required BuildContext context,
    required CartProvider cart,
    required Product product,
    required Color cardBorder,
    required Color cardSurface,
    required Color softSurface,
    required Color darkText,
    required Color mutedText,
    required Color actionBlue,
  }) {
    final price = double.tryParse(product.price) ?? 0;
    return SizedBox(
      width: 118,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
          decoration: BoxDecoration(
            color: cardSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 70,
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: softSurface,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: AppCachedImage(
                  url: product.image,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 40,
                child: Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: darkText,
                    fontSize: 10.8,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                price > 0 ? "\u20B9${price.toStringAsFixed(0)}" : "View price",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: price > 0 ? darkText : mutedText,
                  fontSize: 11.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                width: double.infinity,
                height: 28,
                child: OutlinedButton(
                  onPressed: price <= 0
                      ? null
                      : () {
                          cart.addToCart(
                            CartItem(
                              id: product.id,
                              name: product.name,
                              image: product.image,
                              price: price,
                            ),
                          );
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: actionBlue,
                    side: BorderSide(color: actionBlue.withOpacity(0.45)),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: const Text(
                    "Add",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
