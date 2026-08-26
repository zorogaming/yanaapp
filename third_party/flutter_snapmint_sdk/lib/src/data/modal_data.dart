import 'dart:developer' as SnapmintLogger;

import '../PluginConstant.dart';

class ModalData {
  final Map<String, dynamic>? jsonData;
  final double amount;

  ModalData({
    required this.amount,
    this.jsonData,
  });

  // Safe converters to handle dynamic JSON values
  double _toDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  int _toInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  String _toString(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    return value.toString();
  }

  Map<String, double>? calculateAmountsForPopup(
      Map<String, dynamic> popupItem) {
    final payNowPercentage = popupItem['pay_now_percentage'] is num
        ? popupItem['pay_now_percentage'] as num
        : null;
    final emiPercentage = popupItem['emi_percentage'] is num
        ? popupItem['emi_percentage'] as num
        : null;
    final popup = popupItem['popup'] as String?;

    if (payNowPercentage == null || emiPercentage == null || popup == null) {
      return null;
    }

    // Calculate pay now amount with ceiling rounding
    final downPaymentPrice = (amount * payNowPercentage.toDouble() / 100).ceilToDouble();

    // Calculate EMI amounts with ceiling rounding (all three are the same)
    final emiAmount = (amount * emiPercentage.toDouble() / 100).ceilToDouble();

    return {
      'downPaymentPrice': downPaymentPrice,
      'firstEmiPrice': emiAmount,
      'secondEmiPrice': emiAmount,
      'thirdEmiPrice': emiAmount,
    };
  }

  // Calculate EMI amounts (similar to Android logic)
  Map<String, double> calculateAmounts() {
    SnapmintLogger.log('💰 Modal: Calculating EMI amounts for order: $amount');

    if (jsonData == null) {
      return {
        'downPaymentPrice': (amount * 0.33).ceilToDouble(),
        'firstEmiPrice': (amount * 0.33).ceilToDouble(),
        'secondEmiPrice': (amount * 0.34).ceilToDouble(),
        'thirdEmiPrice': 0.0,
      };
    }

    final payNowPercentage = amount > 2000
        ? _toString(jsonData!['pay_now_percentage_3_tenure'], '25')
        : _toString(jsonData!['pay_now_percentage'], '33.34');

    final emiOnePercentage = amount > 2000
        ? _toString(jsonData!['emi_one_percentage_3_tenure'], '25')
        : _toString(jsonData!['emi_one_percentage'], '33.33');

    final emiSecondPercentage = amount > 2000
        ? _toString(jsonData!['emi_second_percentage_3_tenure'], '25')
        : _toString(jsonData!['emi_second_percentage'], '33.33');

    final emiThirdPercentage = _toString(
      jsonData!['emi_third_percentage_3_tenure'],
      '25',
    );

    return {
      'downPaymentPrice':
          (amount * double.parse(payNowPercentage) / 100).ceilToDouble(),
      'firstEmiPrice':
          (amount * double.parse(emiOnePercentage) / 100).ceilToDouble(),
      'secondEmiPrice':
          (amount * double.parse(emiSecondPercentage) / 100).ceilToDouble(),
      'thirdEmiPrice': amount > 2000
          ? (amount * double.parse(emiThirdPercentage) / 100).ceilToDouble()
          : 0.0,
    };
  }

  // Calculate tenure amounts (Android logic)
  Map<String, int> calculateTenureAmounts(double downPaymentPrice) {
    if (jsonData == null || !jsonData!.containsKey('tenure_list')) return {};

    final tenureAmounts = <String, int>{};

    final tenureList = jsonData!['tenure_list'] as List<dynamic>?;
    if (tenureList != null) {
      for (var tenure in tenureList) {
        double tenureValue;
        final tenureNum = _toInt(tenure['tenure']);
        final roi = _toDouble(tenure['roi'], 0.0);

        if (roi > 0) {
          // If ROI is specified, calculate with interest
          tenureValue = (amount * roi) / 100;
        } else {
          // If no ROI, divide remaining amount by tenure
          tenureValue =
              tenureNum > 0 ? (amount - downPaymentPrice) / tenureNum : 0.0;
        }

        // Flutter-like rounding
        final rounded = (tenureValue.floor() + (tenureValue % 1 > 0 ? 1 : 0));
        tenureAmounts['tenure_$tenureNum'] = rounded.round();
      }
    }

    SnapmintLogger.log('📊 Modal: Calculated tenure amounts: $tenureAmounts');
    return tenureAmounts;
  }

  // Generate suffix for dates (1st, 2nd, 3rd, etc.)
  String getNumberSuffix(int number) {
    if (number % 10 == 1 && number != 11) return 'st';
    if (number % 10 == 2 && number != 12) return 'nd';
    if (number % 10 == 3 && number != 13) return 'rd';
    return 'th';
  }

