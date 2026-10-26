import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../core/location_manager.dart';
import '../infrastructure/apps_script_service.dart';
import 'ui_manager.dart';

class GeoVerificationRenderer {
  dynamic _map;
  dynamic _targetMarker;
  Timer? _debounceTimer;
  final _appsScriptService = AppsScriptService.getInstance();
  double _currentDeviceLat = 28.52785;
  double _currentDeviceLng = 76.08361;

  GeoVerificationRenderer(LocationManager locationManager) {
    final loc = locationManager.getData();
    if (loc.lat != null) _currentDeviceLat = loc.lat!;
    if (loc.lon != null) _currentDeviceLng = loc.lon!;
  }

  void renderPopup() {
    var modal = UIManager.el('antinna-geo-modal');
    if (modal == null) {
      modal = web.document.createElement('div');
      modal.id = 'antinna-geo-modal';
      modal.className = 'antinna-geo-backdrop';
      modal.innerHTML = '''
        <div class="antinna-geo-content">
          <div class="antinna-geo-header">
            <h3>Destination Verification</h3>
            <button class="antinna-geo-close" onclick="document.getElementById('antinna-geo-modal').classList.remove('active')">&times;</button>
          </div>
          <p class="antinna-geo-subtitle">
            Type to search, choose from suggestions, <b>OR click directly on the map</b> to drop a custom pinpoint marker.
          </p>

          <div class="antinna-geo-search-container">
            <input id="antinna-geo-search" type="text" placeholder="Start typing address..." autocomplete="off">
            <div id="antinna-geo-dropdown" class="antinna-geo-dropdown"></div>
          </div>

          <div id="antinna-geo-status" class="antinna-geo-status">Detecting position...</div>

          <div id="antinna-geo-map-canvas"></div>

          <div id="antinna-geo-metrics" class="antinna-geo-metrics" style="display: none;">
            <strong>Target Location Context:</strong><br>
            <span id="antinna-geo-clean-address" style="color: #202124; font-weight: 600;"></span><br>

            <div style="margin-top:10px; display:grid; grid-template-columns: 1fr 1fr; gap:10px;">
                <div>📍 Target: <span class="antinna-geo-tag" id="antinna-geo-tag-target">0.0, 0.0</span></div>
                <div>📱 Current: <span class="antinna-geo-tag" id="antinna-geo-tag-current">0.0, 0.0</span></div>
            </div>
            <div style="margin-top:8px; font-weight:700; color:var(--accent);">
                Distance: <span id="antinna-geo-dist">--</span> | Duration: <span id="antinna-geo-dur">--</span>
            </div>
          </div>

          <div id="antinna-geo-address-form" style="display:none; margin-top:15px; border-top: 1px solid #eee; padding-top:15px;">
              <div style="display:grid; grid-template-columns: 1fr 1fr; gap:10px;">
                  <div class="v-group">
                      <span class="v-label">Flat/Plot/Building</span>
                      <input id="geo-extendedAddress" class="antinna-geo-input" placeholder="e.g. 3rd Floor, Plot 42"/>
                  </div>
                  <div class="v-group">
                      <span class="v-label">Street/Sector</span>
                      <input id="geo-streetAddress" class="antinna-geo-input" placeholder="e.g. Sector 14"/>
                  </div>
              </div>
              <div style="display:grid; grid-template-columns: 1fr 1fr; gap:10px; margin-top:10px;">
                  <div class="v-group">
                      <span class="v-label">City</span>
                      <input id="geo-locality" class="antinna-geo-input" readonly style="background:#f8f9fa;"/>
                  </div>
                  <div class="v-group">
                      <span class="v-label">Postal Code</span>
                      <input id="geo-postalCode" class="antinna-geo-input" placeholder="6-digit PIN"/>
                  </div>
              </div>
          </div>

          <button id="antinna-geo-finalize-btn" class="v-btn active" style="width:100%; margin-top:20px; display:none; justify-content:center; align-items:center;">
              <span class="antinna-spinner"></span>
              <span class="btn-text">Confirm Delivery Address</span>
          </button>
        </div>
      ''';
      web.document.body?.appendChild(modal);
      _setupListeners();
    }

    modal.classList.add('active');
    _initMap();
  }

