import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import 'package:marquee/marquee.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/woo_service.dart';
import '../services/admin_service.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import 'product_detail_screen.dart';
import 'products_screen.dart';
import 'cart_screen.dart';
import '../models/cart_item.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart';
import '../services/recently_viewed_service.dart';
import 'login_screen.dart';
import 'admin_dashboard_screen.dart';
import 'ai_brain_screen.dart';
import 'profile_screen.dart';
import 'ride_community_screen.dart';
import 'riding_groups_screen.dart';
import 'search_result_screen.dart';
import 'wallet_screen.dart';
import '../services/data_manager.dart';
import '../services/category_image_cache.dart';
import 'package:url_launcher/url_launcher.dart';
import 'bike_garage_screen.dart';
import 'motorcycle_service_station_screen.dart';
import 'sale_products_screen.dart';
import 'tracking_webview_screen.dart';
import 'top_category_detail_screen.dart';
import 'shop_by_category_screen.dart';

// ✅ STEP 2: Imported SignupScreen
import 'signup_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/app_cached_image.dart';
import '../widgets/skeletons.dart';
import '../widgets/sale_banner.dart';
import '../widgets/storefront_widgets.dart';
import '../widgets/yana_products_loading_screen.dart';
import '../widgets/category_fallback_image.dart';

// 🎨 BRAND COLORS (Racing Theme)
const Color primaryRed = Color(0xFFD7FC70);
const Color accentGold = Color(0xFFD7FC70);
const Color cardBg = Color(0xFF141414);
const Color scaffoldBg = Color(0xFF0D0D0D);

class HomeBannerMedia {
  const HomeBannerMedia.image(this.url)
    : type = _HomeBannerMediaType.image,
      youtubeId = null,
      sourceUrl = url;

  const HomeBannerMedia.video({
    required this.sourceUrl,
    required this.youtubeId,
  }) : type = _HomeBannerMediaType.video,
       url = '';

  final _HomeBannerMediaType type;
  final String url;
  final String sourceUrl;
  final String? youtubeId;

  bool get isVideo => type == _HomeBannerMediaType.video && youtubeId != null;
}

enum _HomeBannerMediaType { image, video }

class _HomeCategorySectionData {
  const _HomeCategorySectionData({
    required this.groupedCategories,
    required this.topBrandCategories,
    required this.imageVersion,
  });

  final Map<String, List> groupedCategories;
  final List<dynamic> topBrandCategories;
  final String imageVersion;
}

class _HomeTopNavItem {
  const _HomeTopNavItem({
    required this.title,
    required this.key,
    required this.icon,
    this.imageAsset,
  });

  final String title;
  final String key;
  final IconData icon;
  final String? imageAsset;
}

class HomeBannerMediaCard extends StatefulWidget {
  const HomeBannerMediaCard({
    super.key,
    required this.item,
    this.onVideoStarted,
    this.onVideoEnded,
  });

  final HomeBannerMedia item;
  final VoidCallback? onVideoStarted;
  final VoidCallback? onVideoEnded;

  @override
  State<HomeBannerMediaCard> createState() => _HomeBannerMediaCardState();
}

