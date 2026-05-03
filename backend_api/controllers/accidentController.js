const AccidentReport  = require('../models/accidentReportModel');
const Driver          = require('../models/driverModel');
const Police          = require('../models/policeModel');
const Station         = require('../models/stationModel');
const { sendToMultiple } = require('../services/fcmService');
const sendEmail          = require('../utils/sendEmail');
const { resolveLocation } = require('../utils/sriLankaGeoHelper');

const ACCIDENT_RADIUS_METERS = 5000; // 5 km

const buildEmailHtml = ({
  driverName, licenseNumber, driverPhone, accidentType,
  description, latitude, longitude, mapsLink, province, district,
  division, officersCount, reportedAt
}) => {
  return `
    <div style="max-width: 600px; margin: 0 auto; font-family: Arial, sans-serif; border: 1px solid #e0e0e0; border-radius: 8px; overflow: hidden;">
      <div style="background-color: #d32f2f; padding: 20px; text-align: center; color: white;">
        <h2 style="margin: 0;">🚨 ACCIDENT ALERT</h2>
        <p style="margin: 5px 0 0 0; font-size: 14px;">e-Fine SL Traffic Management System</p>
      </div>
      
      <div style="background-color: #ffebee; padding: 15px; border-bottom: 1px solid #ef9a9a; text-align: center;">
        <h3 style="color: #c62828; margin: 0; font-size: 20px;">${accidentType}</h3>
        <p style="color: #b71c1c; margin: 5px 0 0 0; font-size: 14px;">Reported At: ${reportedAt}</p>
      </div>

      <div style="padding: 20px;">
        <h4 style="color: #333; margin-top: 0; border-bottom: 2px solid #eee; padding-bottom: 5px;">Driver Details</h4>
        <table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
          <tr><td style="padding: 8px 0; color: #666; width: 40%;">Name:</td><td style="padding: 8px 0; font-weight: bold; color: #333;">${driverName}</td></tr>
          <tr><td style="padding: 8px 0; color: #666;">License Number:</td><td style="padding: 8px 0; font-weight: bold; color: #333;">${licenseNumber}</td></tr>
          <tr><td style="padding: 8px 0; color: #666;">Phone:</td><td style="padding: 8px 0; font-weight: bold; color: #333;">${driverPhone || 'Not provided'}</td></tr>
        </table>

        <h4 style="color: #333; margin-top: 0; border-bottom: 2px solid #eee; padding-bottom: 5px;">Location Details</h4>
        <table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
          <tr><td style="padding: 8px 0; color: #666; width: 40%;">Province:</td><td style="padding: 8px 0; font-weight: bold; color: #333;">${province}</td></tr>
          <tr><td style="padding: 8px 0; color: #666;">District:</td><td style="padding: 8px 0; font-weight: bold; color: #333;">${district}</td></tr>
          <tr><td style="padding: 8px 0; color: #666;">Police Division:</td><td style="padding: 8px 0; font-weight: bold; color: #333;">${division}</td></tr>
          <tr><td style="padding: 8px 0; color: #666;">GPS Coordinates:</td><td style="padding: 8px 0; font-weight: bold; color: #333;">${latitude}, ${longitude}</td></tr>
        </table>

        <div style="text-align: center; margin: 25px 0;">
          <a href="${mapsLink}" target="_blank" style="background-color: #1976d2; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; font-weight: bold; display: inline-block;">View on Google Maps</a>
        </div>

        ${description ? `
        <div style="background-color: #fff8e1; border: 1px solid #ffecb3; padding: 15px; border-radius: 4px; margin-bottom: 20px;">
          <h4 style="color: #f57f17; margin-top: 0; margin-bottom: 10px;">Additional Description</h4>
          <p style="color: #333; margin: 0; font-size: 14px; line-height: 1.5;">${description}</p>
        </div>
        ` : ''}
      </div>

      <div style="background-color: #f5f5f5; padding: 15px; text-align: center; border-top: 1px solid #e0e0e0; color: #757575; font-size: 12px;">
        <p style="margin: 0 0 5px 0;">${officersCount} officer(s) also notified via e-Fine SL app.</p>
        <p style="margin: 0;">This is an automated emergency alert. Do not reply to this email.</p>
      </div>
    </div>
  `;
};

