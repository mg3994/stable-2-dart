import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'ui_manager.dart';

class PhoneVerificationRenderer {
  dynamic _confirmationResult;
  Timer? _resendTimer;
  int _countdown = 60;
  Map<String, String> _selectedCountry = {'code': '+91', 'name': 'India', 'flag': '🇮🇳'};

  final List<Map<String, String>> _countries = [
    {'code': '+91', 'name': 'India', 'flag': '🇮🇳'},
    {'code': '+1', 'name': 'USA', 'flag': '🇺🇸'},
    {'code': '+44', 'name': 'UK', 'flag': '🇬🇧'},
    {'code': '+971', 'name': 'UAE', 'flag': '🇦🇪'},
    {'code': '+65', 'name': 'Singapore', 'flag': '🇸🇬'}
  ];

  void render() {
    var modal = UIManager.el('antinna-phone-modal');
    if (modal == null) {
      modal = web.document.createElement('div');
      modal.id = 'antinna-phone-modal';
      modal.className = 'antinna-geo-backdrop';
      UIManager.injectModalStyles();

      final countriesHtml = _countries.map((c) => '''
          <div class="antinna-country-item" data-code="${c['code']}">
              <span class="antinna-country-flag">${c['flag']}</span>
              <span class="antinna-country-name">${c['name']}</span>
              <span class="antinna-country-code">${c['code']}</span>
          </div>
      ''').join('');

      modal.innerHTML = '''
        <div class="antinna-geo-content">
          <div class="antinna-geo-header">
            <h3>Phone Verification</h3>
            <button class="antinna-geo-close" onclick="document.getElementById('antinna-phone-modal').classList.remove('active')">&times;</button>
          </div>
          <p class="antinna-geo-subtitle">
            Please link your phone number to continue with the order.
          </p>

          <div id="phone-input-container">
            <div class="antinna-geo-search-container antinna-input-prefixed">
                <div id="antinna-country-trigger" class="antinna-country-selector">
                    <span id="antinna-selected-flag">${_selectedCountry['flag']}</span>
                    <span id="antinna-selected-code">${_selectedCountry['code']}</span>
                    <span class="antinna-country-chevron"></span>
                    <div id="antinna-country-list" class="antinna-country-list">
                        $countriesHtml
                    </div>
                </div>
                <input id="antinna-phone-number" type="tel" placeholder="98765 43210" autocomplete="off">
            </div>
            <div id="recaptcha-container" style="margin-top:15px;"></div>
            <button id="antinna-send-otp-btn" class="v-btn active" style="width:100%; margin-top:20px; display: flex; align-items: center; justify-content: center;">
                <span class="antinna-spinner"></span>
                <span class="btn-text">Send OTP</span>
            </button>
          </div>

          <div id="otp-input-container" style="display:none;">
            <div class="antinna-geo-search-container">
                <input id="antinna-otp-code" type="text" placeholder="Enter 6-digit OTP" maxlength="6" autocomplete="off">
            </div>
            <div id="antinna-resend-container" style="margin-top:15px; font-size:0.85rem; text-align:center; color:#777;">
                Didn't receive code? <button id="antinna-resend-btn" disabled style="background:none; border:none; color:var(--accent); font-weight:700; cursor:pointer; opacity:0.5;">Resend (<span id="antinna-countdown">60</span>s)</button>
            </div>
            <button id="antinna-verify-otp-btn" class="v-btn active" style="width:100%; margin-top:20px; display: flex; align-items: center; justify-content: center;">
                <span class="antinna-spinner"></span>
                <span class="btn-text">Verify & Link</span>
            </button>
            <button class="qty-btn" style="border:none; margin-top:10px; background:none; width:100%;" onclick="document.getElementById('phone-input-container').style.display='block'; document.getElementById('otp-input-container').style.display='none';">Back</button>
          </div>
        </div>
      ''';
      web.document.body?.appendChild(modal);
      _setupListeners();
    }

    modal.classList.add('active');
    _initRecaptcha();
  }

