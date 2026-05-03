# 🚨 e-Fine SL — Accident Report Feature
## Complete Project Plan v2.0
### Covers: Flutter App + Node.js Backend + Next.js Admin Portal

---

## 📌 Project Overview

| Item | Detail |
|------|--------|
| **Mobile Repo** | https://github.com/e-fine-sl/e-fine-sl-traffic-management |
| **Admin Repo** | https://github.com/e-fine-sl/e-fine-Sl-admin-portal |
| **Admin Stack** | Next.js 16, React 19, TypeScript, Tailwind CSS 4, shadcn/ui, Recharts, Axios |
| **Backend Stack** | Node.js, Express 5, MongoDB/Mongoose, Firebase Admin FCM, Nodemailer |
| **Flutter Stack** | Flutter, Provider, Google ML Kit, FCM, Geolocator |

---

## 🧠 Feature Summary

| Role | What They Get |
|------|--------------|
| **Driver** | Taps "Report Accident" → selects type → GPS auto-captured → single tap sends alert |
| **Police Officers (nearby)** | FCM push notification instantly on device |
| **Police Station** | Email with full incident details + Google Maps link |
| **Admin** | Real-time dashboard of all island-wide accident reports, filterable by Province → District → Police Division, can manage status and notify divisions |

---

## 🗺️ End-to-End System Architecture

```
DRIVER taps "Report Accident"
           │
           ▼
   [Flutter ReportScreen]
   Select: Accident Type + Optional Description
   GPS captured automatically
           │
           ▼  POST /api/accident/report
           │  { licenseNumber, lat, lng, accidentType,
           │    description, province, district, division }
           │  (province/district/division resolved on backend
           │   from GPS coordinates using Sri Lanka geo data)
           ▼
┌──────────────────────────────────────────────────────────┐
│           Node.js Backend  /api/accident/report          │
│                                                          │
│  1. Validate input                                       │
│  2. Find Driver by licenseNumber                         │
│  3. Resolve GPS → Province / District / Division         │
│  4. $near query → find nearby Police officers (5 km)     │
│  5. Find nearest Station by driver's policeStation field │
│                                                          │
│  6. Promise.allSettled([                                 │
│       sendToMultiple(officerTokens, fcmPayload),  ─────► FCM → Officer devices
│       sendEmail(stationEmail, htmlTemplate)       ─────► Gmail → Station inbox
│     ])                                                   │
│                                                          │
│  7. Save AccidentReport to MongoDB                       │
│  8. Return 200 with reportId + stats                     │
└──────────────────────────────────────────────────────────┘
           │
           ▼
  [Flutter shows Success Screen]
  "3 officers notified. Station alerted."

           │
           │  (MongoDB AccidentReport saved)
           ▼
┌──────────────────────────────────────────────────────────┐
│              Next.js Admin Portal                        │
│           /accident-reports  (NEW PAGE)                  │
│                                                          │
│  ┌──── LIVE STATS BAR ────────────────────────────────┐  │
│  │ Total Reports | Open | Acknowledged | Resolved     │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
│  ┌──── FILTER BAR ─────────────────────────────────────┐  │
│  │ Province ▼  |  District ▼  |  Division ▼  | Status  │  │
│  │ (9 Provinces) (25 Districts) (Police Divisions)     │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                          │
│  ┌──── REPORTS TABLE ─────────────────────────────────┐  │
│  │ ID | Type | Driver | Location | Division | Status  │  │
│  │  [View] [Acknowledge] [Notify Division] [Resolve]  │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
│  ┌──── DETAIL MODAL ──────────────────────────────────┐  │
│  │ Full report details + Google Maps embed             │  │
│  │ Timeline of status changes                         │  │
│  │ Notify Police Division button                      │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

---

## 🏝️ Sri Lanka Geographic Data (Used for Filtering)

```typescript
// 9 Provinces → 25 Districts → Police Divisions (subset shown)

Provinces & Districts:
  Western:       Colombo, Gampaha, Kalutara
  Central:       Kandy, Matale, Nuwara Eliya
  Southern:      Galle, Matara, Hambantota
  Northern:      Jaffna, Kilinochchi, Mannar, Vavuniya, Mullaitivu
  Eastern:       Trincomalee, Batticaloa, Ampara
  North Western: Kurunegala, Puttalam
  North Central: Anuradhapura, Polonnaruwa
  Uva:           Badulla, Monaragala
  Sabaragamuwa:  Ratnapura, Kegalle

Police Divisions (examples per district):
  Colombo District:   Colombo, Dehiwela, Nugegoda, Kotte, Kelaniya,
                      Moratuwa, Homagama, Kaduwela
  Gampaha District:   Gampaha, Negombo, Ja-Ela, Wattala, Minuwangoda
  Kandy District:     Kandy, Peradeniya, Katugastota, Gampola
  Galle District:     Galle, Hikkaduwa, Elpitiya, Balapitiya
  (... and so on for all 25 districts)
```

---

# 📦 COMPLETE BUILD PLAN

---

## PART A — Backend: New MongoDB Model

### File: `/backend_api/models/accidentReportModel.js`

```javascript
// CREATE NEW FILE
// Collection: "accidentreports"

const mongoose = require('mongoose');

const statusHistorySchema = new mongoose.Schema({
  status:    { type: String },          // OPEN | ACKNOWLEDGED | RESOLVED
  changedBy: { type: String },          // Admin name or "System"
  changedAt: { type: Date, default: Date.now },
  note:      { type: String }           // Optional admin note
}, { _id: false });

const accidentReportSchema = new mongoose.Schema({

  // ── Driver Info ─────────────────────────────────────────────────
  driverLicense: { type: String, required: true },
  driverName:    { type: String, required: true },
  driverPhone:   { type: String },

  // ── Accident Details ─────────────────────────────────────────────
  accidentType: {
    type: String,
    required: true,
    enum: [
      'Vehicle Collision',
      'Pedestrian Accident',
      'Hit & Run',
      'Road Hazard / Obstruction',
      'Other'
    ]
  },
  description: { type: String, maxlength: 200, default: '' },

  // ── Geographic Location ──────────────────────────────────────────
  location: {
    type: {
      type: String,
      enum: ['Point'],
      default: 'Point'
    },
    coordinates: {
      type: [Number],    // [longitude, latitude] — GeoJSON order
      required: true
    }
  },
  // Human-readable location fields (resolved on backend from GPS)
  province:        { type: String, default: 'Unknown' },
  district:        { type: String, default: 'Unknown' },
  policeDivision:  { type: String, default: 'Unknown' },
  locationAddress: { type: String, default: '' },

  // ── Notification Results ─────────────────────────────────────────
  officersNotified:   { type: Number, default: 0 },
  stationNotified:    { type: String, default: '' },
  stationEmail:       { type: String, default: '' },
  emailSent:          { type: Boolean, default: false },
  divisionNotifiedAt: { type: Date, default: null }, // When admin sent division alert

  // ── Status Management ────────────────────────────────────────────
  status: {
    type: String,
    enum: ['OPEN', 'ACKNOWLEDGED', 'RESOLVED'],
    default: 'OPEN'
  },
  acknowledgedBy: { type: String, default: null },
  resolvedBy:     { type: String, default: null },
  statusHistory:  [statusHistorySchema],

  reportedAt: { type: Date, default: Date.now }

}, {
  timestamps: true,
  collection: 'accidentreports'
});

