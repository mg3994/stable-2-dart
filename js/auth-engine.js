import {
      initializeApp,
      getApps,
    } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-app.js";
    import {
      getAuth,
      signInWithPopup,
      GoogleAuthProvider,
      onAuthStateChanged,
      signOut,
      setPersistence,
      browserLocalPersistence,
      RecaptchaVerifier,
      linkWithPhoneNumber,
    } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-auth.js";
    import {
      getMessaging,
      getToken,
      onMessage,
    } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-messaging.js";

    // Dynamic environment fallback resolution parsing
    let firebaseConfig = {};
    try {
      if (typeof __firebase_config !== "undefined") {
        firebaseConfig = JSON.parse(__firebase_config);
      } else {
        firebaseConfig = {
          apiKey: "AIzaSyDtRB-0S8VNgY-HoQYAAvkLX7iOAK-K-i0",
          authDomain: "antinnamain.firebaseapp.com",
          projectId: "antinnamain",
          storageBucket: "antinnamain.appspot.com",
          messagingSenderId: "907520801915",
          appId: "1:907520801915:web:5a99962f7ce400da54b6de",
        };
      }
    } catch (e) {
      console.error(
        "Critical: Failed to resolve core Firebase configurations.",
        e,
      );
    }

    // Initialize application nodes securely
    const app = !getApps().length
      ? initializeApp(firebaseConfig)
      : getApps()[0];
    const auth = getAuth(app);
    window.firebaseAuth = auth; // Expose for linking
    window.RecaptchaVerifier = RecaptchaVerifier;
    window.linkWithPhoneNumber = linkWithPhoneNumber;

    // Set persistence to LOCAL so session is remembered
    (async () => {
        try {
          await setPersistence(auth, browserLocalPersistence);
        } catch (e) {
          console.warn("Set persistence failed:", e);
        }
    })();

    const provider = new GoogleAuthProvider();

    // Global Messaging Instantiation References
    let messaging = null;
    try {
      messaging = getMessaging(app);
    } catch (e) {
      console.warn("FCM Messaging initialization skipped or unsupported in this browser environment.", e);
    }

    const APPS_SCRIPT_URL =
      "https://script.google.com/macros/s/YOUR_DEPLOYED_WEB_APP_ID/exec";

    // Resolve persistent unique browser profile instance ID
    let browserClientId = localStorage.getItem("antinna_browser_client_id");
    if (!browserClientId) {
      browserClientId =
        "client-" +
        Math.random().toString(36).substring(2, 15) +
        "-" +
        Date.now().toString(36);
      localStorage.setItem("antinna_browser_client_id", browserClientId);
    }

    // Proactively backmount the service worker loop on execution start
    if ("serviceWorker" in navigator) {
      window.addEventListener("load", () => {
        navigator.serviceWorker.getRegistration("/").then((existing) => {
          if (!existing) {
            navigator.serviceWorker
              .register("/firebase-messaging-sw.js")
              .then((reg) =>
                console.log(
                  "FCM Worker ready state bound with scope:",
                  reg.scope,
                ),
              )
              .catch((err) =>
                console.error("Worker registration structural failure:", err),
              );
          }
        });
      });
    }

    // Toast Notification utility
    function showToast(message, type = 'info') {
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
            border: 1px solid var(--border-ui);
        `;
        toast.innerText = message;
        container.appendChild(toast);
        setTimeout(() => {
            toast.style.animation = 'fadeOut 0.3s forwards';
            setTimeout(() => toast.remove(), 300);
        }, 3000);
    }
    window.showToast = showToast;

    // Set globally accessible window authentication variables
    async function updateWindowAuthData(user, deviceToken = null) {
      window.isLoggedIn = !!user;
      window.firebaseUid = user ? user.uid : null;

      let linkedPhoneNumber = null;
      if (user) {
          linkedPhoneNumber = user.phoneNumber;
          if (!linkedPhoneNumber && user.providerData) {
            const providerMatch = user.providerData.find(info => info.phoneNumber);
            if (providerMatch) linkedPhoneNumber = providerMatch.phoneNumber;
          }
          window.hasPhoneLinked = !!linkedPhoneNumber;

        try {
          window.firebaseAuthToken = await user.getIdToken();
        } catch (e) {
          console.error("Error getting Firebase ID Token for window:", e);
          window.firebaseAuthToken = null;
        }
      } else {
        window.firebaseAuthToken = null;
        window.hasPhoneLinked = false;
      }

      if (deviceToken) {
        window.firebaseRemoteDeviceToken = deviceToken;
      } else if (!user) {
        window.firebaseRemoteDeviceToken = null;
      }
      console.log("Updated global auth window variables:", {
        isLoggedIn: window.isLoggedIn,
        firebaseUid: window.firebaseUid,
        hasPhoneLinked: window.hasPhoneLinked,
        firebaseAuthToken: window.firebaseAuthToken ? "EXISTS" : null,
        firebaseRemoteDeviceToken: window.firebaseRemoteDeviceToken
      });
    }

    /**
     * REACTIVE CORE: Synchronizes latest tokens to backend database arrays
     */
    async function autoSyncDeviceSession(currentUserInstance) {
      if (!messaging) return;
      if (Notification.permission === "denied") {
        console.warn(
          "Notification permissions blocked by browser configuration.",
        );
        return;
      }

      const userIdentifier = currentUserInstance
        ? currentUserInstance.uid
        : "guest";
      const syncSessionKey = `antinna_sync_lock_${userIdentifier}`;

      // Check lock state BEFORE requesting token promises
      if (sessionStorage.getItem(syncSessionKey) === "active") {
        console.log(
          `[Sync Ignored] State lock for ${userIdentifier} already active.`,
        );
        try {
          const activeRegistration = await navigator.serviceWorker.ready;
          const registrationToken = await getToken(messaging, {
            vapidKey:
              "BA2CnO0uBsc7Ikc9LHyaY92oY1IGmTFLYemtw7uWSPrWHUP6SibSpMka0Hif5QibHqsHO7dbUPpto87m1fTEKr0",
            serviceWorkerRegistration: activeRegistration,
          });
          if (registrationToken) {
            await updateWindowAuthData(currentUserInstance, registrationToken);
          }
        } catch (err) {
          console.error("Failed retrieving token for window object:", err);
        }
        return;
      }
      try {
        const permission = await Notification.requestPermission();
        if (permission !== "granted") return;

        const activeRegistration = await navigator.serviceWorker.ready;
        const registrationToken = await getToken(messaging, {
          vapidKey:
            "BA2CnO0uBsc7Ikc9LHyaY92oY1IGmTFLYemtw7uWSPrWHUP6SibSpMka0Hif5QibHqsHO7dbUPpto87m1fTEKr0",
          serviceWorkerRegistration: activeRegistration,
        });

        if (registrationToken) {
          await updateWindowAuthData(currentUserInstance, registrationToken);
          let detectedClient = "Web Browser";
          if (navigator.userAgent.indexOf("Chrome") > -1)
            detectedClient = "Chrome";
          else if (navigator.userAgent.indexOf("Safari") > -1)
            detectedClient = "Safari";
          else if (navigator.userAgent.indexOf("Firefox") > -1)
            detectedClient = "Firefox";
          if (navigator.userAgent.indexOf("Mobile") > -1)
            detectedClient += " (Mobile)";

          if (currentUserInstance) {
            try {
              const idToken = await currentUserInstance.getIdToken();
              dispatchSyncPayload({
                action: "SYNC_DEVICE",
                clientId: browserClientId,
                idToken: idToken,
                deviceToken: registrationToken,
                clientName: detectedClient,
              });
              sessionStorage.setItem(syncSessionKey, "active");
            } catch (err) {
              console.error("Failed fetching secure token proof:", err);
            }
          } else {
            dispatchSyncPayload({
              action: "SYNC_DEVICE",
              clientId: browserClientId,
              idToken: "guest_session",
              deviceToken: registrationToken,
              clientName: detectedClient,
            });
            sessionStorage.setItem(syncSessionKey, "active");
          }
        }
      } catch (err) {
        console.error("Central synchronization sequence blocked:", err);
      }
    }

    function dispatchSyncPayload(payload) {
      fetch(APPS_SCRIPT_URL, {
        method: "POST",
        mode: "no-cors",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      }).catch((err) => console.error("Database tracking relay failure:", err));
    }

    if (messaging) {
      onMessage(messaging, (payload) => {
        console.log("Foreground tracking alert frame:", payload);
        if (payload.notification) {
          showToast(
            `${payload.notification.title}: ${payload.notification.body}`,
            "info",
          );
        }
      });
    }

    /**
     * Executes authentication pop-up lifecycle sequence
     */
    async function handleLogin() {
      try {
        const loginBtn = document.getElementById("google-login-btn-sidebar");
        if (loginBtn) {
          loginBtn.disabled = true;
          loginBtn.style.opacity = "0.7";
        }
        await signInWithPopup(auth, provider);
        showToast("Secure login established successfully!", "success");
      } catch (error) {
        console.error("Authentication Error Matrix:", error);
        if (error.code === "auth/popup-closed-by-user") {
          showToast("Sign-in context aborted by user.", "error");
        } else {
          showToast("Failed to establish validation session.", "error");
        }
      } finally {
        const loginBtn = document.getElementById("google-login-btn-sidebar");
        if (loginBtn) {
          loginBtn.disabled = false;
          loginBtn.style.opacity = "1";
        }
      }
    }
    window.handleLogin = handleLogin;

    /**
     * Terminate active validation container context
     */
    async function handleLogout() {
      try {
        const currentUserInstance = auth.currentUser;
        const userIdentifier = currentUserInstance
          ? currentUserInstance.uid
          : "guest";

        dispatchSyncPayload({
          action: "LOGOUT_DEVICE",
          clientId: browserClientId,
        });

        sessionStorage.removeItem(`antinna_sync_lock_${userIdentifier}`);
        sessionStorage.removeItem("antinna_sync_lock_guest");
        await signOut(auth);
        showToast("Session signed out cleanly.", "info");
      } catch (error) {
        console.error("SignOut pipeline exception execution:", error);
        showToast("Failed to safely terminate session data flow.", "error");
      }
    }
    window.handleLogout = handleLogout;

    /**
     * Copy User Unique ID context string buffer to clipboard securely
     */
    async function copyUserUID(uid) {
      try {
        await navigator.clipboard.writeText(uid);
        showToast("UID parsed and copied to clipboard!", "success");
      } catch (err) {
        console.error(
          "Failed writing explicit buffer strings to clipboard",
          err,
        );
      }
    }

    window.openSettingsModal = function() {
      const modalBackdrop = document.getElementById('account-settings-modal-backdrop');
      if (modalBackdrop) {
        modalBackdrop.classList.add('active');
      }
    };

    window.closeSettingsModal = function() {
      const modalBackdrop = document.getElementById('account-settings-modal-backdrop');
      if (modalBackdrop) {
        modalBackdrop.classList.remove('active');
      }
    };

    // Close settings modal when clicking outside settings container
    document.addEventListener('click', (e) => {
      const modalBackdrop = document.getElementById('account-settings-modal-backdrop');
      if (modalBackdrop && modalBackdrop.classList.contains('active')) {
        if (e.target === modalBackdrop) {
          window.closeSettingsModal();
        }
      }
    });

    /**
     * High Performance Interface Painter updating targets reactive to authentication state
     */
    function renderAuthState(user) {
      const footerRow = document.querySelector('.avatar-footer-row');
      if (!footerRow) return;

      // 1. ANCHOR STATE: User is Unauthenticated (Render initial clean Sign-In template node)
      if (!user) {
        footerRow.innerHTML = `
          <button class="btn-google-login" id="google-login-btn-sidebar">
            <svg viewBox="0 0 24 24">
              <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
              <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
              <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"/>
              <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"/>
            </svg>
            <span>Continue with Google</span>
          </button>
        `;

        const initialBtn = document.getElementById("google-login-btn-sidebar");
        if (initialBtn) {
          initialBtn.addEventListener("click", handleLogin);
        }
        return;
      }

      // 2. ACTIVE STATE: User Profile Loaded
      const userAvatar =
        user.photoURL ||
        "https://www.gravatar.com/avatar/00000000000000000000000000000000";
      const userEmail = user.email || "anonymous@antinna.in";
      const userName = user.displayName || "Antinna Member";

      // Resolve phone number if explicitly bound to the social auth account profile
      let linkedPhoneNumber = user.phoneNumber || null;
      if (!linkedPhoneNumber) {
        if (user.providerData) {
          const providerMatch = user.providerData.find(
            (info) => info.phoneNumber,
          );
          if (providerMatch) {
            linkedPhoneNumber = providerMatch.phoneNumber;
          }
        }
      }

      footerRow.innerHTML = `
        <div class="avatar-left-info">
          <div class="user-avatar-circle" style="background: none;">
            <img src="${userAvatar}" alt="${userName}" style="width: 100%; height: 100%; border-radius: 50%; object-fit: cover;" />
          </div>
          <div class="user-meta-strings">
            <span class="user-display-name">${userName}</span>
            <span class="user-display-role" title="${userEmail}">${userEmail}</span>
          </div>
        </div>
        <button aria-label="Settings" class="btn-settings-gear" id="btn-settings-gear-trigger">⚙</button>
      `;

      // Settings gear listener
      const settingsTrigger = document.getElementById("btn-settings-gear-trigger");
      if (settingsTrigger) {
        settingsTrigger.addEventListener("click", (e) => {
          e.stopPropagation();
          window.openSettingsModal();
        });
      }

      // Populate Settings Modal elements
      const modalAvatar = document.getElementById('modal-user-avatar');
      const modalName = document.getElementById('modal-user-name');
      const modalEmail = document.getElementById('modal-user-email');
      const modalPhoneContainer = document.getElementById('modal-user-phone-container');
      const modalPhone = document.getElementById('modal-user-phone');
      const modalUid = document.getElementById('modal-user-uid');

      if (modalAvatar) modalAvatar.src = userAvatar;
      if (modalName) modalName.textContent = userName;
      if (modalEmail) modalEmail.textContent = userEmail;
      if (modalUid) modalUid.textContent = user.uid;

      if (linkedPhoneNumber) {
        if (modalPhone) modalPhone.textContent = linkedPhoneNumber;
        if (modalPhoneContainer) modalPhoneContainer.classList.remove('ui-hidden');
      } else {
        if (modalPhoneContainer) modalPhoneContainer.classList.add('ui-hidden');
      }
    }

    // Modal Copy UID button binding
    const modalCopyBtn = document.getElementById('modal-copy-uid-btn');
    if (modalCopyBtn) {
      modalCopyBtn.addEventListener("click", () => {
        if (auth.currentUser) {
          copyUserUID(auth.currentUser.uid);
        }
      });
    }

    // Modal Signout button binding
    const modalLogoutBtn = document.getElementById('modal-signout-btn');
    if (modalLogoutBtn) {
      modalLogoutBtn.addEventListener("click", () => {
        window.closeSettingsModal();
        handleLogout();
      });
    }

    // Reactive Master Pipeline Controller Hook
    onAuthStateChanged(auth, async (user) => {
      renderAuthState(user);
      await updateWindowAuthData(user);
      autoSyncDeviceSession(user);
    });
