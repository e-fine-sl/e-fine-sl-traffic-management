// ─────────────────────────────────────────────────────────────────────────────
// controllers/sosController.js
// POST /api/sos  —  Zero-Typing SOS Emergency Alert
//
// FLOW:
//  1. Validate request (badgeNumber, lat, lng, emergencyType)
//  2. Update sender's location in DB
//  3. Find all ACTIVE officers within 5 km using $near
//  4. Filter out the sender themselves
//  5. Send HIGH-PRIORITY FCM push to every nearby officer's token
//  6. Return a detailed JSON response (great for debugging)
// ─────────────────────────────────────────────────────────────────────────────

const Police      = require('../models/policeModel');
const { sendToMultiple } = require('../services/fcmService');

// ── CONSTANTS ──────────────────────────────────────────────────────────────────
const SOS_RADIUS_METERS = 5000; // 5 km

/**
 * @route   POST /api/sos
 * @access  Private (requires valid JWT) — but we also support open for demo
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

  if (!badgeNumber) {
    console.error(`${tag}  STEP 1 FAILED: Missing badgeNumber`);
    return res.status(400).json({ success: false, message: 'badgeNumber is required' });
  }
  if (lat === undefined || lat === null || lng === undefined || lng === null) {
    console.error(`${tag}  STEP 1 FAILED: Missing lat/lng`);
    return res.status(400).json({ success: false, message: 'lat and lng are required' });
  }
  if (!emergencyType) {
    console.error(`${tag}  STEP 1 FAILED: Missing emergencyType`);
    return res.status(400).json({ success: false, message: 'emergencyType is required' });
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

    // GeoJSON stores coordinates as [longitude, latitude] — NOTE THE ORDER!
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
      console.error(`${tag}  STEP 2 FAILED: Officer with badgeNumber "${badgeNumber}" NOT FOUND in DB`);
      return res.status(404).json({ success: false, message: `Officer ${badgeNumber} not found` });
    }
    console.log(`${tag}  STEP 2 OK: Location updated for officer: ${updateResult.name}`);
    console.log(`${tag}    Stored coordinates: [${longitude}, ${latitude}]`);

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

    nearbyOfficers.forEach((o, i) => {
      console.log(`${tag}    [${i + 1}] ${o.name} (${o.badgeNumber}) | Token: ${o.fcmToken ? o.fcmToken.slice(-10) + '...' : 'NO TOKEN'}`);
    });

    // ── STEP 4: FILTER OUT THE SENDER ───────────────────────────────────────
    console.log(`\n${tag} STEP 4: Filtering out sender (${badgeNumber})...`);

    const recipients = nearbyOfficers.filter(o => o.badgeNumber !== badgeNumber);
    console.log(`${tag}  STEP 4 OK: ${recipients.length} recipients after excluding sender`);

    if (recipients.length === 0) {
      console.warn(`${tag}  No nearby officers to notify (either none in range, or only the sender is nearby).`);
      return res.status(200).json({
        success: true,
        message: 'SOS logged but no nearby officers found to notify.',
        nearbyCount: 0,
        notified: 0,
      });
    }

    // ── STEP 5: SEND FCM NOTIFICATIONS ───────────────────────────────────────
    console.log(`\n${tag} STEP 5: Dispatching FCM notifications...`);

    // Collect tokens — skip officers without a token
    const validTokens = recipients
      .map(o => o.fcmToken)
      .filter(t => t && t.length > 10);

    console.log(`${tag}    Valid FCM tokens: ${validTokens.length} / ${recipients.length}`);

    const senderName = updateResult.name || `Officer ${badgeNumber}`;
    const fcmPayload = {
      title: ` SOS: ${emergencyType}`,
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

    console.log(`${tag}    FCM Payload:`, JSON.stringify(fcmPayload, null, 2));

    let fcmResult = { sent: 0, failed: 0, results: [] };
    if (validTokens.length > 0) {
      fcmResult = await sendToMultiple(validTokens, fcmPayload);
    } else {
      console.warn(`${tag}  No valid FCM tokens — all nearby officers may not have logged in yet.`);
    }

    // ── STEP 6: RESPOND ───────────────────────────────────────────────────────
    console.log(`\n${tag}  SOS PROCESSING COMPLETE`);
    console.log(`${tag}    nearbyOfficers: ${nearbyOfficers.length}`);
    console.log(`${tag}    recipients:     ${recipients.length}`);
    console.log(`${tag}    validTokens:    ${validTokens.length}`);
    console.log(`${tag}    fcm.sent:       ${fcmResult.sent}`);
    console.log(`${tag}    fcm.failed:     ${fcmResult.failed}`);
    console.log(`${'═'.repeat(60)}\n`);

    return res.status(200).json({
      success: true,
      message: `SOS alert dispatched. ${fcmResult.sent} officer(s) notified.`,
      debug: {
        senderBadge: badgeNumber,
        emergencyType,
        senderLocation: { lat: latitude, lng: longitude },
        radiusMeters: SOS_RADIUS_METERS,
        nearbyCount: nearbyOfficers.length,
        recipientCount: recipients.length,
        validTokenCount: validTokens.length,
        fcmSent: fcmResult.sent,
        fcmFailed: fcmResult.failed,
      },
    });

  } catch (err) {
    console.error(`${tag}  UNHANDLED EXCEPTION:`, err.message);
    console.error(err.stack);
    return res.status(500).json({ success: false, message: 'Internal Server Error', error: err.message });
  }
};

/**
 * @route   PUT /api/sos/update-location
 * @desc    Updates an officer's stored location and FCM token in DB.
 *          Called on login from Flutter.
 * @body    { badgeNumber, lat, lng, fcmToken }
 */
const updateOfficerPresence = async (req, res) => {
  const tag = '[SOS/UpdatePresence]';
  console.log(`${tag} Incoming:`, JSON.stringify(req.body));

  const { badgeNumber, lat, lng, fcmToken } = req.body;

  if (!badgeNumber || !fcmToken) {
    return res.status(400).json({ success: false, message: 'badgeNumber and fcmToken are required' });
  }

  const updateFields = { fcmToken, isActive: true };

  // Location is optional at login time (we update it precisely on SOS press)
  if (lat !== undefined && lng !== undefined) {
    updateFields.location = {
      type: 'Point',
      coordinates: [parseFloat(lng), parseFloat(lat)],
    };
    console.log(`${tag} Updating location to [${lng}, ${lat}]`);
  }

  try {
    const result = await Police.findOneAndUpdate(
      { badgeNumber },
      { $set: updateFields },
      { new: true }
    );

    if (!result) {
      console.error(`${tag}  Officer ${badgeNumber} not found`);
      return res.status(404).json({ success: false, message: `Officer ${badgeNumber} not found` });
    }

    console.log(`${tag}  Presence updated for ${result.name} (${badgeNumber})`);
    console.log(`${tag}    FCM Token: ...${fcmToken.slice(-10)}`);

    return res.status(200).json({ success: true, message: 'Presence updated successfully' });
  } catch (err) {
    console.error(`${tag}  Error:`, err.message);
    return res.status(500).json({ success: false, message: 'Server Error', error: err.message });
  }
};

module.exports = { triggerSOS, updateOfficerPresence };
