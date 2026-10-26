import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

class ProductionApiService {
  static ProductionApiService? _instance;
  final String _baseUrl = 'https://api.antinna.in';

  static ProductionApiService getInstance() {
    _instance ??= ProductionApiService();
    return _instance!;
  }

  Future<dynamic> _request(String method, String path, [dynamic body]) async {
    final clientId = web.window.localStorage.getItem('antinna_client_id') ?? '';

    // Get firebase token if available on window
    String token = '';
    try {
      final fbToken = (web.window as dynamic).firebaseAuthToken;
      final fbAuth = (web.window as dynamic).firebaseAuth;
      token = fbToken?.toString() ?? fbAuth?.currentUser?.accessToken?.toString() ?? '';
    } catch (_) {}

    final headers = {
      'Content-Type': 'application/json',
      'X-Antinna-Client-Id': clientId,
      'Authorization': 'Bearer $token',
    };

    final uri = Uri.parse('$_baseUrl$path');
    http.Response response;

    try {
      if (method == 'POST') {
        response = await http.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
      } else {
        response = await http.get(uri, headers: headers);
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception("API error! status: ${response.statusCode}");
      }
      return jsonDecode(response.body);
    } catch (e) {
      web.console.error("ProductionApiService error [$path]: $e".toJS);
      rethrow;
    }
  }

  Future<dynamic> createOrder(dynamic order) async {
    return _request('POST', '/orders', order);
  }

  Future<dynamic> recordPayment(dynamic paymentData) async {
    return _request('POST', '/payments', paymentData);
  }

  Future<dynamic> isOrderPaid(String orderId) async {
    return _request('GET', '/orders/$orderId/status');
  }

  Future<dynamic> listNotifications({int page = 1, int pageSize = 20}) async {
    return _request('GET', '/notifications?page=$page&pageSize=$pageSize');
  }
}
