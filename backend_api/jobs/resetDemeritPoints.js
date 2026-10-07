// jobs/resetDemeritPoints.js
// ─────────────────────────────────────────────────────────────────────────────
// Scheduled Job: Monthly Good-Behaviour Demerit Point Recovery
//
// Runs at 00:00 on the 1st of every month (CRON.MONTHLY_RESET).
// Behaviour is fully controlled by the SystemConfig document in the database.
// Suspended drivers are always EXCLUDED and must be reactivated by an Admin.
// ─────────────────────────────────────────────────────────────────────────────

const cron = require('node-cron');
const Driver = require('../models/driverModel');
const SystemConfig = require('../models/systemConfigModel');
const { DEMERIT, LICENSE_STATUS, CRON } = require('../config/constants');
const { calculateLevel, calculateRating } = require('../controllers/demeritController');
const { sendToToken } = require('../services/fcmService');
const { sendDemeritAdjustmentEmail } = require('../services/emailService');

cron.schedule(CRON.MONTHLY_RESET, async () => {
  console.log('[CRON/RECOVERY] Triggered — reading live config from database...');

  try {
    // ── 1. Load live configuration from DB ──────────────────────────────────
    let config = await SystemConfig.findOne();

    if (!config) {
      console.warn('[CRON/RECOVERY] No SystemConfig found in DB — using hardcoded fallback values.');
      config = {
        recoveryEnabled: true,
        monthlyRecoveryPoints: DEMERIT.MONTHLY_RECOVERY || 2,
        defaultDemeritPoints: DEMERIT.DEFAULT_POINTS,
        recoveryPeriodMonths: 1,
        lastRecoveryRunAt: null,
        save: async () => {}
      };
    }

    // ── 2. Respect master switch ────────────────────────────────────────────
    if (!config.recoveryEnabled) {
      console.log('[CRON/RECOVERY] Recovery is currently DISABLED by admin. Skipping run.');
      return;
    }

    // ── 3. Enforce recoveryPeriodMonths ─────────────────────────────────────
    if (config.lastRecoveryRunAt) {
      const now = new Date();
      const last = new Date(config.lastRecoveryRunAt);

      const monthsElapsed =
        (now.getFullYear() - last.getFullYear()) * 12 +
        (now.getMonth() - last.getMonth());

      if (monthsElapsed < config.recoveryPeriodMonths) {
        console.log(
          `[CRON/RECOVERY] Skipping — only ${monthsElapsed} month(s) since last run. ` +
          `Period set to ${config.recoveryPeriodMonths} month(s).`
        );
        return;
      }
    }

    // ── 4. Fetch eligible drivers ───────────────────────────────────────────
    const recoveryPoints = config.monthlyRecoveryPoints || 2;
    const ceiling = config.defaultDemeritPoints || 24;
    const cleanPeriodDays = config.cleanRecordDays || 30;
    const cleanCutoffDate = new Date(Date.now() - cleanPeriodDays * 24 * 60 * 60 * 1000);

    const driversToUpdate = await Driver.find({
      licenseStatus: LICENSE_STATUS.ACTIVE,
      demeritPoints: { $lt: ceiling },
      $or: [
        { lastOffenseDate: null },
        { lastOffenseDate: { $lt: cleanCutoffDate } }
      ]
    });

    // ── 5. Apply recovery & dispatch notifications ──────────────────────────
    let updatedCount = 0;

    for (const driver of driversToUpdate) {
      const previousPoints = driver.demeritPoints;
      const newPoints = Math.min(ceiling, driver.demeritPoints + recoveryPoints);

      driver.demeritPoints = newPoints;
      driver.demeritLevel  = calculateLevel(newPoints);
      driver.ratingScore   = calculateRating(newPoints);

      await driver.save();
      updatedCount++;

      // 1. Dispatch Email
      if (driver.email) {
        try {
          await sendDemeritAdjustmentEmail(
            driver,
            previousPoints,
            newPoints,
            'Automated Good-Behavior Recovery Cycle',
            true
          );
        } catch (emailErr) {
          console.error(`[CRON/RECOVERY] Email notification error for driver ${driver.licenseNumber}:`, emailErr.message);
        }
      }

      // 2. Dispatch FCM Push Notification
      if (driver.fcmToken) {
        try {
          await sendToToken(driver.fcmToken, {
            title: 'Good Driver Demerit Recovery',
            body: `You have been rewarded with +${newPoints - previousPoints} demerit recovery points. New balance: ${newPoints}/${ceiling} pts (${driver.demeritLevel}).`,
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
          console.error(`[CRON/RECOVERY] FCM error for driver ${driver.licenseNumber}:`, fcmErr.message);
        }
      }
    }

    // ── 6. Persist lastRecoveryRunAt ─────────────────────────────────────────
    if (config._id) {
      config.lastRecoveryRunAt = new Date();
      await config.save();
    }

    if (updatedCount === 0) {
      console.log('[CRON/RECOVERY] No eligible active drivers needed recovery. Timestamp updated.');
    } else {
      console.log(
        `[CRON/RECOVERY] Complete — ${updatedCount} driver(s) rewarded with +${recoveryPoints} points ` +
        `(ceiling: ${ceiling}, period: every ${config.recoveryPeriodMonths} month(s)). Notifications dispatched.`
      );
    }

  } catch (err) {
    console.error('[CRON/RECOVERY] Point recovery failed:', err.message);
  }
});

console.log('[CRON/RECOVERY] Monthly demerit recovery job registered (DB-driven configuration).');
