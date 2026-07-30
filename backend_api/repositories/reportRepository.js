const IssuedFine = require('../models/issuedFineModel');
const Driver = require('../models/driverModel');
const { PAYMENT } = require('../config/constants');

/**
 * ReportRepository - Data Access Layer for Reports & Audits
 * Encapsulates Mongoose queries and database aggregations.
 */
class ReportRepository {
    /**
     * Find fines matching date range and optional region filters
     */
    static async findFines(query) {
        return await IssuedFine.find(query).populate('offenseId', 'offenseName').sort({ date: -1 });
    }

    /**
     * Find settled payment transactions matching query
     */
    static async findPayments(query) {
        return await IssuedFine.find({ ...query, status: PAYMENT.STATUS.PAID })
            .populate('offenseId', 'offenseName')
            .sort({ paidAt: -1 });
    }

    /**
     * Find single registered driver by license number
     */
    static async findDriverByLicense(licenseNumber) {
        return await Driver.findOne({
            licenseNumber: { $regex: new RegExp(`^${licenseNumber.trim()}$`, 'i') }
        });
    }

    /**
     * Count total fines for a specific driver
     */
    static async countDriverFines(licenseNumber) {
        return await IssuedFine.countDocuments({
            licenseNumber: { $regex: new RegExp(`^${licenseNumber.trim()}$`, 'i') }
        });
    }

    /**
     * Aggregate nationwide driver audit dataset
     */
    static async getDriverAuditDataset(query = {}) {
        const [allDrivers, totalSuspended, totalWarningOrDanger, totalFinesCount] = await Promise.all([
            Driver.find(query).select('name licenseNumber licenseStatus demeritPoints demeritLevel'),
            Driver.countDocuments({ licenseStatus: 'SUSPENDED' }),
            Driver.countDocuments({ demeritLevel: { $in: ['WARNING', 'DANGER'] } }),
            IssuedFine.countDocuments({})
        ]);

        return {
            allDrivers,
            totalSuspended,
            totalWarningOrDanger,
            totalFinesCount
        };
    }

    /**
     * Find fines by vehicle license plate
     */
    static async findFinesByVehicle(vehicleNumber) {
        return await IssuedFine.find({
            vehicleNumber: { $regex: new RegExp(`^${vehicleNumber.trim()}$`, 'i') }
        }).populate('offenseId', 'offenseName').sort({ date: -1 });
    }

    /**
     * Find fines by police officer badge ID
     */
    static async findFinesByOfficer(policeOfficerId) {
        return await IssuedFine.find({
            policeOfficerId: { $regex: new RegExp(`^${policeOfficerId.trim()}$`, 'i') }
        }).populate('offenseId', 'offenseName').sort({ date: -1 });
    }
}

module.exports = ReportRepository;
