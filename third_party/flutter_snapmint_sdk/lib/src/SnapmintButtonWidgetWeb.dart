import 'dart:js_interop';

import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'data/button_data.dart';
import 'data/modal_data.dart';
import 'logger.dart';

class SnapmintButtonWidget extends StatefulWidget {
  final String amount;
  final String? jsonUrl;
  final TextStyle? fontFamily;
  final double? buttonWidth;
  final bool disablePopup;
  final Map<String, dynamic>? jsonData;

  const SnapmintButtonWidget({
    super.key,
    required this.amount,
    this.jsonUrl,
    this.fontFamily,
    this.buttonWidth,
    required this.disablePopup,
    this.jsonData,
  }) : assert(jsonUrl != null || jsonData != null,
            'Either jsonUrl or jsonData must be provided');

  @override
  State<SnapmintButtonWidget> createState() => _SnapmintButtonWidgetState();
}

class _SnapmintButtonWidgetState extends State<SnapmintButtonWidget> {
  bool loading = false;
  Map<String, dynamic>? jsonData;
  late ButtonData _buttonData;
  late ModalData _modalData;

  // Web-specific elements
  web.HTMLDivElement? _buttonDiv;
  web.HTMLIFrameElement? _modalIframe;
  String _buttonViewType = '';

  bool _modalVisible = false;
  DateTime? _lastOpenAt;
  double _buttonHeight = 75.0;

  late JSExportedDartFunction modelEventListener = ((web.Event event) {
    _handleModalMessage(event);
  }).toJS;

  @override
  void initState() {
    super.initState();

    // Initialize data handlers
    _buttonData = ButtonData(amount: widget.amount, jsonData: widget.jsonData);
    _modalData = ModalData(amount: double.parse(widget.amount), jsonData: widget.jsonData);

    // Create unique view type for iframe registration
    _buttonViewType = 'snapmint-button-${widget.amount}-${DateTime.now().millisecondsSinceEpoch}';

    // Initialize button iframe
    _initializeButtonIframe();

    // Use provided jsonData if available, otherwise fetch from API
    if (widget.jsonData != null) {
      SnapmintLogger.log('✅ Web: Using provided jsonData instead of API call');
      setState(() {
        jsonData = widget.jsonData;
        loading = false;
      });
      _buttonData.calculateAmounts();
      _loadButtonContent();
    } else {
      SnapmintLogger.log('🌐 Web: No jsonData provided, fetching from API');
      _fetchJsonData();
    }
  }

  void _initializeButtonIframe() {
    SnapmintLogger.log('🔧 Web: Initializing button div...');

    // Create div element for button (not iframe!)
    _buttonDiv = web.HTMLDivElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = 'auto'
      ..style.overflow = 'visible'
      ..style.cursor = 'pointer';

    // Register the div view
    ui_web.platformViewRegistry.registerViewFactory(
      _buttonViewType,
      (int viewId) => _buttonDiv!,
    );

    SnapmintLogger.log('✅ Web: Button div initialized');
  }

  // No longer needed - click handler is directly on the div

  Future<void> _fetchJsonData() async {
    SnapmintLogger.log('🚀 Web: Starting fetchJsonData for amount: ${widget.amount}');

    if (widget.jsonUrl == null) {
      SnapmintLogger.log('❌ Web: No jsonUrl provided and no jsonData available');
      setState(() {
        loading = false;
      });
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final normalized = await _buttonData.fetchJsonData(widget.jsonUrl!);

      setState(() {
        jsonData = normalized;
        loading = false;
      });

      // Update modal data
      _modalData = ModalData(amount: double.parse(widget.amount), jsonData: normalized);

      _loadButtonContent();
    } catch (e) {
      SnapmintLogger.log('❌ Web: API Error: $e');
      setState(() {
        loading = false;
      });

      _loadButtonContent();
    }
  }

