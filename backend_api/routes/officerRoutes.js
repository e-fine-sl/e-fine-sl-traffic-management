const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/authMiddleware');
const { 
    officerLogout, 
    officerPresence,
    getOfficerSessions, 
    getOfficerLastSession 
} = require('../controllers/officerSessionController');

// Officer calls this on logout — no strict auth (same rationale as SOS)
router.put('/logout', officerLogout);

// App calls this on lifecycle change (foreground/background)
router.put('/presence', officerPresence);

// Admin-protected routes — session history and last session info
router.get('/sessions/last/:badgeNumber', protect, getOfficerLastSession);
router.get('/sessions',                   protect, getOfficerSessions);

module.exports = router;
