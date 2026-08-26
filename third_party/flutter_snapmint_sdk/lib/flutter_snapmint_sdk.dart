
import 'flutter_snapmint_sdk_platform_interface.dart';
import 'src/HeaderOptions.dart';
export 'src/RNSnapmintCheckout.dart';
export 'src/RNSnapmintButton.dart';
export 'src/HeaderOptions.dart';

class FlutterSnapmintSdk {
  Future<String?> getPlatformVersion() {
    return FlutterSnapmintSdkPlatform.instance.getPlatformVersion();
  }

  Future<String?> openSnapmintModule(String url) {
    return FlutterSnapmintSdkPlatform.instance.openSnapmintModule(url);
  }

  Future<String?> openSnapmintModuleWithOptions(String url, {HeaderOptions? iosHeader}) {
    return FlutterSnapmintSdkPlatform.instance.openSnapmintModuleWithOptions(
      url,
      iosHeader: iosHeader?.toMap(),
    );
  }
}
