// models/adminSessionModel.js
// Tracks every active admin login session in the backend_api.
const mongoose = require('mongoose');

const adminSessionSchema = new mongoose.Schema({
  userId:           { type: String, required: true, index: true },
  userRole:         { type: String, required: true },

  // Unique session token stored in frontend
  sessionToken:     { type: String, required: true, unique: true, index: true },

  // SHA-256 hash of the refresh JWT
  refreshTokenHash: { type: String, required: true, index: true },

  // Device/browser info
  deviceInfo:       { type: String, default: 'Unknown' },

  createdAt:        { type: Date, default: Date.now },
  expiresAt:        { type: Date, required: true },

  // Revocation status
  isRevoked:        { type: Boolean, default: false },
});

// Auto-delete expired sessions from DB
adminSessionSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 2592000 });

module.exports = mongoose.model('AdminSession', adminSessionSchema, 'admin_auth_sessions');
