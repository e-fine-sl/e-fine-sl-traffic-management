const mongoose = require('mongoose');

const systemConfigSchema = new mongoose.Schema({
  // ── Alert & Emergency Notification Settings ────────────────────────────────
  accidentNotificationRadiusKm: {
    type: Number,
    required: true,
    default: 10,
    min: 1,
    max: 100
  },
  officerLogoutGracePeriodMinutes: {
    type: Number,
    required: true,
    default: 20,
    min: 5,
    max: 120
  },
  sosBroadcastRadiusKm: {
    type: Number,
    default: 15,
    min: 1,
    max: 100
  },
  emergencyEmailAlerts: {
    type: Boolean,
    default: true
  },
  emergencyPushAlerts: {
    type: Boolean,
    default: true
  },

  // ── Demerit System Values ───────────────────────────────────────────────────
  defaultDemeritPoints: {
    type: Number,
    required: true,
    default: 24,
    min: 1,
    max: 100
  },
  monthlyRecoveryPoints: {
    type: Number,
    required: true,
    default: 2,
    min: 1,
    max: 10
  },
  recoveryPeriodMonths: {
    type: Number,
    required: true,
    default: 1,
    min: 1,
    max: 12
  },
  cleanRecordDays: {
    type: Number,
    required: true,
    default: 30,
    min: 0,
    max: 365
  },
  recoveryEnabled: {
    type: Boolean,
    required: true,
    default: true
  },
  lastRecoveryRunAt: {
    type: Date,
    default: null
  },

  // ── Payment & Fine Policy Settings ──────────────────────────────────────────
  finePaymentGracePeriodDays: {
    type: Number,
    default: 14,
    min: 1,
    max: 90
  },
  minFineAmount: {
    type: Number,
    default: 500,
    min: 100
  },
  maxFineAmount: {
    type: Number,
    default: 100000,
    min: 1000
  },

  // ── Security & Access Policies ─────────────────────────────────────────────
  adminSessionTimeoutMinutes: {
    type: Number,
    default: 60,
    min: 15,
    max: 480
  },
  maxLoginAttempts: {
    type: Number,
    default: 5,
    min: 3,
    max: 10
  },
  enforceAdmin2FA: {
    type: Boolean,
    default: false
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('SystemConfig', systemConfigSchema);
