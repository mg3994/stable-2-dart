import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../types/app.dart';

class LocationManager {
  LocationData _data = LocationData();
  final String _storageKey = "antinna_location";

  LocationManager() {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    final saved = web.window.localStorage.getItem(_storageKey);
    if (saved != null && saved.isNotEmpty) {
      try {
        _data = LocationData.fromJson(jsonDecode(saved));
      } catch (_) {}
    }
  }

  void save() {
    web.window.localStorage.setItem(_storageKey, jsonEncode(_data.toJson()));
  }

  LocationData getData() {
    return _data;
  }

  void setData({double? lat, double? lon, String? pin, String? city}) {
    _data = LocationData(
      lat: lat ?? _data.lat,
      lon: lon ?? _data.lon,
      pin: pin ?? _data.pin,
      city: city ?? _data.city,
    );
    save();
  }

  void clear() {
    _data = LocationData();
    web.window.localStorage.removeItem(_storageKey);
  }

  Future<Map<String, dynamic>> reverseGeocode(double lat, double lon) async {
    try {
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json'),
        headers: {'User-Agent': 'Antinna-Blogger-Engine/1.0'},
      );
      final d = jsonDecode(response.body);
      if (d is Map && d.containsKey('address')) {
        final addr = d['address'];
        return {
          'pin': addr['postcode'] ?? _data.pin,
          'city': addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['state_district'],
        };
      }
    } catch (e) {
      web.console.error("Geocoding failed: $e".toJS);
    }
    return {};
  }

  Future<Map<String, dynamic>> lookupPin(String pin) async {
    try {
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?postalcode=$pin&country=India&format=json&addressdetails=1'),
        headers: {'User-Agent': 'Antinna-Blogger-Engine/1.0'},
      );
      final d = jsonDecode(response.body);
      if (d is List && d.isNotEmpty) {
        final first = d[0];
        final addr = first['address'] ?? {};
        return {
          'lat': double.tryParse(first['lat']?.toString() ?? ''),
          'lon': double.tryParse(first['lon']?.toString() ?? ''),
          'city': addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['state_district'] ?? addr['county'],
        };
      }
    } catch (e) {
      web.console.error("PIN lookup failed: $e".toJS);
    }
    return {'city': null, 'lat': null, 'lon': null};
  }
}
