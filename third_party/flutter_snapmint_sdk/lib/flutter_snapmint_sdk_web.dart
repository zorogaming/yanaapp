// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of your plugin.
// ignore: avoid_web_libraries_in_flutter

import 'dart:async';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'flutter_snapmint_sdk_platform_interface.dart';

/// A web implementation of the FlutterSnapmintSdkPlatform of the FlutterSnapmintSdk plugin.
class FlutterSnapmintSdkWeb extends FlutterSnapmintSdkPlatform {
  /// Constructs a FlutterSnapmintSdkWeb
  FlutterSnapmintSdkWeb();

  static void registerWith(Registrar registrar) {
    FlutterSnapmintSdkPlatform.instance = FlutterSnapmintSdkWeb();
  }

  /// Returns a [String] containing the version of the platform.
  @override
  Future<String?> getPlatformVersion() async {
    final version = web.window.navigator.userAgent;
    return version;
  }

  @override
  Future<String?> openSnapmintModule(String url) async {
    return "";
  }
}
