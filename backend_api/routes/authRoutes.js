const express = require('express');
const router = express.Router();

const { 
  requestVerification, 
  verifyOTP, 
  registerPolice,
  registerDriver,
  loginUser,
  forgotPassword,
  verifyResetOTP,
  resetPassword,
  getMe,
  verifyDriver,
  updateProfileImage,
  updateProfile,
  checkFieldExistence
} = require('../controllers/authController');


const { protect } = require('../middleware/authMiddleware');

// --- Routes ---

router.post('/request-verification', requestVerification);
router.post('/verify-otp', verifyOTP);      
router.post('/register-police', registerPolice);
router.post('/register-driver', registerDriver);
router.post('/login', loginUser);
router.post('/forgot-password', forgotPassword);
router.post('/verify-reset-otp', verifyResetOTP);
router.post('/reset-password', resetPassword);

router.get('/check-exists', checkFieldExistence);

// Protected Routes (Login වෙලා ඉන්න ඕන)
router.get('/me', protect, getMe);
router.put('/verify-driver', protect, verifyDriver);
router.put('/update-profile-image', protect, updateProfileImage);
router.put('/update-profile', protect, updateProfile);

module.exports = router;