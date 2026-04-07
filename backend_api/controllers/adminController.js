const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const speakeasy = require('speakeasy');
const qrcode = require('qrcode');
const crypto = require('crypto');
const Admin = require('../models/adminModel');
const AdminSession = require('../models/adminSessionModel');
const AdminTokenConfig = require('../models/adminTokenConfigModel');
const Driver = require('../models/driverModel');
const Police = require('../models/policeModel');
const IssuedFine = require('../models/issuedFineModel');
const Offense = require('../models/offenseModel');
const { sendLicenseStatusEmail } = require('../services/emailService');
const { HTTP, ROLES, PAYMENT, AUTH, PAGINATION } = require('../config/constants');

// Helper: Get or create Admin token configuration from DB
const getAdminTokenConfig = async () => {
    let config = await AdminTokenConfig.findOne();
    if (!config) {
        // Auto-create defaults on first run
        config = await AdminTokenConfig.create({
            access_token_expiry_minutes: 15,
            refresh_token_expiry_hours: 1,
            session_token_expiry_days: 7
        });
        console.log('[ADMIN] Created default admin_token_configs document in DB');
    }
    return config;
};

// Generate JWT Token
const generateToken = (id) => {
    return jwt.sign({ id }, process.env.JWT_SECRET, {
        expiresIn: AUTH.JWT_EXPIRY
    });
};

// @desc    Admin login
// @route   POST /api/admin/login
// @access  Public
const adminLogin = async (req, res) => {
    try {
        const { email, password, totpToken } = req.body;

        // Validate input
        if (!email || !password) {
            return res.status(HTTP.BAD_REQUEST).json({ message: 'Please provide email and password' });
        }

        // Find admin by email
        const admin = await Admin.findOne({ email });

        if (!admin) {
            return res.status(HTTP.UNAUTHORIZED).json({ message: 'Invalid credentials' });
        }

        // Check if account is active
        if (!admin.isActive) {
            return res.status(HTTP.FORBIDDEN).json({ message: 'Account is deactivated' });
        }

        // Check password
        const isPasswordMatch = await bcrypt.compare(password, admin.password);

        if (!isPasswordMatch) {
            return res.status(HTTP.UNAUTHORIZED).json({ message: 'Invalid credentials' });
        }

        // 2FA Verification Logic
        if (admin.isTwoFactorEnabled) {
            // If 2FA is enabled but not verified (setup incomplete), force them to complete setup?
            // Or if verified, require token.

            if (!totpToken) {
                return res.status(HTTP.FORBIDDEN).json({
                    requireTwoFactor: true,
                    message: 'Two-factor authentication required'
                });
            }

            // Verify TOTP
            const verified = speakeasy.totp.verify({
                secret: admin.twoFactorSecret,
                encoding: 'base32',
                token: totpToken
            });

            if (!verified) {
                return res.status(HTTP.UNAUTHORIZED).json({ message: 'Invalid 2FA code' });
            }
        }

        // Update last login
        admin.lastLogin = new Date();
        await admin.save();

        // ── Read token expiry config from DB ─────────────────────────────────
        const tokenConfig = await getAdminTokenConfig();
        const accessExpiryMins    = tokenConfig.access_token_expiry_minutes;  // e.g. 15
        const refreshExpiryHours  = tokenConfig.refresh_token_expiry_hours;   // e.g. 1
        const sessionExpiryDays   = tokenConfig.session_token_expiry_days;    // e.g. 7

        // ── Generate Tokens ──────────────────────────────────────────────────
        const accessToken = jwt.sign(
            { id: admin._id, role: admin.role },
            process.env.JWT_SECRET,
            { expiresIn: `${accessExpiryMins}m` }
        );

        const refreshToken = jwt.sign(
            { id: admin._id, role: admin.role },
            process.env.JWT_SECRET,
            { expiresIn: `${refreshExpiryHours}h` }
        );

        const sessionToken = crypto.randomUUID();
        const refreshTokenHash = crypto.createHash('sha256').update(refreshToken).digest('hex');

        // ── Calculate exact expiry Dates ─────────────────────────────────────
        const now = new Date();

        const refreshTokenExpiresAt = new Date(now);
        refreshTokenExpiresAt.setHours(refreshTokenExpiresAt.getHours() + refreshExpiryHours);

        const sessionExpiresAt = new Date(now);
        sessionExpiresAt.setDate(sessionExpiresAt.getDate() + sessionExpiryDays);

        // ── Persist session to admin_auth_sessions ───────────────────────────
        await AdminSession.create({
            userId:                admin._id,
            userRole:              admin.role,
            sessionToken:          sessionToken,
            refreshTokenHash:      refreshTokenHash,
            deviceInfo:            req.headers['user-agent'] || 'Unknown Device',
            expiresAt:             sessionExpiresAt,          // Session expiry (7 days)
            refreshTokenExpiresAt: refreshTokenExpiresAt,     // Refresh token expiry (1 hr)
        });

        res.json({
            success: true,
            token: accessToken, // Retained for backward compatibility with admin portal
            accessToken,
            refreshToken,
            sessionToken,
            user: {
                id: admin._id,
                name: admin.name,
                email: admin.email,
                role: admin.role,
                phone: admin.phone,
                profileImage: admin.profileImage,
                isTwoFactorEnabled: admin.isTwoFactorEnabled
            }
        });

    } catch (error) {
        console.error('Admin login error:', error);
        res.status(HTTP.SERVER_ERROR).json({ message: 'Server error', error: error.message });
    }
};

