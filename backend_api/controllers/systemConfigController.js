// controllers/systemConfigController.js
const SystemConfig = require('../models/systemConfigModel');
const Driver = require('../models/driverModel');
const { calculateLevel, calculateRating } = require('./demeritController');

// ─────────────────────────────────────────────────────────────────────────────
// Helper: Ensure one SystemConfig document always exists (singleton pattern)
// ─────────────────────────────────────────────────────────────────────────────
const getOrCreateConfig = async () => {
  let config = await SystemConfig.findOne();
  if (!config) {
    config = await SystemConfig.create({
      accidentNotificationRadiusKm: 10,
      officerLogoutGracePeriodMinutes: 20,
      defaultDemeritPoints: 24,
      monthlyRecoveryPoints: 2,
      recoveryPeriodMonths: 1,
      recoveryEnabled: true,
      lastRecoveryRunAt: null
    });
  }
  return config;
};

// ─────────────────────────────────────────────────────────────────────────────
// @desc    Get system configuration
// @route   GET /api/admin/system-config
// @access  Private / admin_officer, super_admin
// ─────────────────────────────────────────────────────────────────────────────
const getSystemConfig = async (req, res) => {
  try {
    const config = await getOrCreateConfig();
    res.status(200).json({ success: true, data: config });
  } catch (error) {
    console.error('[SystemConfig] Error fetching config:', error);
    res.status(500).json({ success: false, message: 'Server Error' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// @desc    Update system configuration (notification + demerit settings)
// @route   PUT /api/admin/system-config
// @access  Private / super_admin
// ─────────────────────────────────────────────────────────────────────────────
const updateSystemConfig = async (req, res) => {
  try {
    const {
      accidentNotificationRadiusKm,
      officerLogoutGracePeriodMinutes,
      defaultDemeritPoints,
      monthlyRecoveryPoints,
      recoveryPeriodMonths
    } = req.body;

    // ── Field-level validation ───────────────────────────────────────────────
    if (accidentNotificationRadiusKm !== undefined) {
      if (accidentNotificationRadiusKm < 1 || accidentNotificationRadiusKm > 100) {
        return res.status(400).json({ success: false, message: 'Radius must be between 1 and 100 km' });
      }
    }

    if (officerLogoutGracePeriodMinutes !== undefined) {
      if (officerLogoutGracePeriodMinutes < 5 || officerLogoutGracePeriodMinutes > 120) {
        return res.status(400).json({ success: false, message: 'Grace period must be between 5 and 120 minutes' });
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

    const config = await getOrCreateConfig();
    const oldDefaultPoints = config.defaultDemeritPoints;

    // Apply provided values (only update what was sent)
    if (accidentNotificationRadiusKm !== undefined)    config.accidentNotificationRadiusKm    = accidentNotificationRadiusKm;
    if (officerLogoutGracePeriodMinutes !== undefined) config.officerLogoutGracePeriodMinutes = officerLogoutGracePeriodMinutes;
    if (defaultDemeritPoints !== undefined)            config.defaultDemeritPoints            = Number(defaultDemeritPoints);
    if (monthlyRecoveryPoints !== undefined)           config.monthlyRecoveryPoints           = Number(monthlyRecoveryPoints);
    if (recoveryPeriodMonths !== undefined)            config.recoveryPeriodMonths            = Number(recoveryPeriodMonths);

    await config.save();

    console.log(`[SystemConfig] System configuration updated successfully. Default demerit points ceiling is now: ${config.defaultDemeritPoints}`);

    res.status(200).json({
      success: true,
      message: 'System configuration updated successfully',
      data: config
    });
  } catch (error) {
    console.error('[SystemConfig] Error updating config:', error);
    res.status(500).json({ success: false, message: 'Server Error' });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// @desc    Toggle the monthly recovery job on / off (without changing values)
// @route   PATCH /api/admin/system-config/recovery-toggle
// @access  Private / super_admin
// ─────────────────────────────────────────────────────────────────────────────
const toggleRecovery = async (req, res) => {
  try {
    const config = await getOrCreateConfig();

    // Flip the boolean
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
// @desc    Delete / reset demerit config to factory defaults
//          (keeps accidentNotificationRadiusKm & grace period intact)
// @route   DELETE /api/admin/system-config/demerit
// @access  Private / super_admin
// ─────────────────────────────────────────────────────────────────────────────
const resetDemeritConfig = async (req, res) => {
  try {
    const config = await getOrCreateConfig();

    config.defaultDemeritPoints  = 24;
    config.monthlyRecoveryPoints = 2;
    config.recoveryPeriodMonths  = 1;
    config.recoveryEnabled       = true;
    config.lastRecoveryRunAt     = null;

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
  resetDemeritConfig,
  getPublicSystemConfig
};
