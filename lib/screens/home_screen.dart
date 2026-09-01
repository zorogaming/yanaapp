import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature, lerpDouble;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import 'package:marquee/marquee.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

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
  });

  final Map<String, List> groupedCategories;
  final List<dynamic> topBrandCategories;
}

class _HomeTopNavItem {
  const _HomeTopNavItem({
    required this.title,
    required this.key,
    required this.icon,
  });

  final String title;
  final String key;
  final IconData icon;
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
  String? _loadedYoutubeId;

  @override
  void initState() {
    super.initState();
    _configureVideoIfNeeded();
  }

  @override
  void didUpdateWidget(covariant HomeBannerMediaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.youtubeId != widget.item.youtubeId ||
        oldWidget.item.type != widget.item.type) {
      _configureVideoIfNeeded();
    }
  }

  void _configureVideoIfNeeded() {
    if (!widget.item.isVideo) {
      _controller = null;
      _loadedYoutubeId = null;
      return;
    }

    final safeId = widget.item.youtubeId!.replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '',
    );
    if (safeId.isEmpty || safeId == _loadedYoutubeId) return;

    _loadedYoutubeId = safeId;
    final params = WebViewPlatform.instance is WebKitWebViewPlatform
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'YanaVideoState',
        onMessageReceived: (message) {
          final value = message.message.trim().toLowerCase();
          if (value == 'play') {
            widget.onVideoStarted?.call();
          } else if (value == 'ended') {
            widget.onVideoEnded?.call();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            widget.onVideoStarted?.call();
          },
        ),
      );

    _controller = controller;
    controller.loadHtmlString(
      _buildYoutubeEmbedHtml(safeId),
      baseUrl: 'https://www.youtube.com',
    );
  }

  String _buildYoutubeEmbedHtml(String youtubeId) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: #000;
    }
    #player {
      position: fixed;
      inset: 0;
      width: 100%;
      height: 100%;
      background: #000;
    }
    iframe {
      position: fixed;
      inset: 0;
      width: 100%;
      height: 100%;
      border: 0;
      pointer-events: none;
      background: #000;
    }
  </style>
</head>
<body>
  <div id="player"></div>
  <script>
    var tag = document.createElement('script');
    tag.src = 'https://www.youtube.com/iframe_api';
    document.head.appendChild(tag);

    var player;

    function notify(value) {
      try {
        if (window.YanaVideoState && window.YanaVideoState.postMessage) {
          window.YanaVideoState.postMessage(value);
        }
      } catch (error) {}
    }

    function forceMutedPlayback() {
      try {
        if (!player || !player.mute || !player.playVideo) {
          return;
        }
        player.mute();
        player.setVolume(0);
        player.playVideo();
      } catch (error) {}
    }

    function onYouTubeIframeAPIReady() {
      player = new YT.Player('player', {
        videoId: '$youtubeId',
        width: '100%',
        height: '100%',
        playerVars: {
          autoplay: 1,
          mute: 1,
          controls: 0,
          playsinline: 1,
          rel: 0,
          modestbranding: 1,
          iv_load_policy: 3,
          fs: 0,
          disablekb: 1,
          loop: 1,
          playlist: '$youtubeId',
          origin: 'https://www.youtube.com'
        },
        events: {
          onReady: function(event) {
            forceMutedPlayback();
            notify('play');
          },
          onStateChange: function(event) {
            if (event.data === YT.PlayerState.PLAYING) {
              forceMutedPlayback();
              notify('play');
            } else if (event.data === YT.PlayerState.ENDED) {
              notify('ended');
              forceMutedPlayback();
            }
          },
          onError: function() {
            notify('error');
          }
        }
      });
      window.setInterval(forceMutedPlayback, 1800);
    }
  </script>
