import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import 'package:marquee/marquee.dart';
import 'package:http/http.dart' as http;
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
  })  : type = _HomeBannerMediaType.video,
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

      video.style.position = 'fixed';
      video.style.inset = '0';
      video.style.width = '100vw';
      video.style.height = '100vh';
      video.style.objectFit = 'cover';
      video.style.background = '#000';
      video.style.zIndex = '2147483647';
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
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const String _themePromptCompletedKey = "theme_prompt_completed_v1";
  static const String _imageCacheKey = "home_banner_image_txt_cache";
  static const String _imageCacheVersionKey = "home_banner_image_txt_version";
  static const String _videoCacheKey = "home_banner_video_txt_cache";
  static const String _videoCacheVersionKey = "home_banner_video_txt_version";
  static const String _seenHomePopupCampaignsKey =
      "seen_home_popup_campaign_ids";
  static String _lastHandledPopupSignature = "";
  static bool _hasCheckedHomePopupThisSession = false;
  static const int _homeBannerCacheWidth = 1280;
  static const int _homeProductImageCacheWidth = 720;
  static const int _homeCategoryImageCacheWidth = 240;
  final CarouselSliderController _bannerController = CarouselSliderController();
  late final Future<_HomeCategorySectionData> _categorySectionFuture;
  late Future<Map<String, dynamic>> _bikeGarageFuture;
  late Future<String?> _authTokenFuture;
  late final AnimationController _titleAnimController;
  late final AnimationController _cartPulseController;
  late final AnimationController _searchCtaController;
  String currentSearch = "";
  String offerText = "";
  bool isOfferLoading = true;
  int _currentBannerIndex = 0;

  static const List<String> _defaultBannerImageUrls = [
    "https://yanaworldwide.store/wp-content/uploads/slider-1.jpg",
    "https://yanaworldwide.store/wp-content/uploads/slider-2.jpg",
    "https://yanaworldwide.store/wp-content/uploads/slider-3.jpg",
  ];

  final List<HomeBannerMedia> _bannerItems = [
    HomeBannerMedia.image(
      _defaultBannerImageUrls[0],
    ),
    HomeBannerMedia.image(
      _defaultBannerImageUrls[1],
    ),
    HomeBannerMedia.image(
      _defaultBannerImageUrls[2],
    ),
  ];

  final WooService api = WooService();
  final DataManager dataManager = DataManager();

  final ScrollController _scrollController = ScrollController();
  final TextEditingController searchController = TextEditingController();

  List<Product> products = [];
  bool isLoading = false;
  bool isInitialLoading = true;
  bool _hasInternet = true;
  bool _internetStatusKnown = false;
  bool _isCheckingInternet = false;
  int _internetFailureCount = 0;
  bool _homePopupDialogShown = false;
  bool _themeChooserShown = false;
  bool _dailySaleEnabled = true;
  bool _bigDaysSaleEnabled = true;
  bool _quickAccessExpanded = false;
  final GlobalKey _quickAccessRailKey = GlobalKey();
  final GlobalKey _cartIconKey = GlobalKey();
  final GlobalKey _searchBoxKey = GlobalKey();

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
    AnalyticsService.instance.logScreen("home");
    _categorySectionFuture = _loadHomeCategorySection();
    _bikeGarageFuture = _loadBikeGarageData();
    _authTokenFuture = AuthService().getToken();
    _loadSaleAvailability();
    loadOffer();
    _loadBannerImages();
    _loadBannerVideos();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForHomePopup();
      _warmBannerImages();
    });

    isInitialLoading = true;
    fetchProductsFromServer();
    _refreshInternetStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshInternetStatus();
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


  Future<void> _warmBannerImages() async {
    if (!mounted) return;
    for (final item in _bannerItems.where((item) => !item.isVideo).take(3)) {
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
    for (final product in items.take(8)) {
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

  void _scheduleInternetRetry() {
    _internetRetryTimer?.cancel();
    _internetRetryTimer = Timer(const Duration(seconds: 30), () {
      _refreshInternetStatus();
    });
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
      _internetFailureCount = 0;
      if (!_internetStatusKnown || !_hasInternet) {
        setState(() {
          _internetStatusKnown = true;
          _hasInternet = true;
        });
      }
      _internetRetryTimer?.cancel();
      return;
    }

    _internetFailureCount++;
    if (_internetFailureCount < 2) {
      _scheduleInternetRecheck();
      return;
    }

    if (!_internetStatusKnown || _hasInternet) {
      setState(() {
        _internetStatusKnown = true;
        _hasInternet = false;
      });
    }

    if (!_hasInternet) {
      _scheduleInternetRetry();
    }
  }

  void _refreshAuthToken() {
    setState(() {
      _authTokenFuture = AuthService().getToken();
    });
  }

  Future<void> _loadSaleAvailability() async {
    try {
      final dailyPayload = await dataManager.getSaleCollection("daily_sale");
      final bigDaysPayload = await dataManager.getSaleCollection("big_days_sale");
      if (!mounted) return;
      setState(() {
        _dailySaleEnabled = dailyPayload["enabled"] != false;
        _bigDaysSaleEnabled = bigDaysPayload["enabled"] != false;
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
              scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
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
                              icon: const Icon(Icons.close, color: Colors.white70),
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
    final hasSavedTheme =
        (prefs.getString('selected_app_theme') ?? '').trim().isNotEmpty;
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
        final sheetPalette = Theme.of(sheetContext).extension<AppThemePalette>() ??
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
                  style: TextStyle(
                    color: sheetPalette.textMuted,
                    fontSize: 13,
                  ),
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
                              colors: [optionPalette.heroStart, optionPalette.heroEnd],
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

  Widget _buildThemeDot(Color color) {
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Future<void> fetchProductsFromServer({
    bool loadMore = false,
    String? searchQuery,
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
            ))
              .items
          : await dataManager.getHomeProducts(
              page: 1,
              search: null,
            );

      final parsedProducts =
          data.map<Product>((e) => Product.fromJson(e)).toList();
      final newProducts =
          parsedProducts.where((product) => _isValidHomeProduct(product)).toList();

      if (mounted) {
        setState(() {
          products = newProducts;

          isLoading = false;
          isInitialLoading = false;
        });
        unawaited(_warmProductImages(newProducts));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeShowInitialThemeChooser();
        });
      }
    } catch (e) {
      print("Error fetching products: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
          isInitialLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeShowInitialThemeChooser();
        });
      }
    }
  }

  bool _isValidHomeProduct(Product product) {
    final image = product.image.trim();
    final hasValidImage = image.isNotEmpty && image.toLowerCase().startsWith("http");

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
    _debounce = Timer(
      Duration(milliseconds: debounceMs),
      () {
        fetchProductsFromServer(
          searchQuery: trimmed.isEmpty ? null : trimmed,
        );
      },
    );
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
        final scale = hasQuery ? 1 + (0.10 * t) : 1.0;
        final shift = hasQuery ? 1 + (4 * t) : 0.0;
        final glowOpacity = hasQuery ? 0.20 + (0.16 * t) : 0.0;
        final ringOpacity = hasQuery ? 0.22 - (0.10 * t) : 0.0;

        return Transform.translate(
          offset: Offset(shift, 0),
          child: Transform.scale(
            scale: scale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (hasQuery)
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: palette.accent.withOpacity(ringOpacity),
                        width: 2,
                      ),
                    ),
                  ),
                Container(
                  width: 32,
                  height: 32,
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
                          : [
                              palette.accent,
                              palette.accent,
                            ],
                    ),
                    borderRadius: BorderRadius.circular(11),
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
                            size: 22,
                          ),
                        ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: palette.onAccent,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    final endBox = _searchBoxKey.currentContext?.findRenderObject() as RenderBox?;
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
        final opacity =
            t < 0.9 ? 1.0 : (1.0 - ((t - 0.9) / 0.1)).clamp(0.0, 1.0);
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
    final currentVersion = (await api.fetchAppVersion())?.trim() ?? "";
    final cachedVersion = (prefs.getString(_videoCacheVersionKey) ?? "").trim();
    final cachedRaw = prefs.getString(_videoCacheKey) ?? "";

    if (cachedRaw.isNotEmpty && currentVersion.isNotEmpty && cachedVersion == currentVersion) {
      final cachedItems = _parseVideoLinks(cachedRaw);
      if (cachedItems.isNotEmpty && mounted) {
        setState(() {
          _replaceVideoBanners(cachedItems);
        });
      }
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
    final rawProducts = await dataManager.getSuggestedProductsForBike(selectedBike);
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
                      selectedBike.isEmpty ? "Bike Garage" : "For Your Bike: $selectedBike",
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
                        MaterialPageRoute(builder: (_) => const BikeGarageScreen()),
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
                              builder: (_) => ProductDetailScreen(product: product),
                            ),
                          );
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
                                    maxWidthDiskCache: _homeProductImageCacheWidth,
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
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                          ),
                                        if (product.discountPercent > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: primaryRed,
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              "${product.discountPercent}% OFF",
                                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
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
      items.add(
        HomeBannerMedia.video(
          sourceUrl: value,
          youtubeId: youtubeId,
        ),
      );
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
        if ((first == "embed" || first == "shorts") && uri.pathSegments.length > 1) {
          return uri.pathSegments[1].trim();
        }
      }
    }

    return null;
  }

  String _normalizeCategoryName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9]+"), " ")
        .trim();
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
                            color: isWhiteTheme ? palette.border : palette.accent,
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
    _titleAnimController.dispose();
    _cartPulseController.dispose();
    _searchCtaController.dispose();
    _scrollController.dispose();
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
    final endBox = _cartIconKey.currentContext?.findRenderObject() as RenderBox?;
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
        final dx = (lerpDouble(start.dx, end.dx, t) ?? end.dx) +
            (math.sin(t * math.pi * 1.15) * 14 * (1 - t));
        final dy = (lerpDouble(start.dy, end.dy, t) ?? end.dy) -
            (math.sin(t * math.pi) * 138) -
            (squeezeProgress * 6);
        final opacity =
            t < 0.9 ? 1.0 : (1.0 - ((t - 0.9) / 0.1)).clamp(0.0, 1.0);
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
                            border: Border.all(color: palette.surface, width: 1.5),
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
    }

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final response = await http
          .get(Uri.parse("https://yanaworldwide.store/Yanaapp/banner.txt?v=$now"))
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

  List<Color> _promoCardColors(
    AppThemePalette palette, {
    required List<Color> defaultColors,
  }) {
    if (palette.id == AppThemes.whitePalette.id) {
      return <Color>[palette.accent, palette.highlight];
    }
    return defaultColors;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(208),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [palette.heroStart, palette.heroEnd, palette.background],
              begin: Alignment.topLeft,
              end: Alignment.bottomCenter,
            ),
          ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      color: palette.surface,
                      border: Border.all(color: palette.border.withOpacity(0.7)),
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: palette.isLight ? 12 : 0,
                        vertical: palette.isLight ? 6 : 0,
                      ),
                      decoration: BoxDecoration(
                        color:
                            palette.isLight
                                ? const Color(0xFF121212)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Image.asset(
                        "assets/icon/icon.png",
                        height: 30,
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
                          if (!snapshot.hasData || snapshot.data == null) {
                            return Row(
                              children: [
                                IconButton(
                                  tooltip: "Wallet",
                                  icon: Icon(
                                    Icons.account_balance_wallet_outlined,
                                    color: palette.accent,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const WalletScreen(),
                                      ),
                                    );
                                  },
                                  constraints: const BoxConstraints(
                                    minHeight: 34,
                                    minWidth: 34,
                                  ),
                                  padding: const EdgeInsets.all(5),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LoginScreen(),
                                      ),
                                    ).then((_) => _refreshAuthToken());
                                  },
                                  child: Text(
                                    "Login",
                                    style: TextStyle(
                                      color: palette.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Text(
                                  "|",
                                  style: TextStyle(color: palette.textMuted),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                  onPressed: () {
                                    // ✅ STEP 3: Implement Signup Screen Navigation
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SignupScreen(),
                                      ),
                                    ).then((_) => _refreshAuthToken());
                                  },
                                  child: Text(
                                    "Signup",
                                    style: TextStyle(
                                      color: palette.accent,
                                      fontWeight: FontWeight.w800,
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
                                  Icons.account_balance_wallet_outlined,
                                  color: palette.accent,
                                  size: 20,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const WalletScreen(),
                                    ),
                                  );
                                },
                                constraints: const BoxConstraints(
                                  minHeight: 34,
                                  minWidth: 34,
                                ),
                                padding: const EdgeInsets.all(5),
                              ),
                              FutureBuilder<bool>(
                                future: AuthService().isPrivilegedAdmin(),
                                builder: (context, adminSnapshot) {
                                  if (adminSnapshot.data != true) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: TextButton.icon(
                                      style: TextButton.styleFrom(
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                        backgroundColor:
                                            palette.accent.withOpacity(0.14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          side: BorderSide(
                                             color: palette.accent.withOpacity(0.35),
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
                                        Icons.admin_panel_settings_outlined,
                                        color: palette.accent,
                                        size: 16,
                                      ),
                                      label: Text(
                                        "Admin",
                                        style: TextStyle(
                                          color: palette.accent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
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
                                      builder: (_) => const ProfileScreen(),
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
                                  animation: _cartPulseController,
                                  builder: (context, child) {
                                    final progress = Curves.elasticOut.transform(
                                      _cartPulseController.value.clamp(0.0, 1.0),
                                    );
                                    final scale = 1 + (0.24 * progress);
                                    final rotation =
                                        math.sin(progress * math.pi * 4) *
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
                                      builder: (_) => const CartScreen(),
                                    ),
                                  );
                                },
                              ),
                              if (cart.items.isNotEmpty)
                                Positioned(
                                  right: 5,
                                  top: 5,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: palette.accent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      cart.items.length.toString(),
                                      style: TextStyle(
                                        color: palette.onAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
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
              const SizedBox(height: 12),
              Container(
                key: _searchBoxKey,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: palette.border),
                  color: palette.surface,
                ),
                child: TextField(
                  controller: searchController,
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
                    suffixIcon: IconButton(
                      icon: _buildAnimatedSearchArrow(palette),
                      onPressed: _goToSearch,
                    ),
                    border: InputBorder.none,
                    isDense: true, // VERY IMPORTANT
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildCommerceHeroStrip(palette),
            ],
          ),
        ),
      ),
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if (!_quickAccessExpanded) return;
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
            _buildQuickAccessRail(),
            if (_internetStatusKnown && !_hasInternet)
              Positioned(
                top: 10,
                left: 12,
                right: 12,
                child: _buildNoInternetBanner(),
              ),
          ],
        ),
      ),
      // ✅ WHATSAPP BUTTON (Correct Position)
      floatingActionButton: FloatingActionButton(
        onPressed: openWhatsApp,
        backgroundColor: palette.accent,
        foregroundColor: palette.onAccent,
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
                color: palette.onAccent,
              ),
              Positioned(
                top: 7,
                child: Icon(
                  Icons.call_rounded,
                  size: 12,
                  color: palette.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildMainContent() {
    final palette = context.appPalette;
    final currentBanner = _bannerItems.isNotEmpty &&
            _currentBannerIndex >= 0 &&
            _currentBannerIndex < _bannerItems.length
        ? _bannerItems[_currentBannerIndex]
        : null;
    final autoPlayBanners = currentBanner == null ? true : !currentBanner.isVideo;

    return CustomScrollView(
      controller: _scrollController,
      cacheExtent: 900,
      slivers: [
        /// 1. Top Section (Banner)
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.accent.withOpacity(0.78), width: 1.8),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        palette.surfaceStrong,
                        palette.surface,
                      ],
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
                                                _currentBannerIndex < _bannerItems.length &&
                                                identical(_bannerItems[_currentBannerIndex], item)) {
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
              const SizedBox(height: 16),
            ],
          ),
        ),

        // ✅ Glassmorphism Offer Bar
        if (!isOfferLoading && offerText.isNotEmpty)
          SliverToBoxAdapter(
            child: Builder(
              builder: (context) {
                final offerLink = _extractOfferLink(offerText);
                return Container(
                  height: 44,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                );
              },
            ),
          ),

        // --- Categories ---
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
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
                      _buildCategoryScroller(topBrandCategories),
                    );
                  }

                  sectionWidgets.add(
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                      child: Center(
                        child: _buildAnimatedHeading(
                          "SELECT YOUR MOTORCYCLE",
                          fontSize: 18,
                        ),
                      ),
                    ),
                  );

                  sectionWidgets.addAll(
                    groupedData.entries.map((entry) {
                      final visible = entry.value.where((raw) {
                        return raw is Map;
                      }).toList();

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
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildAIBrainCard(),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildRideCommunityCard(),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildRidingEventsCard(),
              ),
              const SizedBox(height: 20),
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

        SliverToBoxAdapter(
          child: _buildBikeGarageSection(),
        ),

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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                childCount: (isInitialLoading && products.isEmpty) ? 6 : products.length,
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
              Icon(Icons.wifi_off_rounded, color: palette.highlight, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "No Internet Connection",
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSaleButton(
                  title: "Daily Sale",
                  subtitle: _dailySaleEnabled ? "Today picks" : "Currently disabled",
                  icon: Icons.bolt_rounded,
                  colors: const [Color(0xFFFF7A18), Color(0xFFFFB347)],
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
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSaleButton(
                  title: "Big Days Sale",
                  subtitle: _bigDaysSaleEnabled ? "Event deals" : "Currently disabled",
                  icon: Icons.local_fire_department_rounded,
                  colors: const [Color(0xFFE53935), Color(0xFFFF7043)],
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
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSaleButton(
                  title: "Track your parcel",
                  subtitle: "Open parcel tracking",
                  icon: Icons.local_shipping_rounded,
                  colors: _promoCardColors(
                    context.appPalette,
                    defaultColors: const [Color(0xFF2563EB), Color(0xFF06B6D4)],
                  ),
                  isEnabled: true,
                  titleFontSize: 12.5,
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
              const SizedBox(width: 12),
              Expanded(
                child: _buildSaleButton(
                  title: "Motorcycle Service Station",
                  subtitle: "Book bike service packages",
                  icon: Icons.miscellaneous_services_rounded,
                  colors: _promoCardColors(
                    context.appPalette,
                    defaultColors: const [Color(0xFF0EA5E9), Color(0xFF14B8A6)],
                  ),
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
          );
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
                pageBuilder:
                    (_, __, ___) => ProductDetailScreen(product: product),
                transitionsBuilder: (_, animation, __, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              ),
            );
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
                      (item) => item.id == product.id && item.variationId == null,
                    );

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isInCart ? palette.surfaceStrong : palette.accent,
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
                              color: isInCart ? palette.textPrimary : palette.onAccent,
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
          onTap: (startContext) => _fillSearchFromBadgeAnimated("RCB", startContext),
        ),
        const SizedBox(width: 8),
        _buildHeroBadge(
          palette: palette,
          icon: Icons.flash_on_rounded,
          title: "UMA Racing",
          onTap:
              (startContext) =>
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

  Widget _buildAIBrainCard() {
    final palette = context.appPalette;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AIBrainScreen()),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [palette.heroStart, palette.heroEnd, palette.background],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: palette.textPrimary.withValues(alpha: 0.14),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [palette.accentStrong, palette.highlight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.psychology_alt_rounded,
                    color: palette.onAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "AI Brain Dashboard",
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Smart bike insights, predictive service alerts, and rider intelligence in one place.",
                        style: TextStyle(
                          color: palette.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildAIBrainPill("92% Health Score", 0),
                _buildAIBrainPill("3 Smart Alerts", 1),
                _buildAIBrainPill("Ride AI Active", 2),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: palette.surfaceStrong,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: palette.border),
                      ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Next Action",
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "Brake and chain health review due",
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: palette.accent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Open",
                        style: TextStyle(
                          color: palette.onAccent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: palette.onAccent,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
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
            padding: const EdgeInsets.only(left: 6),
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
                      setState(() => _quickAccessExpanded = !_quickAccessExpanded);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: palette.surfaceSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _quickAccessExpanded
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                        color: palette.accent,
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
                          MaterialPageRoute(builder: (_) => const BikeGarageScreen()),
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
                          MaterialPageRoute(builder: (_) => const AIBrainScreen()),
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

  Widget _buildAIBrainPill(String label, int variant) {
    final palette = context.appPalette;
    final tone = switch (variant % 3) {
      0 => palette.accent,
      1 => palette.highlight,
      _ => palette.accentStrong,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.34)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildRideCommunityCard() {
    final palette = context.appPalette;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RidingGroupsScreen()),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [palette.heroStart, palette.heroEnd, palette.surfaceStrong],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: palette.textPrimary.withValues(alpha: 0.14),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [palette.accent, palette.highlight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.groups_rounded,
                    color: palette.onAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Riding Groups",
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Find city-wise riding groups, join after login, and connect through WhatsApp or the admin contact.",
                        style: TextStyle(
                          color: palette.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildAIBrainPill("City Search", 0),
                _buildAIBrainPill("Join Group", 1),
                _buildAIBrainPill("Rate Groups", 2),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: palette.surfaceStrong,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: palette.border),
                      ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Community Value",
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "Simple discovery, repeat visits, and stronger rider branding",
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: palette.accent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Open",
                        style: TextStyle(
                          color: palette.onAccent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: palette.onAccent,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRidingEventsCard() {
    final palette = context.appPalette;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RideCommunityScreen()),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [palette.heroStart, palette.heroEnd, palette.surfaceStrong],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: palette.textPrimary.withValues(alpha: 0.14),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [palette.highlight, palette.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.route_rounded,
                    color: palette.onAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Riding Events",
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Create ride events, share routes, approve requests, and manage riders from one place.",
                        style: TextStyle(
                          color: palette.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildAIBrainPill("Create Ride", 1),
                _buildAIBrainPill("Join Requests", 2),
                _buildAIBrainPill("Manage Riders", 0),
              ],
            ),
          ],
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        height: 92,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isEnabled ? palette.surface : const Color(0xFF232323),
          border: Border.all(
            color: isEnabled ? palette.accent : Colors.white24,
            width: 1.4,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? palette.accent
                        : Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isEnabled ? icon : Icons.lock_rounded,
                    color: isEnabled ? Colors.black : Colors.white,
                  ),
                ),
                  const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: titleFontSize,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isEnabled ? palette.textMuted : Colors.white60,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!isEnabled)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Text(
                    "OFF",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}



