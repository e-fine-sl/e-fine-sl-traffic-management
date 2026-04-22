// ─────────────────────────────────────────────────────────────────────────────
// controllers/policeController.js
// Police-specific analytics and HQ alerts
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @route   GET /api/police/hq-alerts
 * @desc    Fetch active alerts and broadcasts from HQ
 * @access  Private (Officer/Admin)
 */
const getHqAlerts = async (req, res) => {
  try {
    // In a real app, you would fetch these from a "Broadcast" or "Alert" collection in MongoDB.
    // For now, we return a high-quality dummy array to satisfy the UI.
    const alerts = [
      {
        id: "alert-1",
        title: "Special Operation",
        message: "Check all vehicles in Colombo area today for valid insurance.",
        severity: "high",
        timestamp: new Date().toISOString(),
      },
      {
        id: "alert-2",
        title: "Weather Advisory",
        message: "Heavy rain expected. Ensure road safety protocols are active.",
        severity: "medium",
        timestamp: new Date().toISOString(),
      }
    ];

    // Return the array directly as expected by the mobile dashboard service
    return res.status(200).json(alerts);
  } catch (err) {
    console.error('[PoliceController] Error fetching HQ alerts:', err.message);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch HQ alerts',
      error: err.message
    });
  }
};

module.exports = {
  getHqAlerts
};
