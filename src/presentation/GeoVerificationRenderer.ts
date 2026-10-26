import { UIManager } from './UIManager';
import { AppsScriptService } from '../infrastructure/AppsScriptService';
import { LocationManager } from '../core/LocationManager';

export class GeoVerificationRenderer {
  private map: any;
  private targetMarker: any;
  private debounceTimer: any;
  private appsScriptService = AppsScriptService.getInstance();
  private currentDeviceLat: number = 28.52785;
  private currentDeviceLng: number = 76.08361;
  private isAddressModified: boolean = false;

  constructor(locationManager: LocationManager) {
    const loc = locationManager.getData();
    if (loc.lat) this.currentDeviceLat = loc.lat;
    if (loc.lon) this.currentDeviceLng = loc.lon;
  }

  public renderPopup(): void {
    let modal = UIManager.el('antinna-geo-modal');
    if (!modal) {
      modal = document.createElement('div');
      modal.id = 'antinna-geo-modal';
      modal.className = 'antinna-geo-backdrop';
      modal.innerHTML = `
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

          <button id="antinna-geo-finalize-btn" class="v-btn active" style="width:100%; margin-top:20px; display:none; align-items:center; justify-content:center; gap:10px;">
            <span class="antinna-spinner"></span>
            <span class="btn-text">Finalize Order</span>
          </button>
        </div>
      `;
      document.body.appendChild(modal);
      UIManager.injectModalStyles();
      this.setupListeners();
    }

    modal.classList.add('active');
    this.initMap();
  }

  private setupListeners(): void {
    const input = UIManager.el<HTMLInputElement>('antinna-geo-search');
    if (input) {
      input.oninput = (e) => this.handleTypeAhead((e.target as HTMLInputElement).value);
    }

    const formInputs = ['geo-extendedAddress', 'geo-streetAddress', 'geo-postalCode'];
    formInputs.forEach(id => {
        const el = UIManager.el(id);
        if (el) el.oninput = () => {
            if (id !== 'geo-postalCode') this.isAddressModified = true;
            this.validateAddressForm();
        };
    });

    document.addEventListener('click', (e) => {
      const dropdown = UIManager.el('antinna-geo-dropdown');
      if (dropdown && e.target !== input) {
        dropdown.style.display = 'none';
      }
    });

    const finalizeBtn = UIManager.el('antinna-geo-finalize-btn');
    if (finalizeBtn) {
      finalizeBtn.onclick = async () => {
        try {
            this.setFinalizeLoading(true);
            // Simulate a small delay for API feel
            await new Promise(r => setTimeout(r, 800));

            const deliveryData = this.collectDeliveryData();

            (window as any).AntinnaEngine.setOrderDelivery(deliveryData);

            this.setFinalizeLoading(false);
            (window as any).AntinnaEngine.showOrderSummary();
        } catch (e) {
            console.error("Error in finalizeBtn.onclick:", e);
        }
      };
    }
  }

  private setFinalizeLoading(loading: boolean): void {
      const btn = UIManager.el('antinna-geo-finalize-btn');
      if (btn) btn.classList.toggle('loading', loading);
  }

  private validateAddressForm(): void {
      const extended = UIManager.el<HTMLInputElement>('geo-extendedAddress')?.value.trim();
      const street = UIManager.el<HTMLInputElement>('geo-streetAddress')?.value.trim();
      const pin = UIManager.el<HTMLInputElement>('geo-postalCode')?.value.trim();

      const finalizeBtn = UIManager.el('antinna-geo-finalize-btn');
      if (finalizeBtn) {
          const isValid = !!(extended && street && pin && pin.length >= 6);
          finalizeBtn.style.display = isValid ? 'flex' : 'none';
      }
  }

