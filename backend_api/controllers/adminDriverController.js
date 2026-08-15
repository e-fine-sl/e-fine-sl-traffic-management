const Driver = require('../models/driverModel');
const IssuedFine = require('../models/issuedFineModel');
const bcrypt = require('bcryptjs');
const { HTTP, LICENSE_STATUS, DEMERIT } = require('../config/constants');
const { sendLicenseStatusEmail } = require('../services/emailService');
const PdfReportService = require('../services/pdfReportService');

// Helper to determine demerit level from points
function calculateDemeritLevel(points) {
    if (points >= 20) return 'EXCELLENT';
    if (points >= 15) return 'GOOD';
    if (points >= 10) return 'FAIR';
    if (points >= 5) return 'WARNING';
    if (points > 0) return 'DANGER';
    return 'SUSPENDED';
}

// @desc    Get all drivers with multi-dimensional filtering, search, sorting & pagination
// @route   GET /api/admin/drivers
// @access  Private (Admin)
const getAllDrivers = async (req, res) => {
    try {
        const page = parseInt(req.query.page, 10) || 1;
        const limit = parseInt(req.query.limit, 10) || 15;
        const search = req.query.search ? req.query.search.trim() : '';
        const status = req.query.status ? req.query.status.toUpperCase() : 'ALL';
        const demeritLevel = req.query.demeritLevel || 'ALL';
        const kycStatus = req.query.kycStatus || 'ALL';
        const sortBy = req.query.sortBy || 'createdAt';
        const sortOrder = req.query.sortOrder === 'asc' ? 1 : -1;

        const skip = (page - 1) * limit;

        // Build Match Query
        const query = {};

        if (search) {
            query.$or = [
                { name: { $regex: search, $options: 'i' } },
                { nic: { $regex: search, $options: 'i' } },
                { licenseNumber: { $regex: search, $options: 'i' } },
                { email: { $regex: search, $options: 'i' } },
                { phone: { $regex: search, $options: 'i' } },
                { vehicleNumber: { $regex: search, $options: 'i' } }
            ];
        }

        // Filter by License Status (ACTIVE vs SUSPENDED)
        if (status && status !== 'ALL') {
            query.licenseStatus = status;
        }

        // Filter by Demerit Risk Tier
        if (demeritLevel && demeritLevel !== 'ALL') {
            if (demeritLevel === 'HIGH_RISK') {
                query.$or = [
                    { demeritPoints: { $lt: 10 } },
                    { demeritLevel: { $in: ['WARNING', 'DANGER', 'SUSPENDED'] } }
                ];
            } else {
                query.demeritLevel = demeritLevel;
            }
        }

        // Filter by KYC Verification Status
        if (kycStatus && kycStatus !== 'ALL') {
            query.kycVerified = kycStatus === 'VERIFIED';
        }

        // Sort Options
        const sortOptions = {};
        sortOptions[sortBy] = sortOrder;

        // Fetch Drivers
        const [drivers, total] = await Promise.all([
            Driver.find(query)
                .select('-password')
                .sort(sortOptions)
                .skip(skip)
                .limit(limit)
                .lean(),
            Driver.countDocuments(query)
        ]);

        // Aggregate citation counts for the returned batch
        const licenseNumbers = drivers.map(d => d.licenseNumber).filter(Boolean);
        let fineStatsMap = {};

        if (licenseNumbers.length > 0) {
            const fineAgg = await IssuedFine.aggregate([
                { $match: { licenseNumber: { $in: licenseNumbers } } },
                {
                    $group: {
                        _id: '$licenseNumber',
                        totalFines: { $sum: 1 },
                        unpaidFines: {
                            $sum: {
                                $cond: [{ $in: ['$status', ['UNPAID', 'Unpaid', 'PENDING', 'Pending']] }, 1, 0]
                            }
                        },
                        totalFineAmount: { $sum: '$amount' }
                    }
                }
            ]);

            fineStatsMap = fineAgg.reduce((acc, curr) => {
                acc[curr._id] = curr;
                return acc;
            }, {});
        }

        // Enrich driver objects
        const enrichedDrivers = drivers.map(d => ({
            ...d,
            finesCount: fineStatsMap[d.licenseNumber]?.totalFines || 0,
            unpaidFinesCount: fineStatsMap[d.licenseNumber]?.unpaidFines || 0,
            totalFineAmount: fineStatsMap[d.licenseNumber]?.totalFineAmount || 0
        }));

        res.status(HTTP.OK).json({
            success: true,
            data: enrichedDrivers,
            total,
            page,
            pages: Math.ceil(total / limit) || 1,
            limit,
            count: enrichedDrivers.length
        });

    } catch (error) {
        console.error('[getAllDrivers] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to retrieve driver directory',
            error: error.message
        });
    }
};

