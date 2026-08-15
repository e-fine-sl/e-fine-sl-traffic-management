const IssuedFine = require('../models/issuedFineModel');
const Offense = require('../models/offenseModel');
const Driver = require('../models/driverModel');
const Police = require('../models/policeModel');
const { HTTP, PAYMENT } = require('../config/constants');
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

// @desc    Get all issued fines with multi-dimensional filtering, search, sorting & pagination
// @route   GET /api/admin/fines
// @access  Private (Admin)
const getAllFines = async (req, res) => {
    try {
        const page = parseInt(req.query.page, 10) || 1;
        const limit = parseInt(req.query.limit, 10) || 15;
        const search = req.query.search ? req.query.search.trim() : '';
        const status = req.query.status ? req.query.status.toUpperCase() : 'ALL';
        const offenseId = req.query.offenseId || 'ALL';
        const policeStation = req.query.policeStation || 'ALL';
        const startDate = req.query.startDate;
        const endDate = req.query.endDate;
        const sortBy = req.query.sortBy || 'date';
        const sortOrder = req.query.sortOrder === 'asc' ? 1 : -1;

        const skip = (page - 1) * limit;

        // Build Query
        const query = {};

        // Status Filter
        if (status && status !== 'ALL') {
            if (status === 'UNPAID') {
                query.status = { $in: ['UNPAID', 'Unpaid', 'PENDING', 'Pending'] };
            } else {
                query.status = status;
            }
        }

        // Offense Filter
        if (offenseId && offenseId !== 'ALL') {
            query.offenseId = offenseId;
        }

        // Police Station Filter
        if (policeStation && policeStation !== 'ALL') {
            query.policeStation = policeStation;
        }

        // Date Range Filter
        if (startDate || endDate) {
            query.date = {};
            if (startDate) {
                const s = new Date(startDate);
                s.setHours(0, 0, 0, 0);
                query.date.$gte = s;
            }
            if (endDate) {
                const e = new Date(endDate);
                e.setHours(23, 59, 59, 999);
                query.date.$lte = e;
            }
        }

        // Search Filter
        if (search) {
            query.$or = [
                { licenseNumber: { $regex: search, $options: 'i' } },
                { vehicleNumber: { $regex: search, $options: 'i' } },
                { offenseName: { $regex: search, $options: 'i' } },
                { place: { $regex: search, $options: 'i' } },
                { policeStation: { $regex: search, $options: 'i' } },
                { policeOfficerId: { $regex: search, $options: 'i' } },
                { paymentId: { $regex: search, $options: 'i' } }
            ];
        }

        const sortOptions = {};
        sortOptions[sortBy] = sortOrder;

        const [fines, total] = await Promise.all([
            IssuedFine.find(query)
                .populate('offenseId', 'offenseName sectionOfAct demeritPoints category')
                .sort(sortOptions)
                .skip(skip)
                .limit(limit)
                .lean(),
            IssuedFine.countDocuments(query)
        ]);

        res.status(HTTP.OK).json({
            success: true,
            data: fines,
            total,
            page,
            pages: Math.ceil(total / limit) || 1,
            limit,
            count: fines.length
        });

    } catch (error) {
        console.error('[getAllFines] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to retrieve traffic fines directory',
            error: error.message
        });
    }
};

