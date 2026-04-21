/**
 * scripts/download-models.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Downloads @vladmandic/face-api model weight files from GitHub (raw) into
 * backend_api/models/ before the server starts.
 *
 * Behaviour:
 *   • Skips any file that already exists on disk (idempotent).
 *   • Exits with code 1 on any download failure so the server won't start
 *     with missing models.
 *
 * Usage (in package.json):
 *   "start": "node scripts/download-models.js && node server.js"
 * ─────────────────────────────────────────────────────────────────────────────
 */

const https = require('https');
const fs    = require('fs');
const path  = require('path');

// ── Destination folder ────────────────────────────────────────────────────────
const MODELS_DIR = path.join(__dirname, '..', 'models');
const BASE_URL   =
  'https://github.com/vladmandic/face-api/raw/master/model/';

// ── Model files required by kyc.js ───────────────────────────────────────────
const MODEL_FILES = [
  // SSD MobileNet v1 (face detection)
  'ssd_mobilenetv1_model-weights_manifest.json',
  'ssd_mobilenetv1_model-shard1',
  'ssd_mobilenetv1_model-shard2',

  // Face landmark 68-point network
  'face_landmark_68_model-weights_manifest.json',
  'face_landmark_68_model-shard1',

  // Face recognition network
  'face_recognition_model-weights_manifest.json',
  'face_recognition_model-shard1',
  'face_recognition_model-shard2',
];

// ── Helper: download a single file with redirect support ─────────────────────
function downloadFile(url, destPath) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(destPath);

    function fetch(currentUrl) {
      https.get(currentUrl, (response) => {
        // Follow HTTP 3xx redirects (GitHub uses them)
        if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
          file.close();
          fetch(response.headers.location);
          return;
        }

        if (response.statusCode !== 200) {
          file.close();
          fs.unlinkSync(destPath);
          reject(new Error(`HTTP ${response.statusCode} for ${currentUrl}`));
          return;
        }

        response.pipe(file);
        file.on('finish', () => { file.close(); resolve(); });
      }).on('error', (err) => {
        fs.unlinkSync(destPath);
        reject(err);
      });
    }

    fetch(url);
  });
}

// ── Main ──────────────────────────────────────────────────────────────────────
(async () => {
  // Create models directory if missing
  if (!fs.existsSync(MODELS_DIR)) {
    fs.mkdirSync(MODELS_DIR, { recursive: true });
    console.log('[models] Created directory:', MODELS_DIR);
  }

  let allPresent = true;

  for (const fileName of MODEL_FILES) {
    const destPath = path.join(MODELS_DIR, fileName);

    if (fs.existsSync(destPath)) {
      console.log(`[models] [OK] Already present: ${fileName}`);
      continue;
    }

    allPresent = false;
    const url = BASE_URL + fileName;
    process.stdout.write(`[models] [INFO] Downloading: ${fileName} ... `);

    try {
      await downloadFile(url, destPath);
      console.log('done');
    } catch (err) {
      console.error(`\n[models] [ERROR] Failed: ${fileName} — ${err.message}`);
      process.exit(1); // Stop server from starting with missing models
    }
  }

  if (allPresent) {
    console.log('[models] All model files are already present. Skipping download.');
  } else {
    console.log('[models] All model files downloaded successfully.');
  }
})();
