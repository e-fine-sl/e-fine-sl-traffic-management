const express    = require('express');
const router     = express.Router();
const { protect } = require('../middleware/authMiddleware');
const { reportAccident, getAccidentReports, getAccidentReportById,
        updateAccidentStatus, notifyPoliceDivision, getAccidentStats
      } = require('../controllers/accidentController');

// Driver route — no strict auth (same pattern as SOS)
router.post('/report', reportAccident);

// Admin routes — all protected
router.get('/reports/stats',                protect, getAccidentStats);
router.get('/reports',                      protect, getAccidentReports);
router.get('/reports/:id',                  protect, getAccidentReportById);
router.patch('/reports/:id/status',         protect, updateAccidentStatus);
router.post('/reports/:id/notify-division', protect, notifyPoliceDivision);

module.exports = router;
