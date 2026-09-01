import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../services/data_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/app_cached_image.dart';
import '../widgets/skeletons.dart';
import 'product_detail_screen.dart';
import 'products_screen.dart';

class BikeGarageScreen extends StatefulWidget {
  const BikeGarageScreen({super.key});

  @override
  State<BikeGarageScreen> createState() => _BikeGarageScreenState();
}

class _BikeGarageScreenState extends State<BikeGarageScreen> {
  final DataManager _dataManager = DataManager();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String _selectedBike = "";
  List<String> _bikeOptions = const <String>[];
  List<Map<String, dynamic>> _suggestedCategories = const <Map<String, dynamic>>[];
  List<Product> _suggestedProducts = const <Product>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final options = await _dataManager.getBikeGarageOptions();
    final selected = await _dataManager.getSelectedBike() ?? "";

    List<Map<String, dynamic>> categories = const <Map<String, dynamic>>[];
    List<Product> products = const <Product>[];
    if (selected.isNotEmpty) {
      categories = await _dataManager.getSuggestedCategoriesForBike(selected);
      final rawProducts = await _dataManager.getSuggestedProductsForBike(selected);
      products = rawProducts
          .whereType<Map>()
          .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    if (!mounted) return;
    setState(() {
      _bikeOptions = options;
      _selectedBike = selected;
      _suggestedCategories = categories;
      _suggestedProducts = products;
      _loading = false;
    });
  }

  Future<void> _selectBike(String bikeName) async {
    await _dataManager.setSelectedBike(bikeName);
    await _load();
  }

  Future<void> _clearBike() async {
    await _dataManager.clearSelectedBike();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _bikeOptions.where((bike) {
      if (query.isEmpty) return true;
      return bike.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text("Bike Garage", style: TextStyle(color: palette.textPrimary)),
        backgroundColor: palette.surface,
        iconTheme: IconThemeData(color: palette.textPrimary),
        actions: [
          if (_selectedBike.isNotEmpty)
            IconButton(
              onPressed: _clearBike,
              tooltip: "Remove bike",
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: _loading
          ? const FullPageSkeleton()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Add Your Bike",
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Bike select karte hi uske according categories aur products suggest honge.",
                        style: TextStyle(color: palette.textMuted, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(color: palette.textPrimary),
                        decoration: InputDecoration(
                          hintText: "Search your bike",
                          hintStyle: TextStyle(color: palette.textMuted),
                          filled: true,
                          fillColor: palette.surfaceStrong,
                          prefixIcon: Icon(Icons.search, color: palette.accent),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      if (_selectedBike.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: palette.surfaceStrong,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: palette.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.two_wheeler, color: palette.accent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Selected Bike: $_selectedBike",
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                  Text(
                    "Available Bikes",
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: filtered.take(80).map((bike) {
                    final selected = bike == _selectedBike;
                    return ChoiceChip(
                      label: Text(bike),
                      selected: selected,
                      selectedColor: palette.accent,
                      backgroundColor: palette.surface,
                      labelStyle: TextStyle(
                        color: selected ? Colors.black : palette.textPrimary,
                      ),
                      onSelected: (_) => _selectBike(bike),
                    );
                  }).toList(),
                ),
                if (_selectedBike.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    "Suggested Categories",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_suggestedCategories.isEmpty)
                    const Text(
                      "Is bike ke liye direct category match nahi mila.",
                      style: TextStyle(color: Colors.white70),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _suggestedCategories.map((category) {
                        final categoryId =
                            int.tryParse((category["id"] ?? "").toString()) ?? 0;
                        final title = (category["name"] ?? "").toString();
                        return ActionChip(
                          backgroundColor: const Color(0xFF1C1F2E),
                          label: Text(
                            title,
                            style: const TextStyle(color: Colors.white),
                          ),
                          onPressed: categoryId <= 0
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProductsScreen(
                                        categoryId: categoryId,
                                        title: title,
                                      ),
                                    ),
                                  );
                                },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    "Products For Your Bike",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_suggestedProducts.isEmpty)
                    const Text(
                      "Abhi product suggestions nahi mile.",
                      style: TextStyle(color: Colors.white70),
                    )
                  else
                    ..._suggestedProducts.take(8).map((product) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1F2E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: AppCachedImage(
                                url: product.image,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          title: Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Text(
                                "\u20B9${product.price}",
                                style: const TextStyle(
                                  color: Color(0xFFFFB36B),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (product.hasDiscount)
                                Text(
                                  "\u20B9${product.regularPrice}",
                                  style: const TextStyle(color: Colors.white54, fontSize: 11, decoration: TextDecoration.lineThrough),
                                ),
                              if (product.discountPercent > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(color: const Color(0xFFFFB36B), borderRadius: BorderRadius.circular(999)),
                                  child: Text("${product.discountPercent}% OFF", style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w800)),
                                ),
                            ],
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white54,
                            size: 16,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductDetailScreen(product: product),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                ],
              ],
            ),
    );
  }
}
