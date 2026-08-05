const mongoose = require('mongoose');

const systemConfigSchema = new mongoose.Schema({
  // ── Accident / Officer Settings ──────────────────────────────────────────
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
  },

  // ── Demerit System Values ─────────────────────────────────────────────────

  /**
   * The default starting demerit points assigned to every new driver
   * and the ceiling that recovery cannot exceed.
   * Changing this affects all new driver registrations and the rating % calculation.
   */
  defaultDemeritPoints: {
    type: Number,
    required: true,
    default: 24,
    min: 1,
    max: 100
  },

  /**
   * Number of demerit points added to active drivers on every recovery run.
   * Maps to the former DEMERIT.MONTHLY_RECOVERY constant.
   */
  monthlyRecoveryPoints: {
    type: Number,
    required: true,
    default: 2,
    min: 1,
    max: 10
  },

  /**
   * How often (in calendar months) the recovery runs.
   * 1 = every month, 3 = every quarter, 12 = annually.
   * The cron still fires monthly but skips execution if not enough time
   * has elapsed since lastRecoveryRunAt.
   */
  recoveryPeriodMonths: {
    type: Number,
    required: true,
    default: 1,
    min: 1,
    max: 12
  },

  /**
   * Number of days a driver must have no new offenses before being eligible for demerit point recovery.
   */
  cleanRecordDays: {
    type: Number,
    required: true,
    default: 30,
    min: 0,
    max: 365
  },

  /**
   * Master switch for the monthly recovery job.
   * When false the cron runs but performs no updates.
   */
  recoveryEnabled: {
    type: Boolean,
    required: true,
    default: true
  },

  /**
   * Timestamp of the last successful recovery run.
   * Used by the cron job to enforce recoveryPeriodMonths.
   */
  lastRecoveryRunAt: {
    type: Date,
    default: null
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('SystemConfig', systemConfigSchema);