// 2dsphere index for geospatial queries
accidentReportSchema.index({ location: '2dsphere' });
// Compound indexes for admin filters
accidentReportSchema.index({ province: 1, status: 1 });
accidentReportSchema.index({ district: 1, status: 1 });
accidentReportSchema.index({ policeDivision: 1, status: 1 });
accidentReportSchema.index({ reportedAt: -1 });

module.exports = mongoose.model('AccidentReport', accidentReportSchema);
```

---

## PART B — Backend: Sri Lanka Geo Data Helper

### File: `/backend_api/utils/sriLankaGeoHelper.js`

```javascript
// CREATE NEW FILE
// Maps GPS coordinates to Province → District → Police Division
// Uses bounding-box approach (simple, no external API needed)

// Sri Lanka District Bounding Boxes
// Format: [minLat, maxLat, minLng, maxLng]
const DISTRICT_BOUNDS = {
  'Colombo':        { province: 'Western',       bounds: [6.7500, 7.0500, 79.7800, 80.0200] },
  'Gampaha':        { province: 'Western',       bounds: [6.9500, 7.3500, 79.8500, 80.2500] },
  'Kalutara':       { province: 'Western',       bounds: [6.3500, 6.8000, 79.9000, 80.5000] },
  'Kandy':          { province: 'Central',       bounds: [6.9000, 7.5000, 80.3500, 81.2000] },
  'Matale':         { province: 'Central',       bounds: [7.3500, 8.1000, 80.4000, 81.0000] },
  'Nuwara Eliya':   { province: 'Central',       bounds: [6.7500, 7.1000, 80.6000, 81.1000] },
  'Galle':          { province: 'Southern',      bounds: [5.9500, 6.4000, 80.0000, 80.7000] },
  'Matara':         { province: 'Southern',      bounds: [5.8500, 6.2000, 80.4500, 81.2000] },
  'Hambantota':     { province: 'Southern',      bounds: [6.0000, 6.5000, 80.7500, 81.5000] },
  'Jaffna':         { province: 'Northern',      bounds: [9.5000, 9.8500, 79.9000, 80.4000] },
  'Kilinochchi':    { province: 'Northern',      bounds: [8.9500, 9.5000, 80.0000, 80.6000] },
  'Mannar':         { province: 'Northern',      bounds: [8.6500, 9.2000, 79.7500, 80.3000] },
  'Vavuniya':       { province: 'Northern',      bounds: [8.5500, 9.1000, 80.2500, 80.8500] },
  'Mullaitivu':     { province: 'Northern',      bounds: [8.9500, 9.4500, 80.4500, 81.1000] },
  'Trincomalee':    { province: 'Eastern',       bounds: [7.8500, 9.0000, 80.9000, 81.5000] },
  'Batticaloa':     { province: 'Eastern',       bounds: [7.4500, 8.3500, 81.2500, 81.8500] },
  'Ampara':         { province: 'Eastern',       bounds: [6.8500, 7.7000, 81.0500, 81.9500] },
  'Kurunegala':     { province: 'North Western', bounds: [7.2500, 8.0500, 79.9500, 80.8500] },
  'Puttalam':       { province: 'North Western', bounds: [7.7500, 8.5000, 79.6500, 80.3500] },
  'Anuradhapura':   { province: 'North Central', bounds: [7.9000, 9.0000, 80.0500, 81.0500] },
  'Polonnaruwa':    { province: 'North Central', bounds: [7.5500, 8.3500, 80.8000, 81.5000] },
  'Badulla':        { province: 'Uva',           bounds: [6.5500, 7.2000, 80.7500, 81.5000] },
  'Monaragala':     { province: 'Uva',           bounds: [6.1000, 7.0000, 81.0000, 81.9000] },
  'Ratnapura':      { province: 'Sabaragamuwa',  bounds: [6.3500, 6.9500, 80.2500, 81.0000] },
  'Kegalle':        { province: 'Sabaragamuwa',  bounds: [7.0000, 7.4000, 80.1500, 80.7500] },
};

// Police Divisions per District
const POLICE_DIVISIONS = {
  'Colombo':      ['Colombo', 'Dehiwela', 'Nugegoda', 'Sri Jayawardenepura Kotte', 'Kelaniya', 'Moratuwa', 'Homagama', 'Kaduwela', 'Boralesgamuwa'],
  'Gampaha':      ['Gampaha', 'Negombo', 'Ja-Ela', 'Wattala', 'Minuwangoda', 'Divulapitiya', 'Mirigama'],
  'Kalutara':     ['Kalutara', 'Panadura', 'Horana', 'Mathugama', 'Beruwala'],
  'Kandy':        ['Kandy', 'Peradeniya', 'Katugastota', 'Gampola', 'Nawalapitiya', 'Akurana'],
  'Matale':       ['Matale', 'Dambulla', 'Galewela', 'Ukuwela'],
  'Nuwara Eliya': ['Nuwara Eliya', 'Hatton', 'Talawakelle', 'Ragala'],
  'Galle':        ['Galle', 'Hikkaduwa', 'Elpitiya', 'Balapitiya', 'Ambalangoda'],
  'Matara':       ['Matara', 'Weligama', 'Dikwella', 'Akuressa'],
  'Hambantota':   ['Hambantota', 'Tangalle', 'Tissamaharama', 'Beliatta'],
  'Jaffna':       ['Jaffna', 'Chavakachcheri', 'Point Pedro', 'Kilinochchi'],
  'Kilinochchi':  ['Kilinochchi', 'Paranthan'],
  'Mannar':       ['Mannar', 'Murunkan'],
  'Vavuniya':     ['Vavuniya', 'Nedunkerni'],
  'Mullaitivu':   ['Mullaitivu', 'Oddusuddan'],
  'Trincomalee':  ['Trincomalee', 'Kinniya', 'Muttur'],
  'Batticaloa':   ['Batticaloa', 'Kattankudy', 'Valaichenai'],
  'Ampara':       ['Ampara', 'Kalmunai', 'Sammanthurai', 'Pottuvil'],
  'Kurunegala':   ['Kurunegala', 'Kuliyapitiya', 'Nikaweratiya', 'Maho', 'Wariyapola'],
  'Puttalam':     ['Puttalam', 'Chilaw', 'Wennappuwa', 'Marawila'],
  'Anuradhapura': ['Anuradhapura', 'Kekirawa', 'Medawachchiya', 'Mihintale'],
  'Polonnaruwa':  ['Polonnaruwa', 'Medirigiriya', 'Hingurakgoda'],
  'Badulla':      ['Badulla', 'Bandarawela', 'Haputale', 'Welimada', 'Mahiyanganaya'],
  'Monaragala':   ['Monaragala', 'Wellawaya', 'Buttala'],
  'Ratnapura':    ['Ratnapura', 'Embilipitiya', 'Balangoda', 'Pelmadulla'],
  'Kegalle':      ['Kegalle', 'Mawanella', 'Warakapola', 'Rambukkana'],
};

