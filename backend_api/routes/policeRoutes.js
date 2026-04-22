// ─────────────────────────────────────────────────────────────────────────────
// routes/policeRoutes.js
// Police operations routes
// ─────────────────────────────────────────────────────────────────────────────

const express = require('express');
const router = express.Router();
const { getHqAlerts } = require('../controllers/policeController');

// GET /api/police/hq-alerts
router.get('/hq-alerts', getHqAlerts);

module.exports = router;
