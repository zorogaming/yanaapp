import 'dart:async';
import 'dart:convert';

import 'logger.dart';

import '../flutter_snapmint_sdk.dart';
import 'dart:io' show Platform;

class PaymentResult {
  final String status;
  final int? statusCode;
  final String? message;
  final String? responseMsg;
  final String? paymentId;
  final String? timestamp;

  PaymentResult({
    required this.status,
    this.statusCode,
    this.message,
    this.responseMsg,
    this.paymentId,
    this.timestamp,
  });

  factory PaymentResult.fromMap(Map<String, dynamic> map) {
    return PaymentResult(
      status: (map['status'] ?? map['Status'] ?? '').toString(),
      statusCode: _asInt(map['statusCode']),
      message: map['message']?.toString(),
      responseMsg: map['responseMsg']?.toString() ?? map['message']?.toString(),
      paymentId: map['paymentId']?.toString(),
      timestamp: map['timestamp']?.toString(),
    );
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }
}

class PaymentError implements Exception {
  final String status;
  final int? statusCode;
  final String? message;
  final String? responseMsg;
  final String? timestamp;

  PaymentError({
    required this.status,
    this.statusCode,
    this.message,
    this.responseMsg,
    this.timestamp,
  });

  @override
  String toString() {
    return 'PaymentError(status: '+status+', code: '+(statusCode?.toString() ?? 'null')+', message: '+(message ?? responseMsg ?? 'unknown')+')';
  }
}

class PaymentOptions {
  final void Function(PaymentResult result)? onSuccess;
  final void Function(PaymentError error)? onError;

  const PaymentOptions({this.onSuccess, this.onError});
}

class RNSnapmintCheckout {
  static const Duration _timeout = Duration(minutes: 5);

  static Future<PaymentResult> openSnapmintMerchant(String checkoutUrl, {PaymentOptions? options, HeaderOptions? iosHeader}) async {
    // Debug: entry
    // Using print to ensure visibility in `flutter run` and device logs
    SnapmintLogger.log('[RNSnapmintCheckout] openSnapmintMerchant called');
    if (checkoutUrl.trim().isEmpty) {
      final error = PaymentError(
        status: 'failure',
        statusCode: 400,
        message: 'Invalid checkout URL provided',
        responseMsg: 'Invalid checkout URL provided',
        timestamp: DateTime.now().toIso8601String(),
      );
      if (options?.onError != null) {
        scheduleMicrotask(() => options!.onError!(error));
      }
      throw error;
    }

    try {
      final future = (iosHeader != null && Platform.isIOS)
          ? FlutterSnapmintSdk().openSnapmintModuleWithOptions(checkoutUrl, iosHeader: iosHeader)
          : FlutterSnapmintSdk().openSnapmintModule(checkoutUrl);

      final String? raw = await future.timeout(_timeout, onTimeout: () {
        SnapmintLogger.log('[RNSnapmintCheckout] Timeout reached while waiting for native result');
        throw PaymentError(
          status: 'failure',
          statusCode: 408,
          message: 'Payment request timed out',
          responseMsg: 'Payment request timed out',
          timestamp: DateTime.now().toIso8601String(),
        );
      });

      Map<String, dynamic> decoded;
      try {
        SnapmintLogger.log('[RNSnapmintCheckout] Raw native response: ' + (raw ?? 'null'));
        decoded = raw != null && raw.isNotEmpty ? json.decode(raw) as Map<String, dynamic> : <String, dynamic>{};
      } catch (_) {
        SnapmintLogger.log('[RNSnapmintCheckout] Failed to decode JSON, wrapping raw text');
        decoded = <String, dynamic>{ 'status': 'unknown', 'message': raw ?? '' };
      }

      final result = PaymentResult.fromMap(decoded);
      SnapmintLogger.log('[RNSnapmintCheckout] Decoded result: ' + decoded.toString());

      final int code = result.statusCode ?? (result.status.toLowerCase() == 'success' ? 200 : 400);
      final bool isSuccess = code == 200 || result.status.toLowerCase() == 'success';

      if (isSuccess) {
        SnapmintLogger.log('[RNSnapmintCheckout] Success → invoking onSuccess callback');
        try {
          if (options?.onSuccess != null) {
            options!.onSuccess!(result);
          }
        } catch (cbErr, _) {
          // Swallow UI callback exceptions so success does not flip to failure
          SnapmintLogger.log('[RNSnapmintCheckout] onSuccess callback threw: ' + cbErr.toString());
        }
        return result;
      }

      final error = PaymentError(
        status: 'failure',
        statusCode: result.statusCode ?? 400,
        message: result.message ?? result.responseMsg ?? 'Payment failed',
        responseMsg: result.responseMsg ?? result.message,
        timestamp: result.timestamp ?? DateTime.now().toIso8601String(),
      );
      SnapmintLogger.log('[RNSnapmintCheckout] Failure → invoking onError callback: ' + (error.message ?? ''));
      if (options?.onError != null) {
        options!.onError!(error);
      }
      throw error;
    } on PaymentError catch (e) {
      SnapmintLogger.log('[RNSnapmintCheckout] PaymentError thrown: ' + e.toString());
      if (options?.onError != null) {
        options!.onError!(e);
      }
      rethrow;
    } catch (e) {
      SnapmintLogger.log('[RNSnapmintCheckout] Unexpected error: ' + e.toString());
      final error = PaymentError(
        status: 'failure',
        statusCode: 500,
        message: e.toString(),
        responseMsg: e.toString(),
        timestamp: DateTime.now().toIso8601String(),
      );
      if (options?.onError != null) {
        options!.onError!(error);
      }
      throw error;
    }
  }
}

