import 'dart:convert';
import 'dart:developer' as SnapmintLogger;
import 'package:http/http.dart' as http;

class ButtonData {
  // API Configuration - Similar to React Native
  static const String BASE_URL = 'https://merchant-js.snapmint.com/';
  static const String MERCHANT_ENDPOINT = 'assets/merchant/';

  // EMI calculation variables
  double amountPay = 0;
  double firstEmiAmount = 0;
  double secondEmiAmount = 0;
  double thirdEmiAmount = 0;

  Map<String, dynamic>? jsonData;
  String amount;

  ButtonData({required this.amount, this.jsonData});

  // Build API URL like React Native does
  String buildApiUrl(String merchantPath) {
    if (merchantPath.isEmpty) return '';

    // If merchantPath already contains full URL, use it directly
    if (merchantPath.startsWith('http://') || merchantPath.startsWith('https://')) {
      return merchantPath;
    }

    // Otherwise, construct URL like React Native: BASE_URL + ENDPOINT + PATH
    return '$BASE_URL$MERCHANT_ENDPOINT$merchantPath';
  }

  Future<Map<String, dynamic>?> fetchJsonData(String jsonUrl) async {
    SnapmintLogger.log('🚀 Starting fetchJsonData for amount: $amount');

    try {
      // Build full API URL like React Native
      final apiUrl = buildApiUrl(jsonUrl);
      SnapmintLogger.log('🔄 LIVE MODE: Fetching from API: $apiUrl');
      SnapmintLogger.log('📍 Merchant Path: $jsonUrl');

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Cache-Control': 'no-cache',
          'User-Agent': 'Flutter-SnapmintSDK/1.0',
        }
      ).timeout(const Duration(seconds: 30));

