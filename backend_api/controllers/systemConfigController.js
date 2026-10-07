// controllers/systemConfigController.js
const mongoose = require('mongoose');
const SystemConfig = require('../models/systemConfigModel');
const Driver = require('../models/driverModel');
const { calculateLevel, calculateRating } = require('./demeritController');
const { LICENSE_STATUS } = require('../config/constants');

// ─────────────────────────────────────────────────────────────────────────────
// Helper: Ensure one SystemConfig document always exists (singleton pattern)
// ─────────────────────────────────────────────────────────────────────────────
const getOrCreateConfig = async () => {
  let config = await SystemConfig.findOne();
  if (!config) {
    config = await SystemConfig.create({
      accidentNotificationRadiusKm: 10,
      officerLogoutGracePeriodMinutes: 20,
      sosBroadcastRadiusKm: 15,
      emergencyEmailAlerts: true,
      emergencyPushAlerts: true,
      defaultDemeritPoints: 24,
      monthlyRecoveryPoints: 2,
      recoveryPeriodMonths: 1,
      cleanRecordDays: 30,
      recoveryEnabled: true,
      lastRecoveryRunAt: null,
      finePaymentGracePeriodDays: 14,
      minFineAmount: 500,
      maxFineAmount: 100000,
      adminSessionTimeoutMinutes: 60,
      maxLoginAttempts: 5,
      enforceAdmin2FA: false
    });
  }
  return config;
};

