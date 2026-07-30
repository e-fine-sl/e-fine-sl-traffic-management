const ReportRepository = require('../repositories/reportRepository');
const PdfReportService = require('./pdfReportService');
const { PAYMENT } = require('../config/constants');

/**
 * ReportService - Business & Application Service Layer
 * Orchestrates business logic, calculations, date boundaries, and document formatting.
 */
class ReportService {

    /**
     * Pre-validate driver registration in database
     */
    static async verifyDriver(licenseNumber) {
        if (!licenseNumber || !licenseNumber.trim()) {
            throw { status: 400, message: 'Please provide a driving license number to search.' };
        }

        const driver = await ReportRepository.findDriverByLicense(licenseNumber.trim());

        if (!driver) {
            throw {
                status: 404,
                message: `No registered driver found in database matching License Number: ${licenseNumber.toUpperCase()}`
            };
        }

        const offenseCount = await ReportRepository.countDriverFines(driver.licenseNumber);

        return {
            name: driver.name,
            licenseNumber: driver.licenseNumber,
            nic: driver.nic,
            email: driver.email,
            phone: driver.phone,
            licenseStatus: driver.licenseStatus || 'ACTIVE',
            demeritPoints: driver.demeritPoints !== undefined ? driver.demeritPoints : 24,
            demeritLevel: driver.demeritLevel || 'EXCELLENT',
            ratingScore: driver.ratingScore || 5.0,
            offenseCount
        };
    }

    /**
     * Build date range using IST boundaries (+05:30)
     */
    static buildDateRange({ periodType = 'monthly', month, year, startDate: customStart, endDate: customEnd }) {
        const pad = (n) => String(n).padStart(2, '0');
        let startDate, endDate, periodLabel;

        if (periodType === 'annual') {
            if (!year) throw { status: 400, message: 'Please select a year for annual report.' };
            startDate = new Date(`${year}-01-01T00:00:00.000+05:30`);
            endDate = new Date(`${year}-12-31T23:59:59.999+05:30`);
            periodLabel = `Annual Audit (${year})`;
        } else if (periodType === 'custom') {
            if (!customStart || !customEnd) throw { status: 400, message: 'Please select start and end dates.' };
            startDate = new Date(customStart);
            endDate = new Date(customEnd);
            endDate.setHours(23, 59, 59, 999);
            periodLabel = `Custom Range (${new Date(customStart).toLocaleDateString()} to ${new Date(customEnd).toLocaleDateString()})`;
        } else {
            if (!month || !year) throw { status: 400, message: 'Please provide month and year' };
            startDate = new Date(`${year}-${pad(month)}-01T00:00:00.000+05:30`);
            const lastDay = new Date(year, month, 0).getDate();
            endDate = new Date(`${year}-${pad(month)}-${pad(lastDay)}T23:59:59.999+05:30`);
            periodLabel = `Monthly Report (${pad(month)}/${year})`;
        }

        return { startDate, endDate, periodLabel };
    }

