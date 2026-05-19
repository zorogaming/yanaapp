import 'package:flutter/material.dart';
import '../services/woo_service.dart';
import '../models/product_model.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_cached_image.dart';
import '../widgets/skeletons.dart';
import 'product_detail_screen.dart';

class SearchResultScreen extends StatefulWidget {
  final String searchQuery;

  const SearchResultScreen({
    super.key,
    required this.searchQuery,
  });

  @override
  State<SearchResultScreen> createState() => _SearchResultScreenState();
}

class _SearchResultScreenState extends State<SearchResultScreen> {
  final WooService api = WooService();
  final ScrollController _scrollController = ScrollController();

  List<Product> products = [];
  int currentPage = 1;
  int totalProducts = 0;
  int totalPages = 0;
  bool isLoading = false;
  bool hasMore = true;

  String? orderBy;
  String order = "desc";

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreen("search_results");
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
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchProducts({bool loadMore = false}) async {
    if (isLoading) return;

    setState(() => isLoading = true);

    try {
      final result = await api.searchProductsSmart(
        query: widget.searchQuery,
        page: currentPage,
        orderBy: orderBy,
        order: order,
      );

      final newProducts =
          result.items.map<Product>((e) => Product.fromJson(e)).toList();

      setState(() {
        if (loadMore) {
          products.addAll(newProducts);
        } else {
          products = newProducts;
        }

        totalProducts = result.totalProducts;
        totalPages = result.totalPages;
        hasMore = totalPages > 0 ? currentPage < totalPages : false;
        isLoading = false;
      });

      if (!loadMore) {
        AnalyticsService.instance.logSearch(
          query: widget.searchQuery,
          resultsCount: newProducts.length,
          source: "search_results_screen",
        );
      }
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

  void applyFilter(String value) {
    setState(() {
      currentPage = 1;
      hasMore = true;
      totalProducts = 0;
      totalPages = 0;
      products.clear();

      if (value == "low") {
        orderBy = "price";
        order = "asc";
      } else if (value == "high") {
        orderBy = "price";
        order = "desc";
      } else if (value == "latest") {
        orderBy = "date";
        order = "desc";
      } else {
        orderBy = null;
        order = "desc";
      }
    });

    fetchProducts();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          "Search: ${widget.searchQuery}",
          style: TextStyle(color: palette.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: palette.textPrimary),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          currentPage = 1;
          hasMore = true;
          totalProducts = 0;
          totalPages = 0;
          products.clear();
          await fetchProducts();
        },
        child: Column(
          children: [
            Container(
              color: palette.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Sort By:",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: palette.textMuted,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: palette.surfaceStrong,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: palette.border),
                    ),
                    child: DropdownButton<String>(
                      value: orderBy == null
                          ? "default"
                          : orderBy == "price" && order == "asc"
                              ? "low"
                              : orderBy == "price" && order == "desc"
                                  ? "high"
                                  : "latest",
                      underline: const SizedBox(),
                      dropdownColor: palette.surface,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "default",
                          child: Text("Default"),
                        ),
                        DropdownMenuItem(
                          value: "low",
                          child: Text("Price: Low to High"),
                        ),
                        DropdownMenuItem(
                          value: "high",
                          child: Text("Price: High to Low"),
                        ),
                        DropdownMenuItem(
                          value: "latest",
                          child: Text("Latest"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          applyFilter(value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: palette.surface,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMetaChip(
                    "${totalProducts > 0 ? totalProducts : products.length} matches",
                    palette,
                  ),
                  _buildMetaChip("Name + SKU + half text search", palette),
                  if (totalPages > 0) _buildMetaChip("Pages: $totalPages", palette),
                ],
              ),
            ),
            Expanded(
              child: products.isEmpty && isLoading
                  ? const ProductsGridSkeleton(
                      padding: EdgeInsets.all(10),
                      childAspectRatio: 0.60,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    )
                  : products.isEmpty && !isLoading
                      ? Center(
                          child: Text(
                            "No products found.",
                            style: TextStyle(color: palette.textPrimary),
                          ),
                        )
                      : GridView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.fromLTRB(
                            10,
                            10,
                            10,
                            10 + safeBottom + 8,
                          ),
                          itemCount: products.length + (hasMore ? 1 : 0),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.60,
                          ),
                          itemBuilder: (context, index) {
                            if (index == products.length) {
                              return const ProductCardSkeleton();
                            }

                            final product = products[index];
                            final displaySku = product.sku.trim();
                            final isOutOfStock = !product.isInStock;

                            return Container(
                              decoration: BoxDecoration(
                                color: palette.surface,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: palette.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ProductDetailScreen(
                                              product: product,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: const BorderRadius.vertical(
                                              top: Radius.circular(15),
                                            ),
                                            child: Container(
                                              width: double.infinity,
                                              color: palette.surfaceStrong,
                                              child: AppCachedImage(
                                                url: product.image,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                          if (isOutOfStock)
                                            Positioned(
                                              top: 10,
                                              left: 10,
                                              right: 10,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  gradient: const LinearGradient(
                                                    colors: [
                                                      Color(0xFFE53935),
                                                      Color(0xFFB71C1C),
                                                    ],
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                child: const Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .remove_shopping_cart_rounded,
                                                      color: Colors.white,
                                                      size: 15,
                                                    ),
                                                    SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        "OUT OF STOCK",
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w900,
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
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: palette.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        if (displaySku.isNotEmpty) ...[
                                          Text(
                                            "SKU: $displaySku",
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: palette.textMuted,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            Text(
                                              "\u20B9${product.price}",
                                              style: TextStyle(
                                                color: palette.accent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            if (product.hasDiscount)
                                              Text(
                                                "\u20B9${product.regularPrice}",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: palette.textMuted,
                                                  decoration: TextDecoration
                                                      .lineThrough,
                                                ),
                                              ),
                                            if (product.discountPercent > 0)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: palette.accent,
                                                  borderRadius:
                                                      BorderRadius.circular(999),
                                                ),
                                                child: Text(
                                                  "${product.discountPercent}% OFF",
                                                  style: const TextStyle(
                                                    color: Colors.black,
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
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaChip(String label, AppThemePalette palette) {
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