// @desc    Get executive KPI metrics for fines & citations
// @route   GET /api/admin/fines/metrics
// @access  Private (Admin)
const getFineMetrics = async (req, res) => {
    try {
        const [
            totalAgg,
            statusBreakdown
        ] = await Promise.all([
            IssuedFine.aggregate([
                {
                    $group: {
                        _id: null,
                        totalCount: { $sum: 1 },
                        totalAmount: { $sum: '$amount' },
                        paidCount: {
                            $sum: {
                                $cond: [{ $eq: ['$status', 'PAID'] }, 1, 0]
                            }
                        },
                        paidAmount: {
                            $sum: {
                                $cond: [{ $eq: ['$status', 'PAID'] }, '$amount', 0]
                            }
                        },
                        unpaidCount: {
                            $sum: {
                                $cond: [{ $in: ['$status', ['UNPAID', 'Unpaid', 'PENDING', 'Pending']] }, 1, 0]
                            }
                        },
                        unpaidAmount: {
                            $sum: {
                                $cond: [{ $in: ['$status', ['UNPAID', 'Unpaid', 'PENDING', 'Pending']] }, '$amount', 0]
                            }
                        },
                        disputedCount: {
                            $sum: {
                                $cond: [{ $eq: ['$status', 'DISPUTED'] }, 1, 0]
                            }
                        },
                        refundedCount: {
                            $sum: {
                                $cond: [{ $eq: ['$status', 'REFUNDED'] }, 1, 0]
                            }
                        }
                    }
                }
            ]),
            IssuedFine.aggregate([
                { $group: { _id: '$status', count: { $sum: 1 }, totalAmount: { $sum: '$amount' } } }
            ])
        ]);

        const stats = totalAgg.length > 0 ? totalAgg[0] : {
            totalCount: 0,
            totalAmount: 0,
            paidCount: 0,
            paidAmount: 0,
            unpaidCount: 0,
            unpaidAmount: 0,
            disputedCount: 0,
            refundedCount: 0
        };

        const collectionRate = stats.totalAmount > 0 
            ? parseFloat(((stats.paidAmount / stats.totalAmount) * 100).toFixed(1))
            : 0;

        res.status(HTTP.OK).json({
            success: true,
            data: {
                totalFines: stats.totalCount,
                totalAmount: stats.totalAmount,
                paidFines: stats.paidCount,
                paidAmount: stats.paidAmount,
                unpaidFines: stats.unpaidCount,
                unpaidAmount: stats.unpaidAmount,
                disputedFines: stats.disputedCount,
                refundedFines: stats.refundedCount,
                collectionRate,
                statusBreakdown
            }
        });

    } catch (error) {
        console.error('[getFineMetrics] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to calculate fine metrics',
            error: error.message
        });
    }
};

// @desc    Get deep fine citation record with driver, officer & violation details
// @route   GET /api/admin/fines/:id
// @access  Private (Admin)
const getFineById = async (req, res) => {
    try {
        const fine = await IssuedFine.findById(req.params.id)
            .populate('offenseId', 'offenseName sectionOfAct demeritPoints amount category description')
            .lean();

        if (!fine) {
            return res.status(HTTP.NOT_FOUND).json({
                success: false,
                message: 'Traffic citation not found'
            });
        }

        // Parallel lookup of Driver and Police Officer profile
        const [driver, officer] = await Promise.all([
            Driver.findOne({ licenseNumber: fine.licenseNumber }).select('-password').lean(),
            Police.findOne({ badgeNumber: fine.policeOfficerId }).select('-password').lean()
        ]);

        res.status(HTTP.OK).json({
            success: true,
            data: {
                ...fine,
                driverDetails: driver ? {
                    id: driver._id,
                    name: driver.name,
                    nic: driver.nic,
                    phone: driver.phone,
                    email: driver.email,
                    demeritPoints: driver.demeritPoints,
                    demeritLevel: driver.demeritLevel,
                    licenseStatus: driver.licenseStatus,
                    profileImage: driver.profileImage
                } : null,
                officerDetails: officer ? {
                    id: officer._id,
                    name: officer.name,
                    badgeNumber: officer.badgeNumber,
                    policeStation: officer.policeStation,
                    position: officer.position,
                    phone: officer.phone,
                    email: officer.email
                } : null
            }
        });

    } catch (error) {
        console.error('[getFineById] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to retrieve citation record',
            error: error.message
        });
    }
};

