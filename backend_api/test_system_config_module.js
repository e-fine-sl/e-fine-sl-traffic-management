// test_system_config_module.js
require('dotenv').config({ path: '.env' });
const mongoose = require('mongoose');
const {
  getSystemConfig,
  updateSystemConfig,
  toggleRecovery,
  triggerManualRecovery,
  resetDemeritConfig
} = require('./controllers/systemConfigController');

const mockReqRes = (body = {}, query = {}, params = {}, user = { role: 'super_admin', name: 'Super Admin' }) => {
  const req = { body, query, params, user };
  const res = {
    statusCode: 200,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(data) {
      this.data = data;
      return this;
    }
  };
  return { req, res };
};

async function runTests() {
  console.log('\n======================================================');
  console.log('🧪 RUNNING SYSTEM CONFIGURATION SUITE INTEGRATION TESTS');
  console.log('======================================================\n');

  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('✅ Connected to MongoDB successfully.\n');

    let testsPassed = 0;

    // Test 1: getSystemConfig
    {
      const { req, res } = mockReqRes();
      await getSystemConfig(req, res);
      if (res.statusCode === 200 && res.data.success && res.data.data && res.data.health) {
        console.log(`✅ [1/7] getSystemConfig passed: Database status=${res.data.health.database}, Default Points=${res.data.data.defaultDemeritPoints}`);
        testsPassed++;
      } else {
        console.error('❌ [1/7] getSystemConfig failed:', res.data);
      }
    }

    // Test 2: updateSystemConfig (Alerts & Emergency)
    {
      const { req, res } = mockReqRes({
        accidentNotificationRadiusKm: 15,
        officerLogoutGracePeriodMinutes: 30,
        sosBroadcastRadiusKm: 20,
        emergencyEmailAlerts: true,
        emergencyPushAlerts: true
      });
      await updateSystemConfig(req, res);
      if (res.statusCode === 200 && res.data.success && res.data.data.accidentNotificationRadiusKm === 15) {
        console.log(`✅ [2/7] updateSystemConfig (Alerts) passed: Radius=15km, SOS=20km`);
        testsPassed++;
      } else {
        console.error('❌ [2/7] updateSystemConfig (Alerts) failed:', res.data);
      }
    }

    // Test 3: updateSystemConfig (Payment & Security)
    {
      const { req, res } = mockReqRes({
        finePaymentGracePeriodDays: 21,
        minFineAmount: 500,
        maxFineAmount: 50000,
        adminSessionTimeoutMinutes: 45,
        maxLoginAttempts: 5,
        enforceAdmin2FA: true
      });
      await updateSystemConfig(req, res);
      if (res.statusCode === 200 && res.data.success && res.data.data.finePaymentGracePeriodDays === 21) {
        console.log(`✅ [3/7] updateSystemConfig (Payment & Security) passed: Grace=${res.data.data.finePaymentGracePeriodDays} days, Timeout=${res.data.data.adminSessionTimeoutMinutes}m`);
        testsPassed++;
      } else {
        console.error('❌ [3/7] updateSystemConfig (Payment & Security) failed:', res.data);
      }
    }

    // Test 4: updateSystemConfig (Demerit System)
    {
      const { req, res } = mockReqRes({
        defaultDemeritPoints: 24,
        monthlyRecoveryPoints: 3,
        recoveryPeriodMonths: 2,
        cleanRecordDays: 45
      });
      await updateSystemConfig(req, res);
      if (res.statusCode === 200 && res.data.success && res.data.data.monthlyRecoveryPoints === 3) {
        console.log(`✅ [4/7] updateSystemConfig (Demerit) passed: Recovery Points=3, Clean Days=45`);
        testsPassed++;
      } else {
        console.error('❌ [4/7] updateSystemConfig (Demerit) failed:', res.data);
      }
    }

    // Test 5: toggleRecovery
    {
      const { req, res } = mockReqRes();
      await toggleRecovery(req, res);
      const state1 = res.data.data.recoveryEnabled;
      // Toggle back
      await toggleRecovery(req, res);
      const state2 = res.data.data.recoveryEnabled;

      if (res.statusCode === 200 && res.data.success && state1 !== state2) {
        console.log(`✅ [5/7] toggleRecovery passed: State cycled (${state1} -> ${state2})`);
        testsPassed++;
      } else {
        console.error('❌ [5/7] toggleRecovery failed:', res.data);
      }
    }

    // Test 6: triggerManualRecovery
    {
      const { req, res } = mockReqRes();
      await triggerManualRecovery(req, res);
      if (res.statusCode === 200 && res.data.success && res.data.data) {
        console.log(`✅ [6/7] triggerManualRecovery passed: Updated ${res.data.data.updatedCount} driver(s) (ceiling: ${res.data.data.ceiling} pts)`);
        testsPassed++;
      } else {
        console.error('❌ [6/7] triggerManualRecovery failed:', res.data);
      }
    }

    // Test 7: resetDemeritConfig
    {
      const { req, res } = mockReqRes();
      await resetDemeritConfig(req, res);
      if (res.statusCode === 200 && res.data.success && res.data.data.defaultDemeritPoints === 24 && res.data.data.monthlyRecoveryPoints === 2) {
        console.log(`✅ [7/7] resetDemeritConfig passed: Reset to 24 default points and 2 recovery points`);
        testsPassed++;
      } else {
        console.error('❌ [7/7] resetDemeritConfig failed:', res.data);
      }
    }

    console.log('\n======================================================');
    console.log(`📊 TEST RESULTS: ${testsPassed} Passed, ${7 - testsPassed} Failed (${Math.round((testsPassed / 7) * 100)}%)`);
    console.log('======================================================\n');

    await mongoose.disconnect();
    process.exit(testsPassed === 7 ? 0 : 1);

  } catch (error) {
    console.error('Test execution error:', error);
    process.exit(1);
  }
}

runTests();
