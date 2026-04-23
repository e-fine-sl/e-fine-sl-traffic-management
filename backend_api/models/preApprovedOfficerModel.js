const mongoose = require('mongoose');

const preApprovedOfficerSchema = new mongoose.Schema(
  {
    badgeNumber: {
      type: String,
      required: [true, 'Badge number is required'],
      unique: true,
      trim: true,
    },
    isRegistered: {
      type: Boolean,
      default: false,
    },
    registeredAt: {
      type: Date,
      default: null,
    },

    notes: {
      type: String,
      default: '',
    },
  },
  {
    timestamps: true,
    collection: 'preapprovedofficers',
  }
);

module.exports = mongoose.model('PreApprovedOfficer', preApprovedOfficerSchema);