// @desc    Admin logout
// @route   POST /api/admin/logout
// @access  Public
const adminLogout = async (req, res) => {
    try {
        const { sessionToken } = req.body;
        if (!sessionToken) {
            return res.status(HTTP.BAD_REQUEST).json({ message: 'Session token is required' });
        }
        
        const session = await AdminSession.findOneAndUpdate(
            { sessionToken },
            { isRevoked: true }
        );

        res.json({ success: true, message: 'Logged out successfully' });
    } catch (error) {
        console.error('Admin logout error:', error);
        res.status(HTTP.SERVER_ERROR).json({ message: 'Server error', error: error.message });
    }
};

// @desc    Generate 2FA Secret and QR Code
// @route   POST /api/admin/2fa/generate
// @access  Private (Admin)
const generateTwoFactor = async (req, res) => {
    try {
        const secret = speakeasy.generateSecret({
            name: `e-Fine Admin (${req.user.email})`
        });

        const qrCodeUrl = await qrcode.toDataURL(secret.otpauth_url);

        res.json({
            success: true,
            secret: secret.base32,
            qrCodeUrl
        });

    } catch (error) {
        console.error('Generate 2FA error:', error);
        res.status(HTTP.SERVER_ERROR).json({ message: 'Server error', error: error.message });
    }
};

// @desc    Verify and Enable 2FA
// @route   POST /api/admin/2fa/enable
// @access  Private (Admin)
const enableTwoFactor = async (req, res) => {
    try {
        const { token, secret } = req.body;
        const userId = req.user.id; // Or from body if registering new admin

        const verified = speakeasy.totp.verify({
            secret: secret,
            encoding: 'base32',
            token: token
        });

        if (!verified) {
            return res.status(HTTP.BAD_REQUEST).json({ message: 'Invalid verification code' });
        }

        await Admin.findByIdAndUpdate(userId, {
            twoFactorSecret: secret,
            isTwoFactorEnabled: true,
            isTwoFactorVerified: true
        });

        res.json({
            success: true,
            message: 'Two-factor authentication enabled successfully'
        });

    } catch (error) {
        console.error('Enable 2FA error:', error);
        res.status(HTTP.SERVER_ERROR).json({ message: 'Server error', error: error.message });
    }
};

