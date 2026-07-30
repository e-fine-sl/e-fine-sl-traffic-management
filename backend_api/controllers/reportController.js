const ReportService = require('../services/reportService');
const { HTTP } = require('../config/constants');

/**
 * ReportController - Presentation / HTTP Layer
 * Handles HTTP requests, input parameter validation, and PDF streaming.
 */
class ReportController {

    /**
     * Pre-validate driver existence before generating report
     */
    static async verifyDriver(req, res) {
        try {
            const { licenseNumber } = req.body;
            const driver = await ReportService.verifyDriver(licenseNumber);
            res.status(HTTP.OK).json({
                success: true,
                message: 'Driver found and verified',
                driver
            });
        } catch (error) {
            const status = error.status || HTTP.SERVER_ERROR;
            res.status(status).json({ success: false, message: error.message || 'Server error verifying driver' });
        }
    }

    /**
     * Pre-validate vehicle existence before generating report
     */
    static async verifyVehicle(req, res) {
        try {
            const { vehicleNumber } = req.body;
            const vehicle = await ReportService.verifyVehicle(vehicleNumber);
            res.status(HTTP.OK).json({
                success: true,
                message: 'Vehicle found and verified',
                vehicle
            });
        } catch (error) {
            const status = error.status || HTTP.SERVER_ERROR;
            res.status(status).json({ success: false, message: error.message || 'Server error verifying vehicle' });
        }
    }

    /**
     * Pre-validate police officer existence before generating report
     */
    static async verifyOfficer(req, res) {
        try {
            const { policeOfficerId } = req.body;
            const officer = await ReportService.verifyOfficer(policeOfficerId);
            res.status(HTTP.OK).json({
                success: true,
                message: 'Officer found and verified',
                officer
            });
        } catch (error) {
            const status = error.status || HTTP.SERVER_ERROR;
            res.status(status).json({ success: false, message: error.message || 'Server error verifying officer' });
        }
    }

    /**
     * Helper to send PDF stream or JSON response
     */
    static handleOutput(res, result) {
        if (result.type === 'json') {
            return res.json({ success: true, ...result.data });
        }

        res.setHeader('Content-disposition', `attachment; filename="${result.filename}"`);
        res.setHeader('Content-type', 'application/pdf');
        result.doc.pipe(res);
        result.doc.end();
    }

    /**
     * Generate Monthly / Annual / Custom Fine Audit Report
     */
    static async generateMonthlyReport(req, res) {
        try {
            const result = await ReportService.generateFinesReport({
                params: req.body,
                format: req.query.format,
                adminInfo: req.user
            });
            ReportController.handleOutput(res, result);
        } catch (error) {
            console.error('Generate monthly report error:', error);
            const status = error.status || HTTP.SERVER_ERROR;
            res.status(status).json({ message: error.message || 'Server error', error: error.message });
        }
    }

    /**
     * Generate Payment Reconciliation Report
     */
    static async generatePaymentReport(req, res) {
        try {
            const result = await ReportService.generatePaymentReport({
                params: req.body,
                format: req.query.format,
                adminInfo: req.user
            });
            ReportController.handleOutput(res, result);
        } catch (error) {
            console.error('Generate payment report error:', error);
            const status = error.status || HTTP.SERVER_ERROR;
            res.status(status).json({ message: error.message || 'Server error', error: error.message });
        }
    }

    /**
     * Generate Driver Violation Report (Individual / Nationwide Audit)
     */
    static async generateDriverViolationReport(req, res) {
        try {
            const result = await ReportService.generateDriverReport({
                params: req.body,
                format: req.query.format,
                adminInfo: req.user
            });
            ReportController.handleOutput(res, result);
        } catch (error) {
            console.error('Generate driver report error:', error);
            const status = error.status || HTTP.SERVER_ERROR;
            res.status(status).json({ message: error.message || 'Server error', error: error.message });
        }
    }

    /**
     * Generate Vehicle Citation History Report
     */
    static async generateVehicleReport(req, res) {
        try {
            const result = await ReportService.generateVehicleReport({
                params: req.body,
                format: req.query.format,
                adminInfo: req.user
            });
            ReportController.handleOutput(res, result);
        } catch (error) {
            console.error('Generate vehicle report error:', error);
            const status = error.status || HTTP.SERVER_ERROR;
            res.status(status).json({ message: error.message || 'Server error', error: error.message });
        }
    }

    /**
     * Generate Police Officer Performance Report
     */
    static async generateOfficerReport(req, res) {
        try {
            const result = await ReportService.generateOfficerReport({
                params: req.body,
                format: req.query.format,
                adminInfo: req.user
            });
            ReportController.handleOutput(res, result);
        } catch (error) {
            console.error('Generate officer report error:', error);
            const status = error.status || HTTP.SERVER_ERROR;
            res.status(status).json({ message: error.message || 'Server error', error: error.message });
        }
    }
}

module.exports = ReportController;
