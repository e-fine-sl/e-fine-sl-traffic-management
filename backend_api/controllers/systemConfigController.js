const SystemConfig = require('../models/systemConfigModel');

// @desc    Get system configuration
// @route   GET /api/admin/system-config
// @access  Private/Admin
const getSystemConfig = async (req, res) => {
  try {
    let config = await SystemConfig.findOne();
    
    // If no config exists, create a default one
    if (!config) {
      config = await SystemConfig.create({
        accidentNotificationRadiusKm: 10,
        officerLogoutGracePeriodMinutes: 20
      });
    }

    res.status(200).json({
      success: true,
      data: config
    });
  } catch (error) {
    console.error('Error fetching system config:', error);
    res.status(500).json({ success: false, message: 'Server Error' });
  }
};

// @desc    Update system configuration
// @route   PUT /api/admin/system-config
// @access  Private/SuperAdmin
const updateSystemConfig = async (req, res) => {
  try {
    const { accidentNotificationRadiusKm, officerLogoutGracePeriodMinutes } = req.body;

    if (accidentNotificationRadiusKm && (accidentNotificationRadiusKm < 1 || accidentNotificationRadiusKm > 100)) {
       return res.status(400).json({ success: false, message: 'Radius must be between 1 and 100 km' });
    }

    if (officerLogoutGracePeriodMinutes && (officerLogoutGracePeriodMinutes < 5 || officerLogoutGracePeriodMinutes > 120)) {
       return res.status(400).json({ success: false, message: 'Grace period must be between 5 and 120 minutes' });
    }

    let config = await SystemConfig.findOne();

    if (!config) {
      config = new SystemConfig();
    }

    if (accidentNotificationRadiusKm) {
        config.accidentNotificationRadiusKm = accidentNotificationRadiusKm;
    }

    if (officerLogoutGracePeriodMinutes) {
        config.officerLogoutGracePeriodMinutes = officerLogoutGracePeriodMinutes;
    }

    await config.save();

    res.status(200).json({
      success: true,
      message: 'System configuration updated successfully',
      data: config
    });
  } catch (error) {
    console.error('Error updating system config:', error);
    res.status(500).json({ success: false, message: 'Server Error' });
  }
};

module.exports = {
  getSystemConfig,
  updateSystemConfig
};