// @desc    Disable 2FA
// @route   POST /api/admin/2fa/disable
// @access  Private (Admin)
const disableTwoFactor = async (req, res) => {
    try {
        const { password } = req.body;
        const admin = await Admin.findById(req.user.id);

        if (!admin) {
            return res.status(HTTP.NOT_FOUND).json({ message: 'User not found' });
        }

        const isPasswordMatch = await bcrypt.compare(password, admin.password);

        if (!isPasswordMatch) {
            return res.status(HTTP.UNAUTHORIZED).json({ message: 'Invalid password' });
        }

        admin.twoFactorSecret = undefined;
        admin.isTwoFactorEnabled = false;
        admin.isTwoFactorVerified = false;
        await admin.save();

        res.json({
            success: true,
            message: 'Two-factor authentication disabled'
        });

    } catch (error) {
        console.error('Disable 2FA error:', error);
        res.status(HTTP.SERVER_ERROR).json({ message: 'Server error', error: error.message });
    }
};

// @desc    Register New Admin (Step 1: Validate & Generate 2FA)
// @route   POST /api/admin/register/init
// @access  Private (Super Admin)
const initAdminRegistration = async (req, res) => {
    try {
        const { name, email, password, role } = req.body;

        // Validation
        if (!name || !email || !password || !role) {
            return res.status(HTTP.BAD_REQUEST).json({ message: 'Please provide all fields' });
        }

        const existingAdmin = await Admin.findOne({ email });
        if (existingAdmin) {
            return res.status(HTTP.BAD_REQUEST).json({ message: 'Email already exists' });
        }

        // Generate 2FA secret
        const secret = speakeasy.generateSecret({
            name: `e-Fine Admin (${email})`
        });
        const qrCodeUrl = await qrcode.toDataURL(secret.otpauth_url);

        // Return secret to frontend (DO NOT SAVE USER YET)
        // Pass temp data back to client to resend with verification
        res.json({
            success: true,
            tempSecret: secret.base32,
            qrCodeUrl,
            message: 'Scan QR code to verify and complete registration'
        });

    } catch (error) {
        console.error('Init admin reg error:', error);
        res.status(HTTP.SERVER_ERROR).json({ message: 'Server error', error: error.message });
    }
};

// @desc    Complete Admin Registration (Step 2: Verify & Save)
// @route   POST /api/admin/register/complete
// @access  Private (Super Admin)
const completeAdminRegistration = async (req, res) => {
    try {
        const { name, email, password, role, secret, token } = req.body;

        // Verify TOTP
        const verified = speakeasy.totp.verify({
            secret: secret,
            encoding: 'base32',
            token: token
        });

        if (!verified) {
            return res.status(HTTP.BAD_REQUEST).json({ message: 'Invalid verification code. Registration failed.' });
        }

        // Hash password
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);

        // Create Admin
        const admin = await Admin.create({
            name,
            email,
            password: hashedPassword,
            role,
            twoFactorSecret: secret,
            isTwoFactorEnabled: true,
            isTwoFactorVerified: true,
            profileImage: 'https://cdn-icons-png.flaticon.com/512/3135/3135715.png'
        });

        res.status(HTTP.CREATED).json({
            success: true,
            message: 'Admin registered successfully with 2FA enabled',
            admin: {
                id: admin._id,
                name: admin.name,
                email: admin.email,
                role: admin.role
            }
        });

    } catch (error) {
        console.error('Complete admin reg error:', error);
        res.status(HTTP.SERVER_ERROR).json({ message: 'Server error', error: error.message });
    }
};

