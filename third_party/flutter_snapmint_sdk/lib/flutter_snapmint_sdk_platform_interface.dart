import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_snapmint_sdk_method_channel.dart';

abstract class FlutterSnapmintSdkPlatform extends PlatformInterface {
  /// Constructs a FlutterSnapmintSdkPlatform.
  FlutterSnapmintSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterSnapmintSdkPlatform _instance = MethodChannelFlutterSnapmintSdk();

  /// The default instance of [FlutterSnapmintSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterSnapmintSdk].
  static FlutterSnapmintSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterSnapmintSdkPlatform] when
  /// they register themselves.
  static set instance(FlutterSnapmintSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<String?> openSnapmintModule(String url) {
    throw UnimplementedError('openSnapmint() has not been implemented');
  }

  /// iOS-only enhanced API: pass optional header options as a map.
  /// Other platforms may ignore the header.
  Future<String?> openSnapmintModuleWithOptions(String url, {Map<String, dynamic>? iosHeader}) {
    throw UnimplementedError('openSnapmintModuleWithOptions() has not been implemented');
  }
}