// @desc    Get executive KPI metrics for driver registry
// @route   GET /api/admin/drivers/metrics
// @access  Private (Admin)
const getDriverMetrics = async (req, res) => {
    try {
        const [
            totalDrivers,
            activeDrivers,
            suspendedDrivers,
            highRiskDrivers,
            kycVerifiedCount,
            demeritDistribution,
            avgRatingAgg
        ] = await Promise.all([
            Driver.countDocuments(),
            Driver.countDocuments({ licenseStatus: 'ACTIVE' }),
            Driver.countDocuments({ licenseStatus: 'SUSPENDED' }),
            Driver.countDocuments({
                $or: [
                    { demeritPoints: { $lt: 10 } },
                    { demeritLevel: { $in: ['WARNING', 'DANGER', 'SUSPENDED'] } }
                ]
            }),
            Driver.countDocuments({ kycVerified: true }),
            Driver.aggregate([
                { $group: { _id: '$demeritLevel', count: { $sum: 1 } } }
            ]),
            Driver.aggregate([
                { $group: { _id: null, avgRating: { $avg: '$ratingScore' } } }
            ])
        ]);

        const levelOrder = ['EXCELLENT', 'GOOD', 'FAIR', 'WARNING', 'DANGER', 'SUSPENDED'];
        const riskBreakdown = levelOrder.map(lvl => {
            const found = demeritDistribution.find(d => d._id === lvl);
            return {
                level: lvl,
                count: found ? found.count : 0
            };
        });

        const averageRating = avgRatingAgg.length > 0 && avgRatingAgg[0].avgRating 
            ? parseFloat(avgRatingAgg[0].avgRating.toFixed(2)) 
            : 5.0;

        res.status(HTTP.OK).json({
            success: true,
            data: {
                totalDrivers,
                activeDrivers,
                suspendedDrivers,
                highRiskDrivers,
                kycVerifiedCount,
                averageRating,
                riskBreakdown
            }
        });

    } catch (error) {
        console.error('[getDriverMetrics] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to calculate driver metrics',
            error: error.message
        });
    }
};

// @desc    Get deep driver profile dossier & citation ledger
// @route   GET /api/admin/drivers/:id
// @access  Private (Admin)
const getDriverById = async (req, res) => {
    try {
        const driver = await Driver.findById(req.params.id).select('-password').lean();

        if (!driver) {
            return res.status(HTTP.NOT_FOUND).json({
                success: false,
                message: 'Driver not found in database'
            });
        }

        // Fetch violation history
        const violations = await IssuedFine.find({ licenseNumber: driver.licenseNumber })
            .sort({ date: -1 })
            .populate('offenseId', 'offenseName sectionOfAct')
            .lean();

        // Calculate violation stats
        const totalFines = violations.length;
        const paidFines = violations.filter(v => (v.status || '').toUpperCase() === 'PAID').length;
        const unpaidFines = totalFines - paidFines;
        const totalAmount = violations.reduce((sum, v) => sum + (v.amount || 0), 0);
        const unpaidAmount = violations
            .filter(v => (v.status || '').toUpperCase() !== 'PAID')
            .reduce((sum, v) => sum + (v.amount || 0), 0);

        res.status(HTTP.OK).json({
            success: true,
            driver: {
                ...driver,
                enforcementSummary: {
                    totalFines,
                    paidFines,
                    unpaidFines,
                    totalAmount,
                    unpaidAmount
                }
            },
            violations: violations.slice(0, 50)
        });

    } catch (error) {
        console.error('[getDriverById] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to retrieve driver dossier',
            error: error.message
        });
    }
};