// ─────────────────────────────────────────────────────────────────────────────
// @desc    Get system configuration & live service health
// @route   GET /api/admin/system-config
// @access  Private / admin_officer, super_admin
// ─────────────────────────────────────────────────────────────────────────────
const getSystemConfig = async (req, res) => {
  try {
    const config = await getOrCreateConfig();
    const mongoState = mongoose.connection.readyState;
    const uptime = process.uptime();

    res.status(200).json({
      success: true,
      data: config,
      health: {
        database: mongoState === 1 ? 'HEALTHY' : 'DISCONNECTED',
        databaseLatencyMs: 12,
        serverUptimeSeconds: Math.floor(uptime),
        serverTime: new Date().toISOString(),
        fcmConfigured: Boolean(process.env.FIREBASE_SERVICE_ACCOUNT || require('fs').existsSync(require('path').join(__dirname, '../config/firebase-service-account.json'))),
        mailConfigured: Boolean(process.env.SENDGRID_API_KEY || (process.env.EMAIL_USER && process.env.EMAIL_PASS))
      }
    });
  } catch (error) {
    console.error('[SystemConfig] Error fetching config:', error);
    res.status(500).json({ success: false, message: 'Server Error' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// @desc    Update system configuration (all domains)
// @route   PUT /api/admin/system-config
// @access  Private / super_admin
// ─────────────────────────────────────────────────────────────────────────────
const updateSystemConfig = async (req, res) => {
  try {
    const {
      // Alert & Emergency
      accidentNotificationRadiusKm,
      officerLogoutGracePeriodMinutes,
      sosBroadcastRadiusKm,
      emergencyEmailAlerts,
      emergencyPushAlerts,

      // Demerit
      defaultDemeritPoints,
      monthlyRecoveryPoints,
      recoveryPeriodMonths,
      cleanRecordDays,

      // Payment
      finePaymentGracePeriodDays,
      minFineAmount,
      maxFineAmount,

      // Security
      adminSessionTimeoutMinutes,
      maxLoginAttempts,
      enforceAdmin2FA
    } = req.body;

    // ── Field Validation ────────────────────────────────────────────────────
    if (accidentNotificationRadiusKm !== undefined) {
      if (accidentNotificationRadiusKm < 1 || accidentNotificationRadiusKm > 100) {
        return res.status(400).json({ success: false, message: 'Accident radius must be between 1 and 100 km' });
      }
    }

    if (officerLogoutGracePeriodMinutes !== undefined) {
      if (officerLogoutGracePeriodMinutes < 5 || officerLogoutGracePeriodMinutes > 120) {
        return res.status(400).json({ success: false, message: 'Grace period must be between 5 and 120 minutes' });
      }
    }

    if (sosBroadcastRadiusKm !== undefined) {
      if (sosBroadcastRadiusKm < 1 || sosBroadcastRadiusKm > 100) {
        return res.status(400).json({ success: false, message: 'SOS radius must be between 1 and 100 km' });
      }
    }

    if (defaultDemeritPoints !== undefined) {
      const v = Number(defaultDemeritPoints);
      if (isNaN(v) || v % 1 !== 0 || v < 1 || v > 100) {
        return res.status(400).json({ success: false, message: 'Default demerit points must be a whole number between 1 and 100' });
      }
    }

    if (monthlyRecoveryPoints !== undefined) {
      const v = Number(monthlyRecoveryPoints);
      if (isNaN(v) || v % 1 !== 0 || v < 1 || v > 10) {
        return res.status(400).json({ success: false, message: 'Monthly recovery points must be a whole number between 1 and 10' });
      }
    }

    if (recoveryPeriodMonths !== undefined) {
      const v = Number(recoveryPeriodMonths);
      if (isNaN(v) || v % 1 !== 0 || v < 1 || v > 12) {
        return res.status(400).json({ success: false, message: 'Recovery period must be a whole number between 1 and 12 months' });
      }
    }

    if (cleanRecordDays !== undefined) {
      const v = Number(cleanRecordDays);
      if (isNaN(v) || v < 0 || v > 365) {
        return res.status(400).json({ success: false, message: 'Clean record period must be between 0 and 365 days' });
      }
    }

    if (finePaymentGracePeriodDays !== undefined) {
      const v = Number(finePaymentGracePeriodDays);
      if (isNaN(v) || v < 1 || v > 90) {
        return res.status(400).json({ success: false, message: 'Payment grace period must be between 1 and 90 days' });
      }
    }

    if (adminSessionTimeoutMinutes !== undefined) {
      const v = Number(adminSessionTimeoutMinutes);
      if (isNaN(v) || v < 15 || v > 480) {
        return res.status(400).json({ success: false, message: 'Admin session timeout must be between 15 and 480 minutes' });
      }
    }

    if (maxLoginAttempts !== undefined) {
      const v = Number(maxLoginAttempts);
      if (isNaN(v) || v < 3 || v > 10) {
        return res.status(400).json({ success: false, message: 'Max login attempts must be between 3 and 10' });
      }
    }

    const config = await getOrCreateConfig();

    // Alert & Emergency
    if (accidentNotificationRadiusKm !== undefined) config.accidentNotificationRadiusKm = accidentNotificationRadiusKm;
    if (officerLogoutGracePeriodMinutes !== undefined) config.officerLogoutGracePeriodMinutes = officerLogoutGracePeriodMinutes;
    if (sosBroadcastRadiusKm !== undefined) config.sosBroadcastRadiusKm = sosBroadcastRadiusKm;
    if (emergencyEmailAlerts !== undefined) config.emergencyEmailAlerts = Boolean(emergencyEmailAlerts);
    if (emergencyPushAlerts !== undefined) config.emergencyPushAlerts = Boolean(emergencyPushAlerts);

    // Demerit
    if (defaultDemeritPoints !== undefined) config.defaultDemeritPoints = Number(defaultDemeritPoints);
    if (monthlyRecoveryPoints !== undefined) config.monthlyRecoveryPoints = Number(monthlyRecoveryPoints);
    if (recoveryPeriodMonths !== undefined) config.recoveryPeriodMonths = Number(recoveryPeriodMonths);
    if (cleanRecordDays !== undefined) config.cleanRecordDays = Number(cleanRecordDays);

    // Payment
    if (finePaymentGracePeriodDays !== undefined) config.finePaymentGracePeriodDays = Number(finePaymentGracePeriodDays);
    if (minFineAmount !== undefined) config.minFineAmount = Number(minFineAmount);
    if (maxFineAmount !== undefined) config.maxFineAmount = Number(maxFineAmount);

    // Security
    if (adminSessionTimeoutMinutes !== undefined) config.adminSessionTimeoutMinutes = Number(adminSessionTimeoutMinutes);
    if (maxLoginAttempts !== undefined) config.maxLoginAttempts = Number(maxLoginAttempts);
    if (enforceAdmin2FA !== undefined) config.enforceAdmin2FA = Boolean(enforceAdmin2FA);

    await config.save();

    console.log(`[SystemConfig] Updated system settings successfully.`);

    res.status(200).json({
      success: true,
      message: 'System configuration updated successfully',
      data: config
    });
  } catch (error) {
    console.error('[SystemConfig] Error updating config:', error);
    res.status(500).json({ success: false, message: 'Server Error', error: error.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// @desc    Toggle the monthly recovery job on / off
// @route   PATCH /api/admin/system-config/recovery-toggle
// @access  Private / super_admin
// ─────────────────────────────────────────────────────────────────────────────
const toggleRecovery = async (req, res) => {
  try {
    const config = await getOrCreateConfig();
    config.recoveryEnabled = !config.recoveryEnabled;
    await config.save();

    const status = config.recoveryEnabled ? 'enabled' : 'disabled';
    res.status(200).json({
      success: true,
      message: `Monthly demerit recovery has been ${status}`,
      data: {
        recoveryEnabled: config.recoveryEnabled
      }
    });
  } catch (error) {
    console.error('[SystemConfig] Error toggling recovery:', error);
    res.status(500).json({ success: false, message: 'Server Error' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// @desc    Manually Execute a Demerit Point Recovery Run On-Demand
// @route   POST /api/admin/system-config/trigger-recovery
// @access  Private / super_admin
// ─────────────────────────────────────────────────────────────────────────────
const triggerManualRecovery = async (req, res) => {
  try {
    const config = await getOrCreateConfig();

    const recoveryPoints = config.monthlyRecoveryPoints || 2;
    const ceiling = config.defaultDemeritPoints || 24;
    const cleanPeriodDays = config.cleanRecordDays || 30;
    const cleanCutoffDate = new Date(Date.now() - cleanPeriodDays * 24 * 60 * 60 * 1000);

    const eligibleDrivers = await Driver.find({
      licenseStatus: LICENSE_STATUS.ACTIVE,
      demeritPoints: { $lt: ceiling },
      $or: [
        { lastOffenseDate: null },
        { lastOffenseDate: { $lt: cleanCutoffDate } }
      ]
    });

    let updatedCount = 0;
    for (const driver of eligibleDrivers) {
      const previousPoints = driver.demeritPoints || 0;
      const newPoints = Math.min(ceiling, previousPoints + recoveryPoints);
      driver.demeritPoints = newPoints;
      driver.demeritLevel = calculateLevel(newPoints);
      driver.ratingScore = calculateRating(newPoints);
      await driver.save();
      updatedCount++;

      // 1. Dispatch Email Notice
      if (driver.email) {
        try {
          const { sendDemeritAdjustmentEmail } = require('../services/emailService');
          await sendDemeritAdjustmentEmail(
            driver,
            previousPoints,
            newPoints,
            'Good-Behavior Demerit Recovery Run',
            true
          );
        } catch (emailErr) {
          console.error(`[SystemConfig] Email error for driver ${driver.licenseNumber}:`, emailErr.message);
        }
      }

      // 2. Dispatch FCM Push Notification
      if (driver.fcmToken) {
        try {
          const { sendToToken } = require('../services/fcmService');
          await sendToToken(driver.fcmToken, {
            title: 'Good Driver Demerit Recovery',
            body: `You have been rewarded with +${newPoints - previousPoints} demerit points. New balance: ${newPoints}/${ceiling} pts (${driver.demeritLevel}).`,
            channelId: 'traffic_alerts',
            data: {
              type: 'DEMERIT_RECOVERY',
              licenseNumber: driver.licenseNumber,
              newPoints: String(newPoints),
              previousPoints: String(previousPoints),
              recoveryPoints: String(newPoints - previousPoints)
            }
          });
        } catch (fcmErr) {
          console.error(`[SystemConfig] FCM error for driver ${driver.licenseNumber}:`, fcmErr.message);
        }
      }
    }

    config.lastRecoveryRunAt = new Date();
    await config.save();

    res.status(200).json({
      success: true,
      message: `Manual recovery complete: ${updatedCount} driver(s) rewarded with +${recoveryPoints} points (ceiling: ${ceiling} pts).`,
      data: {
        updatedCount,
        eligibleCount: eligibleDrivers.length,
        recoveryPoints,
        ceiling,
        executedAt: config.lastRecoveryRunAt
      }
    });

  } catch (error) {
    console.error('[SystemConfig] Error running manual recovery:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to execute manual demerit recovery cycle',
      error: error.message
    });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// @desc    Reset demerit config to factory defaults
// @route   DELETE /api/admin/system-config/demerit
// @access  Private / super_admin
// ─────────────────────────────────────────────────────────────────────────────
const resetDemeritConfig = async (req, res) => {
  try {
    const config = await getOrCreateConfig();

    config.defaultDemeritPoints = 24;
    config.monthlyRecoveryPoints = 2;
    config.recoveryPeriodMonths = 1;
    config.cleanRecordDays = 30;
    config.recoveryEnabled = true;
    config.lastRecoveryRunAt = null;

    await config.save();

    res.status(200).json({
      success: true,
      message: 'Demerit configuration has been reset to factory defaults',
      data: config
    });
  } catch (error) {
    console.error('[SystemConfig] Error resetting demerit config:', error);
    res.status(500).json({ success: false, message: 'Server Error' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// @desc    Get public / driver system configuration values
// @route   GET /api/auth/system-config OR GET /api/drivers/config
// @access  Public / Driver
// ─────────────────────────────────────────────────────────────────────────────
const getPublicSystemConfig = async (req, res) => {
  try {
    const config = await getOrCreateConfig();
    const defaultPts = config.defaultDemeritPoints || 24;

    res.status(200).json({
      success: true,
      data: {
        defaultDemeritPoints: defaultPts,
        monthlyRecoveryPoints: config.monthlyRecoveryPoints,
        recoveryPeriodMonths: config.recoveryPeriodMonths,
        recoveryEnabled: config.recoveryEnabled,
      }
    });
  } catch (error) {
    console.error('[SystemConfig] Error fetching public system config:', error);
    res.status(500).json({ success: false, message: 'Server Error' });
  }
};

module.exports = {
  getSystemConfig,
  updateSystemConfig,
  toggleRecovery,
  triggerManualRecovery,
  resetDemeritConfig,
  getPublicSystemConfig
};
