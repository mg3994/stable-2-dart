import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

class AppsScriptService {
  static AppsScriptService? _instance;

  String _mapUrl = 'https://script.google.com/macros/s/AKfycbyca4Xz_AE6Om1okIMf0TQ9EE9uIifQcVZhsDwnZK0K4weG7VD0w3jEzM0aCcuBeoWIIA/exec';

  static AppsScriptService getInstance() {
    _instance ??= AppsScriptService();
    return _instance!;
  }

  void setMapUrl(String url) {
    _mapUrl = url;
  }

  Future<dynamic> _callAction(String action, [Map<String, dynamic> params = const {}]) async {
    final payload = {'action': action, 'params': params};

    try {
      final response = await http.post(
        Uri.parse(_mapUrl),
        headers: {'Content-Type': 'text/plain;charset=utf-8'},
        body: jsonEncode(payload),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception("HTTP error! status: ${response.statusCode}");
      }
      return jsonDecode(response.body);
    } catch (e) {
      web.console.error("AppsScriptService error [$action]: $e".toJS);
      rethrow;
    }
  }

  Future<List<String>> getPlaceSuggestions(String inputToken) async {
    try {
      final res = await _callAction('getPlaceSuggestions', {'inputToken': inputToken});
      if (res is Map && res['success'] == true && res['suggestions'] is List) {
        return (res['suggestions'] as List).map((e) => e.toString()).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<dynamic> processLocationAndMetrics(double originLat, double originLng, String destinationQuery) async {
    return _callAction('processLocationAndMetrics', {
      'originLat': originLat,
      'originLng': originLng,
      'destinationQuery': destinationQuery,
    });
  }

  Future<dynamic> processPinDropMetrics(double originLat, double originLng, double pinLat, double pinLng) async {
    return _callAction('processPinDropMetrics', {
      'originLat': originLat,
      'originLng': originLng,
      'pinLat': pinLat,
      'pinLng': pinLng,
    });
  }
}
