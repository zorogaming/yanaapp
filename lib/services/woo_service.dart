import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/cart_item.dart';
import '../models/paginated_products_result.dart';
import 'auth_service.dart';

class WooService {
  static const String _fallbackCategoryImage =
      "https://yanaworldwide.store/yanaapp/blank.jpg";
  static const String _appVersionCacheKey = "app_version_cache";
  static const String _appVersionFetchedAtKey = "app_version_fetched_at";
  static const String _defaultTaxClassKey = "__standard__";
  static String? _sessionAppVersion;
  static bool _hasCheckedAppVersionThisLaunch = false;
  static Map<String, double>? _cachedTaxRatesByClass;
  static final Map<String, PaginatedProductsResult> _smartSearchCache = {};
  static const Map<String, String> _countryNameToCode = {
    "india": "IN",
    "united states": "US",
    "united kingdom": "GB",
    "australia": "AU",
    "canada": "CA",
    "germany": "DE",
    "france": "FR",
    "italy": "IT",
    "spain": "ES",
    "netherlands": "NL",
    "brazil": "BR",
    "russia": "RU",
    "china": "CN",
    "japan": "JP",
    "south korea": "KR",
    "indonesia": "ID",
    "malaysia": "MY",
    "singapore": "SG",
    "thailand": "TH",
    "united arab emirates": "AE",
    "saudi arabia": "SA",
    "south africa": "ZA",
    "sri lanka": "LK",
    "nepal": "NP",
    "bangladesh": "BD",
    "pakistan": "PK",
    "mexico": "MX",
    "argentina": "AR",
    "turkey": "TR",
    "new zealand": "NZ",
  };

  static double partialAdvanceRate(double totalAmount) {
    if (totalAmount > 10000) return 0.20;
    if (totalAmount > 5000) return 0.15;
    return 0.08;
  }

  static double partialAdvanceAmount(double totalAmount) {
    return totalAmount * partialAdvanceRate(totalAmount);
  }

  static double partialRemainingAmount(double totalAmount) {
    return totalAmount - partialAdvanceAmount(totalAmount);
  }

  Map<String, String> _wcHeaders({bool json = false}) {
    return {
      Config.appHeaderKey: Config.appHeaderValue,
      if (json) "Content-Type": "application/json",
    };
  }

  Uri _buildUri(String endpoint, Map<String, String> params) {
    final defaultParams = {
      "consumer_key": Config.consumerKey,
      "consumer_secret": Config.consumerSecret,
    };

    return Uri.parse(
      "${Config.baseUrl}$endpoint",
    ).replace(queryParameters: {...defaultParams, ...params});
  }

  Uri _buildWpV1Uri(String endpoint) {
    final base = Uri.parse(Config.baseUrl);
    final host = base.host;
    final scheme = base.scheme;
    return Uri.parse("$scheme://$host/wp-json/wp/v1/$endpoint");
  }

  String _normalizeTaxClassKey(String? raw) {
    final value = raw?.trim().toLowerCase() ?? "";
    return value.isEmpty ? _defaultTaxClassKey : value;
  }

  double? _parseMoney(dynamic raw) {
    if (raw == null) return null;
    final normalized = raw.toString().replaceAll(",", "").trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  String _formatMoney(double value) {
    final fixed = value.toStringAsFixed(2);
    if (fixed.endsWith(".00")) {
      return fixed.substring(0, fixed.length - 3);
    }
    if (fixed.endsWith("0")) {
      return fixed.substring(0, fixed.length - 1);
    }
    return fixed;
  }

  double _resolveTaxRateForClass(
    Map<String, double> ratesByClass,
    String? taxClass,
  ) {
    final classKey = _normalizeTaxClassKey(taxClass);
    return ratesByClass[classKey] ??
        ratesByClass[_defaultTaxClassKey] ??
        0.0;
  }

  String _applyDisplayTax({
    required dynamic rawPrice,
    required String taxStatus,
    required String? taxClass,
    required Map<String, double> ratesByClass,
  }) {
    final parsedPrice = _parseMoney(rawPrice);
    if (parsedPrice == null) {
      return rawPrice?.toString() ?? "";
    }

    if (taxStatus.trim().toLowerCase() != "taxable") {
      return _formatMoney(parsedPrice);
    }

    final rate = _resolveTaxRateForClass(ratesByClass, taxClass);
    if (rate <= 0) {
      return _formatMoney(parsedPrice);
    }

    final priceWithTax = parsedPrice * (1 + (rate / 100));
    return _formatMoney(priceWithTax);
  }

  Map<String, dynamic> _normalizeProductPricing(
    Map<String, dynamic> product,
    Map<String, double> ratesByClass,
  ) {
    final normalized = Map<String, dynamic>.from(product);
    final taxStatus = normalized["tax_status"]?.toString() ?? "";
    final taxClass = normalized["tax_class"]?.toString();

    normalized["price"] = _applyDisplayTax(
      rawPrice: normalized["price"],
      taxStatus: taxStatus,
      taxClass: taxClass,
      ratesByClass: ratesByClass,
    );
    normalized["regular_price"] = _applyDisplayTax(
      rawPrice: normalized["regular_price"],
      taxStatus: taxStatus,
      taxClass: taxClass,
      ratesByClass: ratesByClass,
    );
    normalized["sale_price"] = _applyDisplayTax(
      rawPrice: normalized["sale_price"],
      taxStatus: taxStatus,
      taxClass: taxClass,
      ratesByClass: ratesByClass,
    );
    return normalized;
  }

  Future<Map<String, double>> _getTaxRatesByClass() async {
    if (_cachedTaxRatesByClass != null) {
      return _cachedTaxRatesByClass!;
    }

    try {
      final response = await http
          .get(_buildUri("taxes", {"per_page": "100"}), headers: _wcHeaders())
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          final ratesByClass = <String, double>{};
          for (final rawItem in decoded) {
            if (rawItem is! Map) continue;
            final item = Map<String, dynamic>.from(rawItem);
            final classKey = _normalizeTaxClassKey(
              item["class"]?.toString(),
            );
            final parsedRate = _parseMoney(item["rate"]) ?? 0.0;
            if (parsedRate <= 0) continue;

            final currentRate = ratesByClass[classKey] ?? 0.0;
            if (parsedRate > currentRate) {
              ratesByClass[classKey] = parsedRate;
            }
          }

          _cachedTaxRatesByClass = ratesByClass;
          return ratesByClass;
        }
      }
    } catch (e) {
      print("Fetch taxes Exception: $e");
    }

