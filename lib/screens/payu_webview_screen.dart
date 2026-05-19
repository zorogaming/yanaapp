import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PayUWebViewScreen extends StatefulWidget {
  final double amount;
  final String name;
  final String email;
  final String phone;
  final String paymentPagePath;
  final String successPathMatch;
  final String failurePathMatch;
  final String appBarTitle;

  const PayUWebViewScreen({
    super.key,
    required this.amount,
    required this.name,
    required this.email,
    required this.phone,
    this.paymentPagePath = "payu_payment.php",
    this.successPathMatch = "success.php",
    this.failurePathMatch = "failure.php",
    this.appBarTitle = "Secure Payment",
  });

  @override
  State<PayUWebViewScreen> createState() => _PayUWebViewScreenState();
}

class _PayUWebViewScreenState extends State<PayUWebViewScreen> {
  late final WebViewController _controller;

  static const String _upiMissingMessage =
      'No UPI app found. Please install a UPI app and try again.';

  bool _shouldOpenExternally(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme.isEmpty) return false;
    if (scheme == 'http' || scheme == 'https') return false;
    if (scheme == 'about' || scheme == 'data' || scheme == 'javascript') {
      return false;
    }
    return true;
  }

  String? _extractIntentParam(String raw, String key) {
    final marker = '$key=';
    final start = raw.indexOf(marker);
    if (start < 0) return null;
    final valueStart = start + marker.length;
    final end = raw.indexOf(';', valueStart);
    if (end < 0) return raw.substring(valueStart);
    return raw.substring(valueStart, end);
  }

  Uri? _buildUriFromIntentUrl(String raw) {
    if (!raw.toLowerCase().startsWith('intent://')) return null;
    final hashIndex = raw.indexOf('#Intent;');
    if (hashIndex <= 0) return null;
    final body = raw.substring('intent://'.length, hashIndex);
    final scheme = _extractIntentParam(raw, 'scheme');
    if (scheme == null || scheme.trim().isEmpty) return null;
    return Uri.tryParse('${scheme.trim()}://$body');
  }

  Uri? _extractBrowserFallbackUri(String raw) {
    final encoded = _extractIntentParam(raw, 'S.browser_fallback_url');
    if (encoded == null || encoded.trim().isEmpty) return null;
    return Uri.tryParse(Uri.decodeComponent(encoded.trim()));
  }

  Future<bool> _launchExternalUrl(String rawUrl) async {
    final direct = Uri.tryParse(rawUrl);
    if (direct != null) {
      final launchedDirect = await launchUrl(
        direct,
        mode: LaunchMode.externalApplication,
      );
      if (launchedDirect) return true;
    }

    final intentUri = _buildUriFromIntentUrl(rawUrl);
    if (intentUri != null) {
      final launchedIntent = await launchUrl(
        intentUri,
        mode: LaunchMode.externalApplication,
      );
      if (launchedIntent) return true;
    }

    final fallbackUri = _extractBrowserFallbackUri(rawUrl);
    if (fallbackUri != null) {
      return launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  bool _isExternalLikeUrl(String rawUrl) {
    final lower = rawUrl.trim().toLowerCase();
    return lower.startsWith('intent://') ||
        lower.startsWith('upi://') ||
        lower.startsWith('phonepe://') ||
        lower.startsWith('paytmmp://') ||
        lower.startsWith('tez://') ||
        lower.startsWith('gpay://') ||
        lower.startsWith('credpay://');
  }

  Future<void> _attachDeepLinkJsBridge() async {
    const script = '''
      (function () {
        if (window.__yanaDeepLinkBridgeInstalled) return;
        window.__yanaDeepLinkBridgeInstalled = true;
        function sendIfDeep(u) {
          if (!u) return;
          var s = String(u).toLowerCase();
          if (
            s.indexOf('intent://') === 0 ||
            s.indexOf('upi://') === 0 ||
            s.indexOf('phonepe://') === 0 ||
            s.indexOf('paytmmp://') === 0 ||
            s.indexOf('tez://') === 0 ||
            s.indexOf('gpay://') === 0 ||
            s.indexOf('credpay://') === 0
          ) {
            AppLinkBridge.postMessage(String(u));
          }
        }
        document.addEventListener('click', function (e) {
          var n = e.target;
          while (n && n.tagName !== 'A') n = n.parentElement;
          if (!n) return;
          var href = n.getAttribute('href');
          sendIfDeep(href);
        }, true);
        var oldOpen = window.open;
        window.open = function (url) {
          sendIfDeep(url);
          if (oldOpen) return oldOpen.apply(window, arguments);
          return null;
        };
      })();
    ''';
    await _controller.runJavaScript(script);
  }

  Future<NavigationDecision> _handleNavigationRequest(
    NavigationRequest request,
  ) async {
    // Keep existing success/failure signal behavior intact.
    if (request.url.contains(widget.successPathMatch)) {
      Navigator.pop(context, true);
      return NavigationDecision.prevent;
    }

    if (request.url.contains(widget.failurePathMatch)) {
      Navigator.pop(context, false);
      return NavigationDecision.prevent;
    }

    final uri = Uri.tryParse(request.url);
    if ((uri != null && _shouldOpenExternally(uri)) ||
        request.url.toLowerCase().startsWith('intent://')) {
      final launched = await _launchExternalUrl(request.url);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(_upiMissingMessage)),
        );
      }
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  @override
  void initState() {
    super.initState();

    final paymentUrl = "https://yanaworldwide.store/${widget.paymentPagePath}"
        "?amount=${widget.amount}"
        "&name=${Uri.encodeComponent(widget.name)}"
        "&email=${Uri.encodeComponent(widget.email)}"
        "&phone=${widget.phone}";

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'AppLinkBridge',
        onMessageReceived: (message) async {
          final raw = message.message.trim();
          if (!_isExternalLikeUrl(raw)) return;
          final launched = await _launchExternalUrl(raw);
          if (!launched && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text(_upiMissingMessage)),
            );
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _handleNavigationRequest,
          onPageFinished: (_) {
            _attachDeepLinkJsBridge();
          },
        ),
      )
      ..loadRequest(Uri.parse(paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.appBarTitle)),
      body: WebViewWidget(controller: _controller),
    );
  }
}
