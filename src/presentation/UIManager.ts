export class UIManager {
  static el<T extends HTMLElement>(id: string): T | null {
    return document.getElementById(id) as T;
  }

  static query<T extends HTMLElement>(selector: string): T | null {
    return document.querySelector(selector) as T;
  }

  static setContent(idOrSelector: string, content: string): void {
    const e = this.el(idOrSelector) || this.query(idOrSelector);
    if (e) e.textContent = content;
  }

  static setHtml(idOrSelector: string, html: string): void {
    const e = this.el(idOrSelector) || this.query(idOrSelector);
    if (e) e.innerHTML = html;
  }

  static toggleClass(idOrSelector: string, className: string, force?: boolean): void {
    const e = this.el(idOrSelector) || this.query(idOrSelector);
    if (e) e.classList.toggle(className, force);
  }

  static injectModalStyles(): void {
    if (document.getElementById('antinna-modal-styles')) return;
    const style = document.createElement('style');
    style.id = 'antinna-modal-styles';
    style.textContent = `
      @keyframes slideUp { from { transform: translateY(20px); opacity: 0; } to { transform: translateY(0); opacity: 1; } }
      @keyframes fadeOut { from { opacity: 1; } to { opacity: 0; } }
      .toast-container { position: fixed; bottom: 24px; right: 24px; z-index: 9999; display: flex; flex-direction: column; align-items: flex-end; pointer-events: none; }
      .antinna-geo-backdrop { position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; background: rgba(0,0,0,0.6); backdrop-filter: blur(4px); z-index: 4000; display: none; align-items: center; justify-content: center; opacity: 0; transition: opacity 0.3s; pointer-events: none; }
      .antinna-geo-backdrop.active { display: flex; opacity: 1; pointer-events: auto; }
      .antinna-geo-content { background: var(--card); width: 95%; max-width: 500px; padding: 25px; border-radius: 20px; box-shadow: 0 20px 40px rgba(0,0,0,0.3); position: relative; max-height: 90vh; overflow-y: auto; color: var(--text); }
      .antinna-geo-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; }
      .antinna-geo-header h3 { margin: 0; font-size: 1.3rem; font-weight: 800; }
      .antinna-geo-close { background: none; border: none; font-size: 1.8rem; cursor: pointer; color: var(--text); opacity: 0.5; }
      .antinna-geo-subtitle { font-size: 0.85rem; color: #777; margin: 0 0 15px 0; }
      .antinna-geo-search-container { position: relative; width: 100%; }
      .antinna-geo-search-container input { width: 100%; padding: 12px 15px; border-radius: 10px; border: 1px solid #ddd; outline: none; font-size: 1rem; background: var(--bg); color: var(--text); box-sizing: border-box; }
      html.dark .antinna-geo-search-container input { border-color: #334155; }
      .antinna-geo-dropdown { position: absolute; top: 100%; left: 0; width: 100%; background: var(--card); border: 1px solid #ddd; border-radius: 0 0 10px 10px; box-shadow: 0 10px 20px rgba(0,0,0,0.1); max-height: 200px; overflow-y: auto; z-index: 1001; display: none; }
      html.dark .antinna-geo-dropdown { border-color: #334155; }
      .antinna-geo-dropdown-item { padding: 12px; cursor: pointer; font-size: 0.9rem; border-bottom: 1px solid #eee; }
      html.dark .antinna-geo-dropdown-item { border-bottom-color: #334155; }
      .antinna-geo-dropdown-item:hover { background: #f0f0f0; color: var(--accent); }
      html.dark .antinna-geo-dropdown-item:hover { background: #334155; }
      #antinna-geo-map-canvas { width: 100%; height: 250px; border-radius: 12px; margin-top: 15px; background: #eee; border: 1px solid #ddd; }
      html.dark #antinna-geo-map-canvas { border-color: #334155; background: #0f172a; }
      .antinna-geo-status { margin-top: 8px; font-size: 0.8rem; color: var(--accent); font-weight: 600; min-height: 18px; }
      .antinna-geo-metrics { background: #f0f7ff; padding: 15px; margin-top: 15px; border-radius: 12px; border-left: 5px solid #34a853; font-size: 0.9rem; }
      html.dark .antinna-geo-metrics { background: #1e293b; border-color: #059669; }
      .antinna-geo-tag { font-family: monospace; font-size: 0.75rem; background: #e2e8f0; padding: 2px 6px; border-radius: 4px; color: #475569; }
      html.dark .antinna-geo-tag { background: #334155; color: #cbd5e1; }
      .antinna-geo-input { width: 100%; padding: 10px; border-radius: 8px; border: 1px solid #ddd; font-size: 0.9rem; outline: none; background: var(--bg); color: var(--text); }
      html.dark .antinna-geo-input { border-color: #334155; }

      .antinna-spinner { display: none; width: 22px; height: 22px; border: 3px solid rgba(0,0,0,0.1); border-radius: 50%; border-top-color: #e67e22; animation: antinna-spin 0.8s linear infinite; box-sizing: border-box; }
      @keyframes antinna-spin {
          from { transform: translate(-50%, -50%) rotate(0deg); }
          to { transform: translate(-50%, -50%) rotate(360deg); }
      }

      .v-btn.loading { pointer-events: none; opacity: 0.8; position: relative; }
      .v-btn.loading .antinna-spinner { display: block !important; position: absolute; left: 50%; top: 50%; border-top-color: #fff; margin: 0; }
      .v-btn.loading .btn-text { visibility: hidden; }

      .loc-btn.loading { pointer-events: none; position: relative; color: transparent !important; font-size: 0 !important; }
      .loc-btn.loading * { visibility: hidden; }
      .loc-btn.loading .antinna-spinner { display: block !important; visibility: visible; position: absolute; left: 50%; top: 50%; border-top-color: #e67e22; margin: 0; }

      .antinna-input-prefixed { display: flex; align-items: center; border: 1px solid #ddd; border-radius: 12px; position: relative; background: var(--bg); }
      html.dark .antinna-input-prefixed { border-color: #334155; }
      .antinna-input-prefix { padding: 0 15px; background: #eee; height: 100%; display: flex; align-items: center; font-weight: 700; color: #555; border-right: 1px solid #ddd; border-radius: 12px 0 0 12px; }
      html.dark .antinna-input-prefix { background: #334155; color: #cbd5e1; border-right-color: #475569; }
      .antinna-input-prefixed input { border: none !important; flex: 1; border-radius: 0 12px 12px 0 !important; }

      .antinna-country-selector { position: relative; display: flex; align-items: center; gap: 10px; padding: 0 18px; height: 48px; cursor: pointer; border-right: 1px solid #eee; background: var(--card); transition: all 0.2s; border-radius: 12px 0 0 12px; font-weight: 700; }
      html.dark .antinna-country-selector { border-right-color: #334155; }
      .antinna-country-selector:hover { background: var(--bg); }

      .antinna-country-chevron { border: solid #888; border-width: 0 2px 2px 0; display: inline-block; padding: 2px; transform: rotate(45deg); margin-left: 4px; transition: transform 0.3s; }
      .antinna-country-selector.active .antinna-country-chevron { transform: rotate(-135deg) translateY(-2px); }

      .antinna-country-list { position: absolute; top: calc(100% + 10px); left: 0; width: 240px; background: var(--card); border: 1px solid rgba(0,0,0,0.08); border-radius: 16px; box-shadow: 0 15px 35px rgba(0,0,0,0.15); z-index: 5000; display: block; opacity: 0; pointer-events: none; transform: translateY(-10px); transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1); max-height: 300px; overflow-y: auto; scrollbar-width: thin; }
      html.dark .antinna-country-list { border-color: #334155; box-shadow: 0 15px 35px rgba(0,0,0,0.4); }
      .antinna-country-list.active { opacity: 1; pointer-events: auto; transform: translateY(0); }

      .antinna-country-item { display: flex; align-items: center; gap: 14px; padding: 14px 18px; font-size: 0.95rem; transition: all 0.2s; cursor: pointer; border-bottom: 1px solid rgba(0,0,0,0.03); }
      html.dark .antinna-country-item { border-bottom-color: #334155; }
      .antinna-country-item:last-child { border-bottom: none; }
      .antinna-country-item:hover { background: var(--bg); transform: translateX(5px); }
      .antinna-country-flag { font-size: 1.2rem; }
      .antinna-country-name { flex: 1; color: var(--text); }
      .antinna-country-code { color: var(--accent); font-weight: 800; font-size: 0.85rem; }

      .antinna-search-dropdown {
        position: absolute; top: 100%; left: 0; right: 0; background: var(--card);
        border: 1px solid rgba(0,0,0,0.1); border-radius: 0 0 12px 12px;
        box-shadow: 0 10px 25px rgba(0,0,0,0.1); z-index: 9999; display: none;
        max-height: 300px; overflow-y: auto; margin-top: 0; width: 100%; box-sizing: border-box;
      }
      .antinna-search-item { padding: 12px 15px; cursor: pointer; border-bottom: 1px solid rgba(0,0,0,0.05); font-size: 0.9rem; transition: background 0.2s; color: var(--text); }
      .antinna-search-item:hover, .antinna-search-item.active { background: rgba(0,0,0,0.05); color: var(--accent); }

      .btn-clear-loc {
        margin-top: 15px; width: 100%; padding: 12px; border-radius: 10px;
        background: rgba(255, 59, 48, 0.1); color: #ff3b30;
        border: 1px solid rgba(255, 59, 48, 0.2); cursor: pointer;
        font-weight: 700; transition: all 0.2s;
      }
      .btn-clear-loc:hover { background: rgba(255, 59, 48, 0.2); }

      .condition-badge { display: inline-block; padding: 4px 12px; border-radius: 6px; font-size: 0.7rem; font-weight: 900; background: #f1f5f9; color: #64748b; text-transform: uppercase; border: 1px solid #e2e8f0; margin-left: 10px; vertical-align: middle; letter-spacing: 0.5px; }
      .condition-badge.cond-new { background: #e0f2fe; color: #0369a1; border-color: #bae6fd; }
      .condition-badge.cond-refurbished { background: #fef3c7; color: #92400e; border-color: #fde68a; }
      .condition-badge.cond-used { background: #f1f5f9; color: #475569; border-color: #e2e8f0; }
      .condition-badge.cond-damaged { background: #fee2e2; color: #b91c1c; border-color: #fecaca; }
      html.dark .condition-badge { background: #1e293b; color: #94a3b8; border-color: #334155; }
      html.dark .condition-badge.cond-new { background: rgba(3, 105, 161, 0.2); color: #7dd3fc; border-color: rgba(3, 105, 161, 0.3); }
      html.dark .condition-badge.cond-refurbished { background: rgba(146, 64, 14, 0.2); color: #fcd34d; border-color: rgba(146, 64, 14, 0.3); }

      .antinna-3d-active { overflow: hidden !important; height: 100vh; position: fixed; width: 100%; }
      .antinna-3d-backdrop { position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; background: #000; z-index: 9999; display: none; flex-direction: column; touch-action: none; }
      .antinna-3d-backdrop.active { display: flex; }
      .antinna-3d-header { padding: 15px 25px; display: flex; justify-content: space-between; align-items: center; background: rgba(255,255,255,0.05); color: #fff; touch-action: auto; }
      .antinna-3d-close { background: none; border: none; color: #fff; font-size: 2rem; cursor: pointer; opacity: 0.8; }
      #antinna-3d-container { flex: 1; width: 100%; position: relative; }
      #antinna-3d-container model-viewer { width: 100%; height: 100%; --poster-color: transparent; }
      .antinna-ar-button {
          position: absolute; top: 20px; right: 20px;
          background: #fff; color: #000; border-radius: 30px;
          padding: 10px 20px; font-weight: 800; font-size: 0.8rem;
          border: none; cursor: pointer; box-shadow: 0 4px 12px rgba(0,0,0,0.3);
          display: flex; align-items: center; gap: 8px; z-index: 100;
      }

      .g-signin-button {
        display: inline-flex; align-items: center; justify-content: center;
        background: #131314; color: #E3E3E3;
        border: 1px solid #8E918F; border-radius: 20px;
        padding: 1px; cursor: pointer; transition: background 0.2s, box-shadow 0.2s;
        font-family: 'Google Sans Medium', 'Roboto', arial, sans-serif;
        font-weight: 500; font-size: 14px; line-height: 20px;
      }
      .g-signin-button:hover { background: #1e1e1f; box-shadow: 0 1px 2px 0 rgba(0,0,0,0.30), 0 1px 3px 1px rgba(0,0,0,0.15); }
      .g-signin-button .g-icon-wrapper { background: transparent; padding: 10px 0 10px 12px; border-radius: 20px 0 0 20px; display: flex; align-items: center; justify-content: center; }
      .g-signin-button .g-text { padding: 0 12px; }
    `;
    document.head.appendChild(style);
  }

  static injectModelViewer(): Promise<void> {
    return new Promise((resolve) => {
        if (document.querySelector('script[src*="model-viewer"]')) return resolve();
        const script = document.createElement('script');
        script.type = 'module';
        script.src = 'https://ajax.googleapis.com/ajax/libs/model-viewer/3.5.0/model-viewer.min.js';
        script.onload = () => resolve();
        document.head.appendChild(script);
    });
  }

  static injectLeaflet(): Promise<void> {
    return new Promise((resolve) => {
        if ((window as any).L) return resolve();

        const link = document.createElement('link');
        link.rel = 'stylesheet';
        link.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css';
        document.head.appendChild(link);

        const script = document.createElement('script');
        script.src = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js';
        script.onload = () => resolve();
        document.head.appendChild(script);
    });
  }

  static async show3DViewer(url: string): Promise<void> {
    this.injectModalStyles();
    await this.injectModelViewer();

    let backdrop = this.el('antinna-3d-modal');
    if (!backdrop) {
        backdrop = document.createElement('div');
        backdrop.id = 'antinna-3d-modal';
        backdrop.className = 'antinna-3d-backdrop';
        backdrop.innerHTML = `
            <div class="antinna-3d-header">
                <h3 style="margin:0;">3D Model Preview</h3>
                <button class="antinna-3d-close" onclick="UIManager.hide3DViewer()">&times;</button>
            </div>
            <div id="antinna-3d-container"></div>
        `;
        document.body.appendChild(backdrop);
    }

    const container = this.el('antinna-3d-container');
    if (container) {
        container.innerHTML = `
            <model-viewer src="${url}" ar ar-modes="webxr scene-viewer quick-look" camera-controls touch-action="pan-y" alt="A 3D model" shadow-intensity="1">
                <button slot="ar-button" class="antinna-ar-button">
                   <span>📷</span> View in your space (AR)
                </button>
                <div slot="progress-bar"></div>
            </model-viewer>
        `;
    }

    backdrop.classList.add('active');
    document.body.classList.add('antinna-3d-active');
  }

  static hide3DViewer(): void {
      const backdrop = this.el('antinna-3d-modal');
      if (backdrop) {
          backdrop.classList.remove('active');
          document.body.classList.remove('antinna-3d-active');
          const container = this.el('antinna-3d-container');
          if (container) container.innerHTML = ''; // Stop the model viewer
      }
  }

  static showToast(message: string, type: 'success' | 'error' | 'info' = 'success'): void {
    this.injectModalStyles();
    let container = document.getElementById('toast-container');
    if (!container) {
        container = document.createElement('div');
        container.id = 'toast-container';
        container.className = 'toast-container';
        document.body.appendChild(container);
    }

    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.style.cssText = `
        background: ${type === 'success' ? '#10b981' : type === 'error' ? '#ef4444' : '#1e293b'};
        color: white;
        padding: 12px 24px;
        border-radius: 10px;
        box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
        display: flex;
        align-items: center;
        gap: 10px;
        margin-top: 10px;
        font-size: 0.9rem;
        font-weight: 600;
        animation: slideUp 0.3s cubic-bezier(0.4, 0, 0.2, 1) forwards;
        pointer-events: auto;
        border: 1px solid rgba(255,255,255,0.1);
    `;
    toast.innerText = message;
    container.appendChild(toast);

    setTimeout(() => {
        toast.style.animation = 'fadeOut 0.3s forwards';
        setTimeout(() => toast.remove(), 300);
    }, 3000);
  }
}