// @desc    Manual Court / Admin Traffic Citation Registration
// @route   POST /api/admin/fines
// @access  Private (Admin Officer, Super Admin)
const createFine = async (req, res) => {
    try {
        const {
            licenseNumber,
            vehicleNumber,
            offenseId,
            place,
            policeStation,
            policeOfficerId,
            date,
            notes
        } = req.body;

        if (!licenseNumber || !vehicleNumber || !offenseId || !place) {
            return res.status(HTTP.BAD_REQUEST).json({
                success: false,
                message: 'Please provide all required citation fields (License, Vehicle, Offense, Place)'
            });
        }

        // Validate Offense
        const offense = await Offense.findById(offenseId);
        if (!offense) {
            return res.status(HTTP.BAD_REQUEST).json({
                success: false,
                message: 'Selected traffic offense does not exist in master data'
            });
        }

        // Check Driver
        const driver = await Driver.findOne({ licenseNumber: licenseNumber.toUpperCase().trim() });
        const demeritDeduction = offense.demeritPoints || 0;

        const newFine = await IssuedFine.create({
            licenseNumber: licenseNumber.toUpperCase().trim(),
            vehicleNumber: vehicleNumber.toUpperCase().trim(),
            offenseId: offense._id,
            offenseName: offense.offenseName,
            amount: offense.amount,
            place: place.trim(),
            policeStation: policeStation || 'Court Administration',
            policeOfficerId: policeOfficerId || (req.user?.badgeNumber || req.user?.name || 'ADMIN-DESK'),
            status: 'UNPAID',
            demeritPoints: demeritDeduction,
            date: date ? new Date(date) : new Date(),
            paymentNotes: notes ? notes.trim() : undefined
        });

        // Deduct demerit points from driver if driver exists
        if (driver && demeritDeduction > 0) {
            const currentPoints = driver.demeritPoints ?? 24;
            const updatedPoints = Math.max(0, currentPoints - demeritDeduction);
            driver.demeritPoints = updatedPoints;
            driver.demeritLevel = calculateDemeritLevel(updatedPoints);
            driver.ratingScore = parseFloat(((updatedPoints / 24) * 5.0).toFixed(1));
            driver.lastOffenseDate = new Date();
            await driver.save();
        }

        // Dispatch FCM Push notification to Driver's Mobile App
        if (driver && driver.fcmToken) {
            try {
                const { sendToToken } = require('../services/fcmService');
                await sendToToken(driver.fcmToken, {
                    title: 'New Traffic Citation Issued',
                    body: `Citation #${newFine._id.toString().slice(-8).toUpperCase()} for "${newFine.offenseName}" (LKR ${newFine.amount.toLocaleString()}) has been issued at ${newFine.place}.`,
                    data: {
                        type: 'NEW_FINE_ISSUED',
                        fineId: newFine._id.toString(),
                        licenseNumber: newFine.licenseNumber,
                        amount: String(newFine.amount),
                        offenseName: newFine.offenseName,
                        place: newFine.place
                    }
                });
            } catch (fcmError) {
                console.error('[createFine] FCM notification error:', fcmError);
            }
        }

        res.status(HTTP.CREATED).json({
            success: true,
            message: `Traffic citation #${newFine._id.toString().slice(-8).toUpperCase()} issued successfully`,
            data: newFine
        });

    } catch (error) {
        console.error('[createFine] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to issue citation',
            error: error.message
        });
    }
};

// @desc    Update Fine Status & Resolve Disputes / Administrative Overrides
// @route   PATCH /api/admin/fines/:id/status
// @access  Private (Admin Officer, Super Admin)
const updateFineStatus = async (req, res) => {
    try {
        const { status, notes, restoreDemerit } = req.body;

        if (!status || !['PAID', 'UNPAID', 'DISPUTED', 'REFUNDED'].includes(status.toUpperCase())) {
            return res.status(HTTP.BAD_REQUEST).json({
                success: false,
                message: 'Invalid status. Must be PAID, UNPAID, DISPUTED, or REFUNDED.'
            });
        }

        const fine = await IssuedFine.findById(req.params.id);
        if (!fine) {
            return res.status(HTTP.NOT_FOUND).json({
                success: false,
                message: 'Citation record not found'
            });
        }

        const newStatus = status.toUpperCase();
        fine.status = newStatus;

        if (notes) {
            fine.paymentNotes = `${fine.paymentNotes ? fine.paymentNotes + ' | ' : ''}${notes} (by ${req.user?.name || req.user?.email || 'Admin'})`;
        }

        if (newStatus === 'PAID') {
            fine.paidAt = new Date();
        } else if (newStatus === 'DISPUTED') {
            fine.disputeReason = notes || 'Flagged under administrative investigation';
        }

        await fine.save();

        // Optional demerit points restoration if citation was dismissed or waived
        if (restoreDemerit && fine.demeritPoints > 0) {
            const driver = await Driver.findOne({ licenseNumber: fine.licenseNumber });
            if (driver) {
                const currentPoints = driver.demeritPoints ?? 24;
                const restoredPoints = Math.min(24, currentPoints + fine.demeritPoints);
                driver.demeritPoints = restoredPoints;
                driver.demeritLevel = calculateDemeritLevel(restoredPoints);
                driver.ratingScore = parseFloat(((restoredPoints / 24) * 5.0).toFixed(1));
                await driver.save();
            }
        }

        // Dispatch push notification to driver if fcmToken present
        try {
            const driver = await Driver.findOne({ licenseNumber: fine.licenseNumber });
            if (driver && driver.fcmToken) {
                const { sendToToken } = require('../services/fcmService');
                let notifTitle = 'Traffic Citation Status Updated';
                let notifBody = `Your citation #${fine._id.toString().slice(-8).toUpperCase()} status is now ${newStatus}.`;
                if (newStatus === 'REFUNDED') {
                    notifTitle = 'Traffic Fine Dismissed / Refunded';
                    notifBody = `Citation #${fine._id.toString().slice(-8).toUpperCase()} has been overturned/dismissed. ${restoreDemerit ? 'Demerit points restored.' : ''}`;
                } else if (newStatus === 'DISPUTED') {
                    notifTitle = 'Traffic Citation Dispute Under Review';
                    notifBody = `Citation #${fine._id.toString().slice(-8).toUpperCase()} has been flagged under administrative review.`;
                }

                await sendToToken(driver.fcmToken, {
                    title: notifTitle,
                    body: notifBody,
                    data: {
                        type: 'FINE_STATUS_UPDATED',
                        fineId: fine._id.toString(),
                        status: newStatus
                    }
                });
            }
        } catch (fcmErr) {
            console.error('[updateFineStatus] FCM error:', fcmErr);
        }

        res.status(HTTP.OK).json({
            success: true,
            message: `Citation #${fine._id.toString().slice(-8).toUpperCase()} updated to ${newStatus}`,
            data: fine
        });

    } catch (error) {
        console.error('[updateFineStatus] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to update citation status',
            error: error.message
        });
    }
};

