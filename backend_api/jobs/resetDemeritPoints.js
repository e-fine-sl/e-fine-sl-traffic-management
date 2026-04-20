const cron = require('node-cron');
const Driver = require('../models/driverModel');
const { DEMERIT, LICENSE_STATUS, CRON } = require('../config/constants');
const { calculateLevel, calculateRating } = require('../controllers/demeritController');

/**
 * Scheduled Job: Monthly Good Behavior Demerit Point Recovery
 * Runs at 00:00 on the 1st of every month.
 * Rewards active drivers by restoring points up to the maximum (24).
 * Suspended drivers are EXCLUDED and must be reactivated by an Admin.
 */
cron.schedule(CRON.MONTHLY_RESET, async () => {
  console.log('[CRON/RECOVERY] Running monthly point recovery for active drivers...');

  try {
    const driversToUpdate = await Driver.find({
      licenseStatus: LICENSE_STATUS.ACTIVE,
      demeritPoints: { $lt: DEMERIT.DEFAULT_POINTS }
    });

    let updatedCount = 0;

    for (const driver of driversToUpdate) {
      // Increment points but cap at DEFAULT_POINTS (24)
      const newPoints = Math.min(
        DEMERIT.DEFAULT_POINTS,
        driver.demeritPoints + (DEMERIT.MONTHLY_RECOVERY || 2)
      );

      driver.demeritPoints = newPoints;
      driver.demeritLevel = calculateLevel(newPoints);
      driver.ratingScore = calculateRating(newPoints);

      await driver.save();
      updatedCount++;
    }

    console.log(`[CRON/RECOVERY] Recovery complete. ${updatedCount} active driver(s) rewarded.`);

  } catch (err) {
    console.error('[CRON/RECOVERY] Point recovery failed:', err.message);
  }
});

console.log('[CRON/RECOVERY] Monthly demerit recovery job registered.');
