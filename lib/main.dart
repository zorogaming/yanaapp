import 'dart:io';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'providers/cart_provider.dart';
import 'providers/wishlist_provider.dart';
import 'services/analytics_service.dart';
import 'services/auth_service.dart';
import 'services/admin_service.dart';
import 'services/app_sound_service.dart';
import 'services/coupon_service.dart';
import 'services/notification_inbox_service.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'This channel is used for important notifications.',
  importance: Importance.max,
  playSound: true,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

bool _localNotificationsInitialized = false;

Future<void> _ensureLocalNotificationsInitialized() async {
  if (_localNotificationsInitialized) return;

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher_v2');
  const DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  _localNotificationsInitialized = true;
}

Future<void> _showLocalNotification(RemoteMessage message) async {
  final RemoteNotification? notification = message.notification;
  final title =
      notification?.title ??
      (message.data['title']?.toString().trim().isNotEmpty == true
          ? message.data['title'].toString()
          : 'New update');
  final body =
      notification?.body ??
      (message.data['body']?.toString().trim().isNotEmpty == true
          ? message.data['body'].toString()
          : 'You have a new message.');

  await _ensureLocalNotificationsInitialized();
  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        icon: '@mipmap/ic_launcher_v2',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
  );
}

Future<void> _captureCouponFromMessage(RemoteMessage message) async {
  try {
    if (message.data.isEmpty) return;
    await CouponService.instance.captureFromNotificationData(message.data);
  } catch (_) {
    // Coupon capture must not block notification flow.
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationInboxService.instance.captureFromRemoteMessage(
    message,
    source: 'background',
  );
  await _captureCouponFromMessage(message);
  await _showLocalNotification(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await _ensureLocalNotificationsInitialized();
  final themeController = AppThemeController();
  await themeController.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeController),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _updateDialogShown = false;
  bool _adminUpdateDialogShown = false;
  Timer? _adminUpdatePollTimer;
  DateTime? _lastAdminUpdateCheckAt;
  bool _isCheckingAdminUpdate = false;
  static const String _androidPackageName = "com.yanaworldwide.shop";
  static const String _acceptedUpdateCampaignKey =
      "accepted_update_notice_campaign_id";
  String? _currentAppVersion;
  static const Duration _adminUpdateCheckCooldown = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrapTelemetry();
    _setupFCM();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkForAppUpdate();
      await _checkForAdminTriggeredUpdate(force: true);
    });
    _scheduleNextAdminUpdateCheck();
  }

  @override
  void dispose() {
    _adminUpdatePollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AnalyticsService.instance.logAppLifecycle(
        eventName: "app_foreground",
        page: "app",
      );
      _checkForAppUpdate();
      _checkForAdminTriggeredUpdate(force: true);
      _scheduleNextAdminUpdateCheck();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      AnalyticsService.instance.logAppLifecycle(
        eventName: "app_background",
        page: "app",
      );
    }
  }

  Future<void> _bootstrapTelemetry() async {
    final userId = await AuthService().getUserId();
    final packageInfo = await PackageInfo.fromPlatform();
    _currentAppVersion = _composeAppVersion(
      packageInfo.version,
      packageInfo.buildNumber,
    );
    await AnalyticsService.instance.setAppVersion(_currentAppVersion ?? "");
    await AnalyticsService.instance.initIdentity(userId: userId);
    await AnalyticsService.instance.logAppLifecycle(
      eventName: "app_open",
      page: "app_open",
    );
    await AnalyticsService.instance.logScreen("app_open");
  }

  Future<void> _checkForAppUpdate() async {
    if (!Platform.isAndroid || !mounted || _updateDialogShown) return;

    try {
      final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();
      final hasUpdate =
          updateInfo.updateAvailability == UpdateAvailability.updateAvailable;
      if (!hasUpdate || !mounted) return;

      final started = await _startGoogleUpdateFlow(
        updateInfo,
        preferImmediate: false,
      );
      if (started || !mounted) return;

      _updateDialogShown = true;
      await _showPlayStoreFallbackDialog(
        title: 'Update Available',
        message:
            'New app version available on Play Store. Please update the app.',
        forceUpdate: false,
      );
    } catch (_) {
      // Ignore failures for unsupported environments (debug/sideload/non-PlayStore).
    }
  }

  void _scheduleNextAdminUpdateCheck() {
    _adminUpdatePollTimer?.cancel();
    if (_adminUpdateDialogShown) return;
    _adminUpdatePollTimer = Timer(_adminUpdateCheckCooldown, () {
      _checkForAdminTriggeredUpdate();
    });
  }

  Future<bool> _startGoogleUpdateFlow(
    AppUpdateInfo updateInfo, {
    required bool preferImmediate,
  }) async {
    try {
      if (preferImmediate && updateInfo.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return true;
      }

      if (!preferImmediate && updateInfo.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
        return true;
      }

      if (updateInfo.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return true;
      }

      if (updateInfo.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openPlayStoreListing() async {
    final marketUri = Uri.parse("market://details?id=$_androidPackageName");
    final webUri = Uri.parse(
      "https://play.google.com/store/apps/details?id=$_androidPackageName",
    );

    if (await canLaunchUrl(marketUri)) {
      await launchUrl(marketUri, mode: LaunchMode.externalApplication);
      return;
    }

    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _checkForAdminTriggeredUpdate({bool force = false}) async {
    if (!Platform.isAndroid || !mounted || _adminUpdateDialogShown) return;
    if (_isCheckingAdminUpdate) return;

    final now = DateTime.now();
    if (!force &&
        _lastAdminUpdateCheckAt != null &&
        now.difference(_lastAdminUpdateCheckAt!) < _adminUpdateCheckCooldown) {
      _scheduleNextAdminUpdateCheck();
      return;
    }

    _isCheckingAdminUpdate = true;
    _lastAdminUpdateCheckAt = now;
    try {
      final data = await AdminService().getPublicAppUpdateStatus();
      if (data["ok"] != true || data["active"] != true) {
        _scheduleNextAdminUpdateCheck();
        return;
      }

      final campaignId =
          int.tryParse((data["campaign_id"] ?? "0").toString()) ?? 0;
      if (campaignId <= 0) return;

      final currentVersion = await _getCurrentAppVersion();
      final minVersion = (data["min_version"] ?? "").toString().trim();
      final latestVersion = (data["latest_version"] ?? "").toString().trim();
      final requiredVersion =
          minVersion.isNotEmpty
              ? minVersion
              : (latestVersion.isNotEmpty ? latestVersion : "");
      final forceUpdate = data["force_update"] == true;
      if (requiredVersion.isNotEmpty &&
          _compareVersions(currentVersion, requiredVersion) >= 0) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final acceptedCampaignId = prefs.getInt(_acceptedUpdateCampaignKey) ?? 0;
      if (requiredVersion.isEmpty && acceptedCampaignId == campaignId) {
        return;
      }

      Future<void> markUpdatePopupHandled() async {
        if (requiredVersion.isEmpty) {
          await prefs.setInt(_acceptedUpdateCampaignKey, campaignId);
        }
      }

      _adminUpdateDialogShown = true;
      final title = (data["title"] ?? "Update Available").toString().trim();
      final message = (data["message"] ??
              "A new app version is available. Please update the app.")
          .toString()
          .trim();
      final url = (data["url"] ?? "").toString().trim();

      final AppUpdateInfo? updateInfo = await _getPlayStoreUpdateInfo();
      if (updateInfo != null) {
        final started = await _startGoogleUpdateFlow(
          updateInfo,
          preferImmediate: forceUpdate,
        );
        if (started) {
          await markUpdatePopupHandled();
          return;
        }
      }

      _adminUpdateDialogShown = true;
      await _showPlayStoreFallbackDialog(
        title: title.isEmpty ? "Update Available" : title,
        message: _buildUpdateMessage(
          baseMessage:
              message.isEmpty
                  ? "A new app version is available. Please update the app."
                  : message,
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          minVersion: minVersion,
          forceUpdate: forceUpdate,
        ),
        forceUpdate: forceUpdate,
        onCancel: markUpdatePopupHandled,
        onUpdate: () async {
          await markUpdatePopupHandled();
          await _openUrlOrPlayStore(url);
        },
      );
    } catch (_) {
      // Ignore API/network failures for update notice.
    } finally {
      _isCheckingAdminUpdate = false;
      if (mounted && !_adminUpdateDialogShown) {
        _scheduleNextAdminUpdateCheck();
      }
    }
  }

  Future<void> _openUrlOrPlayStore(String rawUrl) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isNotEmpty) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    await _openPlayStoreListing();
  }

  Future<AppUpdateInfo?> _getPlayStoreUpdateInfo() async {
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      final hasUpdate =
          updateInfo.updateAvailability == UpdateAvailability.updateAvailable;
      return hasUpdate ? updateInfo : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _showPlayStoreFallbackDialog({
    required String title,
    required String message,
    required bool forceUpdate,
    Future<void> Function()? onCancel,
    Future<void> Function()? onUpdate,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () async {
                  if (onCancel != null) {
                    await onCancel();
                  }
                  if (!mounted) return;
                  Navigator.of(context).pop();
                },
                child: const Text("Cancel"),
              )
            else
              TextButton(
                onPressed: () => SystemNavigator.pop(),
                child: const Text('Exit App'),
              ),
            ElevatedButton(
              onPressed: () async {
                if (onUpdate != null) {
                  await onUpdate();
                } else {
                  await _openPlayStoreListing();
                }
                if (!mounted) return;
                Navigator.of(context).pop();
              },
              child: Text(forceUpdate ? "Update Now" : "Open Play Store"),
            ),
          ],
        );
      },
    );
  }

  Future<String> _getCurrentAppVersion() async {
    if (_currentAppVersion != null && _currentAppVersion!.isNotEmpty) {
      return _currentAppVersion!;
    }
    final packageInfo = await PackageInfo.fromPlatform();
    _currentAppVersion = _composeAppVersion(
      packageInfo.version,
      packageInfo.buildNumber,
    );
    return _currentAppVersion ?? "";
  }

  int _compareVersions(String left, String right) {
    List<int> parseVersion(String input) {
      final normalized = input.trim();
      return normalized
          .replaceAll('+', '.')
          .split('.')
          .map((part) => int.tryParse(part.trim()) ?? 0)
          .toList();
    }

    final a = parseVersion(left);
    final b = parseVersion(right);
    final maxLength = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < maxLength; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av != bv) {
        return av.compareTo(bv);
      }
    }
    return 0;
  }

  String _composeAppVersion(String version, String buildNumber) {
    final cleanVersion = version.trim();
    final cleanBuild = buildNumber.trim();
    if (cleanVersion.isEmpty) return cleanBuild;
    if (cleanBuild.isEmpty) return cleanVersion;
    return "$cleanVersion+$cleanBuild";
  }

  String _buildUpdateMessage({
    required String baseMessage,
    required String currentVersion,
    required String latestVersion,
    required String minVersion,
    required bool forceUpdate,
  }) {
    final parts = <String>[baseMessage];
    if (currentVersion.isNotEmpty) {
      parts.add("Current version: $currentVersion");
    }
    if (latestVersion.isNotEmpty) {
      parts.add("Latest version: $latestVersion");
    }
    if (minVersion.isNotEmpty) {
      parts.add("Minimum required version: $minVersion");
    }
    if (forceUpdate) {
      parts.add("Ye update required hai.");
    }
    return parts.join("\n\n");
  }

  Future<void> _setupFCM() async {
    final FirebaseMessaging messaging = FirebaseMessaging.instance;

    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('FCM permission: ${settings.authorizationStatus}');

    final token = await messaging.getToken();
    print('FCM token: $token');
    final currentVersion = await _getCurrentAppVersion();
    await AnalyticsService.instance.setAppVersion(currentVersion);
    if (token != null && token.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("fcm_token", token);
      await AnalyticsService.instance.registerPushToken(
        token: token,
        platform: Platform.isIOS ? "ios" : "android",
      );
    }
    messaging.onTokenRefresh.listen((newToken) {
      print('FCM token refreshed: $newToken');
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString("fcm_token", newToken);
      });
      AnalyticsService.instance.registerPushToken(
        token: newToken,
        platform: Platform.isIOS ? "ios" : "android",
      );
    });
    await AuthService().syncFcmTopicForCurrentUser();

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      NotificationInboxService.instance.captureFromRemoteMessage(
        message,
        source: 'foreground',
      );
      _captureCouponFromMessage(message);
      AppSoundService.instance.playNotificationSound();
      _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      NotificationInboxService.instance.captureFromRemoteMessage(
        message,
        source: 'opened_app',
      );
      _captureCouponFromMessage(message);
      print("Notification clicked. Data: ${message.data}");
    });

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      await NotificationInboxService.instance.captureFromRemoteMessage(
        initialMessage,
        source: 'initial_message',
      );
      await _captureCouponFromMessage(initialMessage);
      print("Opened from terminated notification. Data: ${initialMessage.data}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppThemeController>(
      builder: (context, themeController, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: "Yanaworldwide Store",
          theme: AppThemes.themeDataFor(themeController.mode),
          themeAnimationDuration: const Duration(milliseconds: 260),
          routes: {
            ForgotPasswordScreen.routeName: (_) =>
                const ForgotPasswordScreen(),
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}
