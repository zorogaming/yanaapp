import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:webview_flutter/webview_flutter.dart';
import 'SnapmintModal.dart';
import 'logger.dart';
import 'data/button_data.dart';

class SnapmintButtonWidget extends StatefulWidget {
  final String amount;
  final String? jsonUrl; // Make optional when jsonData is provided
  final TextStyle? fontFamily;
  final double? buttonWidth;
  final bool disablePopup;
  final Map<String, dynamic>? jsonData; // Add optional jsonData parameter

  const SnapmintButtonWidget({
    super.key,
    required this.amount,
    this.jsonUrl, // Make optional
    this.fontFamily,
    this.buttonWidth,
    required this.disablePopup,
    this.jsonData, // Add to constructor
  }) : assert(jsonUrl != null || jsonData != null,
            'Either jsonUrl or jsonData must be provided');

  @override
  State<SnapmintButtonWidget> createState() => _SnapmintButtonWidgetState();
}

class _SnapmintButtonWidgetState extends State<SnapmintButtonWidget> {
  bool loading = false;
  Map<String, dynamic>? jsonData;
  bool showModal = false;
  late TextStyle fontMultiplier;
  WebViewController? _webViewController;
  double _webViewHeight = 75.0; // Fixed height for button widget
  bool _modalVisible = false; // Guard to prevent duplicate modal opens
  DateTime? _lastOpenAt; // Time-based throttle to coalesce duplicate events

  // ButtonData instance for HTML generation and API calls
  late ButtonData _buttonData;

  // EMI calculation variables - now accessed via _buttonData
  double get amountPay => _buttonData.amountPay;

  double get firstEmiAmount => _buttonData.firstEmiAmount;

  double get secondEmiAmount => _buttonData.secondEmiAmount;

  double get thirdEmiAmount => _buttonData.thirdEmiAmount;

  @override
  void initState() {
    super.initState();
    fontMultiplier = widget.fontFamily ?? const TextStyle(fontSize: 15);

    // Initialize ButtonData
    _buttonData = ButtonData(amount: widget.amount, jsonData: widget.jsonData);

    // Initialize WebView immediately like Gold widget
    _initializeWebView();

    // Use provided jsonData if available, otherwise fetch from API
    if (widget.jsonData != null) {
      SnapmintLogger.log('✅ Using provided jsonData instead of API call');
      setState(() {
        jsonData = widget.jsonData;
        loading = false;
      });
      _buttonData.calculateAmounts();

      // Use _loadWebViewContent() to properly process emi_widget from jsonData
      _loadWebViewContent();
    } else {
      SnapmintLogger.log('🌐 No jsonData provided, fetching from API');
      fetchJsonData();
    }
  }

