import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'woo_service.dart';

class DataManager {
  final WooService api = WooService();
  static bool _hasFetchedGroupedCategoriesThisLaunch = false;

  static const String homeProductsKey = "home_products";
  static const String homeProcVersionKey = "home_proc_version";
  static const String homeCategoriesKey = "home_categories";
  static const String homeCategoriesVersionKey = "home_categories_version";
  static const String topBrandsNamesKey = "top_brands_names";
  static const String topBrandsVersionKey = "top_brands_version";
  static const String topBrandCategoriesKey = "top_brand_categories";
  static const String topBrandCategoriesVersionKey = "top_brand_categories_version";
  static const String newArrivalProductsKey = "new_arrival_products";
  static const String newArrivalProductsVersionKey =
      "new_arrival_products_version";
  static const String bestSellingProductsKey = "best_selling_products";
  static const String bestSellingProductsVersionKey =
      "best_selling_products_version";
  static const String productPriceSnapshotKey = "product_price_snapshot_v1";
  static const int homeLatestProductsLimit = 10;
  static const String bikeGarageSelectedKey = "bike_garage_selected_bike";
  static const String bikeGarageOptionsKey = "bike_garage_options";
  static const String saleCollectionPrefix = "sale_collection_";
  static const String saleCollectionVersionPrefix = "sale_collection_version_";

  // ================= HOME PRODUCTS =================

