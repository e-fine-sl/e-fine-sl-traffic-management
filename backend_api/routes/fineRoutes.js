const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/authMiddleware');

// Import all required functions from fineController only (avoid duplicate declarations)
const {
    getOffenses,
    addOffense,
    issueFine,
    getFineHistory,
    getDriverPendingFines,
    payFine,
    getDriverPaidHistory,
    getDashboardStats
} = require('../controllers/fineController');

router.get('/offenses', protect, getOffenses);
router.post('/add', protect, addOffense);
router.post('/issue', protect, issueFine);
router.get('/dashboard-stats', protect, getDashboardStats);
router.get('/history', protect, getFineHistory);
router.get('/pending', protect, getDriverPendingFines);
router.get('/driver-history', protect, getDriverPaidHistory);
router.post('/:id/pay', protect, payFine);

module.exports = router;