      SnapmintLogger.log('📡 API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        // ✅ Decode bytes explicitly as UTF-8 to handle rupee symbols properly
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));

        // ✅ Normalize any rupee encodings in the templates from API
        final normalized = _normalizeRupeeInJson(decoded);

        jsonData = normalized;

        // Calculate EMI amounts
        calculateAmounts();

        return normalized;
      } else {
        throw Exception('HTTP error! status: ${response.statusCode}');
      }
    } catch (e) {
      SnapmintLogger.log('❌ API Error: $e');
      SnapmintLogger.log('🔗 Failed URL: ${buildApiUrl(jsonUrl)}');
      SnapmintLogger.log('🔄 Fallback to default calculations');

      // Calculate with default values on error
      calculateAmounts();

      return null;
    }
  }

  // ✅ Normalize rupee signs in all template strings that may arrive escaped
  dynamic _normalizeRupeeInJson(dynamic data) {
    if (data is Map<String, dynamic>) {
      final out = <String, dynamic>{};
      data.forEach((k, v) => out[k] = _normalizeRupeeInJson(v));
      return out;
    } else if (data is List) {
      return data.map(_normalizeRupeeInJson).toList();
    } else if (data is String) {
      return _normalizeRupee(data);
    }
    return data;
  }

  // ✅ Fix all common rupee symbol encoding issues
  String _normalizeRupee(String s) {
    // Handle common cases: &#8377;, &amp;#8377;, \u20B9, plain text "Rs."
    return s
        .replaceAll('&amp;#8377;', '&#8377;') // double-escaped → single
        .replaceAll('&#8377;', '₹')           // HTML entity → char
        .replaceAll('\\\\u20B9', '₹')          // JSON-escaped backslash u → char
        .replaceAll('\\u20B9', '₹')           // direct unicode → ensure char
        .replaceAll(RegExp(r'\bRs\.?\s?'), '₹ '); // Rs/Rs. → ₹
  }

  void calculateAmounts() {

    if(_calculateAmountsForPopup()){
      return;
    }

    final double totalOrder = double.parse(amount);
    final model = jsonData;
    SnapmintLogger.log('💰 Calculating EMI amounts for order: $totalOrder');

    if (model == null) {
      SnapmintLogger.log('⚠️ No EMI model data, using default percentages');
      amountPay = (totalOrder * 0.33).ceil().toDouble();
      firstEmiAmount = (totalOrder * 0.33).ceil().toDouble();
      secondEmiAmount = (totalOrder * 0.34).ceil().toDouble();
      thirdEmiAmount = 0;
      return;
    }

    String payNowPercentage = totalOrder > 2000
        ? (model['pay_now_percentage_3_tenure'] ?? '25')
        : (model['pay_now_percentage'] ?? '33.34');

    String emiOnePercentage = totalOrder > 2000
        ? (model['emi_one_percentage_3_tenure'] ?? '25')
        : (model['emi_one_percentage'] ?? '33.33');

    String emiSecondPercentage = totalOrder > 2000
        ? (model['emi_second_percentage_3_tenure'] ?? '25')
        : (model['emi_second_percentage'] ?? '33.33');

    String emiThirdPercentage = model['emi_third_percentage_3_tenure'] ?? '25';

    double calculatedAmountPay = (totalOrder * double.parse(payNowPercentage)) / 100;
    double calculatedFirstEmi = (totalOrder * double.parse(emiOnePercentage)) / 100;
    double calculatedSecondEmi = (totalOrder * double.parse(emiSecondPercentage)) / 100;
    double calculatedThirdEmi = totalOrder > 2000
        ? (totalOrder * double.parse(emiThirdPercentage)) / 100
        : 0;

    // Flutter-like rounding logic (similar to Android)
    amountPay = (calculatedAmountPay.floor() + (calculatedAmountPay % 1 > 0 ? 1 : 0)).toDouble();
    firstEmiAmount = (calculatedFirstEmi.floor() + (calculatedFirstEmi % 1 > 0 ? 1 : 0)).toDouble();
    secondEmiAmount = (calculatedSecondEmi.floor() + (calculatedSecondEmi % 1 > 0 ? 1 : 0)).toDouble();
    thirdEmiAmount = (calculatedThirdEmi.floor() + (calculatedThirdEmi % 1 > 0 ? 1 : 0)).toDouble();

    SnapmintLogger.log('💰 Calculated amounts: amountPay=$amountPay, firstEmi=$firstEmiAmount, secondEmi=$secondEmiAmount, thirdEmi=$thirdEmiAmount');
  }

  bool _calculateAmountsForPopup() {
    final popupItem = getPopupItem();

    if(popupItem == null) return false;

    final payNowPercentage = popupItem['pay_now_percentage'] is num
        ? popupItem['pay_now_percentage'] as num
        : null;
    final emiPercentage = popupItem['emi_percentage'] is num
        ? popupItem['emi_percentage'] as num
        : null;
    final popup = popupItem['popup'] as String?;

    if (payNowPercentage == null || emiPercentage == null || popup == null) {
      return false;
    }

    final amount = double.parse(this.amount);

    // Calculate pay now amount with ceiling rounding
    final downPaymentPrice = (amount * payNowPercentage.toDouble() / 100).ceilToDouble();

    // Calculate EMI amounts with ceiling rounding (all three are the same)
    final emiAmount = (amount * emiPercentage.toDouble() / 100).ceilToDouble();

    amountPay = downPaymentPrice;
    firstEmiAmount = emiAmount;
    secondEmiAmount = emiAmount;
    thirdEmiAmount = emiAmount;

    return true;
  }

  String generateSimpleButtonHtml() {
    SnapmintLogger.log('🎨 Generating button HTML...');
    SnapmintLogger.log('📊 JSON Data available: ${jsonData != null}');

    if (jsonData == null) {
      // Fallback HTML if no API data
      return '''
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            margin: 0;
            padding: 6px 8px;
            font-family: Arial, sans-serif;
            background: white;
            cursor: pointer;
            height: 63px;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .emi-button {
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 8px 12px;
            border: 1px solid #D2902D;
            border-radius: 6px;
            background: #fff;
        }
        .emi-content {
            text-align: center;
        }
        .emi-title {
            font-size: 14px;
            font-weight: 600;
            color: #D2902D;
            margin-bottom: 2px;
        }
        .emi-amount {
            font-size: 12px;
            color: #333;
        }
    </style>
</head>
<body onclick="openModal()">
    <div class="emi-button">
        <div class="emi-content">
            <div class="emi-title">EMI Options Available</div>
            <div class="emi-amount">Pay ₹${amountPay.toInt()} + EMIs</div>
        </div>
    </div>
    <script>
        (function(){
          window.__snapmintOpening = false;
          function openModal() {
            if (window.__snapmintOpening) return;
            window.__snapmintOpening = true;
            console.log('📱 Opening EMI modal');
            if (window.SnapmintButtonChannel) {
              window.SnapmintButtonChannel.postMessage('openModal');
            }
            setTimeout(function(){ window.__snapmintOpening = false; }, 600);
          }
          window.openModal = openModal;
        })();
    </script>
</body>
</html>
      ''';
    }

    SnapmintLogger.log('🎨 Generating complete EMI button HTML from API JSON response');

    // Use emi_widget from API like React Native
    String emiWidget = jsonData!['emi_widget'] ?? '';

    SnapmintLogger.log('🔍 Raw emi_widget from API: ${emiWidget.substring(0, emiWidget.length.clamp(0, 200))}...');
    SnapmintLogger.log('💱 Raw emi_widget contains ₹: ${emiWidget.contains('₹')}');

    // Fix escaped characters from API response
    emiWidget = emiWidget
        .replaceAll('\\\\_', '_')  // Fix escaped underscores
        .replaceAll('\\\\n', '\n')  // Fix escaped newlines
        .replaceAll('\\\\{', '{')   // Fix escaped braces
        .replaceAll('\\\\}', '}');  // Fix escaped braces
    SnapmintLogger.log('🔧 After fixing escaped characters contains ₹: ${emiWidget.contains('₹')}');



    // Find specific part with down_payment_price placeholder
    int dpIndex = emiWidget.indexOf('{{down_payment_price}}');
    if (dpIndex != -1) {
      int startIndex = (dpIndex - 100).clamp(0, emiWidget.length);
      int endIndex = (dpIndex + 150).clamp(0, emiWidget.length);
      String dpContext = emiWidget.substring(startIndex, endIndex);
      SnapmintLogger.log('💰 Main Button down_payment_price context: $dpContext');
    } else {
      SnapmintLogger.log('❌ Main Button: {{down_payment_price}} placeholder NOT found in emi_widget!');
    }

    // Search for any price-related text in the widget
    if (emiWidget.contains('pay') || emiWidget.contains('Pay')) {
      RegExp payPattern = RegExp(r'[Pp]ay[^<>]*(?:\d+|{{[^}]+}})[^<>]*', multiLine: true);
      Iterable<RegExpMatch> payMatches = payPattern.allMatches(emiWidget);
      for (RegExpMatch match in payMatches) {
        SnapmintLogger.log('💰 Main Button pay text: ${match.group(0)}');
      }
    }

    // Find any span with currency related classes
    RegExp spanPattern = RegExp(r'<span[^>]*(?:color|price|amount|dp|currency)[^>]*>[^<]*</span>');
    Iterable<RegExpMatch> spans = spanPattern.allMatches(emiWidget);
    for (RegExpMatch span in spans) {
      SnapmintLogger.log('💰 Main Button found currency span: ${span.group(0)}');
    }
    SnapmintLogger.log('🔍 Full raw emi_widget length: ${emiWidget.length}');

    // Log character by character analysis for debugging
    if (emiWidget.contains('₹') || emiWidget.contains('â¹') || emiWidget.contains('Rs')) {
      SnapmintLogger.log('💰 Found currency symbols in API response');

      // Find and log the currency pattern
      RegExp currencyPattern = RegExp(r'[₹â¹]|Rs\.?|INR');
      Iterable<RegExpMatch> matches = currencyPattern.allMatches(emiWidget);
      for (RegExpMatch match in matches) {
        String found = match.group(0) ?? '';
        SnapmintLogger.log('💰 Found currency symbol: "$found" at position ${match.start}');
        // Log hex values of the characters
        List<int> bytes = found.codeUnits;
        SnapmintLogger.log('💰 Hex values: ${bytes.map((b) => b.toRadixString(16)).join(' ')}');
      }
    } else {
      SnapmintLogger.log('⚠️ No currency symbols found in API response');
    }

    if (emiWidget.isEmpty) {
      // Fallback if no emi_widget in API
      SnapmintLogger.log('⚠️ Empty emi_widget, using fallback');
      return generateFallbackHtml();
    }

    // Replace placeholder with amountPay value (React Native logic)
    emiWidget = emiWidget.replaceAll('{{down_payment_price}}', '${amountPay.toInt()}');
    emiWidget = emiWidget.replaceAll('{{pay_now_price}}', '${amountPay.toInt()}');



    // Enhanced HTML structure like React Native

    return '''
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <meta charset="UTF-8">
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <style>
        * {
            box-sizing: border-box;
            -webkit-tap-highlight-color: transparent;
        }
        html, body {
            margin: 0;
            padding: 0;
            width: 100%;
            background: white;
            overflow-x: hidden;
            font-family: -apple-system, BlinkMacSystemFont, 'Noto Sans', 'Roboto', 'Open Sans', 'Inter', 'Segoe UI', Arial, sans-serif;
            height: auto;
            min-height: auto;
        }
        /* Enhanced rupee symbol support */
        body, div, span, p {
            font-family: 'Noto Sans', 'Roboto', 'Open Sans', 'Inter', system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif !important;
        }
        .snap_emi_amt, .snap_total_order_value_amt, .snap_pay_only_text, .snap_dp_color, .snap_cashback_line {
            font-family: 'Noto Sans', 'Roboto', 'Open Sans', 'Inter', system-ui, sans-serif !important;
        }
        body {
            padding: 6px 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 63px;
            overflow: hidden;
        }
        .widget-wrapper {
            cursor: pointer;
        }
    </style>
</head>
<body>
    <div class="widget-wrapper">
        <div style="padding: 10px; font-family: 'Noto Sans', Arial, sans-serif;">
            Test: ₹1234 Direct Rupee Symbol
        </div>
        $emiWidget
    </div>
    <script>
        (function(){
          window.__snapmintOpening = false;
          function handleWidgetClick() {
            if (window.__snapmintOpening) return;
            window.__snapmintOpening = true;
            console.log('🔥 EMI Widget clicked - opening modal');
            if (window.SnapmintButtonChannel) {
              window.SnapmintButtonChannel.postMessage('openModal');
            }
            setTimeout(function(){ window.__snapmintOpening = false; }, 600);
          }
          document.addEventListener('DOMContentLoaded', function() {
            // Bind only to Snapmint widget elements to avoid duplicate firing
            ['.snap_buy_now_btn', '.snap_emi_txt', '.snap_flex_section', '.snap_above_widget']
              .forEach(function(sel){
                var nodes = document.querySelectorAll(sel);
                nodes.forEach(function(n){
                  n.style.cursor = 'pointer';
                  n.addEventListener('click', function(e){ e.preventDefault(); e.stopPropagation(); handleWidgetClick(); });
                  n.addEventListener('touchend', function(e){ e.preventDefault(); e.stopPropagation(); handleWidgetClick(); });
                });
              });
            // Optional guarded body fallback
            document.body.addEventListener('click', function(){ handleWidgetClick(); });
          });
        })();
    </script>
</body>
</html>
    ''';
  }

  String generateFallbackHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            margin: 0;
            padding: 6px 8px;
            font-family: Arial, sans-serif;
            background: white;
            cursor: pointer;
            height: 63px;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .emi-info {
            text-align: center;
            color: #D2902D;
            font-size: 14px;
            font-weight: 600;
        }
    </style>
