const bcrypt = require('bcryptjs');
const mongoose = require('mongoose');
const Police = require('../models/policeModel');
const IssuedFine = require('../models/issuedFineModel');
const Station = require('../models/stationModel');
const { HTTP, ROLES, PAGINATION } = require('../config/constants');
const PdfReportService = require('../services/pdfReportService');

// @desc    Get all police officers with multi-dimensional filtering & pagination
// @route   GET /api/admin/officers
// @access  Private (Admin)
const getAllOfficers = async (req, res) => {
    try {
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || PAGINATION.DEFAULT_LIMIT || 15;
        const skip = (page - 1) * limit;

        const { search, station, position, status, dutyState, sortBy = 'createdAt', sortOrder = 'desc' } = req.query;

        let query = {};

        // 1. Text Search across Name, Badge Number, Email, NIC, Phone
        if (search && search.trim() !== '') {
            const searchRegex = { $regex: search.trim(), $options: 'i' };
            query.$or = [
                { name: searchRegex },
                { badgeNumber: searchRegex },
                { email: searchRegex },
                { nic: searchRegex },
                { phone: searchRegex },
                { policeStation: searchRegex }
            ];
        }

        // 2. Filter by Police Station
        if (station && station !== 'ALL') {
            query.policeStation = station;
        }

        // 3. Filter by Position / Rank
        if (position && position !== 'ALL') {
            query.position = position;
        }

        // 4. Filter by Account Status (Active vs Suspended)
        if (status && status !== 'ALL') {
            if (status === 'ACTIVE') {
                query.isActive = true;
            } else if (status === 'SUSPENDED' || status === 'INACTIVE') {
                query.isActive = false;
            }
        }

        // 5. Filter by Presence Duty State (FOREGROUND, BACKGROUND, LOGGED_OUT)
        if (dutyState && dutyState !== 'ALL') {
            query.appState = dutyState;
        }

        const sortOptions = {};
        sortOptions[sortBy] = sortOrder === 'asc' ? 1 : -1;

        const [officers, total] = await Promise.all([
            Police.find(query)
                .select('-password')
                .sort(sortOptions)
                .skip(skip)
                .limit(limit)
                .lean(),
            Police.countDocuments(query)
        ]);

        // Attach Fine Counts for each officer
        const badgeNumbers = officers.map(o => o.badgeNumber).filter(Boolean);
        const fineCounts = await IssuedFine.aggregate([
            { $match: { policeOfficerId: { $in: badgeNumbers } } },
            { $group: { _id: '$policeOfficerId', count: { $sum: 1 }, totalRevenue: { $sum: '$amount' } } }
        ]);

        const fineCountMap = {};
        fineCounts.forEach(fc => {
            fineCountMap[fc._id] = { count: fc.count, totalRevenue: fc.totalRevenue };
        });

        const enrichedOfficers = officers.map(officer => ({
            ...officer,
            finesCount: fineCountMap[officer.badgeNumber]?.count || 0,
            finesRevenue: fineCountMap[officer.badgeNumber]?.totalRevenue || 0
        }));

        res.status(HTTP.OK).json({
            success: true,
            data: enrichedOfficers,
            total,
            page,
            pages: Math.ceil(total / limit) || 1,
            limit,
            count: enrichedOfficers.length
        });
    } catch (error) {
        console.error('[getAllOfficers] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to retrieve police officers',
            error: error.message
        });
    }
};

// @desc    Get aggregated Police Officer Workforce & Field Metrics
// @route   GET /api/admin/officers/metrics
// @access  Private (Admin)
const getOfficerMetrics = async (req, res) => {
    try {
        const [
            totalOfficers,
            activeOfficers,
            suspendedOfficers,
            onDutyOfficers,
            stationsResult,
            rankDistribution,
            totalCitationsResult
        ] = await Promise.all([
            Police.countDocuments(),
            Police.countDocuments({ isActive: true }),
            Police.countDocuments({ isActive: false }),
            Police.countDocuments({ appState: { $in: ['FOREGROUND', 'BACKGROUND'] } }),
            Police.distinct('policeStation'),
            Police.aggregate([
                { $group: { _id: '$position', count: { $sum: 1 } } },
                { $sort: { count: -1 } }
            ]),
            IssuedFine.countDocuments()
        ]);

        res.status(HTTP.OK).json({
            success: true,
            data: {
                totalOfficers,
                activeOfficers,
                suspendedOfficers,
                onDutyOfficers,
                stationsCoveredCount: stationsResult.filter(Boolean).length,
                totalCitationsIssued: totalCitationsResult,
                rankDistribution: rankDistribution.map(r => ({ position: r._id || 'Unassigned', count: r.count }))
            }
        });
    } catch (error) {
        console.error('[getOfficerMetrics] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to calculate officer metrics',
            error: error.message
        });
    }
};

