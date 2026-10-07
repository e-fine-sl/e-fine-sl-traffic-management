const express = require('express');
const router = express.Router();
const { getMyWallet } = require('../controllers/walletController');
const { protect } = require('../middleware/authMiddleware');

// Get wallet details for the authenticated driver
router.get('/', protect, getMyWallet);

module.exports = router;