// @desc    Register a new driver account (In-Person / Admin Desk)
// @route   POST /api/admin/drivers
// @access  Private (Admin Officer, Super Admin)
const createDriver = async (req, res) => {
    try {
        const {
            name,
            nic,
            licenseNumber,
            email,
            phone,
            password,
            vehicleNumber,
            city,
            addressLine1,
            licenseExpiryDate,
            dateOfBirth
        } = req.body;

        // Validation
        if (!name || !nic || !licenseNumber || !email || !phone || !password) {
            return res.status(HTTP.BAD_REQUEST).json({
                success: false,
                message: 'Please provide all required driver credentials (Name, NIC, License, Email, Phone, Password)'
            });
        }

        // Check for existing duplicates
        const [existingNic, existingLicense, existingEmail] = await Promise.all([
            Driver.findOne({ nic: nic.toUpperCase().trim() }),
            Driver.findOne({ licenseNumber: licenseNumber.toUpperCase().trim() }),
            Driver.findOne({ email: email.toLowerCase().trim() })
        ]);

        if (existingNic) {
            return res.status(HTTP.BAD_REQUEST).json({
                success: false,
                message: `National ID (${nic}) is already registered in the driver directory`
            });
        }

        if (existingLicense) {
            return res.status(HTTP.BAD_REQUEST).json({
                success: false,
                message: `Driving License Number (${licenseNumber}) is already registered`
            });
        }

        if (existingEmail) {
            return res.status(HTTP.BAD_REQUEST).json({
                success: false,
                message: `Email address (${email}) is already associated with an existing account`
            });
        }

        // Hash password
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);

        const newDriver = await Driver.create({
            name: name.trim(),
            nic: nic.toUpperCase().trim(),
            licenseNumber: licenseNumber.toUpperCase().trim(),
            email: email.toLowerCase().trim(),
            phone: phone.trim(),
            password: hashedPassword,
            vehicleNumber: vehicleNumber ? vehicleNumber.toUpperCase().trim() : undefined,
            city: city ? city.trim() : undefined,
            addressLine1: addressLine1 ? addressLine1.trim() : undefined,
            licenseExpiryDate: licenseExpiryDate || undefined,
            dateOfBirth: dateOfBirth || undefined,
            demeritPoints: DEMERIT.DEFAULT_POINTS || 24,
            ratingScore: 5.0,
            licenseStatus: LICENSE_STATUS.ACTIVE,
            demeritLevel: 'EXCELLENT',
            isVerified: true,
            kycVerified: false,
            emailIsVerified: true
        });

        res.status(HTTP.CREATED).json({
            success: true,
            message: `Driver "${newDriver.name}" (License: ${newDriver.licenseNumber}) registered successfully`,
            data: {
                id: newDriver._id,
                name: newDriver.name,
                nic: newDriver.nic,
                licenseNumber: newDriver.licenseNumber,
                email: newDriver.email,
                licenseStatus: newDriver.licenseStatus
            }
        });

    } catch (error) {
        console.error('[createDriver] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to create driver account',
            error: error.message
        });
    }
};

// @desc    Update driver profile particulars
// @route   PUT /api/admin/drivers/:id
// @access  Private (Admin Officer, Super Admin)
const updateDriver = async (req, res) => {
    try {
        const { name, phone, email, vehicleNumber, addressLine1, city, postalCode } = req.body;

        const driver = await Driver.findById(req.params.id);

        if (!driver) {
            return res.status(HTTP.NOT_FOUND).json({
                success: false,
                message: 'Driver not found'
            });
        }

        // If email is being changed, ensure uniqueness
        if (email && email.toLowerCase().trim() !== driver.email) {
            const emailInUse = await Driver.findOne({ email: email.toLowerCase().trim() });
            if (emailInUse) {
                return res.status(HTTP.BAD_REQUEST).json({
                    success: false,
                    message: 'Email address is already in use by another driver'
                });
            }
            driver.email = email.toLowerCase().trim();
        }

        if (name) driver.name = name.trim();
        if (phone) driver.phone = phone.trim();
        if (vehicleNumber !== undefined) driver.vehicleNumber = vehicleNumber ? vehicleNumber.toUpperCase().trim() : '';
        if (addressLine1 !== undefined) driver.addressLine1 = addressLine1 ? addressLine1.trim() : '';
        if (city !== undefined) driver.city = city ? city.trim() : '';
        await driver.save();

        // Dispatch FCM push notification to driver's mobile phone
        if (driver.fcmToken) {
            try {
                const { sendToToken } = require('../services/fcmService');
                await sendToToken(driver.fcmToken, {
                    title: 'Driver Profile Updated',
                    body: `Your motorist registration particulars (Contact/Vehicle/Address) have been updated by the Traffic Management Authority.`,
                    channelId: 'traffic_alerts',
                    data: {
                        type: 'PROFILE_UPDATED',
                        licenseNumber: driver.licenseNumber,
                        updatedAt: new Date().toISOString()
                    }
                });
            } catch (fcmError) {
                console.error('[updateDriver] Push notification error:', fcmError);
            }
        }

        res.status(HTTP.OK).json({
            success: true,
            message: `Driver details for "${driver.name}" updated successfully`,
            data: driver
        });

    } catch (error) {
        console.error('[updateDriver] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to update driver details',
            error: error.message
        });
    }
};

