const express = require('express');
const router = express.Router();
const { getDriverStatus } = require('../controllers/demeritController');
const { getPublicSystemConfig } = require('../controllers/systemConfigController');

// GET public system / demerit configuration for drivers
router.get('/config', getPublicSystemConfig);
router.get('/system-config', getPublicSystemConfig);

// GET demerit status for a specific driver
router.get('/:licenseNumber/status', getDriverStatus);

module.exports = router;