    /**
     * Generate Fine Audit Report
     */
    static async generateFinesReport({ params, format, adminInfo }) {
        const { startDate, endDate, periodLabel } = this.buildDateRange(params);
        const { province, district } = params;

        const query = { date: { $gte: startDate, $lte: endDate } };
        let regionText = 'Whole Country (All Island)';

        if (province && province !== 'ALL') {
            query.province = { $regex: new RegExp(province, 'i') };
            regionText = `Province: ${province}`;
        }
        if (district && district !== 'ALL') {
            query.district = { $regex: new RegExp(district, 'i') };
            regionText += (province && province !== 'ALL') ? `, District: ${district}` : `District: ${district}`;
        }

        const fines = await ReportRepository.findFines(query);

        const totalFines = fines.length;
        const paidFines = fines.filter(f => f.status === PAYMENT.STATUS.PAID).length;
        const unpaidFines = fines.filter(f => f.status === PAYMENT.STATUS.UNPAID).length;
        const totalAmount = fines.reduce((sum, f) => sum + (f.amount || 0), 0);
        const paidAmount = fines.filter(f => f.status === PAYMENT.STATUS.PAID).reduce((sum, f) => sum + (f.amount || 0), 0);

        const offenseBreakdown = {};
        fines.forEach(fine => {
            const offenseName = fine.offenseName || fine.offenseId?.offenseName || 'General Traffic Offense';
            if (!offenseBreakdown[offenseName]) {
                offenseBreakdown[offenseName] = { count: 0, amount: 0 };
            }
            offenseBreakdown[offenseName].count++;
            offenseBreakdown[offenseName].amount += (fine.amount || 0);
        });

        if (format === 'json') {
            return {
                type: 'json',
                data: {
                    periodLabel,
                    region: regionText,
                    summary: { totalFines, paidFines, unpaidFines, totalAmount, paidAmount, unpaidAmount: totalAmount - paidAmount },
                    offenseBreakdown,
                    fines
                }
            };
        }

        // PDF Generation
        const doc = PdfReportService.createDocument();
        const collectionRate = totalFines > 0 ? Math.round((paidFines / totalFines) * 100) : 0;

        PdfReportService.buildHeader(doc, {
            title: `Fine Audit Report — ${periodLabel}`,
            category: 'FINANCIAL & ENFORCEMENT AUDIT',
            adminInfo,
            reportId: `FAR-${Date.now().toString().slice(-6)}`,
            dateRange: `${regionText} | ${periodLabel}`
        });

        PdfReportService.buildKPICards(doc, [
            { label: 'Total Fines', value: totalFines.toString(), subtext: 'Total Violations', color: '#2563EB' },
            { label: 'Paid Fines', value: `${paidFines} (${collectionRate}%)`, subtext: 'Settled Fines', color: '#10B981' },
            { label: 'Total Value', value: `LKR ${totalAmount.toLocaleString()}`, subtext: 'Fine Liability', color: '#F59E0B' },
            { label: 'Collected Revenue', value: `LKR ${paidAmount.toLocaleString()}`, subtext: 'Realized Cash', color: '#10B981' }
        ]);

        PdfReportService.buildSectionHeader(doc, 'Offense Type Summary Breakdown');

        const table = {
            headers: ["Offense Description", "Violations Count", "Total Value (LKR)"],
            rows: Object.keys(offenseBreakdown).map(name => [
                name,
                offenseBreakdown[name].count.toString(),
                `LKR ${offenseBreakdown[name].amount.toLocaleString()}`
            ])
        };

        if (table.rows.length > 0) {
            await doc.table(table, {
                prepareHeader: () => doc.font("Helvetica-Bold").fontSize(9),
                prepareRow: () => doc.font("Helvetica").fontSize(9)
            });
        } else {
            doc.fontSize(9).fillColor('#64748B').text("No offenses recorded for this selected criteria.");
        }

        PdfReportService.buildFooter(doc);
        return { type: 'pdf', doc, filename: `Fines_Report_${Date.now()}.pdf` };
    }

    /**
     * Generate Payment Reconciliation Report
     */
    static async generatePaymentReport({ params, format, adminInfo }) {
        const { startDate, endDate, periodLabel } = this.buildDateRange(params);
        const { province, district } = params;

        const query = { paidAt: { $gte: startDate, $lte: endDate } };
        let regionText = 'Whole Country (All Island)';

        if (province && province !== 'ALL') {
            query.province = { $regex: new RegExp(province, 'i') };
            regionText = `Province: ${province}`;
        }
        if (district && district !== 'ALL') {
            query.district = { $regex: new RegExp(district, 'i') };
            regionText += (province && province !== 'ALL') ? `, District: ${district}` : `District: ${district}`;
        }

        const payments = await ReportRepository.findPayments(query);

        const totalPayments = payments.length;
        const totalRevenue = payments.reduce((sum, p) => sum + (p.amount || 0), 0);

        if (format === 'json') {
            return {
                type: 'json',
                data: {
                    periodLabel,
                    region: regionText,
                    summary: { totalPayments, totalRevenue },
                    payments
                }
            };
        }

        const doc = PdfReportService.createDocument();

        PdfReportService.buildHeader(doc, {
            title: 'Payment Reconciliation Summary',
            category: 'FINANCE & REVENUE RECONCILIATION',
            adminInfo,
            reportId: `PAY-${Date.now().toString().slice(-6)}`,
            dateRange: `${regionText} | ${periodLabel}`
        });

        PdfReportService.buildKPICards(doc, [
            { label: 'Total Transactions', value: totalPayments.toString(), subtext: 'Settled Receipts', color: '#10B981' },
            { label: 'Total Revenue', value: `LKR ${totalRevenue.toLocaleString()}`, subtext: 'Realized Revenue', color: '#2563EB' },
            { label: 'Average Fine Value', value: `LKR ${(totalPayments > 0 ? Math.round(totalRevenue / totalPayments) : 0).toLocaleString()}`, subtext: 'Per Transaction', color: '#F59E0B' }
        ]);

        PdfReportService.buildSectionHeader(doc, 'Settled Payment Log');

        const table = {
            headers: ["Payment Date", "Offense Description", "Driver License", "Amount (LKR)"],
            rows: payments.map(p => [
                p.paidAt ? new Date(p.paidAt).toLocaleDateString() : 'N/A',
                p.offenseName || p.offenseId?.offenseName || 'Traffic Offense',
                p.licenseNumber || 'N/A',
                `LKR ${(p.amount || 0).toLocaleString()}`
            ])
        };

        if (table.rows.length > 0) {
            await doc.table(table, {
                prepareHeader: () => doc.font("Helvetica-Bold").fontSize(9),
                prepareRow: () => doc.font("Helvetica").fontSize(9)
            });
        } else {
            doc.fontSize(9).fillColor('#64748B').text("No settled payments recorded for this criteria.");
        }

        PdfReportService.buildFooter(doc);
        return { type: 'pdf', doc, filename: `Payment_Report_${Date.now()}.pdf` };
    }