const buildDivisionNotificationHtml = ({
  reportId, driverName, licenseNumber, accidentType, description,
  province, district, division, mapsLink, reportedAt, sentBy
}) => {
  return `
    <div style="max-width: 600px; margin: 0 auto; font-family: Arial, sans-serif; border: 1px solid #e0e0e0; border-radius: 8px; overflow: hidden;">
      <div style="background-color: #6a1b9a; padding: 20px; text-align: center; color: white;">
        <h2 style="margin: 0;">🚨 ACTION REQUIRED</h2>
        <p style="margin: 5px 0 0 0; font-size: 14px;">Accident in Your Division</p>
      </div>
      
      <div style="background-color: #f3e5f5; padding: 15px; border-bottom: 1px solid #e1bee7; text-align: center;">
        <p style="color: #4a148c; margin: 0; font-size: 14px; font-weight: bold;">Manually sent by ${sentBy} — Report ID: ${reportId}</p>
      </div>

      <div style="padding: 20px;">
        <h3 style="color: #d32f2f; margin-top: 0; text-align: center; font-size: 22px;">${accidentType}</h3>
        
        <table style="width: 100%; border-collapse: collapse; margin-bottom: 20px; margin-top: 20px;">
          <tr><td style="padding: 8px 0; color: #666; width: 40%;">Location:</td><td style="padding: 8px 0; font-weight: bold; color: #333;">${division}, ${district}, ${province}</td></tr>
          <tr><td style="padding: 8px 0; color: #666;">Driver Name:</td><td style="padding: 8px 0; font-weight: bold; color: #333;">${driverName}</td></tr>
          <tr><td style="padding: 8px 0; color: #666;">License Number:</td><td style="padding: 8px 0; font-weight: bold; color: #333;">${licenseNumber}</td></tr>
          <tr><td style="padding: 8px 0; color: #666;">Timestamp:</td><td style="padding: 8px 0; font-weight: bold; color: #333;">${reportedAt}</td></tr>
        </table>

        ${description ? `
        <div style="background-color: #fff8e1; border: 1px solid #ffecb3; padding: 15px; border-radius: 4px; margin-bottom: 20px;">
          <h4 style="color: #f57f17; margin-top: 0; margin-bottom: 10px;">Details</h4>
          <p style="color: #333; margin: 0; font-size: 14px; line-height: 1.5;">${description}</p>
        </div>
        ` : ''}

        <div style="text-align: center; margin: 25px 0;">
          <a href="${mapsLink}" target="_blank" style="background-color: #d32f2f; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; font-weight: bold; display: inline-block;">View Accident Location</a>
        </div>
      </div>
    </div>
  `;
};

