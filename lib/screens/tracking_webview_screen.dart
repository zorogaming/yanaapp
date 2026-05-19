import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TrackingWebViewScreen extends StatefulWidget {
  const TrackingWebViewScreen({super.key});

  static const String trackingUrl = 'https://yanaworldwide.store/track.php';

  @override
  State<TrackingWebViewScreen> createState() => _TrackingWebViewScreenState();
}

class _TrackingWebViewScreenState extends State<TrackingWebViewScreen> {
  late final WebViewController _controller;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _loadingProgress = progress;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(TrackingWebViewScreen.trackingUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracking'),
      ),
      body: Column(
        children: [
          if (_loadingProgress < 100)
            LinearProgressIndicator(value: _loadingProgress / 100),
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}