// @desc    Get dashboard statistics
// @route   GET /api/admin/dashboard/stats
// @access  Private (Admin)
const getDashboardStats = async (req, res) => {
    try {
        // Total fines issued
        const totalFines = await IssuedFine.countDocuments();

        // Total fines this month
        const startOfMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
        const finesThisMonth = await IssuedFine.countDocuments({
            date: { $gte: startOfMonth }
        });

        // Total revenue (sum of all paid fines)
        const revenueResult = await IssuedFine.aggregate([
            { $match: { status: PAYMENT.STATUS.PAID } },
            { $group: { _id: null, total: { $sum: '$amount' } } }
        ]);
        const totalRevenue = revenueResult.length > 0 ? revenueResult[0].total : 0;

        // Pending payments
        const pendingPayments = await IssuedFine.countDocuments({ status: PAYMENT.STATUS.UNPAID });

        // Completed payments
        const completedPayments = await IssuedFine.countDocuments({ status: PAYMENT.STATUS.PAID });

        // Total drivers
        const totalDrivers = await Driver.countDocuments();

        // Active drivers
        const activeDrivers = await Driver.countDocuments({ licenseStatus: 'ACTIVE' });

        // Suspended drivers
        const suspendedDrivers = await Driver.countDocuments({ licenseStatus: 'SUSPENDED' });

        // Total police officers
        const totalOfficers = await Police.countDocuments();

        // Total offense types
        const totalOffenseTypes = await Offense.countDocuments();

        // Recent fines (last 5)
        const recentFines = await IssuedFine.find()
            .sort({ date: -1 })
            .limit(5)
            .populate('offenseId', 'offenseName');

        // Recent payments (last 5)
        const recentPayments = await IssuedFine.find({ status: PAYMENT.STATUS.PAID })
            .sort({ paidAt: -1 })
            .limit(5);

        res.json({
            success: true,
            stats: {
                totalFines,
                finesThisMonth,
                totalRevenue,
                pendingPayments,
                completedPayments,
                totalDrivers,
                activeDrivers,
                suspendedDrivers,
                totalOfficers,
                totalOffenseTypes
            },
            recentActivity: {
                recentFines,
                recentPayments
            }
        });

    } catch (error) {
        console.error('Dashboard stats error:', error);
        res.status(HTTP.SERVER_ERROR).json({ message: 'Server error', error: error.message });
    }
};

// @desc    Get all drivers with pagination and search
// @route   GET /api/admin/drivers?page=1&limit=20&search=keyword
// @access  Private (Admin)
const getAllDrivers = async (req, res) => {
    try {
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 20;
        const search = req.query.search || '';
        const skip = (page - 1) * limit;

        // Build search query
        let query = {};
        if (search) {
            query = {
                $or: [
                    { name: { $regex: search, $options: 'i' } },
                    { nic: { $regex: search, $options: 'i' } },
                    { licenseNumber: { $regex: search, $options: 'i' } },
                    { email: { $regex: search, $options: 'i' } }
                ]
            };
        }

        // Filter by license status if provided
        if (req.query.status) {
            query.licenseStatus = req.query.status;
        }

        // Get drivers with pagination
        const drivers = await Driver.find(query)
            .select('-password')
            .sort({ createdAt: -1 })
            .skip(skip)
            .limit(limit);

        // Get total count
        const total = await Driver.countDocuments(query);

        res.json({
            success: true,
            count: drivers.length,
            total,
            page,
            pages: Math.ceil(total / limit),
            data: drivers
        });

    } catch (error) {
        console.error('Get drivers error:', error);
        res.status(HTTP.SERVER_ERROR).json({ message: 'Server error', error: error.message });
    }
};

// @desc    Get driver details with violation history
// @route   GET /api/admin/drivers/:id
// @access  Private (Admin)
const getDriverDetails = async (req, res) => {
    try {
        const driver = await Driver.findById(req.params.id).select('-password');

        if (!driver) {
            return res.status(HTTP.NOT_FOUND).json({ message: 'Driver not found' });
        }

        // Get driver's violation history
        const violations = await IssuedFine.find({ licenseNumber: driver.licenseNumber })
            .sort({ date: -1 })
            .populate('offenseId', 'offenseName sectionOfAct');

        res.json({
            success: true,
            driver,
            violations
        });

    } catch (error) {
        console.error('Get driver details error:', error);
        res.status(HTTP.SERVER_ERROR).json({ message: 'Server error', error: error.message });
    }
};