  void _loadButtonContent() {
    if (_buttonDiv == null) return;

    SnapmintLogger.log('🌐 Web: Loading button content into div');

    // Generate HTML content using ButtonData
    final htmlContent = _buttonData.generateButtonHtml();

    SnapmintLogger.log('💱 Web Button: Generated HTML contains ₹: ${htmlContent.contains('₹')}');
    SnapmintLogger.log('📏 Web Button: HTML length: ${htmlContent.length}');

    // Extract just the body content from the generated HTML
    final bodyMatch = RegExp(r'<body[^>]*>([\s\S]*?)</body>', caseSensitive: false).firstMatch(htmlContent);
    String bodyContent = bodyMatch?.group(1) ?? htmlContent;

    // Remove scripts from body content (we'll execute them separately)
    bodyContent = bodyContent.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');

    // Extract and apply any styles
    final styleMatches = RegExp(r'<style[^>]*>([\s\S]*?)</style>', caseSensitive: false).allMatches(htmlContent);
    final styles = styleMatches.map((m) => m.group(1) ?? '').join('\n');

    // Inject the content into the div
    _buttonDiv!.innerHTML = '''
      <style>
        $styles
      </style>
      $bodyContent
    '''.toJS;

    // Set up click handler directly on div
    _buttonDiv!.addEventListener('click', ((web.Event event) {
      SnapmintLogger.log('📨 Web: Button div clicked');
      if (widget.disablePopup) {
        SnapmintLogger.log('⚠️ Web: Modal disabled by disablePopup flag');
        return;
      }

      final now = DateTime.now();
      final recentlyOpened = _lastOpenAt != null &&
          now.difference(_lastOpenAt!).inMilliseconds < 800;

      if (_modalVisible || recentlyOpened) {
        SnapmintLogger.log('⚠️ Web: Modal already visible, ignoring duplicate open request');
        return;
      }

      SnapmintLogger.log('🔥 Web: Opening EMI modal');
      _lastOpenAt = now;
      _modalVisible = true;
      _openModal();
    }).toJS);

    // Measure the actual height of the content after a short delay to let it render
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_buttonDiv != null && mounted) {
        final height = _buttonDiv!.offsetHeight.toDouble();
        SnapmintLogger.log('📏 Web: Button content height measured: $height');
        if (height > 0) {
          setState(() {
            _buttonHeight = height;
          });
        }
      }
    });

    SnapmintLogger.log('✅ Web: Button content loaded into div');
  }

  void _openModal() {
    SnapmintLogger.log('🔥 Web: Opening EMI modal with amount: ${widget.amount}');
    SnapmintLogger.log('📊 Web: JSON data available: ${jsonData != null}');

    // Create modal iframe that fills the entire viewport
    _modalIframe = web.HTMLIFrameElement()
      ..style.position = 'fixed'
      ..style.top = '0'
      ..style.left = '0'
      ..style.right = '0'
      ..style.bottom = '0'
      ..style.width = '100vw'
      ..style.height = '100vh'
      ..style.margin = '0'
      ..style.padding = '0'
      ..style.border = 'none'
      ..style.backgroundColor = 'transparent'
      ..style.zIndex = '999999';

    // Process template with placeholders
    String processedHtml = _modalData.getProcessedTemplate();

    SnapmintLogger.log('💱 Web Modal: Processed HTML contains ₹: ${processedHtml.contains('₹')}');

    // Inject bridge script into modal HTML
    // This creates BOTH window.SnapmintModalChannel (for new code) and window.Android (for legacy code)
    const modalBridgeScript = '''
    <script>
      // Bridge for SnapmintModalChannel (used in modal_data.dart closePopup function)
      window.SnapmintModalChannel = {
        postMessage: function(message) {
          console.log('📤 Modal Bridge: SnapmintModalChannel forwarding message to parent:', message);
          window.parent.postMessage(message, '*');
        }
      };

      // Legacy bridge for Android interface (backward compatibility)
      window.Android = {
        closePopup: function() {
          console.log('📤 Modal Bridge: Android.closePopup forwarding to parent');
          window.parent.postMessage('closeModal', '*');
        }
      };

      console.log('✅ Modal bridges created (SnapmintModalChannel + Android)');
    </script>
    ''';

    // Inject the bridge script right after <head> tag
    processedHtml = processedHtml.replaceFirst(
      '<head>',
      '<head>\n$modalBridgeScript',
    );

    SnapmintLogger.log('🔍 Injected modal bridges into HTML');

    // Load HTML into modal iframe
    final dataUrl = 'data:text/html;charset=utf-8,${Uri.encodeComponent(processedHtml)}';
    _modalIframe!.src = dataUrl;

    // Add iframe directly to body
    web.document.body!.appendChild(_modalIframe!);

    // Listen for close messages (only add if not already listening)
    web.window.addEventListener('message', modelEventListener);

    SnapmintLogger.log('✅ Web: Modal opened');
  }

  void _handleModalMessage(web.Event event) {
    if (event is web.MessageEvent) {
      final data = event.data;
      SnapmintLogger.log('📨 Web Modal: Received message: $data');

      if (data == null) return;

      // Convert JSAny to Dart type
      final dartData = data.dartify();
      SnapmintLogger.log('📨 Web Modal: Dartified data: $dartData (type: ${dartData.runtimeType})');

      // Handle both string and potential other formats
      String? dataString;
      if (dartData is String) {
        dataString = dartData;
      } else if (dartData is Map) {
        // If it's a map, check for action/message key
        dataString = dartData['action'] as String? ?? dartData['message'] as String?;
      }

      if (dataString == null) {
        SnapmintLogger.log('⚠️ Web Modal: Could not extract string from message data');
        return;
      }

      SnapmintLogger.log('📨 Web Modal: Extracted string: $dataString');

      if (dataString == 'closeModal' || dataString == 'close') {
        SnapmintLogger.log('🔴 Web: Close modal message received');
        _closeModal();
      }
    }
  }

  void _closeModal() {
    SnapmintLogger.log('🔴 Web: Closing modal');

    if (_modalIframe != null) {
      _modalIframe!.remove();
      _modalIframe = null;
    }

    _modalVisible = false;
    web.window.removeEventListener('message', modelEventListener);
    setState(() {});
  }

  @override
  void dispose() {
    // Close modal if open
    if (_modalIframe != null) {
      _modalIframe!.remove();
    }
    web.window.removeEventListener('message', modelEventListener);

    // Clean up button div
    if (_buttonDiv != null) {
      _buttonDiv!.remove();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        width: widget.buttonWidth,
        height: 75,
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
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Return HtmlElementView with the button div
    // HtmlElementView needs explicit sizing constraints
    return SizedBox(
      width: widget.buttonWidth ?? double.infinity,
      height: _buttonHeight, // Dynamic height based on content
      child: HtmlElementView(
        viewType: _buttonViewType,
      ),
    );
  }
}