    /**
     * Generate Driver Violation Report (Individual / Nationwide Audit)
     */
    static async generateDriverReport({ params, format, adminInfo }) {
        const { licenseNumber, reportScope = 'individual', province, district } = params;

        if (reportScope === 'individual') {
            const driver = await this.verifyDriver(licenseNumber);
            const violations = await ReportRepository.findFines({ licenseNumber: driver.licenseNumber });
            const unpaidCount = violations.filter(v => v.status === PAYMENT.STATUS.UNPAID).length;

            if (format === 'json') {
                return { type: 'json', data: { driver, violations } };
            }

            const doc = PdfReportService.createDocument();

            PdfReportService.buildHeader(doc, {
                title: `Driver Violation Record`,
                category: 'CITIZEN ENFORCEMENT AUDIT',
                adminInfo,
                reportId: `DVR-${driver.licenseNumber}`,
                dateRange: `As of ${new Date().toLocaleDateString()}`
            });

            const statusColor = driver.licenseStatus === 'SUSPENDED' ? '#EF4444' : '#10B981';
            PdfReportService.buildKPICards(doc, [
                { label: 'Driver Name', value: driver.name, subtext: `License: ${driver.licenseNumber}`, color: '#2563EB' },
                { label: 'License Status', value: driver.licenseStatus || 'ACTIVE', subtext: `Level: ${driver.demeritLevel || 'GOOD'}`, color: statusColor },
                { label: 'Demerit Points', value: `${driver.demeritPoints} Pts`, subtext: 'Current Balance', color: '#F59E0B' },
                { label: 'Total Offenses', value: violations.length.toString(), subtext: `${unpaidCount} Unpaid`, color: '#EF4444' }
            ]);

            PdfReportService.buildSectionHeader(doc, 'Chronological Violation History');

            const table = {
                headers: ["Date", "Offense Description", "Location", "Amount (LKR)", "Status"],
                rows: violations.map(v => [
                    v.date ? new Date(v.date).toLocaleDateString() : 'N/A',
                    v.offenseName || v.offenseId?.offenseName || 'Traffic Offense',
                    v.place || 'Sri Lanka',
                    `LKR ${(v.amount || 0).toLocaleString()}`,
                    v.status || 'UNPAID'
                ])
            };

            if (table.rows.length > 0) {
                await doc.table(table, {
                    prepareHeader: () => doc.font("Helvetica-Bold").fontSize(9),
                    prepareRow: () => doc.font("Helvetica").fontSize(9)
                });
            } else {
                doc.fontSize(9).fillColor('#64748B').text("No violations recorded for this driver.");
            }

            PdfReportService.buildFooter(doc);
            return { type: 'pdf', doc, filename: `Driver_Violations_${driver.licenseNumber}.pdf` };
        }

        // Nationwide Audit
        let regionText = 'Whole Country (Nationwide Audit)';
        if (province && province !== 'ALL') regionText = `Province: ${province}`;
        if (district && district !== 'ALL') regionText += `, District: ${district}`;

        const dataset = await ReportRepository.getDriverAuditDataset();

        if (format === 'json') {
            return { type: 'json', data: { scope: reportScope, region: regionText, summary: dataset } };
        }

        const doc = PdfReportService.createDocument();

        PdfReportService.buildHeader(doc, {
            title: `Nationwide Driver Violation Audit`,
            category: 'NATIONAL DEMERIT & COMPLIANCE AUDIT',
            adminInfo,
            reportId: `NWA-${Date.now().toString().slice(-6)}`,
            dateRange: regionText
        });

        PdfReportService.buildKPICards(doc, [
            { label: 'Registered Drivers', value: dataset.allDrivers.length.toString(), subtext: 'Total Accounts', color: '#2563EB' },
            { label: 'Active Suspensions', value: dataset.totalSuspended.toString(), subtext: 'Suspended Licenses', color: '#EF4444' },
            { label: 'High-Risk Drivers', value: dataset.totalWarningOrDanger.toString(), subtext: 'Warning / Danger Level', color: '#F59E0B' },
            { label: 'Total Violations', value: dataset.totalFinesCount.toString(), subtext: 'System-wide Fines', color: '#10B981' }
        ]);

        PdfReportService.buildSectionHeader(doc, 'High-Risk & Penalized Driver Roster');

        const highRiskDrivers = dataset.allDrivers.filter(d => d.licenseStatus === 'SUSPENDED' || ['WARNING', 'DANGER', 'FAIR'].includes(d.demeritLevel));

        const table = {
            headers: ["Driver Name", "License Number", "Demerit Points", "Demerit Level", "Status"],
            rows: highRiskDrivers.map(d => [
                d.name,
                d.licenseNumber,
                `${d.demeritPoints !== undefined ? d.demeritPoints : 24} Pts`,
                d.demeritLevel || 'EXCELLENT',
                d.licenseStatus || 'ACTIVE'
            ])
        };

        if (table.rows.length > 0) {
            await doc.table(table, {
                prepareHeader: () => doc.font("Helvetica-Bold").fontSize(9),
                prepareRow: () => doc.font("Helvetica").fontSize(9)
            });
        } else {
            doc.fontSize(9).fillColor('#64748B').text("No high-risk or penalized drivers found for this audit scope.");
        }

        PdfReportService.buildFooter(doc);
        return { type: 'pdf', doc, filename: `Nationwide_Driver_Audit_${Date.now()}.pdf` };
    }