// @desc    Suspend driver license
// @route   PUT /api/admin/drivers/:id/suspend
// @access  Private (Admin Officer, Super Admin)
const suspendDriver = async (req, res) => {
    try {
        const driver = await Driver.findById(req.params.id);

        if (!driver) {
            return res.status(HTTP.NOT_FOUND).json({ message: 'Driver not found' });
        }

        if (driver.licenseStatus === 'SUSPENDED') {
            return res.status(HTTP.BAD_REQUEST).json({ message: 'License is already suspended' });
        }

        // Update license status
        driver.licenseStatus = 'SUSPENDED';
        driver.demeritLevel = 'SUSPENDED';
        driver.suspendedAt = new Date();
        await driver.save();

        // Send email notification
        try {
            await sendLicenseStatusEmail(driver, 'SUSPENDED');
        } catch (emailError) {
            console.error('Email send error:', emailError);
        }

        res.json({
            success: true,
            message: 'Driver license suspended successfully',
            driver: {
                id: driver._id,
                name: driver.name,
                licenseNumber: driver.licenseNumber,
                licenseStatus: driver.licenseStatus
            }
        });

    } catch (error) {
        console.error('Suspend driver error:', error);
        res.status(HTTP.SERVER_ERROR).json({ message: 'Server error', error: error.message });
    }
};

// @desc    Activate driver license
// @route   PUT /api/admin/drivers/:id/activate
// @access  Private (Admin Officer, Super Admin)
const activateDriver = async (req, res) => {
    try {
        const driver = await Driver.findById(req.params.id);

        if (!driver) {
            return res.status(HTTP.NOT_FOUND).json({ message: 'Driver not found' });
        }

        if (driver.licenseStatus === 'ACTIVE') {
            return res.status(HTTP.BAD_REQUEST).json({ message: 'License is already active' });
        }

        // Update license status
        driver.licenseStatus = 'ACTIVE';
        driver.demeritPoints = 50;
        driver.demeritLevel = 'WARNING';
        driver.suspendedAt = null;
        await driver.save();

        // Send email notification
        try {
            await sendLicenseStatusEmail(driver, 'ACTIVE');
        } catch (emailError) {
            console.error('Email send error:', emailError);
        }

        res.json({
            success: true,
            message: 'Driver license activated successfully',
            driver: {
                id: driver._id,
                name: driver.name,
                licenseNumber: driver.licenseNumber,
                licenseStatus: driver.licenseStatus
            }
        });

    } catch (error) {
        console.error('Activate driver error:', error);
        res.status(HTTP.SERVER_ERROR).json({ message: 'Server error', error: error.message });
    }
};

// @desc    Get all police officers
// @route   GET /api/admin/officers?page=1&limit=20
// @access  Private (Admin)
const getAllOfficers = async (req, res) => {
    try {
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 20;
        const search = req.query.search || '';
        const skip = (page - 1) * limit;

        // Build search query
        let query = {};
        if (search) {
            query = {
                $or: [
                    { name: { $regex: search, $options: 'i' } },
                    { badgeNumber: { $regex: search, $options: 'i' } },
                    { email: { $regex: search, $options: 'i' } },
                    { policeStation: { $regex: search, $options: 'i' } }
                ]
            };
        }

        // Get officers with pagination
        const officers = await Police.find(query)
            .select('-password')
            .sort({ createdAt: -1 })
            .skip(skip)
            .limit(limit);

        // Get total count
        const total = await Police.countDocuments(query);

        res.json({
            success: true,
            count: officers.length,
            total,
            page,
            pages: Math.ceil(total / limit),
            data: officers
        });

    } catch (error) {
        console.error('Get officers error:', error);
        res.status(HTTP.SERVER_ERROR).json({ message: 'Server error', error: error.message });
    }
};

