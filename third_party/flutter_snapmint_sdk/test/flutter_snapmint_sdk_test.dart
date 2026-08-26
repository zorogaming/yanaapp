import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_snapmint_sdk/flutter_snapmint_sdk.dart';
import 'package:flutter_snapmint_sdk/flutter_snapmint_sdk_platform_interface.dart';
import 'package:flutter_snapmint_sdk/flutter_snapmint_sdk_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterSnapmintSdkPlatform
    with MockPlatformInterfaceMixin
    implements FlutterSnapmintSdkPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<String?> openSnapmintModule(String url) {
    // TODO: implement openSnapmintModule
    throw UnimplementedError();
  }

  @override
  Future<String?> openSnapmintModuleWithOptions(String url, {Map<String, dynamic>? iosHeader}) {
    // TODO: implement openSnapmintModuleWithOptions
    throw UnimplementedError();
  }
}

void main() {
  final FlutterSnapmintSdkPlatform initialPlatform = FlutterSnapmintSdkPlatform.instance;

  test('$MethodChannelFlutterSnapmintSdk is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterSnapmintSdk>());
  });

  test('getPlatformVersion', () async {
    FlutterSnapmintSdk flutterSnapmintSdkPlugin = FlutterSnapmintSdk();
    MockFlutterSnapmintSdkPlatform fakePlatform = MockFlutterSnapmintSdkPlatform();
    FlutterSnapmintSdkPlatform.instance = fakePlatform;

    expect(await flutterSnapmintSdkPlugin.getPlatformVersion(), '42');
  });
}