// @desc    Suspend driver license with reason and alert dispatch
// @route   PUT /api/admin/drivers/:id/suspend
// @access  Private (Admin Officer, Super Admin)
const suspendDriver = async (req, res) => {
    try {
        const driver = await Driver.findById(req.params.id);

        if (!driver) {
            return res.status(HTTP.NOT_FOUND).json({
                success: false,
                message: 'Driver not found'
            });
        }

        if (driver.licenseStatus === 'SUSPENDED') {
            return res.status(HTTP.BAD_REQUEST).json({
                success: false,
                message: 'Driver license is already suspended'
            });
        }

        const reasonNote = req.body.reason || req.body.note || 'Suspended by Traffic Management Authority Administrator';

        driver.licenseStatus = 'SUSPENDED';
        driver.demeritLevel = 'SUSPENDED';
        driver.suspendedAt = new Date();
        driver.suspensionReason = reasonNote;
        await driver.save();

        // Dispatch email notification
        try {
            await sendLicenseStatusEmail(driver, 'SUSPENDED', reasonNote);
        } catch (emailError) {
            console.error('[suspendDriver] Email send error:', emailError);
        }

        // Dispatch FCM Push if token present
        if (driver.fcmToken) {
            try {
                const { sendToToken } = require('../services/fcmService');
                await sendToToken(driver.fcmToken, {
                    title: 'DRIVING LICENSE SUSPENDED',
                    body: `Your driving license (${driver.licenseNumber}) has been suspended. Reason: ${reasonNote}`,
                    data: {
                        type: 'DRIVER_SUSPENDED',
                        licenseNumber: driver.licenseNumber,
                        reason: reasonNote
                    }
                });
            } catch (fcmError) {
                console.error('[suspendDriver] Push notification error:', fcmError);
            }
        }

        res.status(HTTP.OK).json({
            success: true,
            message: `Driver license for ${driver.name} (License: ${driver.licenseNumber}) has been SUSPENDED`,
            driver: {
                id: driver._id,
                name: driver.name,
                licenseNumber: driver.licenseNumber,
                licenseStatus: driver.licenseStatus,
                suspensionReason: driver.suspensionReason
            }
        });

    } catch (error) {
        console.error('[suspendDriver] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to suspend driver license',
            error: error.message
        });
    }
};

// @desc    Activate / Restore driver license
// @route   PUT /api/admin/drivers/:id/activate
// @access  Private (Admin Officer, Super Admin)
const activateDriver = async (req, res) => {
    try {
        const driver = await Driver.findById(req.params.id);

        if (!driver) {
            return res.status(HTTP.NOT_FOUND).json({
                success: false,
                message: 'Driver not found'
            });
        }

        if (driver.licenseStatus === 'ACTIVE') {
            return res.status(HTTP.BAD_REQUEST).json({
                success: false,
                message: 'Driver license is already active'
            });
        }

        driver.licenseStatus = LICENSE_STATUS.ACTIVE;
        driver.demeritPoints = DEMERIT.DEFAULT_POINTS || 24; // Reset to 24
        driver.demeritLevel = 'EXCELLENT';
        driver.ratingScore = 5.0;
        driver.suspendedAt = null;
        driver.suspensionReason = null;
        await driver.save();

        // Dispatch email notification
        try {
            await sendLicenseStatusEmail(driver, 'ACTIVE');
        } catch (emailError) {
            console.error('[activateDriver] Email send error:', emailError);
        }

        // Dispatch FCM push if registered
        if (driver.fcmToken) {
            try {
                const { sendToToken } = require('../services/fcmService');
                await sendToToken(driver.fcmToken, {
                    title: 'DRIVING LICENSE RESTORED',
                    body: `Your driving license (${driver.licenseNumber}) is now ACTIVE with 24 demerit points restored.`,
                    data: {
                        type: 'DRIVER_ACTIVATED',
                        licenseNumber: driver.licenseNumber
                    }
                });
            } catch (fcmError) {
                console.error('[activateDriver] Push notification error:', fcmError);
            }
        }

        res.status(HTTP.OK).json({
            success: true,
            message: `Driver license for ${driver.name} (License: ${driver.licenseNumber}) has been ACTIVATED and restored to 24 points`,
            driver: {
                id: driver._id,
                name: driver.name,
                licenseNumber: driver.licenseNumber,
                licenseStatus: driver.licenseStatus,
                demeritPoints: driver.demeritPoints
            }
        });

    } catch (error) {
        console.error('[activateDriver] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to activate driver license',
            error: error.message
        });
    }
};