  void _setupListeners() {
    final sendBtn = UIManager.el('antinna-send-otp-btn');
    final verifyBtn = UIManager.el('antinna-verify-otp-btn');
    final resendBtn = UIManager.el('antinna-resend-btn');
    final trigger = UIManager.el('antinna-country-trigger');
    final list = UIManager.el('antinna-country-list');

    if (sendBtn != null) (sendBtn as web.HTMLElement).onclick = ((web.MouseEvent e) => _handleSendOTP()).toJS;
    if (verifyBtn != null) (verifyBtn as web.HTMLElement).onclick = ((web.MouseEvent e) => _handleVerifyOTP()).toJS;
    if (resendBtn != null) (resendBtn as web.HTMLElement).onclick = ((web.MouseEvent e) => _handleSendOTP()).toJS;

    if (trigger != null) {
      (trigger as web.HTMLElement).onclick = ((web.MouseEvent e) {
        e.stopPropagation();
        final isActive = list?.classList.toggle('active') ?? false;
        trigger.classList.toggle('active', isActive);
      }).toJS;
    }

    final countryItems = web.document.querySelectorAll('.antinna-country-item');
    for (int i = 0; i < countryItems.length; i++) {
      final item = countryItems.item(i) as web.HTMLElement?;
      if (item != null) {
        item.onclick = ((web.MouseEvent e) {
          final code = item.getAttribute('data-code') ?? '+91';
          final found = _countries.firstWhere((c) => c['code'] == code, orElse: () => _selectedCountry);
          _selectedCountry = found;

          final flagEl = UIManager.el('antinna-selected-flag');
          final codeEl = UIManager.el('antinna-selected-code');
          if (flagEl != null) flagEl.textContent = found['flag']!;
          if (codeEl != null) codeEl.textContent = found['code']!;

          list?.classList.remove('active');
          trigger?.classList.remove('active');
        }).toJS;
      }
    }
  }

  void _initRecaptcha() {
    final win = web.window as dynamic;
    if (win.firebaseAuth == null) return;
    try {
      if (win.recaptchaVerifier == null) {
        win.recaptchaVerifier = win.RecaptchaVerifier(win.firebaseAuth, 'recaptcha-container', {
          'size': 'invisible',
        });
      }
    } catch (_) {}
  }

  Future<void> _handleSendOTP() async {
    final phoneInput = UIManager.el('antinna-phone-number') as web.HTMLInputElement?;
    final sendBtn = UIManager.el('antinna-send-otp-btn');
    if (phoneInput == null || phoneInput.value.trim().isEmpty) {
      UIManager.showToast("Please enter a phone number", "error");
      return;
    }

    final fullNumber = "${_selectedCountry['code']}${phoneInput.value.trim().replaceAll(RegExp(r'\s+'), '')}";

    sendBtn?.classList.add('loading');

    final win = web.window as dynamic;
    try {
      final verifier = win.recaptchaVerifier;
      _confirmationResult = await (win.signInWithPhoneNumber(win.firebaseAuth, fullNumber, verifier) as JSPromise).toDart;

      UIManager.showToast("OTP sent to $fullNumber", "success");
      final phoneCont = UIManager.el('phone-input-container') as web.HTMLElement?;
      final otpCont = UIManager.el('otp-input-container') as web.HTMLElement?;
      if (phoneCont != null) phoneCont.style.display = 'none';
      if (otpCont != null) otpCont.style.display = 'block';

      _startResendTimer();
    } catch (e) {
      UIManager.showToast("Failed to send OTP. Check number format.", "error");
    } finally {
      sendBtn?.classList.remove('loading');
    }
  }

  void _startResendTimer() {
    _countdown = 60;
    final resendBtn = UIManager.el('antinna-resend-btn') as web.HTMLButtonElement?;
    final countdownEl = UIManager.el('antinna-countdown');

    if (resendBtn != null) {
      resendBtn.disabled = true;
      resendBtn.style.opacity = '0.5';
    }

    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _countdown--;
      if (countdownEl != null) countdownEl.textContent = _countdown.toString();

      if (_countdown <= 0) {
        timer.cancel();
        if (resendBtn != null) {
          resendBtn.disabled = false;
          resendBtn.style.opacity = '1';
        }
      }
    });
  }

  Future<void> _handleVerifyOTP() async {
    final otpInput = UIManager.el('antinna-otp-code') as web.HTMLInputElement?;
    final verifyBtn = UIManager.el('antinna-verify-otp-btn');

    if (otpInput == null || otpInput.value.trim().length != 6) {
      UIManager.showToast("Enter a valid 6-digit OTP", "error");
      return;
    }

    if (_confirmationResult == null) {
      UIManager.showToast("Session expired, resend OTP", "error");
      return;
    }

    verifyBtn?.classList.add('loading');

    try {
      await (_confirmationResult.confirm(otpInput.value.trim()) as JSPromise).toDart;
      UIManager.showToast("Phone number verified successfully!", "success");
      UIManager.el('antinna-phone-modal')?.classList.remove('active');

      try {
        (web.window as dynamic).AntinnaEngine?.onPhoneVerified();
      } catch (_) {}
    } catch (e) {
      UIManager.showToast("Invalid OTP code", "error");
    } finally {
      verifyBtn?.classList.remove('loading');
    }
  }
}
