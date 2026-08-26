import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_cached_image.dart';
import 'product_detail_screen.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final pageBg = palette.background;
    final cardBorder = palette.border;
    final darkText = palette.textPrimary;
    final mutedText = palette.textMuted;
    final actionColor = palette.accent;
    final priceGreen = palette.success;
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        shadowColor: palette.border,
        iconTheme: IconThemeData(color: darkText),
        title: Text(
          'Wishlist',
          style: TextStyle(
            color: darkText,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Consumer2<WishlistProvider, CartProvider>(
        builder: (context, wishlist, cart, child) {
          if (!wishlist.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          if (wishlist.items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 44,
                      color: actionColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No products in your wishlist yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: mutedText,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: palette.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.favorite_rounded,
                          color: actionColor,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${wishlist.items.length} saved product${wishlist.items.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                color: darkText,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Saved picks are ready to move into cart.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: mutedText, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                  itemBuilder: (context, index) {
                    final product = wishlist.items[index];
                    final isInCart = cart.items.any(
                      (item) => item.id == product.id && item.variationId == null,
                    );
                    return Container(
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              palette.isLight ? 0.04 : 0.18,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProductDetailScreen(product: product),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 94,
                                    height: 104,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: palette.surfaceStrong,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: AppCachedImage(
                                        url: product.image,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
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
                                          product.isInStock
                                              ? 'In stock  |  Ready for cart'
                                              : 'Out of Stock',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: product.isInStock
                                                ? priceGreen
                                                : mutedText,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '\u20B9${product.price}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: darkText,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 17,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Divider(height: 1, color: cardBorder),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: () {
                                    wishlist.toggle(
                                      product,
                                      source: 'wishlist_screen',
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: mutedText,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 9),
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Remove',
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
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ProductDetailScreen(product: product),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: mutedText,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 9),
                                  ),
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'View',
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
                                  onPressed: product.isInStock
                                      ? () {
                                          cart.addToCart(
                                            CartItem(
                                              id: product.id,
                                              name: product.name,
                                              image: product.image,
                                              price: product.priceValue ?? 0,
                                              variationId: null,
                                            ),
                                          );
                                          ScaffoldMessenger.of(context)
                                            ..hideCurrentSnackBar()
                                            ..showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  isInCart
                                                      ? '${product.name} quantity updated in cart'
                                                      : '${product.name} added to cart',
                                                ),
                                              ),
                                            );
                                        }
                                      : null,
                                  style: TextButton.styleFrom(
                                    foregroundColor: actionColor,
                                    disabledForegroundColor: mutedText,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 9),
                                  ),
                                  icon: Icon(
                                    isInCart
                                        ? Icons.shopping_bag_rounded
                                        : Icons.add_shopping_cart_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    product.isInStock
                                        ? (isInCart ? 'Add Again' : 'Add to Cart')
                                        : 'Out of Stock',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
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
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: wishlist.items.length,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
