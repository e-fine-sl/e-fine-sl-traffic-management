const mongoose = require('mongoose');
const { AUTH } = require('../config/constants');

const verificationSchema = mongoose.Schema({
  badgeNumber: { type: String, required: true }, 
  stationCode: { type: String, required: true }, 
  otp:         { type: String, required: true }, 
  expiresAt:   { type: Date, default: null },     // Optional: used by license-recovery (10 min)
  createdAt:   { type: Date, default: Date.now, expires: AUTH.OTP_EXPIRY_MINUTES * 60 }
});

module.exports = mongoose.model('Verification', verificationSchema);