  void _setupListeners() {
    final input = UIManager.el('antinna-geo-search') as web.HTMLInputElement?;
    if (input != null) {
      input.oninput = ((web.Event e) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () => _handleSearchInput(input.value));
      }).toJS;
    }

    final formInputs = ['geo-extendedAddress', 'geo-streetAddress', 'geo-postalCode'];
    for (final id in formInputs) {
      final el = UIManager.el(id);
      if (el != null) {
        (el as web.HTMLInputElement).oninput = ((web.Event e) {
          _validateAddressForm();
        }).toJS;
      }
    }

    final finalizeBtn = UIManager.el('antinna-geo-finalize-btn');
    if (finalizeBtn != null) {
      (finalizeBtn as web.HTMLElement).onclick = ((web.MouseEvent e) async {
        try {
          _setFinalizeLoading(true);
          await Future.delayed(const Duration(milliseconds: 800));

          final deliveryData = _collectDeliveryData();
          try {
            (web.window as dynamic).AntinnaEngine?.setOrderDelivery(deliveryData);
          } catch (_) {}

          _setFinalizeLoading(false);
          try {
            (web.window as dynamic).AntinnaEngine?.showOrderSummary();
          } catch (_) {}
        } catch (e) {
          web.console.error("Error finalizing address: $e".toJS);
        }
      }).toJS;
    }
  }

  void _setFinalizeLoading(bool loading) {
    final btn = UIManager.el('antinna-geo-finalize-btn');
    if (btn != null) {
      if (loading) btn.classList.add('loading');
      else btn.classList.remove('loading');
    }
  }

  void _validateAddressForm() {
    final extended = (UIManager.el('geo-extendedAddress') as web.HTMLInputElement?)?.value.trim() ?? '';
    final street = (UIManager.el('geo-streetAddress') as web.HTMLInputElement?)?.value.trim() ?? '';
    final pin = (UIManager.el('geo-postalCode') as web.HTMLInputElement?)?.value.trim() ?? '';

    final finalizeBtn = UIManager.el('antinna-geo-finalize-btn');
    if (finalizeBtn != null) {
      final isValid = extended.isNotEmpty && street.isNotEmpty && pin.isNotEmpty && pin.length >= 6;
      (finalizeBtn as web.HTMLElement).style.display = isValid ? 'flex' : 'none';
    }
  }

  Map<String, dynamic> _collectDeliveryData() {
    final win = web.window as dynamic;
    final lastRes = win.lastGeoResponse;

    double lat = _currentDeviceLat;
    double lng = _currentDeviceLng;

    if (_targetMarker != null) {
      final latLng = _targetMarker.getLatLng();
      lat = (latLng.lat as num).toDouble();
      lng = (latLng.lng as num).toDouble();
    } else if (lastRes != null) {
      lat = (lastRes.lat as num).toDouble();
      lng = (lastRes.lng as num).toDouble();
    }

    return {
      "@type": "ParcelDelivery",
      "deliveryName": "Standard Handheld Delivery",
      "deliveryAddress": {
        "@type": "PostalAddress",
        "extendedAddress": (UIManager.el('geo-extendedAddress') as web.HTMLInputElement?)?.value,
        "streetAddress": (UIManager.el('geo-streetAddress') as web.HTMLInputElement?)?.value,
        "addressLocality": (UIManager.el('geo-locality') as web.HTMLInputElement?)?.value,
        "addressRegion": lastRes?.addressDetails?.addressRegion ?? "HR",
        "postalCode": (UIManager.el('geo-postalCode') as web.HTMLInputElement?)?.value,
        "addressCountry": "IN"
      },
      "deliveryStatus": {
        "@type": "DeliveryEvent",
        "name": "Final Destination Drop-off",
        "location": {
          "@type": "Place",
          "name": "Exact Delivery Coordinates",
          "geo": {
            "@type": "GeoCoordinates",
            "latitude": lat.toString(),
            "longitude": lng.toString()
          }
        }
      }
    };
  }

  Future<void> _initMap() async {
    await UIManager.injectLeaflet();
    final win = web.window as dynamic;
    final L = win.L;
    if (L == null) return;

    final center = [ _currentDeviceLat, _currentDeviceLng ];

    if (_map == null) {
      final satellite = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}');
      final labels = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}');

      _map = L.map(UIManager.el("antinna-geo-map-canvas"), {
        'layers': [satellite, labels]
      }).setView(center, 13);

      _targetMarker = L.marker(center, {
        'draggable': true,
        'title': "Delivery Location"
      }).addTo(_map);

      _map.on('click', ((JSObject e) {
        final latLng = (e as dynamic).latlng;
        _handleManualPinPosition((latLng.lat as num).toDouble(), (latLng.lng as num).toDouble());
      }).toJS);

      _targetMarker.on('dragend', ((JSObject e) {
        final pos = (e as dynamic).target.getLatLng();
        _handleManualPinPosition((pos.lat as num).toDouble(), (pos.lng as num).toDouble());
      }).toJS);
    } else {
      _map.setView(center, 13);
      _targetMarker.setLatLng(center);
    }

    final nav = web.window.navigator;
    final geo = (nav as dynamic).geolocation;
    if (geo != null) {
      geo.getCurrentPosition(((JSObject pos) {
        final coords = (pos as dynamic).coords;
        _currentDeviceLat = (coords.latitude as num).toDouble();
        _currentDeviceLng = (coords.longitude as num).toDouble();
        final loc = [ _currentDeviceLat, _currentDeviceLng ];
        _map.setView(loc, 13);
        _targetMarker.setLatLng(loc);
        UIManager.setContent('antinna-geo-status', "Position synchronized.");
      }).toJS);
    }
  }

  Future<void> _handleManualPinPosition(double lat, double lng) async {
    if (_targetMarker != null) {
      _targetMarker.setLatLng([lat, lng]);
    }
    UIManager.setContent('antinna-geo-status', "Pin dropped. Computing metrics...");

    try {
      final res = await _appsScriptService.processPinDropMetrics(_currentDeviceLat, _currentDeviceLng, lat, lng);
      _renderMetrics(res);
    } catch (e) {
      UIManager.setContent('antinna-geo-status', "Failed to compute pin metrics.");
    }
  }

  Future<void> _handleSearchInput(String val) async {
    if (val.length < 3) return;

    final dropdown = UIManager.el('antinna-geo-dropdown');
    if (dropdown == null) return;

    final suggestions = await _appsScriptService.getPlaceSuggestions(val);
    if (suggestions.isEmpty) {
      (dropdown as web.HTMLElement).style.display = 'none';
      return;
    }

    dropdown.innerHTML = suggestions.map((s) => '''
      <div class="antinna-geo-dropdown-item" data-val="${s.replaceAll('"', '&quot;')}">$s</div>
    ''').join('');

    final items = dropdown.querySelectorAll('.antinna-geo-dropdown-item');
    for (int i = 0; i < items.length; i++) {
      final item = items.item(i) as web.HTMLElement?;
      if (item != null) {
        item.onclick = ((web.MouseEvent e) {
          final selectVal = item.getAttribute('data-val') ?? '';
          _selectSuggestion(selectVal);
          (dropdown as web.HTMLElement).style.display = 'none';
        }).toJS;
      }
    }

    (dropdown as web.HTMLElement).style.display = 'block';
  }

  Future<void> _selectSuggestion(String query) async {
    final input = UIManager.el('antinna-geo-search') as web.HTMLInputElement?;
    if (input != null) input.value = query;

    UIManager.setContent('antinna-geo-status', "Resolving destination...");

    try {
      final res = await _appsScriptService.processLocationAndMetrics(_currentDeviceLat, _currentDeviceLng, query);
      _renderMetrics(res);
    } catch (e) {
      UIManager.setContent('antinna-geo-status', "Failed to resolve destination.");
    }
  }

  void _renderMetrics(dynamic res) {
    if (res == null || res['success'] != true) {
      UIManager.setContent('antinna-geo-status', res?['error']?.toString() ?? "Could not find metrics");
      return;
    }

    (web.window as dynamic).lastGeoResponse = res;

    final metrics = UIManager.el('antinna-geo-metrics');
    final form = UIManager.el('antinna-geo-address-form');
    if (metrics != null) (metrics as web.HTMLElement).style.display = 'block';
    if (form != null) (form as web.HTMLElement).style.display = 'block';

    UIManager.setContent('antinna-geo-clean-address', res['address']?.toString() ?? '');
    UIManager.setContent('antinna-geo-tag-target', "${res['lat']}, ${res['lng']}");
    UIManager.setContent('antinna-geo-tag-current', "$_currentDeviceLat, $_currentDeviceLng");
    UIManager.setContent('antinna-geo-dist', res['distance']?.toString() ?? '--');
    UIManager.setContent('antinna-geo-dur', res['duration']?.toString() ?? '--');

    if (_map != null && res['lat'] != null && res['lng'] != null) {
      final target = [ (res['lat'] as num).toDouble(), (res['lng'] as num).toDouble() ];
      _map.setView(target, 15);
      _targetMarker.setLatLng(target);
    }

    final localityInput = UIManager.el('geo-locality') as web.HTMLInputElement?;
    final postalInput = UIManager.el('geo-postalCode') as web.HTMLInputElement?;

    if (localityInput != null) {
      localityInput.value = res['addressDetails']?['addressLocality']?.toString() ?? res['city']?.toString() ?? '';
    }
    if (postalInput != null && postalInput.value.isEmpty) {
      postalInput.value = res['addressDetails']?['postalCode']?.toString() ?? res['postalCode']?.toString() ?? '';
    }

    UIManager.setContent('antinna-geo-status', "Verified target location.");
    _validateAddressForm();
  }
}