// @desc    Create new police officer
// @route   POST /api/admin/officers
// @access  Private (Admin Officer, Super Admin)
const createOfficer = async (req, res) => {
    try {
        const { name, email, badgeNumber, password, policeStation, position, profileImage } = req.body;

        // Validate required fields
        if (!name || !email || !badgeNumber || !password || !policeStation || !position) {
            return res.status(HTTP.BAD_REQUEST).json({ message: 'Please provide all required fields' });
        }

        // Check if badge number already exists
        const existingOfficer = await Police.findOne({ badgeNumber });
        if (existingOfficer) {
            return res.status(HTTP.BAD_REQUEST).json({ message: 'Badge number already exists' });
        }

        // Check if email already exists
        const existingEmail = await Police.findOne({ email });
        if (existingEmail) {
            return res.status(HTTP.BAD_REQUEST).json({ message: 'Email already exists' });
        }

        // Hash password
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);

        // Create officer
        const officer = await Police.create({
            name,
            email,
            badgeNumber,
            password: hashedPassword,
            policeStation,
            position,
            profileImage: profileImage || 'https://cdn-icons-png.flaticon.com/512/206/206853.png'
        });

        res.status(HTTP.CREATED).json({
            success: true,
            message: 'Police officer created successfully',
            officer: {
                id: officer._id,
                name: officer.name,
                email: officer.email,
                badgeNumber: officer.badgeNumber,
                policeStation: officer.policeStation,
                position: officer.position,
                profileImage: officer.profileImage
            }
        });

    } catch (error) {
        console.error('Create officer error:', error);
        res.status(HTTP.SERVER_ERROR).json({ message: 'Server error', error: error.message });
    }
};

// @desc    Update police officer
// @route   PUT /api/admin/officers/:id
// @access  Private (Admin Officer, Super Admin)
const updateOfficer = async (req, res) => {
    try {
        const officer = await Police.findById(req.params.id);

        if (!officer) {
            return res.status(HTTP.NOT_FOUND).json({ message: 'Officer not found' });
        }

        const { name, email, policeStation, position, profileImage } = req.body;

        // Update fields
        if (name) officer.name = name;
        if (email) officer.email = email;
        if (policeStation) officer.policeStation = policeStation;
        if (position) officer.position = position;
        if (profileImage) officer.profileImage = profileImage;

        await officer.save();

        res.json({
            success: true,
            message: 'Officer updated successfully',
            officer: {
                id: officer._id,
                name: officer.name,
                email: officer.email,
                badgeNumber: officer.badgeNumber,
                policeStation: officer.policeStation,
                position: officer.position,
                profileImage: officer.profileImage
            }
        });

    } catch (error) {
        console.error('Update officer error:', error);
        res.status(HTTP.SERVER_ERROR).json({ message: 'Server error', error: error.message });
    }
};

// @desc    Delete police officer
// @route   DELETE /api/admin/officers/:id
// @access  Private (Super Admin only)
const deleteOfficer = async (req, res) => {
    try {
        const officer = await Police.findById(req.params.id);

        if (!officer) {
            return res.status(HTTP.NOT_FOUND).json({ message: 'Officer not found' });
        }

        await officer.deleteOne();

        res.json({
            success: true,
            message: 'Officer deleted successfully'
        });

    } catch (error) {
        console.error('Delete officer error:', error);
        res.status(HTTP.SERVER_ERROR).json({ message: 'Server error', error: error.message });
    }
};

// @desc    Get all issued fines with filters
// @route   GET /api/admin/fines?page=1&limit=20&status=Paid&startDate=&endDate=
// @access  Private (Admin)
const getAllIssuedFines = async (req, res) => {
    try {
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 20;
        const skip = (page - 1) * limit;

        // Build query
        let query = {};

        // Filter by status
        if (req.query.status) {
            query.status = req.query.status;
        }

        // Filter by date range
        if (req.query.startDate || req.query.endDate) {
            query.date = {};
            if (req.query.startDate) {
                query.date.$gte = new Date(req.query.startDate);
            }
            if (req.query.endDate) {
                query.date.$lte = new Date(req.query.endDate);
            }
        }

        // Search by license or vehicle number
        if (req.query.search) {
            query.$or = [
                { licenseNumber: { $regex: req.query.search, $options: 'i' } },
                { vehicleNumber: { $regex: req.query.search, $options: 'i' } }
            ];
        }

        // Get fines with pagination
        const fines = await IssuedFine.find(query)
            .populate('offenseId', 'offenseName sectionOfAct')
            .sort({ date: -1 })
            .skip(skip)
            .limit(limit);

        // Get total count
        const total = await IssuedFine.countDocuments(query);

        res.json({
            success: true,
            count: fines.length,
            total,
            page,
            pages: Math.ceil(total / limit),
            data: fines
        });

    } catch (error) {
        console.error('Get fines error:', error);
        res.status(HTTP.SERVER_ERROR).json({ message: 'Server error', error: error.message });
    }
};

