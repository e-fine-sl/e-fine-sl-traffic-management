const express = require('express');
const router = express.Router();
const { protectAdmin, requireRole } = require('../middleware/adminMiddleware');
const PreApprovedOfficer = require('../models/preApprovedOfficerModel');
const {
    createStation,
    updateStation,
    deleteStation
} = require('../controllers/stationController');
const {
    adminLogin,
    adminLogout,
    adminRefreshToken,
    getDashboardStats,
    getAllDrivers,
    getDriverDetails,
    suspendDriver,
    activateDriver,
    getAllOfficers,
    createOfficer,
    updateOfficer,
    deleteOfficer,
    getAllIssuedFines,
    updateOffense,
    deleteOffense,
    getAllPayments,
    generateMonthlyReport,
    generatePaymentReport,
    generateDriverViolationReport,
    // 2FA Imports
    generateTwoFactor,
    enableTwoFactor,
    disableTwoFactor,
    initAdminRegistration,
    completeAdminRegistration,
    getAllAdmins,
    updateAdmin,
    deleteAdmin
} = require('../controllers/adminController');
const {
    getSystemConfig,
    updateSystemConfig
} = require('../controllers/systemConfigController');

// ==========================================
// PUBLIC ROUTES
// ==========================================

// Admin login, logout & token refresh (no auth required)
router.post('/login', adminLogin);
router.post('/logout', adminLogout);
router.post('/refresh', adminRefreshToken);