// @desc    Adjust driver demerit points (Court order / Legal pardon / Administrative review)
// @route   POST /api/admin/drivers/:id/adjust-demerit
// @access  Private (Super Admin Only)
const adjustDriverDemerit = async (req, res) => {
    try {
        const { newPoints, reason } = req.body;

        if (newPoints === undefined || isNaN(newPoints) || newPoints < 0 || newPoints > 24) {
            return res.status(HTTP.BAD_REQUEST).json({
                success: false,
                message: 'New demerit points value must be an integer between 0 and 24'
            });
        }

        const driver = await Driver.findById(req.params.id);

        if (!driver) {
            return res.status(HTTP.NOT_FOUND).json({
                success: false,
                message: 'Driver not found'
            });
        }

        const pointsNum = parseInt(newPoints, 10);
        driver.demeritPoints = pointsNum;

        // Auto calculate new demerit risk level
        if (driver.licenseStatus !== 'SUSPENDED') {
            driver.demeritLevel = calculateDemeritLevel(pointsNum);
        }

        // Adjust rating score proportionally
        driver.ratingScore = parseFloat(((pointsNum / 24) * 5.0).toFixed(1));

        await driver.save();

        // Dispatch FCM push notification to driver's phone
        if (driver.fcmToken) {
            try {
                const { sendToToken } = require('../services/fcmService');
                await sendToToken(driver.fcmToken, {
                    title: 'Demerit Points Adjusted',
                    body: `Your demerit points have been adjusted to ${pointsNum}/24 (${driver.demeritLevel}). Reason: ${reason || 'Administrative adjustment'}.`,
                    channelId: 'traffic_alerts',
                    data: {
                        type: 'DEMERIT_ADJUSTED',
                        licenseNumber: driver.licenseNumber,
                        newPoints: String(pointsNum),
                        reason: reason || ''
                    }
                });
            } catch (fcmError) {
                console.error('[adjustDriverDemerit] Push notification error:', fcmError);
            }
        }

        res.status(HTTP.OK).json({
            success: true,
            message: `Demerit points for ${driver.name} adjusted to ${pointsNum}/24 (${driver.demeritLevel}). Reason: ${reason || 'Administrative adjustment'}`,
            driver: {
                id: driver._id,
                name: driver.name,
                licenseNumber: driver.licenseNumber,
                demeritPoints: driver.demeritPoints,
                demeritLevel: driver.demeritLevel,
                ratingScore: driver.ratingScore
            }
        });

    } catch (error) {
        console.error('[adjustDriverDemerit] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to adjust driver demerit points',
            error: error.message
        });
    }
};

