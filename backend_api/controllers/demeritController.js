const Driver = require('../models/driverModel');
const Offense = require('../models/offenseModel');
const SystemConfig = require('../models/systemConfigModel');
const { HTTP, DEMERIT, LICENSE_STATUS } = require('../config/constants');

/**
 * Helper to fetch the active defaultDemeritPoints ceiling from SystemConfig.
 * @returns {Promise<number>}
 */
const getDefaultPoints = async () => {
  try {
    const config = await SystemConfig.findOne();
    return config?.defaultDemeritPoints || DEMERIT.DEFAULT_POINTS;
  } catch (err) {
    return DEMERIT.DEFAULT_POINTS;
  }
};

/**
 * Calculates the demerit level descriptive tag.
 * @param {number} points - Current demerit points
 * @param {number} max - Max default demerit points (ceiling)
 * @returns {string} EXCELLENT | GOOD | FAIR | WARNING | DANGER | SUSPENDED
 */
const calculateLevel = (points, max = DEMERIT.DEFAULT_POINTS) => {
  if (points <= DEMERIT.SUSPENSION_THRESHOLD) return LICENSE_STATUS.SUSPENDED;
  
  const ratio = points / (max || DEMERIT.DEFAULT_POINTS);

  if (ratio >= 1.0) return 'EXCELLENT';
  if (ratio >= 0.8) return 'GOOD';
  if (ratio >= 0.6) return 'FAIR';
  if (ratio >= 0.4) return 'WARNING';
  return 'DANGER';
};

/**
 * Calculates the numerical rating (0.0 – 5.0 stars).
 * @param {number} points 
 * @param {number} max - Max default demerit points (ceiling)
 * @returns {number}
 */
const calculateRating = (points, max = DEMERIT.DEFAULT_POINTS) => {
  const ceiling = max || DEMERIT.DEFAULT_POINTS;
  const rawRating = (points / ceiling) * 5;
  return Math.round(rawRating * 10) / 10; // Round to 1 decimal place
};

/**
 * Deducts demerit points after a fine is issued and updates the driver's rating.
 * @param {string} licenseNumber - License Number of the driver
 * @param {string} offenseId - MongoDB ObjectId of the offense
 */
exports.applyDemeritPoints = async (licenseNumber, offenseId) => {
  const [offense, driver, maxPoints] = await Promise.all([
    Offense.findById(offenseId),
    Driver.findOne({ licenseNumber: { $regex: new RegExp(`^${licenseNumber}$`, 'i') } }),
    getDefaultPoints()
  ]);

  if (!offense) throw new Error(`Offense not found: ${offenseId}`);
  if (!driver) throw new Error(`Driver not found with license: ${licenseNumber}`);

  // Deduct points — floor at 0
  driver.demeritPoints = Math.max(0, driver.demeritPoints - offense.demeritValue);

  // Update Rating & Level using live maxPoints
  driver.ratingScore = calculateRating(driver.demeritPoints, maxPoints);
  driver.demeritLevel = calculateLevel(driver.demeritPoints, maxPoints);

  let newlySuspended = false;
  // Check for suspension threshold
  if (driver.demeritPoints <= DEMERIT.SUSPENSION_THRESHOLD && driver.licenseStatus !== LICENSE_STATUS.SUSPENDED) {
    driver.licenseStatus = LICENSE_STATUS.SUSPENDED;
    driver.suspendedAt = new Date();
    driver.suspensionReason = 'Demerit points reduced to 0 due to traffic violations.';
    newlySuspended = true;
  }

  // Record timestamp of latest offense for good-behavior recovery period tracking
  driver.lastOffenseDate = new Date();

  await driver.save();

  // If newly suspended automatically, send Email and Push Notification
  if (newlySuspended) {
    try {
      const { sendLicenseStatusEmail } = require('../services/emailService');
      const { sendToToken } = require('../services/fcmService');

      await sendLicenseStatusEmail(driver, 'SUSPENDED', driver.suspensionReason);

      if (driver.fcmToken) {
        await sendToToken(driver.fcmToken, {
          title: 'LICENSE SUSPENDED',
          body: `Your driving license (${driver.licenseNumber}) has been SUSPENDED. Reason: ${driver.suspensionReason}`,
          data: {
            type: 'DRIVER_SUSPENDED',
            licenseNumber: driver.licenseNumber,
            reason: driver.suspensionReason
          }
        });
      }
    } catch (notifyErr) {
      console.error('[demeritController] Error sending suspension notification:', notifyErr.message);
    }
  }

  return {
    remainingPoints: driver.demeritPoints,
    defaultDemeritPoints: maxPoints,
    ratingScore: driver.ratingScore,
    status: driver.licenseStatus,
    demeritLevel: driver.demeritLevel,
    deducted: offense.demeritValue,
  };
};

/**
 * GET /api/drivers/:licenseNumber/status
 * Returns the demerit status of a driver.
 */
exports.getDriverStatus = async (req, res) => {
  try {
    const [driver, maxPoints] = await Promise.all([
      Driver.findOne({ licenseNumber: { $regex: new RegExp(`^${req.params.licenseNumber}$`, 'i') } })
        .select('demeritPoints ratingScore licenseStatus demeritLevel suspendedAt'),
      getDefaultPoints()
    ]);

    if (!driver) {
      return res.status(HTTP.NOT_FOUND).json({ message: 'Driver not found' });
    }

    const liveRating = calculateRating(driver.demeritPoints, maxPoints);
    const liveLevel = calculateLevel(driver.demeritPoints, maxPoints);

    res.json({
      demeritPoints: driver.demeritPoints,
      defaultDemeritPoints: maxPoints,
      ratingScore: liveRating,
      licenseStatus: driver.licenseStatus,
      demeritLevel: liveLevel,
      suspendedAt: driver.suspendedAt,
    });
  } catch (err) {
    res.status(HTTP.SERVER_ERROR).json({ message: err.message });
  }
};

module.exports = {
  applyDemeritPoints: exports.applyDemeritPoints,
  getDriverStatus: exports.getDriverStatus,
  calculateLevel,
  calculateRating,
  getDefaultPoints
};
