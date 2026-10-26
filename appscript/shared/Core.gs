/**
 * Core Shared logic for all Antinna Apps Script Projects
 */

function getSettings() {
  var props = PropertiesService.getScriptProperties().getProperties();
  return {
    TIMEZONE: props.TIMEZONE || "GMT",
    MERCHANT_ID: props.MERCHANT_ID || "IDBCR2DN5TVPLKL4KZ",
    SPREADSHEET_ID_SESSION: props.SPREADSHEET_ID_SESSION || "1MQD92fUET_gAD_c8l6Hl6Hn0UosG-PVjMcVDoQfFCSY",
    FIREBASE_API_KEY: props.FIREBASE_API_KEY || "AIzaSyDtRB-0S8VNgY-HoQYAAvkLX7iOAK-K-i0",
    FIREBASE_PROJECT_ID: props.FIREBASE_PROJECT_ID || "antinnamain",
    FIREBASE_SERVICE_ACCOUNT: props.FIREBASE_SERVICE_ACCOUNT || null,
  };
}

function generateUniqueId(prefix) {
  var d = new Date();
  var timezone = getSettings().TIMEZONE;
  var datePart = Utilities.formatDate(d, timezone, "yyyyMMdd");
  var uuidPart = Utilities.getUuid().split("-")[0];
  return prefix + "-" + datePart + "-" + uuidPart;
}

function parseRequestPayload(e) {
  try {
    return e.postData && e.postData.contents ? JSON.parse(e.postData.contents) : e.parameter;
  } catch (err) {
    throw new Error("Malformed payload structure");
  }
}

function jsonSuccess(data) {
  return ContentService.createTextOutput(JSON.stringify({ success: true, ...data }))
    .setMimeType(ContentService.MimeType.JSON);
}

function jsonError(message) {
  return ContentService.createTextOutput(JSON.stringify({ success: false, error: message }))
    .setMimeType(ContentService.MimeType.JSON);
}

function decodeJwtPart(part) {
  return Utilities.newBlob(Utilities.base64DecodeWebSafe(part)).getDataAsString();
}

/**
 * ------------------------------------------------
 * Firebase Authentication Core
 * ------------------------------------------------
 */

function verifyFirebaseToken(idToken) {
  try {
    if (!idToken || idToken === "guest_session") {
      return { isValid: false, uid: "guest", error: "Guest session" };
    }
    var settings = getSettings();
    var FIREBASE_PROJECT_ID = settings.FIREBASE_PROJECT_ID;
    if (!FIREBASE_PROJECT_ID) {
      return { isValid: false, error: "Missing Firebase project configuration" };
    }

    var parts = idToken.split(".");
    if (parts.length !== 3) {
      return { isValid: false, error: "Invalid JWT format" };
    }

    var header = JSON.parse(decodeJwtPart(parts[0]));
    var decodedPayload = JSON.parse(decodeJwtPart(parts[1]));

    if (header.alg !== "RS256") {
      return { isValid: false, error: "Invalid JWT algorithm" };
    }

    var expectedIssuer = "https://securetoken.google.com/" + FIREBASE_PROJECT_ID;
    if (!decodedPayload.iss || decodedPayload.iss !== expectedIssuer) {
      return { isValid: false, error: "Invalid issuer" };
    }
    if (!decodedPayload.aud || decodedPayload.aud !== FIREBASE_PROJECT_ID) {
      return { isValid: false, error: "Invalid audience" };
    }
    if (!decodedPayload.sub || decodedPayload.sub.length === 0) {
      return { isValid: false, error: "Invalid subject" };
    }
    var now = Math.floor(Date.now() / 1000);
    if (!decodedPayload.exp || decodedPayload.exp < now) {
      return { isValid: false, error: "Token expired" };
    }

    var certs = getFirebasePublicCertificates();
    var cert = certs[header.kid];
    if (!cert) {
      certs = getFirebasePublicCertificates(true);
      cert = certs[header.kid];
    }
    if (!cert) {
      return { isValid: false, error: "Certificate not found" };
    }

    var signedContent = parts[0] + "." + parts[1];
    var signatureBytes = Utilities.base64DecodeWebSafe(parts[2]);
    var verified = Utilities.verifyRsaSha256Signature(
      Utilities.newBlob(signedContent).getBytes(),
      signatureBytes,
      cert
    );

    if (!verified) {
      return { isValid: false, error: "Invalid signature" };
    }

    var firebaseData = decodedPayload.firebase || {};
    return {
      isValid: true,
      uid: decodedPayload.user_id || decodedPayload.sub || null,
      email: decodedPayload.email || null,
      displayName: decodedPayload.name || null,
      payload: decodedPayload
    };
  } catch (err) {
    return { isValid: false, error: err.toString() };
  }
}

