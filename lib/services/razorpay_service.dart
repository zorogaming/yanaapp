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
  Timer? _checkoutWatchdogTimer;
  Timer? _paymentRecoveryTimer;
  bool _isRecoveringPayment = false;

  bool get hasPendingPayment =>
      _paymentCompleter != null && !_paymentCompleter!.isCompleted;

  Future<RazorpayPaymentResult> startPayment({
    required String keyId,
    required String orderId,
    required double amount,
    required String name,
    required String email,
    required String phone,
    String description = "Yanaworldwide Order",
    String offerId = "",
    Future<RazorpayPaymentResult?> Function(String razorpayOrderId)?
    recoverPayment,
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
    _checkoutWatchdogTimer?.cancel();
    _checkoutWatchdogTimer = Timer(const Duration(minutes: 4), () {
      if (!hasPendingPayment) return;
      _closeNativeCheckout();
      _complete(
        const RazorpayPaymentResult(
          success: false,
          failureReason: "Razorpay checkout timed out. Please try again.",
        ),
      );
    });
    _startRecoveryPolling(orderId.trim(), recoverPayment);
    final amountInPaise = (amount * 100).round();
    print(
      "[RAZORPAY][NATIVE] opening checkout orderId=${orderId.trim()} amountPaise=$amountInPaise",
    );
    final options = <String, dynamic>{
      "key": keyId.trim(),
      "amount": amountInPaise,
      "currency": "INR",
      "order_id": orderId.trim(),
      "name": "Yana Worldwide",
      "description": description,
      "prefill": {
        "name": normalizedName,
        "email": normalizedEmail,
        "contact": normalizedPhone,
      },
      "retry": {"enabled": true, "max_count": 1},
      "modal": {"confirm_close": true},
      "send_sms_hash": true,
      "theme": {"color": "#1E3A8A"},
    };
    if (offerId.trim().isNotEmpty) {
      options["offer_id"] = offerId.trim();
    }

    try {
      _razorpay.open(options);
      print("[RAZORPAY][NATIVE] open invoked");
    } catch (e) {
      print("[RAZORPAY][NATIVE] open threw error=$e");
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

  void _startRecoveryPolling(
    String razorpayOrderId,
    Future<RazorpayPaymentResult?> Function(String razorpayOrderId)?
    recoverPayment,
  ) {
    _paymentRecoveryTimer?.cancel();
    _isRecoveringPayment = false;
    if (recoverPayment == null) return;

    _paymentRecoveryTimer = Timer.periodic(const Duration(seconds: 5), (
      timer,
    ) async {
      if (!hasPendingPayment) {
        timer.cancel();
        return;
      }
      if (_isRecoveringPayment) return;
      _isRecoveringPayment = true;
      try {
        print("[RAZORPAY][NATIVE] recovery poll orderId=$razorpayOrderId");
        final recovered = await recoverPayment(razorpayOrderId);
        if (recovered != null && recovered.success && hasPendingPayment) {
          print(
            "[RAZORPAY][NATIVE] recovery success paymentId=${recovered.paymentId}",
          );
          _closeNativeCheckout();
          _complete(recovered);
        }
      } catch (e) {
        print("[RAZORPAY][NATIVE] recovery error=$e");
      } finally {
        _isRecoveringPayment = false;
      }
    });
  }

  String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r"[^0-9]"), "");
    if (digits.length <= 10) return digits;
    return digits.substring(digits.length - 10);
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) {
    print(
      "[RAZORPAY][NATIVE] success paymentId=${response.paymentId} orderId=${response.orderId} signaturePresent=${(response.signature ?? '').isNotEmpty}",
    );
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
    print(
      "[RAZORPAY][NATIVE] error code=${response.code} message=${response.message} body=${response.error}",
    );
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
    print("[RAZORPAY][NATIVE] external wallet=${response.walletName}");
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
    print(
      "[RAZORPAY][NATIVE] complete success=${result.success} paymentId=${result.paymentId} reason=${result.failureReason}",
    );
    _checkoutWatchdogTimer?.cancel();
    _checkoutWatchdogTimer = null;
    _paymentRecoveryTimer?.cancel();
    _paymentRecoveryTimer = null;
    _isRecoveringPayment = false;
    final completer = _paymentCompleter;
    _paymentCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
  }

  void cancelPending({String reason = "Razorpay checkout was closed"}) {
    print("[RAZORPAY][NATIVE] cancelPending reason=$reason");
    _closeNativeCheckout();
    _complete(RazorpayPaymentResult(success: false, failureReason: reason));
  }

  void _closeNativeCheckout() {
    try {
      print("[RAZORPAY][NATIVE] close requested");
      unawaited(_razorpay.close());
    } catch (_) {}
  }

  void dispose() {
    if (hasPendingPayment) {
      cancelPending(reason: "Razorpay checkout was closed");
    }
    _razorpay.clear();
  }
}