    /**
     * Generate Vehicle Citation History Report
     */
    static async generateVehicleReport({ params, format, adminInfo }) {
        const { vehicleNumber } = params;
        if (!vehicleNumber || !vehicleNumber.trim()) {
            throw { status: 400, message: 'Please provide vehicle registration number' };
        }

        const cleanVehicle = vehicleNumber.trim().toUpperCase();
        const fines = await ReportRepository.findFinesByVehicle(cleanVehicle);
        const totalFineValue = fines.reduce((sum, f) => sum + (f.amount || 0), 0);
        const unpaidFines = fines.filter(f => f.status === PAYMENT.STATUS.UNPAID).length;

        if (format === 'json') {
            return { type: 'json', data: { vehicleNumber: cleanVehicle, count: fines.length, totalFineValue, unpaidFines, fines } };
        }

        const doc = PdfReportService.createDocument();

        PdfReportService.buildHeader(doc, {
            title: `Vehicle Violation Audit Report`,
            category: 'VEHICLE REGISTRATION ENFORCEMENT',
            adminInfo,
            reportId: `VVR-${cleanVehicle}`,
            dateRange: `As of ${new Date().toLocaleDateString()}`
        });

        PdfReportService.buildKPICards(doc, [
            { label: 'Vehicle Number', value: cleanVehicle, subtext: 'License Plate ID', color: '#2563EB' },
            { label: 'Total Violations', value: fines.length.toString(), subtext: 'Offense Records', color: '#F59E0B' },
            { label: 'Total Value', value: `LKR ${totalFineValue.toLocaleString()}`, subtext: 'Combined Fines', color: '#EF4444' },
            { label: 'Unpaid Fines', value: unpaidFines.toString(), subtext: 'Pending Settlement', color: '#EF4444' }
        ]);

        PdfReportService.buildSectionHeader(doc, 'Vehicle Citation Log');

        const table = {
            headers: ["Date", "Offense Description", "Driver License", "Location", "Amount (LKR)", "Status"],
            rows: fines.map(v => [
                v.date ? new Date(v.date).toLocaleDateString() : 'N/A',
                v.offenseName || v.offenseId?.offenseName || 'Traffic Violation',
                v.licenseNumber || 'N/A',
                v.place || 'Sri Lanka',
                `LKR ${(v.amount || 0).toLocaleString()}`,
                v.status || 'UNPAID'
            ])
        };

        if (table.rows.length > 0) {
            await doc.table(table, {
                prepareHeader: () => doc.font("Helvetica-Bold").fontSize(8.5),
                prepareRow: () => doc.font("Helvetica").fontSize(8.5)
            });
        } else {
            doc.fontSize(9).fillColor('#64748B').text("No citation records found for this vehicle registration number.");
        }

        PdfReportService.buildFooter(doc);
        return { type: 'pdf', doc, filename: `Vehicle_Report_${cleanVehicle.replace(/\s+/g, '_')}.pdf` };
    }