/**
 * Resolves GPS coordinates to Province, District, and Police Division.
 * Uses bounding box lookup — fast, no external API needed.
 *
 * @param {number} lat - Latitude
 * @param {number} lng - Longitude
 * @returns {{ province, district, policeDivision }}
 */
const resolveLocation = (lat, lng) => {
  // Find matching district
  for (const [district, data] of Object.entries(DISTRICT_BOUNDS)) {
    const [minLat, maxLat, minLng, maxLng] = data.bounds;
    if (lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng) {
      // Pick nearest division (first division as default — can be expanded)
      const divisions = POLICE_DIVISIONS[district] || ['Unknown'];
      return {
        province:       data.province,
        district:       district,
        policeDivision: divisions[0]   // Simplification for demo; nearest would need haversine
      };
    }
  }
  return {
    province:       'Unknown',
    district:       'Unknown',
    policeDivision: 'Unknown'
  };
};

module.exports = { resolveLocation, DISTRICT_BOUNDS, POLICE_DIVISIONS };
```

---

## PART C — Backend: Accident Controller

### File: `/backend_api/controllers/accidentController.js`

```javascript
// CREATE NEW FILE

const AccidentReport   = require('../models/accidentReportModel');
const Driver           = require('../models/driverModel');
const Police           = require('../models/policeModel');
const Station          = require('../models/stationModel');
const { sendToMultiple }   = require('../services/fcmService');
const sendEmail            = require('../utils/sendEmail');
const { resolveLocation }  = require('../utils/sriLankaGeoHelper');

const SOS_RADIUS_METERS = 5000; // 5 km — same as SOS