// @desc    Get deep Officer profile dossier with fine history & activity
// @route   GET /api/admin/officers/:id
// @access  Private (Admin)
const getOfficerById = async (req, res) => {
    try {
        const { id } = req.params;
        const officer = await Police.findById(id).select('-password').lean();

        if (!officer) {
            return res.status(HTTP.NOT_FOUND).json({
                success: false,
                message: 'Police officer not found'
            });
        }

        // Fetch officer enforcement statistics
        const [fineStats, recentFines, stationInfo] = await Promise.all([
            IssuedFine.aggregate([
                { $match: { policeOfficerId: officer.badgeNumber } },
                {
                    $group: {
                        _id: null,
                        totalFines: { $sum: 1 },
                        totalAmount: { $sum: '$amount' },
                        paidFines: { $sum: { $cond: [{ $eq: ['$status', 'PAID'] }, 1, 0] } },
                        paidAmount: { $sum: { $cond: [{ $eq: ['$status', 'PAID'] }, '$amount', 0] } },
                        unpaidFines: { $sum: { $cond: [{ $in: ['$status', ['UNPAID', 'PENDING']] }, 1, 0] } }
                    }
                }
            ]),
            IssuedFine.find({ policeOfficerId: officer.badgeNumber })
                .sort({ createdAt: -1 })
                .limit(10)
                .lean(),
            Station.findOne({ $or: [{ name: officer.policeStation }, { stationCode: officer.policeStation }] }).lean()
        ]);

        const stats = fineStats[0] || {
            totalFines: 0,
            totalAmount: 0,
            paidFines: 0,
            paidAmount: 0,
            unpaidFines: 0
        };

        const officerDossier = {
            ...officer,
            stationDetails: stationInfo || null,
            enforcementStats: {
                totalFines: stats.totalFines,
                totalAmount: stats.totalAmount,
                paidFines: stats.paidFines,
                paidAmount: stats.paidAmount,
                unpaidFines: stats.unpaidFines,
                collectionRate: stats.totalFines > 0 ? parseFloat(((stats.paidFines / stats.totalFines) * 100).toFixed(1)) : 0
            },
            recentFines
        };

        res.status(HTTP.OK).json({
            success: true,
            data: officerDossier
        });
    } catch (error) {
        console.error('[getOfficerById] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to retrieve officer profile',
            error: error.message
        });
    }
};

// @desc    Create new Police Officer
// @route   POST /api/admin/officers
// @access  Private (Super Admin & Admin Officer)
const createOfficer = async (req, res) => {
    try {
        const { name, email, badgeNumber, nic, phone, password, policeStation, position, profileImage } = req.body;

        if (!name || !email || !badgeNumber || !nic || !phone || !password || !policeStation || !position) {
            return res.status(HTTP.BAD_REQUEST).json({
                success: false,
                message: 'All fields (Name, Email, Badge, NIC, Phone, Password, Station, Position) are required.'
            });
        }

        // Check badge uniqueness
        const existingBadge = await Police.findOne({ badgeNumber: badgeNumber.trim() });
        if (existingBadge) {
            return res.status(HTTP.BAD_REQUEST).json({
                success: false,
                message: `Badge number "${badgeNumber}" is already registered to another officer.`
            });
        }

        // Check email uniqueness
        const existingEmail = await Police.findOne({ email: email.toLowerCase().trim() });
        if (existingEmail) {
            return res.status(HTTP.BAD_REQUEST).json({
                success: false,
                message: `Email "${email}" is already in use.`
            });
        }

        // Check NIC uniqueness
        const existingNic = await Police.findOne({ nic: nic.toUpperCase().trim() });
        if (existingNic) {
            return res.status(HTTP.BAD_REQUEST).json({
                success: false,
                message: `NIC "${nic}" is already registered.`
            });
        }

        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);

        const officer = await Police.create({
            name: name.trim(),
            email: email.toLowerCase().trim(),
            badgeNumber: badgeNumber.trim(),
            nic: nic.toUpperCase().trim(),
            phone: phone.trim(),
            password: hashedPassword,
            policeStation: policeStation.trim(),
            position: position.trim(),
            profileImage: profileImage || 'https://cdn-icons-png.flaticon.com/512/206/206853.png',
            isActive: true,
            appState: 'LOGGED_OUT'
        });

        res.status(HTTP.CREATED).json({
            success: true,
            message: `Police Officer ${officer.name} (Badge: ${officer.badgeNumber}) registered successfully.`,
            data: {
                id: officer._id,
                name: officer.name,
                email: officer.email,
                badgeNumber: officer.badgeNumber,
                policeStation: officer.policeStation,
                position: officer.position,
                isActive: officer.isActive
            }
        });
    } catch (error) {
        console.error('[createOfficer] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to create police officer',
            error: error.message
        });
    }
};