const reportAccident = async (req, res) => {
  const tag = '[AccidentCtrl]';
  console.log(`\n${'═'.repeat(60)}`);
  console.log(`${tag} 🚨 ACCIDENT REPORT SUBMITTED`);
  console.log(`${tag} Timestamp: ${new Date().toISOString()}`);
  console.log(`${tag} Raw Request Body:`, JSON.stringify(req.body, null, 2));
  console.log(`${'═'.repeat(60)}`);

  try {
    // STEP 1 — Validate input
    const { licenseNumber, lat, lng, accidentType, description } = req.body;
    
    if (!licenseNumber || !lat || !lng || !accidentType) {
      console.error(`${tag} ❌ STEP 1 FAILED: Missing required fields`);
      return res.status(400).json({ success: false, message: 'Missing required fields' });
    }

    const validTypes = ['Vehicle Collision', 'Pedestrian Accident', 'Hit & Run', 'Road Hazard / Obstruction', 'Other'];
    if (!validTypes.includes(accidentType)) {
      console.error(`${tag} ❌ STEP 1 FAILED: Invalid accidentType`);
      return res.status(400).json({ success: false, message: 'Invalid accident type' });
    }

    const latitude = parseFloat(lat);
    const longitude = parseFloat(lng);

    if (isNaN(latitude) || isNaN(longitude)) {
      console.error(`${tag} ❌ STEP 1 FAILED: Invalid lat/lng format`);
      return res.status(400).json({ success: false, message: 'Invalid latitude or longitude' });
    }

    const cleanDescription = description ? description.trim().substring(0, 200) : '';
    console.log(`${tag} ✅ STEP 1 OK: Input validated`);

    // STEP 2 — Find Driver
    console.log(`\n${tag} STEP 2: Looking up driver...`);
    const driver = await Driver.findOne({ licenseNumber });
    if (!driver) {
      console.error(`${tag} ❌ STEP 2 FAILED: Driver not found`);
      return res.status(404).json({ success: false, message: 'Driver not found' });
    }
    console.log(`${tag} ✅ STEP 2 OK: Found driver ${driver.name}`);

    // STEP 3 — Resolve GPS to geo fields
    console.log(`\n${tag} STEP 3: Resolving GPS location...`);
    const geoData = resolveLocation(latitude, longitude);
    console.log(`${tag} ✅ STEP 3 OK: ${geoData.province} / ${geoData.district} / ${geoData.policeDivision}`);

    // STEP 4 — Find nearby police officers (5 km $near query)
    console.log(`\n${tag} STEP 4: Finding nearby police officers...`);
    const nearbyOfficers = await Police.find({
      location: {
        $near: {
          $geometry: { type: 'Point', coordinates: [longitude, latitude] },
          $maxDistance: ACCIDENT_RADIUS_METERS
        }
      },
      isActive: true
    }).select('name badgeNumber fcmToken');
    
    const validTokens = nearbyOfficers.map(o => o.fcmToken).filter(t => t && t.length > 10);
    console.log(`${tag} ✅ STEP 4 OK: Found ${nearbyOfficers.length} officer(s), ${validTokens.length} valid token(s)`);

    // STEP 5 — Find police station email
    console.log(`\n${tag} STEP 5: Finding police station email...`);
    let stationName = '';
    let stationEmail = '';
    
    try {
      if (driver.policeStation) {
        const station = await Station.findOne({ name: { $regex: new RegExp(driver.policeStation, 'i') } });
        if (station) {
          stationName = station.name;
          stationEmail = station.officialEmail;
          console.log(`${tag} ✅ STEP 5 OK: Found station email for ${stationName}`);
        } else {
          console.warn(`${tag} ⚠️ STEP 5 WARNING: Station not found for driver.policeStation = ${driver.policeStation}`);
        }
      }
    } catch (err) {
      console.warn(`${tag} ⚠️ STEP 5 WARNING: Error looking up station email - ${err.message}`);
    }

    // STEP 6 — Build FCM payload
    console.log(`\n${tag} STEP 6: Building FCM payload...`);
    const fcmPayload = {
      title: \`🚨 Accident Alert — \${accidentType}\`,
      body: \`Driver \${driver.name} has reported an accident near you. Tap to view location.\`,
      data: {
        type: 'ACCIDENT_ALERT',
        licenseNumber: licenseNumber,
        driverName: driver.name,
        driverPhone: driver.phone || '',
        accidentType: accidentType,
        description: cleanDescription,
        lat: String(latitude),
        lng: String(longitude),
        mapsLink: \`https://maps.google.com/?q=\${latitude},\${longitude}\`,
        province: geoData.province,
        district: geoData.district,
        policeDivision: geoData.policeDivision,
        reportedAt: new Date().toISOString()
      }
    };
    console.log(`${tag} ✅ STEP 6 OK: FCM payload ready`);

    // STEP 7 — Build email HTML
    console.log(`\n${tag} STEP 7: Building email HTML...`);
    const emailHtml = buildEmailHtml({
      driverName: driver.name,
      licenseNumber: licenseNumber,
      driverPhone: driver.phone,
      accidentType: accidentType,
      description: cleanDescription,
      latitude: latitude,
      longitude: longitude,
      mapsLink: \`https://maps.google.com/?q=\${latitude},\${longitude}\`,
      province: geoData.province,
      district: geoData.district,
      division: geoData.policeDivision,
      officersCount: validTokens.length,
      reportedAt: new Date().toLocaleString()
    });
    console.log(`${tag} ✅ STEP 7 OK: Email HTML ready`);

    // STEP 8 — Fire BOTH channels in PARALLEL using Promise.allSettled()
    console.log(`\n${tag} STEP 8: Dispatching FCM and Email in parallel...`);
    const [fcmResult, emailResult] = await Promise.allSettled([
      validTokens.length > 0
        ? sendToMultiple(validTokens, fcmPayload)
        : Promise.resolve({ sent: 0, failed: 0 }),
      stationEmail
        ? sendEmail({
            email: stationEmail,
            subject: \`🚨 ACCIDENT ALERT: \${accidentType} — e-Fine SL\`,
            html: emailHtml
          })
        : Promise.resolve(null)
    ]);

    const fcmSent = fcmResult.status === 'fulfilled' ? (fcmResult.value?.sent || 0) : 0;
    const emailSent = emailResult.status === 'fulfilled' && emailResult.value !== null;
    
    if (fcmResult.status === 'rejected') console.error(`${tag} ❌ FCM Failed:`, fcmResult.reason);
    if (emailResult.status === 'rejected') console.error(`${tag} ❌ Email Failed:`, emailResult.reason);
    
    console.log(`${tag} ✅ STEP 8 OK: Dispatched. FCM sent: ${fcmSent}. Email sent: ${emailSent}`);

    // STEP 9 — Save AccidentReport to MongoDB
    console.log(`\n${tag} STEP 9: Saving accident report to DB...`);
    const report = await AccidentReport.create({
      driverLicense: licenseNumber,
      driverName: driver.name,
      driverPhone: driver.phone || '',
      accidentType,
      description: cleanDescription,
      location: { type: 'Point', coordinates: [longitude, latitude] },
      province: geoData.province,
      district: geoData.district,
      policeDivision: geoData.policeDivision,
      officersNotified: fcmSent,
      stationNotified: stationName,
      stationEmail,
      emailSent,
      status: 'OPEN',
      statusHistory: [{
        status: 'OPEN',
        changedBy: 'System',
        note: 'Report received from driver app'
      }]
    });
    console.log(`${tag} ✅ STEP 9 OK: Saved with ID: ${report._id}`);

    // STEP 10 — Return 201 response
    console.log(`\n${tag} STEP 10: Returning successful response`);
    return res.status(201).json({
      success: true,
      message: \`Accident report submitted. \${fcmSent} officer(s) notified.\`,
      reportId: report._id,
      debug: {
        province: geoData.province,
        district: geoData.district,
        policeDivision: geoData.policeDivision,
        nearbyOfficers: nearbyOfficers.length,
        officersNotified: fcmSent,
        stationEmail: stationEmail || 'Not found',
        emailSent
      }
    });

  } catch (err) {
    console.error(`${tag} ❌ UNHANDLED EXCEPTION:`, err);
    return res.status(500).json({ success: false, message: 'Internal Server Error', error: err.message });
  }
};

const getAccidentReports = async (req, res) => {
  try {
    const { province, district, policeDivision, status, page = 1, limit = 20 } = req.query;
    const filter = {};
    
    if (province && province !== 'all') filter.province = province;
    if (district && district !== 'all') filter.district = district;
    if (policeDivision && policeDivision !== 'all') filter.policeDivision = policeDivision;
    if (status && status !== 'all') filter.status = status;

    const skip = (parseInt(page) - 1) * parseInt(limit);
    
    const [reports, total] = await Promise.all([
      AccidentReport.find(filter).sort({ reportedAt: -1 }).skip(skip).limit(parseInt(limit)),
      AccidentReport.countDocuments(filter)
    ]);

    return res.status(200).json({
      success: true,
      data: reports,
      total,
      page: parseInt(page),
      pages: Math.ceil(total / parseInt(limit))
    });
  } catch (err) {
    console.error('[AccidentCtrl] Error fetching reports:', err);
    return res.status(500).json({ success: false, message: 'Internal Server Error' });
  }
};

const getAccidentReportById = async (req, res) => {
  try {
    const report = await AccidentReport.findById(req.params.id);
    if (!report) return res.status(404).json({ success: false, message: 'Report not found' });
    
    return res.status(200).json({ success: true, data: report });
  } catch (err) {
    console.error('[AccidentCtrl] Error fetching report by ID:', err);
    return res.status(500).json({ success: false, message: 'Internal Server Error' });
  }
};

const updateAccidentStatus = async (req, res) => {
  try {
    const { status, note, adminName } = req.body;
    
    if (!['OPEN', 'ACKNOWLEDGED', 'RESOLVED'].includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid status' });
    }

    const updateObj = {
      status,
      $push: {
        statusHistory: {
          status,
          changedBy: adminName || 'System Admin',
          changedAt: new Date(),
          note
        }
      }
    };

    if (status === 'ACKNOWLEDGED') updateObj.acknowledgedBy = adminName || 'System Admin';
    if (status === 'RESOLVED') updateObj.resolvedBy = adminName || 'System Admin';

    const updatedReport = await AccidentReport.findByIdAndUpdate(
      req.params.id,
      updateObj,
      { new: true }
    );

    if (!updatedReport) return res.status(404).json({ success: false, message: 'Report not found' });

    return res.status(200).json({ 
      success: true, 
      data: updatedReport, 
      message: \`Status updated to \${status}\` 
    });
  } catch (err) {
    console.error('[AccidentCtrl] Error updating status:', err);
    return res.status(500).json({ success: false, message: 'Internal Server Error' });
  }
};

const notifyPoliceDivision = async (req, res) => {
  try {
    const { adminName } = req.body;
    const report = await AccidentReport.findById(req.params.id);
    
    if (!report) return res.status(404).json({ success: false, message: 'Report not found' });

    const station = await Station.findOne({ name: { $regex: new RegExp(report.policeDivision, 'i') } });
    if (!station || !station.officialEmail) {
      return res.status(404).json({ success: false, message: 'Police station email not found for this division' });
    }

    const emailHtml = buildDivisionNotificationHtml({
      reportId: report._id.toString().substring(0, 8).toUpperCase(),
      driverName: report.driverName,
      licenseNumber: report.driverLicense,
      accidentType: report.accidentType,
      description: report.description,
      province: report.province,
      district: report.district,
      division: report.policeDivision,
      mapsLink: \`https://maps.google.com/?q=\${report.location.coordinates[1]},\${report.location.coordinates[0]}\`,
      reportedAt: new Date(report.reportedAt).toLocaleString(),
      sentBy: adminName || 'System Admin'
    });

    await sendEmail({
      email: station.officialEmail,
      subject: \`🚨 ACTION REQUIRED: Accident in Your Division — e-Fine SL\`,
      html: emailHtml
    });

    report.divisionNotifiedAt = new Date();
    report.statusHistory.push({
      status: report.status,
      changedBy: adminName || 'System Admin',
      note: \`Division notification sent to \${station.officialEmail}\`,
      changedAt: new Date()
    });

    await report.save();

    return res.status(200).json({ 
      success: true, 
      message: \`Police division notified at \${station.officialEmail}\` 
    });
  } catch (err) {
    console.error('[AccidentCtrl] Error notifying division:', err);
    return res.status(500).json({ success: false, message: 'Internal Server Error' });
  }
};

const getAccidentStats = async (req, res) => {
  try {
    const [total, open, acknowledged, resolved, byProvince, byType] = await Promise.all([
      AccidentReport.countDocuments(),
      AccidentReport.countDocuments({ status: 'OPEN' }),
      AccidentReport.countDocuments({ status: 'ACKNOWLEDGED' }),
      AccidentReport.countDocuments({ status: 'RESOLVED' }),
      AccidentReport.aggregate([
        { $group: { _id: '$province', count: { $sum: 1 } } },
        { $sort: { count: -1 } }
      ]),
      AccidentReport.aggregate([
        { $group: { _id: '$accidentType', count: { $sum: 1 } } },
        { $sort: { count: -1 } }
      ])
    ]);

    return res.status(200).json({
      success: true,
      stats: { total, open, acknowledged, resolved, byProvince, byType }
    });
  } catch (err) {
    console.error('[AccidentCtrl] Error fetching stats:', err);
    return res.status(500).json({ success: false, message: 'Internal Server Error' });
  }
};

module.exports = {
  reportAccident,
  getAccidentReports,
  getAccidentReportById,
  updateAccidentStatus,
  notifyPoliceDivision,
  getAccidentStats
};
