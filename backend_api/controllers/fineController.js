const Offense = require('../models/offenseModel');
const IssuedFine = require('../models/issuedFineModel');
const { applyDemeritPoints } = require('./demeritController');
const { HTTP, PAYMENT } = require('../config/constants');

// @desc    Get all fine types / offenses
// @route   GET /api/fines/offenses
const getOffenses = async (req, res) => {
  try {
    const offenses = await Offense.find({}).sort({ offenseName: 1 });
    res.status(HTTP.OK).json(offenses);
  } catch (error) {
    res.status(HTTP.SERVER_ERROR).json({ message: 'Server Error', error: error.message });
  }
};

// @desc    Add a new offense (For Admin Testing)
// @route   POST /api/fines/add
const addOffense = async (req, res) => {
  const { offenseName, amount, description, sectionOfAct, demeritValue } = req.body;
  try {
    const offense = await Offense.create({ 
      offenseName, 
      amount, 
      description, 
      sectionOfAct, 
      demeritValue 
    });
    res.status(HTTP.CREATED).json(offense);
  } catch (error) {
    res.status(HTTP.SERVER_ERROR).json({ message: 'Failed to add offense', error: error.message });
  }
};

// @desc    Issue a new fine (Save to Database)
// @route   POST /api/fines/issue
const issueFine = async (req, res) => {
  const { licenseNumber, vehicleNumber, offenseId, offenseName, amount, place, policeOfficerId, date } = req.body;

  if (!licenseNumber || !vehicleNumber || !offenseId || !place || !policeOfficerId) {
    return res.status(HTTP.BAD_REQUEST).json({ message: 'All fields are required' });
  }

  try {
    const offense = await Offense.findById(offenseId);
    if (!offense) {
      return res.status(HTTP.NOT_FOUND).json({ message: 'Offense type not found' });
    }

    const fine = await IssuedFine.create({
      licenseNumber,
      vehicleNumber,
      offenseId,
      offenseName: offense.offenseName, // Always use names from the master offense record
      amount: offense.amount, // Use amount from master record to prevent price tampering
      place,
      policeOfficerId,
      demeritPoints: offense.demeritValue || 0, // Save points into the fine record
      date: date || Date.now()
    });

    let demeritResult = null;
    try {
      demeritResult = await applyDemeritPoints(licenseNumber, offenseId);
    } catch (demeritErr) {
      console.error('[Demerit] Failed to apply points:', demeritErr.message);
    }

    res.status(HTTP.CREATED).json({
      message: 'Fine issued successfully',
      fine,
      demeritResult,
    });
  } catch (error) {
    console.error("Error issuing fine:", error);
    res.status(HTTP.SERVER_ERROR).json({ message: 'Failed to issue fine', error: error.message });
  }
};

// @desc    Get Fine History (Filter by Officer ID)
// @route   GET /api/fines/history
const getFineHistory = async (req, res) => {
  try {
    const { policeOfficerId } = req.query;

    const query = policeOfficerId ? { policeOfficerId: policeOfficerId } : {};

    const history = await IssuedFine.find(query).sort({ createdAt: -1 });

    res.status(HTTP.OK).json(history);
  } catch (error) {
    res.status(HTTP.SERVER_ERROR).json({ message: 'Failed to get history', error: error.message });
  }
};

// @desc    Get Pending Fines for a Driver
// @route   GET /api/fines/pending
const getDriverPendingFines = async (req, res) => {
  try {
    const { licenseNumber } = req.query;

    if (!licenseNumber) {
      return res.status(HTTP.BAD_REQUEST).json({ message: 'License number is required' });
    }

    // Case-insensitive match for both licenseNumber and status
    const fines = await IssuedFine.find({
      licenseNumber: { $regex: new RegExp(`^${licenseNumber}$`, 'i') },
      status: { $in: [
        /^UNPAID$/i,
        /^PENDING$/i
      ] }
    }).sort({ createdAt: -1 });

    res.status(HTTP.OK).json(fines);
  } catch (error) {
    res.status(HTTP.SERVER_ERROR).json({ message: 'Failed to fetch pending fines', error: error.message });
  }
};

// @desc    Mark fine as Paid (After PayHere Success)
// @route   POST /api/fines/:id/pay
const payFine = async (req, res) => {
  try {
    const { id } = req.params;
    const { paymentId } = req.body;

    const fine = await IssuedFine.findById(id);

    if (!fine) {
      return res.status(HTTP.NOT_FOUND).json({ message: 'Fine not found' });
    }

    if (fine.status === PAYMENT.STATUS.PAID) {
      return res.status(HTTP.BAD_REQUEST).json({ message: 'Fine is already paid' });
    }

    fine.status = PAYMENT.STATUS.PAID;
    fine.paymentId = paymentId;
    fine.paidAt = Date.now();

    await fine.save();

    res.status(HTTP.OK).json({ message: 'Fine paid successfully', fine });
  } catch (error) {
    res.status(HTTP.SERVER_ERROR).json({ message: 'Failed to update payment', error: error.message });
  }
};

// @desc    Get Paid Fine History for a Driver
// @route   GET /api/fines/driver-history
const getDriverPaidHistory = async (req, res) => {
  try {
    const { licenseNumber } = req.query;

    if (!licenseNumber) {
      return res.status(HTTP.BAD_REQUEST).json({ message: 'License number is required' });
    }

    // Case-insensitive match for both licenseNumber and status
    const fines = await IssuedFine.find({
      licenseNumber: { $regex: new RegExp(`^${licenseNumber}$`, 'i') },
      status: /^PAID$/i
    }).sort({ paidAt: -1 });

    res.status(HTTP.OK).json(fines);
  } catch (error) {
    res.status(HTTP.SERVER_ERROR).json({ message: 'Failed to fetch history', error: error.message });
  }
};

// @desc    Get Dashboard Stats (Daily Fines Count, Total Amount, Recent 3 Fines)
// @route   GET /api/fines/dashboard-stats
const getDashboardStats = async (req, res) => {
  try {
    const { policeOfficerId } = req.query;

    if (!policeOfficerId) {
      return res.status(HTTP.BAD_REQUEST).json({ message: 'Police Officer ID is required' });
    }

    // === Get Today's Date Range (00:00:00 to 23:59:59) ===
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    // === MongoDB Aggregation Pipeline for Daily Stats ===
    const dailyStatsResult = await IssuedFine.aggregate([
      {
        $match: {
          policeOfficerId: policeOfficerId,
          date: {
            $gte: today,
            $lt: tomorrow
          }
        }
      },
      {
        $group: {
          _id: null,
          count: { $sum: 1 },
          totalAmount: { $sum: '$amount' }
        }
      }
    ]);

    const dailyStats = dailyStatsResult.length > 0
      ? dailyStatsResult[0]
      : { count: 0, totalAmount: 0 };

    // === Get Last 3 Recent Fines ===
    const recentFines = await IssuedFine.find({
      policeOfficerId: policeOfficerId
    })
      .select('vehicleNumber offenseName amount date status -_id')
      .sort({ date: -1 })
      .limit(3)
      .lean();

    res.status(HTTP.OK).json({
      dailyFinesCount: dailyStats.count || 0,
      dailyTotalAmount: dailyStats.totalAmount || 0,
      recentFines: recentFines || []
    });
  } catch (error) {
    res.status(HTTP.SERVER_ERROR).json({ message: 'Failed to fetch dashboard stats', error: error.message });
  }
};

module.exports = {
  getOffenses,
  addOffense,
  issueFine,
  getFineHistory,
  getDriverPendingFines,
  payFine,
  getDriverPaidHistory,
  getDashboardStats
};
