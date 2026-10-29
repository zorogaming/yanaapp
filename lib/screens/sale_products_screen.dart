import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../services/data_manager.dart';
import '../services/woo_service.dart';
import '../theme/app_theme.dart';
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
  final DataManager _dataManager = DataManager();

  List<Product> _products = [];
  final Map<int, List<Map<String, dynamic>>> _productCategories = {};
  bool _isLoading = true;
  String? _errorMessage;
  bool _isCollectionEnabled = true;
  String? _collectionLabel;
  int? _selectedCategoryId;
  String _priceSort = 'none';

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
      final categoriesByProduct = <int, List<Map<String, dynamic>>>{};
      for (final raw in rawItems.whereType<Map>()) {
        final json = Map<String, dynamic>.from(raw);
        final productId = int.tryParse('${json['id']}') ?? 0;
        final rawCategories = json['categories'];
        if (productId <= 0 || rawCategories is! List) continue;
        categoriesByProduct[productId] = rawCategories
            .whereType<Map>()
            .map((category) => Map<String, dynamic>.from(category))
            .toList(growable: false);
      }
      final categoryProducts = await WooService().fetchProductsByIds(
        parsed.map((product) => product.id).toList(growable: false),
        limit: parsed.length,
      );
      for (final json in categoryProducts) {
        final productId = int.tryParse('${json['id']}') ?? 0;
        final rawCategories = json['categories'];
        if (productId <= 0 || rawCategories is! List) continue;
        categoriesByProduct[productId] = rawCategories
            .whereType<Map>()
            .map((category) => Map<String, dynamic>.from(category))
            .toList(growable: false);
      }
      final enabled = payload["enabled"] != false;
      final message = payload["message"]?.toString();

      if (!mounted) return;
      setState(() {
        _products = parsed;
        _productCategories
          ..clear()
          ..addAll(categoriesByProduct);
        _isLoading = false;
        _isCollectionEnabled = enabled;
        _collectionLabel = payload['label']?.toString();
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
        return _collectionLabel ?? widget.title;
      default:
        return widget.title;
    }
  }

  List<Product> get _productsWithSaleBadge {
    if (widget.collectionKey != 'big_days_sale' || !_isCollectionEnabled) {
      return _products;
    }
    final label = (_collectionLabel ?? widget.title).trim();
    return _products
        .map(
          (product) => Product(
            id: product.id,
            name: product.name,
            price: product.price,
            regularPrice: product.regularPrice,
            salePrice: product.salePrice,
            image: product.image,
            galleryImages: product.galleryImages,
            description: product.description,
            shortDescription: product.shortDescription,
            type: product.type,
            sku: product.sku,
            stockStatus: product.stockStatus,
            isInStock: product.isInStock,
            priceDropped: product.priceDropped,
            previousPrice: product.previousPrice,
            averageRating: product.averageRating,
            ratingCount: product.ratingCount,
            saleBadgeLabel: label,
          ),
        )
        .toList(growable: false);
  }

  List<Map<String, dynamic>> get _categories {
    final categories = <int, Map<String, dynamic>>{};
    for (final raw in _products) {
      for (final category in _productCategories[raw.id] ?? const []) {
        final id = int.tryParse('${category['id']}') ?? 0;
        if (id > 0) categories[id] = Map<String, dynamic>.from(category);
      }
    }
    return categories.values.toList()
      ..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
  }

  List<Product> get _visibleProducts {
    final products = _productsWithSaleBadge.where((product) {
      if (_selectedCategoryId == null) return true;
      final raw = _products.firstWhere((item) => item.id == product.id);
      final categories = _productCategories[raw.id] ?? const [];
      return categories.any(
        (category) => int.tryParse('${category['id']}') == _selectedCategoryId,
      );
    }).toList();
    if (_priceSort == 'low_high') {
      products.sort((a, b) => (a.priceValue ?? 0).compareTo(b.priceValue ?? 0));
    } else if (_priceSort == 'high_low') {
      products.sort((a, b) => (b.priceValue ?? 0).compareTo(a.priceValue ?? 0));
    }
    return products;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 2,
        title: Text('', style: TextStyle(color: palette.textPrimary)),
        leadingWidth: 56,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.arrow_back_rounded, color: palette.accent, size: 23),
          tooltip: 'Back',
        ),
        flexibleSpace: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 58, right: 16),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: palette.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.accent.withOpacity(0.3)),
                  ),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    color: palette.accent,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _collectionLabel ?? widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 18,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Special offers for your ride',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isCollectionEnabled && !_isLoading)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x2224C86A),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x7724C86A)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 7, color: Color(0xFF24C86A)),
                        SizedBox(width: 5),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Color(0xFF24C86A),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        backgroundColor: palette.surface,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: palette.accent),
      ),
      body: RefreshIndicator(
        onRefresh: _loadProducts,
        child: _isLoading
            ? ListView.separated(
                padding: EdgeInsets.zero,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: 6,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, __) => const ProductListSkeleton(),
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
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (widget.collectionKey == 'big_days_sale')
                    SliverToBoxAdapter(child: _buildBigDaysControls(palette)),
                  if (_visibleProducts.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text('No products match these filters.'),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final product = _visibleProducts[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ProductCard(
                              product: product,
                              badgeLabel: _badgeLabel,
                            ),
                            const Divider(height: 1),
                          ],
                        );
                      }, childCount: _visibleProducts.length),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildBigDaysControls(AppThemePalette palette) {
    final categories = _categories;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 15, color: palette.accent),
              const SizedBox(width: 6),
              Text(
                'FILTER & SORT',
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.inventory_2_outlined,
                size: 14,
                color: palette.textMuted,
              ),
              const SizedBox(width: 5),
              Text(
                '${_visibleProducts.length} products',
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (categories.isNotEmpty)
                Expanded(
                  child: _filterDropdown<int?>(
                    palette: palette,
                    icon: Icons.category_outlined,
                    value: _selectedCategoryId,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('All categories'),
                      ),
                      ...categories.map(
                        (category) => DropdownMenuItem<int?>(
                          value: int.tryParse('${category['id']}'),
                          child: Text(
                            '${category['name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedCategoryId = value),
                  ),
                ),
              if (categories.isNotEmpty) const SizedBox(width: 9),
              Expanded(
                child: _filterDropdown<String>(
                  palette: palette,
                  icon: Icons.sort_rounded,
                  value: _priceSort,
                  items: const [
                    DropdownMenuItem(
                      value: 'none',
                      child: Text('Sort by price'),
                    ),
                    DropdownMenuItem(
                      value: 'low_high',
                      child: Text('Price: Low to High'),
                    ),
                    DropdownMenuItem(
                      value: 'high_low',
                      child: Text('Price: High to Low'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _priceSort = value ?? 'none'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown<T>({
    required AppThemePalette palette,
    required IconData icon,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 10, right: 7),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: palette.accent),
          const SizedBox(width: 7),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: palette.textMuted,
                ),
                dropdownColor: palette.surface,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
