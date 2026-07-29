// jobs/resetDemeritPoints.js
// ─────────────────────────────────────────────────────────────────────────────
// Scheduled Job: Monthly Good-Behaviour Demerit Point Recovery
//
// Runs at 00:00 on the 1st of every month (CRON.MONTHLY_RESET).
// Behaviour is fully controlled by the SystemConfig document in the database:
//
//   recoveryEnabled       — if false, the job runs but skips all updates
//   monthlyRecoveryPoints — points to add per eligible driver (replaces constant)
//   defaultDemeritPoints  — ceiling; recovery cannot exceed this value
//   recoveryPeriodMonths  — how many calendar months must elapse between runs
//   lastRecoveryRunAt     — timestamp of the last successful run (tracked in DB)
//
// Suspended drivers are always EXCLUDED and must be reactivated by an Admin.
// ─────────────────────────────────────────────────────────────────────────────

const cron = require('node-cron');
const Driver = require('../models/driverModel');
const SystemConfig = require('../models/systemConfigModel');
const { DEMERIT, LICENSE_STATUS, CRON } = require('../config/constants');
const { calculateLevel, calculateRating } = require('../controllers/demeritController');

cron.schedule(CRON.MONTHLY_RESET, async () => {
  console.log('[CRON/RECOVERY] Triggered — reading live config from database...');

  try {
    // ── 1. Load live configuration from DB ──────────────────────────────────
    let config = await SystemConfig.findOne();

    if (!config) {
      // Safety fallback: use hardcoded constants if DB record missing
      console.warn('[CRON/RECOVERY] No SystemConfig found in DB — using hardcoded fallback values.');
      config = {
        recoveryEnabled: true,
        monthlyRecoveryPoints: DEMERIT.MONTHLY_RECOVERY || 2,
        defaultDemeritPoints: DEMERIT.DEFAULT_POINTS,
        recoveryPeriodMonths: 1,
        lastRecoveryRunAt: null,
        // Fake save for fallback — won't persist
        save: async () => {}
      };
    }

    // ── 2. Respect the master kill-switch ───────────────────────────────────
    if (!config.recoveryEnabled) {
      console.log('[CRON/RECOVERY] Recovery is currently DISABLED by admin. Skipping run.');
      return;
    }

    // ── 3. Enforce recoveryPeriodMonths ─────────────────────────────────────
    //       If period is e.g. 3, skip runs that are too early.
    if (config.lastRecoveryRunAt) {
      const now = new Date();
      const last = new Date(config.lastRecoveryRunAt);

      // Calculate elapsed months (approximate)
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

    // ── 4. Fetch eligible drivers ────────────────────────────────────────────
    const recoveryPoints = config.monthlyRecoveryPoints;
    const ceiling = config.defaultDemeritPoints;

    const driversToUpdate = await Driver.find({
      licenseStatus: LICENSE_STATUS.ACTIVE,
      demeritPoints: { $lt: ceiling }
    });

    if (driversToUpdate.length === 0) {
      // No drivers need recovery — we still update lastRecoveryRunAt below
    }

    // ── 5. Apply recovery ────────────────────────────────────────────────────
    let updatedCount = 0;

    for (const driver of driversToUpdate) {
      const newPoints = Math.min(ceiling, driver.demeritPoints + recoveryPoints);

      driver.demeritPoints = newPoints;
      driver.demeritLevel  = calculateLevel(newPoints);
      driver.ratingScore   = calculateRating(newPoints);

      await driver.save();
      updatedCount++;
    }

    // ── 6. Persist lastRecoveryRunAt ─────────────────────────────────────────
    // Update timestamp regardless of whether any drivers were updated,
    // so the period enforcement works correctly on the next run.
    if (config._id) {
      config.lastRecoveryRunAt = new Date();
      await config.save();
    }

    if (updatedCount === 0) {
      console.log('[CRON/RECOVERY] No eligible active drivers needed recovery. Timestamp updated.');
    } else {
      console.log(
        `[CRON/RECOVERY] Complete — ${updatedCount} driver(s) rewarded with +${recoveryPoints} points ` +
        `(ceiling: ${ceiling}, period: every ${config.recoveryPeriodMonths} month(s)).`
      );
    }

  } catch (err) {
    console.error('[CRON/RECOVERY] Point recovery failed:', err.message);
  }
});

console.log('[CRON/RECOVERY] Monthly demerit recovery job registered (DB-driven configuration).');
