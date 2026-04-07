const express = require('express');
const router = express.Router();
const { protectAdmin, requireRole } = require('../middleware/adminMiddleware');
const {
    adminLogin,
    adminLogout,
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
    completeAdminRegistration
} = require('../controllers/adminController');

// ==========================================
// PUBLIC ROUTES
// ==========================================

// Admin login & logout (no auth required for initial hit or session revocation)
router.post('/login', adminLogin);
router.post('/logout', adminLogout);

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

module.exports = router;