// @desc    Export filtered traffic citations (CSV / PDF)
// @route   GET /api/admin/fines/export
// @access  Private (Admin)
const exportFines = async (req, res) => {
    try {
        const { search, status, policeStation, startDate, endDate, format = 'csv' } = req.query;

        const query = {};

        if (status && status !== 'ALL') {
            if (status === 'UNPAID') {
                query.status = { $in: ['UNPAID', 'Unpaid', 'PENDING', 'Pending'] };
            } else {
                query.status = status;
            }
        }

        if (policeStation && policeStation !== 'ALL') {
            query.policeStation = policeStation;
        }

        if (startDate || endDate) {
            query.date = {};
            if (startDate) {
                const s = new Date(startDate);
                s.setHours(0, 0, 0, 0);
                query.date.$gte = s;
            }
            if (endDate) {
                const e = new Date(endDate);
                e.setHours(23, 59, 59, 999);
                query.date.$lte = e;
            }
        }

        if (search) {
            query.$or = [
                { licenseNumber: { $regex: search, $options: 'i' } },
                { vehicleNumber: { $regex: search, $options: 'i' } },
                { offenseName: { $regex: search, $options: 'i' } },
                { place: { $regex: search, $options: 'i' } },
                { policeOfficerId: { $regex: search, $options: 'i' } }
            ];
        }

        const fines = await IssuedFine.find(query).sort({ date: -1 }).lean();

        // ── Format = PDF ──────────────────────────────────────────────────────────
        if (format === 'pdf') {
            const PDFDocument = require('pdfkit-table');
            const doc = new PDFDocument({
                margin: 40,
                size: 'A4',
                info: {
                    Title: 'Traffic Citations & Fines Ledger',
                    Author: 'e-Fine SL Traffic Enforcement Authority'
                }
            });

            const buffers = [];
            doc.on('data', b => buffers.push(b));

            const totalFinesCount = fines.length;
            const totalFinesAmount = fines.reduce((sum, f) => sum + (f.amount || 0), 0);
            const paidFinesCount = fines.filter(f => f.status === 'PAID').length;
            const paidFinesAmount = fines.filter(f => f.status === 'PAID').reduce((sum, f) => sum + (f.amount || 0), 0);

            PdfReportService.buildHeader(doc, {
                title: 'Traffic Citations & Violations Ledger',
                subtitle: 'Official Sri Lanka Traffic Police Enforcement Record',
                dateRange: `Status: ${status || 'All'} | Period: ${startDate || 'Earliest'} to ${endDate || 'Latest'}`
            });

            PdfReportService.buildKPICards(doc, [
                { label: 'Total Citations', value: totalFinesCount.toString(), subtext: 'Tickets Issued', color: '#2563EB' },
                { label: 'Imposed Value', value: `LKR ${totalFinesAmount.toLocaleString()}`, subtext: 'Gross Penalty', color: '#6B7280' },
                { label: 'Settled Treasury', value: `LKR ${paidFinesAmount.toLocaleString()}`, subtext: `${paidFinesCount} Paid Fines`, color: '#16A34A' }
            ]);

            doc.moveDown(1.5);

            const table = {
                title: 'Enforcement Citation Listing',
                headers: ['Date', 'License No', 'Vehicle Plate', 'Offense', 'Location', 'Amount', 'Status'],
                rows: fines.slice(0, 500).map(f => [
                    f.date ? new Date(f.date).toLocaleDateString() : 'N/A',
                    f.licenseNumber || 'N/A',
                    f.vehicleNumber || 'N/A',
                    f.offenseName || 'Violation',
                    f.place || 'N/A',
                    `LKR ${(f.amount || 0).toLocaleString()}`,
                    f.status || 'UNPAID'
                ])
            };

            await doc.table(table, {
                prepareHeader: () => doc.font('Helvetica-Bold').fontSize(8),
                prepareRow: (row, indexColumn, indexRow, rect, rowHeight) => {
                    doc.font('Helvetica').fontSize(7.5);
                }
            });

            PdfReportService.buildFooter(doc, 'e-Fine SL • Official Traffic Citations & Violations Ledger');
            doc.end();

            return new Promise((resolve) => {
                doc.on('end', () => {
                    const pdfData = Buffer.concat(buffers);
                    res.setHeader('Content-Type', 'application/pdf');
                    res.setHeader('Content-Disposition', `attachment; filename="eFine-Citations-Ledger-${new Date().toISOString().slice(0, 10)}.pdf"`);
                    res.status(HTTP.OK).send(pdfData);
                    resolve();
                });
            });
        }

        // ── Format = CSV ──────────────────────────────────────────────────────────
        const headers = ['Citation ID', 'Date', 'License Number', 'Vehicle Plate', 'Offense Name', 'Location', 'Police Station', 'Issuing Officer', 'Amount (LKR)', 'Status', 'Payment Reference', 'Paid Timestamp'];
        const rows = fines.map(f => [
            `"${f._id.toString()}"`,
            `"${f.date ? new Date(f.date).toISOString() : 'N/A'}"`,
            `"${f.licenseNumber || ''}"`,
            `"${f.vehicleNumber || ''}"`,
            `"${(f.offenseName || '').replace(/"/g, '""')}"`,
            `"${(f.place || '').replace(/"/g, '""')}"`,
            `"${f.policeStation || ''}"`,
            `"${f.policeOfficerId || ''}"`,
            `"${f.amount || 0}"`,
            `"${f.status || 'UNPAID'}"`,
            `"${f.paymentId || ''}"`,
            `"${f.paidAt ? new Date(f.paidAt).toISOString() : 'N/A'}"`
        ]);

        const csvContent = [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
        const fileName = `eFine-Citations-Ledger-${new Date().toISOString().slice(0, 10)}.csv`;

        res.setHeader('Content-Type', 'text/csv');
        res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
        return res.status(HTTP.OK).send(csvContent);

    } catch (error) {
        console.error('[exportFines] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to export fines directory',
            error: error.message
        });
    }
};

// @desc    Safe Cancellation / Deletion of Fine
// @route   DELETE /api/admin/fines/:id
// @access  Private (Super Admin Only)
const deleteFine = async (req, res) => {
    try {
        const fine = await IssuedFine.findById(req.params.id);

        if (!fine) {
            return res.status(HTTP.NOT_FOUND).json({
                success: false,
                message: 'Fine not found'
            });
        }

        // If paid, prohibit deletion to prevent financial gap
        if (fine.status === 'PAID') {
            return res.status(HTTP.BAD_REQUEST).json({
                success: false,
                message: 'Cannot delete a settled/paid citation. Please use the refund or dispute resolution mechanism instead.'
            });
        }

        await fine.deleteOne();

        res.status(HTTP.OK).json({
            success: true,
            message: `Citation #${fine._id.toString().slice(-8).toUpperCase()} has been deleted from the registry.`
        });

    } catch (error) {
        console.error('[deleteFine] Error:', error);
        res.status(HTTP.SERVER_ERROR).json({
            success: false,
            message: 'Failed to delete fine',
            error: error.message
        });
    }
};

module.exports = {
    getAllFines,
    getFineMetrics,
    getFineById,
    createFine,
    updateFineStatus,
    exportFines,
    deleteFine
};
