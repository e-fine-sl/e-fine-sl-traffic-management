// ─────────────────────────────────────────────────────────────────────────────
// controllers/sosController.js
// Description: Handles SOS emergency alerts and updates officer locations.
// ─────────────────────────────────────────────────────────────────────────────

const Police = require('../models/policeModel');
const OfficerSession = require('../models/officerSessionModel');
const { sendToMultiple } = require('../services/fcmService');

// Constants
const SOS_RADIUS_METERS = 5000; // Search radius: 5 kilometers

/**
 * @route   POST /api/sos
 * @desc    Trigger an Emergency SOS Alert to nearby active officers
 * @access  Private 
 */
const triggerSOS = async (req, res) => {
  const tag = '[SOS Controller]';
  console.log(`\n${'═'.repeat(60)}`);
  console.log(`${tag} SOS ALERT TRIGGERED`);
  console.log(`${tag} Timestamp: ${new Date().toISOString()}`);

  // 1. Extract and validate incoming request data
  const { badgeNumber, lat, lng, emergencyType } = req.body;

  if (!badgeNumber || lat === undefined || lat === null || lng === undefined || lng === null || !emergencyType) {
    return res.status(400).json({ success: false, message: 'badgeNumber, lat, lng, and emergencyType are required' });
  }

  // Convert string coordinates to floating-point numbers
  const latitude = parseFloat(lat);
  const longitude = parseFloat(lng);

  if (isNaN(latitude) || isNaN(longitude)) {
    return res.status(400).json({ success: false, message: 'lat and lng must be valid numbers' });
  }

  try {
    // 2. Update the sender's location in the database
    // Note: MongoDB GeoJSON strictly requires coordinates in [longitude, latitude] order
    const updateResult = await Police.findOneAndUpdate(
      { badgeNumber },
      {
        $set: {
          location: {
            type: 'Point',
            coordinates: [longitude, latitude], 
          },
          isActive: true,
        },
      },
      { new: true }
    );

    if (!updateResult) {
      console.error(`${tag} Sender (Officer ${badgeNumber}) not found in database.`);
      return res.status(404).json({ success: false, message: `Officer ${badgeNumber} not found` });
    }

    // 3. Find nearby active officers using MongoDB $near geospatial query
    const nearbyOfficers = await Police.find({
      location: {
        $near: {
          $geometry: {
            type: 'Point',
            coordinates: [longitude, latitude], // Query center
          },
          $maxDistance: SOS_RADIUS_METERS, // Limit to 5km
        },
      },
      isActive: true, // Only fetch officers who are currently online
    }).select('name badgeNumber fcmToken location');

    // 4. Filter out the sender from the recipients list (so they don't get their own alert)
    const recipients = nearbyOfficers.filter(o => o.badgeNumber !== badgeNumber);

    // If no one else is nearby, return early
    if (recipients.length === 0) {
      console.warn(`${tag} No nearby officers found to notify.`);
      return res.status(200).json({
        success: true,
        message: 'SOS logged but no nearby officers found to notify.',
        nearbyCount: 0,
        notified: 0,
        notifiedOfficers: [] // Return empty list
      });
    }

    // 5. Prepare and send FCM push notifications
    // Filter out officers who don't have a valid FCM token saved
    const validTokens = recipients
      .map(o => o.fcmToken)
      .filter(t => t && t.length > 10);

    const senderName = updateResult.name || `Officer ${badgeNumber}`;
    
    // The data payload sent to the mobile devices
    const fcmPayload = {
      title: `🚨 SOS: ${emergencyType}`,
      body: `${senderName} needs IMMEDIATE assistance!\nTap to respond.`,
      data: {
        type: 'SOS_ALERT',
        badgeNumber: badgeNumber,
        senderName: senderName,
        emergencyType: emergencyType,
        senderLat: String(latitude),
        senderLng: String(longitude),
        timestamp: new Date().toISOString(),
      },
    };

    // Dispatch the notifications
    let fcmResult = { sent: 0, failed: 0, results: [] };
    if (validTokens.length > 0) {
      fcmResult = await sendToMultiple(validTokens, fcmPayload);
    } else {
      console.warn(`${tag} No valid FCM tokens found for the nearby officers.`);
    }

    // 6. Format the response to include the list of officers who received the alert
    // This allows the frontend app to show who is coming to help
    const notifiedOfficersList = recipients.map(officer => ({
      name: officer.name || 'Unknown Officer',
      badgeNumber: officer.badgeNumber
    }));

    console.log(`\n${tag} SOS COMPLETE - Sent: ${fcmResult.sent}, Failed: ${fcmResult.failed}`);
    console.log(`${'═'.repeat(60)}\n`);

    return res.status(200).json({
      success: true,
      message: `SOS alert dispatched. ${fcmResult.sent} officer(s) notified.`,
      nearbyCount: nearbyOfficers.length,
      notified: fcmResult.sent,
      notifiedOfficers: notifiedOfficersList // 🔥 The list of officers is returned here
    });

  } catch (err) {
    console.error(`${tag} UNHANDLED EXCEPTION:`, err.message);
    return res.status(500).json({ success: false, message: 'Internal Server Error', error: err.message });
  }
};


