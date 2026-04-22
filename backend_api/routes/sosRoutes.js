// ─────────────────────────────────────────────────────────────────────────────
// routes/sosRoutes.js
// SOS Emergency Alert Routes
// ─────────────────────────────────────────────────────────────────────────────

const express = require('express');
const router  = express.Router();
const { triggerSOS, updateOfficerPresence } = require('../controllers/sosController');

// POST /api/sos           — Trigger SOS alert (sends FCM to nearby officers)
// NOTE: No auth middleware intentionally — SOS must fire even if token is borderline.
//       For production you would add: const { protect } = require('../middleware/authMiddleware');
router.post('/', triggerSOS);

// PUT  /api/sos/update-location — Update officer FCM token + GPS location on login
router.put('/update-location', updateOfficerPresence);

module.exports = router;
