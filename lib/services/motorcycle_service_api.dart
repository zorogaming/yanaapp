import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

class MotorcycleServiceApi {
  String? lastErrorMessage;

  Future<MotorcycleServiceAiEstimate?> fetchEstimate({
    required String bikeModel,
  }) async {
    lastErrorMessage = null;
    final endpoint = Config.motorcycleServicePriceApiUrl.trim();
    if (endpoint.isEmpty) {
      lastErrorMessage = 'API URL missing in config';
      return null;
    }

    try {
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: <String, String>{
              'Content-Type': 'application/json',
              if (Config.motorcycleServiceApiToken.trim().isNotEmpty)
                'X-Service-Token': Config.motorcycleServiceApiToken.trim(),
            },
            body: jsonEncode(<String, dynamic>{
              'bikeModel': bikeModel.trim(),
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        lastErrorMessage =
            'HTTP ${response.statusCode}: ${response.body.toString().trim()}';
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        lastErrorMessage = 'Invalid JSON envelope from server';
        return null;
      }
      final map = Map<String, dynamic>.from(decoded);
      if (map['ok'] == false) {
        lastErrorMessage = (map['error'] ?? 'Server returned ok=false')
            .toString()
            .trim();
        return null;
      }

      final payload = _resolvePayload(map);
      if (payload == null) {
        lastErrorMessage = 'Estimate payload missing in API response';
        return null;
      }

      return MotorcycleServiceAiEstimate.fromJson(payload);
    } catch (e) {
      lastErrorMessage = e.toString();
      return null;
    }
  }

  Map<String, dynamic>? _resolvePayload(Map<String, dynamic> root) {
    if (root['data'] is Map) {
      return Map<String, dynamic>.from(root['data'] as Map);
    }

    final outputText = (root['output_text'] ?? '').toString().trim();
    if (outputText.isNotEmpty) {
      try {
        final cleaned = _stripCodeFences(outputText);
        final parsed = jsonDecode(cleaned);
        if (parsed is Map) {
          return Map<String, dynamic>.from(parsed);
        }
      } catch (_) {}
    }

    if (root['bike_model'] != null || root['oil_capacity_litres'] != null) {
      return root;
    }

    return null;
  }

  String _stripCodeFences(String input) {
    var text = input.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```[a-zA-Z0-9_-]*\s*'), '');
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
    }
    return text.trim();
  }
}

class MotorcycleServiceAiEstimate {
  const MotorcycleServiceAiEstimate({
    required this.bikeModel,
    required this.oilCapacityLitres,
    required this.oilFilterPrice,
    required this.airFilterPrice,
    required this.confidence,
    required this.notes,
    required this.sources,
  });

  factory MotorcycleServiceAiEstimate.fromJson(Map<String, dynamic> json) {
    return MotorcycleServiceAiEstimate(
      bikeModel: (json['bike_model'] ?? '').toString().trim(),
      oilCapacityLitres: _toDouble(
        json['oil_capacity_litres'] ??
            json['engine_oil_litres'] ??
            json['oil_capacity'] ??
            json['oil_litres'],
      ),
      oilFilterPrice: _resolvePrice(
        json['oil_filter'] ?? json['oil_filter_price'],
      ),
      airFilterPrice: _resolvePrice(
        json['air_filter'] ?? json['air_filter_price'],
      ),
      confidence: (json['confidence'] ?? 'estimated').toString().trim(),
      notes: (json['notes'] ?? '').toString().trim(),
      sources: _parseSources(json['sources']),
    );
  }

  final String bikeModel;
  final double oilCapacityLitres;
  final double oilFilterPrice;
  final double airFilterPrice;
  final String confidence;
  final String notes;
  final List<String> sources;

  static double _resolvePrice(dynamic raw) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final direct = _toDouble(map['estimated']);
      if (direct > 0) return direct;
      final min = _toDouble(map['min']);
      final max = _toDouble(map['max']);
      if (min > 0 && max > 0) return (min + max) / 2;
      if (max > 0) return max;
      if (min > 0) return min;
    }
    return _toDouble(raw);
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString().trim()) ?? 0;
  }

  static List<String> _parseSources(dynamic raw) {
    if (raw is List) {
      return raw
          .map((item) {
            if (item is Map) {
              return (item['url'] ?? item['link'] ?? '').toString().trim();
            }
            return item.toString().trim();
          })
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }
}