// @desc    Update police officer profile particulars
// @route   PUT /api/admin/officers/:id
// @access  Private (Super Admin & Admin Officer)
const updateOfficer = async (req, res) => {
    try {
        const { id } = req.params;
        const officer = await Police.findById(id);

        if (!officer) {
            return res.status(HTTP.NOT_FOUND).json({
                success: false,
                message: 'Police officer not found'
            });
        }

        const { name, email, phone, position, policeStation, profileImage } = req.body;

        if (name) officer.name = name.trim();
        if (email) officer.email = email.toLowerCase().trim();
        if (phone) officer.phone = phone.trim();
        if (position) officer.position = position.trim();
        if (policeStation) officer.policeStation = policeStation.trim();
        if (profileImage) officer.profileImage = profileImage;

        await officer.save();

        res.status(HTTP.OK).json({
            success: true,
            message: `Officer profile for ${officer.name} updated successfully.`,
            data: {
                id: officer._id,
                name: officer.name,
                email: officer.email,
                badgeNumber: officer.badgeNumber,
                policeStation: officer.policeStation,
                position: officer.position,
                phone: officer.phone,
                isActive: officer.isActive
            }
        });
    } catch (error) {
        console.error('[updateOfficer] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to update officer profile',
            error: error.message
        });
    }
};

// @desc    Toggle Officer Account Status (Active vs Suspended)
// @route   PATCH /api/admin/officers/:id/status
// @access  Private (Super Admin & Admin Officer)
const toggleOfficerStatus = async (req, res) => {
    try {
        const { id } = req.params;
        const { isActive, reason } = req.body;

        const officer = await Police.findById(id);
        if (!officer) {
            return res.status(HTTP.NOT_FOUND).json({
                success: false,
                message: 'Police officer not found'
            });
        }

        officer.isActive = isActive;
        if (!isActive) {
            // Force logout from mobile app & revoke session
            officer.appState = 'LOGGED_OUT';
            officer.fcmToken = null;
        }

        await officer.save();

        const statusLabel = isActive ? 'ACTIVATED' : 'SUSPENDED';
        res.status(HTTP.OK).json({
            success: true,
            message: `Officer ${officer.name} account has been ${statusLabel}. ${reason ? `Reason: ${reason}` : ''}`,
            data: {
                id: officer._id,
                name: officer.name,
                badgeNumber: officer.badgeNumber,
                isActive: officer.isActive,
                appState: officer.appState
            }
        });
    } catch (error) {
        console.error('[toggleOfficerStatus] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to update officer status',
            error: error.message
        });
    }
};