</body>
</html>
''';
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

    final safeId = widget.item.youtubeId!.replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '',
    );
    final thumbnailUrl = safeId.isEmpty
        ? ''
        : 'https://i.ytimg.com/vi/$safeId/hqdefault.jpg';

    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumbnailUrl.isNotEmpty)
          AppCachedImage(
            url: thumbnailUrl,
            width: double.infinity,
            fit: BoxFit.cover,
            memCacheWidth: _HomeScreenState._homeBannerCacheWidth,
            maxWidthDiskCache: _HomeScreenState._homeBannerCacheWidth,
            filterQuality: FilterQuality.low,
          )
        else
          Container(color: Colors.black),
        if (_controller != null)
          Positioned.fill(
            child: IgnorePointer(
              child: WebViewWidget(controller: _controller!),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.03),
                    Colors.transparent,
                    Colors.black.withOpacity(0.08),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
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
  static const String _imageCacheKey = "home_banner_image_txt_cache";
  static const String _imageCacheVersionKey = "home_banner_image_txt_version";
  static const String _videoCacheKey = "home_banner_video_txt_cache";
  static const String _videoCacheVersionKey = "home_banner_video_txt_version";
  static const String _seenHomePopupCampaignsKey =
      "seen_home_popup_campaign_ids";
  static String _lastHandledPopupSignature = "";
  static bool _hasCheckedHomePopupThisSession = false;
  static const bool _homeBannerVideosEnabled = false;
  static const int _homeBannerCacheWidth = 1280;
  static const int _homeProductImageCacheWidth = 720;
  static const int _homeCategoryImageCacheWidth = 240;
  static const double _saleCardHeight = 100;
  static const bool _showQuickAccessRail = false;
  final CarouselSliderController _bannerController = CarouselSliderController();
  Future<_HomeCategorySectionData>? _categorySectionFuture;
  Future<List<Product>>? _newArrivalsFuture;
  Future<List<Product>>? _bestSellersFuture;
  Future<Map<String, dynamic>>? _bikeGarageFuture;
  late Future<String?> _authTokenFuture;
  late final AnimationController _titleAnimController;
  late final AnimationController _cartPulseController;
  late final AnimationController _searchCtaController;
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
  bool _bigDaysSaleEnabled = true;
  bool _quickAccessExpanded = false;
  bool _shopByBikeIntroRunning = false;
  bool _shopByBikeIntroTopActive = false;
  bool _selectMotorcycleIntroActive = false;
  String _selectedTopCategoryKey = "shop_by_bike";
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
      loadOffer();
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
      _refreshInternetStatus();
      _loadRecentlyViewedProducts();
    }
  }

  Future<_HomeCategorySectionData> _loadHomeCategorySection() async {
    final results = await Future.wait<dynamic>([
      dataManager.getGroupedCategoriesWithData(),
      dataManager.getTopBrandCategories(),
    ]);
    return _HomeCategorySectionData(
      groupedCategories: results[0] as Map<String, List>,
      topBrandCategories: results[1] as List<dynamic>,
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
      });
    });
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
      ),
      _HomeTopNavItem(
        title: "Shop By Category",
        key: "shop_by_category",
        icon: Icons.grid_view_rounded,
      ),
      _HomeTopNavItem(
        title: "Bike Accessories",
        key: "motorcycle_accessories",
        icon: Icons.handyman_rounded,
      ),
      _HomeTopNavItem(
        title: "Riding Gears",
        key: "riding_gears",
        icon: Icons.sports_motorsports_rounded,
      ),
      _HomeTopNavItem(
        title: "Luggage",
        key: "luggage_touring",
        icon: Icons.luggage_rounded,
      ),
      _HomeTopNavItem(
        title: "Helmet",
        key: "helmets_accessories",
        icon: Icons.health_and_safety_rounded,
      ),
      _HomeTopNavItem(
        title: "Lubricants",
        key: "combos",
        icon: Icons.inventory_2_rounded,
      ),
      _HomeTopNavItem(
        title: "Top Brands",
        key: "events",
        icon: Icons.workspace_premium_rounded,
      ),
    ];
  }

  Future<void> _warmBannerImages() async {
    if (!mounted) return;
    for (final item in _bannerItems.where((item) => !item.isVideo).take(1)) {
      final source = item.sourceUrl.trim();
      if (!source.toLowerCase().startsWith("http")) continue;
      unawaited(
        precacheImage(
          CachedNetworkImageProvider(source),
          context,
          size: const Size(1280, 720),
        ),
      );
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
    try {
      final payloads = await Future.wait<Map<String, dynamic>>([
        dataManager.getSaleCollection("daily_sale", preferCache: true),
        dataManager.getSaleCollection("big_days_sale", preferCache: true),
      ]);
      if (!mounted) return;
      setState(() {
        _dailySaleEnabled = payloads[0]["enabled"] != false;
        _bigDaysSaleEnabled = payloads[1]["enabled"] != false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dailySaleEnabled = true;
        _bigDaysSaleEnabled = true;
      });
    }
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

  Widget _buildAnimatedSearchArrow(AppThemePalette palette) {
    return AnimatedBuilder(
      animation: _searchCtaController,
      builder: (context, child) {
        final hasQuery = currentSearch.trim().isNotEmpty;
        final t = Curves.easeInOutCubic.transform(_searchCtaController.value);
        final scale = hasQuery ? 1 + (0.07 * t) : 1.0;
        final shift = hasQuery ? 1 + (4 * t) : 0.0;
        final glowOpacity = hasQuery ? 0.20 + (0.16 * t) : 0.0;
        final ringOpacity = hasQuery ? 0.22 - (0.10 * t) : 0.0;

        return SizedBox(
          width: 52,
          height: 46,
          child: Transform.translate(
            offset: Offset(shift - 6, 0),
            child: Transform.scale(
              scale: scale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (hasQuery)
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: palette.accent.withOpacity(ringOpacity),
                          width: 2,
                        ),
                      ),
                    ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: hasQuery
                            ? [
                                palette.accentStrong,
                                palette.accent,
                                palette.highlight,
                              ]
                            : [palette.accent, palette.accent],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: hasQuery
                          ? [
                              BoxShadow(
                                color: palette.accent.withOpacity(glowOpacity),
                                blurRadius: 18,
                                spreadRadius: 1.2,
                                offset: const Offset(0, 5),
                              ),
                            ]
                          : const [],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (hasQuery)
                          Opacity(
                            opacity: 0.14 + (0.18 * t),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              color: palette.onAccent,
                              size: 19,
                            ),
                          ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: palette.onAccent,
                          size: 15,
                        ),
                      ],
                    ),
                  ),
                ],
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
                    color: palette.accent,
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
    if (!_homeBannerVideosEnabled) {
      _bannerItems.removeWhere((item) => item.isVideo);
      if (_currentBannerIndex >= _bannerItems.length) {
        _currentBannerIndex = 0;
      }
      return;
    }

    _bannerItems.removeWhere((item) => item.isVideo);
    _bannerItems.addAll(videoItems);
  }

  void _replaceImageBanners(List<HomeBannerMedia> imageItems) {
    _bannerItems.removeWhere(
      (item) => !item.isVideo || !_homeBannerVideosEnabled,
    );
    _bannerItems.insertAll(0, imageItems);
    if (_currentBannerIndex >= _bannerItems.length) {
      _currentBannerIndex = 0;
    }
  }

  List<HomeBannerMedia> _parseImageLinks(String raw) {
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
      items.add(HomeBannerMedia.image(value));
    }

    if (items.isNotEmpty) {
      return items;
    }

    return _defaultBannerImageUrls
        .map((url) => HomeBannerMedia.image(url))
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

  String _normalizeCategoryName(String value) {
    return value.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), " ").trim();
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

  Widget _buildTopCategoryNavigation(List<_HomeTopNavItem> items) {
    final palette = context.appPalette;
    if (items.isEmpty) return const SizedBox.shrink();
    final collapse = Curves.easeOutCubic.transform(_homeChromeCollapseProgress);
    final expandedHeight = 52.0;
    final compactHeight = 50.0;
    final navHeight = lerpDouble(expandedHeight, compactHeight, collapse)!;
    final itemWidth = lerpDouble(92, 106, collapse)!;
    final itemContentHeight = 46.0;
    final iconOpacity = (1 - (collapse * 1.25)).clamp(0.0, 1.0);
    final iconSlotHeight = lerpDouble(22.0, 0.0, collapse)!.clamp(0.0, 22.0);
    final textFontSize = lerpDouble(9.6, 9.8, collapse)!;
    const textHeight = 12.0;
    final compactTextColor = Color.lerp(
      palette.textPrimary.withOpacity(0.74),
      palette.textPrimary.withOpacity(0.78),
      collapse,
    )!;
    final compactSelectedTextColor = Color.lerp(
      palette.textPrimary,
      palette.textPrimary,
      collapse,
    )!;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        height: navHeight,
        margin: EdgeInsets.fromLTRB(0, lerpDouble(0, 2, collapse)!, 0, 0),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.zero,
          color: Colors.transparent,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: Stack(
            children: [
              ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    SizedBox(width: lerpDouble(6, 8, collapse)!),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = item.key == _selectedTopCategoryKey;
                  final isPrimaryItem = item.key == "shop_by_bike";
                  final isIntroTarget =
                      _shopByBikeIntroTopActive && item.key == "shop_by_bike";
                  final title = item.title;
                  final tileWidth = isPrimaryItem
                      ? lerpDouble(108, 114, collapse)!
                      : itemWidth;
                  final tileContentHeight = itemContentHeight;
                  return SizedBox(
                    width: tileWidth,
                    child: AnimatedBuilder(
                      animation: _shopByBikeIntroController,
                      builder: (context, child) {
                        final pulse = isIntroTarget
                            ? _shopByBikeIntroController.value
                            : 0.0;
                        return Transform.scale(
                          scale: 1 + (pulse * 0.045),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOutCubic,
                            margin: EdgeInsets.symmetric(
                              horizontal: isPrimaryItem ? 8 : 0,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isIntroTarget
                                  ? Color.lerp(
                                      palette.highlight.withOpacity(0.20),
                                      palette.highlight.withOpacity(0.34),
                                      pulse,
                                    )
                                  : isPrimaryItem
                                  ? palette.accent.withOpacity(
                                      palette.isLight ? 0.16 : 0.20,
                                    )
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: isIntroTarget || isPrimaryItem
                                  ? Border.all(
                                      color: isIntroTarget
                                          ? palette.highlight.withOpacity(0.58)
                                          : palette.accent.withOpacity(0.46),
                                      width: isPrimaryItem ? 1.4 : 1.2,
                                    )
                                  : null,
                              boxShadow: const [],
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          onTap: () => _handleTopCategoryTap(item),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: lerpDouble(4, 6, collapse)!,
                            ),
                            child: SizedBox(
                              height: tileContentHeight,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ClipRect(
                                    child: SizedBox(
                                      height: iconSlotHeight,
                                      child: Opacity(
                                        opacity: iconOpacity,
                                        child: Center(
                                          child: Container(
                                            width: isPrimaryItem ? 34 : 32,
                                            height: isPrimaryItem ? 23 : 22,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? palette.accent.withOpacity(
                                                      palette.isLight
                                                          ? 0.16
                                                          : 0.18,
                                                    )
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              item.icon,
                                              color: isSelected
                                                  ? palette.accent
                                                  : palette.textPrimary,
                                              size: isPrimaryItem ? 18 : 17,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  SizedBox(
                                    height: textHeight,
                                    child: Text(
                                      title,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isSelected
                                            ? compactSelectedTextColor
                                            : compactTextColor,
                                        fontSize: isPrimaryItem
                                            ? textFontSize + 0.4
                                            : textFontSize,
                                        height: 1.05,
                                        fontWeight: isPrimaryItem || isSelected
                                            ? FontWeight.w900
                                            : FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 1),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    curve: Curves.easeOutCubic,
                                    width: isSelected
                                        ? lerpDouble(44, 52, collapse)!
                                        : 0,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? palette.accent
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ],
                              ),
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
                    width: 18,
                    height: navHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          palette.background,
                          palette.background.withOpacity(0.0),
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
                    width: 18,
                    height: navHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          palette.background,
                          palette.background.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 28,
                right: 28,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          palette.accent.withOpacity(0.45),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryScroller(List<dynamic> categories) {
    final palette = context.appPalette;
    final isWhiteTheme = palette.id == AppThemes.whitePalette.id;
    return SizedBox(
      height: 146,
      child: Stack(
        children: [
          ListView.builder(
            scrollDirection: Axis.horizontal,
            cacheExtent: 360,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index] is Map
                  ? Map<String, dynamic>.from(categories[index] as Map)
                  : <String, dynamic>{};

              return Container(
                width: 90,
                margin: EdgeInsets.only(
                  left: index == 0 ? 16 : 12,
                  right: index == categories.length - 1 ? 16 : 0,
                ),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductsScreen(
                          categoryId: cat["id"],
                          title: cat["name"],
                        ),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          color: isWhiteTheme ? palette.surface : Colors.white,
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                            color: isWhiteTheme
                                ? palette.border
                                : palette.accent,
                            width: 2.6,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                Theme.of(context).brightness == Brightness.light
                                    ? 0.05
                                    : 0.18,
                              ),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(10),
                        child:
                            cat["image"] != null && cat["image"]["src"] != null
                            ? AppCachedImage(
                                url: (cat["image"]["src"] ?? "").toString(),
                                fit: BoxFit.contain,
                                isCircular: true,
                                memCacheWidth: _homeCategoryImageCacheWidth,
                                maxWidthDiskCache: _homeCategoryImageCacheWidth,
                                filterQuality: FilterQuality.low,
                              )
                            : Image.asset(
                                "assets/icon/Blank.jpg",
                                fit: BoxFit.contain,
                              ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 28,
                        child: Text(
                          (cat["name"] ?? "").toString(),
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
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                width: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      palette.background.withOpacity(0.0),
                      palette.background.withOpacity(0.85),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.chevron_right,
                    color: palette.textMuted,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentlyViewedSection() {
    final palette = context.appPalette;
    final items = _recentlyViewedProducts.take(10).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              Icon(Icons.history_rounded, color: palette.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                "Recently Viewed",
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                  );
                },
                child: Text(
                  "Continue Shopping",
                  style: TextStyle(
                    color: palette.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 164,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final product = items[index];
              return SizedBox(
                width: 120,
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
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: palette.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                          Padding(
                            padding: const EdgeInsets.fromLTRB(9, 8, 9, 0),
                            child: Text(
                              product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 11,
                                height: 1.12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(9, 5, 9, 0),
                            child: Text(
                              "₹${product.price}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
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
      accentColorBuilder: (palette) => palette.highlight,
    );
  }

  Widget _buildBestSellersSection() {
    return _buildProductRailSection(
      future: _bestSellersFuture,
      title: "Best Sellers",
      pillText: "Top 10",
      icon: Icons.local_fire_department_rounded,
      badgeText: "BEST",
      accentColorBuilder: (palette) => palette.accent,
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
                        height: 94,
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
                    Positioned(
                      top: 7,
                      left: 7,
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

  Widget _buildTopBrandsAutoCarousel(List<dynamic> categories) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final palette = context.appPalette;
    final isWhiteTheme = palette.id == AppThemes.whitePalette.id;
    return SizedBox(
      height: 136,
      child: CarouselSlider.builder(
        itemCount: categories.length,
        options: CarouselOptions(
          height: 126,
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
          return Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 16 : 6,
              right: index == categories.length - 1 ? 16 : 6,
            ),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductsScreen(
                      categoryId: cat["id"],
                      title: cat["name"],
                    ),
                  ),
                );
              },
              child: Column(
                children: [
                  Container(
                    height: 78,
                    width: 78,
                    decoration: BoxDecoration(
                      color: isWhiteTheme ? palette.surface : Colors.white,
                      borderRadius: BorderRadius.circular(39),
                      border: Border.all(
                        color: isWhiteTheme ? palette.border : palette.accent,
                        width: 2.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            Theme.of(context).brightness == Brightness.light
                                ? 0.05
                                : 0.18,
                          ),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(10),
                    child: cat["image"] != null && cat["image"]["src"] != null
                        ? AppCachedImage(
                            url: (cat["image"]["src"] ?? "").toString(),
                            fit: BoxFit.contain,
                            isCircular: true,
                            memCacheWidth: _homeCategoryImageCacheWidth,
                            maxWidthDiskCache: _homeCategoryImageCacheWidth,
                            filterQuality: FilterQuality.low,
                          )
                        : Image.asset(
                            "assets/icon/Blank.jpg",
                            fit: BoxFit.contain,
                          ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 28,
                    child: Text(
                      (cat["name"] ?? "").toString(),
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
    WidgetsBinding.instance.removeObserver(this);
    widget.recentlyViewedRefresh?.removeListener(_handleRecentlyViewedRefresh);
    _titleAnimController.dispose();
    _cartPulseController.dispose();
    _searchCtaController.dispose();
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
    final cachedRaw = prefs.getString(_imageCacheKey) ?? "";

    if (cachedRaw.isNotEmpty && mounted) {
      final cachedItems = _parseImageLinks(cachedRaw);
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
            Uri.parse("https://yanaworldwide.store/Yanaapp/banner.txt?v=$now"),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;

      final imageItems = _parseImageLinks(response.body);
      if (imageItems.isEmpty) return;

      await prefs.setString(_imageCacheKey, response.body);
      await prefs.remove(_imageCacheVersionKey);
      if (!mounted) return;

      setState(() {
        _replaceImageBanners(imageItems);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _warmBannerImages();
      });
    } catch (_) {}
  }

  List<Color> _themeSaleCardColors(AppThemePalette palette, int tone) {
    final start = switch (tone % 4) {
      0 => palette.accentStrong,
      1 => Color.lerp(palette.accentStrong, palette.highlight, 0.25)!,
      2 => palette.accent,
      _ => Color.lerp(palette.accent, palette.success, 0.25)!,
    };
    final end = switch (tone % 4) {
      0 => palette.highlight,
      1 => palette.accent,
      2 => Color.lerp(palette.highlight, palette.accent, 0.35)!,
      _ => palette.highlight,
    };
    return <Color>[start, end];
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
    final homeBody = _buildHomeBody();

    return ValueListenableBuilder<double>(
      valueListenable: _homeChromeCollapseProgressNotifier,
      child: homeBody,
      builder: (context, collapseProgress, body) {
        _homeChromeCollapseProgress = collapseProgress;
        final collapse = Curves.easeOutCubic.transform(collapseProgress);
        final headerTopPadding = lerpDouble(8, 4, collapse)!;
        final headerGap = lerpDouble(7, 0, collapse)!;
        final topCategoryNavHeight = 50.0 + lerpDouble(0, 2, collapse)!;
        final appBarHeight =
            headerTopPadding +
            (logoRowHeight * (1 - collapse)) +
            headerGap +
            lerpDouble(48, 46, collapse)! +
            searchSuggestionHeight +
            headerGap +
            (commerceStripHeight * (1 - collapse)) +
            (commerceToCategoryGap * (1 - collapse)) +
            topCategoryNavHeight +
            overflowGuard;
        final searchHeight = lerpDouble(48, 46, collapse)!;

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
                left: 16,
                right: 16,
              ),
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  maxHeight: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildScrollCollapsingChild(
                        expandedHeight: logoRowHeight,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                color: palette.surface,
                                border: Border.all(
                                  color: palette.border.withOpacity(0.7),
                                ),
                              ),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: palette.isLight ? 12 : 0,
                                  vertical: palette.isLight ? 6 : 0,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.isLight
                                      ? const Color(0xFF121212)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Image.asset(
                                  "assets/icon/icon.png",
                                  height: 28,
                                  fit: BoxFit.contain,
                                ),
                              ),
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
                                              children: [
                                                IconButton(
                                                  tooltip: "Wallet",
                                                  icon: Icon(
                                                    Icons
                                                        .account_balance_wallet_outlined,
                                                    color: palette.accent,
                                                    size: 20,
                                                  ),
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            const WalletScreen(),
                                                      ),
                                                    );
                                                  },
                                                  constraints:
                                                      const BoxConstraints(
                                                        minHeight: 34,
                                                        minWidth: 34,
                                                      ),
                                                  padding: const EdgeInsets.all(
                                                    5,
                                                  ),
                                                ),
                                                TextButton(
                                                  style: TextButton.styleFrom(
                                                    minimumSize: Size.zero,
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                  ),
                                                  onPressed: () {
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
                                                  child: Text(
                                                    "Login",
                                                    style: TextStyle(
                                                      color:
                                                          palette.textPrimary,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  "|",
                                                  style: TextStyle(
                                                    color: palette.textMuted,
                                                  ),
                                                ),
                                                TextButton(
                                                  style: TextButton.styleFrom(
                                                    minimumSize: Size.zero,
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                  ),
                                                  onPressed: () {
                                                    // ✅ STEP 3: Implement Signup Screen Navigation
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
                                                  child: Text(
                                                    "Signup",
                                                    style: TextStyle(
                                                      color: palette.accent,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }
                                          // ⬆️ UPDATED: Added Signup Button next to Login ⬆️

                                          return Row(
                                            children: [
                                              IconButton(
                                                tooltip: "Wallet",
                                                icon: Icon(
                                                  Icons
                                                      .account_balance_wallet_outlined,
                                                  color: palette.accent,
                                                  size: 20,
                                                ),
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          const WalletScreen(),
                                                    ),
                                                  );
                                                },
                                                constraints:
                                                    const BoxConstraints(
                                                      minHeight: 34,
                                                      minWidth: 34,
                                                    ),
                                                padding: const EdgeInsets.all(
                                                  5,
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
                                                        minimumSize: Size.zero,
                                                        tapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 6,
                                                            ),
                                                        backgroundColor: palette
                                                            .accent
                                                            .withOpacity(0.14),
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
                                                          color: palette.accent,
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
                                                              .clamp(0.0, 1.0),
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
                                                    color: palette.textPrimary,
                                                    size: 20,
                                                  ),
                                                ),
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
                                                  right: 5,
                                                  top: 5,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: palette.accent,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Text(
                                                      cart.items.length
                                                          .toString(),
                                                      style: TextStyle(
                                                        color: palette.onAccent,
                                                        fontSize: 11,
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
                      SizedBox(height: headerGap),
                      Container(
                        key: _searchBoxKey,
                        height: searchHeight,
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: palette.border),
                          color: palette.surface,
                        ),
                        child: TextField(
                          controller: searchController,
                          focusNode: _searchFocusNode,
                          onChanged: _handleSearchChanged,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _goToSearch(),
                          decoration: InputDecoration(
                            hintText: "Search parts, SKU, model, brand...",
                            hintStyle: TextStyle(
                              color: palette.textMuted,
                              fontSize: 13,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: palette.accent,
                              size: 20,
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 42,
                              minHeight: 40,
                              maxHeight: 42,
                            ),
                            suffixIcon: ClipRect(
                              child: SizedBox(
                                width: 84,
                                height: 42,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 3),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 30,
                                        height: 36,
                                        child: Tooltip(
                                          message: "Barcode scanner",
                                          child: InkWell(
                                            onTap: _openBarcodeSearchOption,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: Center(
                                              child: Container(
                                                width: 28,
                                                height: 28,
                                                decoration: BoxDecoration(
                                                  color: palette.accent
                                                      .withOpacity(0.10),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: palette.accent
                                                        .withOpacity(0.22),
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.qr_code_scanner_rounded,
                                                  color: palette.accent,
                                                  size: 18,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 48,
                                        height: 42,
                                        child: InkWell(
                                          onTap: _goToSearch,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Center(
                                            child: _buildAnimatedSearchArrow(
                                              palette,
                                            ),
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
                              maxHeight: 44,
                            ),
                            border: InputBorder.none,
                            isDense: true, // VERY IMPORTANT
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      if (showSearchSuggestions)
                        _buildSearchSuggestionsPanel(
                          palette,
                          searchSuggestions,
                        ),
                      SizedBox(height: headerGap),
                      _buildScrollCollapsingChild(
                        expandedHeight: commerceStripHeight,
                        translateY: -12,
                        child: _buildCommerceHeroStrip(palette),
                      ),
                      SizedBox(height: commerceToCategoryGap * (1 - collapse)),
                      _buildTopCategoryNavigation(
                        _defaultTopCategoryNavigation(),
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
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: palette.accent.withOpacity(0.78),
                      width: 1.8,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [palette.surfaceStrong, palette.surface],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: palette.accent.withOpacity(0.16),
                        blurRadius: 18,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Color(0x4D000000),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    child: CarouselSlider(
                      carouselController: _bannerController,
                      options: CarouselOptions(
                        height: 220,
                        autoPlay: autoPlayBanners,
                        enlargeCenterPage: false,
                        viewportFraction: 1.0,
                        autoPlayInterval: const Duration(seconds: 4),
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
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: HomeBannerMediaCard(
                                    item: item,
                                    onVideoStarted: item.isVideo
                                        ? () {
                                            if (!mounted) return;
                                            if (_currentBannerIndex >= 0 &&
                                                _currentBannerIndex <
                                                    _bannerItems.length &&
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
                                            _bannerController.nextPage();
                                          }
                                        : null,
                                  ),
                                ),
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.white.withOpacity(0.06),
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.10),
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
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),

        // ✅ Glassmorphism Offer Bar
        if (!isOfferLoading && offerText.isNotEmpty)
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
                    return _buildSaleButtons();
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
                  sectionWidgets.add(_buildSaleButtons());

                  if (topBrandCategories.isNotEmpty) {
                    sectionWidgets.add(
                      Padding(
                        key: _topBrandsSectionKey,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: _buildAnimatedHeading(
                          "TOP BRANDS",
                          fontSize: 16,
                        ),
                      ),
                    );
                    sectionWidgets.add(
                      _buildTopBrandsAutoCarousel(topBrandCategories),
                    );
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
                          child: _buildAnimatedHeading(
                            "SELECT YOUR MOTORCYCLE",
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  );

                  sectionWidgets.addAll(
                    groupedData.entries.map((entry) {
                      final visible = entry.value.whereType<Map>().toList();

                      if (visible.isEmpty) {
                        return const SizedBox();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          _buildCategoryScroller(visible),
                        ],
                      );
                    }),
                  );

                  return Column(children: sectionWidgets);
                },
              ),
            ],
          ),
        ),

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

        SliverToBoxAdapter(child: _buildBikeGarageSection()),

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
    );
  }

  Widget _buildNoInternetBanner() {
    final palette = context.appPalette;
    final backgroundColor = palette.isLight
        ? palette.highlight.withOpacity(0.16)
        : palette.highlight.withOpacity(0.18);
    final borderColor = palette.isLight
        ? palette.highlight.withOpacity(0.75)
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
                color: palette.highlight,
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
            valueColor: AlwaysStoppedAnimation<Color>(palette.highlight),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleButtons() {
    final palette = context.appPalette;
    final saleCards = <Widget>[
      _DailySaleCountdownCard(
        isEnabled: _dailySaleEnabled,
        height: _saleCardHeight,
        colors: _themeSaleCardColors(palette, 0),
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
      _buildSaleButton(
        title: "Big Days Sale",
        subtitle: _bigDaysSaleEnabled ? "Event deals" : "Currently disabled",
        icon: Icons.local_fire_department_rounded,
        colors: _themeSaleCardColors(palette, 1),
        isEnabled: _bigDaysSaleEnabled,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SaleProductsScreen(
                collectionKey: "big_days_sale",
                title: "Big Days Sale",
              ),
            ),
          );
        },
      ),
      _buildSaleButton(
        title: "Track your parcel",
        subtitle: "Open parcel tracking",
        icon: Icons.local_shipping_rounded,
        colors: _themeSaleCardColors(palette, 2),
        isEnabled: true,
        titleFontSize: 12.5,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TrackingWebViewScreen()),
          );
        },
      ),
      _buildSaleButton(
        title: "Motorcycle Service Station",
        subtitle: "Book bike service packages",
        icon: Icons.miscellaneous_services_rounded,
        colors: _themeSaleCardColors(palette, 3),
        isEnabled: true,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const MotorcycleServiceStationScreen(),
            ),
          );
        },
      ),
    ];

    Widget saleRow(int startIndex) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: _saleCardHeight,
              child: saleCards[startIndex],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: _saleCardHeight,
              child: saleCards[startIndex + 1],
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [saleRow(0), const SizedBox(height: 10), saleRow(2)],
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

  Widget _buildHeroBadge({
    required AppThemePalette palette,
    required IconData icon,
    required String title,
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
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: palette.onAccent),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.onAccent,
                      fontSize: 10.5,
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

  Widget _buildSaleButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required bool isEnabled,
    required VoidCallback onTap,
    double titleFontSize = 11.5,
  }) {
    final palette = context.appPalette;
    final activeColors = colors.length >= 2
        ? colors
        : [palette.accentStrong, palette.highlight];
    final disabledColors = [palette.surfaceSoft, palette.surfaceStrong];
    final cardColors = isEnabled ? activeColors : disabledColors;
    final titleSize = title.length > 22 ? 11.8 : titleFontSize + 1.2;
    final activeTextColor = cardColors.first.computeLuminance() > 0.45
        ? Colors.black
        : Colors.white;
    final titleColor = isEnabled ? activeTextColor : palette.textMuted;
    final subtitleColor = isEnabled
        ? activeTextColor.withOpacity(
            activeTextColor == Colors.black ? 0.72 : 0.84,
          )
        : palette.textMuted;
    final badgeColor = isEnabled
        ? activeTextColor.withOpacity(0.90)
        : palette.surfaceSoft;
    final badgeIconColor = isEnabled
        ? (activeTextColor == Colors.black ? Colors.white : cardColors.first)
        : palette.textMuted;

    return SizedBox(
      height: _saleCardHeight,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: cardColors,
            ),
            border: Border.all(
              color: isEnabled
                  ? Colors.white.withOpacity(0.24)
                  : palette.border.withOpacity(0.70),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: cardColors.first.withOpacity(isEnabled ? 0.26 : 0.08),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: palette.accent.withOpacity(0.32),
                        ),
                      ),
                      child: Icon(
                        isEnabled ? icon : Icons.lock_rounded,
                        color: badgeIconColor,
                        size: 17,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: titleSize - 0.4,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 9.5,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isEnabled)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      "OFF",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailySaleCountdownCard extends StatefulWidget {
  const _DailySaleCountdownCard({
    required this.isEnabled,
    required this.height,
    required this.colors,
    required this.onTap,
  });

  final bool isEnabled;
  final double height;
  final List<Color> colors;
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
      setState(() {
        _clock = DateTime.now();
      });
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

  bool get _isLive {
    return !_clock.isBefore(_dailySaleStart(_clock)) &&
        _clock.isBefore(_dailySaleEnd(_clock));
  }

  Duration _countdownDuration() {
    final todayStart = _dailySaleStart(_clock);
    final todayEnd = _dailySaleEnd(_clock);
    if (_clock.isBefore(todayStart)) {
      return todayStart.difference(_clock);
    }
    if (_clock.isBefore(todayEnd)) {
      return todayEnd.difference(_clock);
    }
    return todayStart.add(const Duration(days: 1)).difference(_clock);
  }

  String _formatCountdown(Duration duration) {
    final safeDuration = duration.isNegative ? Duration.zero : duration;
    final hours = safeDuration.inHours;
    final minutes = safeDuration.inMinutes.remainder(60);
    final seconds = safeDuration.inSeconds.remainder(60);
    String twoDigits(int value) => value.toString().padLeft(2, "0");
    return "${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}";
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final activeColors = widget.colors.length >= 2
        ? widget.colors
        : [palette.accentStrong, palette.highlight];
    final disabledColors = [palette.surfaceSoft, palette.surfaceStrong];
    final isAdminEnabled = widget.isEnabled;
    final isLive = isAdminEnabled && _isLive;
    final cardColors = isLive ? activeColors : disabledColors;
    final baseTextColor = cardColors.first.computeLuminance() > 0.45
        ? Colors.black
        : Colors.white;
    final textColor = isLive ? baseTextColor : palette.textMuted;
    final mutedColor = isLive
        ? baseTextColor.withOpacity(baseTextColor == Colors.black ? 0.72 : 0.84)
        : palette.textMuted;
    final countdownLabel = isLive ? "Ends in" : "Starts in";
    final countdownText = _formatCountdown(_countdownDuration());

    return SizedBox(
      height: widget.height,
      child: InkWell(
        onTap: isLive ? widget.onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: cardColors,
            ),
            border: Border.all(
              color: isLive
                  ? Colors.white.withOpacity(0.26)
                  : palette.border.withOpacity(0.70),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: cardColors.first.withOpacity(isLive ? 0.28 : 0.08),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, color: textColor, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        "Daily Sale",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12.2,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    isLive ? "50% OFF" : "CLOSED",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAdminEnabled ? countdownLabel : "Currently disabled",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: mutedColor,
                      fontSize: 9,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(
                        baseTextColor == Colors.black ? 0.10 : 0.22,
                      ),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(0.22)),
                    ),
                    child: Text(
                      isAdminEnabled ? countdownText : "--:--:--",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        height: 1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w900,
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
