const Station = require('../models/stationModel');
const { HTTP } = require('../config/constants');

// @desc    Get all police stations
// @route   GET /api/stations
const getStations = async (req, res) => {
  try {
    const stations = await Station.find();
    res.status(HTTP.OK).json({ success: true, data: stations });
  } catch (error) {
    res.status(HTTP.SERVER_ERROR).json({ message: 'Server Error', error: error.message });
  }
};

// @desc    Create new police station
// @route   POST /api/admin/stations
const createStation = async (req, res) => {
  try {
    const { stationCode, name, district, province, officialEmail, location } = req.body;

    const stationExists = await Station.findOne({ stationCode });
    if (stationExists) {
      return res.status(HTTP.BAD_REQUEST).json({ message: 'Station code already exists' });
    }

    const station = await Station.create({
      stationCode,
      name,
      district,
      province,
      officialEmail,
      location
    });

    res.status(HTTP.CREATED).json({ success: true, data: station });
  } catch (error) {
    res.status(HTTP.SERVER_ERROR).json({ message: 'Server Error', error: error.message });
  }
};

// @desc    Update police station
// @route   PUT /api/admin/stations/:id
const updateStation = async (req, res) => {
  try {
    const { stationCode, name, district, province, officialEmail, location } = req.body;

    let station = await Station.findById(req.params.id);
    if (!station) {
      return res.status(HTTP.NOT_FOUND).json({ message: 'Station not found' });
    }

    if (stationCode && stationCode !== station.stationCode) {
        const stationExists = await Station.findOne({ stationCode });
        if (stationExists) {
            return res.status(HTTP.BAD_REQUEST).json({ message: 'Station code already exists' });
        }
    }

    station = await Station.findByIdAndUpdate(
      req.params.id,
      { stationCode, name, district, province, officialEmail, location },
      { new: true, runValidators: true }
    );

    res.status(HTTP.OK).json({ success: true, data: station });
  } catch (error) {
    res.status(HTTP.SERVER_ERROR).json({ message: 'Server Error', error: error.message });
  }
};

// @desc    Delete police station
// @route   DELETE /api/admin/stations/:id
const deleteStation = async (req, res) => {
  try {
    const station = await Station.findById(req.params.id);
    if (!station) {
      return res.status(HTTP.NOT_FOUND).json({ message: 'Station not found' });
    }

    await station.deleteOne();
    res.status(HTTP.OK).json({ success: true, message: 'Station deleted successfully' });
  } catch (error) {
    res.status(HTTP.SERVER_ERROR).json({ message: 'Server Error', error: error.message });
  }
};

module.exports = { getStations, createStation, updateStation, deleteStation };