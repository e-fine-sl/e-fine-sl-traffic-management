const Driver = require('../models/driverModel');
const Offense = require('../models/offenseModel');
const { HTTP, DEMERIT, LICENSE_STATUS } = require('../config/constants');

/**
 * Calculates the demerit level descriptive tag.
 * @param {number} points - Current demerit points (0–24)
 * @returns {string} EXCELLENT | GOOD | FAIR | WARNING | DANGER | SUSPENDED
 */
const calculateLevel = (points) => {
  if (points <= DEMERIT.SUSPENSION_THRESHOLD) return LICENSE_STATUS.SUSPENDED;
  
  const max = DEMERIT.DEFAULT_POINTS;
  const ratio = points / max;

  if (ratio >= 1.0) return 'EXCELLENT';
  if (ratio >= 0.8) return 'GOOD';
  if (ratio >= 0.6) return 'FAIR';
  if (ratio >= 0.4) return 'WARNING';
  return 'DANGER';
}

/**
 * Calculates the numerical rating (0.0 – 5.0 stars).
 * @param {number} points 
 * @returns {number}
 */
const calculateRating = (points) => {
  const max = DEMERIT.DEFAULT_POINTS;
  const rawRating = (points / max) * 5;
  return Math.round(rawRating * 10) / 10; // Round to 1 decimal place
}

/**
 * Deducts demerit points after a fine is issued and updates the driver's rating.
 * @param {string} licenseNumber - License Number of the driver
 * @param {string} offenseId - MongoDB ObjectId of the offense
 */
exports.applyDemeritPoints = async (licenseNumber, offenseId) => {
  const [offense, driver] = await Promise.all([
    Offense.findById(offenseId),
    Driver.findOne({ licenseNumber: { $regex: new RegExp(`^${licenseNumber}$`, 'i') } }),
  ]);

  if (!offense) throw new Error(`Offense not found: ${offenseId}`);
  if (!driver) throw new Error(`Driver not found with license: ${licenseNumber}`);

  // Deduct points — floor at 0
  driver.demeritPoints = Math.max(0, driver.demeritPoints - offense.demeritValue);

  // Update Rating & Level
  driver.ratingScore = calculateRating(driver.demeritPoints);
  driver.demeritLevel = calculateLevel(driver.demeritPoints);

  // Check for suspension threshold
  if (driver.demeritPoints <= DEMERIT.SUSPENSION_THRESHOLD && driver.licenseStatus !== LICENSE_STATUS.SUSPENDED) {
    driver.licenseStatus = LICENSE_STATUS.SUSPENDED;
    driver.suspendedAt = new Date();
  }

  await driver.save();

  return {
    remainingPoints: driver.demeritPoints,
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
    const driver = await Driver.findOne({ licenseNumber: { $regex: new RegExp(`^${req.params.licenseNumber}$`, 'i') } })
      .select('demeritPoints ratingScore licenseStatus demeritLevel suspendedAt');

    if (!driver) {
      return res.status(HTTP.NOT_FOUND).json({ message: 'Driver not found' });
    }

    res.json({
      demeritPoints: driver.demeritPoints,
      ratingScore: driver.ratingScore,
      licenseStatus: driver.licenseStatus,
      demeritLevel: driver.demeritLevel,
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
  calculateRating
};