class _HomeBannerMediaCardState extends State<HomeBannerMediaCard> {
  WebViewController? _controller;
  bool _videoStarted = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.isVideo) {
      _controller = _buildYoutubeController(widget.item.youtubeId!);
    }
  }

  @override
  void didUpdateWidget(covariant HomeBannerMediaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.youtubeId != widget.item.youtubeId) {
      _videoStarted = false;
      if (widget.item.isVideo) {
        _controller = _buildYoutubeController(widget.item.youtubeId!);
      } else {
        _controller = null;
      }
    }
  }

  WebViewController _buildYoutubeController(String youtubeId) {
    final watchUrl = Uri.parse(
      "https://m.youtube.com/watch?v=$youtubeId&autoplay=1&playsinline=1",
    );

    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'YanaVideoState',
        onMessageReceived: (message) {
          final value = message.message.trim().toLowerCase();
          if (value == 'play' && !_videoStarted) {
            _videoStarted = true;
            widget.onVideoStarted?.call();
          } else if (value == 'ended') {
            widget.onVideoEnded?.call();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            await _attachVideoHooks();
          },
        ),
      )
      ..loadRequest(watchUrl);
  }

  Future<void> _attachVideoHooks() async {
    final controller = _controller;
    if (controller == null) return;

    const script = r'''
(() => {
  if (window.__yanaVideoHooksAttached) {
    return;
  }
  window.__yanaVideoHooksAttached = true;

  function sendState(value) {
    if (window.YanaVideoState && typeof window.YanaVideoState.postMessage === 'function') {
      window.YanaVideoState.postMessage(value);
    }
  }

  function makeVideoBanner(video) {
    if (!video) {
      return false;
    }
    try {
      document.documentElement.style.background = '#000';
      document.body.style.background = '#000';
      document.body.style.margin = '0';
      document.body.style.padding = '0';
      document.body.style.overflow = 'hidden';

      const all = Array.from(document.body.querySelectorAll('*'));
      for (const node of all) {
        if (node !== video && !node.contains(video)) {
          node.style.display = 'none';
        }
      }

      let parent = video.parentElement;
      while (parent) {
        parent.style.display = 'block';
        parent.style.position = 'fixed';
        parent.style.inset = '0';
        parent.style.width = '100vw';
        parent.style.height = '100vh';
        parent.style.margin = '0';
        parent.style.padding = '0';
        parent.style.background = '#000';
        parent.style.zIndex = '2147483646';
        parent = parent.parentElement;
      }

      // YouTube writes inline player dimensions after metadata loads. Keep the
      // video stretched to the banner viewport, including portrait videos.
      const bannerStyles = {
        position: 'fixed',
        inset: '0',
        left: '0',
        top: '0',
        width: '100vw',
        height: '100vh',
        'min-width': '100vw',
        'min-height': '100vh',
        'max-width': 'none',
        'max-height': 'none',
        margin: '0',
        padding: '0',
        transform: 'none',
        'object-fit': 'fill',
        'object-position': 'center',
        background: '#000',
        'z-index': '2147483647',
      };
      for (const [property, value] of Object.entries(bannerStyles)) {
        video.style.setProperty(property, value, 'important');
      }
      return true;
    } catch (error) {
      return false;
    }
  }

  function bindVideo() {
    const video = document.querySelector('video');
    if (!video) {
      window.setTimeout(bindVideo, 700);
      return;
    }

    makeVideoBanner(video);
    sendState('play');

    if (!video.__yanaEventsBound) {
      video.__yanaEventsBound = true;
      video.addEventListener('loadedmetadata', () => makeVideoBanner(video));
      video.addEventListener('playing', () => makeVideoBanner(video));
      window.addEventListener('resize', () => makeVideoBanner(video));
      video.addEventListener('play', () => sendState('play'));
      video.addEventListener('ended', () => sendState('ended'));
    }
  }

  bindVideo();
})();
''';

    try {
      await controller.runJavaScript(script);
    } catch (_) {
      // Ignore JS injection failures; video can still play without auto-advance hooks.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.item.isVideo) {
      return AppCachedImage(
        url: widget.item.sourceUrl,
        width: double.infinity,
        fit: BoxFit.cover,
        memCacheWidth: _HomeScreenState._homeBannerCacheWidth,
        maxWidthDiskCache: _HomeScreenState._homeBannerCacheWidth,
        filterQuality: FilterQuality.low,
      );
    }
    if (_controller != null) {
      return Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _controller!)),
        ],
      );
    }

    return Container(color: Colors.black);
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.recentlyViewedRefresh});

  final ValueListenable<int>? recentlyViewedRefresh;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const String _themePromptCompletedKey = "theme_prompt_completed_v1";
  static const String _shopByBikeIntroSeenKey = "shop_by_bike_intro_seen_v1";
  static const String _imageCacheKey = "home_page_slider_txt_cache";
  static const String _imageCacheVersionKey = "home_page_slider_txt_version";
  static const String _videoCacheKey = "home_banner_video_txt_cache";
  static const String _videoCacheVersionKey = "home_banner_video_txt_version";
  static const String _seenHomePopupCampaignsKey =
      "seen_home_popup_campaign_ids";
  static String _lastHandledPopupSignature = "";
  static bool _hasCheckedHomePopupThisSession = false;
  static const int _homeBannerCacheWidth = 1280;
  static const int _homeProductImageCacheWidth = 720;
  static const int _homeCategoryImageCacheWidth = 240;
  static const bool _showOfferMarquee = false;
  static const bool _showQuickAccessRail = false;
  final CarouselSliderController _bannerController = CarouselSliderController();
  Future<_HomeCategorySectionData>? _categorySectionFuture;
  Future<List<Product>>? _newArrivalsFuture;
  Future<List<Product>>? _bestSellersFuture;
  Future<List<Product>>? _bigDaysSaleProductsFuture;
  Future<Map<String, dynamic>>? _bikeGarageFuture;
  late Future<String?> _authTokenFuture;
  late final AnimationController _titleAnimController;
  late final AnimationController _cartPulseController;
  late final AnimationController _searchCtaController;
  late final AnimationController _saleLivePulseController;
  late final AnimationController _shopByBikeIntroController;
  String currentSearch = "";
  String offerText = "";
  bool isOfferLoading = true;
  int _currentBannerIndex = 0;

  static const List<String> _defaultBannerImageUrls = [
    "https://yanaworldwide.store/wp-content/uploads/slider-1.jpg",
    "https://yanaworldwide.store/wp-content/uploads/slider-2.jpg",
    "https://yanaworldwide.store/wp-content/uploads/slider-3.jpg",
  ];
  static const List<String> _defaultSearchSuggestions = [
    "RCB",
    "UMA Racing",
    "Helmet",
    "Full face helmet",
    "Helmet visor",
    "Helmet lock",
    "Riding gloves",
    "Riding jacket",
    "Riding pants",
    "Riding boots",
    "Knee guard",
    "Elbow guard",
    "Mobile holder",
    "Phone mount",
    "USB charger",
    "Chain lube",
    "Chain cleaner",
    "Engine oil",
    "Brake oil",
    "Coolant",
    "Crash guard",
    "Saree guard",
    "Leg guard",
    "Bike cover",
    "Tank pad",
    "Tank bag",
    "Tail bag",
    "Saddle bag",
    "LED indicators",
    "Aux lights",
    "Fog lights",
    "Mirror",
    "Handle grip",
    "Bar end mirror",
    "Touring luggage",
    "Brake pads",
    "Clutch lever",
    "Brake lever",
    "Spark plug",
    "Air filter",
    "Oil filter",
    "Disc lock",
    "Number plate holder",
    "Hazard flasher",
    "Exhaust",
    "Windshield",
    "Tyre inflator",
    "Puncture kit",
    "Rain cover",
    "Balaclava",
    "Rynox",
    "Axor",
    "MT helmet",
    "Studds",
    "Vega",
    "Raida",
    "Motul",
    "Liqui Moly",
  ];

  static const Map<String, List<String>> _searchSuggestionAliases = {
    "helmet": ["helm", "halmet", "cap"],
    "visor": ["glass", "shield"],
    "gloves": ["glove", "hand"],
    "jacket": ["jaket", "coat"],
    "boots": ["boot", "shoe", "shoes"],
    "mobile": ["phone", "holder", "mount"],
    "usb": ["charger", "charging"],
    "chain": ["lube", "cleaner"],
    "oil": ["lubricant", "lube", "engine"],
    "guard": ["crash", "leg", "saree", "protector"],
    "bag": ["luggage", "tank", "tail", "saddle", "touring"],
    "light": ["led", "fog", "aux", "indicator"],
    "mirror": ["bar end", "rear view"],
    "brake": ["pad", "lever", "disc"],
    "filter": ["air", "oil"],
    "lock": ["disc", "helmet", "security"],
    "cover": ["rain", "bike"],
  };

  final List<HomeBannerMedia> _bannerItems = [
    HomeBannerMedia.image(_defaultBannerImageUrls[0]),
    HomeBannerMedia.image(_defaultBannerImageUrls[1]),
    HomeBannerMedia.image(_defaultBannerImageUrls[2]),
  ];

  final WooService api = WooService();
  final DataManager dataManager = DataManager();

  final ScrollController _scrollController = ScrollController();
  final TextEditingController searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Product> products = [];
  bool isLoading = false;
  bool isInitialLoading = true;
  bool _hasInternet = true;
  bool _internetStatusKnown = false;
  bool _isCheckingInternet = false;
  int _internetFailureCount = 0;
  bool _serverRetryActive = false;
  bool _homePopupDialogShown = false;
  bool _themeChooserShown = false;
  bool _dailySaleEnabled = true;
  bool _bigDaysSaleEnabled = false;
  String _bigDaysSaleLabel = 'Big Days Sale';
  String _bigDaysFestivalKey = '';
  String? _upcomingSaleMessage;
  Timer? _saleStatusTimer;
  Timer? _saleTransitionTimer;
  bool _saleStatusLoading = false;
  bool _quickAccessExpanded = false;
  bool _shopByBikeIntroRunning = false;
  bool _shopByBikeIntroTopActive = false;
  bool _selectMotorcycleIntroActive = false;
  String _selectedTopCategoryKey = "shop_by_bike";
  String? _pressedTopCategoryKey;
  double _homeChromeCollapseProgress = 0;
  final ValueNotifier<double> _homeChromeCollapseProgressNotifier =
      ValueNotifier<double>(0);
  List<Product> _recentlyViewedProducts = const <Product>[];
  final GlobalKey _quickAccessRailKey = GlobalKey();
  final GlobalKey _cartIconKey = GlobalKey();
  final GlobalKey _searchBoxKey = GlobalKey();
  final GlobalKey _selectMotorcycleSectionKey = GlobalKey();
  final GlobalKey _topBrandsSectionKey = GlobalKey();

  Timer? _debounce;
  Timer? _internetRetryTimer;
  Future<void> openWhatsApp() async {
    final String phone = "919166666554"; // 91 + number (no + sign)

    final String message = Uri.encodeComponent(
      "Hello Yanaworldwide Support, I need help regarding my order.",
    );

    final Uri url = Uri.parse("https://wa.me/$phone?text=$message");

    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _titleAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    )..forward();
    _cartPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _searchCtaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    );
    _saleLivePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
    _shopByBikeIntroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );
    _scrollController.addListener(_handleHomeScroll);
    widget.recentlyViewedRefresh?.addListener(_handleRecentlyViewedRefresh);
    _searchFocusNode.addListener(_handleSearchFocusChanged);
    AnalyticsService.instance.logScreen("home");
    _authTokenFuture = AuthService().getToken();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleHomeLazyLoads();
    });

    isInitialLoading = true;
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      _loadInitialProductsWithVersionCheck();
    });
    Future<void>.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      _refreshInternetStatus();
    });
  }

  Future<void> _loadInitialProductsWithVersionCheck() async {
    await api.fetchAppVersion(forceRefresh: true);
    if (!mounted) return;
    await fetchProductsFromServer();
  }

  void _scheduleHomeLazyLoads() {
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      if (!mounted || _categorySectionFuture != null) return;
      setState(() {
        _categorySectionFuture = _loadHomeCategorySection();
      });
    });

    Future<void>.delayed(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      _loadSaleAvailability();
      _saleStatusTimer ??= Timer.periodic(const Duration(minutes: 1), (_) {
        if (WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed) {
          _loadSaleAvailability();
        }
      });
      _loadRecentlyViewedProducts();
    });

    Future<void>.delayed(const Duration(milliseconds: 620), () {
      if (!mounted || _bikeGarageFuture != null) return;
      setState(() {
        _bikeGarageFuture = _loadBikeGarageData();
      });
    });

    Future<void>.delayed(const Duration(milliseconds: 760), () {
      if (!mounted) return;
      _scheduleProductRailLoads();
    });

    Future<void>.delayed(const Duration(milliseconds: 940), () {
      if (!mounted) return;
      if (_showOfferMarquee) loadOffer();
      _loadBannerImages();
      _loadBannerVideos();
    });

    Future<void>.delayed(const Duration(milliseconds: 1250), () {
      if (!mounted) return;
      _checkForHomePopup();
      _warmBannerImages();
    });
  }

  Future<void> _loadRecentlyViewedProducts() async {
    final items = await RecentlyViewedService.instance.load();
    if (!mounted) return;
    setState(() {
      _recentlyViewedProducts = items;
    });
  }

  void _handleRecentlyViewedRefresh() {
    _loadRecentlyViewedProducts();
  }

  void _handleSearchFocusChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recentlyViewedRefresh != widget.recentlyViewedRefresh) {
      oldWidget.recentlyViewedRefresh?.removeListener(
        _handleRecentlyViewedRefresh,
      );
      widget.recentlyViewedRefresh?.addListener(_handleRecentlyViewedRefresh);
      _loadRecentlyViewedProducts();
    }
  }

  void _handleHomeScroll() {
    final nextProgress = (_scrollController.offset / 28).clamp(0.0, 1.0);
    if ((nextProgress - _homeChromeCollapseProgress).abs() < 0.02) return;
    if (!mounted) return;
    _homeChromeCollapseProgress = nextProgress;
    _homeChromeCollapseProgressNotifier.value = nextProgress;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadSaleAvailability();
      _refreshInternetStatus();
      _loadRecentlyViewedProducts();
    }
  }

  Future<_HomeCategorySectionData> _loadHomeCategorySection() async {
    final imageVersion = (await WooService().fetchAppVersion())?.trim() ?? "";
    final results = await Future.wait<dynamic>([
      dataManager.getGroupedCategoriesWithData(),
      dataManager.getTopBrandCategories(),
    ]);
    return _HomeCategorySectionData(
      groupedCategories: results[0] as Map<String, List>,
      topBrandCategories: results[1] as List<dynamic>,
      imageVersion: imageVersion,
    );
  }

  Future<List<Product>> _loadNewArrivals() async {
    final data = await dataManager.getNewArrivalProducts();
    return _parseHomeProductsSafely(data).take(10).toList();
  }

  Future<List<Product>> _loadBestSellers() async {
    final data = await dataManager.getBestSellingProducts();
    return _parseHomeProductsSafely(data).take(10).toList();
  }

  void _scheduleProductRailLoads() {
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (!mounted ||
          _newArrivalsFuture != null ||
          _bestSellersFuture != null) {
        return;
      }
      setState(() {
        _newArrivalsFuture = _loadNewArrivals();
        _bestSellersFuture = _loadBestSellers();
        _bigDaysSaleProductsFuture = _loadBigDaysSaleProducts();
      });
    });
  }

  Future<List<Product>> _loadBigDaysSaleProducts() async {
    final payload = await dataManager.getSaleCollection(
      'big_days_sale',
      perPage: 50,
    );
    if (payload['enabled'] != true || payload['items'] is! List) {
      return const <Product>[];
    }
    final label = (payload['label'] ?? _bigDaysSaleLabel).toString().trim();
    return (payload['items'] as List)
        .whereType<Map>()
        .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
        .where((product) {
          final price = product.priceValue;
          return product.image.trim().toLowerCase().startsWith('http') &&
              price != null &&
              price > 0;
        })
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
            saleBadgeLabel: label.isEmpty ? 'Big Days Sale' : label,
          ),
        )
        .toList(growable: false);
  }

  List<Product> _parseHomeProductsSafely(List<dynamic> items) {
    final products = <Product>[];
    for (final item in items.whereType<Map>()) {
      try {
        products.add(Product.fromJson(Map<String, dynamic>.from(item)));
      } catch (e) {
        debugPrint("Home product parse skipped: $e");
      }
    }
    return products;
  }

  List<_HomeTopNavItem> _defaultTopCategoryNavigation() {
    return const [
      _HomeTopNavItem(
        title: "Shop By Bike",
        key: "shop_by_bike",
        icon: Icons.motorcycle_rounded,
        imageAsset: 'assets/home_nav/shop_by_bike.png',
      ),
      _HomeTopNavItem(
        title: "Shop By Category",
        key: "shop_by_category",
        icon: Icons.grid_view_rounded,
        imageAsset: 'assets/home_nav/shop_by_category.png',
      ),
      _HomeTopNavItem(
        title: "Bike Accessories",
        key: "motorcycle_accessories",
        icon: Icons.handyman_rounded,
        imageAsset: 'assets/home_nav/bike_accessories.png',
      ),
      _HomeTopNavItem(
        title: "Riding Gears",
        key: "riding_gears",
        icon: Icons.sports_motorsports_rounded,
        imageAsset: 'assets/home_nav/riding_gears.png',
      ),
      _HomeTopNavItem(
        title: "Luggage",
        key: "luggage_touring",
        icon: Icons.luggage_rounded,
        imageAsset: 'assets/home_nav/luggage.png',
      ),
      _HomeTopNavItem(
        title: "Helmet",
        key: "helmets_accessories",
        icon: Icons.health_and_safety_rounded,
        imageAsset: 'assets/home_nav/helmet.png',
      ),
      _HomeTopNavItem(
        title: "Lubricants",
        key: "combos",
        icon: Icons.inventory_2_rounded,
        imageAsset: 'assets/home_nav/lubricants.png',
      ),
      _HomeTopNavItem(
        title: "Top Brands",
        key: "events",
        icon: Icons.workspace_premium_rounded,
        imageAsset: 'assets/home_nav/top_brands.png',
      ),
    ];
  }

  Future<void> _warmBannerImages() async {
    if (!mounted) return;
    final images = _bannerItems.where((item) => !item.isVideo).toList();
    for (final item in images) {
      if (!mounted) return;
      final source = item.sourceUrl.trim();
      if (!source.toLowerCase().startsWith("http")) continue;
      try {
        await precacheImage(
          CachedNetworkImageProvider(source, maxWidth: _homeBannerCacheWidth),
          context,
          size: const Size(1280, 720),
        );
      } catch (_) {}
    }
  }

  Future<void> _warmProductImages(List<Product> items) async {
    if (!mounted) return;
    for (final product in items.take(4)) {
      final imageUrl = product.image.trim();
      if (!imageUrl.toLowerCase().startsWith("http")) continue;
      unawaited(
        precacheImage(
          CachedNetworkImageProvider(imageUrl),
          context,
          size: const Size(720, 720),
        ),
      );
    }
  }

  void _scheduleInternetRecheck({Duration delay = const Duration(seconds: 5)}) {
    _internetRetryTimer?.cancel();
    _internetRetryTimer = Timer(delay, () {
      _refreshInternetStatus();
    });
  }

  Future<void> _refreshInternetStatus() async {
    if (_isCheckingInternet) return;
    _isCheckingInternet = true;
    bool online = false;
    try {
      final response = await http
          .get(Uri.parse("https://yanaworldwide.store/Yanaapp/version.txt"))
          .timeout(const Duration(seconds: 5));
      online = response.statusCode >= 200 && response.statusCode < 500;
    } catch (_) {
      online = false;
    } finally {
      _isCheckingInternet = false;
    }

    if (!mounted) return;

    if (online) {
      final shouldReloadAfterRetry =
          _serverRetryActive ||
          (!_hasInternet && products.isEmpty) ||
          (currentSearch.trim().isEmpty &&
              isInitialLoading &&
              products.isEmpty);
      _internetFailureCount = 0;
      if (!_internetStatusKnown || !_hasInternet || _serverRetryActive) {
        setState(() {
          _internetStatusKnown = true;
          _hasInternet = true;
          _serverRetryActive = false;
        });
      }
      _internetRetryTimer?.cancel();
      if (shouldReloadAfterRetry && currentSearch.trim().isEmpty) {
        unawaited(fetchProductsFromServer(forceRefresh: true));
      }
      return;
    }

    _internetFailureCount++;
    if (_internetFailureCount < 2) {
      _scheduleInternetRecheck();
      return;
    }

    if (!_internetStatusKnown || _hasInternet || !_serverRetryActive) {
      setState(() {
        _internetStatusKnown = true;
        _hasInternet = false;
        _serverRetryActive = true;
      });
    }

    if (!_hasInternet) {
      _scheduleInternetRecheck();
    }
  }

  void _refreshAuthToken() {
    setState(() {
      _authTokenFuture = AuthService().getToken();
    });
  }

  Future<void> _loadSaleAvailability() async {
    if (_saleStatusLoading || !mounted) return;
    _saleStatusLoading = true;
    try {
      final payloads = await Future.wait<Map<String, dynamic>>([
        WooService()
            .fetchSaleCollection(
              collectionKey: 'daily_sale',
              statusOnly: true,
              perPage: 1,
            )
            .catchError((_) => <String, dynamic>{}),
        WooService()
            .fetchSaleCollection(
              collectionKey: 'big_days_sale',
              statusOnly: true,
              perPage: 1,
            )
            .catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      setState(() {
        if (payloads[0]['enabled'] is bool) {
          _dailySaleEnabled = payloads[0]['enabled'] == true;
        }
        if (payloads[1]['enabled'] is bool) {
          _bigDaysSaleEnabled = payloads[1]['enabled'] == true;
          final responseLabel = (payloads[1]['label'] ?? '').toString().trim();
          _bigDaysFestivalKey = _normalizeFestivalKey(
            (payloads[1]['festival_key'] ?? '').toString(),
          );
          _bigDaysSaleLabel =
              responseLabel.isNotEmpty &&
                  responseLabel.toLowerCase() != 'big days sale'
              ? responseLabel
              : _festivalSaleLabel(_bigDaysFestivalKey) ?? 'Big Days Sale';
          final upcomingStart = DateTime.tryParse(
            '${payloads[1]['upcoming_starts_at']}',
          );
          final upcomingEnd = DateTime.tryParse(
            '${payloads[1]['upcoming_ends_at']}',
          );
          final upcomingLabel = (payloads[1]['upcoming_label'] ?? '')
              .toString()
              .trim();
          final upcomingKey = _normalizeFestivalKey(
            (payloads[1]['upcoming_festival_key'] ?? '').toString(),
          );
          final upcomingName = upcomingLabel.isNotEmpty
              ? upcomingLabel
              : _festivalSaleLabel(upcomingKey);
          final daysUntilStart =
              upcomingStart == null || payloads[1]['server_now'] == null
              ? null
              : upcomingStart
                    .difference(DateTime.parse('${payloads[1]['server_now']}'))
                    .inDays;
          _upcomingSaleMessage =
              upcomingStart != null &&
                  upcomingEnd != null &&
                  upcomingName != null &&
                  daysUntilStart != null &&
                  daysUntilStart >= 0 &&
                  daysUntilStart <= 15 &&
                  DateTime.parse(
                    '${payloads[1]['server_now']}',
                  ).isBefore(upcomingEnd)
              ? '$upcomingName Starts ${_formatSaleDate(upcomingStart)}'
              : null;
        }
      });
      if (_bigDaysSaleEnabled || _upcomingSaleMessage != null) {
        if (!_saleLivePulseController.isAnimating) {
          _saleLivePulseController.repeat(reverse: true);
        }
      } else if (_saleLivePulseController.isAnimating) {
        _saleLivePulseController.stop();
        _saleLivePulseController.value = 0;
      }
      if (payloads[1]['enabled'] is! bool) return;
      _saleTransitionTimer?.cancel();
      final serverNow = DateTime.tryParse('${payloads[1]['server_now']}');
      final transition = DateTime.tryParse(
        '${payloads[1]['next_transition_at']}',
      );
      if (serverNow != null && transition != null) {
        final delay = transition.difference(serverNow);
        _saleTransitionTimer = Timer(
          delay.isNegative ? Duration.zero : delay,
          () {
            if (!mounted) return;
            setState(() => _bigDaysSaleEnabled = false);
            _loadSaleAvailability();
          },
        );
      }
    } catch (_) {
      // Keep the last server-confirmed state; a failed refresh must not
      // reactivate a festival after its scheduled end.
    } finally {
      _saleStatusLoading = false;
    }
  }

  String _normalizeFestivalKey(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  String? _festivalSaleLabel(String key) {
    const labels = <String, String>{
      'sankranti': 'Sankranti Sale',
      'republic_day': 'Republic Day Sale',
      'shivratri': 'Maha Shivratri Sale',
      'holi': 'Holi Sale',
      'ugadi': 'Ugadi Sale',
      'eid_fitr': 'Eid Sale',
      'baisakhi': 'Baisakhi Sale',
      'akshaya_tritiya': 'Akshaya Tritiya Sale',
      'eid_adha': 'Eid Sale',
      'rakhi': 'Rakhi Sale',
      'independence_day': 'Independence Day Sale',
      'janmashtami': 'Janmashtami Sale',
      'ganesh': 'Ganesh Utsav Sale',
      'onam': 'Onam Sale',
      'navratri': 'Navratri Sale',
      'dussehra': 'Dussehra Sale',
      'dhanteras': 'Dhanteras Sale',
      'diwali': 'Diwali Sale',
      'chhath': 'Chhath Puja Sale',
      'gurpurab': 'Gurpurab Sale',
      'christmas': 'Christmas Sale',
      'new_year': 'New Year Sale',
    };
    return labels[key];
  }

  String _formatSaleDate(DateTime date) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }

  Future<void> _checkForHomePopup() async {
    if (!mounted || _homePopupDialogShown || _hasCheckedHomePopupThisSession) {
      return;
    }

    try {
      _hasCheckedHomePopupThisSession = true;
      final data = await AdminService().getPublicHomePopupStatus();
      if (!mounted || data["ok"] != true || data["active"] != true) return;

      _homePopupDialogShown = true;
      final title = (data["title"] ?? "Important Update").toString().trim();
      final message = (data["message"] ?? "").toString().trim();
      final buttonText = (data["button_text"] ?? "Got it").toString().trim();
      final actionUrl = (data["action_url"] ?? "").toString().trim();
      final updatedAt = (data["updated_at"] ?? "").toString().trim();
      final campaignId = (data["campaign_id"] ?? "").toString().trim();
      final popupSignature = [
        campaignId,
        updatedAt,
        title,
        message,
        buttonText,
        actionUrl,
      ].join("|");
      if (popupSignature.replaceAll("|", "").trim().isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final acceptedPopupSignature =
          prefs.getString("accepted_home_popup_signature") ?? "";
      final acceptedCampaignId =
          prefs.getString("accepted_home_popup_campaign_id") ?? "";
      final seenCampaignIds =
          prefs.getStringList(_seenHomePopupCampaignsKey) ?? const <String>[];
      if (_lastHandledPopupSignature == popupSignature) return;
      if (campaignId.isNotEmpty && acceptedCampaignId == campaignId) return;
      if (campaignId.isNotEmpty && seenCampaignIds.contains(campaignId)) return;
      if (acceptedPopupSignature == popupSignature) return;

      var popupAction = "dismiss";

      Future<void> markPopupHandled() async {
        _lastHandledPopupSignature = popupSignature;
        await prefs.setString("accepted_home_popup_signature", popupSignature);
        if (campaignId.isNotEmpty) {
          await prefs.setString("accepted_home_popup_campaign_id", campaignId);
        }
        if (campaignId.isNotEmpty && !seenCampaignIds.contains(campaignId)) {
          final updatedSeenCampaignIds = <String>[
            ...seenCampaignIds,
            campaignId,
          ];
          await prefs.setStringList(
            _seenHomePopupCampaignsKey,
            updatedSeenCampaignIds,
          );
        }
        await AdminService().acknowledgeHomePopup(
          campaignId: campaignId,
          action: popupAction,
        );
      }

      unawaited(
        AnalyticsService.instance.logHomePopupEvent(
          action: "view",
          campaignId: campaignId,
          title: title,
          buttonText: buttonText,
          actionUrl: actionUrl,
        ),
      );
      await markPopupHandled();

      await showGeneralDialog<void>(
        context: context,
        barrierLabel: "home_popup",
        barrierDismissible: true,
        barrierColor: Colors.black54,
        pageBuilder: (_, __, ___) => const SizedBox.shrink(),
        transitionBuilder: (context, animation, _, __) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1F2937), Color(0xFF111827)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 26,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: accentGold.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.notifications_active_rounded,
                                color: accentGold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                title.isEmpty ? "Important Update" : title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () async {
                                popupAction = "close";
                                await markPopupHandled();
                                if (!mounted) return;
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        if (message.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            message,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  popupAction = "close";
                                  await markPopupHandled();
                                  if (!mounted) return;
                                  Navigator.of(context).pop();
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white24),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text("Close"),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  popupAction = "cta";
                                  await markPopupHandled();
                                  if (!mounted) return;
                                  Navigator.of(context).pop();
                                  if (actionUrl.isNotEmpty) {
                                    final uri = Uri.tryParse(actionUrl);
                                    if (uri != null) {
                                      await launchUrl(
                                        uri,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentGold,
                                  foregroundColor: Colors.black,
                                ),
                                child: Text(
                                  buttonText.isEmpty ? "Got it" : buttonText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );

      unawaited(
        AnalyticsService.instance.logHomePopupEvent(
          action: popupAction,
          campaignId: campaignId,
          title: title,
          buttonText: buttonText,
          actionUrl: actionUrl,
        ),
      );
      await markPopupHandled();
    } catch (_) {
      // Fail-open: popup fetch must never block home screen.
    } finally {
      _homePopupDialogShown = false;
    }
  }

  Future<void> _maybeShowInitialThemeChooser() async {
    if (!mounted || _themeChooserShown) return;
    final prefs = await SharedPreferences.getInstance();
    final hasCompletedPrompt = prefs.getBool(_themePromptCompletedKey) ?? false;
    final hasSavedTheme = (prefs.getString('selected_app_theme') ?? '')
        .trim()
        .isNotEmpty;
    if (hasCompletedPrompt || hasSavedTheme) return;

    _themeChooserShown = true;
    if (!mounted) return;
    final themeController = context.read<AppThemeController>();
    final palette = context.appPalette;

    Future<void> completePrompt() async {
      await prefs.setBool(_themePromptCompletedKey, true);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final sheetPalette =
            Theme.of(sheetContext).extension<AppThemePalette>() ??
            AppThemes.midnightPalette;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Choose Your Theme",
                  style: TextStyle(
                    color: sheetPalette.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Pick the storefront style you want to start with.",
                  style: TextStyle(color: sheetPalette.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: AppThemes.allModes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final mode = AppThemes.allModes[index];
                      final optionPalette = AppThemes.paletteFor(mode);
                      final isSelected = themeController.mode == mode;
                      return InkWell(
                        onTap: () async {
                          await themeController.setTheme(mode);
                          await completePrompt();
                          if (!sheetContext.mounted) return;
                          Navigator.pop(sheetContext);
                        },
                        borderRadius: BorderRadius.circular(22),
                        child: Ink(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                optionPalette.heroStart,
                                optionPalette.heroEnd,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isSelected
                                  ? optionPalette.accent
                                  : optionPalette.border,
                              width: isSelected ? 1.4 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      optionPalette.label,
                                      style: TextStyle(
                                        color: optionPalette.textPrimary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _buildThemeDot(optionPalette.accent),
                                        _buildThemeDot(optionPalette.highlight),
                                        _buildThemeDot(optionPalette.surface),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? optionPalette.accent
                                      : optionPalette.surfaceStrong,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isSelected
                                      ? Icons.check_rounded
                                      : Icons.arrow_forward_rounded,
                                  color: isSelected
                                      ? optionPalette.onAccent
                                      : optionPalette.textPrimary,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      await completePrompt();
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                    },
                    child: const Text("Keep Shop Lime"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _runInitialThemeAndShopByBikeIntro() async {
    await _maybeShowInitialThemeChooser();
    await _maybeRunShopByBikeIntroTour();
  }

  Future<void> _maybeRunShopByBikeIntroTour() async {
    if (!mounted || _shopByBikeIntroRunning) return;
    final prefs = await SharedPreferences.getInstance();
    final hasSeenIntro = prefs.getBool(_shopByBikeIntroSeenKey) ?? false;
    if (hasSeenIntro) return;

    final hasCompletedThemePrompt =
        prefs.getBool(_themePromptCompletedKey) ?? false;
    final hasSavedTheme = (prefs.getString('selected_app_theme') ?? '')
        .trim()
        .isNotEmpty;
    if (!hasCompletedThemePrompt && !hasSavedTheme) return;

    _shopByBikeIntroRunning = true;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) {
      _shopByBikeIntroRunning = false;
      return;
    }

    setState(() {
      _selectedTopCategoryKey = "shop_by_bike";
      _shopByBikeIntroTopActive = true;
      _selectMotorcycleIntroActive = false;
    });
    _shopByBikeIntroController.repeat(reverse: true);

    await Future<void>.delayed(const Duration(milliseconds: 2100));
    if (!mounted) return;

    setState(() {
      _shopByBikeIntroTopActive = false;
      _selectMotorcycleIntroActive = false;
    });
    _shopByBikeIntroController.stop();
    _shopByBikeIntroController.value = 0;
    await prefs.setBool(_shopByBikeIntroSeenKey, true);
    _shopByBikeIntroRunning = false;
  }

  Widget _buildThemeDot(Color color) {
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Future<void> fetchProductsFromServer({
    bool loadMore = false,
    String? searchQuery,
    bool forceRefresh = false,
  }) async {
    if (isLoading) return;

    setState(() => isLoading = true);

    try {
      final trimmedSearch = searchQuery?.trim() ?? "";
      final data = trimmedSearch.isNotEmpty
          ? (await api.searchProductsSmart(
              query: trimmedSearch,
              perPage: 10,
              page: 1,
              orderBy: "date",
              order: "desc",
            )).items
          : await dataManager.getHomeProducts(
              page: 1,
              search: null,
              forceRefresh: forceRefresh,
            );

      if (trimmedSearch.isEmpty && data.isEmpty && products.isEmpty) {
        if (mounted) {
          setState(() {
            isLoading = false;
            isInitialLoading = true;
          });
          _scheduleInternetRecheck();
        }
        return;
      }

      final parsedProducts = data
          .map<Product>((e) => Product.fromJson(e))
          .toList();
      final newProducts = parsedProducts
          .where((product) => _isValidHomeProduct(product))
          .toList();

      if (mounted) {
        setState(() {
          products = newProducts;

          isLoading = false;
          isInitialLoading = false;
          _serverRetryActive = false;
        });
        unawaited(_warmProductImages(newProducts));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_runInitialThemeAndShopByBikeIntro());
        });
      }
    } catch (e) {
      print("Error fetching products: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
          isInitialLoading = currentSearch.trim().isEmpty && products.isEmpty;
        });
        if (currentSearch.trim().isEmpty) {
          _scheduleInternetRecheck();
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_runInitialThemeAndShopByBikeIntro());
        });
      }
    }
  }

  bool _isValidHomeProduct(Product product) {
    final image = product.image.trim();
    final hasValidImage =
        image.isNotEmpty && image.toLowerCase().startsWith("http");

    final normalizedPrice = product.price.replaceAll(",", "").trim();
    final parsedPrice = double.tryParse(normalizedPrice);
    final hasValidPrice = parsedPrice != null && parsedPrice > 0;

    return hasValidImage && hasValidPrice;
  }

  void loadOffer() async {
    try {
      String text = await api.fetchOfferText();
      if (mounted) {
        setState(() {
          offerText = text;
          isOfferLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isOfferLoading = false);
    }
  }

  Uri? _extractOfferLink(String text) {
    final match = RegExp(
      r'((https?:\/\/)?([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(\/\S*)?)',
      caseSensitive: false,
    ).firstMatch(text);
    final raw = match?.group(0)?.trim();
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw.startsWith('http://') || raw.startsWith('https://')
        ? raw
        : 'https://$raw';
    return Uri.tryParse(normalized);
  }

  Future<void> _openOfferLink() async {
    final uri = _extractOfferLink(offerText);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to open offer link")),
      );
    }
  }

  void _goToSearch() {
    final query = searchController.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SearchResultScreen(searchQuery: query)),
    );
  }

  String _normalizeSuggestionText(String value) {
    return value.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), " ").trim();
  }

  List<String> _suggestionTokens(String value) {
    final normalized = _normalizeSuggestionText(value);
    if (normalized.isEmpty) return const <String>[];
    return normalized
        .split(RegExp(r"\s+"))
        .where((token) => token.length >= 2)
        .toList(growable: false);
  }

  bool _matchesSearchSuggestion(String suggestion, String query) {
    final normalizedSuggestion = _normalizeSuggestionText(suggestion);
    final normalizedQuery = _normalizeSuggestionText(query);
    if (normalizedQuery.isEmpty) return true;
    if (normalizedSuggestion.contains(normalizedQuery)) return true;

    final queryTokens = _suggestionTokens(query);
    final suggestionTokens = _suggestionTokens(suggestion);
    for (final queryToken in queryTokens) {
      if (suggestionTokens.any(
        (term) => term.contains(queryToken) || queryToken.contains(term),
      )) {
        return true;
      }
      for (final entry in _searchSuggestionAliases.entries) {
        final aliasGroup = [entry.key, ...entry.value]
            .map(_normalizeSuggestionText)
            .where((term) => term.isNotEmpty)
            .toList(growable: false);
        final queryHitsAlias =
            aliasGroup.any((alias) => alias.contains(queryToken)) ||
            aliasGroup.any((alias) => queryToken.contains(alias));
        if (!queryHitsAlias) continue;
        if (suggestionTokens.any(aliasGroup.contains)) return true;
      }
    }

    return false;
  }

  List<String> _searchSuggestions() {
    final query = searchController.text.trim();
    if (!_searchFocusNode.hasFocus && query.isEmpty) {
      return const <String>[];
    }

    final suggestions = <String>[];
    void addTerm(String value) {
      final term = value.trim();
      if (term.length < 2) return;
      if (suggestions.any((item) => item.toLowerCase() == term.toLowerCase())) {
        return;
      }
      suggestions.add(term);
    }

    for (final product in products) {
      if (query.isNotEmpty &&
          !_matchesSearchSuggestion(product.name, query) &&
          !_matchesSearchSuggestion(product.sku, query)) {
        continue;
      }
      addTerm(product.name);
      if (product.sku.isNotEmpty && query.isNotEmpty) {
        addTerm(product.sku);
      }
      if (suggestions.length >= 6) return suggestions;
    }

    for (final product in _recentlyViewedProducts) {
      if (query.isNotEmpty &&
          !_matchesSearchSuggestion(product.name, query) &&
          !_matchesSearchSuggestion(product.sku, query)) {
        continue;
      }
      addTerm(product.name);
      if (suggestions.length >= 6) return suggestions;
    }

    for (final term in _defaultSearchSuggestions) {
      if (_matchesSearchSuggestion(term, query)) {
        addTerm(term);
      }
      if (suggestions.length >= 6) break;
    }

    if (suggestions.isEmpty && query.length >= 2) {
      addTerm("$query accessories");
      addTerm("$query parts");
      addTerm("$query for bike");
    }

    return suggestions;
  }

  void _selectSearchSuggestion(String suggestion) {
    final trimmed = suggestion.trim();
    if (trimmed.isEmpty) return;
    searchController.value = TextEditingValue(
      text: trimmed,
      selection: TextSelection.collapsed(offset: trimmed.length),
    );
    _handleSearchChanged(trimmed);
    _goToSearch();
  }

  Future<void> _openBarcodeSearchOption() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _BarcodeScannerScreen()),
    );
    final scannedCode = code?.trim();
    if (!mounted || scannedCode == null || scannedCode.isEmpty) return;
    searchController.text = scannedCode;
    _handleSearchChanged(scannedCode);
    _goToSearch();
  }

  void _handleSearchChanged(String value) {
    final trimmed = value.trim();
    _debounce?.cancel();
    _syncSearchCallToAction(trimmed);

    if (!mounted) return;
    setState(() {
      currentSearch = trimmed;
      isInitialLoading = trimmed.isNotEmpty;
    });

    final debounceMs = trimmed.isEmpty
        ? 100
        : trimmed.length < 3
        ? 220
        : 300;
    _debounce = Timer(Duration(milliseconds: debounceMs), () {
      fetchProductsFromServer(searchQuery: trimmed.isEmpty ? null : trimmed);
    });
  }

  void _fillSearchFromBadge(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _syncSearchCallToAction(trimmed);
    setState(() {
      currentSearch = trimmed;
      searchController.value = TextEditingValue(
        text: trimmed,
        selection: TextSelection.collapsed(offset: trimmed.length),
      );
    });
  }

  void _syncSearchCallToAction(String query) {
    final hasQuery = query.trim().isNotEmpty;
    if (hasQuery) {
      if (!_searchCtaController.isAnimating) {
        _searchCtaController.repeat(reverse: true);
      }
    } else {
      _searchCtaController.stop();
      _searchCtaController.value = 0;
    }
  }

  Widget _buildAnimatedSearchArrow() {
    return AnimatedBuilder(
      animation: _searchCtaController,
      builder: (context, child) {
        final hasQuery = currentSearch.trim().isNotEmpty;
        final t = Curves.easeInOutCubic.transform(_searchCtaController.value);
        const lime = Color(0xFFB6F21E);

        return SizedBox(
          width: 36,
          height: 34,
          child: Transform.scale(
            scale: hasQuery ? 1 + (0.035 * t) : 1,
            child: Container(
              decoration: BoxDecoration(
                color: lime,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: lime.withOpacity(hasQuery ? 0.34 : 0.18),
                    blurRadius: hasQuery ? 9 : 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Transform.translate(
                offset: Offset(hasQuery ? 2 * t : 0, 0),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.black,
                  size: 21,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchSuggestionsPanel(
    AppThemePalette palette,
    List<String> suggestions,
  ) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 38,
      alignment: Alignment.centerLeft,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: suggestions.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Center(
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.accent.withOpacity(0.24)),
                ),
                child: Text(
                  "Search Suggestions",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.isLight
                        ? const Color(0xFF466600)
                        : palette.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            );
          }

          final suggestion = suggestions[index - 1];
          return Center(
            child: InkWell(
              onTap: () => _selectSearchSuggestion(suggestion),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 170),
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.border.withOpacity(0.85)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: palette.textMuted,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        suggestion,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _fillSearchFromBadgeAnimated(
    String query,
    BuildContext startContext,
  ) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final startBox = startContext.findRenderObject() as RenderBox?;
    final endBox =
        _searchBoxKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlay == null || startBox == null || endBox == null) {
      _fillSearchFromBadge(trimmed);
      return;
    }

    final start = startBox.localToGlobal(startBox.size.center(Offset.zero));
    final end = endBox.localToGlobal(endBox.size.center(Offset.zero));
    final palette = context.appPalette;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOutCubicEmphasized,
    );

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) {
        final t = animation.value;
        final width = lerpDouble(startBox.size.width, 140, t) ?? 140;
        final height = lerpDouble(startBox.size.height, 34, t) ?? 34;
        final dx =
            (lerpDouble(start.dx, end.dx, t) ?? end.dx) +
            (math.sin(t * math.pi) * 10 * (1 - t));
        final dy =
            (lerpDouble(start.dy, end.dy, t) ?? end.dy) -
            (math.sin(t * math.pi) * 24);
        final opacity = t < 0.9
            ? 1.0
            : (1.0 - ((t - 0.9) / 0.1)).clamp(0.0, 1.0);
        final glowOpacity = (1 - t).clamp(0.0, 1.0) * 0.22;

        return Positioned(
          left: dx - (width / 2),
          top: dy - (height / 2),
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -8,
                    top: -6,
                    child: Opacity(
                      opacity: glowOpacity,
                      child: Container(
                        width: width + 16,
                        height: height + 12,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: palette.accent.withOpacity(0.55),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: width,
                    height: height,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: palette.accent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: palette.surface, width: 1.2),
                    ),
                    child: Text(
                      trimmed,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.onAccent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    controller.addListener(entry.markNeedsBuild);
    await controller.forward();
    entry.remove();
    controller.dispose();
    if (mounted) {
      _fillSearchFromBadge(trimmed);
    }
  }

  Future<void> _loadBannerVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedRaw = prefs.getString(_videoCacheKey) ?? "";
    if (cachedRaw.isNotEmpty && mounted) {
      final cachedItems = _parseVideoLinks(cachedRaw);
      if (cachedItems.isNotEmpty) {
        setState(() {
          _replaceVideoBanners(cachedItems);
        });
      }
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
    }

    final currentVersion = (await api.fetchAppVersion())?.trim() ?? "";
    final cachedVersion = (prefs.getString(_videoCacheVersionKey) ?? "").trim();

    if (cachedRaw.isNotEmpty &&
        currentVersion.isNotEmpty &&
        cachedVersion == currentVersion) {
      return;
    }

    try {
      final response = await http
          .get(Uri.parse("https://yanaworldwide.store/Yanaapp/video.txt"))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        if (cachedRaw.isNotEmpty && mounted) {
          final cachedItems = _parseVideoLinks(cachedRaw);
          if (cachedItems.isNotEmpty) {
            setState(() {
              _replaceVideoBanners(cachedItems);
            });
          }
        }
        return;
      }

      final videoItems = _parseVideoLinks(response.body);
      if (videoItems.isEmpty) return;

      await prefs.setString(_videoCacheKey, response.body);
      if (currentVersion.isNotEmpty) {
        await prefs.setString(_videoCacheVersionKey, currentVersion);
      }
      if (!mounted) return;

      setState(() {
        _replaceVideoBanners(videoItems);
      });
    } catch (_) {
      if (cachedRaw.isEmpty || !mounted) {
        return;
      }
      final cachedItems = _parseVideoLinks(cachedRaw);
      if (cachedItems.isEmpty) return;
      setState(() {
        _replaceVideoBanners(cachedItems);
      });
    }
  }

  Future<Map<String, dynamic>> _loadBikeGarageData() async {
    final selectedBike = await dataManager.getSelectedBike();
    if (selectedBike == null || selectedBike.trim().isEmpty) {
      return {
        "selectedBike": "",
        "categories": const <Map<String, dynamic>>[],
        "products": const <Product>[],
      };
    }

    final categories = await dataManager.getSuggestedCategoriesForBike(
      selectedBike,
    );
    final rawProducts = await dataManager.getSuggestedProductsForBike(
      selectedBike,
    );
    final products = rawProducts
        .whereType<Map>()
        .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
        .where((product) => _isValidHomeProduct(product))
        .take(8)
        .toList();

    return {
      "selectedBike": selectedBike,
      "categories": categories,
      "products": products,
    };
  }

  void _refreshBikeGarage() {
    setState(() {
      _bikeGarageFuture = _loadBikeGarageData();
    });
  }

  Widget _buildBikeGarageSection() {
    if (_bikeGarageFuture == null) return const SizedBox.shrink();
    return FutureBuilder<Map<String, dynamic>>(
      future: _bikeGarageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SkeletonBox(height: 180, radius: 20),
          );
        }

        final data = snapshot.data ?? const <String, dynamic>{};
        final selectedBike = (data["selectedBike"] ?? "").toString().trim();
        final categories = (data["categories"] as List?) ?? const [];
        final products = (data["products"] as List?) ?? const [];

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF171B28), Color(0xFF111522)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.two_wheeler_rounded, color: accentGold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedBike.isEmpty
                          ? "Bike Garage"
                          : "For Your Bike: $selectedBike",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BikeGarageScreen(),
                        ),
                      );
                      _refreshBikeGarage();
                    },
                    child: Text(
                      selectedBike.isEmpty ? "Add Bike" : "Change",
                      style: const TextStyle(color: accentGold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                selectedBike.isEmpty
                    ? "Apni bike add karo aur matching category/products dekho."
                    : "Selected bike ke according compatible suggestions yahan show honge.",
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              if (selectedBike.isNotEmpty && categories.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.take(4).map((raw) {
                    if (raw is! Map) return const SizedBox.shrink();
                    final category = Map<String, dynamic>.from(raw);
                    final categoryId =
                        int.tryParse((category["id"] ?? "").toString()) ?? 0;
                    final title = (category["name"] ?? "").toString();
                    return ActionChip(
                      backgroundColor: Colors.white10,
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
              ],
              if (selectedBike.isNotEmpty && products.isNotEmpty) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    cacheExtent: 360,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    itemCount: products.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final product = products[index] as Product;
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProductDetailScreen(product: product),
                            ),
                          ).then((_) => _loadRecentlyViewedProducts());
                        },
                        child: Container(
                          width: 150,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1F2E),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(18),
                                ),
                                child: SizedBox(
                                  height: 116,
                                  width: double.infinity,
                                  child: AppCachedImage(
                                    url: product.image,
                                    fit: BoxFit.cover,
                                    memCacheWidth: _homeProductImageCacheWidth,
                                    maxWidthDiskCache:
                                        _homeProductImageCacheWidth,
                                    filterQuality: FilterQuality.low,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        height: 1.25,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          "\u20B9${product.price}",
                                          style: const TextStyle(
                                            color: accentGold,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        if (product.hasDiscount)
                                          Text(
                                            "\u20B9${product.regularPrice}",
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                            ),
                                          ),
                                        if (product.discountPercent > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: primaryRed,
                                              borderRadius:
                                                  BorderRadius.circular(999),
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
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _replaceVideoBanners(List<HomeBannerMedia> videoItems) {
    _bannerItems.removeWhere((item) => item.isVideo);
    _bannerItems.addAll(videoItems);
  }

  void _replaceImageBanners(List<HomeBannerMedia> imageItems) {
    _bannerItems.removeWhere((item) => !item.isVideo);
    _bannerItems.insertAll(0, imageItems);
    if (_currentBannerIndex >= _bannerItems.length) {
      _currentBannerIndex = 0;
    }
  }

  String _versionedBannerImageUrl(String url, String cacheRevision) {
    if (cacheRevision.isEmpty) return url;
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            "banner_build": cacheRevision,
          },
        )
        .toString();
  }

  List<HomeBannerMedia> _parseImageLinks(
    String raw, {
    required String cacheRevision,
  }) {
    final normalized = raw.replaceAll("\r", "\n");
    final items = <HomeBannerMedia>[];
    final seen = <String>{};

    for (final line in normalized.split("\n")) {
      final value = line.trim();
      if (value.isEmpty || value.startsWith("#")) continue;
      final lower = value.toLowerCase();
      if (!lower.startsWith("http://") && !lower.startsWith("https://")) {
        continue;
      }
      if (seen.contains(value)) continue;
      seen.add(value);
      items.add(
        HomeBannerMedia.image(_versionedBannerImageUrl(value, cacheRevision)),
      );
    }

    if (items.isNotEmpty) {
      return items;
    }

    return _defaultBannerImageUrls
        .map(
          (url) => HomeBannerMedia.image(
            _versionedBannerImageUrl(url, cacheRevision),
          ),
        )
        .toList();
  }

  List<HomeBannerMedia> _parseVideoLinks(String raw) {
    final normalized = raw.replaceAll("\r", "\n");
    final items = <HomeBannerMedia>[];
    final seen = <String>{};

    for (final line in normalized.split("\n")) {
      final value = line.trim();
      if (value.isEmpty || value.startsWith("#")) continue;

      final youtubeId = _extractYoutubeId(value);
      if (youtubeId == null || youtubeId.isEmpty) continue;
      if (seen.contains(youtubeId)) continue;

      seen.add(youtubeId);
      items.add(HomeBannerMedia.video(sourceUrl: value, youtubeId: youtubeId));
    }

    return items;
  }

  String? _extractYoutubeId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final host = uri.host.toLowerCase();
    if (host.contains("youtu.be")) {
      final segment = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : "";
      return segment.isEmpty ? null : segment;
    }

    if (host.contains("youtube.com")) {
      final watchId = uri.queryParameters["v"]?.trim();
      if (watchId != null && watchId.isNotEmpty) return watchId;

      if (uri.pathSegments.isNotEmpty) {
        final first = uri.pathSegments.first.toLowerCase();
        if ((first == "embed" || first == "shorts") &&
            uri.pathSegments.length > 1) {
          return uri.pathSegments[1].trim();
        }
      }
    }

    return null;
  }

  bool _opensTopCategoryDetailPage(String key) {
    return const {
      "motorcycle_accessories",
      "riding_gears",
      "luggage_touring",
      "helmets_accessories",
      "combos",
    }.contains(key);
  }

  void _handleTopCategoryTap(_HomeTopNavItem item) {
    if (item.key == "shop_by_category") {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ShopByCategoryScreen()));
    } else if (item.key == "shop_by_bike") {
      if (_selectedTopCategoryKey != item.key) {
        setState(() {
          _selectedTopCategoryKey = item.key;
        });
      }
      _scrollToSelectMotorcycleSection();
    } else if (item.key == "events") {
      if (_selectedTopCategoryKey != item.key) {
        setState(() {
          _selectedTopCategoryKey = item.key;
        });
      }
      _scrollToTopBrandsSection();
    } else if (_opensTopCategoryDetailPage(item.key)) {
      final remoteSource = TopCategoryDetailScreen.remoteSourceFor(item.key);
      if (remoteSource != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ShopByCategoryScreen(
              title: item.title,
              sourceUrl: remoteSource.sourceUrl,
              cacheKeyPrefix: remoteSource.cacheKeyPrefix,
            ),
          ),
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TopCategoryDetailScreen(
            categoryKey: item.key,
            title: item.title,
            icon: item.icon,
          ),
        ),
      );
    }
  }

  Future<void> _scrollToSelectMotorcycleSection({
    Duration duration = const Duration(milliseconds: 520),
    double alignment = 0.12,
  }) async {
    for (var attempt = 0; attempt < 6; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
      if (!mounted || !_scrollController.hasClients) return;
      final targetContext = _selectMotorcycleSectionKey.currentContext;
      if (targetContext == null) continue;
      await Scrollable.ensureVisible(
        targetContext,
        duration: duration,
        curve: Curves.easeOutCubic,
        alignment: alignment,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
      return;
    }
  }

  Future<void> _scrollToTopBrandsSection() async {
    for (var attempt = 0; attempt < 6; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
      if (!mounted || !_scrollController.hasClients) return;
      final targetContext = _topBrandsSectionKey.currentContext;
      if (targetContext == null) continue;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        alignment: 0.12,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
      return;
    }
  }

  Future<void> _scrollToTop({
    Duration duration = const Duration(milliseconds: 520),
  }) async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: duration,
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildSelectMotorcycleIntroHighlight({required Widget child}) {
    if (!_selectMotorcycleIntroActive) return child;
    final palette = context.appPalette;
    return AnimatedBuilder(
      animation: _shopByBikeIntroController,
      builder: (context, _) {
        final pulse = _shopByBikeIntroController.value;
        return Transform.scale(
          scale: 1 + (pulse * 0.035),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Color.lerp(
                palette.highlight.withOpacity(0.13),
                palette.highlight.withOpacity(0.28),
                pulse,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: palette.highlight.withOpacity(0.62),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.highlight.withOpacity(0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildSelectMotorcycleHeading() {
    final palette = context.appPalette;
    final accent = palette.accent;
    final title = RichText(
      maxLines: 1,
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.55,
        ),
        children: [
          TextSpan(
            text: 'SELECT YOUR ',
            style: TextStyle(color: palette.textPrimary),
          ),
          TextSpan(
            text: 'MOTORCYCLE',
            style: TextStyle(color: accent),
          ),
        ],
      ),
    );

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.transparent, accent]),
            ),
          ),
        ),
        const SizedBox(width: 12),
        title,
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [accent, Colors.transparent]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopCategoryNavigation(
    List<_HomeTopNavItem> items, {
    double? collapseOverride,
    void Function(_HomeTopNavItem item)? onItemTap,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    final palette = context.appPalette;
    final collapse = Curves.easeOutCubic.transform(
      collapseOverride ?? _homeChromeCollapseProgress,
    );
    final navHeight = lerpDouble(84, 38, collapse)!;
    final itemWidth = lerpDouble(78, 84, collapse)!;
    final imageSlotHeight = lerpDouble(50, 0, collapse)!;
    final imageSize = (imageSlotHeight - 8).clamp(0.0, 42.0).toDouble();
    final imageFrameInset = imageSlotHeight >= 8 ? 2.0 : 0.0;
    final imageOpacity = (1 - collapse).clamp(0.0, 1.0).toDouble();
    final textHeight = 24.0;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
        height: navHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ListView.separated(
              clipBehavior: Clip.none,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = item.key == _selectedTopCategoryKey;
                final isPressed = _pressedTopCategoryKey == item.key;
                final showGlow = isSelected || isPressed;

                return SizedBox(
                  width: itemWidth,
                  child: AnimatedScale(
                    scale: isPressed ? 0.90 : 1,
                    duration: const Duration(milliseconds: 130),
                    curve: Curves.easeOutBack,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onHighlightChanged: (pressed) {
                          if (!mounted) return;
                          setState(() {
                            _pressedTopCategoryKey = pressed ? item.key : null;
                          });
                        },
                        onTap: () {
                          if (_selectedTopCategoryKey != item.key) {
                            setState(() => _selectedTopCategoryKey = item.key);
                          }
                          if (onItemTap != null) {
                            onItemTap(item);
                          } else {
                            _handleTopCategoryTap(item);
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: imageSlotHeight,
                                child: Opacity(
                                  opacity: imageOpacity,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOutCubic,
                                    width: imageSlotHeight,
                                    height: imageSlotHeight,
                                    padding: EdgeInsets.all(imageFrameInset),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: showGlow
                                          ? LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                palette.accentStrong,
                                                palette.accent,
                                              ],
                                            )
                                          : null,
                                      border: showGlow
                                          ? null
                                          : Border.all(
                                              color: palette.isLight
                                                  ? palette.border
                                                  : Colors.white.withOpacity(
                                                      0.34,
                                                    ),
                                              width: 0.8,
                                            ),
                                      boxShadow: showGlow
                                          ? [
                                              BoxShadow(
                                                color: palette.accentStrong
                                                    .withOpacity(
                                                      palette.isLight
                                                          ? 0.34
                                                          : 0.58,
                                                    ),
                                                blurRadius: 16,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : const [],
                                    ),
                                    child: ClipOval(
                                      child: item.imageAsset == null
                                          ? Icon(
                                              item.icon,
                                              size: imageSize,
                                              color: palette.textPrimary,
                                            )
                                          : Image.asset(
                                              item.imageAsset!,
                                              width: imageSize,
                                              height: imageSize,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Icon(
                                                    item.icon,
                                                    size: imageSize,
                                                    color: palette.textPrimary,
                                                  ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: textHeight,
                                child: Center(
                                  child: Text(
                                    item.title == 'Riding Gears'
                                        ? 'Riding Gear'
                                        : item.title,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isSelected
                                          ? palette.textPrimary
                                          : palette.textPrimary.withOpacity(
                                              0.78,
                                            ),
                                      fontSize: 9.6,
                                      height: 1.02,
                                      fontWeight: isSelected
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: IgnorePointer(
                child: Container(
                  width: 12,
                  height: navHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        palette.background,
                        palette.background.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IgnorePointer(
                child: Container(
                  width: 12,
                  height: navHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        palette.background,
                        palette.background.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeCategoryGroups(
    Map<String, List> groupedCategories,
    String imageVersion,
  ) {
    final groups = groupedCategories.entries
        .where((entry) => entry.value.whereType<Map>().isNotEmpty)
        .toList();
    if (groups.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 3;
        const gap = 8.0;
        final cardWidth =
            (constraints.maxWidth - 32 - gap * (columns - 1)) / columns;
        final cardHeight = (cardWidth * 1.08).clamp(116.0, 230.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: gap,
            runSpacing: 10,
            children: [
              for (final group in groups)
                Builder(
                  builder: (context) {
                    final children = group.value
                        .whereType<Map>()
                        .map((item) => Map<String, dynamic>.from(item))
                        .toList();
                    return SizedBox(
                      width: cardWidth,
                      child: _buildHomeBikeGridCard(
                        title: group.key,
                        imageUrl: _homeCategoryFolderImageUrl(
                          group.key,
                          imageVersion,
                          lightTheme: context.appPalette.isLight,
                        ),
                        height: cardHeight.toDouble(),
                        showGreenStripe: false,
                        showNeonBorder: false,
                        onTap: () => _openHomeCategoryGroup(
                          title: group.key,
                          categories: children,
                          imageVersion: imageVersion,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _openHomeCategoryGroup({
    required String title,
    required List<Map<String, dynamic>> categories,
    required String imageVersion,
  }) {
    final categoryImagesFuture = _precacheHomeCategoryGroupImages(categories);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (pageContext) => FutureBuilder<void>(
          future: categoryImagesFuture,
          builder: (loadingContext, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return YanaProductsLoadingScreen(
                dataReady: true,
                imagesReady: false,
                accent: loadingContext.appPalette.accent,
                dataLabel: 'CATEGORIES',
                imageLabel: 'PHOTOS',
                loadingTitle: 'LOADING CATEGORY PHOTOS...',
              );
            }

            final palette = pageContext.appPalette;
            return Scaffold(
              backgroundColor: palette.background,
              body: SafeArea(
                child: Column(
                  children: [
                    _buildInnerCategoryPageHeader(pageContext),
                    Expanded(
                      child: ColoredBox(
                        color: palette.background,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 11, 16, 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "${categories.length} categories",
                                    style: TextStyle(
                                      color: palette.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (gridContext, constraints) {
                                  const columns = 3;
                                  const gap = 8.0;
                                  final cardWidth =
                                      (constraints.maxWidth -
                                          32 -
                                          gap * (columns - 1)) /
                                      columns;
                                  final cardHeight = (cardWidth * 1.22).clamp(
                                    128.0,
                                    250.0,
                                  );

                                  return GridView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      4,
                                      16,
                                      24,
                                    ),
                                    itemCount: categories.length,
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: columns,
                                          crossAxisSpacing: gap,
                                          mainAxisSpacing: 10,
                                          childAspectRatio:
                                              cardWidth / cardHeight,
                                        ),
                                    itemBuilder: (context, index) {
                                      final category = categories[index];
                                      final categoryName =
                                          (category["name"] ?? "").toString();

                                      return _buildHomeInnerCategoryCard(
                                        title: categoryName,
                                        imageUrl: _homeCategoryImageUrl(
                                          category,
                                        ),
                                        fallbackImageUrl: categoryFallbackAsset,
                                        onTap: () {
                                          Navigator.of(gridContext).push(
                                            MaterialPageRoute(
                                              builder: (_) => ProductsScreen(
                                                categoryId: category["id"],
                                                title: categoryName,
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
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
        ),
      ),
    );
  }

  Future<void> _precacheHomeCategoryGroupImages(
    List<Map<String, dynamic>> categories,
  ) async {
    final imageUrls = <String>{};
    for (final category in categories.take(9)) {
      final fallbackImage = _homeCategoryImageUrl(category);
      if (fallbackImage.toLowerCase().startsWith('http')) {
        imageUrls.add(fallbackImage);
      }
    }
    if (imageUrls.isEmpty || !mounted) return;

    await Future.wait<void>(
      imageUrls.map((url) async {
        try {
          await precacheImage(
            CachedNetworkImageProvider(
              url,
              maxWidth: _homeCategoryImageCacheWidth,
            ),
            context,
            onError: (_, __) {},
          );
        } catch (_) {}
      }),
    ).timeout(const Duration(seconds: 8), onTimeout: () => <void>[]);
  }

  Widget _buildInnerCategoryPageHeader(BuildContext pageContext) {
    final palette = pageContext.appPalette;
    final searchDecoration = InputDecoration(
      hintText: "Search parts, bikes, brands, SKU...",
      hintStyle: TextStyle(color: palette.textMuted, fontSize: 12.5),
      prefixIcon: Icon(
        Icons.search_rounded,
        color: palette.isLight ? palette.accentStrong : palette.accent,
        size: 23,
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 40),
      suffixIcon: SizedBox(
        width: 82,
        height: 40,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              width: 32,
              height: 40,
              child: IconButton(
                tooltip: "Barcode scanner",
                padding: EdgeInsets.zero,
                onPressed: _openBarcodeSearchOption,
                icon: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: palette.isLight
                      ? palette.accentStrong
                      : palette.accent,
                  size: 22,
                ),
              ),
            ),
            SizedBox(
              width: 46,
              height: 40,
              child: InkWell(
                onTap: _goToSearch,
                borderRadius: BorderRadius.circular(12),
                child: Center(child: _buildAnimatedSearchArrow()),
              ),
            ),
          ],
        ),
      ),
      suffixIconConstraints: const BoxConstraints(
        minWidth: 82,
        minHeight: 40,
        maxWidth: 82,
        maxHeight: 40,
      ),
      border: InputBorder.none,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
    );

    return ColoredBox(
      color: palette.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 58,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    height: 40,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(pageContext).pop(),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: palette.textPrimary,
                        size: 21,
                      ),
                    ),
                  ),
                  Image.asset(
                    "assets/icon/icon.png",
                    width: 112,
                    height: 38,
                    fit: BoxFit.contain,
                    color: palette.isLight ? const Color(0xFF11130E) : null,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => Navigator.of(pageContext).push(
                      MaterialPageRoute(builder: (_) => const WalletScreen()),
                    ),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 31,
                      height: 31,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.accent, width: 1.3),
                      ),
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        color: palette.isLight
                            ? palette.textPrimary
                            : const Color(0xFFFFD23F),
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  SizedBox(
                    width: 100,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            InkWell(
                              onTap: () {
                                Navigator.of(pageContext)
                                    .push(
                                      MaterialPageRoute(
                                        builder: (_) => LoginScreen(),
                                      ),
                                    )
                                    .then((_) => _refreshAuthToken());
                              },
                              child: Text(
                                "Login",
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              " / ",
                              style: TextStyle(
                                color: palette.textMuted,
                                fontSize: 10,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                Navigator.of(pageContext)
                                    .push(
                                      MaterialPageRoute(
                                        builder: (_) => SignupScreen(),
                                      ),
                                    )
                                    .then((_) => _refreshAuthToken());
                              },
                              child: Text(
                                "Signup",
                                style: TextStyle(
                                  color: palette.isLight
                                      ? palette.accentStrong
                                      : palette.accent,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Get Exclusive Offers",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 8.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Consumer<CartProvider>(
                    builder: (context, cart, child) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          constraints: const BoxConstraints.tightFor(
                            width: 34,
                            height: 38,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.of(pageContext).push(
                            MaterialPageRoute(
                              builder: (_) => const CartScreen(),
                            ),
                          ),
                          icon: Icon(
                            Icons.shopping_cart_rounded,
                            color: palette.textPrimary,
                            size: 21,
                          ),
                        ),
                        if (cart.itemCount > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 16,
                              height: 16,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF3038),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                cart.itemCount > 9 ? "9+" : "${cart.itemCount}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Container(
              height: 40,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.border),
                color: palette.surface,
              ),
              child: TextField(
                onChanged: (value) {
                  searchController.value = TextEditingValue(
                    text: value,
                    selection: TextSelection.collapsed(offset: value.length),
                  );
                  _handleSearchChanged(value);
                },
                onSubmitted: (value) {
                  searchController.text = value;
                  _goToSearch();
                },
                cursorColor: palette.accentStrong,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textInputAction: TextInputAction.search,
                decoration: searchDecoration,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
            child: _buildCommerceHeroStrip(palette),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 5),
            child: _buildTopCategoryNavigation(
              _defaultTopCategoryNavigation(),
              collapseOverride: 0,
              onItemTap: (item) =>
                  _handleInnerCategoryTopNavTap(pageContext, item),
            ),
          ),
        ],
      ),
    );
  }

  void _handleInnerCategoryTopNavTap(
    BuildContext pageContext,
    _HomeTopNavItem item,
  ) {
    if (item.key == "shop_by_bike") {
      Navigator.of(pageContext).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectMotorcycleSection();
      });
      return;
    }
    if (item.key == "events") {
      Navigator.of(pageContext).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToTopBrandsSection();
      });
      return;
    }
    _handleTopCategoryTap(item);
  }

  Widget _buildHomeInnerCategoryCard({
    required String title,
    required String imageUrl,
    required String fallbackImageUrl,
    required VoidCallback onTap,
  }) {
    final palette = context.appPalette;
    final hasImage = imageUrl.toLowerCase().startsWith("http");
    final hasFallbackImage = fallbackImageUrl.toLowerCase().startsWith("http");
    final hasFallbackAsset = fallbackImageUrl.isNotEmpty && !hasFallbackImage;
    final radius = BorderRadius.circular(18);

    return Material(
      color: palette.surface,
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.4),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: palette.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Colors.white),
                  if (hasImage)
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      memCacheWidth: _homeCategoryImageCacheWidth,
                      maxWidthDiskCache: _homeCategoryImageCacheWidth,
                      filterQuality: FilterQuality.low,
                      placeholder: (_, __) => hasFallbackAsset
                          ? const CategoryFallbackImage()
                          : const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                      errorWidget: (_, __, ___) => hasFallbackImage
                          ? AppCachedImage(
                              url: fallbackImageUrl,
                              fit: BoxFit.contain,
                              memCacheWidth: _homeCategoryImageCacheWidth,
                              maxWidthDiskCache: _homeCategoryImageCacheWidth,
                              filterQuality: FilterQuality.low,
                            )
                          : hasFallbackAsset
                          ? const CategoryFallbackImage()
                          : const Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.black38,
                              ),
                            ),
                    )
                  else if (hasFallbackImage)
                    AppCachedImage(
                      url: fallbackImageUrl,
                      fit: BoxFit.contain,
                      memCacheWidth: _homeCategoryImageCacheWidth,
                      maxWidthDiskCache: _homeCategoryImageCacheWidth,
                      filterQuality: FilterQuality.low,
                    )
                  else if (hasFallbackAsset)
                    const CategoryFallbackImage(),
                  Positioned(
                    right: 7,
                    bottom: 7,
                    child: Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        color: palette.highlight,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.16),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.black,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 6, 9, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 11,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 31,
                    height: 3,
                    decoration: BoxDecoration(
                      color: palette.highlight,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _homeCategoryImageUrl(Map<String, dynamic> category) {
    final image = category["image"];
    if (image is Map) return (image["src"] ?? "").toString().trim();
    return "";
  }

  String _homeCategoryFolderImageUrl(
    String title,
    String imageVersion, {
    required bool lightTheme,
  }) {
    final imageName = title
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9]+"), "_")
        .replaceAll(RegExp(r"^_+|_+$"), "");
    if (imageName.isEmpty) return "";
    final version = imageVersion.trim();
    final versionQuery = version.isEmpty
        ? ""
        : "?v=${Uri.encodeQueryComponent(version)}";
    final imageFolder = lightTheme ? 'catiimglight' : 'catimg';
    return "https://yanaworldwide.store/Yanaapp/$imageFolder/$imageName.png$versionQuery";
  }

  Widget _buildHomeBikeGridCard({
    required String title,
    required String imageUrl,
    required double height,
    required bool showGreenStripe,
    required bool showNeonBorder,
    required VoidCallback onTap,
  }) {
    final palette = context.appPalette;
    final isLightTheme = palette.isLight;
    return SizedBox(
      height: height,
      child: Semantics(
        label: title,
        button: true,
        child: Material(
          color: isLightTheme ? palette.surface : const Color(0xFF080A08),
          elevation: showNeonBorder ? 2 : 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isLightTheme
                ? BorderSide(color: palette.border, width: 1)
                : showNeonBorder
                ? BorderSide(
                    color: context.appPalette.highlight.withOpacity(0.62),
                    width: 1,
                  )
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: isLightTheme
                      ? palette.surface
                      : const Color(0xFF050605),
                ),
                _RetryingHomeCategoryImage(
                  debugLabel: title,
                  imageUrl: imageUrl,
                  fit: isLightTheme ? BoxFit.cover : BoxFit.contain,
                  memCacheWidth: _homeCategoryImageCacheWidth,
                ),
                if (showGreenStripe)
                  Positioned(
                    left: -13,
                    top: 15,
                    child: Transform.rotate(
                      angle: -math.pi / 4,
                      child: Container(
                        width: 56,
                        height: 9,
                        decoration: BoxDecoration(
                          color: context.appPalette.highlight.withOpacity(0.72),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentlyViewedSection() {
    final palette = context.appPalette;
    final items = _recentlyViewedProducts.take(10).toList();
    if (items.length < 4) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: palette.highlight.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: palette.highlight.withOpacity(0.28),
                  ),
                ),
                child: Icon(
                  Icons.history_rounded,
                  color: palette.highlight,
                  size: 17,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                "Recently Viewed",
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  "Latest 10",
                  style: TextStyle(
                    color: palette.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 178,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final product = items[index];
              return SizedBox(
                width: 126,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailScreen(product: product),
                        ),
                      ).then((_) => _loadRecentlyViewedProducts());
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Ink(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE7E7E7)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(14),
                                ),
                                child: SizedBox(
                                  height: 94,
                                  width: double.infinity,
                                  child: AppCachedImage(
                                    url: product.image,
                                    fit: BoxFit.contain,
                                    memCacheWidth: _homeProductImageCacheWidth,
                                    maxWidthDiskCache:
                                        _homeProductImageCacheWidth,
                                    filterQuality: FilterQuality.low,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 7,
                                left: 7,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.highlight,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    "VIEWED",
                                    style: TextStyle(
                                      color: palette.onAccent,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(9, 8, 9, 0),
                            child: Text(
                              product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: const Color(0xFF151515),
                                fontSize: 11.5,
                                height: 1.12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(9, 5, 7, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "₹${product.price}",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFD32F2F),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Builder(
                                  builder: (buttonContext) => Material(
                                    color: const Color(0xFFF0F0F0),
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () {
                                        final cartProvider =
                                            Provider.of<CartProvider>(
                                              context,
                                              listen: false,
                                            );
                                        final alreadyInCart = cartProvider.items
                                            .any(
                                              (item) =>
                                                  item.id == product.id &&
                                                  item.variationId == null,
                                            );
                                        if (alreadyInCart) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const CartScreen(),
                                            ),
                                          );
                                          return;
                                        }
                                        cartProvider.addToCart(
                                          CartItem(
                                            id: product.id,
                                            variationId: null,
                                            name: product.name,
                                            image: product.image,
                                            price:
                                                double.tryParse(
                                                  product.price,
                                                ) ??
                                                0,
                                            quantity: 1,
                                          ),
                                        );
                                        _runAddToBagAnimation(
                                          startContext: buttonContext,
                                          imageUrl: product.image,
                                        );
                                      },
                                      child: const SizedBox(
                                        width: 27,
                                        height: 27,
                                        child: Icon(
                                          Icons.add_shopping_cart_rounded,
                                          color: Color(0xFF252525),
                                          size: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNewArrivalsSection() {
    return _buildProductRailSection(
      future: _newArrivalsFuture,
      title: "New Arrivals",
      pillText: "Latest 10",
      icon: Icons.new_releases_rounded,
      badgeText: "NEW",
      accentColorBuilder: (palette) =>
          palette.isLight ? palette.accentStrong : palette.highlight,
    );
  }

  Widget _buildBigDaysSaleSection() {
    final palette = context.appPalette;
    return FutureBuilder<List<Product>>(
      future: _bigDaysSaleProductsFuture,
      builder: (context, snapshot) {
        if (_bigDaysSaleProductsFuture == null ||
            snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final products = snapshot.data ?? const <Product>[];
        if (!_bigDaysSaleEnabled || products.isEmpty) {
          return const SizedBox.shrink();
        }
        final accent = palette.isLight
            ? palette.accentStrong
            : palette.highlight;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.local_offer_rounded,
                      color: accent,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _bigDaysSaleLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SaleProductsScreen(
                          collectionKey: 'big_days_sale',
                          title: _bigDaysSaleLabel,
                        ),
                      ),
                    ),
                    child: Text(
                      'View all Products',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 178,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: products.length > 10 ? 10 : products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) => _buildHomeProductRailCard(
                  products[index],
                  palette,
                  _bigDaysSaleLabel,
                  accent,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildBestSellersSection() {
    return _buildProductRailSection(
      future: _bestSellersFuture,
      title: "Best Sellers",
      pillText: "Top 10",
      icon: Icons.local_fire_department_rounded,
      badgeText: "BEST",
      accentColorBuilder: (palette) =>
          palette.isLight ? palette.accentStrong : palette.accent,
    );
  }

  Widget _buildProductRailSection({
    required Future<List<Product>>? future,
    required String title,
    required String pillText,
    required IconData icon,
    required String badgeText,
    required Color Function(AppThemePalette palette) accentColorBuilder,
  }) {
    final palette = context.appPalette;
    final accentColor = accentColorBuilder(palette);
    if (future == null) {
      return _buildProductRailLoadingSection(
        title: title,
        pillText: pillText,
        icon: icon,
        accentColor: accentColor,
        palette: palette,
      );
    }
    return FutureBuilder<List<Product>>(
      future: future,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final items = snapshot.data ?? const <Product>[];
        if (!isLoading && items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accentColor.withOpacity(0.28)),
                    ),
                    child: Icon(icon, color: accentColor, size: 17),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    title,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: palette.border),
                    ),
                    child: Text(
                      pillText,
                      style: TextStyle(
                        color: palette.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 178,
              child: isLoading
                  ? ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 5,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, __) => const SkeletonBox(
                        width: 124,
                        height: 168,
                        radius: 14,
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      cacheExtent: 360,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final product = items[index];
                        return _buildHomeProductRailCard(
                          product,
                          palette,
                          badgeText,
                          accentColor,
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildProductRailLoadingSection({
    required String title,
    required String pillText,
    required IconData icon,
    required Color accentColor,
    required AppThemePalette palette,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accentColor.withOpacity(0.28)),
                ),
                child: Icon(icon, color: accentColor, size: 17),
              ),
              const SizedBox(width: 9),
              Text(
                title,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  pillText,
                  style: TextStyle(
                    color: palette.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 178,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, __) =>
                const SkeletonBox(width: 124, height: 168, radius: 14),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildHomeProductRailCard(
    Product product,
    AppThemePalette palette,
    String badgeText,
    Color badgeColor,
  ) {
    return SizedBox(
      width: 126,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: product),
              ),
            ).then((_) => _loadRecentlyViewedProducts());
          },
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE7E7E7)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                      child: SizedBox(
                        height: 86,
                        width: double.infinity,
                        child: AppCachedImage(
                          url: product.image,
                          fit: BoxFit.contain,
                          memCacheWidth: _homeProductImageCacheWidth,
                          maxWidthDiskCache: _homeProductImageCacheWidth,
                          filterQuality: FilterQuality.low,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(7, 4, 7, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.onAccent,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(9, 7, 9, 0),
                  child: Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF151515),
                      fontSize: 11.5,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(9, 4, 9, 9),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "₹${product.price}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFFD32F2F),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: const Color(0xFF777777),
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBrandsAutoCarousel(
    List<dynamic> categories, {
    VoidCallback? onViewAll,
  }) {
    if (categories.isEmpty) return const SizedBox.shrink();

    final palette = context.appPalette;
    final isWhiteTheme = palette.isLight;
    const tileColor = Colors.white;
    final tileBorder = isWhiteTheme ? palette.border : const Color(0xFF3A3A3F);
    final viewAllColor = isWhiteTheme
        ? palette.surface
        : const Color(0xFF2A2A2E);
    final viewAllBorder = isWhiteTheme
        ? palette.border
        : const Color(0xFF3A3A3F);
    final viewAllContent = isWhiteTheme ? palette.textPrimary : Colors.white;

    const double tileHeight = 54;
    const double viewAllWidth = 70;

    Widget viewAllTile() {
      return Padding(
        padding: const EdgeInsets.only(left: 6),
        child: GestureDetector(
          onTap: onViewAll,
          child: SizedBox(
            width: viewAllWidth,
            child: Container(
              height: tileHeight,
              decoration: BoxDecoration(
                color: viewAllColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: viewAllBorder),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.grid_view_rounded,
                    size: 18,
                    color: viewAllContent,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: viewAllContent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 92,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CarouselSlider.builder(
                itemCount: categories.length,
                options: CarouselOptions(
                  height: 90,
                  viewportFraction: 0.25,
                  autoPlay: categories.length > 4,
                  autoPlayInterval: const Duration(seconds: 2),
                  autoPlayAnimationDuration: const Duration(milliseconds: 650),
                  autoPlayCurve: Curves.easeOutCubic,
                  enlargeCenterPage: false,
                  padEnds: false,
                  enableInfiniteScroll: categories.length > 4,
                ),
                itemBuilder: (context, index, realIndex) {
                  final cat = categories[index] is Map
                      ? Map<String, dynamic>.from(categories[index] as Map)
                      : <String, dynamic>{};
                  final image = cat['image'];
                  final imageUrl = image is Map
                      ? (image['src'] ?? '').toString()
                      : '';

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductsScreen(
                              categoryId: cat['id'],
                              title: cat['name'],
                            ),
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          Container(
                            height: tileHeight,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: tileColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: tileBorder),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: imageUrl.isNotEmpty
                                ? AppCachedImage(
                                    url: imageUrl,
                                    fit: BoxFit.contain,
                                    memCacheWidth: _homeCategoryImageCacheWidth,
                                    maxWidthDiskCache:
                                        _homeCategoryImageCacheWidth,
                                    filterQuality: FilterQuality.low,
                                  )
                                : Image.asset(
                                    'assets/icon/Blank.jpg',
                                    fit: BoxFit.contain,
                                  ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 28,
                            child: Text(
                              (cat['name'] ?? '').toString(),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                height: 1.15,
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            viewAllTile(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryScrollerSkeleton() {
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (_, __) => const Column(
          children: [
            SkeletonBox(width: 80, height: 80, radius: 40),
            SizedBox(height: 6),
            SkeletonBox(width: 70, height: 10, radius: 8),
          ],
        ),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: 6,
      ),
    );
  }

  Widget _buildAnimatedHeading(String text, {double fontSize = 18}) {
    final palette = context.appPalette;
    return AnimatedBuilder(
      animation: _titleAnimController,
      builder: (context, _) {
        final p = _titleAnimController.value.clamp(0.0, 1.0);
        final t = p * math.pi * 12;
        final fade = (1.0 - p).clamp(0.0, 1.0);
        final glitchX = math.sin(t) * 1.8 * fade;
        final speedOpacity = (0.35 * fade).clamp(0.0, 0.35);
        final powerScale = 1.0 + (math.sin(t * 0.6) * 0.03 * fade);

        return Transform.scale(
          scale: powerScale,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Center(
                  child: Opacity(
                    opacity: 0.25 * speedOpacity,
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            palette.accent,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(glitchX, 0),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: palette.textPrimary,
                    shadows: [
                      Shadow(
                        offset: const Offset(1.8, 0),
                        color: Color.fromRGBO(
                          31,
                          107,
                          255,
                          (0.8 * fade).clamp(0.0, 1.0),
                        ),
                        blurRadius: 0.5,
                      ),
                      Shadow(
                        offset: const Offset(-1.2, 0),
                        color: Color.fromRGBO(
                          255,
                          138,
                          61,
                          (0.8 * fade).clamp(0.0, 1.0),
                        ),
                        blurRadius: 0.5,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _saleStatusTimer?.cancel();
    _saleTransitionTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.recentlyViewedRefresh?.removeListener(_handleRecentlyViewedRefresh);
    _titleAnimController.dispose();
    _cartPulseController.dispose();
    _searchCtaController.dispose();
    _saleLivePulseController.dispose();
    _shopByBikeIntroController.dispose();
    _scrollController.removeListener(_handleHomeScroll);
    _scrollController.dispose();
    _homeChromeCollapseProgressNotifier.dispose();
    _searchFocusNode.removeListener(_handleSearchFocusChanged);
    _searchFocusNode.dispose();
    searchController.dispose();
    _debounce?.cancel();
    _internetRetryTimer?.cancel();
    super.dispose();
  }

  Future<void> _runAddToBagAnimation({
    required BuildContext startContext,
    required String imageUrl,
  }) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final startBox = startContext.findRenderObject() as RenderBox?;
    final endBox =
        _cartIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlay == null || startBox == null || endBox == null) {
      _cartPulseController.forward(from: 0);
      return;
    }

    final start = startBox.localToGlobal(startBox.size.center(Offset.zero));
    final end = endBox.localToGlobal(endBox.size.center(Offset.zero));
    final palette = context.appPalette;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1080),
    );
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOutCubicEmphasized,
    );

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) {
        final t = animation.value;
        final squeezeProgress = ((t - 0.76) / 0.24).clamp(0.0, 1.0);
        final size = lerpDouble(62, 16, t) ?? 24;
        final dx =
            (lerpDouble(start.dx, end.dx, t) ?? end.dx) +
            (math.sin(t * math.pi * 1.15) * 14 * (1 - t));
        final dy =
            (lerpDouble(start.dy, end.dy, t) ?? end.dy) -
            (math.sin(t * math.pi) * 138) -
            (squeezeProgress * 6);
        final opacity = t < 0.9
            ? 1.0
            : (1.0 - ((t - 0.9) / 0.1)).clamp(0.0, 1.0);
        final glowSize = size + 20;
        final iconSize = lerpDouble(18, 8, t) ?? 12;
        final scaleBoost = 1 + (math.sin(t * math.pi) * 0.16);
        final squeezeScale = lerpDouble(1.0, 0.38, squeezeProgress) ?? 1.0;
        final endFlash = ((t - 0.82) / 0.18).clamp(0.0, 1.0);
        final trailOpacity = (1 - t).clamp(0.0, 1.0);

        return Positioned(
          left: dx - (size / 2),
          top: dy - (size / 2),
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Transform.rotate(
                angle: (1 - t) * 0.75,
                child: Transform.scale(
                  scale: scaleBoost * squeezeScale,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: -(size * 0.38),
                        top: size * 0.18,
                        child: Opacity(
                          opacity: trailOpacity * 0.32,
                          child: Container(
                            width: size * 0.34,
                            height: size * 0.34,
                            decoration: BoxDecoration(
                              color: palette.accent.withOpacity(0.85),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -(size * 0.2),
                        top: -(size * 0.12),
                        child: Opacity(
                          opacity: trailOpacity * 0.2,
                          child: Container(
                            width: size * 0.22,
                            height: size * 0.22,
                            decoration: BoxDecoration(
                              color: palette.highlight.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -(glowSize - size) / 2,
                        top: -(glowSize - size) / 2,
                        child: Container(
                          width: glowSize,
                          height: glowSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: palette.accent.withOpacity(0.34),
                                blurRadius: 28,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: -(glowSize - size) / 2,
                        top: -(glowSize - size) / 2,
                        child: Opacity(
                          opacity: endFlash * 0.9,
                          child: Container(
                            width: glowSize + (18 * endFlash),
                            height: glowSize + (18 * endFlash),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: palette.highlight.withOpacity(0.75),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          color: palette.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: palette.accent, width: 2.2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 16,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(4),
                        child: imageUrl.isNotEmpty
                            ? ClipOval(
                                child: AppCachedImage(
                                  url: imageUrl,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(
                                Icons.shopping_bag_rounded,
                                color: palette.accent,
                                size: size * 0.48,
                              ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: iconSize * 1.9,
                          height: iconSize * 1.9,
                          decoration: BoxDecoration(
                            color: palette.accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: palette.surface,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.shopping_bag_rounded,
                            color: palette.onAccent,
                            size: iconSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    controller.addListener(entry.markNeedsBuild);
    await controller.forward();
    entry.remove();
    controller.dispose();
    if (mounted) {
      _cartPulseController.forward(from: 0);
    }
  }

  Future<void> _loadBannerImages() async {
    final prefs = await SharedPreferences.getInstance();
    String cacheRevision = "";
    try {
      final appInfo = await PackageInfo.fromPlatform();
      cacheRevision = "${appInfo.version}+${appInfo.buildNumber}";
    } catch (_) {}
    final cachedRaw = prefs.getString(_imageCacheKey) ?? "";

    if (cachedRaw.isNotEmpty && mounted) {
      final cachedItems = _parseImageLinks(
        cachedRaw,
        cacheRevision: cacheRevision,
      );
      if (cachedItems.isNotEmpty) {
        setState(() {
          _replaceImageBanners(cachedItems);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _warmBannerImages();
        });
      }
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
    }

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final response = await http
          .get(
            Uri.parse(
              "https://yanaworldwide.store/Yanaapp/homepageslider.txt?v=$now",
            ),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;

      final imageItems = _parseImageLinks(
        response.body,
        cacheRevision: cacheRevision,
      );
      if (imageItems.isEmpty) return;

      await prefs.setString(_imageCacheKey, response.body);
      if (cacheRevision.isNotEmpty) {
        await prefs.setString(_imageCacheVersionKey, cacheRevision);
      }
      if (!mounted) return;

      setState(() {
        _replaceImageBanners(imageItems);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _warmBannerImages();
      });
    } catch (_) {}
  }

  Widget _buildScrollCollapsingChild({
    required Widget child,
    required double expandedHeight,
    double translateY = -18,
  }) {
    final collapse = Curves.easeOutCubic.transform(_homeChromeCollapseProgress);
    final visible = (1 - collapse).clamp(0.0, 1.0);
    if (visible <= 0) return const SizedBox.shrink();

    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: visible,
        child: Opacity(
          opacity: visible,
          child: SizedBox(
            height: expandedHeight,
            child: Transform.translate(
              offset: Offset(0, translateY * collapse),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeBody() {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (!_showQuickAccessRail || !_quickAccessExpanded) return;
        final context = _quickAccessRailKey.currentContext;
        if (context == null) {
          setState(() => _quickAccessExpanded = false);
          return;
        }
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) {
          setState(() => _quickAccessExpanded = false);
          return;
        }
        final topLeft = box.localToGlobal(Offset.zero);
        final rect = topLeft & box.size;
        if (!rect.contains(event.position)) {
          setState(() => _quickAccessExpanded = false);
        }
      },
      child: Stack(
        children: [
          buildMainContent(),
          if (_showQuickAccessRail) _buildQuickAccessRail(),
          if (_internetStatusKnown && !_hasInternet)
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: _buildNoInternetBanner(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final topInset = MediaQuery.of(context).padding.top;
    const logoRowHeight = 64.0;
    const commerceStripHeight = 32.0;
    const commerceToCategoryGap = 6.0;
    const overflowGuard = 6.0;
    final searchSuggestions = _searchSuggestions();
    final showSearchSuggestions =
        searchSuggestions.isNotEmpty &&
        (_searchFocusNode.hasFocus || searchController.text.trim().isNotEmpty);
    final searchSuggestionHeight = showSearchSuggestions ? 43.0 : 0.0;
    final hasBigDaysBanner =
        _bigDaysSaleEnabled || _upcomingSaleMessage != null;
    final homeBody = _buildHomeBody();

    return ValueListenableBuilder<double>(
      valueListenable: _homeChromeCollapseProgressNotifier,
      child: homeBody,
      builder: (context, collapseProgress, body) {
        _homeChromeCollapseProgress = collapseProgress;
        final collapse = Curves.easeOutCubic.transform(collapseProgress);
        final headerTopPadding = lerpDouble(8, 4, collapse)!;
        final headerGap = lerpDouble(7, 0, collapse)!;
        final topCategoryNavHeight = lerpDouble(84, 38, collapse)!;
        const searchHeight = 40.0;
        final appBarHeight =
            headerTopPadding +
            (logoRowHeight * (1 - collapse)) +
            headerGap +
            searchHeight +
            searchSuggestionHeight +
            headerGap +
            (commerceStripHeight * (1 - collapse)) +
            (commerceToCategoryGap * (1 - collapse)) +
            topCategoryNavHeight +
            overflowGuard;
        return Scaffold(
          backgroundColor: palette.background,
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(appBarHeight),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    palette.heroStart,
                    palette.heroEnd,
                    palette.background,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: EdgeInsets.only(
                top: topInset + lerpDouble(8, 4, collapse)!,
                left: 6,
                right: 6,
              ),
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  maxHeight: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: _buildScrollCollapsingChild(
                          expandedHeight: logoRowHeight,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Image.asset(
                                "assets/icon/icon.png",
                                width: 132,
                                height: 38,
                                alignment: Alignment.centerLeft,
                                fit: BoxFit.contain,
                                color: palette.isLight
                                    ? const Color(0xFF11130E)
                                    : null,
                                colorBlendMode: BlendMode.srcIn,
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FutureBuilder<String?>(
                                          future: _authTokenFuture,
                                          builder: (context, snapshot) {
                                            // ⬇️ UPDATED: Added Signup Button next to Login ⬇️
                                            if (!snapshot.hasData ||
                                                snapshot.data == null) {
                                              return Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  InkWell(
                                                    customBorder:
                                                        const CircleBorder(),
                                                    onTap: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              const WalletScreen(),
                                                        ),
                                                      );
                                                    },
                                                    child: Container(
                                                      width: 34,
                                                      height: 34,
                                                      alignment:
                                                          Alignment.center,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: palette.accent
                                                              .withOpacity(
                                                                0.85,
                                                              ),
                                                          width: 1.4,
                                                        ),
                                                      ),
                                                      child: Icon(
                                                        Icons
                                                            .workspace_premium_rounded,
                                                        color: palette.isLight
                                                            ? Color(0xFF11130E)
                                                            : Color(0xFFFFD23F),
                                                        size: 20,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          InkWell(
                                                            onTap: () {
                                                              Navigator.push(
                                                                context,
                                                                MaterialPageRoute(
                                                                  builder: (_) =>
                                                                      LoginScreen(),
                                                                ),
                                                              ).then(
                                                                (_) =>
                                                                    _refreshAuthToken(),
                                                              );
                                                            },
                                                            child: Padding(
                                                              padding:
                                                                  EdgeInsets.symmetric(
                                                                    vertical: 2,
                                                                  ),
                                                              child: Text(
                                                                'Login',
                                                                style: TextStyle(
                                                                  color: palette
                                                                      .textPrimary,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          Text(
                                                            ' / ',
                                                            style: TextStyle(
                                                              color: palette
                                                                  .textMuted,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                          InkWell(
                                                            onTap: () {
                                                              Navigator.push(
                                                                context,
                                                                MaterialPageRoute(
                                                                  builder: (_) =>
                                                                      SignupScreen(),
                                                                ),
                                                              ).then(
                                                                (_) =>
                                                                    _refreshAuthToken(),
                                                              );
                                                            },
                                                            child: Padding(
                                                              padding:
                                                                  EdgeInsets.symmetric(
                                                                    vertical: 2,
                                                                  ),
                                                              child: Text(
                                                                'Signup',
                                                                style: TextStyle(
                                                                  color:
                                                                      palette
                                                                          .isLight
                                                                      ? palette
                                                                            .accentStrong
                                                                      : palette
                                                                            .accent,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 1),
                                                      Text(
                                                        'Get Exclusive Offers',
                                                        style: TextStyle(
                                                          color:
                                                              palette.textMuted,
                                                          fontSize: 9.5,
                                                          height: 1.1,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              );
                                            }
                                            // ⬆️ UPDATED: Added Signup Button next to Login ⬆️

                                            return Row(
                                              children: [
                                                InkWell(
                                                  customBorder:
                                                      const CircleBorder(),
                                                  onTap: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            const WalletScreen(),
                                                      ),
                                                    );
                                                  },
                                                  child: Container(
                                                    width: 34,
                                                    height: 34,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: palette.accent
                                                            .withOpacity(0.85),
                                                        width: 1.4,
                                                      ),
                                                    ),
                                                    child: Icon(
                                                      Icons
                                                          .workspace_premium_rounded,
                                                      color: palette.isLight
                                                          ? Color(0xFF11130E)
                                                          : Color(0xFFFFD23F),
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                                FutureBuilder<bool>(
                                                  future: AuthService()
                                                      .isPrivilegedAdmin(),
                                                  builder: (context, adminSnapshot) {
                                                    if (adminSnapshot.data !=
                                                        true) {
                                                      return const SizedBox.shrink();
                                                    }
                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            right: 4,
                                                          ),
                                                      child: TextButton.icon(
                                                        style: TextButton.styleFrom(
                                                          minimumSize:
                                                              Size.zero,
                                                          tapTargetSize:
                                                              MaterialTapTargetSize
                                                                  .shrinkWrap,
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 6,
                                                              ),
                                                          backgroundColor:
                                                              palette.accent
                                                                  .withOpacity(
                                                                    0.14,
                                                                  ),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  10,
                                                                ),
                                                            side: BorderSide(
                                                              color: palette
                                                                  .accent
                                                                  .withOpacity(
                                                                    0.35,
                                                                  ),
                                                            ),
                                                          ),
                                                        ),
                                                        onPressed: () {
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (_) =>
                                                                  const AdminDashboardScreen(),
                                                            ),
                                                          );
                                                        },
                                                        icon: Icon(
                                                          Icons
                                                              .admin_panel_settings_outlined,
                                                          color: palette.accent,
                                                          size: 16,
                                                        ),
                                                        label: Text(
                                                          "Admin",
                                                          style: TextStyle(
                                                            color:
                                                                palette.accent,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                                IconButton(
                                                  constraints:
                                                      const BoxConstraints.tightFor(
                                                        width: 32,
                                                        height: 36,
                                                      ),
                                                  padding: EdgeInsets.zero,
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  icon: Icon(
                                                    Icons.person,
                                                    color: palette.textPrimary,
                                                    size: 20,
                                                  ),
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            const ProfileScreen(),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 4),
                                        Consumer<CartProvider>(
                                          builder: (context, cart, child) {
                                            return Stack(
                                              children: [
                                                IconButton(
                                                  key: _cartIconKey,
                                                  icon: AnimatedBuilder(
                                                    animation:
                                                        _cartPulseController,
                                                    builder: (context, child) {
                                                      final progress = Curves
                                                          .elasticOut
                                                          .transform(
                                                            _cartPulseController
                                                                .value
                                                                .clamp(
                                                                  0.0,
                                                                  1.0,
                                                                ),
                                                          );
                                                      final scale =
                                                          1 + (0.24 * progress);
                                                      final rotation =
                                                          math.sin(
                                                            progress *
                                                                math.pi *
                                                                4,
                                                          ) *
                                                          0.12 *
                                                          (1 - progress);
                                                      return Transform.rotate(
                                                        angle: rotation,
                                                        child: Transform.scale(
                                                          scale: scale,
                                                          child: child,
                                                        ),
                                                      );
                                                    },
                                                    child: Icon(
                                                      Icons.shopping_cart,
                                                      color:
                                                          palette.textPrimary,
                                                      size: 21,
                                                    ),
                                                  ),
                                                  constraints:
                                                      const BoxConstraints.tightFor(
                                                        width: 36,
                                                        height: 36,
                                                      ),
                                                  padding: EdgeInsets.zero,
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            const CartScreen(),
                                                      ),
                                                    );
                                                  },
                                                ),
                                                if (cart.items.isNotEmpty)
                                                  Positioned(
                                                    right: 1,
                                                    top: 1,
                                                    child: Container(
                                                      width: 16,
                                                      height: 16,
                                                      alignment:
                                                          Alignment.center,
                                                      decoration:
                                                          const BoxDecoration(
                                                            color: Color(
                                                              0xFFFF3038,
                                                            ),
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                      child: Text(
                                                        cart.items.length > 9
                                                            ? '9+'
                                                            : cart.items.length
                                                                  .toString(),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: headerGap),
                      Container(
                        key: _searchBoxKey,
                        height: searchHeight,
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: palette.border, width: 1),
                          color: palette.isLight ? palette.surface : null,
                          gradient: palette.isLight
                              ? null
                              : const LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Color(0xFF151617),
                                    Color(0xFF0B0C0D),
                                    Color(0xFF171819),
                                  ],
                                ),
                        ),
                        child: TextField(
                          controller: searchController,
                          focusNode: _searchFocusNode,
                          onChanged: _handleSearchChanged,
                          cursorColor: palette.accentStrong,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _goToSearch(),
                          decoration: InputDecoration(
                            hintText: "Search parts, bikes, brands, SKU...",
                            hintStyle: TextStyle(
                              color: palette.textMuted,
                              fontSize: 12.5,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: palette.isLight
                                  ? palette.accentStrong
                                  : palette.accent,
                              size: 23,
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 46,
                              minHeight: 40,
                              maxHeight: 40,
                            ),
                            suffixIcon: ClipRect(
                              child: SizedBox(
                                width: 84,
                                height: 40,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 3),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 33,
                                        height: 40,
                                        child: Tooltip(
                                          message: "Barcode scanner",
                                          child: InkWell(
                                            onTap: _openBarcodeSearchOption,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: Center(
                                              child: Icon(
                                                Icons.qr_code_scanner_rounded,
                                                color: const Color(0xFFB6F21E),
                                                size: 23,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 48,
                                        height: 40,
                                        child: InkWell(
                                          onTap: _goToSearch,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Center(
                                            child: _buildAnimatedSearchArrow(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            suffixIconConstraints: const BoxConstraints(
                              minWidth: 84,
                              minHeight: 40,
                              maxWidth: 84,
                              maxHeight: 40,
                            ),
                            border: InputBorder.none,
                            isDense: true, // VERY IMPORTANT
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      if (hasBigDaysBanner) ...[
                        SizedBox(height: headerGap),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: _buildScrollCollapsingChild(
                            expandedHeight: commerceStripHeight,
                            translateY: -12,
                            child: _buildCommerceHeroStrip(palette),
                          ),
                        ),
                      ],
                      if (showSearchSuggestions)
                        _buildSearchSuggestionsPanel(
                          palette,
                          searchSuggestions,
                        ),
                      if (!hasBigDaysBanner) ...[
                        SizedBox(height: headerGap),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: _buildScrollCollapsingChild(
                            expandedHeight: commerceStripHeight,
                            translateY: -12,
                            child: _buildCommerceHeroStrip(palette),
                          ),
                        ),
                      ],
                      SizedBox(height: commerceToCategoryGap * (1 - collapse)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: _buildTopCategoryNavigation(
                          _defaultTopCategoryNavigation(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: body!,
          // ✅ WHATSAPP BUTTON (Correct Position)
          floatingActionButton: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: _homeChromeCollapseProgress > 0.08
                ? FloatingActionButton(
                    key: const ValueKey("back_to_top_fab"),
                    onPressed: _scrollToTop,
                    backgroundColor: palette.surfaceStrong,
                    foregroundColor: palette.accent,
                    shape: const CircleBorder(),
                    child: const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 30,
                    ),
                  )
                : FloatingActionButton(
                    key: const ValueKey("whatsapp_fab"),
                    onPressed: openWhatsApp,
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_rounded,
                            size: 24,
                            color: Colors.white,
                          ),
                          Positioned(
                            top: 7,
                            child: Icon(
                              Icons.call_rounded,
                              size: 12,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget buildMainContent() {
    final palette = context.appPalette;
    final currentBanner =
        _bannerItems.isNotEmpty &&
            _currentBannerIndex >= 0 &&
            _currentBannerIndex < _bannerItems.length
        ? _bannerItems[_currentBannerIndex]
        : null;
    final autoPlayBanners = currentBanner == null
        ? true
        : !currentBanner.isVideo;

    return CustomScrollView(
      controller: _scrollController,
      cacheExtent: 900,
      slivers: [
        /// 1. Top Section (Banner)
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bannerHeight = constraints.maxWidth / 2.2;
                    final carouselHeight = bannerHeight - 8;

                    return Container(
                      height: bannerHeight,
                      decoration: BoxDecoration(
                        color: const Color(0xFF090A0B),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFF343638),
                          width: 0.8,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x55000000),
                            blurRadius: 7,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            height: carouselHeight,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: CarouselSlider(
                                    carouselController: _bannerController,
                                    options: CarouselOptions(
                                      height: carouselHeight,
                                      autoPlay: autoPlayBanners,
                                      enlargeCenterPage: false,
                                      viewportFraction: 1.0,
                                      autoPlayInterval: const Duration(
                                        seconds: 4,
                                      ),
                                      autoPlayAnimationDuration: const Duration(
                                        milliseconds: 500,
                                      ),
                                      autoPlayCurve: Curves.easeOutCubic,
                                      onPageChanged: (index, reason) {
                                        if (!mounted) return;
                                        setState(() {
                                          _currentBannerIndex = index;
                                        });
                                      },
                                    ),
                                    items: _bannerItems.map((item) {
                                      return RepaintBoundary(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: HomeBannerMediaCard(
                                                  item: item,
                                                  onVideoStarted: item.isVideo
                                                      ? () {
                                                          if (!mounted) return;
                                                          if (_currentBannerIndex >=
                                                                  0 &&
                                                              _currentBannerIndex <
                                                                  _bannerItems
                                                                      .length &&
                                                              identical(
                                                                _bannerItems[_currentBannerIndex],
                                                                item,
                                                              )) {
                                                            setState(() {});
                                                          }
                                                        }
                                                      : null,
                                                  onVideoEnded: item.isVideo
                                                      ? () {
                                                          _bannerController
                                                              .nextPage();
                                                        }
                                                      : null,
                                                ),
                                              ),
                                              Positioned.fill(
                                                child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin:
                                                          Alignment.topCenter,
                                                      end: Alignment
                                                          .bottomCenter,
                                                      colors: [
                                                        Colors.transparent,
                                                        Colors.transparent,
                                                        Colors.black
                                                            .withOpacity(0.14),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                if (_bannerItems.length > 1)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 8,
                                    child: IgnorePointer(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          for (
                                            var index = 0;
                                            index < _bannerItems.length;
                                            index++
                                          )
                                            AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 250,
                                              ),
                                              curve: Curves.easeOutCubic,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 3,
                                                  ),
                                              width:
                                                  index == _currentBannerIndex
                                                  ? 18
                                                  : 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color:
                                                    index == _currentBannerIndex
                                                    ? const Color(0xFFB6F21E)
                                                    : Colors.white38,
                                                borderRadius:
                                                    BorderRadius.circular(6),
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
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),

        // Place Top Brands directly after the hero banner.
        SliverToBoxAdapter(
          child: FutureBuilder<_HomeCategorySectionData>(
            future: _categorySectionFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();

              final topBrandCategories = snapshot.data!.topBrandCategories
                  .whereType<Map>()
                  .map((raw) => Map<String, dynamic>.from(raw))
                  .toList();
              if (topBrandCategories.isEmpty) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KeyedSubtree(
                    key: _topBrandsSectionKey,
                    child: _buildTopBrandsAutoCarousel(
                      topBrandCategories,
                      onViewAll: () {
                        final remoteSource =
                            TopCategoryDetailScreen.remoteSourceFor('events');
                        if (remoteSource == null) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ShopByCategoryScreen(
                              title: 'Top Brands',
                              sourceUrl: remoteSource.sourceUrl,
                              cacheKeyPrefix: remoteSource.cacheKeyPrefix,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // ✅ Glassmorphism Offer Bar
        if (_showOfferMarquee && !isOfferLoading && offerText.isNotEmpty)
          SliverToBoxAdapter(
            child: Builder(
              builder: (context) {
                final offerLink = _extractOfferLink(offerText);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 15, 16, 1),
                  child: SizedBox(
                    height: 44,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: offerLink == null ? null : _openOfferLink,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: offerLink == null
                                  ? palette.border
                                  : palette.accent.withOpacity(0.6),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 12,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.local_offer_rounded,
                                color: palette.accent,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Marquee(
                                  text: offerText,
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    decoration: offerLink == null
                                        ? TextDecoration.none
                                        : TextDecoration.underline,
                                    decorationColor: palette.accent,
                                  ),
                                  scrollAxis: Axis.horizontal,
                                  blankSpace: 50.0,
                                  velocity: 30.0,
                                ),
                              ),
                              if (offerLink != null) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.open_in_new_rounded,
                                  color: palette.accent,
                                  size: 16,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // Keep sale cards in place while the offer marquee is hidden.
        SliverToBoxAdapter(child: _buildSaleButtons()),

        // --- Categories ---
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 1),
              FutureBuilder<_HomeCategorySectionData>(
                future: _categorySectionFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
                          child: SkeletonBox(width: 170, height: 16, radius: 8),
                        ),
                        _buildCategoryScrollerSkeleton(),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                          child: SkeletonBox(width: 210, height: 18, radius: 8),
                        ),
                        _buildCategoryScrollerSkeleton(),
                      ],
                    );
                  }
                  if (!snapshot.hasData ||
                      snapshot.data!.groupedCategories.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final categorySection = snapshot.data!;
                  final groupedData = categorySection.groupedCategories;
                  final topBrandCategories = <dynamic>[];

                  for (final raw in categorySection.topBrandCategories) {
                    if (raw is! Map) continue;
                    final cat = Map<String, dynamic>.from(raw);
                    topBrandCategories.add(cat);
                  }

                  final sectionWidgets = <Widget>[];

                  if (topBrandCategories.isNotEmpty) {
                    sectionWidgets.add(_buildBigDaysSaleSection());
                    sectionWidgets.add(_buildNewArrivalsSection());
                    sectionWidgets.add(_buildBestSellersSection());
                    sectionWidgets.add(_buildRecentlyViewedSection());
                  }

                  sectionWidgets.add(
                    Padding(
                      key: _selectMotorcycleSectionKey,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                      child: Center(
                        child: _buildSelectMotorcycleIntroHighlight(
                          child: _buildSelectMotorcycleHeading(),
                        ),
                      ),
                    ),
                  );

                  sectionWidgets.add(
                    _buildHomeCategoryGroups(
                      groupedData,
                      categorySection.imageVersion,
                    ),
                  );

                  return Column(children: sectionWidgets);
                },
              ),
            ],
          ),
        ),

        /* Keep only these two bottom category promo banners in source, hidden
           from the home feed for now.
        // --- Category Banners ---
        SliverToBoxAdapter(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          int? categoryId = await api.getCategoryIdBySlug(
                            "foglight",
                          );
                          if (categoryId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductsScreen(
                                  categoryId: categoryId,
                                  title: "Foglight",
                                ),
                              ),
                            );
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: const AppCachedImage(
                            url: "https://yanaworldwide.store/Yanaapp/a.jpg",
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          int? categoryId = await api.getCategoryIdBySlug(
                            "frando-brake-pads",
                          );
                          if (categoryId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductsScreen(
                                  categoryId: categoryId,
                                  title: "Frando Brake Pads",
                                ),
                              ),
                            );
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: const AppCachedImage(
                            url: "https://yanaworldwide.store/Yanaapp/b.jpg",
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        */

        // Keep these sections available without showing them on the home feed.
        if (_showHomeBikeGarage)
          SliverToBoxAdapter(child: _buildBikeGarageSection()),

        if (_showHomeLatestProducts || currentSearch.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentSearch.isEmpty
                              ? "Latest Products"
                              : "Search Results",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentSearch.isEmpty
                              ? "Fresh picks from your motorcycle shopping feed"
                              : 'Showing matches for "$currentSearch"',
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: palette.border),
                    ),
                    child: Text(
                      "${products.length} items",
                      style: TextStyle(
                        color: palette.highlight,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          /// 2. Product Grid
          if (!isInitialLoading && products.isEmpty && currentSearch.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  kBottomNavigationBarHeight + 20,
                ),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.border),
                  ),
                  child: Text(
                    'No products found for "$currentSearch".',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                kBottomNavigationBarHeight + 20,
              ),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.62,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (isInitialLoading && products.isEmpty) {
                      return const ProductCardSkeleton();
                    }
                    final product = products[index];

                    return _buildProductGridCard(product, palette);
                  },
                  childCount: (isInitialLoading && products.isEmpty)
                      ? 6
                      : products.length,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                ),
              ),
            ),
        ],
      ],
    );
  }

  static const bool _showHomeBikeGarage = false;
  static const bool _showHomeLatestProducts = false;

  Widget _buildNoInternetBanner() {
    final palette = context.appPalette;
    final backgroundColor = palette.isLight
        ? palette.surfaceStrong
        : palette.highlight.withOpacity(0.18);
    final borderColor = palette.isLight
        ? palette.border
        : palette.highlight.withOpacity(0.88);
    final progressTrack = palette.isLight
        ? palette.surfaceSoft
        : Colors.white.withOpacity(0.18);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: palette.textPrimary.withOpacity(0.14),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_sync_rounded,
                color: palette.isLight
                    ? palette.accentStrong
                    : palette.highlight,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _serverRetryActive ? "Server is busy" : "Connection issue",
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            _serverRetryActive
                ? "Retrying in 5 seconds. Please wait."
                : "Data will load as soon as the connection is restored.",
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            minHeight: 2.5,
            backgroundColor: progressTrack,
            valueColor: AlwaysStoppedAnimation<Color>(
              palette.isLight ? palette.accentStrong : palette.highlight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleButtons() {
    final saleCards = <Widget>[
      _DailySaleCountdownCard(
        isEnabled: _dailySaleEnabled,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SaleProductsScreen(
                collectionKey: "daily_sale",
                title: "Daily Sale",
              ),
            ),
          );
        },
      ),
      SaleBanner(
        daily: false,
        enabled: _bigDaysSaleEnabled,
        saleTitle: _bigDaysSaleLabel,
        festivalKey: _bigDaysFestivalKey,
        upcomingMessage: _bigDaysSaleEnabled ? null : _upcomingSaleMessage,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SaleProductsScreen(
                collectionKey: "big_days_sale",
                title: _bigDaysSaleLabel,
              ),
            ),
          );
        },
      ),
    ];

    Widget saleRow(double height) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(height: height, child: saleCards[0]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(height: height, child: saleCards[1]),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 10) / 2;
              final bannerHeight = cardWidth * 630 / 1045;
              return saleRow(bannerHeight);
            },
          ),
          const SizedBox(height: 12),
          const StorefrontBenefits(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 62,
                  child: StorefrontServiceCard(
                    title: "Track Your Parcel",
                    subtitle: "Enter AWB / Order No.",
                    icon: Icons.inventory_2_rounded,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TrackingWebViewScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 62,
                  child: StorefrontServiceCard(
                    title: "Motorcycle Service",
                    subtitle: "Book Bike Service\nNear You",
                    icon: Icons.handyman_rounded,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const MotorcycleServiceStationScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductGridCard(Product product, AppThemePalette palette) =>
      _buildSafeOptimizedProductGridCard(product, palette);

  /*
  Widget _buildProductGridCard(Product product, AppThemePalette palette) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => ProductDetailScreen(product: product),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          ).then((_) => _loadRecentlyViewedProducts());
        },
        child: Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18),
                      ),
                      child: AppCachedImage(
                        url: product.image,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        memCacheWidth: _homeProductImageCacheWidth,
                        maxWidthDiskCache: _homeProductImageCacheWidth,
                        filterQuality: FilterQuality.low,
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.08),
                              Colors.black.withOpacity(0.32),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: palette.surface.withOpacity(0.82),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: palette.border),
                        ),
                        child: Text(
                          product.discountPercent > 0 ? "TRENDING" : "NEW",
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    if (product.discountPercent > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: palette.highlight,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            "${product.discountPercent}% OFF",
                            style: TextStyle(
                              color: palette.highlight.computeLuminance() > 0.45
                                  ? Colors.black
                                  : Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    if (product.priceDropped)
                      Positioned(
                        top: product.discountPercent > 0 ? 36 : 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2F6BFF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            "DROP",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "RCB • UMA Racing",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: 9.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      Text(
                        "\u20B9${product.price}",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: palette.accent,
                        ),
                      ),
                      if (product.hasDiscount)
                        Text(
                          "\u20B9${product.regularPrice}",
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 9.5,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Consumer<CartProvider>(
              builder: (context, cart, child) {
                final isInCart = cart.items.any(
                  (item) => item.id == product.id && item.variationId == null,
                );

                return Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: Builder(
                      builder: (buttonContext) {
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isInCart
                                    ? palette.surfaceStrong
                                    : palette.accent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () {
                            final cartProvider = Provider.of<CartProvider>(
                              context,
                              listen: false,
                            );
                            final alreadyInCart = cartProvider.items.any(
                              (item) =>
                                  item.id == product.id &&
                                  item.variationId == null,
                            );

                            if (alreadyInCart) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CartScreen(),
                                ),
                              );
                            } else {
                              cartProvider.addToCart(
                                CartItem(
                                  id: product.id,
                                  variationId: null,
                                  name: product.name,
                                  image: product.image,
                                  price: double.tryParse(product.price) ?? 0,
                                  quantity: 1,
                                ),
                              );
                              _runAddToBagAnimation(
                                startContext: buttonContext,
                                imageUrl: product.image,
                              );
                            }
                          },
                          child: Text(
                            isInCart ? "Go to Bag" : "Add to Bag",
                            style: TextStyle(
                              color:
                                  isInCart
                                      ? palette.textPrimary
                                      : palette.onAccent,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  */

  Widget _buildSafeOptimizedProductGridCard(
    Product product,
    AppThemePalette palette,
  ) {
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) =>
                    ProductDetailScreen(product: product),
                transitionsBuilder: (_, animation, __, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              ),
            ).then((_) => _loadRecentlyViewedProducts());
          },
          child: Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                          child: AppCachedImage(
                            url: product.image,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            memCacheWidth: _homeProductImageCacheWidth,
                            maxWidthDiskCache: _homeProductImageCacheWidth,
                            filterQuality: FilterQuality.low,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(18),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.06),
                                Colors.black.withOpacity(0.22),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: palette.surface.withOpacity(0.84),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: palette.border),
                          ),
                          child: Text(
                            product.discountPercent > 0 ? "TRENDING" : "NEW",
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                      if (product.discountPercent > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: palette.highlight,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              "${product.discountPercent}% OFF",
                              style: TextStyle(
                                color:
                                    palette.highlight.computeLuminance() > 0.45
                                    ? Colors.black
                                    : Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      if (product.priceDropped)
                        Positioned(
                          top: product.discountPercent > 0 ? 36 : 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2F6BFF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              "DROP",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "RCB • UMA Racing",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textMuted,
                          fontSize: 9.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          Text(
                            "\u20B9${product.price}",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: palette.accent,
                            ),
                          ),
                          if (product.hasDiscount)
                            Text(
                              "\u20B9${product.regularPrice}",
                              style: TextStyle(
                                color: palette.textMuted,
                                fontSize: 9.5,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Consumer<CartProvider>(
                  builder: (context, cart, _) {
                    final isInCart = cart.items.any(
                      (item) =>
                          item.id == product.id && item.variationId == null,
                    );

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isInCart
                                ? palette.surfaceStrong
                                : palette.accent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () {
                            final cartProvider = Provider.of<CartProvider>(
                              context,
                              listen: false,
                            );
                            final alreadyInCart = cartProvider.items.any(
                              (item) =>
                                  item.id == product.id &&
                                  item.variationId == null,
                            );

                            if (alreadyInCart) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CartScreen(),
                                ),
                              );
                              return;
                            }

                            cartProvider.addToCart(
                              CartItem(
                                id: product.id,
                                variationId: null,
                                name: product.name,
                                image: product.image,
                                price: double.tryParse(product.price) ?? 0,
                                quantity: 1,
                              ),
                            );
                          },
                          child: Text(
                            isInCart ? "Go to Bag" : "Add to Bag",
                            style: TextStyle(
                              color: isInCart
                                  ? palette.textPrimary
                                  : palette.onAccent,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommerceHeroStrip(AppThemePalette palette) {
    if (_bigDaysSaleEnabled || _upcomingSaleMessage != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final saleWidth = (constraints.maxWidth * 0.55)
              .clamp(160.0, 188.0)
              .toDouble();
          return Row(
            children: [
              SizedBox(
                width: saleWidth,
                child: _buildBigDaysSaleSearchBanner(palette),
              ),
              const Spacer(),
              _buildHeroBadge(
                palette: palette,
                icon: Icons.bolt_rounded,
                title: "RCB",
                compact: true,
                onTap: (startContext) =>
                    _fillSearchFromBadgeAnimated("RCB", startContext),
              ),
              const SizedBox(width: 5),
              _buildHeroBadge(
                palette: palette,
                icon: Icons.flash_on_rounded,
                title: "UMA Racing",
                compact: true,
                onTap: (startContext) =>
                    _fillSearchFromBadgeAnimated("UMA Racing", startContext),
              ),
            ],
          );
        },
      );
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            "Search faster, shop compact, and keep your favorites ready.",
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 11.5,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 10),
        _buildHeroBadge(
          palette: palette,
          icon: Icons.bolt_rounded,
          title: "RCB",
          onTap: (startContext) =>
              _fillSearchFromBadgeAnimated("RCB", startContext),
        ),
        const SizedBox(width: 8),
        _buildHeroBadge(
          palette: palette,
          icon: Icons.flash_on_rounded,
          title: "UMA Racing",
          onTap: (startContext) =>
              _fillSearchFromBadgeAnimated("UMA Racing", startContext),
        ),
      ],
    );
  }

  Widget _buildBigDaysSaleSearchBanner(AppThemePalette palette) {
    final isLive = _bigDaysSaleEnabled;
    final upcomingMessage = _upcomingSaleMessage ?? '';
    final label = isLive ? _bigDaysSaleLabel : upcomingMessage;
    final statusColor = isLive ? const Color(0xFFFF4655) : palette.accentStrong;
    final pulse = CurvedAnimation(
      parent: _saleLivePulseController,
      curve: Curves.easeInOut,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SaleProductsScreen(
                collectionKey: 'big_days_sale',
                title: _bigDaysSaleLabel,
              ),
            ),
          );
        },
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              ScaleTransition(
                scale: Tween<double>(begin: 0.82, end: 1.12).animate(pulse),
                child: Icon(
                  isLive ? Icons.circle : Icons.event_available_rounded,
                  size: isLive ? 11 : 15,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 3),
              ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.08).animate(pulse),
                child: Text(
                  isLive ? 'LIVE' : 'UPCOMING',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 8,
                    letterSpacing: 0.3,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBadge({
    required AppThemePalette palette,
    required IconData icon,
    required String title,
    bool compact = false,
    Future<void> Function(BuildContext startContext)? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: Builder(
        builder: (badgeContext) {
          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap == null ? null : () => onTap(badgeContext),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 9 : 11,
                vertical: compact ? 7 : 8,
              ),
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: compact ? 12 : 14, color: palette.onAccent),
                  SizedBox(width: compact ? 3 : 6),
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.onAccent,
                      fontSize: compact ? 9.5 : 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickAccessRail() {
    final palette = context.appPalette;
    return Positioned.fill(
      child: SafeArea(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.zero,
            child: AnimatedContainer(
              key: _quickAccessRailKey,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: EdgeInsets.symmetric(
                horizontal: _quickAccessExpanded ? 8 : 5,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    palette.surfaceStrong.withValues(alpha: 0.94),
                    palette.surface.withValues(alpha: 0.94),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: palette.textPrimary.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      setState(
                        () => _quickAccessExpanded = !_quickAccessExpanded,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: palette.surfaceSoft,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Center(
                        child: Icon(
                          _quickAccessExpanded
                              ? Icons.keyboard_arrow_left_rounded
                              : Icons.keyboard_arrow_right_rounded,
                          color: palette.accent,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                  if (_quickAccessExpanded) ...[
                    const SizedBox(height: 10),
                    _buildQuickActionIcon(
                      icon: Icons.two_wheeler_rounded,
                      tooltip: 'Bike Garage',
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BikeGarageScreen(),
                          ),
                        );
                        _refreshBikeGarage();
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildQuickActionIcon(
                      icon: Icons.psychology_alt_rounded,
                      tooltip: 'AI Brain',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AIBrainScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildQuickActionIcon(
                      icon: Icons.groups_rounded,
                      tooltip: 'Riding Groups',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RidingGroupsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildQuickActionIcon(
                      icon: Icons.route_rounded,
                      tooltip: 'Riding Events',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RideCommunityScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final palette = context.appPalette;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: palette.surfaceSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          child: Icon(icon, color: palette.accent, size: 20),
        ),
      ),
    );
  }
}

class _DailySaleCountdownCard extends StatefulWidget {
  const _DailySaleCountdownCard({required this.isEnabled, required this.onTap});

  final bool isEnabled;
  final VoidCallback onTap;

  @override
  State<_DailySaleCountdownCard> createState() =>
      _DailySaleCountdownCardState();
}

class _DailySaleCountdownCardState extends State<_DailySaleCountdownCard> {
  late Timer _timer;
  DateTime _clock = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _clock = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  DateTime _dailySaleStart(DateTime now) =>
      DateTime(now.year, now.month, now.day, 10);

  DateTime _dailySaleEnd(DateTime now) =>
      DateTime(now.year, now.month, now.day, 19);

  bool get _isLive =>
      !_clock.isBefore(_dailySaleStart(_clock)) &&
      _clock.isBefore(_dailySaleEnd(_clock));

  Duration _countdownDuration() {
    final todayStart = _dailySaleStart(_clock);
    final todayEnd = _dailySaleEnd(_clock);
    if (_clock.isBefore(todayStart)) return todayStart.difference(_clock);
    if (_clock.isBefore(todayEnd)) return todayEnd.difference(_clock);
    return todayStart.add(const Duration(days: 1)).difference(_clock);
  }

  String _formatCountdown(Duration duration) {
    final safeDuration = duration.isNegative ? Duration.zero : duration;
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(safeDuration.inHours)}:'
        '${twoDigits(safeDuration.inMinutes.remainder(60))}:'
        '${twoDigits(safeDuration.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    final isLive = widget.isEnabled && _isLive;
    return SaleBanner(
      daily: true,
      enabled: isLive,
      onTap: widget.onTap,
      countdown: widget.isEnabled
          ? _formatCountdown(_countdownDuration())
          : '--:--:--',
      countdownLabel: !widget.isEnabled
          ? 'Currently disabled'
          : isLive
          ? 'Ends in'
          : 'Starts in',
    );
  }
}

class _RetryingHomeCategoryImage extends StatefulWidget {
  const _RetryingHomeCategoryImage({
    required this.debugLabel,
    required this.imageUrl,
    required this.fit,
    required this.memCacheWidth,
  });

  final String debugLabel;
  final String imageUrl;
  final BoxFit fit;
  final int memCacheWidth;

  @override
  State<_RetryingHomeCategoryImage> createState() =>
      _RetryingHomeCategoryImageState();
}

class _RetryingHomeCategoryImageState
    extends State<_RetryingHomeCategoryImage> {
  Timer? _retryTimer;
  int _retryAttempt = 0;
  String? _lastRemovedFailedUrl;

  @override
  void didUpdateWidget(covariant _RetryingHomeCategoryImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _retryAttempt = 0;
      _lastRemovedFailedUrl = null;
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _retryAfterDelay() {
    if (_retryTimer != null) return;
    _retryTimer = Timer(const Duration(seconds: 20), () {
      _retryTimer = null;
      if (!mounted) return;
      setState(() => _retryAttempt++);
    });
  }

  void _removeFailedCachedImage(String url) {
    if (_lastRemovedFailedUrl == url) return;
    _lastRemovedFailedUrl = url;
    unawaited(CategoryImageCache.removeFailedFile(url));
  }

  String get _retryUrl {
    if (_retryAttempt == 0) return widget.imageUrl;
    final uri = Uri.tryParse(widget.imageUrl);
    if (uri == null) return widget.imageUrl;
    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            'retry': _retryAttempt.toString(),
          },
        )
        .toString();
  }

  Widget _loadingPlaceholder() {
    return const SkeletonBox(radius: 16);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.imageUrl.trim().toLowerCase().startsWith('http')) {
      return _loadingPlaceholder();
    }

    return CachedNetworkImage(
      key: ValueKey(_retryUrl),
      imageUrl: _retryUrl,
      cacheManager: CategoryImageCache.instance,
      fit: widget.fit,
      memCacheWidth: widget.memCacheWidth,
      filterQuality: FilterQuality.low,
      placeholder: (_, __) => const SkeletonBox(radius: 16),
      imageBuilder: (context, imageProvider) {
        _retryTimer?.cancel();
        _retryTimer = null;
        return Image(image: imageProvider, fit: widget.fit);
      },
      errorWidget: (_, url, error) {
        debugPrint(
          '[home-category-image] ${widget.debugLabel} url=$url error=$error',
        );
        _removeFailedCachedImage(_retryUrl);
        _retryAfterDelay();
        return _loadingPlaceholder();
      },
    );
  }
}

class _BarcodeScannerScreen extends StatefulWidget {
  const _BarcodeScannerScreen();

  @override
  State<_BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<_BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim() ?? "")
        .firstWhere((code) => code.isNotEmpty, orElse: () => "");
    if (value.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("Scan Barcode"),
        actions: [
          IconButton(
            tooltip: "Flash",
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: _controller.toggleTorch,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _handleDetect),
          Center(
            child: Container(
              width: 260,
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 34,
            child: Text(
              "Place the barcode inside the frame",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.86),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
