// ─────────────────────────────────────────────────────────────────────────────
// services/fcmService.js
// Firebase Admin SDK initializer — singleton pattern.
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

let _messaging = null; // cached instance

/**
 * Discovers and loads Firebase service account credentials dynamically.
 */
const getServiceAccountCredential = () => {
  // Option 1: Environment Variable (Best for production deployment like Render/Heroku)
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    console.log('[FCMService] Initializing using FIREBASE_SERVICE_ACCOUNT environment variable.');
    try {
      const sa = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
      return admin.credential.cert(sa);
    } catch (parseErr) {
      console.error('[FCMService] ERROR: FIREBASE_SERVICE_ACCOUNT is not a valid JSON string:', parseErr.message);
    }
  }

  // Option 2: Config directory file search
  const configDir = path.resolve(__dirname, '../config');
  if (fs.existsSync(configDir)) {
    const files = fs.readdirSync(configDir);
    // Find any JSON file containing "firebase" or "adminsdk" or "service-account"
    const saFileName = files.find(
      (f) =>
        f.endsWith('.json') &&
        (f.includes('firebase') || f.includes('adminsdk') || f.includes('service-account'))
    );

    if (saFileName) {
      const saFullPath = path.join(configDir, saFileName);
      try {
        const saContent = JSON.parse(fs.readFileSync(saFullPath, 'utf8'));
        if (saContent.project_id && (saContent.private_key || saContent.client_email)) {
          console.log(`[FCMService] Initializing using service account file: ${saFileName} (Project: ${saContent.project_id})`);
          return admin.credential.cert(saContent);
        }
      } catch (readErr) {
        console.error(`[FCMService] Failed to read service account file ${saFileName}:`, readErr.message);
      }
    }
  }

  return null;
};

/**
 * Returns the initialized Firebase Messaging instance.
 * Safe to call multiple times — initializes only once.
 */
const getMessaging = () => {
  if (_messaging) return _messaging;

  try {
    if (admin.apps.length === 0) {
      const credential = getServiceAccountCredential();

      if (!credential) {
        console.warn('[FCMService] ⚠️ WARNING: No valid Firebase service account found. Push notifications will be disabled.');
        _messaging = null;
        return null;
      }

      admin.initializeApp({ credential });
      console.log('[FCMService] Firebase Admin SDK initialized successfully.');
    }
    _messaging = admin.messaging();
  } catch (err) {
    console.error('[FCMService] CRITICAL: Failed to initialize Firebase Admin SDK:', err.message);
    _messaging = null;
  }

  return _messaging;
};

/**
 * Sends a high-priority FCM notification to a single FCM token.
 * Returns { success: true, messageId } or { success: false, error }
 *
 * @param {string} token  - Target device FCM registration token
 * @param {object} payload - { title, body, data, channelId }
 */
const sendToToken = async (token, payload) => {
  if (!token) {
    console.warn('[FCMService] sendToToken called with empty token — skipping.');
    return { success: false, error: 'Empty token' };
  }

  const messaging = getMessaging();
  if (!messaging) {
    console.warn('[FCMService] Messaging instance is unavailable (missing credentials) — skipping push.');
    return { success: false, error: 'FCM not initialized' };
  }

  const title = payload.title || (payload.notification && payload.notification.title) || 'e-Fine SL Alert';
  const body = payload.body || (payload.notification && payload.notification.body) || '';
  const rawData = payload.data || {};
  const channelId = payload.channelId || 'traffic_alerts';

  // Ensure all data attributes are strings
  const stringifiedData = {};
  for (const [key, value] of Object.entries(rawData)) {
    stringifiedData[key] = value !== undefined && value !== null ? String(value) : '';
  }

  const message = {
    token,
    notification: {
      title,
      body,
    },
    data: {
      ...stringifiedData,
      title,
      body,
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    android: {
      priority: 'high',
      notification: {
        title,
        body,
        sound: 'default',
        channelId,
        priority: 'max',
        defaultSound: true,
        defaultVibrateTimings: true,
        visibility: 'public',
      },
    },
    apns: {
      headers: { 'apns-priority': '10' },
      payload: {
        aps: {
          alert: { title, body },
          sound: 'default',
          badge: 1,
          contentAvailable: true,
        },
      },
    },
  };

  try {
    const messageId = await messaging.send(message);
    console.log(`[FCMService] Push delivered to token ...${token.slice(-8)} | messageId: ${messageId}`);
    return { success: true, messageId };
  } catch (err) {
    console.error(`[FCMService] Push failed for token ...${token.slice(-8)} | Code: ${err.code} | Error: ${err.message}`);
    return { success: false, error: err.message, code: err.code };
  }
};

/**
 * Sends to multiple FCM tokens in parallel.
 * Returns a summary: { sent, failed, results }
 *
 * @param {string[]} tokens   - Array of FCM registration tokens
 * @param {object}   payload  - { title, body, data, channelId }
 */
const sendToMultiple = async (tokens, payload) => {
  if (!tokens || tokens.length === 0) {
    console.warn('[FCMService] sendToMultiple called with 0 tokens.');
    return { sent: 0, failed: 0, results: [] };
  }

  console.log(`[FCMService] Dispatching push to ${tokens.length} token(s)...`);
  const results = await Promise.all(tokens.map((token) => sendToToken(token, payload)));

  const sent = results.filter((r) => r.success).length;
  const failed = results.filter((r) => !r.success).length;

  console.log(`[FCMService] Dispatch complete: ${sent} sent, ${failed} failed`);
  return { sent, failed, results };
};

module.exports = {
  getMessaging,
  sendToToken,
  sendToMultiple,
};
