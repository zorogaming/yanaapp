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
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.textPrimary),
        title: Text(
          'Wishlist',
          style: TextStyle(
            color: palette.textPrimary,
            fontWeight: FontWeight.w700,
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
                      color: palette.accent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No products in your wishlist yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.textMuted,
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [palette.heroStart, palette.heroEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: palette.surface.withOpacity(0.82),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.favorite_rounded,
                          color: palette.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${wishlist.items.length} saved product${wishlist.items.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap any item to open details or remove it anytime.',
                              style: TextStyle(
                                color: palette.textMuted,
                                fontSize: 11,
                              ),
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemBuilder: (context, index) {
                    final product = wishlist.items[index];
                    final isInCart = cart.items.any(
                      (item) => item.id == product.id && item.variationId == null,
                    );
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(product: product),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: palette.border),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 72,
                                height: 72,
                                child: AppCachedImage(
                                  url: product.image,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: palette.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '\u20B9${product.price}',
                                    style: TextStyle(
                                      color: palette.accent,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    product.isInStock ? 'In Stock' : 'Out of Stock',
                                    style: TextStyle(
                                      color: product.isInStock
                                          ? palette.accent
                                          : palette.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 36,
                                    child: ElevatedButton.icon(
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
                                                          ? '${product.name} quantity updated in bag'
                                                          : '${product.name} added to bag',
                                                    ),
                                                  ),
                                                );
                                            }
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isInCart
                                            ? palette.surfaceStrong
                                            : palette.accent,
                                        disabledBackgroundColor:
                                            palette.surfaceStrong,
                                        foregroundColor: isInCart
                                            ? palette.textPrimary
                                            : palette.onAccent,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 0,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      icon: Icon(
                                        isInCart
                                            ? Icons.shopping_bag_rounded
                                            : Icons.add_shopping_cart_rounded,
                                        size: 16,
                                      ),
                                      label: Text(
                                        product.isInStock
                                            ? (isInCart
                                                  ? 'Add Again'
                                                  : 'Add to Bag')
                                            : 'Out of Stock',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                wishlist.toggle(
                                  product,
                                  source: 'wishlist_screen',
                                );
                              },
                              icon: Icon(
                                Icons.favorite_rounded,
                                color: palette.accent,
                              ),
                            ),
                          ],
                        ),
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