// @desc    Update offense type
// @route   PUT /api/admin/fines/offenses/:id
// @access  Private (Admin Officer, Super Admin)
const updateOffense = async (req, res) => {
    try {
        const offense = await Offense.findById(req.params.id);

        if (!offense) {
            return res.status(HTTP.NOT_FOUND).json({ message: 'Offense not found' });
        }

        const { offenseName, amount, description, sectionOfAct } = req.body;

        // Update fields
        if (offenseName) offense.offenseName = offenseName;
        if (amount) offense.amount = amount;
        if (description !== undefined) offense.description = description;
        if (sectionOfAct !== undefined) offense.sectionOfAct = sectionOfAct;

        await offense.save();

        res.json({
            success: true,
            message: 'Offense updated successfully',
            offense
        });

    } catch (error) {
        console.error('Update offense error:', error);
        res.status(HTTP.SERVER_ERROR).json({ message: 'Server error', error: error.message });
    }
};

// @desc    Delete offense type
// @route   DELETE /api/admin/fines/offenses/:id
// @access  Private (Super Admin only)
const deleteOffense = async (req, res) => {
    try {
        const offense = await Offense.findById(req.params.id);

        if (!offense) {
            return res.status(HTTP.NOT_FOUND).json({ message: 'Offense not found' });
        }

        // Check if offense is referenced in any issued fines
        const issuedFine = await IssuedFine.findOne({ offenseId: req.params.id });
        if (issuedFine) {
            return res.status(HTTP.BAD_REQUEST).json({
                message: 'Cannot delete offense - it is referenced in issued fines'
            });
        }

        await offense.deleteOne();

        res.json({
            success: true,
            message: 'Offense deleted successfully'
        });

    } catch (error) {
        console.error('Delete offense error:', error);
        res.status(HTTP.SERVER_ERROR).json({ message: 'Server error', error: error.message });
    }
};

// @desc    Get all payments with filters
// @route   GET /api/admin/payments?page=1&limit=20&status=Paid&startDate=&endDate=
// @access  Private (Admin)
const getAllPayments = async (req, res) => {
    try {
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 20;
        const skip = (page - 1) * limit;

        // Build query for paid fines only
        let query = { status: PAYMENT.STATUS.PAID };

        // Filter by date range
        if (req.query.startDate || req.query.endDate) {
            query.paidAt = {};
            if (req.query.startDate) {
                query.paidAt.$gte = new Date(req.query.startDate);
            }
            if (req.query.endDate) {
                query.paidAt.$lte = new Date(req.query.endDate);
            }
        }

        // Get payments with pagination
        const payments = await IssuedFine.find(query)
            .populate('offenseId', 'offenseName')
            .sort({ paidAt: -1 })
            .skip(skip)
            .limit(limit);

        // Get total count
        const total = await IssuedFine.countDocuments(query);

        res.json({
            success: true,
            count: payments.length,
            total,
            page,
            pages: Math.ceil(total / limit),
            data: payments
        });

    } catch (error) {
        console.error('Get payments error:', error);
        res.status(HTTP.SERVER_ERROR).json({ message: 'Server error', error: error.message });
    }
};

