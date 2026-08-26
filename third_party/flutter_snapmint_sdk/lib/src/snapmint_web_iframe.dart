import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;

class SnapmintWebIFrame {
  final web.HTMLIFrameElement _iframe;

  final Function(String) onOrderSuccess;
  final Function(String) onOrderError;

  late final JSExportedDartFunction _message = ((web.Event event) {
    if (event is! web.MessageEvent) {
      return;
    }

    final data = event.data?.dartify();

    if (data == null) return;

    if (data is Map<dynamic, dynamic>) {
      if (data["closeIframe"] == true) {
        _closeRequested();
      }
    }
  }).toJS;

  SnapmintWebIFrame({
    required this.onOrderSuccess,
    required this.onOrderError,
    required String url,
  }) : _iframe = web.document.createElement('iframe') as web.HTMLIFrameElement {
    // Create Dart callback functions that can be called from JavaScript
    final JSFunction orderSuccessCallback = ((JSString data) {
      onOrderSuccess(data.toDart);
      _closeIframe();
    }).toJS;

    final JSFunction orderErrorCallback = ((JSString data) {
      onOrderError(data.toDart);
      _closeIframe();
    }).toJS;

    final JSFunction closeWebViewCallback = ((JSString data) {
      _closeRequested();
    }).toJS;

    final callbacksObj = JSObject();
    callbacksObj.setProperty('orderSuccess'.toJS, orderSuccessCallback);
    callbacksObj.setProperty('orderError'.toJS, orderErrorCallback);
    callbacksObj.setProperty('closeWebView'.toJS, closeWebViewCallback);

    web.window.setProperty('Android'.toJS, callbacksObj);
    web.window.addEventListener('message', _message);
    _iframe
      ..src = url
      ..style.position = 'fixed'
      ..style.top = '0'
      ..style.left = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none'
      ..style.zIndex = '9999';

    web.document.body?.appendChild(_iframe);
  }

  void _closeIframe() {
    _iframe.remove();
    web.window.removeEventListener('message', _message);
  }

  /// Removes the iframe from the document
  void _closeRequested() {
    _closeIframe();
    onOrderError("");
  }
}