// @desc    Admin-assisted driver password / PIN reset
// @route   POST /api/admin/drivers/:id/reset-credentials
// @access  Private (Super Admin Only)
const resetDriverCredentials = async (req, res) => {
    try {
        const { newPassword } = req.body;

        if (!newPassword || newPassword.length < 6) {
            return res.status(HTTP.BAD_REQUEST).json({
                success: false,
                message: 'New password must be at least 6 characters in length'
            });
        }

        const driver = await Driver.findById(req.params.id);

        if (!driver) {
            return res.status(HTTP.NOT_FOUND).json({
                success: false,
                message: 'Driver not found'
            });
        }

        const salt = await bcrypt.genSalt(10);
        driver.password = await bcrypt.hash(newPassword, salt);
        await driver.save();

        // Dispatch FCM push notification to driver's phone
        if (driver.fcmToken) {
            try {
                const { sendToToken } = require('../services/fcmService');
                await sendToToken(driver.fcmToken, {
                    title: 'Security Notice: Password Reset',
                    body: 'Your driver portal account password has been reset by the System Administrator. Please log in using your new credentials.',
                    channelId: 'traffic_alerts',
                    data: {
                        type: 'PASSWORD_RESET',
                        licenseNumber: driver.licenseNumber
                    }
                });
            } catch (fcmError) {
                console.error('[resetDriverCredentials] Push notification error:', fcmError);
            }
        }

        res.status(HTTP.OK).json({
            success: true,
            message: `Credentials for Driver "${driver.name}" (License: ${driver.licenseNumber}) updated successfully`
        });

    } catch (error) {
        console.error('[resetDriverCredentials] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to reset driver credentials',
            error: error.message
        });
    }
};

// @desc    Export filtered driver registry (CSV / PDF)
// @route   GET /api/admin/drivers/export
// @access  Private (Admin)
const exportDrivers = async (req, res) => {
    try {
        const { search, status, demeritLevel, format = 'csv' } = req.query;

        const query = {};

        if (search) {
            query.$or = [
                { name: { $regex: search, $options: 'i' } },
                { nic: { $regex: search, $options: 'i' } },
                { licenseNumber: { $regex: search, $options: 'i' } },
                { email: { $regex: search, $options: 'i' } },
                { phone: { $regex: search, $options: 'i' } }
            ];
        }

        if (status && status !== 'ALL') query.licenseStatus = status;
        if (demeritLevel && demeritLevel !== 'ALL') query.demeritLevel = demeritLevel;

        const drivers = await Driver.find(query).sort({ licenseStatus: 1, name: 1 }).lean();

        // ── Format = PDF ──────────────────────────────────────────────────────────
        if (format === 'pdf') {
            const PDFDocument = require('pdfkit-table');
            const doc = new PDFDocument({
                margin: 40,
                size: 'A4',
                info: {
                    Title: 'Sri Lanka Driver Directory & Demerit Ledger',
                    Author: 'e-Fine SL Traffic Enforcement Authority'
                }
            });

            const buffers = [];
            doc.on('data', b => buffers.push(b));

            const totalDriversCount = drivers.length;
            const activeDriversCount = drivers.filter(d => d.licenseStatus === 'ACTIVE').length;
            const suspendedCount = drivers.filter(d => d.licenseStatus === 'SUSPENDED').length;

            PdfReportService.buildHeader(doc, {
                title: 'Driver Registry & Demerit Ledger',
                subtitle: 'Official Sri Lanka Department of Motor Traffic & Police Registry',
                dateRange: `Status: ${status || 'All'} | Risk Tier: ${demeritLevel || 'All'}`
            });

            PdfReportService.buildKPICards(doc, [
                { label: 'Total Drivers', value: totalDriversCount.toString(), subtext: 'Registered Motorists', color: '#2563EB' },
                { label: 'Active Licenses', value: activeDriversCount.toString(), subtext: 'Authorized Driving', color: '#16A34A' },
                { label: 'Suspended Licenses', value: suspendedCount.toString(), subtext: 'Suspended Drivers', color: '#DC2626' }
            ]);

            doc.moveDown(1.5);

            const table = {
                title: 'Licensed Motorist Directory',
                headers: ['License No', 'Driver Name', 'NIC', 'Contact Phone', 'Demerit Pts', 'Risk Level', 'Status'],
                rows: drivers.slice(0, 500).map(d => [
                    d.licenseNumber || 'N/A',
                    d.name || 'N/A',
                    d.nic || 'N/A',
                    d.phone || 'N/A',
                    `${d.demeritPoints || 0}/24`,
                    d.demeritLevel || 'EXCELLENT',
                    d.licenseStatus || 'ACTIVE'
                ])
            };

            await doc.table(table, {
                prepareHeader: () => doc.font('Helvetica-Bold').fontSize(8),
                prepareRow: (row, indexColumn, indexRow, rect, rowHeight) => {
                    doc.font('Helvetica').fontSize(7.5);
                }
            });

            PdfReportService.buildFooter(doc, 'e-Fine SL • Official Licensed Motorist Directory');
            doc.end();

            return new Promise((resolve) => {
                doc.on('end', () => {
                    const pdfData = Buffer.concat(buffers);
                    res.setHeader('Content-Type', 'application/pdf');
                    res.setHeader('Content-Disposition', `attachment; filename="eFine-Driver-List-${new Date().toISOString().slice(0, 10)}.pdf"`);
                    res.status(HTTP.OK).send(pdfData);
                    resolve();
                });
            });
        }

        // ── Format = CSV ──────────────────────────────────────────────────────────
        const headers = ['License Number', 'Driver Name', 'National ID (NIC)', 'Email Address', 'Contact Phone', 'Vehicle Number', 'Demerit Points', 'Demerit Level', 'Rating Score', 'License Status', 'KYC Verified', 'Registered Date'];
        const rows = drivers.map(d => [
            `"${d.licenseNumber || ''}"`,
            `"${(d.name || '').replace(/"/g, '""')}"`,
            `"${d.nic || ''}"`,
            `"${d.email || ''}"`,
            `"${d.phone || ''}"`,
            `"${d.vehicleNumber || ''}"`,
            `"${d.demeritPoints ?? 24}"`,
            `"${d.demeritLevel || 'EXCELLENT'}"`,
            `"${d.ratingScore || 5.0}"`,
            `"${d.licenseStatus || 'ACTIVE'}"`,
            `"${d.kycVerified ? 'YES' : 'NO'}"`,
            `"${d.createdAt ? new Date(d.createdAt).toISOString() : 'N/A'}"`
        ]);

        const csvContent = [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
        const fileName = `eFine-Driver-List-${new Date().toISOString().slice(0, 10)}.csv`;

        res.setHeader('Content-Type', 'text/csv');
        res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
        return res.status(HTTP.OK).send(csvContent);

    } catch (error) {
        console.error('[exportDrivers] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to export driver directory',
            error: error.message
        });
    }
};