// @desc    Execute Police Station Transfer with audit remarks
// @route   POST /api/admin/officers/:id/transfer
// @access  Private (Super Admin & Admin Officer)
const transferOfficerStation = async (req, res) => {
    try {
        const { id } = req.params;
        const { targetStation, transferReason, effectiveDate } = req.body;

        if (!targetStation) {
            return res.status(HTTP.BAD_REQUEST).json({
                success: false,
                message: 'Target police station is required'
            });
        }

        const officer = await Police.findById(id);
        if (!officer) {
            return res.status(HTTP.NOT_FOUND).json({
                success: false,
                message: 'Police officer not found'
            });
        }

        const previousStation = officer.policeStation;
        officer.policeStation = targetStation;
        await officer.save();

        res.status(HTTP.OK).json({
            success: true,
            message: `Officer ${officer.name} successfully transferred from "${previousStation}" to "${targetStation}".`,
            data: {
                id: officer._id,
                name: officer.name,
                badgeNumber: officer.badgeNumber,
                previousStation,
                currentStation: officer.policeStation,
                effectiveDate: effectiveDate || new Date().toISOString()
            }
        });
    } catch (error) {
        console.error('[transferOfficerStation] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to execute station transfer',
            error: error.message
        });
    }
};

// @desc    Admin-Assisted Credential / PIN Reset
// @route   POST /api/admin/officers/:id/reset-credentials
// @access  Private (Super Admin Only)
const resetOfficerCredentials = async (req, res) => {
    try {
        const { id } = req.params;
        const { newPassword } = req.body;

        if (!newPassword || newPassword.length < 6) {
            return res.status(HTTP.BAD_REQUEST).json({
                success: false,
                message: 'New password / PIN must be at least 6 characters.'
            });
        }

        const officer = await Police.findById(id);
        if (!officer) {
            return res.status(HTTP.NOT_FOUND).json({
                success: false,
                message: 'Police officer not found'
            });
        }

        const salt = await bcrypt.genSalt(10);
        officer.password = await bcrypt.hash(newPassword, salt);
        officer.appState = 'LOGGED_OUT';
        officer.fcmToken = null;
        await officer.save();

        res.status(HTTP.OK).json({
            success: true,
            message: `Credentials for Officer ${officer.name} (Badge: ${officer.badgeNumber}) reset successfully. Mobile terminal forced logout applied.`,
            data: {
                id: officer._id,
                name: officer.name,
                badgeNumber: officer.badgeNumber
            }
        });
    } catch (error) {
        console.error('[resetOfficerCredentials] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to reset officer credentials',
            error: error.message
        });
    }
};

