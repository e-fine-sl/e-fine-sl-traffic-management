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

router.get('/offenses', getOffenses);


router.post('/add', addOffense);


router.post('/issue', issueFine);


router.get('/dashboard-stats', getDashboardStats);


router.get('/history', getFineHistory);


router.get('/pending', getDriverPendingFines);

router.get('/driver-history', getDriverPaidHistory);

router.post('/:id/pay', payFine);

module.exports = router;

//update the route name