  private collectDeliveryData(): any {
      const pos = this.targetMarker?.getLatLng();
      const lat = pos ? pos.lat : ((window as any).lastGeoResponse?.lat || 0);
      const lng = pos ? pos.lng : ((window as any).lastGeoResponse?.lng || 0);

      return {
          "@type": "ParcelDelivery",
          "deliveryName": "Standard Handheld Delivery",
          "deliveryAddress": {
              "@type": "PostalAddress",
              "extendedAddress": UIManager.el<HTMLInputElement>('geo-extendedAddress')?.value,
              "streetAddress": UIManager.el<HTMLInputElement>('geo-streetAddress')?.value,
              "addressLocality": UIManager.el<HTMLInputElement>('geo-locality')?.value,
              "addressRegion": (window as any).lastGeoResponse?.addressDetails?.addressRegion || "HR",
              "postalCode": UIManager.el<HTMLInputElement>('geo-postalCode')?.value,
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
                      "latitude": String(lat),
                      "longitude": String(lng)
                  }
              }
          }
      };
  }

  private async initMap(): Promise<void> {
    await UIManager.injectLeaflet();
    const L = (window as any).L;
    if (!L) return;

    const center: [number, number] = [this.currentDeviceLat, this.currentDeviceLng];

    if (!this.map) {
      const satellite = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
          attribution: 'Tiles &copy; Esri'
      });
      const labels = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}');
      const streets = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
          attribution: '© OpenStreetMap contributors'
      });

      this.map = L.map(UIManager.el("antinna-geo-map-canvas"), {
          layers: [satellite, labels]
      }).setView(center, 13);

      const baseMaps = {
          "Satellite Hybrid": L.layerGroup([satellite, labels]),
          "Streets": streets
      };
      L.control.layers(baseMaps).addTo(this.map);

      this.targetMarker = L.marker(center, {
        draggable: true,
        title: "Delivery Location"
      }).addTo(this.map);

      this.map.on('click', (e: any) => {
        this.handleManualPinPosition(e.latlng.lat, e.latlng.lng);
      });

      this.targetMarker.on('dragend', (e: any) => {
        const pos = e.target.getLatLng();
        this.handleManualPinPosition(pos.lat, pos.lng);
      });
    } else {
        this.map.setView(center, 13);
        this.targetMarker.setLatLng(center);
    }

    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(pos => {
        this.currentDeviceLat = pos.coords.latitude;
        this.currentDeviceLng = pos.coords.longitude;
        const loc: [number, number] = [this.currentDeviceLat, this.currentDeviceLng];
        this.map.setView(loc, 13);
        this.targetMarker.setLatLng(loc);
        UIManager.setContent('antinna-geo-status', "Position synchronized.");
      });
    }
  }

  private async handleManualPinPosition(lat: number, lng: number): Promise<void> {
    if (this.targetMarker) {
        this.targetMarker.setLatLng([lat, lng]);
    }
    UIManager.setContent('antinna-geo-status', "Pin dropped. Computing metrics...");

    try {
      // GAS expects originLng/pinLng
      const response = await this.appsScriptService.processPinDropMetrics(this.currentDeviceLat, this.currentDeviceLng, lat, lng);
      this.updateTelemetryUI(response);
    } catch (e) {
      UIManager.setContent('antinna-geo-status', "Error computing metrics.");
    }
  }

  private handleTypeAhead(value: string): void {
    clearTimeout(this.debounceTimer);
    const dropdown = UIManager.el('antinna-geo-dropdown');
    if (!dropdown) return;

    if (value.length < 3) {
      dropdown.innerHTML = "";
      dropdown.style.display = 'none';
      return;
    }

    this.debounceTimer = setTimeout(async () => {
      try {
        const suggestions = await this.appsScriptService.getPlaceSuggestions(value);
        this.populateDropdown(suggestions);
      } catch (e) {}
    }, 400);
  }

  private populateDropdown(suggestions: string[]): void {
    const dropdown = UIManager.el('antinna-geo-dropdown');
    if (!dropdown) return;
    dropdown.innerHTML = "";

    if (suggestions.length === 0) {
      dropdown.style.display = 'none';
      return;
    }

    suggestions.forEach(text => {
      const item = document.createElement('div');
      item.className = "antinna-geo-dropdown-item";
      item.innerText = text;
      item.onclick = async () => {
        const input = UIManager.el<HTMLInputElement>('antinna-geo-search');
        if (input) input.value = text;
        dropdown.style.display = 'none';
        UIManager.setContent('antinna-geo-status', "Resolving coordinates...");

        try {
          this.isAddressModified = false; // Reset on new search selection
          const response = await this.appsScriptService.processLocationAndMetrics(this.currentDeviceLat, this.currentDeviceLng, text);
          if (response.success) {
            const newPos: [number, number] = [response.lat, response.lng];
            this.map.setView(newPos, 15);
            this.targetMarker.setLatLng(newPos);
            this.updateTelemetryUI(response);
          }
        } catch (e) {}
      };
      dropdown.appendChild(item);
    });
    dropdown.style.display = 'block';
  }

  private updateTelemetryUI(response: any): void {
    if (response.success) {
      (window as any).lastGeoResponse = response;
      UIManager.setContent('antinna-geo-status', "Location verified.");
      UIManager.setContent('antinna-geo-clean-address', response.address);
      UIManager.setContent('antinna-geo-dist', response.distance);
      UIManager.setContent('antinna-geo-dur', response.duration);
      const targetLat = Number(response.lat || 0);
      const targetLng = Number(response.lng || response.lon || 0);
      UIManager.setContent('antinna-geo-tag-target', `${targetLat.toFixed(4)}, ${targetLng.toFixed(4)}`);
      UIManager.setContent('antinna-geo-tag-current', `${this.currentDeviceLat.toFixed(4)}, ${this.currentDeviceLng.toFixed(4)}`);

      UIManager.toggleClass("#antinna-geo-metrics", "hidden", false);
      UIManager.el("antinna-geo-metrics")!.style.display = "block";

      const form = UIManager.el("antinna-geo-address-form");
      if (form) {
          form.style.display = "block";
          if (response.addressDetails) {
              const d = response.addressDetails;
              const extInput = UIManager.el<HTMLInputElement>('geo-extendedAddress')!;
              const streetInput = UIManager.el<HTMLInputElement>('geo-streetAddress')!;

              if (!this.isAddressModified) {
                  extInput.value = d.extendedAddress || "";
                  streetInput.value = d.streetAddress || "";
              }

              UIManager.el<HTMLInputElement>('geo-locality')!.value = d.addressLocality || "";
              UIManager.el<HTMLInputElement>('geo-postalCode')!.value = d.postalCode || "";
          }
          this.validateAddressForm();
      }

      // Save verified location to state
      (window as any).AntinnaEngine.setVerifiedLocation(response);
    }
  }
}
