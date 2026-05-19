import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../services/data_manager.dart';
import '../services/woo_service.dart';
import '../widgets/skeletons.dart';
import 'products_screen.dart';

class SaleProductsScreen extends StatefulWidget {
  const SaleProductsScreen({
    super.key,
    required this.collectionKey,
    required this.title,
  });

  final String collectionKey;
  final String title;

  @override
  State<SaleProductsScreen> createState() => _SaleProductsScreenState();
}

class _SaleProductsScreenState extends State<SaleProductsScreen> {
  final WooService _api = WooService();
  final DataManager _dataManager = DataManager();

  List<Product> _products = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isCollectionEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isCollectionEnabled = true;
    });

    try {
      final payload = await _dataManager.getSaleCollection(
        widget.collectionKey,
        perPage: 50,
      );
      final rawItems = payload["items"];
      if (rawItems is! List) {
        throw const FormatException("Sale collection items missing");
      }
      final parsed = rawItems
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(Product.fromJson)
          .where(_isValidProduct)
          .toList();
      final enabled = payload["enabled"] != false;
      final message = payload["message"]?.toString();

      if (!mounted) return;
      setState(() {
        _products = parsed;
        _isLoading = false;
        _isCollectionEnabled = enabled;
        _errorMessage = enabled ? null : (message ?? "This sale is disabled.");
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _products = [];
        _isLoading = false;
        _isCollectionEnabled = true;
        _errorMessage =
            "Sale products load nahi ho paaye. WooCommerce plugin/endpoint check karein.";
      });
    }
  }

  bool _isValidProduct(Product product) {
    final image = product.image.trim();
    final hasValidImage =
        image.isNotEmpty && image.toLowerCase().startsWith("http");
    final price = double.tryParse(product.price.replaceAll(",", "").trim());
    return hasValidImage && price != null && price > 0;
  }

  String get _badgeLabel {
    switch (widget.collectionKey) {
      case "daily_sale":
        return "Daily Sale";
      case "big_days_sale":
        return "Big Days";
      default:
        return widget.title;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RacingColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            color: RacingColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: RacingColors.panelBg,
        iconTheme: const IconThemeData(color: RacingColors.textPrimary),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [RacingColors.scaffoldBgSoft, RacingColors.scaffoldBg],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _loadProducts,
          child: _isLoading
              ? const ProductsGridSkeleton(
                  padding: EdgeInsets.all(12),
                  childAspectRatio: 0.56,
                )
              : _products.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        Icon(
                          _errorMessage == null
                              ? Icons.local_offer_outlined
                              : Icons.wifi_off_rounded,
                          size: 52,
                          color: RacingColors.textMuted,
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            _errorMessage == null
                                ? "No products selected yet."
                                : _isCollectionEnabled
                                    ? "Sale products unavailable."
                                    : "Sale disabled by admin.",
                            style: const TextStyle(
                              color: RacingColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            _errorMessage ??
                                "WooCommerce me is sale collection me products add karne ke baad yahan dikh jayenge.",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: RacingColors.textMuted,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _products.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.56,
                      ),
                      itemBuilder: (context, index) {
                        return ProductCard(
                          product: _products[index],
                          badgeLabel: _badgeLabel,
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
