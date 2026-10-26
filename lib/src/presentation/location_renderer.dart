import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../core/location_manager.dart';
import 'ui_manager.dart';

class LocationRenderer {
  final LocationManager locationManager;

  LocationRenderer(this.locationManager);

  void init() {
    final data = locationManager.getData();
    if ((data.pin == null || data.pin!.isEmpty) && (data.city == null || data.city!.isEmpty)) {
      Timer(const Duration(seconds: 2), () => showModal());
    }
    updateUI();
  }

  void showModal() {
    UIManager.injectModalStyles();
    final backdrop = UIManager.el('loc-modal-backdrop');
    if (backdrop != null) {
      final data = locationManager.getData();
      final hasLocation = (data.pin != null && data.pin!.isNotEmpty) || (data.city != null && data.city!.isNotEmpty);

      var clearBtn = UIManager.el('modal-clear-loc-btn');
      if (clearBtn == null) {
        final footer = backdrop.querySelector('.antinna-geo-content') ?? backdrop.querySelector('.modal-content');
        if (footer != null) {
          clearBtn = web.document.createElement('button') as web.HTMLButtonElement;
          clearBtn.id = 'modal-clear-loc-btn';
          clearBtn.className = 'btn-clear-loc';
          clearBtn.innerHTML = 'Clear Location';
          (clearBtn as web.HTMLButtonElement).onclick = ((web.MouseEvent e) => handleClearLocation()).toJS;
          footer.appendChild(clearBtn);
        }
      }

      if (clearBtn != null) {
        (clearBtn as web.HTMLElement).style.display = hasLocation ? 'block' : 'none';
      }

      backdrop.classList.add('active');
    }
  }

  void hideModal() {
    UIManager.el('loc-modal-backdrop')?.classList.remove('active');
  }

  void updateUI() {
    final data = locationManager.getData();
    final display = UIManager.el('loc-display-v2') as web.HTMLInputElement?;
    final pinInput = UIManager.el('modal-pin-input') as web.HTMLInputElement?;

    final text = data.city != null && data.city!.isNotEmpty
        ? (data.pin != null && data.pin!.isNotEmpty ? '${data.city}, ${data.pin}' : data.city!)
        : (data.pin ?? "");

    if (display != null) display.value = text;
    if (pinInput != null) pinInput.value = data.pin ?? "";
  }

  Future<void> handleRequestLocation() async {
    final nav = web.window.navigator;
    final geo = (nav as dynamic).geolocation;
    if (geo == null) {
      UIManager.showToast("Geolocation not supported", "error");
      return;
    }

    final btn = UIManager.query('.loc-btn');
    if (btn != null) {
      btn.classList.add('loading');
      if (btn.querySelector('.antinna-spinner') == null) {
        final spinner = web.document.createElement('span');
        spinner.className = 'antinna-spinner';
        btn.appendChild(spinner);
      }
    }

    final successCallback = ((JSObject pos) async {
      try {
        final coords = (pos as dynamic).coords;
        final double latitude = (coords.latitude as num).toDouble();
        final double longitude = (coords.longitude as num).toDouble();

        final geoData = await locationManager.reverseGeocode(latitude, longitude);
        locationManager.setData(lat: latitude, lon: longitude, pin: geoData['pin']?.toString(), city: geoData['city']?.toString());
        updateUI();
        hideModal();
        UIManager.showToast("Location set to ${geoData['city'] ?? 'your area'}", "success");
      } catch (e) {
        UIManager.showToast("Failed to resolve address", "error");
      } finally {
        btn?.classList.remove('loading');
      }
    }).toJS;

    final errorCallback = ((JSObject err) {
      UIManager.showToast("Location access denied", "error");
      btn?.classList.remove('loading');
    }).toJS;

    geo.getCurrentPosition(successCallback, errorCallback);
  }

  Future<void> handleSetPin() async {
    final input = UIManager.el('modal-pin-input') as web.HTMLInputElement?;
    if (input != null && input.value.length == 6) {
      final pin = input.value;
      UIManager.showToast("Verifying PIN...", "success");

      final geoData = await locationManager.lookupPin(pin);
      locationManager.setData(
        pin: pin,
        lat: geoData['lat'] != null ? (geoData['lat'] as num).toDouble() : null,
        lon: geoData['lon'] != null ? (geoData['lon'] as num).toDouble() : null,
        city: geoData['city']?.toString(),
      );

      updateUI();
      hideModal();

      if (geoData['city'] != null) {
        UIManager.showToast("Location set to ${geoData['city']}", "success");
      } else {
        UIManager.showToast("Location updated!", "success");
      }
    } else {
      UIManager.showToast("Enter a valid 6-digit PIN", "error");
    }
  }

  void handleClearLocation() {
    locationManager.clear();
    updateUI();
    hideModal();
    UIManager.showToast("Location cleared", "success");
  }
}
