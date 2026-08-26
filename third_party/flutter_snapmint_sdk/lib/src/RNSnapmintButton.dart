import 'package:flutter/widgets.dart';

import 'SnapmintButtonWidget.dart'
    if (dart.library.html) 'SnapmintButtonWidgetWeb.dart';



class FontFamilyConfig {
  final String fontFamily;
  final int fontMultiplier;

  const FontFamilyConfig({
    required this.fontFamily,
    required this.fontMultiplier,
  });

  TextStyle toTextStyle() =>
      TextStyle(fontFamily: fontFamily, fontSize: fontMultiplier.toDouble());
}

class RNSnapmintButton extends StatelessWidget {
  final String amount;
  final String? merchantPath; // preferred
  final String? jsonUrl; // legacy
  final FontFamilyConfig? fontFamily;
  final double? buttonWidth;
  final bool disablePopup;

  const RNSnapmintButton({
    super.key,
    required this.amount,
    this.merchantPath,
    this.jsonUrl,
    this.fontFamily,
    this.buttonWidth,
    this.disablePopup = false,
  });

  String? get _resolvedJsonUrl {
    if (merchantPath == null || merchantPath!.isEmpty) return jsonUrl;
    // If merchantPath already a full URL, pass through. Else build like RN
    if (merchantPath!.startsWith('http://') ||
        merchantPath!.startsWith('https://')) {
      return merchantPath;
    }
    return 'https://merchant-js.snapmint.com/assets/merchant/${merchantPath!}';
  }

  @override
  Widget build(BuildContext context) {
    return SnapmintButtonWidget(
      amount: amount,
      jsonUrl: _resolvedJsonUrl,
      fontFamily: fontFamily?.toTextStyle(),
      buttonWidth: buttonWidth,
      disablePopup: disablePopup,
      jsonData: null,
    );
  }
}
