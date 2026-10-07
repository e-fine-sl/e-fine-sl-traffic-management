const express = require('express');
const router = express.Router();
const { generateHash, handlePaymentNotification } = require('../controllers/paymentController');

// URL: /api/payment/hash
router.post('/hash', generateHash);

// URL: /api/payment/notify
router.post('/notify', handlePaymentNotification);

module.exports = router;
