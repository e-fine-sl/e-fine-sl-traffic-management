const express = require('express');
const router = express.Router();
const ReportController = require('../controllers/reportController');
const { protectAdmin } = require('../middleware/authMiddleware');

// Dedicated Modular Report Subsystem Routes
router.post('/verify-driver', protectAdmin, ReportController.verifyDriver);
router.post('/monthly-fines', protectAdmin, ReportController.generateMonthlyReport);
router.post('/payments', protectAdmin, ReportController.generatePaymentReport);
router.post('/driver-violations', protectAdmin, ReportController.generateDriverViolationReport);
router.post('/vehicle-violations', protectAdmin, ReportController.generateVehicleReport);
router.post('/officer-performance', protectAdmin, ReportController.generateOfficerReport);

module.exports = router;
