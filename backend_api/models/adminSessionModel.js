// models/adminSessionModel.js
// Tracks every active admin login session in the backend_api.
// Both token expiry timestamps are stored here for easy inspection during testing.
const mongoose = require('mongoose');

const adminSessionSchema = new mongoose.Schema({
  userId:           { type: String, required: true, index: true },
  userRole:         { type: String, required: true },

  // Unique session token (UUID) stored in the frontend
  sessionToken:     { type: String, required: true, unique: true, index: true },

  // SHA-256 hash of the refresh JWT — never store raw refresh token
  refreshTokenHash: { type: String, required: true, index: true },

  // Device/browser info for session listing
  deviceInfo:       { type: String, default: 'Unknown' },

  createdAt:             { type: Date, default: Date.now },

  // Session token expiry (e.g. 7 days) — visible directly in DB
  expiresAt:             { type: Date, required: true },

  // Refresh token expiry (e.g. 1 hour for testing) — visible directly in DB
  refreshTokenExpiresAt: { type: Date, required: true },

  // Set to true on logout or revocation
  isRevoked:        { type: Boolean, default: false },
});

// Auto-delete expired sessions from DB after 30 days past their expiry
adminSessionSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 2592000 });

module.exports = mongoose.model('AdminSession', adminSessionSchema, 'admin_auth_sessions');