function getFirebasePublicCertificates(forceRefresh) {
  var CACHE_KEY = "firebase_public_certs";
  var CERTS_URL = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com";
  var cache = CacheService.getScriptCache();

  if (!forceRefresh) {
    var cached = cache.get(CACHE_KEY);
    if (cached) return JSON.parse(cached);
  }

  var lock = LockService.getScriptLock();
  lock.waitLock(5000);
  try {
    if (!forceRefresh) {
      var retryCached = cache.get(CACHE_KEY);
      if (retryCached) return JSON.parse(retryCached);
    }
    var response = UrlFetchApp.fetch(CERTS_URL, { method: "get", muteHttpExceptions: true });
    if (response.getResponseCode() !== 200) throw new Error("Unable to fetch Firebase certificates");
    var certs = JSON.parse(response.getContentText());
    cache.put(CACHE_KEY, JSON.stringify(certs), 3600);
    return certs;
  } finally {
    lock.releaseLock();
  }
}

/**
 * ------------------------------------------------
 * FCM / Notification Core
 * ------------------------------------------------
 */

function getFcmAccessToken(forceRefresh) {
  var CACHE_KEY = "fcm_oauth2_access_token";
  var cache = CacheService.getScriptCache();
  if (!forceRefresh) {
    var cachedToken = cache.get(CACHE_KEY);
    if (cachedToken) return cachedToken;
  }
  var lock = LockService.getScriptLock();
  lock.waitLock(5000);
  try {
    var settings = getSettings();
    if (!settings.FIREBASE_SERVICE_ACCOUNT) throw new Error("Missing FIREBASE_SERVICE_ACCOUNT");
    var sa = typeof settings.FIREBASE_SERVICE_ACCOUNT === 'string' ? JSON.parse(settings.FIREBASE_SERVICE_ACCOUNT) : settings.FIREBASE_SERVICE_ACCOUNT;
    var now = Math.floor(Date.now() / 1000);
    var header = JSON.stringify({ alg: "RS256", typ: "JWT" });
    var payload = JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      exp: now + 3600,
      iat: now
    });
    var base64Encode = (str) => Utilities.base64EncodeWebSafe(str).replace(/=+$/, '');
    var signatureInput = base64Encode(header) + "." + base64Encode(payload);
    var signatureBytes = Utilities.computeRsaSha256Signature(signatureInput, sa.private_key);
    var jwt = signatureInput + "." + base64Encode(signatureBytes);
    var res = UrlFetchApp.fetch("https://oauth2.googleapis.com/token", {
      method: "post",
      payload: { grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt },
      muteHttpExceptions: true
    });
    var tokenData = JSON.parse(res.getContentText());
    cache.put(CACHE_KEY, tokenData.access_token, 3300);
    return tokenData.access_token;
  } finally {
    lock.releaseLock();
  }
}

function sendFcmMessage(token, title, body, data) {
  var settings = getSettings();
  var url = "https://fcm.googleapis.com/v1/projects/" + settings.FIREBASE_PROJECT_ID + "/messages:send";
  var payload = {
    message: {
      token: token,
      notification: { title: title, body: body },
      data: data || {}
    }
  };
  var options = {
    method: "post",
    contentType: "application/json",
    headers: { Authorization: "Bearer " + getFcmAccessToken() },
    payload: JSON.stringify(payload),
    muteHttpExceptions: true
  };
  return UrlFetchApp.fetch(url, options);
}

/**
 * ------------------------------------------------
 * Locking Mechanisms
 * ------------------------------------------------
 */

function withLock(callback, timeoutMs) {
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(timeoutMs || 30000)) throw new Error("Server busy");
  try { return callback(); } finally { lock.releaseLock(); }
}

function withLockDelayedRetry(callback, maxAttempts) {
  var lock = LockService.getScriptLock();
  var attempts = maxAttempts || 5;
  for (var i = 0; i < attempts; i++) {
    if (lock.tryLock(1000)) {
      try { return callback(); } finally { lock.releaseLock(); }
    }
    if (i < attempts - 1) Utilities.sleep(100 * Math.pow(2, i) + Math.floor(Math.random() * 50));
  }
  throw new Error("Server timeout");
}
