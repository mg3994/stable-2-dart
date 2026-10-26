import { LocationManager } from '../core/LocationManager';
import { UIManager } from './UIManager';

export class LocationRenderer {
  constructor(private locationManager: LocationManager) {}

  init(): void {
    const data = this.locationManager.getData();
    if (!data.pin && !data.city) {
      setTimeout(() => this.showModal(), 2000);
    }
    this.updateUI();
  }

  showModal(): void {
    UIManager.injectModalStyles();
    const backdrop = UIManager.el('loc-modal-backdrop');
    if (backdrop) {
        const data = this.locationManager.getData();
        const hasLocation = !!(data.pin || data.city);

        let clearBtn = UIManager.el('modal-clear-loc-btn');
        if (!clearBtn) {
            const footer = backdrop.querySelector('.antinna-geo-content') || backdrop.querySelector('.modal-content');
            if (footer) {
                clearBtn = document.createElement('button');
                clearBtn.id = 'modal-clear-loc-btn';
                clearBtn.className = 'btn-clear-loc';
                clearBtn.innerHTML = 'Clear Location';
                clearBtn.onclick = () => this.handleClearLocation();
                footer.appendChild(clearBtn);
            }
        }

        if (clearBtn) {
            clearBtn.style.display = hasLocation ? 'block' : 'none';
        }

        backdrop.classList.add('active');
    }
  }

  hideModal(): void {
    UIManager.el('loc-modal-backdrop')?.classList.remove('active');
  }

  updateUI(): void {
    const data = this.locationManager.getData();
    const display = UIManager.el<HTMLInputElement>('loc-display-v2');
    const pinInput = UIManager.el<HTMLInputElement>('modal-pin-input');

    const text = data.city ? (data.pin ? `${data.city}, ${data.pin}` : data.city) : (data.pin || "");
    if (display) display.value = text;
    if (pinInput) pinInput.value = data.pin || "";
  }

  async handleRequestLocation(): Promise<void> {
    if (!navigator.geolocation) {
      UIManager.showToast("Geolocation not supported", "error");
      return;
    }

    const btn = UIManager.query('.loc-btn');
    if (btn) {
        btn.classList.add('loading');
        if (!btn.querySelector('.antinna-spinner')) {
            const spinner = document.createElement('span');
            spinner.className = 'antinna-spinner';
            btn.appendChild(spinner); // Use append so it doesn't shift existing spans
        }
    }

    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        try {
            const { latitude, longitude } = pos.coords;
            const geoData = await this.locationManager.reverseGeocode(latitude, longitude);
            this.locationManager.setData({ lat: latitude, lon: longitude, ...geoData });
            this.updateUI();
            this.hideModal();
            UIManager.showToast(`Location set to ${geoData.city || 'your area'}`, "success");
        } catch (e) {
            UIManager.showToast("Failed to resolve address", "error");
        } finally {
            btn?.classList.remove('loading');
        }
      },
      (_err) => {
        UIManager.showToast("Location access denied", "error");
        btn?.classList.remove('loading');
      }
    );
  }

  async handleSetPin(): Promise<void> {
    const input = UIManager.el<HTMLInputElement>('modal-pin-input');
    if (input && input.value.length === 6) {
      const pin = input.value;
      UIManager.showToast("Verifying PIN...", "success");

      const geoData = await this.locationManager.lookupPin(pin);
      this.locationManager.setData({ pin, ...geoData });

      this.updateUI();
      this.hideModal();

      if (geoData.city) {
          UIManager.showToast(`Location set to ${geoData.city}`, "success");
      } else {
          UIManager.showToast("Location updated!", "success");
      }
    } else {
      UIManager.showToast("Enter a valid 6-digit PIN", "error");
    }
  }

  handleClearLocation(): void {
      this.locationManager.clear();
      this.updateUI();
      this.hideModal();
      UIManager.showToast("Location cleared", "success");
  }
}