</head>
<body onclick="openModal()">
    <div class="emi-info">
        ⏳ Loading EMI Widget...
    </div>
    <script>
        function openModal() {
            console.log('📱 Opening EMI modal from fallback');
            if (window.SnapmintButtonChannel) {
                window.SnapmintButtonChannel.postMessage('openModal');
            }
        }
    </script>
</body>
</html>
    ''';
  }

  String generateButtonHtml() {
    SnapmintLogger.log('🎨 Generating button HTML...');
    SnapmintLogger.log('📊 JSON Data available: ${jsonData != null}');

    if (jsonData == null) {
      SnapmintLogger.log('⚠️ No JSON data, using fallback HTML');
      return '''
        <!DOCTYPE html>
        <html>
          <head>
            <meta name='viewport' content='width=device-width, initial-scale=1.0'>
            <style>
              body { margin: 0; padding: 15px; background: white; font-family: Arial, sans-serif; cursor: pointer; }
              .loading { text-align: center; padding: 20px; color: #666; }
            </style>
            <script>
              function openModal() {
                console.log('📱 Opening modal from fallback HTML');
                if (window.SnapmintButtonChannel) {
                  window.SnapmintButtonChannel.postMessage('openModal');
                }
              }
            </script>
          </head>
          <body onclick="openModal()">
            <div class="loading">
              <div>⏳ Loading EMI Widget...</div>
              <small>Click when loaded to see EMI details</small>
            </div>
          </body>
        </html>
      ''';
    }

    SnapmintLogger.log('🎨 Generating complete EMI button HTML from API JSON response');

    // Use emi_widget from JSON if available, otherwise create from other JSON data
    String widgetHtml = '';

    if (jsonData!.containsKey('emi_widget')) {
      widgetHtml = jsonData!['emi_widget'];


      // Fix escaped characters from API response if needed (legacy cleanup)
      widgetHtml = widgetHtml
          .replaceAll(r'\_', '_')    // Fix escaped underscores
          .replaceAll(r'\n', '\n')   // Fix escaped newlines
          .replaceAll(r'\{', '{')    // Fix escaped braces
          .replaceAll(r'\}', '}')    // Fix escaped braces
          .replaceAll(r'\\', r'\')   // Fix double backslashes
          .replaceAll('&amp;', '&')  // Fix HTML entities
          .replaceAll('&lt;', '<')   // Fix HTML entities
          .replaceAll('&gt;', '>');  // Fix HTML entities

      // Log character by character analysis for debugging in _generateButtonHtml
      if (widgetHtml.contains('₹') || widgetHtml.contains('â¹') || widgetHtml.contains('Rs')) {
        SnapmintLogger.log('💰 [ButtonHtml] Found currency symbols in API response');

        // Find and log the currency pattern
        RegExp currencyPattern = RegExp(r'[₹â¹]|Rs\.?|INR');
        Iterable<RegExpMatch> matches = currencyPattern.allMatches(widgetHtml);
        for (RegExpMatch match in matches) {
          String found = match.group(0) ?? '';
          SnapmintLogger.log('💰 [ButtonHtml] Found currency symbol: "$found" at position ${match.start}');
          // Log hex values of the characters
          List<int> bytes = found.codeUnits;
          SnapmintLogger.log('💰 [ButtonHtml] Hex values: ${bytes.map((b) => b.toRadixString(16)).join(' ')}');
        }
      } else {
        SnapmintLogger.log('⚠️ [ButtonHtml] No currency symbols found in API response');
      }
    } else {
      // Build widget HTML from individual JSON components
      final payNowText1 = jsonData!['pay_now_text1_part1'] ?? 'Pay';
      final payNowText3 = jsonData!['pay_now_text1_part3'] ?? 'now, rest in';
      final payNowText4 = jsonData!['pay_now_text1_part4'] ?? '2 EMIs';
      final logoUrl = jsonData!['pay_now_text2'] ?? 'https://assets.snapmint.com/assets/merchant/emitxt/snapmint_logo.png';
      final additionalText = jsonData!['pay_now_text3'] ?? 'No Cost EMI';

      widgetHtml = '''
        <div style="display: flex; align-items: center; padding: 8px 12px; background: white; border-radius: 8px; border: 1px solid #e0e0e0; font-family: -apple-system, BlinkMacSystemFont, 'Inter', sans-serif;">
          <div style="flex: 1; font-size: 14px; color: #333;">
            <span>$payNowText1 </span>
            <strong style="color: #D2902D;">₹${amountPay.floor()}</strong>
            <span> $payNowText3 </span>
            <strong style="color: #D2902D;">$payNowText4</strong>
          </div>
          <img src="$logoUrl" style="width: 60px; height: 20px; margin-left: 8px;" alt="Snapmint" />
        </div>
        <div style="text-align: center; font-size: 10px; color: #666; margin-top: 4px;">
          $additionalText
        </div>
      ''';
    }

    // Process placeholders in the widget HTML
    widgetHtml = widgetHtml
        .replaceAll('{{down_payment_price}}', '${amountPay.floor()}')
        .replaceAll('{{pay_now_price}}', '${amountPay.floor()}')
        .replaceAll('{{first_emi_price}}', '${firstEmiAmount.floor()}')
        .replaceAll('{{second_emi_price}}', '${secondEmiAmount.floor()}')
        .replaceAll('{{third_emi_price}}', '${thirdEmiAmount.floor()}')
        .replaceAll('{{total_order_value}}', '${double.parse(amount).floor()}');

    return '''
      <!DOCTYPE html>
      <html>
        <head>
          <meta name='viewport' content='width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no'>
          <meta charset='utf-8'>
          <style>
            * {
              box-sizing: border-box;
              -webkit-tap-highlight-color: transparent;
            }
            html, body {
               margin: 0;
               padding: 0;
               width: 100%;
               background: white;
               overflow-x: hidden;
               font-family: -apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', sans-serif;
               height: auto;
               min-height: auto;
             }
             body {
               padding: 6px 8px;
               display: flex;
               align-items: center;
               justify-content: center;
               min-height: 63px;
               overflow: hidden;
             }
             .widget-wrapper {
               width: 100%;
               cursor: pointer;
             }
             .widget-wrapper:hover {
               opacity: 0.9;
             }
          </style>
        </head>
        <body>
           <div class="widget-wrapper">
             $widgetHtml
           </div>
          <script>
            (function(){
              window.__snapmintOpening = false;
              function postOnce(){
                if (window.__snapmintOpening) return;
                window.__snapmintOpening = true;
                if (window.SnapmintButtonChannel) {
                  window.SnapmintButtonChannel.postMessage('openModal');
                }
                setTimeout(function(){ window.__snapmintOpening = false; }, 800);
              }
              function bindCapture(el){
                if (!el) return;
                // Remove inline onclick if present
                try { el.onclick = null; el.removeAttribute('onclick'); } catch(e){}
                el.style.cursor = 'pointer';
                el.addEventListener('click', function(e){
                  e.preventDefault();
                  e.stopPropagation();
                  if (e.stopImmediatePropagation) e.stopImmediatePropagation();
                  postOnce();
                }, { capture: true });
                el.addEventListener('touchend', function(e){
                  e.preventDefault();
                  e.stopPropagation();
                  if (e.stopImmediatePropagation) e.stopImmediatePropagation();
                  postOnce();
                }, { capture: true });
              }
              document.addEventListener('DOMContentLoaded', function(){
                var selectors = ['.snap_buy_now_btn', '.snap_emi_txt', '.snap_flex_section', '.snap_above_widget'];
                selectors.forEach(function(sel){
                  document.querySelectorAll(sel).forEach(bindCapture);
                });
              });
            })();
          </script>
        </body>
      </html>
    ''';
  }

  Map<String, dynamic>? getPopupItem() {
    if (jsonData == null) return null;

    final List<dynamic> popupList = jsonData?["pop_up_list"] ?? [];

    if (popupList.isEmpty) return null;

    final amount = double.parse(this.amount);

    for (var popupItem in popupList) {
      if (popupItem is! Map<String, dynamic>) {
        SnapmintLogger.log(popupItem);
        continue;
      }
      if (popupItem["min"] is! num || popupItem["min"] is! num) {
        continue;
      }

      final min = (popupItem["min"] as num).toDouble();
      final max =( popupItem["max"] as num).toDouble();
      final maxValue = (max == -1.0) ? double.maxFinite : max;
      if (amount >= min && amount <= maxValue) {
        return popupItem;
      }
    }
    return null;
  }

}