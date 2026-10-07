const mongoose = require('mongoose');
const { DEMERIT } = require('../config/constants');

const offenseSchema = mongoose.Schema(
  {
    offenseName: {
      type: String,
      required: true,
      unique: true, // Ekama waradda deparak liyawenne na
    },
    amount: {
      type: Number,
      required: true,
    },
    description: {
      type: String,
      required: false,
    },
    sectionOfAct: { // Panatha (Example: 123-A)
      type: String,
      required: false,
    },
    demeritValue: {
      type: Number,
      required: true,
      default: DEMERIT.OFFENSE_LEVELS.P1_MINOR,
      min: 1,
      max: DEMERIT.OFFENSE_LEVELS.P4_CRITICAL,
    },
    // Severity tag derived from demeritValue (MINOR=2, MODERATE=4, SERIOUS=6, CRITICAL=8)
    severity: {
      type: String,
      enum: Object.values(DEMERIT.SEVERITY_BY_POINTS),
      default: 'MINOR',
    },
    // Spot fine metadata (Gazette Extraordinary No. 2054/9 of 15 Jan 2018 — 33 offences)
    offenseCode: { type: String, unique: true, sparse: true }, // e.g. SF-01
    spotFineNo: { type: Number }, // 1 – 33, order in the gazette schedule
    isSpotFine: { type: Boolean, default: false },
    // Inactive offenses are hidden from the officer's dropdown but kept for fine history
    isActive: { type: Boolean, default: true },
  },
  {
    timestamps: true,
  }
);

// Keep severity in sync when demeritValue is created / edited (e.g. from the admin dashboard)
offenseSchema.pre('save', function () {
  const p = this.demeritValue;
  this.severity = p >= 8 ? 'CRITICAL' : p >= 6 ? 'SERIOUS' : p >= 4 ? 'MODERATE' : 'MINOR';
});

module.exports = mongoose.model('Offense', offenseSchema);
