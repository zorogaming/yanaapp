import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:payu_checkoutpro_flutter/PayUConstantKeys.dart';
import 'package:payu_checkoutpro_flutter/payu_checkoutpro_flutter.dart';

import '../config.dart';

class PayUService implements PayUCheckoutProProtocol {
  late final PayUCheckoutProFlutter _checkoutPro;
  Completer<bool>? _paymentCompleter;
  Map<String, dynamic>? _activePayment;
  String? _lastFailureReason;

  String? get lastFailureReason => _lastFailureReason;

  PayUService() {
    _checkoutPro = PayUCheckoutProFlutter(this);
  }

  String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r"[^0-9]"), "");
    if (digits.isEmpty) return "";
    if (digits.length > 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  Future<bool> startPayment({
    required double amount,
    required String name,
    required String email,
    required String phone,
  }) async {
    final normalizedName = name.trim().isEmpty ? "Customer" : name.trim();
    final normalizedEmail = email.trim().isEmpty
        ? "customer@yanaworldwide.store"
        : email.trim().toLowerCase();
    final normalizedPhone = _normalizePhone(phone);
    if (normalizedPhone.length < 10) {
      _lastFailureReason =
          "User credentials missing (valid phone required)";
      return false;
    }
    final userCredential = "${Config.payuMerchantKey}:$normalizedEmail";

    final txnId = _buildTxnId();
    print(
      "[PAYU][FLOW] start txnId=$txnId amount=${amount.toStringAsFixed(2)} email=$normalizedEmail",
    );
    _paymentCompleter = Completer<bool>();
    _lastFailureReason = null;
    _activePayment = {
      "txnid": txnId,
      "amount": amount.toStringAsFixed(2),
      "productinfo": "Yanaworldwide Order",
      "firstname": normalizedName,
      "email": normalizedEmail,
      "phone": normalizedPhone,
      "userCredential": userCredential,
    };

    final Map<String, dynamic> params = {
      PayUPaymentParamKey.key: Config.payuMerchantKey,
      PayUPaymentParamKey.transactionId: txnId,
      PayUPaymentParamKey.amount: amount.toStringAsFixed(2),
      PayUPaymentParamKey.productInfo: "Yanaworldwide Order",
      PayUPaymentParamKey.firstName: normalizedName,
      PayUPaymentParamKey.email: normalizedEmail,
      PayUPaymentParamKey.phone: normalizedPhone,
      PayUPaymentParamKey.android_surl: Config.payuSuccessUrl,
      PayUPaymentParamKey.android_furl: Config.payuFailureUrl,
      PayUPaymentParamKey.ios_surl: Config.payuSuccessUrl,
      PayUPaymentParamKey.ios_furl: Config.payuFailureUrl,
      PayUPaymentParamKey.environment: Config.payuEnvironment,
      "userCredential": userCredential,
    };

    _checkoutPro.openCheckoutScreen(
      payUPaymentParams: params,
      payUCheckoutProConfig: {
        PayUCheckoutProConfigKeys.merchantName: "Yana Worldwide",
        PayUCheckoutProConfigKeys.showCbToolbar: true,
      },
    );
    print("[PAYU][FLOW] checkout screen opened");

    return _paymentCompleter!.future.timeout(
      const Duration(minutes: 8),
      onTimeout: () {
        print("[PAYU][FLOW] timeout waiting for callback");
        return false;
      },
    );
  }

  String _buildTxnId() {
    final raw = DateTime.now().millisecondsSinceEpoch.toString();
    final clean = raw.replaceAll(RegExp(r"[^a-zA-Z0-9]"), "");
    if (clean.length <= 25) return clean;
    return clean.substring(0, 25);
  }

  Map<String, String> _backendHeaders({bool json = false}) {
    return {
      Config.appHeaderKey: Config.appHeaderValue,
      if (json) "Content-Type": "application/json",
    };
  }

  Future<Map<String, dynamic>?> _requestHashFromBackend(
    Map<String, dynamic> payload,
  ) async {
    final url = Uri.parse(Config.payuHashApiUrl);
    try {
      print("[PAYU][HASH] JSON request -> ${url.toString()}");
      final jsonResponse = await http
          .post(
            url,
            headers: _backendHeaders(json: true),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));
      print(
        "[PAYU][HASH] JSON HTTP ${jsonResponse.statusCode} body=${jsonResponse.body.substring(0, jsonResponse.body.length > 250 ? 250 : jsonResponse.body.length)}",
      );
      if (jsonResponse.statusCode >= 200 && jsonResponse.statusCode < 300) {
        final parsed = _decodeJsonObject(jsonResponse.body);
        print("[PAYU][HASH] JSON parsed=${parsed != null}");
        if (parsed != null) return parsed;
      }
    } catch (_) {}

    try {
      print("[PAYU][HASH] FORM request -> ${url.toString()}");
      final formPayload = payload.map(
        (key, value) => MapEntry(key, value?.toString() ?? ""),
      );
      final formResponse = await http
          .post(url, headers: _backendHeaders(), body: formPayload)
          .timeout(const Duration(seconds: 20));
      print(
        "[PAYU][HASH] FORM HTTP ${formResponse.statusCode} body=${formResponse.body.substring(0, formResponse.body.length > 250 ? 250 : formResponse.body.length)}",
      );
      if (formResponse.statusCode >= 200 && formResponse.statusCode < 300) {
        return _decodeJsonObject(formResponse.body);
      }
    } catch (_) {}

    return null;
  }

  Map<String, dynamic>? _decodeJsonObject(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}

    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        final decoded = jsonDecode(raw.substring(start, end + 1));
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  Map<String, String> _stringOnlyMap(Map<dynamic, dynamic> source) {
    final out = <String, String>{};
    source.forEach((key, value) {
      if (key == null || value == null) return;
      if (value is String || value is num || value is bool) {
        out[key.toString()] = value.toString();
      }
    });
    return out;
  }

  void _complete(bool result) {
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      _paymentCompleter!.complete(result);
    }
    _activePayment = null;
  }

  String _extractReason(dynamic response) {
    if (response == null) return "Unknown PayU error";
    if (response is String) {
      final v = response.trim();
      return v.isEmpty ? "Unknown PayU error" : v;
    }
    if (response is Map) {
      final keys = [
        "errorMessage",
        "error_message",
        "error",
        "message",
        "errorCode",
        "error_code",
        "status",
        "txnid",
      ];
      for (final key in keys) {
        final value = response[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return response.toString();
    }
    return response.toString();
  }

  @override
  Future<void> generateHash(Map response) async {
    try {
      print("[PAYU][CALLBACK] generateHash req=$response");
      final requestBody = Map<String, dynamic>.from(response);
      if (_activePayment != null) {
        requestBody.addAll(_activePayment!);
      }
      requestBody["merchant_key"] = Config.payuMerchantKey;
      final data = await _requestHashFromBackend(requestBody) ?? {};
      final callbackHashName = (response["hashName"] ?? "").toString().trim();
      String callbackHashValue = "";
      if (callbackHashName.isNotEmpty) {
        callbackHashValue = (data[callbackHashName] ?? "").toString().trim();
      }
      if (callbackHashValue.isEmpty) {
        callbackHashValue = (data["hash"] ?? "").toString().trim();
      }
      print(
        "[PAYU][CALLBACK] hashName=$callbackHashName hashValueLength=${callbackHashValue.length} dataKeys=${data.keys.toList()}",
      );

      if (callbackHashName.isNotEmpty && callbackHashValue.isNotEmpty) {
        _checkoutPro.hashGenerated(
          hash: <String, String>{callbackHashName: callbackHashValue},
        );
        return;
      }

      final stringMap = _stringOnlyMap(data);
      if (stringMap.isNotEmpty) {
        _checkoutPro.hashGenerated(hash: stringMap);
        return;
      }

      _checkoutPro.hashGenerated(hash: <String, String>{});
    } catch (_) {
      print("[PAYU][CALLBACK] generateHash exception");
      _checkoutPro.hashGenerated(hash: <String, String>{});
    }
  }

  @override
  void onPaymentSuccess(response) {
    print("[PAYU][RESULT] success response=$response");
    _complete(true);
  }

  @override
  void onPaymentFailure(response) {
    print("[PAYU][RESULT] failure response=$response");
    _lastFailureReason = _extractReason(response);
    _complete(false);
  }

  @override
  void onPaymentCancel(Map? response) {
    print("[PAYU][RESULT] cancel response=$response");
    _lastFailureReason = "Payment cancelled by user";
    _complete(false);
  }

  @override
  void onError(Map? response) {
    print("[PAYU][RESULT] error response=$response");
    _lastFailureReason = _extractReason(response);
    _complete(false);
  }
}
