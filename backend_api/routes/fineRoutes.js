const express = require('express');
const router = express.Router();
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

// URL: /api/fines/offenses (දඩ වර්ග ටික ගන්න)
router.get('/offenses', getOffenses);

// URL: /api/fines/add (Admin use only - අලුත් දඩ වර්ගයක් සිස්ටම් එකට දාන්න)
router.post('/add', addOffense);

// --- අලුත් Routes ---

// URL: /api/fines/issue (අලුත් දඩයක් ගහන්න - Data Save කරන්න)
router.post('/issue', issueFine);

// URL: /api/fines/dashboard-stats (Dashboard stats - Police Officer ID අවශ්‍ය)
router.get('/dashboard-stats', getDashboardStats);

// URL: /api/fines/history (ගහපු දඩ වල හිස්ට්‍රි එක ගන්න - Police Only)
router.get('/history', getFineHistory);

// URL: /api/fines/pending (Driver ගේ Pending දඩ ගන්න)
router.get('/pending', getDriverPendingFines);

// URL: /api/fines/driver-history (Driver ගේ Paid දඩ ගන්න)
router.get('/driver-history', getDriverPaidHistory);

// URL: /api/fines/:id/pay (දඩයක් ගෙවන්න)
router.post('/:id/pay', payFine);

module.exports = router;

//update the route name
