const express = require('express');
const router = express.Router();
const { protectAdmin, requireRole } = require('../middleware/adminMiddleware');
const PreApprovedOfficer = require('../models/preApprovedOfficerModel');
const { getOffenses, addOffense } = require('../controllers/fineController');
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
    deleteDriver,
    getAllIssuedFines,
    deleteFine,
    updateOffense,
    deleteOffense,
    generateMonthlyReport,
    generatePaymentReport,
    generateDriverViolationReport,
    generateVehicleReport,
    generateOfficerReport,
    verifyDriverForReport,
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
    getAllOfficers,
    getOfficerMetrics,
    getOfficerById,
    createOfficer,
    updateOfficer,
    toggleOfficerStatus,
    transferOfficerStation,
    resetOfficerCredentials,
    exportOfficers,
    deleteOfficer
} = require('../controllers/adminOfficerController');
const {
    getAllPayments,
    getPaymentMetrics,
    getPaymentById,
    verifyPaymentGateway,
    processPaymentRefund,
    flagPaymentDispute,
    exportPayments
} = require('../controllers/adminPaymentController');
const {
    getSystemConfig,
    updateSystemConfig,
    toggleRecovery,
    resetDemeritConfig
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
      { badgeNumber: '10001', notes: 'Constable - Colombo Fort' },
      { badgeNumber: '10002', notes: 'Sergeant - Maradana' },
      { badgeNumber: '10003', notes: 'Sub-Inspector - Kandy' },
      { badgeNumber: '10004', notes: 'Inspector - Galle' },
      { badgeNumber: '10005', notes: 'OIC - Kurunegala' },
    ];

    // insertMany with ordered:false so duplicates are skipped gracefully
    const result = await PreApprovedOfficer.insertMany(mockBadges, {
      ordered: false,
    });

    return res.status(201).json({
      success: true,
      message: `${result.length} badge(s) seeded successfully.`,
      inserted: result.map((r) => r.badgeNumber),
    });
  } catch (error) {
    // If some badges already exist (code 11000 bulk write), report what was inserted
    if (error.code === 11000 || error.writeErrors) {
      const inserted = (error.insertedDocs || []).map((d) => d.badgeNumber);
      return res.status(200).json({
        success: true,
        message: 'Seeding complete. Some badges already existed and were skipped.',
        inserted,
      });
    }
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

// Police Officer Workforce Management Suite
router.get('/officers/metrics', protectAdmin, getOfficerMetrics);
router.get('/officers/export', protectAdmin, exportOfficers);
router.get('/officers/:id', protectAdmin, getOfficerById);
router.post('/officers', protectAdmin, requireRole('admin_officer', 'super_admin'), createOfficer);
router.put('/officers/:id', protectAdmin, requireRole('admin_officer', 'super_admin'), updateOfficer);
router.patch('/officers/:id/status', protectAdmin, requireRole('admin_officer', 'super_admin'), toggleOfficerStatus);
router.post('/officers/:id/transfer', protectAdmin, requireRole('admin_officer', 'super_admin'), transferOfficerStation);
router.post('/officers/:id/reset-credentials', protectAdmin, requireRole('super_admin'), resetOfficerCredentials);
router.delete('/officers/:id', protectAdmin, requireRole('super_admin', 'admin_officer'), deleteOfficer);
router.get('/officers', protectAdmin, getAllOfficers);

// Fines - View only
router.get('/fines', protectAdmin, getAllIssuedFines);

// Payments & Financial Reconciliation - Enhanced Suite
router.get('/payments/metrics', protectAdmin, getPaymentMetrics);
router.get('/payments/export', protectAdmin, exportPayments);
router.get('/payments/:id', protectAdmin, getPaymentById);
router.post('/payments/:id/verify-gateway', protectAdmin, requireRole('super_admin', 'finance_officer', 'admin_officer'), verifyPaymentGateway);
router.post('/payments/dispute', protectAdmin, requireRole('super_admin', 'finance_officer', 'admin_officer'), flagPaymentDispute);
router.post('/payments/refund', protectAdmin, requireRole('super_admin'), processPaymentRefund);
router.get('/payments', protectAdmin, getAllPayments);

// Reports - All admins can generate reports
router.post('/reports/verify-driver', protectAdmin, verifyDriverForReport);
router.post('/reports/monthly-fines', protectAdmin, generateMonthlyReport);
router.post('/reports/payments', protectAdmin, generatePaymentReport);
router.post('/reports/driver-violations', protectAdmin, generateDriverViolationReport);
router.post('/reports/vehicle-violations', protectAdmin, generateVehicleReport);
router.post('/reports/officer-performance', protectAdmin, generateOfficerReport);

// ==========================================
// ADMIN OFFICER & SUPER ADMIN ONLY
// ==========================================

// Driver management
router.put('/drivers/:id/suspend', protectAdmin, requireRole('admin_officer', 'super_admin'), suspendDriver);
router.put('/drivers/:id/activate', protectAdmin, requireRole('admin_officer', 'super_admin'), activateDriver);
router.delete('/drivers/:id', protectAdmin, requireRole('admin_officer', 'super_admin'), deleteDriver);

// Offense management
router.get('/fines/offenses', protectAdmin, getOffenses);
router.post('/fines/offenses', protectAdmin, requireRole('admin_officer', 'super_admin'), addOffense);
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
router.delete('/fines/offenses/:id', protectAdmin, requireRole('super_admin'), deleteOffense);
router.delete('/fines/:id', protectAdmin, requireRole('super_admin'), deleteFine);

// Station management
router.post('/stations', protectAdmin, requireRole('super_admin'), createStation);
router.put('/stations/:id', protectAdmin, requireRole('super_admin'), updateStation);
router.delete('/stations/:id', protectAdmin, requireRole('super_admin'), deleteStation);

// System Config (Master Data)
router.get('/system-config', protectAdmin, requireRole('super_admin', 'admin_officer'), getSystemConfig);
router.put('/system-config', protectAdmin, requireRole('super_admin'), updateSystemConfig);

// Demerit Config — toggle recovery on/off (super_admin only)
router.patch('/system-config/recovery-toggle', protectAdmin, requireRole('super_admin'), toggleRecovery);

// Demerit Config — reset to factory defaults (super_admin only)
router.delete('/system-config/demerit', protectAdmin, requireRole('super_admin'), resetDemeritConfig);

// Admin management
router.get('/all', protectAdmin, requireRole('super_admin'), getAllAdmins);
router.put('/:id', protectAdmin, requireRole('super_admin'), updateAdmin);
router.delete('/:id', protectAdmin, requireRole('super_admin'), deleteAdmin);

module.exports = router;