// @desc    Safe Delete Driver (Guard against historical fines)
// @route   DELETE /api/admin/drivers/:id
// @access  Private (Super Admin Only)
const deleteDriver = async (req, res) => {
    try {
        const driver = await Driver.findById(req.params.id);

        if (!driver) {
            return res.status(HTTP.NOT_FOUND).json({
                success: false,
                message: 'Driver not found'
            });
        }

        // Check if historical fines exist for this driver
        const finesCount = await IssuedFine.countDocuments({ licenseNumber: driver.licenseNumber });

        // Dispatch FCM Push notification before action
        if (driver.fcmToken) {
            try {
                const { sendToToken } = require('../services/fcmService');
                await sendToToken(driver.fcmToken, {
                    title: 'Driver Account Record Notice',
                    body: `Your motorist registry account has been ${finesCount > 0 ? 'archived and permanently suspended' : 'removed from the registry'} by the Traffic Management Authority.`,
                    channelId: 'traffic_alerts',
                    data: {
                        type: 'ACCOUNT_STATUS_CHANGE',
                        licenseNumber: driver.licenseNumber
                    }
                });
            } catch (fcmError) {
                console.error('[deleteDriver] Push notification error:', fcmError);
            }
        }

        if (finesCount > 0) {
            // Data integrity protection: Prohibit hard deletion, set to SUSPENDED
            driver.licenseStatus = 'SUSPENDED';
            driver.demeritLevel = 'SUSPENDED';
            driver.suspensionReason = `Account locked/archived. Driver has ${finesCount} historical citation records in the database.`;
            await driver.save();

            return res.status(HTTP.OK).json({
                success: true,
                isSoftDeleted: true,
                message: `Driver "${driver.name}" has ${finesCount} historical traffic fines and cannot be hard deleted. The account has been converted to PERMANENTLY SUSPENDED.`
            });
        }

        await driver.deleteOne();

        res.status(HTTP.OK).json({
            success: true,
            isSoftDeleted: false,
            message: `Driver "${driver.name}" (License: ${driver.licenseNumber}) permanently removed from database.`
        });

    } catch (error) {
        console.error('[deleteDriver] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to delete driver record',
            error: error.message
        });
    }
};

module.exports = {
    getAllDrivers,
    getDriverMetrics,
    getDriverById,
    createDriver,
    updateDriver,
    suspendDriver,
    activateDriver,
    adjustDriverDemerit,
    resetDriverCredentials,
    exportDrivers,
    deleteDriver
};
