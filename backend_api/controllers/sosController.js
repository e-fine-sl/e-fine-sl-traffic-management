// ─────────────────────────────────────────────────────────────────────────────
// controllers/sosController.js
// POST /api/sos  —  Zero-Typing SOS Emergency Alert
// ─────────────────────────────────────────────────────────────────────────────

const Police       = require('../models/policeModel');
const OfficerSession = require('../models/officerSessionModel');
const { sendToMultiple } = require('../services/fcmService');

// ── CONSTANTS ──────────────────────────────────────────────────────────────────
const SOS_RADIUS_METERS = 5000; // 5 km

/**
 * @route   POST /api/sos
 * @access  Private (requires valid JWT)
 * @body    { badgeNumber, lat, lng, emergencyType }
 */
const triggerSOS = async (req, res) => {
  const tag = '[SOS Controller]';
  console.log(`\n${'═'.repeat(60)}`);
  console.log(`${tag}  SOS ALERT TRIGGERED`);
  console.log(`${tag} Timestamp: ${new Date().toISOString()}`);
  console.log(`${tag} Raw Request Body:`, JSON.stringify(req.body, null, 2));
  console.log(`${'═'.repeat(60)}`);

  // ── STEP 1: VALIDATE INPUT ─────────────────────────────────────────────────
  const { badgeNumber, lat, lng, emergencyType } = req.body;

  if (!badgeNumber || lat === undefined || lat === null || lng === undefined || lng === null || !emergencyType) {
    console.error(`${tag}  STEP 1 FAILED: Missing required fields`);
    return res.status(400).json({ success: false, message: 'badgeNumber, lat, lng, and emergencyType are required' });
  }

  const latitude  = parseFloat(lat);
  const longitude = parseFloat(lng);

  if (isNaN(latitude) || isNaN(longitude)) {
    console.error(`${tag}  STEP 1 FAILED: lat/lng are not valid numbers`);
    return res.status(400).json({ success: false, message: 'lat and lng must be valid numbers' });
  }

  console.log(`${tag}  STEP 1 OK: badgeNumber=${badgeNumber}, lat=${latitude}, lng=${longitude}, type=${emergencyType}`);

  try {
    // ── STEP 2: UPDATE SENDER'S LOCATION IN DB ───────────────────────────────
    console.log(`\n${tag} STEP 2: Updating sender's location in DB...`);

    const updateResult = await Police.findOneAndUpdate(
      { badgeNumber },
      {
        $set: {
          location: {
            type: 'Point',
            coordinates: [longitude, latitude], // GeoJSON: [lng, lat]
          },
          isActive: true,
        },
      },
      { new: true }
    );

    if (!updateResult) {
      console.error(`${tag}  STEP 2 FAILED: Officer ${badgeNumber} NOT FOUND`);
      return res.status(404).json({ success: false, message: `Officer ${badgeNumber} not found` });
    }
    console.log(`${tag}  STEP 2 OK: Location updated for ${updateResult.name}`);

    // ── STEP 3: GEO-QUERY — find officers within 5 km ───────────────────────
    console.log(`\n${tag} STEP 3: Running $near query (radius=${SOS_RADIUS_METERS}m)...`);
    console.log(`${tag}    Query center: [${longitude}, ${latitude}]`);

    const nearbyOfficers = await Police.find({
      location: {
        $near: {
          $geometry: {
            type: 'Point',
            coordinates: [longitude, latitude], // GeoJSON: [lng, lat]
          },
          $maxDistance: SOS_RADIUS_METERS,
        },
      },
      isActive: true,
    }).select('name badgeNumber fcmToken location');

    console.log(`${tag}  STEP 3 OK: Found ${nearbyOfficers.length} officer(s) within 5 km`);

    // ── STEP 4: FILTER OUT THE SENDER ───────────────────────────────────────
    const recipients = nearbyOfficers.filter(o => o.badgeNumber !== badgeNumber);
    console.log(`${tag}  STEP 4 OK: ${recipients.length} recipients after excluding sender`);

    if (recipients.length === 0) {
      console.warn(`${tag}  No nearby officers to notify.`);
      return res.status(200).json({
        success: true,
        message: 'SOS logged but no nearby officers found to notify.',
        nearbyCount: 0,
        notified: 0,
      });
    }

    // ── STEP 5: SEND FCM NOTIFICATIONS ───────────────────────────────────────
    console.log(`\n${tag} STEP 5: Dispatching FCM notifications...`);

    const validTokens = recipients
      .map(o => o.fcmToken)
      .filter(t => t && t.length > 10);

    const senderName = updateResult.name || `Officer ${badgeNumber}`;
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

    let fcmResult = { sent: 0, failed: 0, results: [] };
    if (validTokens.length > 0) {
      fcmResult = await sendToMultiple(validTokens, fcmPayload);
    } else {
      console.warn(`${tag}  No valid FCM tokens found for nearby officers.`);
    }

    // ── STEP 6: RESPOND ───────────────────────────────────────────────────────
    console.log(`\n${tag}  SOS PROCESSING COMPLETE - Sent: ${fcmResult.sent}, Failed: ${fcmResult.failed}`);
    return res.status(200).json({
      success: true,
      message: `SOS alert dispatched. ${fcmResult.sent} officer(s) notified.`,
      nearbyCount: nearbyOfficers.length,
      notified: fcmResult.sent
    });

  } catch (err) {
    console.error(`${tag}  UNHANDLED EXCEPTION:`, err.message);
    return res.status(500).json({ success: false, message: 'Internal Server Error', error: err.message });
  }
};