// @desc    Export Officers Roster Dataset to CSV or PDF format
// @route   GET /api/admin/officers/export
// @access  Private (Admin)
const exportOfficers = async (req, res) => {
    try {
        const { search, station, position, status, format = 'csv' } = req.query;

        let query = {};

        if (search && search.trim() !== '') {
            const searchRegex = { $regex: search.trim(), $options: 'i' };
            query.$or = [
                { name: searchRegex },
                { badgeNumber: searchRegex },
                { email: searchRegex },
                { nic: searchRegex },
                { phone: searchRegex },
                { policeStation: searchRegex }
            ];
        }

        if (station && station !== 'ALL') query.policeStation = station;
        if (position && position !== 'ALL') query.position = position;
        if (status && status !== 'ALL') {
            query.isActive = status === 'ACTIVE';
        }

        const officers = await Police.find(query).sort({ policeStation: 1, position: 1, name: 1 }).lean();

        // ── Format = PDF ──────────────────────────────────────────────────────────
        if (format === 'pdf') {
            const PDFDocument = require('pdfkit-table');
            const doc = new PDFDocument({
                margin: 40,
                size: 'A4',
                info: {
                    Title: 'Sri Lanka Police - Officer Roster Directory',
                    Author: 'e-Fine SL Traffic Enforcement Authority'
                }
            });

            const buffers = [];
            doc.on('data', b => buffers.push(b));

            const totalOfficersCount = officers.length;
            const activeOfficersCount = officers.filter(o => o.isActive).length;
            const stationsCount = new Set(officers.map(o => o.policeStation)).size;

            PdfReportService.buildHeader(doc, {
                title: 'Police Officer Directory & Personnel List',
                subtitle: 'Official Sri Lanka Traffic Police Personnel Registry',
                dateRange: `Station: ${station || 'All Stations'} | Rank: ${position || 'All Ranks'}`
            });

            PdfReportService.buildKPICards(doc, [
                { label: 'Total Officers', value: totalOfficersCount.toString(), subtext: 'Total Personnel', color: '#2563EB' },
                { label: 'Active Personnel', value: activeOfficersCount.toString(), subtext: 'Active Duty', color: '#16A34A' },
                { label: 'Stations Covered', value: stationsCount.toString(), subtext: 'Command Divisions', color: '#9333EA' }
            ]);

            doc.moveDown(1.5);

            const table = {
                title: 'Police Officer Personnel Directory',
                headers: ['Badge No', 'Officer Name', 'Rank / Position', 'Station', 'Contact Phone', 'NIC', 'Status'],
                rows: officers.map(o => [
                    o.badgeNumber || 'N/A',
                    o.name || 'N/A',
                    o.position || 'Constable',
                    o.policeStation || 'Unassigned',
                    o.phone || 'N/A',
                    o.nic || 'N/A',
                    o.isActive ? 'ACTIVE' : 'SUSPENDED'
                ])
            };

            await doc.table(table, {
                prepareHeader: () => doc.font('Helvetica-Bold').fontSize(8),
                prepareRow: (row, indexColumn, indexRow, rect, rowHeight) => {
                    doc.font('Helvetica').fontSize(7.5);
                }
            });

            PdfReportService.buildFooter(doc, 'e-Fine SL • Official Police Officer Personnel Directory');
            doc.end();

            return new Promise((resolve) => {
                doc.on('end', () => {
                    const pdfData = Buffer.concat(buffers);
                    res.setHeader('Content-Type', 'application/pdf');
                    res.setHeader('Content-Disposition', `attachment; filename="eFine-Officer-List-${new Date().toISOString().slice(0, 10)}.pdf"`);
                    res.status(HTTP.OK).send(pdfData);
                    resolve();
                });
            });
        }

        // ── Format = CSV ──────────────────────────────────────────────────────────
        const headers = ['Badge Number', 'Full Name', 'Position / Rank', 'Police Station', 'NIC Number', 'Contact Phone', 'Email Address', 'Account Status', 'Live Presence State', 'Last Login Time'];
        const rows = officers.map(o => [
            `"${o.badgeNumber || ''}"`,
            `"${(o.name || '').replace(/"/g, '""')}"`,
            `"${o.position || ''}"`,
            `"${o.policeStation || ''}"`,
            `"${o.nic || ''}"`,
            `"${o.phone || ''}"`,
            `"${o.email || ''}"`,
            `"${o.isActive ? 'ACTIVE' : 'SUSPENDED'}"`,
            `"${o.appState || 'LOGGED_OUT'}"`,
            `"${o.lastLoginTime ? new Date(o.lastLoginTime).toISOString() : 'N/A'}"`
        ]);

        const csvContent = [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
        const fileName = `eFine-Officer-List-${new Date().toISOString().slice(0, 10)}.csv`;

        res.setHeader('Content-Type', 'text/csv');
        res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
        return res.status(HTTP.OK).send(csvContent);
    } catch (error) {
        console.error('[exportOfficers] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to export officer directory',
            error: error.message
        });
    }
};

// @desc    Safe Delete Police Officer
// @route   DELETE /api/admin/officers/:id
// @access  Private (Super Admin Only)
const deleteOfficer = async (req, res) => {
    try {
        const { id } = req.params;
        const officer = await Police.findById(id);

        if (!officer) {
            return res.status(HTTP.NOT_FOUND).json({
                success: false,
                message: 'Police officer not found'
            });
        }

        // Check if officer has issued existing fines
        const issuedFinesCount = await IssuedFine.countDocuments({ policeOfficerId: officer.badgeNumber });

        if (issuedFinesCount > 0) {
            // Soft delete / suspend instead of destroying historical records
            officer.isActive = false;
            officer.appState = 'LOGGED_OUT';
            officer.fcmToken = null;
            await officer.save();

            return res.status(HTTP.OK).json({
                success: true,
                message: `Officer ${officer.name} has issued ${issuedFinesCount} historical fines. Account has been safely SUSPENDED and deactivated to preserve legal audit records.`,
                isSoftDeleted: true
            });
        }

        await officer.deleteOne();

        res.status(HTTP.OK).json({
            success: true,
            message: `Officer ${officer.name} (Badge: ${officer.badgeNumber}) permanently removed from database.`,
            isSoftDeleted: false
        });
    } catch (error) {
        console.error('[deleteOfficer] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to delete officer',
            error: error.message
        });
    }
};

module.exports = {
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
};