  Future<List<dynamic>> getHomeProducts({
    int page = 1,
    String? search,
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 🔥 If pagination or search → direct API (NO CACHE)
    if (page > 1 || (search != null && search.isNotEmpty)) {
      final data = await api.fetchProducts(
        perPage: homeLatestProductsLimit,
        page: page,
        search: search,
        orderBy: "date",
        order: "desc",
      );
      return annotateProductsWithPriceDrops(data);
    }

    // 🔥 First check cache
    String? cachedData = prefs.getString(homeProductsKey);
    // ✅ If cache exists → RETURN IMMEDIATELY (NO WAIT)
    if (!forceRefresh && cachedData != null) {
      return jsonDecode(cachedData);
    }

    // ❌ No cache → First time fetch
    return await _fetchAndCacheHomeProducts();
  }

  // ================= PRIVATE METHODS =================

  Future<List<dynamic>> _fetchAndCacheHomeProducts() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final freshData = await api.fetchProducts(
        perPage: homeLatestProductsLimit,
        page: 1,
        orderBy: "date",
        order: "desc",
      );

      final procResponse = await http
          .get(Uri.parse("https://yanaworldwide.store/Yanaapp/proc.txt"))
          .timeout(const Duration(seconds: 6));

      String serverProcVersion =
          procResponse.statusCode == 200 ? procResponse.body.trim() : "1";

      final annotatedData = await annotateProductsWithPriceDrops(freshData);
      await prefs.setString(homeProductsKey, jsonEncode(annotatedData));
      await prefs.setString(homeProcVersionKey, serverProcVersion);

      return annotatedData;
    } catch (e) {
      print("Home fetch error: $e");
      return [];
    }
  }

  // ================= HOME CATEGORIES =================

  Future<Map<String, List>> getGroupedCategoriesWithData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(homeCategoriesKey);
    final savedVersion = prefs.getString(homeCategoriesVersionKey);

    if (_hasFetchedGroupedCategoriesThisLaunch) {
      if (cachedData != null) {
        return _decodeGroupedCategories(cachedData);
      }
      return await _fetchAndCacheGroupedCategories();
    }

    try {
      if (cachedData != null) {
        final serverVersion = await api.fetchAppVersion();
        _hasFetchedGroupedCategoriesThisLaunch = true;
        if (serverVersion == null || serverVersion == savedVersion) {
          return _decodeGroupedCategories(cachedData);
        }
      }

      final freshData = await _fetchAndCacheGroupedCategories();
      _hasFetchedGroupedCategoriesThisLaunch = true;
      return freshData;
    } catch (_) {
      _hasFetchedGroupedCategoriesThisLaunch = true;
      if (cachedData != null) {
        return _decodeGroupedCategories(cachedData);
      }
      return {};
    }
  }

  Future<List<dynamic>> getBestSellingProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(bestSellingProductsKey);
    final savedVersion = prefs.getString(bestSellingProductsVersionKey);

    if (cached != null) {
      try {
        final serverVersion = await api.fetchAppVersion();
        if (serverVersion == null || serverVersion == savedVersion) {
          return List<dynamic>.from(jsonDecode(cached) as List);
        }
      } catch (_) {
        return List<dynamic>.from(jsonDecode(cached) as List);
      }
    }

    return _fetchAndCacheBestSellingProducts();
  }

  Future<List<dynamic>> getNewArrivalProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(newArrivalProductsKey);
    final savedVersion = prefs.getString(newArrivalProductsVersionKey);

    if (cached != null) {
      try {
        final serverVersion = await api.fetchAppVersion();
        if (serverVersion == null || serverVersion == savedVersion) {
          return List<dynamic>.from(jsonDecode(cached) as List);
        }
      } catch (_) {
        return List<dynamic>.from(jsonDecode(cached) as List);
      }
    }

    return _fetchAndCacheNewArrivalProducts();
  }

  Future<List<dynamic>> _fetchAndCacheNewArrivalProducts() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final freshData = await api.fetchProducts(
        perPage: 10,
        page: 1,
        orderBy: "date",
        order: "desc",
      );
      final serverVersion = await api.fetchAppVersion() ?? "1";
      final annotatedData = await annotateProductsWithPriceDrops(freshData);
      await prefs.setString(newArrivalProductsKey, jsonEncode(annotatedData));
      await prefs.setString(newArrivalProductsVersionKey, serverVersion);
      return annotatedData;
    } catch (e) {
      print("New arrival products fetch error: $e");
      return const [];
    }
  }

  Future<List<dynamic>> _fetchAndCacheBestSellingProducts() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final freshData = await api.fetchProducts(
        perPage: 10,
        page: 1,
        orderBy: "popularity",
        order: "desc",
      );
      final serverVersion = await api.fetchAppVersion() ?? "1";
      final annotatedData = await annotateProductsWithPriceDrops(freshData);
      await prefs.setString(bestSellingProductsKey, jsonEncode(annotatedData));
      await prefs.setString(bestSellingProductsVersionKey, serverVersion);
      return annotatedData;
    } catch (e) {
      print("Best selling products fetch error: $e");
      return const [];
    }
  }

  Future<Map<String, List>> _fetchAndCacheGroupedCategories() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final freshData = await api.fetchGroupedCategoriesWithData();
      final serverVersion = await api.fetchAppVersion() ?? "1";

      // Important: empty categories list is also a valid latest state.
      await prefs.setString(homeCategoriesKey, jsonEncode(freshData));
      await prefs.setString(homeCategoriesVersionKey, serverVersion);

      return freshData;
    } catch (e) {
      print("Home categories fetch error: $e");
      return {};
    }
  }

  Map<String, List> _decodeGroupedCategories(String cachedData) {
    final decoded = jsonDecode(cachedData) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, List.from(value)));
  }

  Future<List<String>> getTopBrandsNames() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(topBrandsNamesKey);
    final savedVersion = prefs.getString(topBrandsVersionKey);

    if (cached != null) {
      try {
        final serverVersion = await api.fetchAppVersion();
        if (serverVersion == null || serverVersion == savedVersion) {
          return _decodeTopBrands(cached);
        }
        final fresh = await _fetchAndCacheTopBrands();
        return fresh;
      } catch (_) {
        return _decodeTopBrands(cached);
      }
    }

    return _fetchAndCacheTopBrands();
  }

  Future<List<String>> _fetchAndCacheTopBrands() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final response = await http
          .get(Uri.parse("https://yanaworldwide.store/topbrands.txt"))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return const [];
      }
      final names = _parseTopBrandsText(response.body);
      final serverVersion = await api.fetchAppVersion() ?? "1";
      await prefs.setString(topBrandsNamesKey, jsonEncode(names));
      await prefs.setString(topBrandsVersionKey, serverVersion);
      return names;
    } catch (e) {
      print("Top brands fetch error: $e");
      return const [];
    }
  }

  Future<List<dynamic>> getTopBrandCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(topBrandCategoriesKey);
    final savedVersion = prefs.getString(topBrandCategoriesVersionKey);

    if (cached != null) {
      try {
        final serverVersion = await api.fetchAppVersion();
        if (serverVersion == null || serverVersion == savedVersion) {
          return List<dynamic>.from(jsonDecode(cached) as List);
        }
      } catch (_) {
        return List<dynamic>.from(jsonDecode(cached) as List);
      }
    }

    return _fetchAndCacheTopBrandCategories();
  }

  Future<List<dynamic>> _fetchAndCacheTopBrandCategories() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final topNames = await getTopBrandsNames();
      final categories = await api.fetchTopBrandCategories(topNames);
      final serverVersion = await api.fetchAppVersion() ?? "1";
      await prefs.setString(topBrandCategoriesKey, jsonEncode(categories));
      await prefs.setString(topBrandCategoriesVersionKey, serverVersion);
      return categories;
    } catch (e) {
      print("Top brand categories cache error: $e");
      return const [];
    }
  }

  List<String> _decodeTopBrands(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  List<String> _parseTopBrandsText(String text) {
    final out = <String>[];
    final seen = <String>{};
    final normalized = text.replaceAll("\r", "\n").replaceAll(",", "\n");
    for (final line in normalized.split("\n")) {
      final value = line.trim();
      if (value.isEmpty) continue;
      final key = value.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(value);
    }
    return out;
  }

  // ================= CATEGORY PRODUCTS =================

  Future<List<dynamic>> getCategoryProducts(int categoryId) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _categoryProductsKey(categoryId);
    final versionKey = _categoryProcVersionKey(categoryId);
    final cachedData = prefs.getString(cacheKey);

    if (cachedData != null) {
      return jsonDecode(cachedData);
    }

    try {
      return await _fetchAndCacheCategoryProducts(
        categoryId: categoryId,
        cacheKey: cacheKey,
        versionKey: versionKey,
      );
    } catch (e) {
      print("Category live fetch fallback error: $e");
      return [];
    }
  }

  Future<List<dynamic>> _fetchAndCacheCategoryProducts({
    required int categoryId,
    required String cacheKey,
    required String versionKey,
  }) async {
    try {
      final freshData =
          await api.fetchProducts(page: 1, categoryId: categoryId);
      final serverProcVersion = await _fetchProcVersion();
      final annotatedData = await annotateProductsWithPriceDrops(freshData);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(annotatedData));
      await prefs.setString(versionKey, serverProcVersion);

      return annotatedData;
    } catch (e) {
      print("Category fetch error: $e");
      return [];
    }
  }

  Future<String> _fetchProcVersion() async {
    try {
      final response = await http
          .get(Uri.parse("https://yanaworldwide.store/Yanaapp/proc.txt"))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return response.body.trim();
      }
    } catch (_) {}
    return "1";
  }

  String _categoryProductsKey(int categoryId) => "category_$categoryId";

  String _categoryProcVersionKey(int categoryId) =>
      "category_${categoryId}_proc_version";

  Future<Map<String, dynamic>> getSaleCollection(
    String collectionKey, {
    int page = 1,
    int perPage = 50,
    bool preferCache = false,
  }) async {
    final normalizedKey = collectionKey.trim().toLowerCase();
    if (normalizedKey.isEmpty) {
      return const <String, dynamic>{"items": <dynamic>[]};
    }

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _saleCollectionCacheKey(normalizedKey);
    final versionKey = _saleCollectionVersionKey(normalizedKey);
    final cachedData = prefs.getString(cacheKey);
    if (preferCache && cachedData != null && cachedData.isNotEmpty) {
      final cachedPayload = _decodeSaleCollectionCache(cachedData);
      if (cachedPayload != null) return cachedPayload;
    }

    try {
      final freshData = await api.fetchSaleCollection(
        collectionKey: normalizedKey,
        page: page,
        perPage: perPage,
      );
      final serverVersion = await _fetchProcVersion();
      final annotatedData = await _annotateSaleCollectionWithPriceDrops(
        freshData,
      );

      if (page == 1 && perPage <= 50) {
        await prefs.setString(cacheKey, jsonEncode(annotatedData));
        await prefs.setString(versionKey, serverVersion);
      }

      return annotatedData;
    } catch (e) {
      print("Sale collection fetch error: $e");
      if (cachedData != null && cachedData.isNotEmpty) {
        final cachedPayload = _decodeSaleCollectionCache(cachedData);
        if (cachedPayload != null) return cachedPayload;
      }
      return const <String, dynamic>{"items": <dynamic>[]};
    }
  }

  Map<String, dynamic>? _decodeSaleCollectionCache(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  String _saleCollectionCacheKey(String collectionKey) =>
      "$saleCollectionPrefix$collectionKey";

  String _saleCollectionVersionKey(String collectionKey) =>
      "$saleCollectionVersionPrefix$collectionKey";

  Future<List<dynamic>> annotateProductsWithPriceDrops(
    List<dynamic> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final previousSnapshot = _decodePriceSnapshot(
      prefs.getString(productPriceSnapshotKey),
    );
    final nextSnapshot = Map<String, double>.from(previousSnapshot);
    final annotated = <dynamic>[];

    for (final item in items) {
      if (item is! Map) {
        annotated.add(item);
        continue;
      }

      final map = Map<String, dynamic>.from(item);
      final id = (map["id"] ?? "").toString().trim();
      final currentPrice = _productPriceValue(map);
      final previousPrice = id.isEmpty ? null : previousSnapshot[id];

      if (id.isNotEmpty &&
          currentPrice != null &&
          currentPrice > 0 &&
          previousPrice != null &&
          previousPrice > currentPrice) {
        map["_yana_price_drop"] = true;
        map["_yana_previous_price"] = previousPrice;
      } else {
        map.remove("_yana_price_drop");
        map.remove("_yana_previous_price");
      }

      if (id.isNotEmpty && currentPrice != null && currentPrice > 0) {
        nextSnapshot[id] = currentPrice;
      }
      annotated.add(map);
    }

    await prefs.setString(productPriceSnapshotKey, jsonEncode(nextSnapshot));
    return annotated;
  }

  Future<Map<String, dynamic>> _annotateSaleCollectionWithPriceDrops(
    Map<String, dynamic> collection,
  ) async {
    final items = collection["items"];
    if (items is! List) return collection;
    final annotatedItems = await annotateProductsWithPriceDrops(items);
    return Map<String, dynamic>.from(collection)..["items"] = annotatedItems;
  }

  Map<String, double> _decodePriceSnapshot(String? raw) {
    if (raw == null || raw.isEmpty) return <String, double>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, double>{};
      return decoded.map((key, value) {
        final parsed = double.tryParse((value ?? "").toString());
        return MapEntry(key.toString(), parsed ?? 0);
      })..removeWhere((_, value) => value <= 0);
    } catch (_) {
      return <String, double>{};
    }
  }

  double? _productPriceValue(Map<String, dynamic> item) {
    final raw = _firstNonEmpty([
      item["price"],
      item["sale_price"],
      item["regular_price"],
    ]);
    if (raw.isEmpty) return null;
    return double.tryParse(raw.replaceAll(",", "").trim());
  }

  List<dynamic> _mergeCategoryProducts({
    required List<dynamic> cachedItems,
    required List<dynamic> freshItems,
  }) {
    final cachedById = <String, Map<String, dynamic>>{};
    for (final item in cachedItems) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final id = (map["id"] ?? "").toString();
      if (id.isNotEmpty) {
        cachedById[id] = map;
      }
    }

    final merged = <dynamic>[];
    for (final item in freshItems) {
      if (item is! Map) {
        merged.add(item);
        continue;
      }

      final freshMap = Map<String, dynamic>.from(item);
      final id = (freshMap["id"] ?? "").toString();
      final cachedMap = cachedById[id];
      if (cachedMap == null) {
        merged.add(freshMap);
        continue;
      }

      if (_hasProductChanged(cachedMap, freshMap)) {
        merged.add(freshMap);
      } else {
        merged.add(cachedMap);
      }
    }

    return merged;
  }

  bool _hasProductChanged(
    Map<String, dynamic> cached,
    Map<String, dynamic> fresh,
  ) {
    final cachedModified = _firstNonEmpty([
      cached["date_modified_gmt"],
      cached["date_modified"],
      cached["modified"],
    ]);
    final freshModified = _firstNonEmpty([
      fresh["date_modified_gmt"],
      fresh["date_modified"],
      fresh["modified"],
    ]);

    if (cachedModified.isNotEmpty && freshModified.isNotEmpty) {
      return cachedModified != freshModified;
    }

    return jsonEncode(cached) != jsonEncode(fresh);
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = (value ?? "").toString().trim();
      if (text.isNotEmpty) return text;
    }
    return "";
  }

  // ================= OFFER TEXT =================

  Future<String> getOfferText() async {
    try {
      final response = await http.get(
        Uri.parse("https://yanaworldwide.store/Yanaapp/offer.txt"),
      );

      if (response.statusCode == 200) {
        return response.body.trim();
      }
    } catch (e) {}

    return "";
  }

  Future<List<String>> getBikeGarageOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(bikeGarageOptionsKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        final decoded = jsonDecode(cached);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    try {
      final response = await http
          .get(Uri.parse("https://yanaworldwide.store/Yanaapp/bike.txt"))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return const <String>[];
      final items = _parseBikeOptions(response.body);
      await prefs.setString(bikeGarageOptionsKey, jsonEncode(items));
      return items;
    } catch (e) {
      print("Bike garage options fetch error: $e");
      return const <String>[];
    }
  }

  List<String> _parseBikeOptions(String raw) {
    final items = <String>[];
    final seen = <String>{};
    final normalized = raw.replaceAll("\r", "\n");

    for (final line in normalized.split("\n")) {
      final value = line
          .replaceAll(RegExp(r"^[\-\*\d\.\)\s]+"), "")
          .trim();
      if (value.isEmpty) continue;
      if (value.startsWith("#")) continue;
      if (value.contains(":") && value.length < 25) continue;
      final key = value.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      items.add(value);
    }

    return items;
  }

  Future<String?> getSelectedBike() async {
    final prefs = await SharedPreferences.getInstance();
    final value = (prefs.getString(bikeGarageSelectedKey) ?? "").trim();
    return value.isEmpty ? null : value;
  }

  Future<void> setSelectedBike(String bikeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(bikeGarageSelectedKey, bikeName.trim());
  }

  Future<void> clearSelectedBike() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(bikeGarageSelectedKey);
  }

  Future<List<Map<String, dynamic>>> getSuggestedCategoriesForBike(
    String bikeName,
  ) async {
    final query = bikeName.trim();
    if (query.isEmpty) return const <Map<String, dynamic>>[];

    final categories = await api.fetchAllCategories();
    final terms = query
        .toLowerCase()
        .split(RegExp(r"[^a-z0-9]+"))
        .where((e) => e.length > 1)
        .toList();

    final matched = <Map<String, dynamic>>[];
    final seenIds = <int>{};

    for (final category in categories) {
      final id = int.tryParse((category["id"] ?? "").toString()) ?? 0;
      if (id <= 0 || seenIds.contains(id)) continue;
      final name = (category["name"] ?? "").toString().toLowerCase();
      final slug = (category["slug"] ?? "").toString().toLowerCase();
      final score = terms.where((term) => name.contains(term) || slug.contains(term)).length;
      if (score <= 0) continue;
      matched.add(category);
      seenIds.add(id);
      if (matched.length >= 8) break;
    }

    return matched;
  }

  Future<List<dynamic>> getSuggestedProductsForBike(
    String bikeName, {
    int limit = 10,
  }) async {
    final categories = await getSuggestedCategoriesForBike(bikeName);
    if (categories.isNotEmpty) {
      final categoryId = int.tryParse((categories.first["id"] ?? "").toString()) ?? 0;
      if (categoryId > 0) {
        return api.fetchProducts(perPage: limit, categoryId: categoryId);
      }
    }

    return api.fetchProducts(
      perPage: limit,
      search: bikeName.trim(),
      orderBy: "date",
      order: "desc",
    );
  }
}