// ─────────────────────────────────────────────────────────────────────────────
// [DEV/SETUP ONLY] Seed pre-approved badge numbers into the database.
// Call once: POST /api/admin/seed-badges
// IMPORTANT: Disable or remove this route before deploying to production!
// ─────────────────────────────────────────────────────────────────────────────
router.post('/seed-badges', async (req, res) => {
  try {
    const mockBadges = [
      // 3 for COL-01 (Colombo Fort - krasanjana81@gmail.com)
      { badgeNumber: '19001', stationCode: 'COL-01', isRegistered: false, registeredAt: null, notes: 'Auto-generated - Colombo Fort (krasanjana81)' },
      { badgeNumber: '19002', stationCode: 'COL-01', isRegistered: false, registeredAt: null, notes: 'Auto-generated - Colombo Fort (krasanjana81)' },
      { badgeNumber: '19003', stationCode: 'COL-01', isRegistered: false, registeredAt: null, notes: 'Auto-generated - Colombo Fort (krasanjana81)' },
      
      // 3 for COL-03 (Cinnamon Gardens - krasanjana83@gmail.com)
      { badgeNumber: '19004', stationCode: 'COL-03', isRegistered: false, registeredAt: null, notes: 'Auto-generated - Cinnamon Gardens (krasanjana83)' },
      { badgeNumber: '19005', stationCode: 'COL-03', isRegistered: false, registeredAt: null, notes: 'Auto-generated - Cinnamon Gardens (krasanjana83)' },
      { badgeNumber: '19006', stationCode: 'COL-03', isRegistered: false, registeredAt: null, notes: 'Auto-generated - Cinnamon Gardens (krasanjana83)' },

      // 4 for COL-02 (Maradana - kavishkarasanjana217@gmail.com)
      { badgeNumber: '19007', stationCode: 'COL-02', isRegistered: false, registeredAt: null, notes: 'Auto-generated - Maradana (kavishkarasanjana217)' },
      { badgeNumber: '19008', stationCode: 'COL-02', isRegistered: false, registeredAt: null, notes: 'Auto-generated - Maradana (kavishkarasanjana217)' },
      { badgeNumber: '19009', stationCode: 'COL-02', isRegistered: false, registeredAt: null, notes: 'Auto-generated - Maradana (kavishkarasanjana217)' },
      { badgeNumber: '19010', stationCode: 'COL-02', isRegistered: false, registeredAt: null, notes: 'Auto-generated - Maradana (kavishkarasanjana217)' }
    ];

    // Delete any old ones from this seed block to avoid duplicates during testing
    await PreApprovedOfficer.deleteMany({ badgeNumber: { $regex: /^190/ } });

    // We must pass strict:false on the model if stationCode isn't in schema
    // But since it's already defined via insertMany, it should work depending on mongoose version
    const result = await PreApprovedOfficer.collection.insertMany(mockBadges, { ordered: false });

    return res.status(201).json({
      success: true,
      message: `${result.insertedCount} badge(s) seeded successfully with real stations.`,
      inserted: mockBadges.map((r) => r.badgeNumber),
    });
  } catch (error) {
    console.error('[SEED-BADGES] Error:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
});

// ==========================================
// PROTECTED ROUTES - All Admin Roles
// ==========================================

// Dashboard
router.get('/dashboard/stats', protectAdmin, getDashboardStats);

// Drivers - View only
router.get('/drivers', protectAdmin, getAllDrivers);
router.get('/drivers/:id', protectAdmin, getDriverDetails);

// Officers - View only
router.get('/officers', protectAdmin, getAllOfficers);

// Fines - View only
router.get('/fines', protectAdmin, getAllIssuedFines);

// Payments - View only
router.get('/payments', protectAdmin, getAllPayments);

// Reports - All admins can generate reports
router.post('/reports/monthly-fines', protectAdmin, generateMonthlyReport);
router.post('/reports/payments', protectAdmin, generatePaymentReport);
router.post('/reports/driver-violations', protectAdmin, generateDriverViolationReport);

// ==========================================
// ADMIN OFFICER & SUPER ADMIN ONLY
// ==========================================

// Driver management
router.put('/drivers/:id/suspend', protectAdmin, requireRole('admin_officer', 'super_admin'), suspendDriver);
router.put('/drivers/:id/activate', protectAdmin, requireRole('admin_officer', 'super_admin'), activateDriver);

// Officer management
router.post('/officers', protectAdmin, requireRole('admin_officer', 'super_admin'), createOfficer);
router.put('/officers/:id', protectAdmin, requireRole('admin_officer', 'super_admin'), updateOfficer);

// Offense management
router.put('/fines/offenses/:id', protectAdmin, requireRole('admin_officer', 'super_admin'), updateOffense);

// ==========================================
// 2FA MANAGEMENT - All Admin Roles
// ==========================================

router.post('/2fa/generate', protectAdmin, generateTwoFactor);
router.post('/2fa/enable', protectAdmin, enableTwoFactor);
router.post('/2fa/disable', protectAdmin, disableTwoFactor);

// ==========================================
// SUPER ADMIN ONLY
// ==========================================

// Secure Admin Registration (Enforced 2FA)
router.post('/register/init', protectAdmin, requireRole('super_admin'), initAdminRegistration);
router.post('/register/complete', protectAdmin, requireRole('super_admin'), completeAdminRegistration);

// Delete operations
router.delete('/officers/:id', protectAdmin, requireRole('super_admin'), deleteOfficer);
router.delete('/fines/offenses/:id', protectAdmin, requireRole('super_admin'), deleteOffense);

// Station management
router.post('/stations', protectAdmin, requireRole('super_admin'), createStation);
router.put('/stations/:id', protectAdmin, requireRole('super_admin'), updateStation);
router.delete('/stations/:id', protectAdmin, requireRole('super_admin'), deleteStation);

// System Config (Master Data)
router.get('/system-config', protectAdmin, requireRole('super_admin', 'admin_officer'), getSystemConfig);
router.put('/system-config', protectAdmin, requireRole('super_admin'), updateSystemConfig);

// Admin management
router.get('/all', protectAdmin, requireRole('super_admin'), getAllAdmins);
router.put('/:id', protectAdmin, requireRole('super_admin'), updateAdmin);
router.delete('/:id', protectAdmin, requireRole('super_admin'), deleteAdmin);

module.exports = router;
