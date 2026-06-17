const mongoose = require('mongoose');

const statusHistorySchema = new mongoose.Schema({
  status: { type: String, required: true },
  changedBy: { type: String, required: true },
  changedAt: { type: Date, default: Date.now },
  note: { type: String }
}, { _id: false });

const accidentReportSchema = new mongoose.Schema({
  driverLicense: { type: String, required: true },
  driverName: { type: String, required: true },
  driverPhone: { type: String },
  accidentType: { 
    type: String, 
    required: true,
    enum: ['Vehicle Collision', 'Pedestrian Accident', 'Hit & Run', 'Road Hazard / Obstruction', 'Other']
  },
  description: { type: String, maxlength: 200, default: '' },
  location: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: { type: [Number], required: true }
  },
  province: { type: String, default: 'Unknown' },
  district: { type: String, default: 'Unknown' },
  policeDivision: { type: String, default: 'Unknown' },
  locationAddress: { type: String, default: '' },
  officersNotified: { type: Number, default: 0 },
  stationNotified: { type: String, default: '' },
  stationEmail: { type: String, default: '' },
  nearbyStationsNotified: { type: [String], default: [] },
  nearbyStationEmails: { type: [String], default: [] },
  emailSent: { type: Boolean, default: false },
  divisionNotifiedAt: { type: Date, default: null },
  status: { 
    type: String, 
    enum: ['OPEN', 'ACKNOWLEDGED', 'RESOLVED'], 
    default: 'OPEN' 
  },
  acknowledgedBy: { type: String, default: null },
  resolvedBy: { type: String, default: null },
  statusHistory: [statusHistorySchema],
  images: [{ type: String }],
  reportedAt: { type: Date, default: Date.now }
}, { 
  timestamps: true, 
  collection: 'accidentreports' 
});

// Indexes
accidentReportSchema.index({ location: '2dsphere' });
accidentReportSchema.index({ province: 1, status: 1 });
accidentReportSchema.index({ district: 1, status: 1 });
accidentReportSchema.index({ policeDivision: 1, status: 1 });
accidentReportSchema.index({ reportedAt: -1 });

module.exports = mongoose.model('AccidentReport', accidentReportSchema);