  String getProcessedTemplate() {
    final popUpItem = getPopupItem();
    Map<String, double>? amounts;
    String? selectedTemplate;
    if (popUpItem != null) {
      amounts = calculateAmountsForPopup(popUpItem);
      selectedTemplate = popUpItem["popup"] is String ? popUpItem["popup"] : null;
    }

    amounts ??= calculateAmounts();
    selectedTemplate ??= _selectTemplate();

    if (selectedTemplate.isEmpty) {
      // Use fallback if no template
      selectedTemplate = snapMintHtml;
      SnapmintLogger.log('⚠️ Web Modal: No template selected, using fallback');
    }

    return _processHtmlString(
      html: selectedTemplate,
      downPaymentPrice: amounts["downPaymentPrice"]!,
      firstEmiPrice: amounts["firstEmiPrice"]!,
      secondEmiPrice: amounts["secondEmiPrice"]!,
      thirdEmiPrice: amounts["thirdEmiPrice"]!,
    );
  }

  String _processHtmlString({
    required String html,
    required double downPaymentPrice,
    required double firstEmiPrice,
    required double secondEmiPrice,
    required double thirdEmiPrice,
  }) {
    if (jsonData == null) {
      return '''
        <!DOCTYPE html>
        <html>
          <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
          </head>
          <body style="display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0;">
            <div style="text-align: center;">
              <h2>Loading...</h2>
            </div>
          </body>
        </html>
      ''';
    }

    SnapmintLogger.log(
      '🎯 Modal: Processing HTML content for amount: $amount',
    );

    // Check if the HTML already contains rupee symbols
    bool hasRupeeSymbol = html.contains('₹');
    bool hasRsText = html.contains('Rs');
    SnapmintLogger.log(
      '💱 Modal: Template analysis - Rupee symbol: $hasRupeeSymbol, Rs text: $hasRsText',
    );

    final List<String> month = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    final DateTime now = DateTime.now();

    String firstEmiMonth = '';
    String secondEmiMonth = '';
    String thirdEmiMonth = '';

    if (now.day >= 1 && now.day <= 23) {
      firstEmiMonth = month[now.month % 12];
      secondEmiMonth = month[(now.month + 1) % 12];
      thirdEmiMonth = month[(now.month + 2) % 12];
    } else {
      firstEmiMonth = month[(now.month + 1) % 12];
      secondEmiMonth = month[(now.month + 2) % 12];
      thirdEmiMonth = month[(now.month + 3) % 12];
    }

    // Calculate EMI values using Android-like logic
    final tenureAmounts = calculateTenureAmounts(downPaymentPrice);

    // Use selected template or fallback
    String processedHtml = html;

    // Dynamic date calculations
    const int firstEmiDay = 3;
    const int secondEmiDay = 3;
    const int thirdEmiDay = 3;

    SnapmintLogger.log(
      '📅 Modal: EMI dates calculated: downPayment=$downPaymentPrice, firstEmi=$firstEmiPrice, secondEmi=$secondEmiPrice, thirdEmi=$thirdEmiPrice',
    );

    // Debug: Check rupee symbol before replacement
    SnapmintLogger.log(
      '💱 Modal: Rupee symbol in template before replacements: ${processedHtml.contains('₹')}',
    );

    // Comprehensive placeholder replacement (Android-like)
    processedHtml = processedHtml
        // Main EMI amounts - ENABLE down_payment_price replacement!
        .replaceAll(
          '{{down_payment_price}}',
          downPaymentPrice.floor().toString(),
        )
        .replaceAll(
          '{{total_order_value}}',
          _toDouble(amount).floor().toString(),
        )
        .replaceAll(
          '{{first_emi_price}}',
          firstEmiPrice.floor().toString(),
        )
        .replaceAll(
          '{{second_emi_price}}',
          secondEmiPrice.floor().toString(),
        )
        .replaceAll(
          '{{third_emi_price}}',
          thirdEmiPrice.floor().toString(),
        )
        // EMI dates and suffixes
        .replaceAll('{{first_emi_date}}', firstEmiDay.toString())
        .replaceAll('{{first_emi_suffix}}', getNumberSuffix(firstEmiDay))
        .replaceAll('{{first_emi_month}}', firstEmiMonth)
        .replaceAll('{{second_emi_date}}', secondEmiDay.toString())
        .replaceAll('{{second_emi_suffix}}', getNumberSuffix(secondEmiDay))
        .replaceAll('{{second_emi_month}}', secondEmiMonth)
        .replaceAll('{{third_emi_date}}', thirdEmiDay.toString())
        .replaceAll('{{third_emi_suffix}}', getNumberSuffix(thirdEmiDay))
        .replaceAll('{{third_emi_month}}', thirdEmiMonth)
        // Legacy placeholders (for backward compatibility)
        .replaceAll(
          '{{pay_now_price}}',
          downPaymentPrice.floor().toString(),
        )
        .replaceAll(
          '{{first_installment_price}}',
          firstEmiPrice.floor().toString(),
        )
        .replaceAll(
          '{{second_installment_price}}',
          secondEmiPrice.floor().toString(),
        )
        .replaceAll('{{first_installment_month}}', firstEmiMonth)
        .replaceAll('{{second_installment_month}}', secondEmiMonth);

    // Add tenure amounts (Android logic)
    tenureAmounts.forEach((tenureKey, amount) {
      processedHtml = processedHtml.replaceAll(
        '{{$tenureKey}}',
        amount.toString(),
      );
      final capitalizedKey = tenureKey.isNotEmpty
          ? '${tenureKey[0].toUpperCase()}${tenureKey.substring(1)}'
          : tenureKey;
      processedHtml = processedHtml.replaceAll(
        '{{$capitalizedKey}}',
        amount.toString(),
      );
      SnapmintLogger.log(
          '📊 Modal: Replaced $tenureKey/$capitalizedKey with $amount');
    });

    // Debug: Check rupee symbol after all replacements
    SnapmintLogger.log(
      '💱 Modal: Rupee symbol in template after replacements: ${processedHtml.contains('₹')}',
    );

    // Add enhanced scripts and styling
    if (!processedHtml.contains('<head>')) {
      processedHtml = '<html><head></head><body>$processedHtml</body></html>';
    }

    processedHtml = processedHtml.replaceAll('<head>', '''
      <head>
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
              <style>
        body {
          margin: 0;
          padding: 10px;
          height: 460px; /* Fixed height (480 - padding) like React Native */
          overflow-y: auto;
          overflow-x: hidden;
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        }
        img {
          max-width: 100%;
          height: auto;
          display: block;
        }
        * {
          box-sizing: border-box;
        }

        /* Show close buttons properly */
        .snap-close-wrpr,
        .snap-close-wrpr img,
        #snapModalCloseon_page,
        [src*="close_icon"],
        [src*="cross_black"],
        [class*="close"],
        [id*="close"] {
          display: block !important;
          visibility: visible !important;
          opacity: 1 !important;
          cursor: pointer !important;
        }

        /* Make sure close button is on top and properly positioned */
        .snap-close-wrpr {
          z-index: 9999 !important;
          position: absolute !important;
          top: 15px !important;
          right: 15px !important;
        }

        /* Style close button image */
        .snap-close-wrpr img,
        #snapModalCloseon_page {
          width: 24px !important;
          height: 24px !important;
          cursor: pointer !important;
        }
      </style>
      <script>
        function closePopup() {
          if (window.SnapmintModalChannel) {
            window.SnapmintModalChannel.postMessage('close');
          }
        }

        // Fallback for Android.closePopup
        if (typeof Android === 'undefined') {
          window.Android = { closePopup: closePopup };
        }

        // Auto-attach close handlers when DOM loads
        document.addEventListener('DOMContentLoaded', function() {
          const closeButtons = document.querySelectorAll('[onclick*="closePopup"], #snapModalCloseon_page');
          closeButtons.forEach(button => {
            button.onclick = closePopup;
          });

          // Force image reload if not loaded
          const images = document.querySelectorAll('img');
          images.forEach(img => {
            if (!img.complete || img.naturalWidth === 0) {
              const newSrc = img.src;
              img.src = '';
              img.src = newSrc;
            }
          });
        });
      </script>
    ''');

    return processedHtml;
  }

  String _selectTemplate() {
    if (jsonData == null) {
      return '';
    }

    // Use API-based template selection (Android-like logic)
    String selectedTemplate = ''; // Will use default from PluginConstant

    if (jsonData!.containsKey('emi_pop_up_1')) {
      if (amount < 2000) {
        selectedTemplate = jsonData!['emi_pop_up_1'] ?? '';
      } else if (amount < 4000) {
        selectedTemplate = jsonData!['emi_pop_up_2'] ?? '';
      } else if (amount < 6000) {
        selectedTemplate = jsonData!['emi_pop_up_3'] ?? '';
      } else if (amount < 10000) {
        selectedTemplate = jsonData!['emi_pop_up_4'] ?? '';
      } else {
        selectedTemplate = jsonData!['emi_pop_up_5'] ?? '';
      }
    }

    SnapmintLogger.log('🎯 Modal: Loading template based on amount: $amount');
    SnapmintLogger.log(
        '📊 Selected template length: ${selectedTemplate.length}');

    return selectedTemplate;
  }

  Map<String, dynamic>? getPopupItem() {
    if (jsonData == null) return null;

    final List<dynamic> popupList = jsonData?["pop_up_list"] ?? [];

    if (popupList.isEmpty) return null;

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
