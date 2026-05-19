import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayPaymentResult {
  const RazorpayPaymentResult({
    required this.success,
    this.paymentId = "",
    this.orderId = "",
    this.signature = "",
    this.failureReason = "",
    this.code,
  });

  final bool success;
  final String paymentId;
  final String orderId;
  final String signature;
  final String failureReason;
  final int? code;
}

class RazorpayService {
  RazorpayService() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  late final Razorpay _razorpay;
  Completer<RazorpayPaymentResult>? _paymentCompleter;

  Future<RazorpayPaymentResult> startPayment({
    required String keyId,
    required String orderId,
    required double amount,
    required String name,
    required String email,
    required String phone,
    String description = "Yanaworldwide Order",
  }) async {
    final normalizedName = name.trim().isEmpty ? "Customer" : name.trim();
    final normalizedEmail = email.trim().isEmpty
        ? "customer@yanaworldwide.store"
        : email.trim().toLowerCase();
    final normalizedPhone = _normalizePhone(phone);

    if (keyId.trim().isEmpty) {
      return const RazorpayPaymentResult(
        success: false,
        failureReason: "Razorpay key id missing",
      );
    }
    if (orderId.trim().isEmpty) {
      return const RazorpayPaymentResult(
        success: false,
        failureReason: "Razorpay order id missing",
      );
    }
    if (normalizedPhone.length < 10) {
      return const RazorpayPaymentResult(
        success: false,
        failureReason: "Razorpay requires a valid phone number",
      );
    }

    _paymentCompleter = Completer<RazorpayPaymentResult>();
    final amountInPaise = (amount * 100).round();
    final options = <String, dynamic>{
      "key": keyId.trim(),
      "amount": amountInPaise,
      "order_id": orderId.trim(),
      "name": "Yana Worldwide",
      "description": description,
      "prefill": {
        "name": normalizedName,
        "email": normalizedEmail,
        "contact": normalizedPhone,
      },
      "retry": {"enabled": true, "max_count": 1},
      "send_sms_hash": true,
      "theme": {"color": "#1E3A8A"},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      return RazorpayPaymentResult(
        success: false,
        failureReason: "Unable to open Razorpay: $e",
      );
    }

    return _paymentCompleter!.future.timeout(
      const Duration(minutes: 8),
      onTimeout: () => const RazorpayPaymentResult(
        success: false,
        failureReason: "Razorpay payment timed out",
      ),
    );
  }

  String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r"[^0-9]"), "");
    if (digits.length <= 10) return digits;
    return digits.substring(digits.length - 10);
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) {
    _complete(
      RazorpayPaymentResult(
        success: true,
        paymentId: response.paymentId ?? "",
        orderId: response.orderId ?? "",
        signature: response.signature ?? "",
      ),
    );
  }

  void _onPaymentError(PaymentFailureResponse response) {
    final rawMessage = (response.message ?? "").trim();
    final normalizedMessage =
        rawMessage.isEmpty ||
            rawMessage.toLowerCase() == "undefined" ||
            rawMessage.toLowerCase() == "null"
        ? "Razorpay payment was not completed"
        : rawMessage;
    _complete(
      RazorpayPaymentResult(
        success: false,
        failureReason: normalizedMessage,
        code: response.code,
      ),
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    _complete(
      RazorpayPaymentResult(
        success: false,
        failureReason: response.walletName?.trim().isNotEmpty == true
            ? "External wallet selected: ${response.walletName}"
            : "External wallet selected",
      ),
    );
  }

  void _complete(RazorpayPaymentResult result) {
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      _paymentCompleter!.complete(result);
    }
  }

  void dispose() {
    _razorpay.clear();
  }
}