// @desc    Generate monthly fine report
// @route   POST /api/admin/reports/monthly-fines
// @access  Private (Admin)
const generateMonthlyReport = async (req, res) => {
    try {
        const { month, year } = req.body;

        if (!month || !year) {
            return res.status(HTTP.BAD_REQUEST).json({ message: 'Please provide month and year' });
        }

        // Calculate date range
        const startDate = new Date(year, month - 1, 1);
        const endDate = new Date(year, month, 0, 23, 59, 59);

        // Get fines for the month
        const fines = await IssuedFine.find({
            date: { $gte: startDate, $lte: endDate }
        }).populate('offenseId', 'offenseName');

        // Calculate statistics
        const totalFines = fines.length;
        const paidFines = fines.filter(f => f.status === PAYMENT.STATUS.PAID).length;
        const unpaidFines = fines.filter(f => f.status === PAYMENT.STATUS.UNPAID).length;
        const totalAmount = fines.reduce((sum, f) => sum + f.amount, 0);
        const paidAmount = fines.filter(f => f.status === PAYMENT.STATUS.PAID).reduce((sum, f) => sum + f.amount, 0);

        // Offense breakdown
        const offenseBreakdown = {};
        fines.forEach(fine => {
            const offenseName = fine.offenseName;
            if (!offenseBreakdown[offenseName]) {
                offenseBreakdown[offenseName] = { count: 0, amount: 0 };
            }
            offenseBreakdown[offenseName].count++;
            offenseBreakdown[offenseName].amount += fine.amount;
        });

        res.json({
            success: true,
            report: {
                month,
                year,
                period: `${startDate.toLocaleDateString()} - ${endDate.toLocaleDateString()}`,
                summary: {
                    totalFines,
                    paidFines,
                    unpaidFines,
                    totalAmount,
                    paidAmount,
                    unpaidAmount: totalAmount - paidAmount
                },
                offenseBreakdown,
                fines
            }
        });

    } catch (error) {
        console.error('Generate monthly report error:', error);
        res.status(HTTP.SERVER_ERROR).json({ message: 'Server error', error: error.message });
    }
};

// @desc    Generate payment summary report
// @route   POST /api/admin/reports/payments
// @access  Private (Admin)
const generatePaymentReport = async (req, res) => {
    try {
        const { startDate, endDate } = req.body;

        if (!startDate || !endDate) {
            return res.status(HTTP.BAD_REQUEST).json({ message: 'Please provide start and end dates' });
        }

        // Get paid fines in date range
        const payments = await IssuedFine.find({
            status: PAYMENT.STATUS.PAID,
            paidAt: { $gte: new Date(startDate), $lte: new Date(endDate) }
        }).populate('offenseId', 'offenseName');

        // Calculate statistics
        const totalPayments = payments.length;
        const totalRevenue = payments.reduce((sum, p) => sum + p.amount, 0);

        res.json({
            success: true,
            report: {
                period: `${startDate} - ${endDate}`,
                summary: {
                    totalPayments,
                    totalRevenue
                },
                payments
            }
        });

    } catch (error) {
        console.error('Generate payment report error:', error);
        res.status(HTTP.SERVER_ERROR).json({ message: 'Server error', error: error.message });
    }
};

// @desc    Generate driver violation report
// @route   POST /api/admin/reports/driver-violations
// @access  Private (Admin)
const generateDriverViolationReport = async (req, res) => {
    try {
        const { licenseNumber } = req.body;

        if (!licenseNumber) {
            return res.status(HTTP.BAD_REQUEST).json({ message: 'Please provide license number' });
        }

        const driver = await Driver.findOne({ licenseNumber });
        if (!driver) {
            return res.status(HTTP.NOT_FOUND).json({ message: 'Driver not found' });
        }

        const violations = await IssuedFine.find({ licenseNumber })
            .populate('offenseId', 'offenseName')
            .sort({ date: -1 });

        res.json({
            success: true,
            driver: {
                name: driver.name,
                licenseNumber: driver.licenseNumber,
                status: driver.licenseStatus
            },
            violations
        });

    } catch (error) {
        console.error('Generate driver report error:', error);
        res.status(HTTP.SERVER_ERROR).json({ message: 'Server error', error: error.message });
    }
};

module.exports = {
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
    // 2FA Exports
    generateTwoFactor,
    enableTwoFactor,
    disableTwoFactor,
    initAdminRegistration,
    completeAdminRegistration
};
