const express    = require('express');
const router     = express.Router();
const { protectAdmin } = require('../middleware/adminMiddleware');
const { reportAccident, getAccidentReports, getAccidentReportById,
        updateAccidentStatus, notifyPoliceDivision, getAccidentStats
      } = require('../controllers/accidentController');

const upload = require('../middleware/uploadMiddleware');

// Driver route — no strict auth (same pattern as SOS)
router.post('/report', upload.array('images', 3), reportAccident);

// Admin routes — all protected
router.get('/reports/stats',                protectAdmin, getAccidentStats);
router.get('/reports',                      protectAdmin, getAccidentReports);
router.get('/reports/:id',                  protectAdmin, getAccidentReportById);
router.patch('/reports/:id/status',         protectAdmin, updateAccidentStatus);
router.post('/reports/:id/notify-division', protectAdmin, notifyPoliceDivision);

module.exports = router;
