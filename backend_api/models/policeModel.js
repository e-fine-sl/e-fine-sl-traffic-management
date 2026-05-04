const mongoose = require('mongoose');
const { ROLES } = require('../config/constants');

const policeSchema = mongoose.Schema({
 
    name: { 
        type: String, 
        required: true 
    },
    email: { 
        type: String, 
        required: true, 
        unique: true 
    },
    badgeNumber: { 
        type: String, 
        required: true, 
        unique: true 
    },
    nic: {
        type: String,
        required: true,
        unique: true
    },
    phone: {
        type: String,
        required: true
    },
    password: { 
        type: String, 
        required: true 
    },


    policeStation: { 
        type: String, 
        required: true 
    },
    position: { 
        type: String, 
        required: true //  OIC, Sergeant, Constable
    },
    profileImage: { 
        type: String, 
        default: 'https://cdn-icons-png.flaticon.com/512/206/206853.png' // Default image
    },

    // --- Role 
    role: { 
        type: String, 
        default: ROLES.OFFICER 
    },

    // ── SOS / FCM FIELDS ─────────────────────────────────────────────────────
    // Firebase Cloud Messaging device token — updated on every login
    fcmToken: {
        type: String,
        default: null,
    },

    // GeoJSON Point — { type: 'Point', coordinates: [lng, lat] }
    // IMPORTANT: MongoDB GeoJSON stores coordinates as [longitude, latitude]
    location: {
        type: {
            type: String,
            enum: ['Point'],
            default: 'Point',
        },
        coordinates: {
            type: [Number], // [longitude, latitude]
            default: [0.0, 0.0], // Initial dummy location to satisfy 2dsphere index
        },
    },

    // Officer active status — used to filter $near queries (only alert ACTIVE officers)
    isActive: {
        type: Boolean,
        default: true,
    },

    // ── Session Tracking Fields ────────────────────────────────────────────
    lastLoginTime: {
        type: Date,
        default: null,
    },
    lastLoginLocation: {
        type: {
            type: String,
            enum: ['Point'],
            default: 'Point',
        },
        coordinates: {
            type: [Number],     // [longitude, latitude] — GeoJSON order
            default: [0.0, 0.0],
        },
    },
    lastLogoutTime: {
        type: Date,
        default: null,
    },
}, {
    timestamps: true
});  // CreatedAt, UpdatedAt 

// ── 2dsphere index (REQUIRED for $near / $geoWithin queries) ─────────────────
// This MUST exist before any geospatial query is run.
policeSchema.index({ location: '2dsphere' });
policeSchema.index({ lastLoginLocation: '2dsphere' });
console.log('[PoliceModel] 2dsphere index registered on location field.');


module.exports = mongoose.model('Police', policeSchema,'polices');