  void _initializeWebView() {
    SnapmintLogger.log(
        '🔧 Initializing WebView controller like Gold widget...');
    _webViewController = WebViewController()
      ..enableZoom(false)
      ..setBackgroundColor(Colors.transparent)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (String url) async {
          SnapmintLogger.log('✅ Button WebView loaded successfully: $url');

          // Get WebView height like Gold widget does
          if (Platform.isIOS) {
            _webViewController
                ?.runJavaScript("document.body.style.overflow = 'hidden';");
          }

          var htmlHeight =
              await _webViewController?.runJavaScriptReturningResult(
                  "document.documentElement.offsetHeight");
          double? finalHtmlHeight = double.tryParse(htmlHeight.toString());

          SnapmintLogger.log('📏 WebView height: $finalHtmlHeight');

          if (mounted) {
            setState(() {
              _webViewHeight = finalHtmlHeight ?? 75.0; // Fallback height
            });
          }
        },
        onWebResourceError: (WebResourceError error) {
          SnapmintLogger.log('❌ Button WebView Error: ${error.description}');
        },
      ))
      ..addJavaScriptChannel('SnapmintButtonChannel',
          onMessageReceived: (message) {
        SnapmintLogger.log(
            '📨 Received message from WebView: ${message.message}');
        if (message.message == 'openModal') {
          final now = DateTime.now();
          final recentlyOpened = _lastOpenAt != null &&
              now.difference(_lastOpenAt!).inMilliseconds < 800;
          if (_modalVisible || recentlyOpened) {
            SnapmintLogger.log(
                '⚠️ Modal already visible, ignoring duplicate open request');
            return;
          }
          SnapmintLogger.log('🔥 Opening EMI modal from button WebView');
          _lastOpenAt = now;
          _modalVisible = true;
          _openModal();
        }
      });

    SnapmintLogger.log('✅ WebView controller initialized like Gold widget');
  }

  Future<void> fetchJsonData() async {
    SnapmintLogger.log(
        '🚀 Starting fetchJsonData for amount: ${widget.amount}');

    // Check if jsonUrl is provided
    if (widget.jsonUrl == null) {
      SnapmintLogger.log('❌ No jsonUrl provided and no jsonData available');
      setState(() {
        loading = false;
      });
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      // Use ButtonData to fetch JSON data
      final normalized = await _buttonData.fetchJsonData(widget.jsonUrl!);

      setState(() {
        jsonData = normalized;
        loading = false;
      });

      // Load WebView immediately like Gold widget
      _loadWebViewContent(); // Use _loadWebViewContent() to properly process emi_widget
    } catch (e) {
      SnapmintLogger.log('❌ API Error: $e');
      SnapmintLogger.log('🔄 Fallback to default calculations');

      setState(() {
        loading = false;
      });

      // Load WebView with default values on error immediately like Gold widget
      _loadWebViewContentDirectly(); // Keep direct loading for error case
    }
  }

  void _loadWebViewContent() {
    if (_webViewController != null) {
      // Use ButtonData to generate button HTML
      final htmlContent = _buttonData.generateButtonHtml();
      SnapmintLogger.log(
          '🌐 Loading WebView content like Gold widget, HTML length: ${htmlContent.length}');
      SnapmintLogger.log(
          '💱 Button: Generated HTML contains ₹: ${htmlContent.contains('₹')}');

      // Load with EXACT same method as dummy page - simple loadHtmlString (like dummy page)
      _webViewController!.loadHtmlString(htmlContent);
      SnapmintLogger.log(
          '✅ Button: Loaded with simple loadHtmlString (dummy page method)');
    } else {
      SnapmintLogger.log('❌ WebView controller is null!');
    }
  }

  // Direct loading like Gold widget - no complex HTML generation
  void _loadWebViewContentDirectly() {
    if (_webViewController != null) {
      SnapmintLogger.log('🌐 Loading WebView directly like Gold widget');

      // Use ButtonData to generate simple HTML
      String simpleHtml = _buttonData.generateSimpleButtonHtml();
      SnapmintLogger.log(
          '💱 Button: Simple HTML contains ₹: ${simpleHtml.contains('₹')}');
      SnapmintLogger.log(
          '✅ Button: Loaded with simple loadHtmlString (dummy page method)');

      // Load HTML with UTF-8 encoding to fix rupee symbol rendering
      final uri = Uri.dataFromString(
        simpleHtml,
        mimeType: 'text/html',
        encoding: utf8,
      );
      _webViewController!.loadRequest(uri);
      SnapmintLogger.log('✅ Button: Loaded directly with UTF-8 encoding');
    } else {
      SnapmintLogger.log('❌ WebView controller is null!');
    }
  }

  void _openModal() {
    SnapmintLogger.log('🔥 Opening EMI modal with amount: ${widget.amount}');
    SnapmintLogger.log('📊 JSON data available: ${jsonData != null}');

    if (jsonData != null) {
      SnapmintLogger.log('📋 JSON keys: ${jsonData!.keys.toList()}');
    }

    showDialog(
        context: context,
        barrierDismissible: true, // Allow dismissing by tapping outside
        barrierColor: Colors.transparent, // Make background transparent
        builder: (BuildContext context) {
          SnapmintLogger.log('✅ Modal dialog builder called');

          // Test with simple modal first
          if (jsonData == null) {
            return AlertDialog(
              title: const Text('EMI Options'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Amount: ₹${widget.amount}'),
                  Text('Pay Now: ₹${amountPay.toInt()}'),
                  Text('First EMI: ₹${firstEmiAmount.toInt()}'),
                  Text('Second EMI: ₹${secondEmiAmount.toInt()}'),
                  if (thirdEmiAmount > 0)
                    Text('Third EMI: ₹${thirdEmiAmount.toInt()}'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          }

          return SnapmintModal(
            show: true,
            jsonData: jsonData,
            amount: double.parse(widget.amount),
            onPopupClose: () {
              SnapmintLogger.log('🔴 Modal close requested');
              setState(() {
                _modalVisible = false;
              });
              Navigator.pop(context);
            },
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double defaultButtonWidth = screenWidth * 0.9;

    final loadingWidget = SizedBox(
      width: widget.buttonWidth ?? defaultButtonWidth,
      height: _webViewHeight,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD2902D)),
            ),
            const SizedBox(height: 8),
            Text(
              'Loading EMI Widget...',
              style: widget.fontFamily ?? const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );

    if(loading){
      return loadingWidget;
    }

    if(_webViewController == null){
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: widget.buttonWidth ?? defaultButtonWidth,
      height: _webViewHeight,
      child: WebViewWidget(
        controller: _webViewController!,
      ),
    );

  }
}