    _cachedTaxRatesByClass = {};
    return _cachedTaxRatesByClass!;
  }

  String _normalizeCountryCode(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return "IN";
    if (value.length == 2) return value.toUpperCase();
    return _countryNameToCode[value.toLowerCase()] ?? value.toUpperCase();
  }

  Uri _buildPhonePeRequestUri() {
    final custom = Config.phonePeBackendRequestUrl.trim();
    if (custom.isNotEmpty) {
      return Uri.parse(custom);
    }
    return _buildWpV1Uri("phonepe-payment-request");
  }

  Uri _buildCashfreeOrderTokenUri() {
    final custom = Config.cashfreeOrderTokenUrl.trim();
    if (custom.isNotEmpty) {
      return Uri.parse(custom);
    }
    return _buildWpV1Uri("cashfree-order-token");
  }

  Uri? _buildCashfreeOrderStatusUri() {
    final custom = Config.cashfreeOrderStatusUrl.trim();
    if (custom.isEmpty) return null;
    return Uri.parse(custom);
  }

  Uri _buildRazorpayOrderCreateUri() {
    final custom = Config.razorpayOrderCreateUrl.trim();
    if (custom.isNotEmpty) {
      return Uri.parse(custom);
    }
    return _buildWpV1Uri("razorpay-create-order");
  }

  Uri? _buildRazorpayVerifyUri() {
    final custom = Config.razorpayVerifyUrl.trim();
    if (custom.isEmpty) return null;
    return Uri.parse(custom);
  }

  Uri _buildSnapmintCheckoutUri() {
    final custom = Config.snapmintCheckoutUrl.trim();
    if (custom.isNotEmpty) {
      return Uri.parse(custom);
    }
    return _buildWpV1Uri("snapmint-checkout-url");
  }

  Map<String, String> _phonePeHeaders() {
    final headers = _wcHeaders(json: true);
    final token = Config.phonePeBackendToken.trim();
    if (token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }
    return headers;
  }

  Map<String, String> _cashfreeHeaders() {
    final headers = _wcHeaders(json: true);
    final token = Config.cashfreeBackendToken.trim();
    if (token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }
    return headers;
  }

  Map<String, String> _razorpayHeaders() {
    final headers = _wcHeaders(json: true);
    final token = Config.razorpayBackendToken.trim();
    if (token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }
    return headers;
  }

  // ================= FETCH APP VERSION =================
  Future<String?> fetchAppVersion({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedVersion = prefs.getString(_appVersionCacheKey);

    if (!forceRefresh && _hasCheckedAppVersionThisLaunch) {
      return _sessionAppVersion ?? cachedVersion;
    }

    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final now = nowMs.toString();
      final response = await http
          .get(
            Uri.parse("https://yanaworldwide.store/Yanaapp/version.txt?v=$now"),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final serverVersion = response.body.trim();
        final hasVersionChanged =
            cachedVersion != null &&
            cachedVersion.trim().isNotEmpty &&
            cachedVersion.trim() != serverVersion;

        await prefs.setString(_appVersionCacheKey, serverVersion);
        await prefs.setInt(_appVersionFetchedAtKey, nowMs);
        _sessionAppVersion = serverVersion;
        _hasCheckedAppVersionThisLaunch = true;
        if (hasVersionChanged) {
          await _clearVersionedCaches(prefs);
        }
        return serverVersion;
      }
      _sessionAppVersion = cachedVersion;
      _hasCheckedAppVersionThisLaunch = true;
      return cachedVersion;
    } catch (e) {
      print("Version fetch error: $e");
      _sessionAppVersion = cachedVersion;
      _hasCheckedAppVersionThisLaunch = true;
      return cachedVersion;
    }
  }

  Future<void> _clearVersionedCaches(SharedPreferences prefs) async {
    final keysToRemove = <String>{
      "home_products",
      "home_proc_version",
      "home_categories",
      "home_categories_version",
      "top_brands_names",
      "top_brands_version",
      "top_brand_categories",
      "top_brand_categories_version",
      "home_banner_image_txt_cache",
      "home_banner_image_txt_version",
      "home_banner_video_txt_cache",
      "home_banner_video_txt_version",
    };

    for (final key in prefs.getKeys()) {
      if (key.startsWith("category_")) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }

  // ================= FETCH OFFER TEXT =================
  Future<String> fetchOfferText() async {
    try {
      final response = await http.get(
        Uri.parse("https://yanaworldwide.store/Yanaapp/offer.txt"),
      );

      if (response.statusCode == 200) {
        return response.body.trim();
      } else {
        return "";
      }
    } catch (e) {
      print("FetchOfferText Exception: $e");
      return "";
    }
  }

  // ================= FETCH COD FLAG =================
  Future<bool> isCodEnabled() async {
    try {
      final response = await http
          .get(Uri.parse("https://yanaworldwide.store/Yanaapp/cod.txt"))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return response.body.trim() == "1";
      }
      return false;
    } catch (e) {
      print("COD flag fetch error: $e");
      return false;
    }
  }

  // ================= FETCH PRODUCTS =================
  Future<List> fetchProducts({
    int perPage = 20,
    int page = 1,
    int? categoryId,
    String? search,
    double? minPrice,
    double? maxPrice,
    String? orderBy,
    String order = "desc",
  }) async {
    final result = await fetchProductsWithMeta(
      perPage: perPage,
      page: page,
      categoryId: categoryId,
      search: search,
      minPrice: minPrice,
      maxPrice: maxPrice,
      orderBy: orderBy,
      order: order,
    );

    return result.items;
  }

  Future<PaginatedProductsResult> searchProductsSmart({
    required String query,
    int perPage = 20,
    int page = 1,
    int? categoryId,
    String? orderBy,
    String order = "desc",
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return fetchProductsWithMeta(
        perPage: perPage,
        page: page,
        categoryId: categoryId,
        orderBy: orderBy,
        order: order,
      );
    }

    final cacheKey = [
      trimmedQuery.toLowerCase(),
      perPage,
      page,
      categoryId ?? 0,
      orderBy ?? "",
      order,
    ].join("|");
    final cachedResult = _smartSearchCache[cacheKey];
    if (cachedResult != null) {
      return cachedResult;
    }

    final normalizedQuery = _normalizeSearchText(trimmedQuery);
    final queryTokens = normalizedQuery
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList();
    final looksLikeSkuQuery = RegExp(r'^[a-z0-9\-_]+$', caseSensitive: false)
        .hasMatch(trimmedQuery.replaceAll(' ', ''));
    final shortQuery = queryTokens.length <= 1 && normalizedQuery.length <= 2;

    final primaryResultFuture = fetchProductsWithMeta(
      perPage: perPage,
      page: 1,
      categoryId: categoryId,
      search: trimmedQuery,
      orderBy: orderBy,
      order: order,
    );
    final exactSkuResultFuture = looksLikeSkuQuery
        ? fetchProductsWithMeta(
            perPage: perPage,
            page: 1,
            categoryId: categoryId,
            sku: trimmedQuery.replaceAll(' ', ''),
          )
        : Future.value(const PaginatedProductsResult(
            items: [],
            totalProducts: 0,
            totalPages: 0,
          ));
    final initialResults = await Future.wait([
      primaryResultFuture,
      exactSkuResultFuture,
    ]);
    final primaryResult = initialResults[0];
    final exactSkuResult = initialResults[1];

    final combined = <int, Map<String, dynamic>>{};
    void addRawProduct(dynamic raw, {bool overwrite = true}) {
      if (raw is! Map) return;
      final product = Map<String, dynamic>.from(raw);
      final id = int.tryParse((product["id"] ?? "").toString()) ?? 0;
      if (id <= 0) return;
      if (overwrite) {
        combined[id] = product;
      } else {
        combined.putIfAbsent(id, () => product);
      }
    }

    for (final raw in exactSkuResult.items) {
      addRawProduct(raw);
    }

    for (final raw in primaryResult.items) {
      addRawProduct(raw);
    }

    final candidatePages = looksLikeSkuQuery
        ? 2
        : shortQuery
            ? 1
            : (queryTokens.length > 1 ? 2 : 3);
    final shouldFetchFallbacks =
        exactSkuResult.items.isEmpty && primaryResult.items.length < perPage;
    if (shouldFetchFallbacks) {
      for (var candidatePage = 1;
          candidatePage <= candidatePages;
          candidatePage++) {
        final fallbackResult = await fetchProductsWithMeta(
          perPage: perPage,
          page: candidatePage,
          categoryId: categoryId,
          orderBy: "date",
          order: "desc",
        );
        if (fallbackResult.items.isEmpty) break;

        for (final raw in fallbackResult.items) {
          addRawProduct(raw, overwrite: false);
        }

        if (fallbackResult.items.length < perPage) break;
      }
    }

    final scoredMatches = <_ScoredSearchMatch>[];
    for (final productMap in combined.values) {
      final score = _scoreSearchMatch(
        product: productMap,
        normalizedQuery: normalizedQuery,
        queryTokens: queryTokens,
      );
      if (score > 0) {
        scoredMatches.add(_ScoredSearchMatch(productMap, score));
      }
    }

    scoredMatches.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;

      final aStock = _isProductMapInStock(a.product) ? 1 : 0;
      final bStock = _isProductMapInStock(b.product) ? 1 : 0;
      final stockCompare = bStock.compareTo(aStock);
      if (stockCompare != 0) return stockCompare;

      final aId = int.tryParse((a.product["id"] ?? "").toString()) ?? 0;
      final bId = int.tryParse((b.product["id"] ?? "").toString()) ?? 0;
      return bId.compareTo(aId);
    });

    final totalProducts = scoredMatches.length;
    final totalPages =
        totalProducts == 0 ? 0 : (totalProducts / perPage).ceil();
    final start = (page - 1) * perPage;
    if (start >= totalProducts) {
      const emptyResult = PaginatedProductsResult(
        items: [],
        totalProducts: 0,
        totalPages: 0,
      );
      _smartSearchCache[cacheKey] = emptyResult;
      if (_smartSearchCache.length > 40) {
        _smartSearchCache.remove(_smartSearchCache.keys.first);
      }
      return emptyResult;
    }
    final end = min(start + perPage, totalProducts);
    final result = PaginatedProductsResult(
      items: scoredMatches
          .sublist(start, end)
          .map((match) => match.product)
          .toList(),
      totalProducts: totalProducts,
      totalPages: totalPages,
    );
    _smartSearchCache[cacheKey] = result;
    if (_smartSearchCache.length > 40) {
      _smartSearchCache.remove(_smartSearchCache.keys.first);
    }
    return result;
  }

  Future<PaginatedProductsResult> fetchProductsWithMeta({
    int perPage = 20,
    int page = 1,
    int? categoryId,
    String? search,
    String? sku,
    double? minPrice,
    double? maxPrice,
    String? orderBy,
    String order = "desc",
  }) async {
    try {
      final ratesByClass = await _getTaxRatesByClass();
      Map<String, String> params = {
        "per_page": perPage.toString(),
        "page": page.toString(),
      };

      if (categoryId != null) {
        params["category"] = categoryId.toString();
      }

      if (search != null && search.isNotEmpty) {
        params["search"] = search;
      }

      if (sku != null && sku.trim().isNotEmpty) {
        params["sku"] = sku.trim();
      }

      if (minPrice != null) {
        params["min_price"] = minPrice.toString();
      }

      if (maxPrice != null) {
        params["max_price"] = maxPrice.toString();
      }

      if (orderBy != null) {
        params["orderby"] = orderBy;
        params["order"] = order;
      }

      final response = await http
          .get(_buildUri("products", params), headers: _wcHeaders())
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final items = jsonDecode(response.body);
        final totalProducts =
            int.tryParse(response.headers["x-wp-total"] ?? "") ?? 0;
        final totalPages =
            int.tryParse(response.headers["x-wp-totalpages"] ?? "") ?? 0;

        if (items is List) {
          final normalizedItems = items
              .whereType<Map>()
              .map(
                (item) => _normalizeProductPricing(
                  Map<String, dynamic>.from(item),
                  ratesByClass,
                ),
              )
              .toList();
          return PaginatedProductsResult(
            items: normalizedItems,
            totalProducts: totalProducts,
            totalPages: totalPages,
          );
        }
      }

      return const PaginatedProductsResult(
        items: [],
        totalProducts: 0,
        totalPages: 0,
      );
    } catch (e) {
      print("FetchProductsWithMeta Exception: $e");
      return const PaginatedProductsResult(
        items: [],
        totalProducts: 0,
        totalPages: 0,
      );
    }
  }

  // Backward-compatible wrapper used by category screen.
  Future<List> fetchProductsByCategory(int categoryId) {
    return fetchProducts(categoryId: categoryId);
  }

  Future<Map<String, List>> fetchGroupedCategoriesWithData() async {
    try {
      final groupedText = await fetchGroupedCategories();

      List allCategories = [];
      int page = 1;
      bool hasMore = true;

      // 🔥 Fetch ALL pages
      while (hasMore) {
        final response = await http.get(
          _buildUri("products/categories", {
            "per_page": "100",
            "page": page.toString(),
          }),
          headers: _wcHeaders(),
        );

        if (response.statusCode != 200) break;

        List data = jsonDecode(response.body);

        if (data.isEmpty) {
          hasMore = false;
        } else {
          allCategories.addAll(data);
          page++;
        }
      }

      Map<String, List> finalData = {};

      groupedText.forEach((title, subList) {
        List matched = [];
        final seenIds = <int>{};

        for (final name in subList) {
          final match = _findBestCategoryMatch(allCategories, name);
          if (match == null) continue;

          final id = int.tryParse(match["id"]?.toString() ?? "");
          if (id != null && seenIds.contains(id)) continue;

          if (id != null) {
            seenIds.add(id);
          }
          matched.add(match);
        }

        // 🔥 Remove categories without image or empty name
        matched = matched.where((cat) {
          final hasName =
              cat["name"] != null && cat["name"].toString().trim().isNotEmpty;
          return hasName && (cat["count"] ?? 0) > 0;
        }).toList();

        matched = matched.map((cat) {
          final normalized = Map<String, dynamic>.from(cat);
          final image = normalized["image"];

          if (image is Map && image["src"] != null) {
            return normalized;
          }

          normalized["image"] = {"src": _fallbackCategoryImage};
          return normalized;
        }).toList();

        if (matched.isNotEmpty) {
          finalData[title] = matched;
        }
      });

      return finalData;
    } catch (e) {
      print("Grouped Filter Exception: $e");
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> fetchTopBrandCategories(
    List<String> topNames,
  ) async {
    try {
      if (topNames.isEmpty) return const <Map<String, dynamic>>[];

      List allCategories = [];
      int page = 1;
      bool hasMore = true;
      final seenIds = <int>{};
      final matched = <Map<String, dynamic>>[];

      while (hasMore) {
        final response = await http.get(
          _buildUri("products/categories", {
            "per_page": "100",
            "page": page.toString(),
          }),
          headers: _wcHeaders(),
        );

        if (response.statusCode != 200) break;

        final data = jsonDecode(response.body);
        if (data is! List || data.isEmpty) {
          hasMore = false;
        } else {
          allCategories.addAll(data);
          page++;
        }
      }

      for (final name in topNames) {
        final match = _findBestCategoryMatch(allCategories, name);
        if (match == null) continue;

        final normalized = Map<String, dynamic>.from(match);
        final id = int.tryParse(normalized["id"]?.toString() ?? "");
        final hasName =
            normalized["name"] != null &&
            normalized["name"].toString().trim().isNotEmpty;
        final hasCount = (normalized["count"] ?? 0) > 0;

        if (!hasName || !hasCount) continue;
        if (id != null && seenIds.contains(id)) continue;
        if (id != null) {
          seenIds.add(id);
        }

        final image = normalized["image"];
        if (image is! Map || image["src"] == null) {
          normalized["image"] = {"src": _fallbackCategoryImage};
        }
        matched.add(normalized);
      }

      return matched;
    } catch (e) {
      print("Top brand categories fetch error: $e");
      return const <Map<String, dynamic>>[];
    }
  }

  Map<String, dynamic>? _findBestCategoryMatch(
    List allCategories,
    String targetName,
  ) {
    final target = _normalizeCategoryText(targetName);
    if (target.isEmpty) return null;

    Map<String, dynamic>? prefixMatch;

    for (final raw in allCategories) {
      if (raw is! Map) continue;
      final cat = Map<String, dynamic>.from(raw);
      final catName = _normalizeCategoryText(cat["name"]?.toString() ?? "");
      final catSlug = _normalizeCategoryText(cat["slug"]?.toString() ?? "");

      if (catName.isEmpty && catSlug.isEmpty) continue;

      if (catName == target || catSlug == target) {
        return cat;
      }

      if (catName.startsWith(target) || catSlug.startsWith(target)) {
        prefixMatch ??= cat;
      }
    }

    return prefixMatch;
  }

  String _normalizeCategoryText(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Future<Map<String, List<String>>> fetchGroupedCategories() async {
    try {
      final response = await http
          .get(Uri.parse("https://yanaworldwide.store/cat.txt"))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return {};

      List<String> lines = response.body.split("\n");

      Map<String, List<String>> grouped = {};
      String? currentTitle;

      for (var rawLine in lines) {
        String line = rawLine.replaceAll("\r", "");

        if (line.trim().isEmpty) continue;

        // Main title
        if (!RegExp(r'^\s').hasMatch(line)) {
          currentTitle = line.trim();
          grouped[currentTitle] = [];
        } else {
          if (currentTitle != null) {
            grouped[currentTitle]!.add(line.trim());
          }
        }
      }

      return grouped;
    } catch (e) {
      print("Grouped TXT Exception: $e");
      return {};
    }
  }

  // ================= FETCH VARIATIONS =================
  Future<List> fetchVariations(int productId) async {
    try {
      final ratesByClass = await _getTaxRatesByClass();
      final response = await http
          .get(
            _buildUri("products/$productId/variations", {}),
            headers: _wcHeaders(),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final items = jsonDecode(response.body);
        if (items is List) {
          return items
              .whereType<Map>()
              .map(
                (item) => _normalizeProductPricing(
                  Map<String, dynamic>.from(item),
                  ratesByClass,
                ),
              )
              .toList();
        }
      }

      return [];
    } catch (e) {
      print("Variation Exception: $e");
      return [];
    }
  }

  // ================= GET CATEGORY BY SLUG =================
  Future<int?> getCategoryIdBySlug(String slug) async {
    try {
      final response = await http
          .get(
            _buildUri("products/categories", {"slug": slug}),
            headers: _wcHeaders(),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          return data.first["id"];
        }
      }

      return null;
    } catch (e) {
      print("Slug Exception: $e");
      return null;
    }
  }

  // ================= FETCH MENU =================
  Future<List> fetchMainMenu() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              "${Config.baseUrl.replaceAll('/wp-json/wc/v3/', '')}/wp-json/menus/v1/menus/header-menu-1",
            ),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["items"] ?? [];
      }

      return [];
    } catch (e) {
      print("Menu Exception: $e");
      return [];
    }
  }

  // ================= FETCH SHIPPING METHODS =================
  Future<List> fetchShippingMethods() async {
    try {
      final response = await http
          .get(_buildUri("shipping/zones/1/methods", {}), headers: _wcHeaders())
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      return [];
    } catch (e) {
      print("Shipping Exception: $e");
      return [];
    }
  }

  // ================= GET CUSTOMER =================
  Future<Map<String, dynamic>?> getCustomer(int id) async {
    try {
      final uri = _buildUri("customers/$id", {});
      final response = await http.get(uri, headers: _wcHeaders());

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      return null;
    } catch (e) {
      print("Get Customer Exception: $e");
      return null;
    }
  }

  // ================= FETCH CUSTOMER ORDERS =================
  Future<List> fetchCustomerOrders(int customerId) async {
    try {
      final response = await http
          .get(
            _buildUri("orders", {
              "customer": customerId.toString(),
              "per_page": "50",
              "orderby": "date",
              "order": "desc",
            }),
            headers: _wcHeaders(),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      return [];
    } catch (e) {
      print("Fetch Orders Exception: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> fetchOrderById(int orderId) async {
    try {
      final response = await http
          .get(
            _buildUri("orders/$orderId", {}),
            headers: _wcHeaders(),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        return {};
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      return {};
    } catch (e) {
      print("Fetch Order By Id Exception: $e");
      return {};
    }
  }

  // ================= UPDATE CUSTOMER ADDRESS =================
  Future<bool> updateCustomerAddress({
    required int customerId,
    required String address,
    required String city,
    required String state,
    required String pincode,
    required String country,
  }) async {
    try {
      final uri = _buildUri("customers/$customerId", {});

      final response = await http.put(
        uri,
        headers: _wcHeaders(json: true),
        body: jsonEncode({
          "billing": {
            "address_1": address,
            "city": city,
            "state": state,
            "postcode": pincode,
            "country": country,
          },
          "shipping": {
            "address_1": address,
            "city": city,
            "state": state,
            "postcode": pincode,
            "country": country,
          },
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Update Address Exception: $e");
      return false;
    }
  }

  // ================= UPDATE ACCOUNT DETAILS =================
  Future<bool> updateAccountDetails({
    required int customerId,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  }) async {
    try {
      final uri = _buildUri("customers/$customerId", {});

      final response = await http.put(
        uri,
        headers: _wcHeaders(json: true),
        body: jsonEncode({
          "first_name": firstName,
          "last_name": lastName,
          "email": email,
          "billing": {"phone": phone},
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Update Account Exception: $e");
      return false;
    }
  }

  // ================= APPLY TXT COUPON =================
  Future<Map<String, dynamic>?> checkTxtCoupon(
    String code,
    double currentTotal,
  ) async {
    try {
      final response = await http
          .get(Uri.parse("https://yanaworldwide.store/coupon.txt"))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      List<String> lines = response.body.split("\n");

      for (var raw in lines) {
        String line = raw.trim();
        if (line.isEmpty) continue;

        if (line.toLowerCase().contains(code.toLowerCase())) {
          List<String> parts = line.split(" ");

          String coupon = parts[1];
          String min = parts[2].split(":")[1];
          String max = parts[3].split(":")[1];
          String value = parts[4].split(":")[1];

          return {"coupon": coupon, "min": min, "max": max, "value": value};
        }
      }

      return null;
    } catch (e) {
      print("TXT Coupon Exception: $e");
      return null;
    }
  }

  // ================= CREATE ORDER =================
  Future<Map<String, dynamic>> createOrder({
    required List<CartItem> cartItems,
    required String name,
    required String email,
    required String phone,
    required String address,
    required String shippingMethodId,
    required String shippingMethodTitle,
    required String shippingTotal,
    required String city,
    required String state,
    required String pincode,
    required String country,
    required String notes,
    required String paymentType,
    required double totalAmount,
    String couponCode = "",
    double walletUsedAmount = 0.0,
    double cashbackThreshold = 0.0,
    double cashbackRewardAmount = 0.0,
    double cashbackEligibleAmount = 0.0,
  }) async {
    try {
      final uri = _buildUri("orders", {});
      final userIdRaw = await AuthService().getUserId();
      final prefs = await SharedPreferences.getInstance();
      final installId = prefs.getString("anonymous_install_id") ?? "";
      final normalizedCountry = _normalizeCountryCode(country);
      int? customerId = int.tryParse(userIdRaw ?? "");
      if (customerId == null && email.trim().isNotEmpty) {
        customerId = await _resolveOrCreateCustomerId(
          name: name,
          email: email.trim(),
          phone: phone,
          address: address,
          city: city,
          state: state,
          pincode: pincode,
          country: normalizedCountry,
        );
      }

      List<Map<String, dynamic>> lineItems = cartItems.map((item) {
        return {
          "product_id": item.id,
          "variation_id": item.variationId ?? 0,
          "quantity": item.quantity,
        };
      }).toList();

      // NEW LOGIC FOR PAYMENT TYPES
      String paymentMethod;
      String paymentTitle;
      bool setPaid;
      String orderStatus;
      final isPhonePeFlow =
          paymentType == "phonepe_full" ||
          paymentType == "phonepe_partial" ||
          paymentType == "phonepe_sdk_full";
      final isCashfreeFlow =
          paymentType == "cashfree_full" ||
          paymentType == "cashfree_partial" ||
          paymentType == "cashfree_partial_pending";
      final isRazorpayFlow =
          paymentType == "razorpay_full" ||
          paymentType == "razorpay_pending" ||
          paymentType == "razorpay_partial" ||
          paymentType == "razorpay_partial_pending";
      final isPartialType =
          paymentType == "partial" ||
          paymentType == "phonepe_partial" ||
          paymentType == "cashfree_partial" ||
          paymentType == "cashfree_partial_pending" ||
          paymentType == "razorpay_partial" ||
          paymentType == "razorpay_partial_pending" ||
          paymentType == "payu_web_partial" ||
          paymentType == "payu_sdk_partial";

      if (paymentType == "snapmint") {
        paymentMethod = "snapmint";
        paymentTitle = "Cardless EMI";
        setPaid = false;
        orderStatus = "pending"; // 👈 VERY IMPORTANT
      } else if (paymentType == "phonepe_sdk_full") {
        paymentMethod = "phonepe";
        paymentTitle = "PhonePe Full Payment";
        setPaid = true;
        orderStatus = "processing";
      } else if (paymentType == "phonepe_full") {
        paymentMethod = "phonepe";
        paymentTitle = "PhonePe Full Payment";
        setPaid = false;
        orderStatus = "pending";
      } else if (paymentType == "phonepe_partial") {
        paymentMethod = "phonepe";
        paymentTitle = "PhonePe 8% Advance + COD";
        setPaid = false;
        orderStatus = "pending";
      } else if (paymentType == "cashfree_full") {
        paymentMethod = "cashfree";
        paymentTitle = "Cashfree Full Payment";
        setPaid = true;
        orderStatus = "processing";
      } else if (paymentType == "cashfree_pending") {
        paymentMethod = "cashfree";
        paymentTitle = "Cashfree Full Payment";
        setPaid = false;
        orderStatus = "pending";
      } else if (paymentType == "cashfree_partial_pending") {
        paymentMethod = "cashfree";
        paymentTitle = "Cashfree 8% Advance + COD";
        setPaid = false;
        orderStatus = "pending";
      } else if (paymentType == "cashfree_partial") {
        paymentMethod = "cashfree";
        paymentTitle = "Cashfree 8% Advance + COD";
        setPaid = false;
        orderStatus = "on-hold";
      } else if (paymentType == "razorpay_full") {
        paymentMethod = "razorpay";
        paymentTitle = "Razorpay Full Payment";
        setPaid = true;
        orderStatus = "processing";
      } else if (paymentType == "razorpay_pending") {
        paymentMethod = "razorpay";
        paymentTitle = "Razorpay Full Payment";
        setPaid = false;
        orderStatus = "pending";
      } else if (paymentType == "razorpay_partial_pending") {
        paymentMethod = "razorpay";
        paymentTitle = "Razorpay 8% Advance + COD";
        setPaid = false;
        orderStatus = "pending";
      } else if (paymentType == "razorpay_partial") {
        paymentMethod = "razorpay";
        paymentTitle = "Razorpay 8% Advance + COD";
        setPaid = false;
        orderStatus = "on-hold";
      } else if (paymentType == "payu_web_full") {
        paymentMethod = "payu_full";
        paymentTitle = "PayU Full Payment";
        setPaid = false;
        orderStatus = "pending";
      } else if (paymentType == "payu_web_partial") {
        paymentMethod = "payu_partial";
        paymentTitle = "PayU 8% Advance + COD";
        setPaid = false;
        orderStatus = "pending";
      } else if (paymentType == "payu_sdk_full") {
        paymentMethod = "payu_full";
        paymentTitle = "PayU Full Payment";
        setPaid = true;
        orderStatus = "processing";
      } else if (paymentType == "payu_sdk_partial") {
        paymentMethod = "payu_partial";
        paymentTitle = "PayU 8% Advance + COD";
        setPaid = false;
        orderStatus = "on-hold";
      } else if (paymentType == "cod") {
        paymentMethod = "cod";
        paymentTitle = "Cash on Delivery";
        setPaid = false;
        orderStatus = "pending";
      } else if (paymentType == "partial") {
        paymentMethod = "payu_partial";
        paymentTitle = "8% Advance + COD";
        setPaid = false;
        orderStatus = "on-hold";
      } else {
        paymentMethod = "payu_full";
        paymentTitle = "Full Payment";
        setPaid = true;
        orderStatus = "processing";
      }

      final response = await http.post(
        uri,
        headers: _wcHeaders(json: true),
        body: jsonEncode({
          if (customerId != null)
            "customer_id": customerId,
          "created_via": "app",
          "payment_method": paymentMethod,
          "payment_method_title": paymentTitle,
          "set_paid": setPaid,
          "status": orderStatus,
          "billing": {
            "first_name": name.split(" ").first,
            "last_name": name.split(" ").length > 1
                ? name.split(" ").sublist(1).join(" ")
                : "",
            "address_1": address,
            "city": city,
            "state": state,
            "postcode": pincode,
            "country": normalizedCountry,
            "phone": phone,
            "email": email,
          },
          "shipping": {
            "first_name": name.split(" ").first,
            "last_name": name.split(" ").length > 1
                ? name.split(" ").sublist(1).join(" ")
                : "",
            "address_1": address,
            "city": city,
            "state": state,
            "postcode": pincode,
            "country": normalizedCountry,
          },
          "line_items": lineItems,
          if (couponCode.trim().isNotEmpty)
            "coupon_lines": [
              {"code": couponCode.trim()}
            ],
          if (walletUsedAmount > 0)
            "fee_lines": [
              {
                "name": "App Wallet Discount",
                "total": (-walletUsedAmount).toStringAsFixed(2),
              },
            ],
          "shipping_lines": [
            {
              "method_id": shippingMethodId,
              "method_title": shippingMethodTitle,
              "total": shippingTotal,
            },
          ],
          "meta_data": [
            {"key": "payment_type", "value": paymentType},
            {
              "key": "advance_amount",
              "value": isPartialType
                  ? partialAdvanceAmount(totalAmount).toStringAsFixed(2)
                  : totalAmount.toStringAsFixed(2),
            },
            {
              "key": "remaining_amount",
              "value": isPartialType
                  ? partialRemainingAmount(totalAmount).toStringAsFixed(2)
                  : "0",
            },
            {
              "key": "online_gateway",
              "value": paymentType == "snapmint"
                  ? "snapmint"
                  : (isPhonePeFlow
                      ? "phonepe"
                      : (isCashfreeFlow
                          ? "cashfree"
                          : (isRazorpayFlow ? "razorpay" : "payu"))),
            },
            {"key": "order_source", "value": "app"},
            if (installId.isNotEmpty)
              {"key": "app_install_id", "value": installId},
            if (walletUsedAmount > 0)
              {
                "key": "wallet_used_amount",
                "value": walletUsedAmount.toStringAsFixed(2),
              },
            if (cashbackThreshold > 0 && cashbackRewardAmount > 0)
              {
                "key": "cashback_rule",
                "value":
                    "Spend ${cashbackThreshold.toStringAsFixed(2)} get ${cashbackRewardAmount.toStringAsFixed(2)}",
              },
            if (cashbackThreshold > 0 && cashbackRewardAmount > 0)
              {
                "key": "cashback_threshold",
                "value": cashbackThreshold.toStringAsFixed(2),
              },
            if (cashbackRewardAmount > 0)
              {
                "key": "cashback_amount",
                "value": cashbackRewardAmount.toStringAsFixed(2),
              },
            if (cashbackEligibleAmount > 0)
              {
                "key": "cashback_eligible_amount",
                "value": cashbackEligibleAmount.toStringAsFixed(2),
              },
            if (cashbackThreshold > 0 && cashbackRewardAmount > 0)
              {
                "key": "cashback_status",
                "value": cashbackEligibleAmount >= cashbackThreshold
                    ? "eligible"
                    : "not_eligible",
              },
          ],
          "customer_note": notes.trim().isEmpty
              ? "App order"
              : "App order | ${notes.trim()}",
        }),
      );

      print(
        "[ORDER][API] POST ${uri.toString()} paymentType=$paymentType customerId=${customerId ?? 0} status=${response.statusCode}",
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final parsed = _decodeJsonObject(response.body);
        if (parsed != null) {
          print("[ORDER][API] parsed keys=${parsed.keys.toList()}");
          return parsed;
        }
        print(
          "CreateOrder parse failed despite success HTTP ${response.statusCode}. Body starts with: ${response.body.substring(0, response.body.length > 180 ? 180 : response.body.length)}",
        );
        return {};
      }

      print(
        "CreateOrder HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length > 180 ? 180 : response.body.length)}",
      );
      return {};
    } catch (e) {
      print("CreateOrder Exception: $e");
      return {};
    }
  }

  Map<String, dynamic>? _decodeJsonObject(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}

    // Some servers prepend notices/warnings before JSON.
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final candidate = raw.substring(start, end + 1);
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  Future<String?> createSnapmintCheckoutUrl({
    required int orderId,
    required int? userId,
    String device = "android",
  }) async {
    final uri = _buildSnapmintCheckoutUri();
    final payload = {
      "order_id": orderId,
      "user_id": userId,
      "device": device,
    };

    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        print(
          "[SNAPMINT][API] POST ${uri.toString()} orderId=$orderId userId=${userId ?? 0} device=$device",
        );
        final response = await http
            .post(
              uri,
              headers: _wcHeaders(json: true),
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 20));

        final preview = response.body.substring(
          0,
          response.body.length > 300 ? 300 : response.body.length,
        );
        print("[SNAPMINT][API] HTTP ${response.statusCode} body=$preview");

        final data = _decodeJsonObject(response.body);
        if (data == null) {
          if (attempt == 1) {
            print(
              "CreateSnapmintCheckoutUrl parse error at ${uri.toString()}: ${response.body}",
            );
            return null;
          }
          continue;
        }

        final map = Map<String, dynamic>.from(data);
        final status = (map["status"] ?? "").toString().trim().toLowerCase();
        final ok = (map["ok"] ?? false) == true;
        final success = (map["success"] ?? false) == true;
        final checkoutUrl = (map["checkout_url"] ??
                map["redirect_url"] ??
                map["redirectUrl"] ??
                map["url"] ??
                map["link"] ??
                map["checkoutLink"] ??
                "")
            .toString()
            .trim();

        if (checkoutUrl.isNotEmpty &&
            (status == "success" ||
                status == "ok" ||
                ok ||
                success ||
                response.statusCode == 200)) {
          return checkoutUrl;
        }

        final message = (map["message"] ??
                map["error"] ??
                map["reason"] ??
                map["detail"] ??
                "")
            .toString()
            .trim();
        print(
          "[SNAPMINT][API] checkout url missing or rejected status=$status message=$message keys=${map.keys.toList()}",
        );

        if (response.statusCode != 200) {
          if (attempt == 1) return null;
          continue;
        }

        if (attempt == 1) return null;
      } catch (e) {
        if (attempt == 1) {
          print("CreateSnapmintCheckoutUrl Exception: $e");
          return null;
        }
      }
    }

    return null;
  }

  Future<Map<String, dynamic>?> createPhonePePaymentRequest({
    required double amount,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String paymentType,
  }) async {
    try {
      final uri = _buildPhonePeRequestUri();
      print(
        "[PHONEPE][API] POST ${uri.toString()} amount=${amount.toStringAsFixed(2)} type=$paymentType",
      );
      final response = await http
          .post(
            uri,
            headers: _phonePeHeaders(),
            body: jsonEncode({
              "amount": amount.toStringAsFixed(2),
              "name": customerName,
              "email": customerEmail,
              "phone": customerPhone,
              "payment_type": paymentType,
              "device": "android",
            }),
          )
          .timeout(const Duration(seconds: 20));

      print(
        "[PHONEPE][API] HTTP ${response.statusCode} body=${response.body.substring(0, response.body.length > 300 ? 300 : response.body.length)}",
      );
      final data = _decodeJsonObject(response.body);
      if (data == null) {
        print(
          "CreatePhonePePaymentRequest parse error at ${uri.toString()}: ${response.body}",
        );
        return null;
      }
      data["http_status"] = response.statusCode;
      print("[PHONEPE][API] parsed keys=${data.keys.toList()}");
      return data;
    } catch (e) {
      print("CreatePhonePePaymentRequest Exception: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> checkCoupon(
    String code,
    double currentTotal,
  ) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;

    final txt = await checkTxtCoupon(normalized, currentTotal);
    if (txt != null) return txt;

    return _checkWooCoupon(normalized, currentTotal);
  }

  Future<Map<String, dynamic>?> fetchGatewayStatus() async {
    try {
      final uri = _buildWpV1Uri("gateway-status");
      final response = await http
          .get(uri, headers: _wcHeaders())
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      print("FetchGatewayStatus Exception: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllCategories() async {
    try {
      final allCategories = <Map<String, dynamic>>[];
      int page = 1;

      while (true) {
        final response = await http
            .get(
              _buildUri("products/categories", {
                "per_page": "100",
                "page": page.toString(),
              }),
              headers: _wcHeaders(),
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode != 200) break;
        final decoded = jsonDecode(response.body);
        if (decoded is! List || decoded.isEmpty) break;

        allCategories.addAll(
          decoded
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item)),
        );
        page++;
      }

      return allCategories;
    } catch (e) {
      print("FetchAllCategories Exception: $e");
      return const <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>?> createCashfreeOrderToken({
    required double amount,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    String merchantOrderId = "",
  }) async {
    try {
      final uri = _buildCashfreeOrderTokenUri();
      print(
        "[CASHFREE][API] POST ${uri.toString()} amount=${amount.toStringAsFixed(2)}",
      );
      final response = await http
          .post(
            uri,
            headers: _cashfreeHeaders(),
            body: jsonEncode({
              "amount": amount.toStringAsFixed(2),
              "name": customerName,
              "email": customerEmail,
              "phone": customerPhone,
              "merchant_order_id": merchantOrderId.trim(),
              "environment": Config.cashfreeEnvironment,
            }),
          )
          .timeout(const Duration(seconds: 25));

      print(
        "[CASHFREE][API] HTTP ${response.statusCode} body=${response.body.substring(0, response.body.length > 300 ? 300 : response.body.length)}",
      );

      final data = _decodeJsonObject(response.body);
      if (data == null) {
        print(
          "CreateCashfreeOrderToken parse error at ${uri.toString()}: ${response.body}",
        );
        return null;
      }
      data["http_status"] = response.statusCode;
      print("[CASHFREE][API] parsed keys=${data.keys.toList()}");
      return data;
    } catch (e) {
      print("CreateCashfreeOrderToken Exception: $e");
      return null;
    }
  }

  Future<bool> verifyCashfreeOrderStatus({
    required String orderId,
  }) async {
    final normalizedOrderId = orderId.trim();
    if (normalizedOrderId.isEmpty) {
      print("[CASHFREE][VERIFY] empty order id");
      return false;
    }

    final uri = _buildCashfreeOrderStatusUri();
    if (uri == null) {
      // Backward-compatible fallback for environments where status endpoint
      // is not deployed yet.
      print("[CASHFREE][VERIFY] skipped; status endpoint not configured");
      return true;
    }

    try {
      print("[CASHFREE][VERIFY] POST ${uri.toString()} order_id=$normalizedOrderId");
      final response = await http
          .post(
            uri,
            headers: _cashfreeHeaders(),
            body: jsonEncode({
              "order_id": normalizedOrderId,
              "environment": Config.cashfreeEnvironment,
            }),
          )
          .timeout(const Duration(seconds: 25));

      print(
        "[CASHFREE][VERIFY] HTTP ${response.statusCode} body=${response.body.substring(0, response.body.length > 300 ? 300 : response.body.length)}",
      );
      final data = _decodeJsonObject(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data == null) {
        return false;
      }

      final verified = data["verified"] == true;
      final orderStatus = (data["order_status"] ?? "").toString().toUpperCase();
      final paymentStatus = (data["payment_status"] ?? "")
          .toString()
          .toUpperCase();

      if (verified) return true;
      if (orderStatus == "PAID") return true;
      if (paymentStatus == "SUCCESS" || paymentStatus == "PAID") return true;
      return false;
    } catch (e) {
      print("VerifyCashfreeOrderStatus Exception: $e");
      return false;
    }
  }

  Future<bool> markCashfreeOrderPaid({
    required int orderId,
    required String cashfreeOrderId,
  }) async {
    try {
      final uri = _buildUri("orders/$orderId", {});
      final response = await http.put(
        uri,
        headers: _wcHeaders(json: true),
        body: jsonEncode({
          "set_paid": true,
          "status": "processing",
          "transaction_id": cashfreeOrderId.trim(),
          "meta_data": [
            {"key": "cashfree_order_id", "value": cashfreeOrderId.trim()},
            {"key": "cashfree_payment_verified", "value": "1"},
            {"key": "payment_type", "value": "cashfree_full"},
            {"key": "online_gateway", "value": "cashfree"},
          ],
        }),
      ).timeout(const Duration(seconds: 25));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print("MarkCashfreeOrderPaid Exception: $e");
      return false;
    }
  }

  Future<bool> markCashfreePartialOrderPaid({
    required int orderId,
    required String cashfreeOrderId,
  }) async {
    try {
      final uri = _buildUri("orders/$orderId", {});
      final response = await http.put(
        uri,
        headers: _wcHeaders(json: true),
        body: jsonEncode({
          "set_paid": false,
          "status": "on-hold",
          "transaction_id": cashfreeOrderId.trim(),
          "meta_data": [
            {"key": "cashfree_order_id", "value": cashfreeOrderId.trim()},
            {"key": "cashfree_payment_verified", "value": "1"},
            {"key": "payment_type", "value": "cashfree_partial"},
            {"key": "online_gateway", "value": "cashfree"},
            {"key": "partial_payment_received", "value": "1"},
          ],
        }),
      ).timeout(const Duration(seconds: 25));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print("MarkCashfreePartialOrderPaid Exception: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>?> createRazorpayOrder({
    required double amount,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    String merchantOrderId = "",
  }) async {
    try {
      final uri = _buildRazorpayOrderCreateUri();
      print(
        "[RAZORPAY][API] POST ${uri.toString()} amount=${amount.toStringAsFixed(2)} merchantOrderId=$merchantOrderId",
      );
      final response = await http
          .post(
            uri,
            headers: _razorpayHeaders(),
            body: jsonEncode({
              "amount": amount.toStringAsFixed(2),
              "name": customerName,
              "email": customerEmail,
              "phone": customerPhone,
              "merchant_order_id": merchantOrderId.trim(),
              "currency": "INR",
            }),
          )
          .timeout(const Duration(seconds: 25));

      print(
        "[RAZORPAY][API] HTTP ${response.statusCode} body=${response.body.substring(0, response.body.length > 300 ? 300 : response.body.length)}",
      );

      final data = _decodeJsonObject(response.body);
      if (data == null) {
        print(
          "CreateRazorpayOrder parse error at ${uri.toString()}: ${response.body}",
        );
        return null;
      }
      data["http_status"] = response.statusCode;
      return data;
    } catch (e) {
      print("CreateRazorpayOrder Exception: $e");
      return null;
    }
  }

  Future<bool> verifyRazorpayPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    String merchantOrderId = "",
  }) async {
    final uri = _buildRazorpayVerifyUri();
    if (uri == null) {
      print("[RAZORPAY][VERIFY] skipped; verify endpoint not configured");
      return razorpayPaymentId.trim().isNotEmpty;
    }

    try {
      final response = await http
          .post(
            uri,
            headers: _razorpayHeaders(),
            body: jsonEncode({
              "razorpay_order_id": razorpayOrderId.trim(),
              "razorpay_payment_id": razorpayPaymentId.trim(),
              "razorpay_signature": razorpaySignature.trim(),
              "merchant_order_id": merchantOrderId.trim(),
            }),
          )
          .timeout(const Duration(seconds: 25));

      print(
        "[RAZORPAY][VERIFY] HTTP ${response.statusCode} body=${response.body.substring(0, response.body.length > 300 ? 300 : response.body.length)}",
      );

      final data = _decodeJsonObject(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data == null) {
        return false;
      }

      if (data["verified"] == true || data["success"] == true) {
        return true;
      }

      final status = (data["status"] ?? data["payment_status"] ?? "")
          .toString()
          .trim()
          .toLowerCase();
      return status == "paid" || status == "captured" || status == "success";
    } catch (e) {
      print("VerifyRazorpayPayment Exception: $e");
      return false;
    }
  }

  Future<bool> markRazorpayOrderPaid({
    required int orderId,
    required String razorpayPaymentId,
    String razorpayOrderId = "",
  }) async {
    try {
      final uri = _buildUri("orders/$orderId", {});
      final response = await http.put(
        uri,
        headers: _wcHeaders(json: true),
        body: jsonEncode({
          "set_paid": true,
          "status": "processing",
          "transaction_id": razorpayPaymentId.trim(),
          "meta_data": [
            {"key": "razorpay_payment_id", "value": razorpayPaymentId.trim()},
            if (razorpayOrderId.trim().isNotEmpty)
              {"key": "razorpay_order_id", "value": razorpayOrderId.trim()},
            {"key": "razorpay_payment_verified", "value": "1"},
            {"key": "payment_type", "value": "razorpay_full"},
            {"key": "online_gateway", "value": "razorpay"},
          ],
        }),
      ).timeout(const Duration(seconds: 25));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print("MarkRazorpayOrderPaid Exception: $e");
      return false;
    }
  }

  Future<bool> markRazorpayPartialOrderPaid({
    required int orderId,
    required String razorpayPaymentId,
    String razorpayOrderId = "",
  }) async {
    try {
      final uri = _buildUri("orders/$orderId", {});
      final response = await http.put(
        uri,
        headers: _wcHeaders(json: true),
        body: jsonEncode({
          "set_paid": false,
          "status": "on-hold",
          "transaction_id": razorpayPaymentId.trim(),
          "meta_data": [
            {"key": "razorpay_payment_id", "value": razorpayPaymentId.trim()},
            if (razorpayOrderId.trim().isNotEmpty)
              {"key": "razorpay_order_id", "value": razorpayOrderId.trim()},
            {"key": "razorpay_payment_verified", "value": "1"},
            {"key": "payment_type", "value": "razorpay_partial"},
            {"key": "online_gateway", "value": "razorpay"},
            {"key": "partial_payment_received", "value": "1"},
          ],
        }),
      ).timeout(const Duration(seconds: 25));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print("MarkRazorpayPartialOrderPaid Exception: $e");
      return false;
    }
  }

  Future<bool> markSnapmintOrderPaid({
    required int orderId,
    String transactionId = "",
  }) async {
    final normalizedTransactionId = transactionId.trim();
    try {
      final uri = _buildUri("orders/$orderId", {});
      final response = await http.put(
        uri,
        headers: _wcHeaders(json: true),
        body: jsonEncode({
          "set_paid": true,
          "status": "processing",
          if (normalizedTransactionId.isNotEmpty)
            "transaction_id": normalizedTransactionId,
          "meta_data": [
            {
              "key": "snapmint_payment_verified",
              "value": "1",
            },
            {
              "key": "payment_type",
              "value": "snapmint",
            },
            {
              "key": "online_gateway",
              "value": "snapmint",
            },
            if (normalizedTransactionId.isNotEmpty)
              {
                "key": "snapmint_payment_id",
                "value": normalizedTransactionId,
              },
          ],
        }),
      ).timeout(const Duration(seconds: 25));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print("MarkSnapmintOrderPaid Exception: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchWalletStatus({
    required double orderAmount,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final installId = (prefs.getString("anonymous_install_id") ?? "").trim();
      final userIdRaw = (await AuthService().getUserId() ?? "").trim();
      final userId = int.tryParse(userIdRaw) ?? 0;

      final uri = _buildWpV1Uri("wallet/status");
      final response = await http
          .post(
            uri,
            headers: _wcHeaders(json: true),
            body: jsonEncode({
              "user_id": userId > 0 ? userId : 0,
              "install_id": installId,
              "order_amount": orderAmount.toStringAsFixed(2),
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      print("FetchWalletStatus Exception: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchWalletOverview({
    double orderAmount = 0.0,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final installId = (prefs.getString("anonymous_install_id") ?? "").trim();
      final userIdRaw = (await AuthService().getUserId() ?? "").trim();
      final userId = int.tryParse(userIdRaw) ?? 0;

      final uri = _buildWpV1Uri("wallet/overview");
      final response = await http
          .post(
            uri,
            headers: _wcHeaders(json: true),
            body: jsonEncode({
              "user_id": userId > 0 ? userId : 0,
              "install_id": installId,
              "order_amount": orderAmount.toStringAsFixed(2),
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      print("FetchWalletOverview Exception: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchGrowthConfig() async {
    try {
      final uri = _buildWpV1Uri("growth-config");
      final response = await http
          .get(uri, headers: _wcHeaders())
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      print("FetchGrowthConfig Exception: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchProductsByIds(
    List<int> productIds, {
    int limit = 10,
  }) async {
    final ids = productIds.where((id) => id > 0).toSet().toList();
    if (ids.isEmpty) return const <Map<String, dynamic>>[];

    try {
      final capped = ids.take(limit <= 0 ? 10 : limit).toList();
      final response = await http
          .get(
            _buildUri("products", {
              "include": capped.join(","),
              "per_page": capped.length.toString(),
            }),
            headers: _wcHeaders(),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        return const <Map<String, dynamic>>[];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const <Map<String, dynamic>>[];

      final byId = <int, Map<String, dynamic>>{};
      for (final raw in decoded) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final id = int.tryParse((map["id"] ?? "").toString()) ?? 0;
        if (id > 0) {
          byId[id] = map;
        }
      }

      return capped
          .where((id) => byId.containsKey(id))
          .map((id) => byId[id]!)
          .toList();
    } catch (e) {
      print("FetchProductsByIds Exception: $e");
      return const <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>> fetchSaleCollection({
    required String collectionKey,
    int page = 1,
    int perPage = 20,
  }) async {
    final normalizedKey = collectionKey.trim().toLowerCase();
    if (normalizedKey.isEmpty) {
      throw ArgumentError("collectionKey cannot be empty");
    }

    try {
      final uri = _buildWpV1Uri(
        "sale-collection?type=$normalizedKey&page=$page&per_page=$perPage",
      );
      final response = await http
          .get(uri, headers: _wcHeaders())
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          "Sale collection endpoint failed with status ${response.statusCode}",
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const FormatException("Sale collection response format invalid");
      }
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      print("FetchSaleCollection Exception: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _checkWooCoupon(
    String code,
    double currentTotal,
  ) async {
    try {
      final uri = _buildUri("coupons", {"code": code, "per_page": "1"});
      final response = await http.get(uri, headers: _wcHeaders());
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      if (body is! List || body.isEmpty) return null;
      final coupon = body.first;
      if (coupon is! Map) return null;

      final amountRaw = (coupon["amount"] ?? "0").toString();
      final discountType = (coupon["discount_type"] ?? "").toString();
      final minRaw = (coupon["minimum_amount"] ?? "0").toString();
      final maxRaw = (coupon["maximum_amount"] ?? "").toString();
      final dateExpiresRaw = (coupon["date_expires"] ?? "").toString();
      final usageLimit = int.tryParse((coupon["usage_limit"] ?? "0").toString()) ?? 0;
      final usageCount = int.tryParse((coupon["usage_count"] ?? "0").toString()) ?? 0;

      if (usageLimit > 0 && usageCount >= usageLimit) {
        return null;
      }

      if (dateExpiresRaw.trim().isNotEmpty) {
        final exp = DateTime.tryParse(dateExpiresRaw);
        if (exp != null && DateTime.now().isAfter(exp)) {
          return null;
        }
      }

      final amount = double.tryParse(amountRaw) ?? 0.0;
      if (amount <= 0) return null;

      String value;
      if (discountType == "percent") {
        value = "${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}%";
      } else {
        value = amount.toStringAsFixed(2);
      }

      final maxParsed = double.tryParse(maxRaw);
      final normalizedMax =
          (maxRaw.trim().isEmpty || (maxParsed != null && maxParsed <= 0))
              ? "9999999"
              : maxRaw;

      return {
        "coupon": code,
        "min": minRaw.isEmpty ? "0" : minRaw,
        "max": normalizedMax,
        "value": value,
      };
    } catch (e) {
      print("Woo Coupon Exception: $e");
      return null;
    }
  }

  Future<int?> _findCustomerIdByEmail(String email) async {
    try {
      final response = await http
          .get(
            _buildUri("customers", {"search": email, "per_page": "100"}),
            headers: _wcHeaders(),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data is! List) return null;

      for (final raw in data) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final customerEmail = (map["email"] ?? "")
            .toString()
            .trim()
            .toLowerCase();
        if (customerEmail == email.toLowerCase()) {
          final id = map["id"];
          if (id != null) return int.tryParse(id.toString());
        }
      }

      return null;
    } catch (e) {
      print("Find Customer By Email Exception: $e");
      return null;
    }
  }

  Future<int?> _resolveOrCreateCustomerId({
    required String name,
    required String email,
    required String phone,
    required String address,
    required String city,
    required String state,
    required String pincode,
    required String country,
  }) async {
    final existingId = await _findCustomerIdByEmail(email);
    if (existingId != null) return existingId;

    return _createCustomerFromCheckout(
      name: name,
      email: email,
      phone: phone,
      address: address,
      city: city,
      state: state,
      pincode: pincode,
      country: country,
    );
  }

  Future<int?> _createCustomerFromCheckout({
    required String name,
    required String email,
    required String phone,
    required String address,
    required String city,
    required String state,
    required String pincode,
    required String country,
  }) async {
    try {
      final parts = name.trim().split(RegExp(r"\s+"));
      final firstName = parts.isNotEmpty ? parts.first : "Customer";
      final lastName = parts.length > 1 ? parts.sublist(1).join(" ") : "";

      final usernameBase = email
          .split("@")
          .first
          .replaceAll(RegExp(r"[^a-zA-Z0-9._-]"), "");
      final username =
          "${usernameBase.isEmpty ? "user" : usernameBase}_${DateTime.now().millisecondsSinceEpoch}";

      final response = await http
          .post(
            _buildUri("customers", {}),
            headers: _wcHeaders(json: true),
            body: jsonEncode({
              "email": email,
              "username": username,
              "password": _generateTempPassword(),
              "first_name": firstName,
              "last_name": lastName,
              "billing": {
                "first_name": firstName,
                "last_name": lastName,
                "address_1": address,
                "city": city,
                "state": state,
                "postcode": pincode,
                "country": country,
                "phone": phone,
                "email": email,
              },
              "shipping": {
                "first_name": firstName,
                "last_name": lastName,
                "address_1": address,
                "city": city,
                "state": state,
                "postcode": pincode,
                "country": country,
              },
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 201) {
        return null;
      }

      final data = jsonDecode(response.body);
      return int.tryParse((data["id"] ?? "").toString());
    } catch (e) {
      print("Create Customer Exception: $e");
      return null;
    }
  }

  String _normalizeSearchText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9]+"), ' ')
        .replaceAll(RegExp(r"\s+"), ' ')
        .trim();
  }

  bool _containsLooseToken(String source, String token) {
    if (token.isEmpty || source.isEmpty) return false;
    if (source.contains(token)) return true;
    if (token.length < 3) return false;

    for (final word in source.split(' ')) {
      if (word.startsWith(token)) {
        return true;
      }
    }

    return _isLooseSubsequence(source.replaceAll(' ', ''), token);
  }

  bool _isLooseSubsequence(String source, String token) {
    if (token.isEmpty || source.isEmpty) return false;
    var sourceIndex = 0;
    var tokenIndex = 0;

    while (sourceIndex < source.length && tokenIndex < token.length) {
      if (source[sourceIndex] == token[tokenIndex]) {
        tokenIndex++;
      }
      sourceIndex++;
    }

    return tokenIndex == token.length;
  }

  int _scoreSearchMatch({
    required Map<String, dynamic> product,
    required String normalizedQuery,
    required List<String> queryTokens,
  }) {
    if (normalizedQuery.isEmpty) return 0;

    final name = _normalizeSearchText(product["name"]?.toString() ?? "");
    final sku = _normalizeSearchText(product["sku"]?.toString() ?? "");
    final description = _normalizeSearchText(
      product["short_description"]?.toString() ?? "",
    );
    final combined = [name, sku, description]
        .where((value) => value.isNotEmpty)
        .join(' ');

    var score = 0;

    if (name == normalizedQuery) score += 220;
    if (sku == normalizedQuery) score += 260;
    if (name.startsWith(normalizedQuery)) score += 150;
    if (sku.startsWith(normalizedQuery)) score += 200;
    if (name.contains(normalizedQuery)) score += 120;
    if (sku.contains(normalizedQuery)) score += 180;
    if (description.contains(normalizedQuery)) score += 50;

    var matchedTokens = 0;
    for (final token in queryTokens) {
      var tokenMatched = false;

      if (_containsLooseToken(sku, token)) {
        score += 65;
        tokenMatched = true;
      }
      if (_containsLooseToken(name, token)) {
        score += 44;
        tokenMatched = true;
      }
      if (_containsLooseToken(description, token)) {
        score += 18;
        tokenMatched = true;
      }

      if (tokenMatched) {
        matchedTokens++;
      }
    }

    if (queryTokens.isNotEmpty && matchedTokens == queryTokens.length) {
      score += 45;
    }

    final compressedQuery = normalizedQuery.replaceAll(' ', '');
    if (compressedQuery.isNotEmpty) {
      final compressedSku = sku.replaceAll(' ', '');
      final compressedName = name.replaceAll(' ', '');
      if (_isLooseSubsequence(compressedSku, compressedQuery) ||
          _isLooseSubsequence(compressedName, compressedQuery)) {
        score += 35;
      }
    }

    if (score == 0 && combined.contains(normalizedQuery)) {
      score = 20;
    }

    return score;
  }

  bool _isProductMapInStock(Map<String, dynamic> product) {
    final inStockRaw = product["in_stock"];
    if (inStockRaw is bool) return inStockRaw;

    final status = (product["stock_status"] ?? "").toString().toLowerCase();
    return status.isEmpty || status == "instock" || status == "onbackorder";
  }

  String _generateTempPassword([int length = 12]) {
    const chars =
        "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789@#\$%";
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }
}

class _ScoredSearchMatch {
  const _ScoredSearchMatch(this.product, this.score);

  final Map<String, dynamic> product;
  final int score;
}
