// ─────────────────────────────────────────────────────────────────────────────
// services/fcmService.js
// Firebase Admin SDK initializer — singleton pattern.
// Initializes ONCE on first require(), returns the messaging object.
//
// SETUP REQUIRED:
//  1. Download your Firebase service-account JSON from:
//     Firebase Console → Project Settings → Service Accounts → Generate New Key
//  2. Save it as:  backend_api/config/firebase-service-account.json
//  3. Add that filename to .gitignore immediately!
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const path  = require('path');

// Path to the service account key file (NEVER commit this to git)
const SERVICE_ACCOUNT_PATH = path.join(__dirname, '../config/firebase-service-account.json');

let _messaging = null; // cached instance

/**
 * Returns the initialized Firebase Messaging instance.
 * Safe to call multiple times — initializes only once.
 */
const getMessaging = () => {
  if (_messaging) return _messaging;

  try {
    if (admin.apps.length === 0) {
      let credential = null;

      // OPTION A: Use Environment Variable (Best for production like Render)
      if (process.env.FIREBASE_SERVICE_ACCOUNT) {
        console.log('[FCMService]  Initializing using FIREBASE_SERVICE_ACCOUNT environment variable.');
        try {
          const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
          credential = admin.credential.cert(serviceAccount);
        } catch (parseErr) {
          console.error('[FCMService]  ERROR: FIREBASE_SERVICE_ACCOUNT is not a valid JSON string.');
          throw parseErr;
        }
      } 
      // OPTION B: Use local JSON file (Best for local development)
      else if (require('fs').existsSync(SERVICE_ACCOUNT_PATH)) {
        console.log('[FCMService]  Initializing using local service-account.json file.');
        const serviceAccount = require(SERVICE_ACCOUNT_PATH);
        credential = admin.credential.cert(serviceAccount);
      } 
      else {
        console.warn('[FCMService]  ⚠️ WARNING: No Firebase credentials found (env or file). Notifications will fail.');
        throw new Error('Firebase credentials missing');
      }

      admin.initializeApp({ credential });
      console.log('[FCMService]  Firebase Admin SDK initialized successfully.');
    }
    _messaging = admin.messaging();
  } catch (err) {
    console.error('[FCMService]  CRITICAL: Failed to initialize Firebase Admin SDK!');
    console.error('[FCMService]    Error:', err.message);
    // Do not throw here to allow the rest of the server to start, 
    // but FCM operations will fail gracefully
    _messaging = null; 
  }

  return _messaging;
};

/**
 * Sends a high-priority FCM notification to a single FCM token.
 * Returns { success: true, messageId } or { success: false, error }
 *
 * @param {string} token  - Target device FCM registration token
 * @param {object} payload - { title, body, data }
 */
const sendToToken = async (token, payload) => {
  if (!token) {
    console.warn('[FCMService] sendToToken called with empty token — skipping.');
    return { success: false, error: 'Empty token' };
  }

  // Extract from either flat or nested structure
  const title = payload.title || (payload.notification && payload.notification.title);
  const body = payload.body || (payload.notification && payload.notification.body);
  const data = payload.data || {};
  const androidPriority = (payload.android && payload.android.priority) || 'high';

  const message = {
    token,
    notification: { title, body },
    data: {
      ...data,
      // All data values MUST be strings for FCM
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    android: {
      priority: androidPriority,
      notification: {
        sound: 'default',
        channelId: 'sos_alerts', // Must match Flutter channel ID
        priority: 'max',
        visibility: 'public',
        // Vibrate for SOS urgency
        vibrateTimingsMillis: [0, 500, 250, 500],
      },
    },
    apns: {
      headers: { 'apns-priority': '10' }, // 10 = immediate (iOS)
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
          contentAvailable: true,
        },
      },
    },
  };

  try {
    const messageId = await getMessaging().send(message);
    console.log(`[FCMService]  Sent to token ...${token.slice(-8)} | messageId: ${messageId}`);
    return { success: true, messageId };
  } catch (err) {
    console.error(`[FCMService]  Failed for token ...${token.slice(-8)} | Error: ${err.code} — ${err.message}`);
    return { success: false, error: err.message, code: err.code };
  }
};

/**
 * Sends to multiple FCM tokens in parallel.
 * Returns a summary: { sent, failed, results }
 *
 * @param {string[]} tokens   - Array of FCM registration tokens
 * @param {object}   payload  - { title, body, data }
 */
const sendToMultiple = async (tokens, payload) => {
  if (!tokens || tokens.length === 0) {
    console.warn('[FCMService] sendToMultiple called with 0 tokens.');
    return { sent: 0, failed: 0, results: [] };
  }

  console.log(`[FCMService]  Sending to ${tokens.length} token(s)...`);
  const results = await Promise.all(tokens.map(token => sendToToken(token, payload)));

  const sent   = results.filter(r => r.success).length;
  const failed = results.filter(r => !r.success).length;

  console.log(`[FCMService] � Dispatch complete: ${sent} sent, ${failed} failed`);
  return { sent, failed, results };
};

module.exports = { getMessaging, sendToToken, sendToMultiple };
