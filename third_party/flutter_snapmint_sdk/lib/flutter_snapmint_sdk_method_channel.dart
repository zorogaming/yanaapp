import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_snapmint_sdk_platform_interface.dart';

/// An implementation of [FlutterSnapmintSdkPlatform] that uses method channels.
class MethodChannelFlutterSnapmintSdk extends FlutterSnapmintSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_snapmint_sdk');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<String?> openSnapmintModule(String url) async {
    String? callback = await methodChannel.invokeMethod<String?>('openSnapmintMerchant',url);
    return callback;
  }

  @override
  Future<String?> openSnapmintModuleWithOptions(String url, {Map<String, dynamic>? iosHeader}) async {
    final bool includeHeader = iosHeader != null && (iosHeader['enableHeader'] == true);
    final Object payload = <String, dynamic>{
      'url': url,
      if (includeHeader) 'header': iosHeader,
    };
    final String? callback = await methodChannel.invokeMethod<String?>('openSnapmintMerchant', payload);
    return callback;
  }
}
