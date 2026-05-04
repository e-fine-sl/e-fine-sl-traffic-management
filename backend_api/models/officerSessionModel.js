const mongoose = require('mongoose');

const officerSessionSchema = new mongoose.Schema({
  badgeNumber: { 
    type: String, 
    required: true, 
    index: true 
  },
  officerName: { 
    type: String, 
    required: true 
  },
  policeStation: { 
    type: String 
  },

  loginTime: { 
    type: Date, 
    required: true 
  },
  loginLocation: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: [Number]   // [longitude, latitude]
  },
  loginAddress: { 
    type: String, 
    default: '' 
  },

  logoutTime: { 
    type: Date, 
    default: null 
  },
  logoutLocation: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: [Number]
  },
  logoutAddress: { 
    type: String, 
    default: '' 
  },

  sessionDurationMinutes: { 
    type: Number, 
    default: null 
  },

  // Reference to accident reports that occurred during this session's grace window
  triggeredAccidentAlerts: [{ 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'AccidentReport' 
  }]
}, { 
  timestamps: true, 
  collection: 'officersessions' 
});

// Indexes
officerSessionSchema.index({ badgeNumber: 1 });
officerSessionSchema.index({ loginTime: -1 });
officerSessionSchema.index({ loginLocation: '2dsphere' });

module.exports = mongoose.model('OfficerSession', officerSessionSchema);