/**
 * @route   PUT /api/sos/update-location
 */
const updateOfficerPresence = async (req, res) => {
  const tag = '[SOS/UpdatePresence]';
  console.log(`${tag} Incoming:`, JSON.stringify(req.body));

  const { badgeNumber, lat, lng, fcmToken } = req.body;

  if (!badgeNumber || !fcmToken) {
    return res.status(400).json({ success: false, message: 'badgeNumber and fcmToken are required' });
  }

  const updateFields = { 
    fcmToken, 
    isActive: true,
    lastLoginTime: new Date()
  };

  // 🔥 THE FIX: Strictly validate Location Data before trusting it
  if (lat !== undefined && lng !== undefined && lat !== null && lng !== null) {
    const parsedLat = parseFloat(lat);
    const parsedLng = parseFloat(lng);
    
    if (!isNaN(parsedLat) && !isNaN(parsedLng)) {
      const coords = [parsedLng, parsedLat]; // GeoJSON: [lng, lat]
      updateFields.location = { type: 'Point', coordinates: coords };
      updateFields.lastLoginLocation = { type: 'Point', coordinates: coords };
      console.log(`${tag} Updating location to [${parsedLng}, ${parsedLat}]`);
    } else {
      console.warn(`${tag} ⚠️ lat/lng provided but invalid numbers: lat=${lat}, lng=${lng}`);
    }
  } else {
    console.warn(`${tag} ⚠️ NO location provided for ${badgeNumber}. This officer will NOT be discoverable via $near!`);
  }

  try {
    const result = await Police.findOneAndUpdate(
      { badgeNumber },
      { $set: updateFields },
      { new: true }
    );

    if (!result) {
      return res.status(404).json({ success: false, message: `Officer ${badgeNumber} not found` });
    }

    // Verify if location was actually saved
    const hasLocation = !!(result.location && result.location.coordinates && result.location.coordinates.length === 2);
    console.log(`${tag} Presence updated for ${result.name} | hasLocation: ${hasLocation}`);

    OfficerSession.create({
      badgeNumber: result.badgeNumber,
      officerName: result.name,
      loginTime: new Date(),
    }).catch(err => console.error(`${tag} Session log failed: ${err.message}`));

    // 🔥 Send warning to Flutter app if location wasn't saved!
    return res.status(200).json({ 
      success: true, 
      message: 'Presence updated successfully',
      hasLocation,
      warning: hasLocation ? null : 'Location not set. SOS will not work!'
    });
  } catch (err) {
    console.error(`${tag} Error:`, err.message);
    return res.status(500).json({ success: false, message: 'Server Error', error: err.message });
  }
};

module.exports = { triggerSOS, updateOfficerPresence };