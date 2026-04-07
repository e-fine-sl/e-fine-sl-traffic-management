// models/adminTokenConfigModel.js
// Stores the configurable expiry settings for Admin tokens.
// You can directly edit these values in MongoDB (admin_token_configs collection)
// and the next login will automatically pick up the new values.
//
// Defaults (set on first boot if no document exists):
//   access_token_expiry_minutes  = 15   (15 minutes)
//   refresh_token_expiry_hours   = 1    (1 hour)  — set to more for testing
//   session_token_expiry_days    = 7    (1 week)

const mongoose = require('mongoose');

const adminTokenConfigSchema = new mongoose.Schema(
    {
        access_token_expiry_minutes: {
            type: Number,
            default: 15,
            min: 1,
            comment: 'How long the access token is valid (in minutes). Default: 15'
        },
        refresh_token_expiry_hours: {
            type: Number,
            default: 1,
            min: 1,
            comment: 'How long the refresh token is valid (in hours). Default: 1 (testing)'
        },
        session_token_expiry_days: {
            type: Number,
            default: 7,
            min: 1,
            comment: 'How long the session remains active (in days). Default: 7 (1 week)'
        },
        updated_at: {
            type: Date,
            default: Date.now
        }
    },
    {
        // Only one config document is ever needed
        collection: 'admin_token_configs'
    }
);

module.exports = mongoose.model('AdminTokenConfig', adminTokenConfigSchema, 'admin_token_configs');