    /**
     * Generate Police Officer Performance Report
     */
    static async generateOfficerReport({ params, format, adminInfo }) {
        const { policeOfficerId } = params;
        if (!policeOfficerId || !policeOfficerId.trim()) {
            throw { status: 400, message: 'Please provide Police Officer Badge Number / ID' };
        }

        const cleanOfficerId = policeOfficerId.trim();
        const fines = await ReportRepository.findFinesByOfficer(cleanOfficerId);

        const totalIssued = fines.length;
        const totalRevenue = fines.reduce((sum, f) => sum + (f.amount || 0), 0);
        const settledCount = fines.filter(f => f.status === PAYMENT.STATUS.PAID).length;

        if (format === 'json') {
            return { type: 'json', data: { policeOfficerId: cleanOfficerId, totalIssued, settledCount, totalRevenue, fines } };
        }

        const doc = PdfReportService.createDocument();

        PdfReportService.buildHeader(doc, {
            title: `Police Officer Enforcement Audit`,
            category: 'POLICE DEPARTMENT PERFORMANCE AUDIT',
            adminInfo,
            reportId: `OPA-${cleanOfficerId}`,
            dateRange: `As of ${new Date().toLocaleDateString()}`
        });

        const collectionRate = totalIssued > 0 ? Math.round((settledCount / totalIssued) * 100) : 0;
        PdfReportService.buildKPICards(doc, [
            { label: 'Officer Badge ID', value: cleanOfficerId, subtext: 'Police Officer', color: '#2563EB' },
            { label: 'Fines Issued', value: totalIssued.toString(), subtext: 'Citations Written', color: '#10B981' },
            { label: 'Settlement Rate', value: `${settledCount} (${collectionRate}%)`, subtext: 'Paid Fines', color: '#F59E0B' },
            { label: 'Total Revenue Value', value: `LKR ${totalRevenue.toLocaleString()}`, subtext: 'Enforcement Value', color: '#10B981' }
        ]);

        PdfReportService.buildSectionHeader(doc, 'Officer Issued Citation Roster');

        const table = {
            headers: ["Date", "Offense Description", "Vehicle", "Driver License", "Amount (LKR)", "Status"],
            rows: fines.map(v => [
                v.date ? new Date(v.date).toLocaleDateString() : 'N/A',
                v.offenseName || v.offenseId?.offenseName || 'Traffic Citation',
                v.vehicleNumber || 'N/A',
                v.licenseNumber || 'N/A',
                `LKR ${(v.amount || 0).toLocaleString()}`,
                v.status || 'UNPAID'
            ])
        };

        if (table.rows.length > 0) {
            await doc.table(table, {
                prepareHeader: () => doc.font("Helvetica-Bold").fontSize(8.5),
                prepareRow: () => doc.font("Helvetica").fontSize(8.5)
            });
        } else {
            doc.fontSize(9).fillColor('#64748B').text("No citation logs recorded for this police officer badge ID.");
        }

        PdfReportService.buildFooter(doc);
        return { type: 'pdf', doc, filename: `Officer_Performance_${cleanOfficerId}.pdf` };
    }
}

module.exports = ReportService;