// ─────────────────────────────────────────────────────────────────
// POST /api/accident/report  —  Driver reports an accident
// ─────────────────────────────────────────────────────────────────
const reportAccident = async (req, res) => {
  const tag = '[AccidentCtrl]';
  console.log(`\n${'═'.repeat(60)}`);
  console.log(`${tag} 🚨 ACCIDENT REPORT RECEIVED`);
  console.log(`${tag} Body:`, JSON.stringify(req.body, null, 2));
  console.log(`${'═'.repeat(60)}`);

  const { licenseNumber, lat, lng, accidentType, description } = req.body;

  // ── STEP 1: Validate Input ─────────────────────────────────────
  if (!licenseNumber || lat === undefined || lng === undefined || !accidentType) {
    return res.status(400).json({
      success: false,
      message: 'licenseNumber, lat, lng, and accidentType are required.'
    });
  }

  const validTypes = ['Vehicle Collision', 'Pedestrian Accident', 'Hit & Run',
                      'Road Hazard / Obstruction', 'Other'];
  if (!validTypes.includes(accidentType)) {
    return res.status(400).json({ success: false, message: 'Invalid accidentType value.' });
  }

  const latitude  = parseFloat(lat);
  const longitude = parseFloat(lng);
  if (isNaN(latitude) || isNaN(longitude)) {
    return res.status(400).json({ success: false, message: 'lat and lng must be valid numbers.' });
  }

  const cleanDescription = (description || '').trim().substring(0, 200);
  console.log(`${tag} ✅ STEP 1 OK`);

  try {
    // ── STEP 2: Find Driver ───────────────────────────────────────
    console.log(`${tag} STEP 2: Finding driver: ${licenseNumber}`);
    const driver = await Driver.findOne({ licenseNumber });
    if (!driver) {
      return res.status(404).json({ success: false, message: 'Driver not found.' });
    }
    console.log(`${tag} ✅ STEP 2 OK: ${driver.name}`);

    // ── STEP 3: Resolve GPS → Province / District / Division ──────
    console.log(`${tag} STEP 3: Resolving geo location...`);
    const geoData = resolveLocation(latitude, longitude);
    console.log(`${tag} ✅ STEP 3 OK:`, geoData);

    // ── STEP 4: Find Nearby Officers ──────────────────────────────
    console.log(`${tag} STEP 4: $near query for officers within ${SOS_RADIUS_METERS}m...`);
    const nearbyOfficers = await Police.find({
      location: {
        $near: {
          $geometry: { type: 'Point', coordinates: [longitude, latitude] },
          $maxDistance: SOS_RADIUS_METERS
        }
      },
      isActive: true
    }).select('name badgeNumber fcmToken');

    const validTokens = nearbyOfficers
      .map(o => o.fcmToken)
      .filter(t => t && t.length > 10);

    console.log(`${tag} ✅ STEP 4 OK: ${nearbyOfficers.length} officers found, ${validTokens.length} with valid tokens`);

    // ── STEP 5: Find Station Email ────────────────────────────────
    console.log(`${tag} STEP 5: Finding station for ${driver.policeStation || 'unknown'}...`);
    let stationName  = '';
    let stationEmail = '';
    try {
      const station = await Station.findOne({
        name: { $regex: new RegExp(driver.policeStation || '', 'i') }
      });
      if (station) {
        stationName  = station.name;
        stationEmail = station.officialEmail;
        console.log(`${tag} ✅ STEP 5 OK: Station found: ${stationName} <${stationEmail}>`);
      } else {
        console.warn(`${tag} ⚠️ STEP 5: Station not found — email channel will be skipped.`);
      }
    } catch (e) {
      console.warn(`${tag} ⚠️ STEP 5: Station lookup error (non-fatal): ${e.message}`);
    }

    // ── STEP 6: Build Payloads ────────────────────────────────────
    const mapsLink   = `https://maps.google.com/?q=${latitude},${longitude}`;
    const reportedAt = new Date().toLocaleString('en-LK', { timeZone: 'Asia/Colombo' });

    const fcmPayload = {
      title: `🚨 Accident Alert — ${accidentType}`,
      body:  `Driver ${driver.name} has reported an accident near you. Tap to view location.`,
      data: {
        type:          'ACCIDENT_ALERT',
        licenseNumber,
        driverName:    driver.name,
        driverPhone:   driver.phone || '',
        accidentType,
        description:   cleanDescription,
        lat:           String(latitude),
        lng:           String(longitude),
        mapsLink,
        province:      geoData.province,
        district:      geoData.district,
        policeDivision: geoData.policeDivision,
        reportedAt:    new Date().toISOString()
      }
    };

    const emailHtml = buildEmailHtml({
      driverName:    driver.name,
      licenseNumber,
      driverPhone:   driver.phone || 'N/A',
      accidentType,
      description:   cleanDescription,
      latitude,
      longitude,
      mapsLink,
      province:      geoData.province,
      district:      geoData.district,
      division:      geoData.policeDivision,
      officersCount: validTokens.length,
      reportedAt
    });

    // ── STEP 7: Fire Both Channels in Parallel ────────────────────
    console.log(`${tag} STEP 7: Firing FCM + Email in parallel...`);
    const [fcmResult, emailResult] = await Promise.allSettled([
      validTokens.length > 0
        ? sendToMultiple(validTokens, fcmPayload)
        : Promise.resolve({ sent: 0, failed: 0 }),
      stationEmail
        ? sendEmail({
            email:   stationEmail,
            subject: `🚨 ACCIDENT ALERT: ${accidentType} — e-Fine SL`,
            html:    emailHtml
          })
        : Promise.resolve(null)
    ]);

    const fcmSent   = fcmResult.status === 'fulfilled' ? (fcmResult.value?.sent || 0) : 0;
    const emailSent = emailResult.status === 'fulfilled' && emailResult.value !== null;

    console.log(`${tag} ✅ STEP 7: FCM sent=${fcmSent}, emailSent=${emailSent}`);

    // ── STEP 8: Save Report to MongoDB ────────────────────────────
    console.log(`${tag} STEP 8: Saving AccidentReport to DB...`);
    const report = await AccidentReport.create({
      driverLicense:   licenseNumber,
      driverName:      driver.name,
      driverPhone:     driver.phone || '',
      accidentType,
      description:     cleanDescription,
      location: {
        type:        'Point',
        coordinates: [longitude, latitude]
      },
      province:        geoData.province,
      district:        geoData.district,
      policeDivision:  geoData.policeDivision,
      officersNotified: fcmSent,
      stationNotified: stationName,
      stationEmail,
      emailSent,
      status:          'OPEN',
      statusHistory: [{
        status:    'OPEN',
        changedBy: 'System',
        note:      'Report received from driver app'
      }]
    });

    console.log(`${tag} ✅ STEP 8: Report saved. ID: ${report._id}`);
    console.log(`${'═'.repeat(60)}\n`);

    // ── STEP 9: Respond ───────────────────────────────────────────
    return res.status(201).json({
      success: true,
      message: `Accident report submitted. ${fcmSent} officer(s) notified.`,
      reportId: report._id,
      debug: {
        province:      geoData.province,
        district:      geoData.district,
        policeDivision: geoData.policeDivision,
        nearbyOfficers: nearbyOfficers.length,
        officersNotified: fcmSent,
        stationEmail:  stationEmail || 'Not found',
        emailSent
      }
    });

  } catch (err) {
    console.error(`${tag} ❌ UNHANDLED ERROR:`, err.message);
    return res.status(500).json({ success: false, message: 'Internal Server Error', error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
// GET /api/accident/reports  — Admin fetches all reports with filters
// ─────────────────────────────────────────────────────────────────
const getAccidentReports = async (req, res) => {
  try {
    const { province, district, policeDivision, status, page = 1, limit = 20 } = req.query;
    const filter = {};

    if (province && province !== 'all')        filter.province       = province;
    if (district && district !== 'all')        filter.district       = district;
    if (policeDivision && policeDivision !== 'all') filter.policeDivision = policeDivision;
    if (status && status !== 'all')            filter.status         = status;

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const [reports, total] = await Promise.all([
      AccidentReport.find(filter)
        .sort({ reportedAt: -1 })
        .skip(skip)
        .limit(parseInt(limit)),
      AccidentReport.countDocuments(filter)
    ]);

    return res.status(200).json({
      success: true,
      data:    reports,
      total,
      page:    parseInt(page),
      pages:   Math.ceil(total / parseInt(limit))
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
// GET /api/accident/reports/:id  — Single report detail for admin
// ─────────────────────────────────────────────────────────────────
const getAccidentReportById = async (req, res) => {
  try {
    const report = await AccidentReport.findById(req.params.id);
    if (!report) return res.status(404).json({ success: false, message: 'Report not found.' });
    return res.status(200).json({ success: true, data: report });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
// PATCH /api/accident/reports/:id/status  — Admin updates status
// ─────────────────────────────────────────────────────────────────
const updateAccidentStatus = async (req, res) => {
  try {
    const { status, note, adminName } = req.body;
    const validStatuses = ['OPEN', 'ACKNOWLEDGED', 'RESOLVED'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid status.' });
    }

    const update = {
      status,
      $push: {
        statusHistory: {
          status,
          changedBy: adminName || 'Admin',
          changedAt: new Date(),
          note: note || ''
        }
      }
    };

    if (status === 'ACKNOWLEDGED') update.acknowledgedBy = adminName || 'Admin';
    if (status === 'RESOLVED')     update.resolvedBy     = adminName || 'Admin';

    const report = await AccidentReport.findByIdAndUpdate(req.params.id, update, { new: true });
    if (!report) return res.status(404).json({ success: false, message: 'Report not found.' });

    return res.status(200).json({ success: true, data: report, message: `Status updated to ${status}` });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
// POST /api/accident/reports/:id/notify-division
// Admin manually notifies the police division via email
// ─────────────────────────────────────────────────────────────────
const notifyPoliceDivision = async (req, res) => {
  try {
    const { adminName } = req.body;
    const report = await AccidentReport.findById(req.params.id);
    if (!report) return res.status(404).json({ success: false, message: 'Report not found.' });

    // Find station by police division name
    const station = await Station.findOne({
      name: { $regex: new RegExp(report.policeDivision, 'i') }
    });

    if (!station) {
      return res.status(404).json({
        success: false,
        message: `No station found for division: ${report.policeDivision}`
      });
    }

    const mapsLink = `https://maps.google.com/?q=${report.location.coordinates[1]},${report.location.coordinates[0]}`;

    const emailHtml = buildDivisionNotificationHtml({
      reportId:      report._id,
      driverName:    report.driverName,
      licenseNumber: report.driverLicense,
      accidentType:  report.accidentType,
      description:   report.description,
      province:      report.province,
      district:      report.district,
      division:      report.policeDivision,
      mapsLink,
      reportedAt:    report.reportedAt.toLocaleString('en-LK', { timeZone: 'Asia/Colombo' }),
      sentBy:        adminName || 'Admin'
    });

    await sendEmail({
      email:   station.officialEmail,
      subject: `🚨 ACTION REQUIRED — Accident in Your Division: ${report.accidentType}`,
      html:    emailHtml
    });

    // Update report to record division notification
    await AccidentReport.findByIdAndUpdate(report._id, {
      divisionNotifiedAt: new Date(),
      $push: {
        statusHistory: {
          status:    report.status,
          changedBy: adminName || 'Admin',
          note:      `Division notification sent to ${station.officialEmail}`
        }
      }
    });

    return res.status(200).json({
      success: true,
      message: `Police division notified at ${station.officialEmail}`
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
// GET /api/accident/stats  — Admin dashboard summary stats
// ─────────────────────────────────────────────────────────────────
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
    return res.status(500).json({ success: false, message: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────
// Email HTML Template Builders
// ─────────────────────────────────────────────────────────────────
const buildEmailHtml = ({ driverName, licenseNumber, driverPhone, accidentType,
  description, latitude, longitude, mapsLink, province, district,
  division, officersCount, reportedAt }) => `
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>Accident Alert</title></head>
<body style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;background:#f5f5f5;padding:20px;">
  <div style="background:#dc2626;color:white;padding:24px;border-radius:8px 8px 0 0;text-align:center;">
    <h1 style="margin:0;font-size:28px;">🚨 ACCIDENT ALERT</h1>
    <p style="margin:8px 0 0;">e-Fine SL Traffic Management System</p>
  </div>
  <div style="background:white;padding:24px;border-radius:0 0 8px 8px;border:1px solid #ddd;">
    <div style="background:#fee2e2;border:1px solid #dc2626;border-radius:6px;padding:16px;margin-bottom:20px;text-align:center;">
      <h2 style="margin:0;color:#dc2626;font-size:22px;">${accidentType}</h2>
      <p style="margin:4px 0 0;color:#666;">Reported at: ${reportedAt}</p>
    </div>
    <table style="width:100%;border-collapse:collapse;">
      <tr><td colspan="2" style="background:#f3f4f6;padding:10px;font-weight:bold;border-radius:4px;">👤 DRIVER DETAILS</td></tr>
      <tr><td style="padding:8px;border-bottom:1px solid #eee;color:#666;width:40%;">Name</td><td style="padding:8px;border-bottom:1px solid #eee;font-weight:600;">${driverName}</td></tr>
      <tr><td style="padding:8px;border-bottom:1px solid #eee;color:#666;">License No.</td><td style="padding:8px;border-bottom:1px solid #eee;font-weight:600;">${licenseNumber}</td></tr>
      <tr><td style="padding:8px;border-bottom:1px solid #eee;color:#666;">Phone</td><td style="padding:8px;border-bottom:1px solid #eee;font-weight:600;">${driverPhone}</td></tr>
    </table>
    <table style="width:100%;border-collapse:collapse;margin-top:16px;">
      <tr><td colspan="2" style="background:#f3f4f6;padding:10px;font-weight:bold;border-radius:4px;">📍 LOCATION</td></tr>
      <tr><td style="padding:8px;border-bottom:1px solid #eee;color:#666;width:40%;">Province</td><td style="padding:8px;border-bottom:1px solid #eee;">${province}</td></tr>
      <tr><td style="padding:8px;border-bottom:1px solid #eee;color:#666;">District</td><td style="padding:8px;border-bottom:1px solid #eee;">${district}</td></tr>
      <tr><td style="padding:8px;border-bottom:1px solid #eee;color:#666;">Division</td><td style="padding:8px;border-bottom:1px solid #eee;">${division}</td></tr>
      <tr><td style="padding:8px;border-bottom:1px solid #eee;color:#666;">GPS</td><td style="padding:8px;border-bottom:1px solid #eee;">${latitude}°N, ${longitude}°E</td></tr>
    </table>
    <div style="text-align:center;margin:20px 0;">
      <a href="${mapsLink}" style="background:#2563eb;color:white;padding:12px 24px;border-radius:6px;text-decoration:none;font-weight:bold;">📍 View on Google Maps</a>
    </div>
    ${description ? `<div style="background:#fffbeb;border:1px solid #f59e0b;border-radius:6px;padding:12px;margin-bottom:16px;"><strong>Description:</strong> ${description}</div>` : ''}
    <p style="color:#666;font-size:13px;border-top:1px solid #eee;padding-top:12px;margin-top:16px;">
      ${officersCount} nearby police officer(s) have also been notified via the e-Fine SL mobile app.<br>
      This is an automated alert from the e-Fine SL Traffic Management System. Do not reply to this email.
    </p>
  </div>
</body>
</html>
`;

const buildDivisionNotificationHtml = ({ reportId, driverName, licenseNumber,
  accidentType, description, province, district, division, mapsLink, reportedAt, sentBy }) => `
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;background:#f5f5f5;padding:20px;">
  <div style="background:#7c3aed;color:white;padding:24px;border-radius:8px 8px 0 0;text-align:center;">
    <h1 style="margin:0;">🚨 ACTION REQUIRED</h1>
    <p style="margin:8px 0 0;">Accident in Your Police Division — Admin Alert</p>
  </div>
  <div style="background:white;padding:24px;border-radius:0 0 8px 8px;border:1px solid #ddd;">
    <p style="background:#ede9fe;border-radius:6px;padding:12px;">This alert was manually sent by <strong>${sentBy}</strong> from the e-Fine SL Admin Portal. Report ID: <code>${reportId}</code></p>
    <h3 style="color:#dc2626;">${accidentType}</h3>
    <p><strong>Division:</strong> ${division}, ${district}, ${province} Province</p>
    <p><strong>Driver:</strong> ${driverName} — License: ${licenseNumber}</p>
    <p><strong>Reported:</strong> ${reportedAt}</p>
    ${description ? `<p><strong>Details:</strong> ${description}</p>` : ''}
    <div style="text-align:center;margin:20px 0;">
      <a href="${mapsLink}" style="background:#dc2626;color:white;padding:12px 24px;border-radius:6px;text-decoration:none;font-weight:bold;">📍 View Accident Location</a>
    </div>
    <p style="color:#888;font-size:12px;border-top:1px solid #eee;padding-top:12px;">e-Fine SL Traffic Management System — Admin Portal</p>
  </div>
</body>
</html>
`;

module.exports = {
  reportAccident,
  getAccidentReports,
  getAccidentReportById,
  updateAccidentStatus,
  notifyPoliceDivision,
  getAccidentStats
};
```

---

## PART D — Backend: Routes & Server Update

### File: `/backend_api/routes/accidentRoutes.js`

```javascript
// CREATE NEW FILE

const express    = require('express');
const router     = express.Router();
const { protect } = require('../middleware/authMiddleware'); // existing middleware
const {
  reportAccident,
  getAccidentReports,
  getAccidentReportById,
  updateAccidentStatus,
  notifyPoliceDivision,
  getAccidentStats
} = require('../controllers/accidentController');

// ── Driver Routes (public / borderline auth — same pattern as SOS) ──
router.post('/report', reportAccident);

// ── Admin Routes (protected) ─────────────────────────────────────────
router.get('/reports',                      protect, getAccidentReports);
router.get('/reports/stats',                protect, getAccidentStats);
router.get('/reports/:id',                  protect, getAccidentReportById);
router.patch('/reports/:id/status',         protect, updateAccidentStatus);
router.post('/reports/:id/notify-division', protect, notifyPoliceDivision);

module.exports = router;
```

### Update: `/backend_api/server.js`

```javascript
// FIND the block of route registrations (around line 27-30)
// ADD this line:
app.use('/api/accident', require('./routes/accidentRoutes'));  // 🚨 Accident Reports
```

---

## PART E — Admin Portal: Types Update

### Update: `/types/index.ts`

```typescript
// ADD these new types at the bottom of the file:

// ── Accident Report Types ─────────────────────────────────────────

export type AccidentStatus = 'OPEN' | 'ACKNOWLEDGED' | 'RESOLVED';

export type AccidentType =
  | 'Vehicle Collision'
  | 'Pedestrian Accident'
  | 'Hit & Run'
  | 'Road Hazard / Obstruction'
  | 'Other';

export interface StatusHistoryEntry {
  status:    AccidentStatus;
  changedBy: string;
  changedAt: string;
  note?:     string;
}

export interface AccidentReport {
  _id:            string;
  driverLicense:  string;
  driverName:     string;
  driverPhone:    string;
  accidentType:   AccidentType;
  description:    string;
  location: {
    type:        'Point';
    coordinates: [number, number];   // [lng, lat]
  };
  province:        string;
  district:        string;
  policeDivision:  string;
  officersNotified: number;
  stationNotified:  string;
  emailSent:        boolean;
  divisionNotifiedAt: string | null;
  status:           AccidentStatus;
  acknowledgedBy:   string | null;
  resolvedBy:       string | null;
  statusHistory:    StatusHistoryEntry[];
  reportedAt:       string;
  createdAt:        string;
  updatedAt:        string;
}

export interface AccidentStatsResponse {
  total:        number;
  open:         number;
  acknowledged: number;
  resolved:     number;
  byProvince:   { _id: string; count: number }[];
  byType:       { _id: string; count: number }[];
}

// ── Sri Lanka Geo Constants ──────────────────────────────────────

export const SL_PROVINCES = [
  'Western', 'Central', 'Southern', 'Northern',
  'Eastern', 'North Western', 'North Central', 'Uva', 'Sabaragamuwa'
] as const;

export const SL_DISTRICTS: Record<string, string[]> = {
  'Western':       ['Colombo', 'Gampaha', 'Kalutara'],
  'Central':       ['Kandy', 'Matale', 'Nuwara Eliya'],
  'Southern':      ['Galle', 'Matara', 'Hambantota'],
  'Northern':      ['Jaffna', 'Kilinochchi', 'Mannar', 'Vavuniya', 'Mullaitivu'],
  'Eastern':       ['Trincomalee', 'Batticaloa', 'Ampara'],
  'North Western': ['Kurunegala', 'Puttalam'],
  'North Central': ['Anuradhapura', 'Polonnaruwa'],
  'Uva':           ['Badulla', 'Monaragala'],
  'Sabaragamuwa':  ['Ratnapura', 'Kegalle'],
};

export const SL_POLICE_DIVISIONS: Record<string, string[]> = {
  'Colombo':        ['Colombo', 'Dehiwela', 'Nugegoda', 'Sri Jayawardenepura Kotte', 'Kelaniya', 'Moratuwa', 'Homagama', 'Kaduwela'],
  'Gampaha':        ['Gampaha', 'Negombo', 'Ja-Ela', 'Wattala', 'Minuwangoda'],
  'Kalutara':       ['Kalutara', 'Panadura', 'Horana', 'Mathugama'],
  'Kandy':          ['Kandy', 'Peradeniya', 'Katugastota', 'Gampola', 'Nawalapitiya'],
  'Matale':         ['Matale', 'Dambulla', 'Galewela'],
  'Nuwara Eliya':   ['Nuwara Eliya', 'Hatton', 'Talawakelle'],
  'Galle':          ['Galle', 'Hikkaduwa', 'Elpitiya', 'Ambalangoda'],
  'Matara':         ['Matara', 'Weligama', 'Dikwella', 'Akuressa'],
  'Hambantota':     ['Hambantota', 'Tangalle', 'Tissamaharama'],
  'Jaffna':         ['Jaffna', 'Chavakachcheri', 'Point Pedro'],
  'Kilinochchi':    ['Kilinochchi', 'Paranthan'],
  'Mannar':         ['Mannar', 'Murunkan'],
  'Vavuniya':       ['Vavuniya', 'Nedunkerni'],
  'Mullaitivu':     ['Mullaitivu', 'Oddusuddan'],
  'Trincomalee':    ['Trincomalee', 'Kinniya', 'Muttur'],
  'Batticaloa':     ['Batticaloa', 'Kattankudy', 'Valaichenai'],
  'Ampara':         ['Ampara', 'Kalmunai', 'Sammanthurai'],
  'Kurunegala':     ['Kurunegala', 'Kuliyapitiya', 'Nikaweratiya', 'Wariyapola'],
  'Puttalam':       ['Puttalam', 'Chilaw', 'Wennappuwa'],
  'Anuradhapura':   ['Anuradhapura', 'Kekirawa', 'Medawachchiya'],
  'Polonnaruwa':    ['Polonnaruwa', 'Medirigiriya', 'Hingurakgoda'],
  'Badulla':        ['Badulla', 'Bandarawela', 'Haputale', 'Welimada'],
  'Monaragala':     ['Monaragala', 'Wellawaya', 'Buttala'],
  'Ratnapura':      ['Ratnapura', 'Embilipitiya', 'Balangoda'],
  'Kegalle':        ['Kegalle', 'Mawanella', 'Warakapola'],
};
```

---

## PART F — Admin Portal: Accident Reports Page

### File: `/app/(dashboard)/accident-reports/page.tsx`

```
CREATE NEW FILE at:
/app/(dashboard)/accident-reports/page.tsx

Tech used (all already in project):
  - React 19 useState/useEffect
  - axios via @/lib/api
  - shadcn/ui: Card, Button, Badge, Dialog, Select
  - lucide-react icons
  - sonner toast
  - Types from @/types

─────────────────────────────────────────────────────────────────
PAGE STRUCTURE (AccidentReportsPage component):
─────────────────────────────────────────────────────────────────

STATE:
  reports:        AccidentReport[]
  stats:          AccidentStatsResponse | null
  loading:        boolean
  statsLoading:   boolean
  selectedReport: AccidentReport | null
  isDetailOpen:   boolean
  isNotifying:    boolean
  page:           number
  total:          number
  filters: {
    province:       string   // '' = all
    district:       string   // '' = all
    policeDivision: string   // '' = all
    status:         string   // '' = all
  }

─────────────────────────────────────────────────────────────────
FUNCTIONS:
─────────────────────────────────────────────────────────────────

fetchStats():
  GET /api/accident/reports/stats
  → setStats(response.data.stats)

fetchReports():
  GET /api/accident/reports
  params: { ...filters, page, limit: 20 }
  All empty strings become undefined (don't send to API)
  → setReports(response.data.data)
  → setTotal(response.data.total)

handleStatusChange(reportId, newStatus):
  PATCH /api/accident/reports/:id/status
  body: { status: newStatus, adminName: user.name }
  On success:
    toast.success("Status updated to ${newStatus}")
    fetchReports() — refresh list
    fetchStats()   — refresh stats
    Close detail modal if open

handleNotifyDivision(reportId):
  setIsNotifying(true)
  POST /api/accident/reports/:id/notify-division
  body: { adminName: user.name }
  On success:
    toast.success("Police division notified successfully")
    fetchReports()
  On error:
    toast.error(error message)
  setIsNotifying(false)

handleProvinceChange(province):
  setFilters({ ...filters, province, district: '', policeDivision: '' })
  setPage(1)
  (district and division cascade reset when province changes)

handleDistrictChange(district):
  setFilters({ ...filters, district, policeDivision: '' })
  setPage(1)

─────────────────────────────────────────────────────────────────
EFFECTS:
─────────────────────────────────────────────────────────────────

useEffect:
  fetchStats()
  fetchReports()
  [on mount]

useEffect:
  fetchReports()
  [when filters or page changes — debounce 300ms]

─────────────────────────────────────────────────────────────────
RENDER — Page Layout:
─────────────────────────────────────────────────────────────────

1. PAGE HEADER
   Title: "🚨 Accident Reports"
   Subtitle: "Monitor and manage accident reports from all over Sri Lanka"

2. STATS CARDS ROW (4 cards using shadcn Card)
   ┌──────────┐ ┌──────────┐ ┌──────────────┐ ┌──────────┐
   │  Total   │ │  OPEN    │ │ ACKNOWLEDGED │ │ RESOLVED │
   │  {total} │ │  {open}  │ │   {acked}    │ │ {resolved}│
   │ AlertTriangle│ │ red  │ │   amber      │ │  green   │
   └──────────┘ └──────────┘ └──────────────┘ └──────────┘

3. FILTER BAR (Card with CardContent)
   Row of 4 Select dropdowns using shadcn Select:

   a. Province Select:
      Placeholder: "All Provinces"
      Options: "All Provinces" + SL_PROVINCES array
      onChange: handleProvinceChange

   b. District Select:
      Placeholder: "All Districts"
      Disabled if no province selected
      Options: "All Districts" + SL_DISTRICTS[selectedProvince] || all districts
      onChange: handleDistrictChange

   c. Police Division Select:
      Placeholder: "All Divisions"
      Disabled if no district selected
      Options: "All Divisions" + SL_POLICE_DIVISIONS[selectedDistrict] || []
      onChange: setFilters + setPage(1)

   d. Status Select:
      Placeholder: "All Statuses"
      Options: All Statuses | OPEN | ACKNOWLEDGED | RESOLVED

   e. Clear Filters Button (outline):
      Resets all filters to '' and page to 1

4. REPORTS TABLE (Card)
   CardHeader: "Reports ({total})" + pagination info "Page X of Y"
   
   Table columns:
     - Report ID  (first 8 chars of _id, monospace)
     - Type       (accident type with emoji icon)
     - Driver     (name + license number below)
     - Location   (division, district — 2 lines)
     - Province   (badge with province color)
     - Officers   (count badge, blue)
     - Status     (colored badge: red=OPEN, amber=ACKNOWLEDGED, green=RESOLVED)
     - Reported   (date + time, relative)
     - Actions    (View button)

   Loading state: spinner centered
   Empty state: "No accident reports found" with appropriate icon

   Status Badge Colors:
     OPEN:         bg-red-100 text-red-700
     ACKNOWLEDGED: bg-amber-100 text-amber-700
     RESOLVED:     bg-green-100 text-green-700

   Province Badge Colors (rotate through):
     Western:       bg-blue-100 text-blue-700
     Central:       bg-purple-100 text-purple-700
     Southern:      bg-orange-100 text-orange-700
     Northern:      bg-gray-100 text-gray-700
     (etc.)

5. PAGINATION
   Previous | Page X of Y | Next
   Disabled when on first/last page

6. DETAIL DIALOG (shadcn Dialog)
   Opens when View button clicked
   selectedReport must not be null

   DIALOG CONTENT (max-width: 2xl):

   Header:
     Title: "Accident Report Details"
     Description: "Report ID: {selectedReport._id}"

   Body sections:

   Section A — Status & Actions (top row):
     Current status badge (colored)
     Three action buttons:
       - "Mark Acknowledged" (amber) — disabled if already ACKNOWLEDGED or RESOLVED
       - "Mark Resolved"     (green) — disabled if already RESOLVED
       - "Notify Division"   (purple, with Mail icon)
         Shows spinner when isNotifying=true

   Section B — Incident Info (grid 2 cols):
     Accident Type (with icon)
     Reported At (formatted date time)
     Description (full text, or "No description" in gray)

   Section C — Driver Info (card):
     Driver Name
     License Number
     Phone Number

   Section D — Location (card):
     Province
     District
     Police Division (highlighted in bold)
     GPS Coordinates (lat, lng)
     "Open in Google Maps" link button → opens new tab

   Section E — Notification Summary (card):
     Officers Notified: {count}
     Station Email Sent: Yes/No (badge)
     Station Name: {stationNotified}
     Division Notified by Admin: Yes/No + timestamp if yes

   Section F — Status History (timeline):
     For each entry in statusHistory (newest first):
       Dot (colored by status) + Status name + Changed by + Date + Note

   Footer:
     Close button

─────────────────────────────────────────────────────────────────
ACCIDENT TYPE ICONS (map in component):
─────────────────────────────────────────────────────────────────
  'Vehicle Collision':         🚗
  'Pedestrian Accident':       🚶
  'Hit & Run':                 🏃
  'Road Hazard / Obstruction': ⚠️
  'Other':                     📋
```

---

## PART G — Admin Portal: Sidebar & Constants Update

### Update: `/components/layout/Sidebar.tsx`

```typescript
// FIND the navigation array
// ADD this entry after 'Reports':

{ name: 'Accident Reports', href: '/accident-reports', icon: AlertCircle },

// ADD this import at the top:
import { ..., AlertCircle } from 'lucide-react';
```

### Update: `/lib/constants.ts`

```typescript
// ADD at the bottom of constants.ts:

// Sri Lanka Provinces
export const SL_PROVINCES = [
  'Western', 'Central', 'Southern', 'Northern',
  'Eastern', 'North Western', 'North Central', 'Uva', 'Sabaragamuwa'
] as const;

// Accident Report Statuses
export const ACCIDENT_STATUSES = [
  { value: 'OPEN',         label: 'Open',         color: 'bg-red-100 text-red-700'   },
  { value: 'ACKNOWLEDGED', label: 'Acknowledged', color: 'bg-amber-100 text-amber-700' },
  { value: 'RESOLVED',     label: 'Resolved',     color: 'bg-green-100 text-green-700' }
] as const;

// Accident Types
export const ACCIDENT_TYPES = [
  { value: 'Vehicle Collision',         icon: '🚗' },
  { value: 'Pedestrian Accident',       icon: '🚶' },
  { value: 'Hit & Run',                 icon: '🏃' },
  { value: 'Road Hazard / Obstruction', icon: '⚠️' },
  { value: 'Other',                     icon: '📋' },
] as const;
```

---

## PART H — Flutter App Changes (From v1.0 Plan — No Changes)

> All Flutter changes from the original plan remain identical.
> ReportScreen, AccidentService, driver_home_screen.dart update — see original plan.
> The backend now returns `province`, `district`, `policeDivision` in the response
> which can be displayed on the Flutter success screen.

### Minor Addition to Flutter Success Screen:

```dart
// After "N officers notified", also show:
Text(
  'Province: ${result['debug']['province']}\n'
  'District: ${result['debug']['district']}\n'
  'Division: ${result['debug']['policeDivision']}',
  style: TextStyle(color: Colors.grey[600], fontSize: 13),
  textAlign: TextAlign.center,
)
```

---

## 🗂️ Complete Files Summary

### Backend (existing repo)
| File | Action |
|------|--------|
| `models/accidentReportModel.js` | CREATE — 6 fields groups, 4 indexes |
| `utils/sriLankaGeoHelper.js` | CREATE — 25 districts bounding box lookup |
| `controllers/accidentController.js` | CREATE — 6 functions |
| `routes/accidentRoutes.js` | CREATE — 5 routes |
| `server.js` | UPDATE — 1 line add |

### Admin Portal (separate repo)
| File | Action |
|------|--------|
| `types/index.ts` | UPDATE — add 6 new types + geo constants |
| `lib/constants.ts` | UPDATE — add accident constants |
| `components/layout/Sidebar.tsx` | UPDATE — add nav item |
| `app/(dashboard)/accident-reports/page.tsx` | CREATE — full page |

### Flutter App (existing repo)
| File | Action |
|------|--------|
| `config/app_constants.dart` | UPDATE — add URL |
| `services/accident_service.dart` | CREATE |
| `screens/driver/report_screen.dart` | CREATE |
| `screens/driver/driver_home_screen.dart` | UPDATE — wire button |

---

## 🔄 Admin Portal User Flow

```
Admin opens /accident-reports

  → Stats cards show: Total | Open | Acknowledged | Resolved counts

  → Table shows all reports island-wide (newest first)

  → Admin applies filters:
      Province: "Western" 
        → District dropdown auto-updates to: Colombo, Gampaha, Kalutara
      District: "Colombo"
        → Division dropdown auto-updates to: Colombo, Dehiwela, Nugegoda...
      Division: "Moratuwa"
        → Table filters to only Moratuwa reports

  → Admin clicks "View" on a report
      → Detail modal opens with:
         - Full incident info
         - Driver details  
         - Police Division highlighted
         - GPS + Google Maps link
         - Status timeline
         - Action buttons

  → Admin clicks "Mark Acknowledged"
      → Status changes, history logged with admin name

  → Admin clicks "Notify Division"  
      → Email sent to police division's official email
      → "Division Notified" timestamp recorded on report
      → Toast: "Police division notified successfully"

  → Admin clicks "Mark Resolved"
      → Report marked resolved, removed from Open count
```

---

## 🧪 Testing Scenarios

### Backend Tests (Postman)
```
POST /api/accident/report
Body: { licenseNumber:"B1234567", lat:6.9271, lng:79.8612, accidentType:"Vehicle Collision" }
Expected: 201 with province, district, division resolved

GET  /api/accident/reports?province=Western&status=OPEN
Expected: Filtered results

PATCH /api/accident/reports/:id/status
Body: { status:"ACKNOWLEDGED", adminName:"Super Admin" }
Expected: Status updated, history appended

POST /api/accident/reports/:id/notify-division
Expected: Email sent to division station, divisionNotifiedAt set
```

### Admin Portal Tests
```
[ ] Stats cards load correctly
[ ] Province filter populates district dropdown
[ ] District filter populates division dropdown
[ ] Clearing filters resets all dropdowns
[ ] Acknowledge button disabled on non-OPEN reports
[ ] Resolve button disabled on RESOLVED reports
[ ] Notify Division fires email and shows timestamp
[ ] Status history shows correct timeline
[ ] Google Maps link opens correct location
[ ] Pagination works correctly
```

---

## 🚀 Implementation Order

```
Step 1  ─ Create sriLankaGeoHelper.js (utility — no deps)
Step 2  ─ Create accidentReportModel.js
Step 3  ─ Create accidentController.js
Step 4  ─ Create accidentRoutes.js
Step 5  ─ Update server.js (1 line)
Step 6  ─ Test all backend endpoints in Postman
Step 7  ─ Update types/index.ts in admin portal
Step 8  ─ Update lib/constants.ts in admin portal
Step 9  ─ Update Sidebar.tsx in admin portal
Step 10 ─ Create accident-reports/page.tsx in admin portal
Step 11 ─ Test admin portal accident reports page
Step 12 ─ Create accident_service.dart in Flutter
Step 13 ─ Create report_screen.dart in Flutter
Step 14 ─ Update driver_home_screen.dart
Step 15 ─ End-to-end test: Driver reports → Officers notified → Station emailed → Admin sees report
```

---

**Document Version:** 2.0  
**Feature:** Accident Report — Full Stack  
**Date:** 2026-04-29  
**Covers:** Flutter App + Node.js Backend + Next.js Admin Portal
