import 'package:flutter/material.dart';
import '../services/data_manager.dart';
import '../services/share_service.dart';
import '../models/product_model.dart';
import 'product_detail_screen.dart';
import '../widgets/app_cached_image.dart';
import '../widgets/skeletons.dart';

class CategoryProductsScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const CategoryProductsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final DataManager dataManager = DataManager();
  late Future<List> products;

  // KTM Theme Colors
  final Color ktmOrange = const Color(0xFFFF6600);
  final Color ktmBlack = const Color(0xFF000000);
  final Color lightBackground = const Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    products = dataManager.getCategoryProducts(widget.categoryId);
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    return Scaffold(
      backgroundColor: lightBackground,
      appBar: AppBar(
        title: Text(
          widget.categoryName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: ktmBlack,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Share category",
            onPressed: () => ShareService.instance.shareCategory(
              context: context,
              categoryId: widget.categoryId,
              categoryName: widget.categoryName,
            ),
            icon: const Icon(Icons.share_rounded, color: Colors.white),
          ),
        ],
      ),
      body: FutureBuilder(
        future: products,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ProductsGridSkeleton(
              padding: EdgeInsets.all(10),
              childAspectRatio: 0.54,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "No products found",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          List data = snapshot.data!;
          List<Product> productList = data
              .map((e) => Product.fromJson(e))
              .toList();

          return GridView.builder(
            padding: EdgeInsets.fromLTRB(10, 10, 10, 10 + safeBottom + 8),
            itemCount: productList.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.54,
            ),
            itemBuilder: (context, index) {
              Product product = productList[index];

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(product: product),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
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
                      // ✅ Image Container
                      AspectRatio(
                        aspectRatio: 1.1,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(15),
                          ),
                          child: AppCachedImage(
                            url: product.image,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      // ✅ Product Details
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  tooltip: "Share product",
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  padding: EdgeInsets.zero,
                                  onPressed: () => ShareService.instance
                                      .shareProduct(context, product),
                                  icon: Icon(
                                    Icons.share_rounded,
                                    color: ktmOrange,
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    "\u20B9${product.price}",
                                    style: TextStyle(
                                      color: ktmOrange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (product.hasDiscount)
                                    Text(
                                      "\u20B9${product.regularPrice}",
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  if (product.discountPercent > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ktmOrange,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        "${product.discountPercent}% OFF",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const Text(
                                "or ₹867/month with Snapmint",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // KTM Style Add to Cart Button
                              SizedBox(
                                width: double.infinity,
                                height: 35,
                                child: ElevatedButton(
                                  onPressed: () {
                                    // TODO: Add to cart API logic
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "${product.name} added to cart",
                                        ),
                                        backgroundColor: ktmOrange,
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ktmBlack,
                                    foregroundColor: Colors.white,
                                    // 🛑 FIX: Padding kam ki tak text na kate
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      "ADD TO BAG",
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0,
                                      ),
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}
