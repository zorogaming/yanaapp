import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'PluginConstant.dart';
import 'data/modal_data.dart';

class SnapmintModal extends StatefulWidget {
  final bool show;
  final VoidCallback onPopupClose;
  final Map<String, dynamic>? jsonData;
  final double amount;
  final String? fontFamilyStyle;

  const SnapmintModal({
    super.key,
    required this.show,
    required this.onPopupClose,
    required this.jsonData,
    required this.amount,
    this.fontFamilyStyle,
  });

  @override
  State<StatefulWidget> createState() => _SnapmintModalState();
}

class _SnapmintModalState extends State<SnapmintModal> {
  double _webViewWidth = 350.0; // Set initial width
  WebViewController? _controller;
  late ModalData _modalData;

  @override
  void initState() {
    super.initState();

    // Initialize ModalData
    _modalData = ModalData(
      amount: widget.amount,
      jsonData: widget.jsonData,
    );

    _controller = WebViewController()
      ..enableZoom(false)
      ..setBackgroundColor(Colors.transparent) // Fully transparent background
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) async {
            if (Platform.isIOS) {
              _controller?.runJavaScript(
                "document.body.style.overflow = 'hidden';",
              );
            }

            // Get both height and width of HTML content for exact sizing
            await Future.delayed(
              Duration(milliseconds: 0),
            ); // Wait for content to render

            var htmlHeight = await _controller?.runJavaScriptReturningResult(
              "Math.max(document.body.scrollHeight, document.body.offsetHeight, document.documentElement.clientHeight, document.documentElement.scrollHeight, document.documentElement.offsetHeight)",
            );
            var htmlWidth = await _controller?.runJavaScriptReturningResult(
              "Math.max(document.body.scrollWidth, document.body.offsetWidth, document.documentElement.clientWidth, document.documentElement.scrollWidth, document.documentElement.offsetWidth)",
            );

            double? finalHtmlHeight = double.tryParse(htmlHeight.toString());
            double? finalHtmlWidth = double.tryParse(htmlWidth.toString());

            debugPrint(
              '🔍 Modal WebView - Raw height: $htmlHeight, Raw width: $htmlWidth',
            );
            debugPrint(
              '✅ Modal WebView loaded, height: $finalHtmlHeight, width: $finalHtmlWidth',
            );

            setState(() {
              _webViewWidth = (finalHtmlWidth != null && finalHtmlWidth > 100)
                  ? finalHtmlWidth
                  : 350.0;
            });
          },
        ),
      )
      ..addJavaScriptChannel(
        'SnapmintModalChannel',
        onMessageReceived: (message) {
          if (message.message == 'close') {
            debugPrint('🔴 Modal: Close button pressed in WebView');
            widget.onPopupClose();
          }
        },
      );

    // Load HTML content based on API JSON response
    if (widget.jsonData != null) {
      if (_controller != null) {
        // Use ModalData to process placeholders
        String processedTemplate = _modalData.getProcessedTemplate();
        debugPrint(
          '💱 Modal: After processing contains ₹: ${processedTemplate.contains('₹')}',
        );

        // Replace Android.closePopup() with Flutter channel for modal interaction
        processedTemplate = processedTemplate.replaceAll(
          'Android.closePopup()',
          'SnapmintModalChannel.postMessage("close")',
        );

        // Load with EXACT same method as dummy page - simple loadHtmlString
        _controller!.loadHtmlString(processedTemplate);
        debugPrint(
          '✅ COPYING: HTML loaded using dummy page EXACT method (loadHtmlString)',
        );
      } else {
        debugPrint('❌ Modal WebView controller is null');
      }
    } else {
      // Load fallback HTML with UTF-8 encoding
      if (_controller != null) {
        final fallbackHtml = _modalData.getProcessedTemplate();
        _controller!.loadHtmlString(fallbackHtml);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (!widget.show) {
      return Container(); // Return empty if not showing modal
    }

    return Dialog(
      insetPadding: EdgeInsets.zero, // Remove all padding for full screen
      backgroundColor: Colors.transparent, // Transparent dialog background
      child: Align(
        alignment: Alignment.center, // Center the modal like React Native
        child: Container(
          width: MediaQuery.of(context).size.width, // Full screen width
          height: MediaQuery.of(context).size.height, // Full screen height
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(
              0.15,
            ), // Light green semi-transparent background
            borderRadius: BorderRadius.circular(
              0,
            ), // Remove border radius for full screen
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge, // overflow: hidden like React Native
          child: Stack(
            children: [
              // Remove Container wrapper that adds background
              _controller != null
                  ? WebViewWidget(controller: _controller!)
                  : Container(
                      color: Colors.transparent,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
              Positioned(
                top: 20, // Position from top
                right: 20, // Position from right
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.transparent, // Semi-transparent background
                    shape: BoxShape.circle,
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
