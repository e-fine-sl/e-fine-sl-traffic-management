const mongoose = require('mongoose');

const systemConfigSchema = new mongoose.Schema({
  accidentNotificationRadiusKm: {
    type: Number,
    required: true,
    default: 10, // Default to 10km
    min: 1,      // Minimum 1km radius
    max: 100     // Maximum 100km radius to prevent excessive queries
  },
  officerLogoutGracePeriodMinutes: {
    type: Number,
    required: true,
    default: 20, // Default to 20 minutes
    min: 5,
    max: 120
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('SystemConfig', systemConfigSchema);