/**
 * @route   PUT /api/sos/update-location
 * @desc    Updates an officer's stored location, presence status, and FCM token.
 * Usually called when the officer opens the app or logs in.
 */
const updateOfficerPresence = async (req, res) => {
  const tag = '[SOS/UpdatePresence]';
  const { badgeNumber, lat, lng, fcmToken } = req.body;

  if (!badgeNumber || !fcmToken) {
    return res.status(400).json({ success: false, message: 'badgeNumber and fcmToken are required' });
  }

  // Base fields to update (marks officer as active)
  const updateFields = { 
    fcmToken, 
    isActive: true,
    lastLoginTime: new Date()
  };

  // Safely parse and attach location data ONLY if the phone provided valid GPS coordinates
  if (lat !== undefined && lng !== undefined && lat !== null && lng !== null) {
    const parsedLat = parseFloat(lat);
    const parsedLng = parseFloat(lng);
    
    if (!isNaN(parsedLat) && !isNaN(parsedLng)) {
      const coords = [parsedLng, parsedLat]; // GeoJSON format: [longitude, latitude]
      updateFields.location = { type: 'Point', coordinates: coords };
      updateFields.lastLoginLocation = { type: 'Point', coordinates: coords };
    } else {
      console.warn(`${tag} ⚠️ Warning: Invalid lat/lng numbers provided.`);
    }
  } else {
    console.warn(`${tag} ⚠️ NO location provided for ${badgeNumber}. They will not be discoverable via $near!`);
  }

  try {
    // Update the officer in MongoDB
    const result = await Police.findOneAndUpdate(
      { badgeNumber },
      { $set: updateFields },
      { new: true }
    );

    if (!result) {
      return res.status(404).json({ success: false, message: `Officer ${badgeNumber} not found` });
    }

    // Check if the location field actually exists after the update
    const hasLocation = !!(result.location && result.location.coordinates && result.location.coordinates.length === 2);

    // Create a session log entry (fire-and-forget, doesn't block the response)
    OfficerSession.create({
      badgeNumber: result.badgeNumber,
      officerName: result.name,
      loginTime: new Date(),
    }).catch(err => console.error(`${tag} Session log failed: ${err.message}`));

    // Respond back to the mobile app
    return res.status(200).json({ 
      success: true, 
      message: 'Presence updated successfully',
      hasLocation, // This flag tells the frontend if the backend successfully saved the GPS data
      warning: hasLocation ? null : 'Location not set. SOS features will not work correctly!'
    });

  } catch (err) {
    console.error(`${tag} Error:`, err.message);
    return res.status(500).json({ success: false, message: 'Server Error', error: err.message });
  }
};

// Export the functions to be used in routes
module.exports = { triggerSOS, updateOfficerPresence };