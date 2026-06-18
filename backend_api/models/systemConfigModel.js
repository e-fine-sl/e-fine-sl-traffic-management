const mongoose = require('mongoose');

const systemConfigSchema = new mongoose.Schema({
  accidentNotificationRadiusKm: {
    type: Number,
    required: true,
    default: 10, // Default to 10km
    min: 1,      // Minimum 1km radius
    max: 100     // Maximum 100km radius to prevent excessive queries
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('SystemConfig', systemConfigSchema);
