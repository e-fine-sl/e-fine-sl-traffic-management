# 🏛️ e-Fine SL — DMT License Verification System
## Complete Implementation Plan & Prompt Guide

---

## 📌 Project Context

| Item | Detail |
|------|--------|
| **Main Repository** | https://github.com/e-fine-sl/e-fine-sl-traffic-management |
| **Main Backend URL** | `https://e-fine-sl-traffic-management-1.onrender.com/api` |
| **Auth Service URL** | `https://e-fine-sl-auth-service.onrender.com` |
| **DMT Server** | Separate repository — hosted on Render |
| **DMT Dummy Data** | 50–60 hardcoded realistic Sri Lankan license records |
| **DMT Fallback** | Block registration — DMT check is mandatory |

---

## 🎯 Confirmed Requirements

| # | Requirement | Answer |
|---|-------------|--------|
| 1 | DMT server hosting | **Separate GitHub repository, deployed on Render** |
| 2 | Dummy data size | **50–60 hardcoded records (realistic demo)** |
| 3 | DMT unreachable behaviour | **Block registration — mandatory check** |
| 4 | Verification input | **License Number + NIC Number** |
| 5 | API Response | **Valid flag + full driver details** |
| 6 | Existing e-Fine SL check | **Keep — runs BEFORE DMT check** |

---

## 🗺️ Complete System Architecture

```
Driver Registration Flow (After Changes):
──────────────────────────────────────────────────────────

  [Flutter App — driver_signup_screen.dart]
          │
          │  User types License Number (500ms debounce triggers)
          │
          ├──────────────────────────────────────────────────────────┐
          │                                                          │
          ▼  CHECK 1 (Existing — Keep as-is)                        │
  ┌─────────────────────────────┐                                   │
  │  e-Fine SL Backend          │                                   │
  │  GET /api/auth/check-exists │                                   │
  │  field=licenseNumber        │                                   │
  └─────────────────────────────┘                                   │
          │                                                          │
     ┌────┴──────┐                                                   │
  TAKEN        AVAILABLE                                             │
     │              │                                                │
     ▼              ▼  CHECK 2 (NEW)                                 │
  Show Error   ┌──────────────────────────────────┐                 │
  "Already     │  e-Fine SL Backend (Proxy)        │                 │
  Registered"  │  POST /api/auth/verify-dmt        │                 │
               │  → forwards to DMT Server         │                 │
               └──────────────────────────────────┘                 │
                          │                                          │
          ┌───────────────┼──────────────────┐                      │
          │               │                  │                      │
      NOT FOUND      NIC MISMATCH    DMT UNREACHABLE                │
          │               │                  │                      │
          ▼               ▼                  ▼                      │
     "License not    "NIC does not    🚫 BLOCK                      │
      found in DMT"   match record"   Registration                  │
                                      Completely                    │
                                                                     │
                    VERIFIED ✓                                       │
                          │                                          │
                          ▼                                          │
               Show ✅ green verified tick                           │
                          │                                          │
                          ▼                                          │
               User clicks "Verify & Register"                      │
                          │                                          │
                          ▼                                          │
               KYC → Liveness Detection → Registration              │
                                                                     │
  [DMT Server — Separate Repo on Render] ◄────────────────────────┘
  POST /api/dmt/verify-license
  { licenseNumber, nic }
  → Checks against 50–60 hardcoded MongoDB records
  → Returns match result + driver details
```

---

## 📦 What Needs to Be Built

| Part | What | Where |
|------|------|-------|
| **Part A** | DMT Server (brand new project) | New GitHub repo → Render |
| **Part B** | Main backend proxy endpoint | Existing repo — `backend_api/` |
| **Part C** | Flutter app DMT integration | Existing repo — `mobile_app/` |

---

# 🔨 PART A — DMT Server (Separate GitHub Repository)

## A.1 — Repository Structure

```
dmt-server/                          ← New GitHub repository root
├── config/
│   └── db.js                        ← MongoDB connection
├── controllers/
│   └── dmtController.js             ← verifyLicense endpoint logic
├── middleware/
│   └── apiKeyMiddleware.js           ← API key guard (only e-Fine SL backend)
├── models/
│   └── dmtLicenseModel.js           ← Mongoose schema
├── routes/
│   └── dmtRoutes.js                 ← Route definitions
├── seed/
│   └── seedRunner.js                ← Run once: inserts hardcoded 50–60 records
├── data/
│   └── licenseRecords.js            ← Hardcoded 50–60 realistic SL license records
├── .env                             ← Environment variables
├── .gitignore                       ← Ignore node_modules, .env
├── package.json
├── README.md                        ← Setup + deployment instructions
└── server.js                        ← Express entry point
```

---

## A.2 — Perfect Prompt for DMT Server

> ✅ Copy this entire prompt and give it to your AI coding tool (Cursor / GitHub Copilot / Claude Code) to generate the full DMT server project from scratch.

---

```
You are a Senior Node.js Backend Developer.

Build a BRAND NEW standalone Node.js + Express server called "DMT Server"
that simulates the Sri Lanka Department of Motor Traffic (DMT) driving
license verification database. This is a completely SEPARATE GitHub
repository from the e-Fine SL main backend.

This server will be deployed on Render as a Web Service.
The e-Fine SL main backend calls this server as a proxy.
Flutter app NEVER calls this DMT server directly.

═══════════════════════════════════════════════════════════════════
TECH STACK:
═══════════════════════════════════════════════════════════════════
- Node.js 20+
- Express 5
- MongoDB with Mongoose
- dotenv
- cors
- helmet
- express-rate-limit

═══════════════════════════════════════════════════════════════════
FILE 1 — package.json
═══════════════════════════════════════════════════════════════════
{
  "name": "dmt-server",
  "version": "1.0.0",
  "description": "Dummy DMT License Verification Server — e-Fine SL Sri Lanka",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "seed": "node seed/seedRunner.js"
  },
  "engines": {
    "node": ">=20.0.0"
  },
  "dependencies": {
    "cors": "^2.8.5",
    "dotenv": "^16.4.5",
    "express": "^5.1.0",
    "express-rate-limit": "^7.4.1",
    "helmet": "^8.0.0",
    "mongoose": "^8.9.5"
  },
  "devDependencies": {
    "nodemon": "^3.1.9"
  }
}

═══════════════════════════════════════════════════════════════════
FILE 2 — .env
═══════════════════════════════════════════════════════════════════
Create a .env file with these variables:

PORT=6000
MONGODB_URI=mongodb+srv://<username>:<password>@cluster.mongodb.net/dmt_db
DMT_API_KEY=dmt_efinesl_secure_key_2025
NODE_ENV=development

IMPORTANT:
- DMT_API_KEY must match the key stored in the e-Fine SL main backend .env
- Only the e-Fine SL main backend is authorised to call this DMT API
- Never commit .env to GitHub — add it to .gitignore

═══════════════════════════════════════════════════════════════════
FILE 3 — .gitignore
═══════════════════════════════════════════════════════════════════
node_modules/
.env
*.log

═══════════════════════════════════════════════════════════════════
FILE 4 — server.js  (Entry Point)
═══════════════════════════════════════════════════════════════════
Create server.js that does the following in order:

1. Load dotenv config
2. Import express, cors, helmet
3. Import mongoose connection from ./config/db
4. Import dmtRouter from ./routes/dmtRoutes
5. Import rate limiter from express-rate-limit:
   - windowMs: 15 * 60 * 1000  (15 minutes)
   - max: 100 requests
   - message: { success: false, message: "Too many requests. Please try later." }
6. Call connectDB() to connect to MongoDB
7. Create Express app
8. Apply middleware in this order:
   a. helmet()
   b. cors({ origin: '*' })
   c. express.json()
   d. rateLimiter
9. Mount routes: app.use('/api/dmt', dmtRouter)
10. Add health check route:
    GET / → return 200 { 
      success: true, 
      message: "DMT Server is running", 
      environment: process.env.NODE_ENV,
      timestamp: new Date().toISOString() 
    }
11. Listen on process.env.PORT with log:
    "[DMT-SERVER] Running on port 6000"

═══════════════════════════════════════════════════════════════════
FILE 5 — config/db.js
═══════════════════════════════════════════════════════════════════
Create an async function connectDB() that:
- Connects to MongoDB using process.env.MONGODB_URI
- On success: console.log("[DMT-DB] MongoDB Connected Successfully")
- On error: console.error("[DMT-DB] Connection Error:", err.message) then process.exit(1)
- Export connectDB as default

═══════════════════════════════════════════════════════════════════
FILE 6 — models/dmtLicenseModel.js
═══════════════════════════════════════════════════════════════════
Create a Mongoose Schema called "DmtLicense" with collection name "dmtlicenses":

Fields:
{
  licenseNumber:    { type: String, required: true, unique: true, uppercase: true, trim: true },
  nic:              { type: String, required: true, unique: true, uppercase: true, trim: true },
  fullName:         { type: String, required: true, trim: true },
  dateOfBirth:      { type: String, required: true },       // Format: "YYYY-MM-DD"
  address:          { type: String, trim: true },
  licenseIssueDate: { type: String, required: true },       // Format: "YYYY-MM-DD"
  licenseExpiryDate:{ type: String, required: true },       // Format: "YYYY-MM-DD"
  licenseStatus: {
    type: String,
    enum: ["ACTIVE", "EXPIRED", "SUSPENDED", "REVOKED"],
    default: "ACTIVE"
  },
  vehicleClasses: [
    {
      category:   { type: String },    // A, B, B1, C, CE, D, DE, G
      issueDate:  { type: String },    // Format: "YYYY-MM-DD"
      expiryDate: { type: String }     // Format: "YYYY-MM-DD"
    }
  ],
  issuingOffice: { type: String }
}

Options: { timestamps: true }

Indexes:
- licenseNumber (unique: true)
- nic (unique: true)

Export as: mongoose.model('DmtLicense', dmtLicenseSchema)

═══════════════════════════════════════════════════════════════════
FILE 7 — middleware/apiKeyMiddleware.js
═══════════════════════════════════════════════════════════════════
Create Express middleware function named validateApiKey:

Logic:
1. Read header: req.headers['x-dmt-api-key']
2. Compare to process.env.DMT_API_KEY
3. If header is missing:
   → return res.status(401).json({
       success: false,
       message: "Unauthorized: API key is missing"
     })
4. If header does not match:
   → return res.status(401).json({
       success: false,
       message: "Unauthorized: Invalid API key"
     })
5. If matches: call next()

Export as: module.exports = validateApiKey

═══════════════════════════════════════════════════════════════════
FILE 8 — routes/dmtRoutes.js
═══════════════════════════════════════════════════════════════════
Create Express router with:

const router = express.Router();
const validateApiKey = require('../middleware/apiKeyMiddleware');
const { verifyLicense } = require('../controllers/dmtController');

Routes:
- GET  /health   → no auth needed → return { success: true, message: "DMT routes OK" }
- POST /verify-license → validateApiKey middleware → verifyLicense controller

module.exports = router;

This router is mounted in server.js at: /api/dmt
So full endpoint is: POST /api/dmt/verify-license

═══════════════════════════════════════════════════════════════════
FILE 9 — controllers/dmtController.js
═══════════════════════════════════════════════════════════════════
Create async controller function verifyLicense(req, res):

─── REQUEST BODY (from e-Fine SL backend proxy): ───
{
  "licenseNumber": "B1234567",
  "nic": "991234567V"
}

─── LOGIC: ───

Step 1: Extract and validate input
  const { licenseNumber, nic } = req.body;
  If either is missing or empty:
    → return 400 {
        success: false,
        message: "Both licenseNumber and nic are required"
      }

Step 2: Normalise both values
  const normalizedLicense = licenseNumber.toString().trim().toUpperCase();
  const normalizedNic     = nic.toString().trim().toUpperCase();

Step 3: Find license in database (case-insensitive)
  const record = await DmtLicense.findOne({
    licenseNumber: { $regex: new RegExp(`^${normalizedLicense}$`, 'i') }
  });

Step 4: If NOT FOUND:
  console.log(`[DMT-CTRL] License not found: ${normalizedLicense}`);
  → return 404 {
      success: false,
      found: false,
      message: "No driving license record found for this License Number in the DMT database."
    }

Step 5: If FOUND — check NIC match
  const normalizedRecordNic = record.nic.toString().trim().toUpperCase();
  if (normalizedRecordNic !== normalizedNic):
    console.log(`[DMT-CTRL] NIC mismatch for license: ${normalizedLicense}`);
    → return 400 {
        success: false,
        found: true,
        nicMatch: false,
        message: "NIC Number does not match the license holder record in the DMT database."
      }

Step 6: Both match — return full driver details:
  console.log(`[DMT-CTRL] License verified: ${normalizedLicense}`);
  → return 200 {
      success: true,
      found: true,
      nicMatch: true,
      message: "Driving license verified successfully in the DMT database.",
      data: {
        licenseNumber:     record.licenseNumber,
        nic:               record.nic,
        fullName:          record.fullName,
        dateOfBirth:       record.dateOfBirth,
        address:           record.address,
        licenseIssueDate:  record.licenseIssueDate,
        licenseExpiryDate: record.licenseExpiryDate,
        licenseStatus:     record.licenseStatus,
        vehicleClasses:    record.vehicleClasses,
        issuingOffice:     record.issuingOffice
      }
    }

Step 7: Wrap everything in try-catch:
  catch(error):
    console.error(`[DMT-CTRL] Server Error: ${error.message}`);
    → return 500 {
        success: false,
        message: "Internal Server Error",
        error: error.message
      }

module.exports = { verifyLicense };

═══════════════════════════════════════════════════════════════════
FILE 10 — data/licenseRecords.js  (HARDCODED — 55 Records)
═══════════════════════════════════════════════════════════════════
Create a JavaScript file that exports an array of exactly 55 hardcoded
realistic Sri Lankan driving license records. DO NOT use a generator.
Write each record manually to ensure realism and testability.

Each record must follow this exact structure:
{
  licenseNumber:     "B1234567",
  nic:               "901234567V",
  fullName:          "Kasun Perera",
  dateOfBirth:       "1990-04-15",
  address:           "23/B, Galle Road, Colombo 03",
  licenseIssueDate:  "2015-06-10",
  licenseExpiryDate: "2023-06-10",
  licenseStatus:     "ACTIVE",
  vehicleClasses: [
    { category: "B", issueDate: "2015-06-10", expiryDate: "2023-06-10" }
  ],
  issuingOffice: "Colombo DMT Office"
}

─── DATA RULES: ───

LICENSE NUMBER FORMATS (use these realistic Sri Lankan patterns):
  Prefix + 6–8 digits
  Prefixes to use: B, B, B, NC, WP, CP, EP, NP, SP
  Examples: B1023456, B2345678, NC3456789, WP4567890

NIC FORMATS:
  Old format (30% of records): 9 digits + V  → e.g. 901234567V, 851234321V
  New format (70% of records): 12 digits     → e.g. 199012345678, 198512348901

NAMES — Use only realistic Sri Lankan names:
  Sinhala Male: Kasun Perera, Nuwan Silva, Chamara Fernando, Dilan Jayawardena,
                Lahiru Bandara, Sachith Wickramasinghe, Asanka Seneviratne,
                Thilina Karunaratne, Gayan Gunawardena, Ruwan Rathnayake,
                Prabath Weerasinghe, Malith Dissanayake, Indunil Rajapaksa,
                Chathura Liyanage, Buddhika Pathirana, Sanjeewa Amarasinghe,
                Harsha Jayasuriya, Thisara Kumara, Ravindra Samarawickrama,
                Dinusha Wijesinghe

  Sinhala Female: Amali Perera, Dilini Silva, Nadeeka Fernando, Sanduni Bandara,
                  Priyanka Jayawardena, Chathurika Wickramasinghe,
                  Nimasha Seneviratne, Chamari Karunaratne

  Tamil Male: Arjun Rajagopal, Kumaran Selvaraj, Vignesh Krishnamurthy,
              Suresh Navaratnam, Rajan Chandrakumar
  Tamil Female: Priya Thambipillai, Nithya Sivanesan, Kavitha Ratnasingham,
                Meena Rajendran, Anitha Jeyarajah

DATE OF BIRTH: Between 1970-01-01 and 1998-12-31. Format: "YYYY-MM-DD"

LICENSE ISSUE DATE: At least 18 years after DOB. Between 2010-01-01 and 2022-12-31.

LICENSE EXPIRY DATE: Issue date + 8 years (Sri Lankan standard validity)

LICENSE STATUS distribution across 55 records:
  - 47 records: "ACTIVE"
  - 4 records:  "EXPIRED"
  - 2 records:  "SUSPENDED"
  - 2 records:  "REVOKED"

VEHICLE CLASSES per record:
  Most records: 1 class → B (standard car license)
  Some records: 2 classes → B + A (car + motorcycle)
  Few records: 3 classes → B + C + B1 (car + heavy + light commercial)
  Each class uses the same issueDate and expiryDate as the license itself

ISSUING OFFICES (distribute evenly):
  "Colombo DMT Office", "Kandy DMT Office", "Galle DMT Office",
  "Matara DMT Office", "Kurunegala DMT Office", "Ratnapura DMT Office",
  "Badulla DMT Office", "Anuradhapura DMT Office", "Jaffna DMT Office",
  "Negombo DMT Office", "Trincomalee DMT Office", "Batticaloa DMT Office"

UNIQUENESS: Every licenseNumber and every nic must be unique across all 55 records.

─── ALSO ADD: 5 special test records at the END of the array ───
These are for easy testing during development:

{
  licenseNumber: "TEST001",
  nic: "900000001V",
  fullName: "Test Driver Active",
  dateOfBirth: "1990-01-01",
  address: "Test Address, Colombo",
  licenseIssueDate: "2015-01-01",
  licenseExpiryDate: "2023-01-01",
  licenseStatus: "ACTIVE",
  vehicleClasses: [{ category: "B", issueDate: "2015-01-01", expiryDate: "2023-01-01" }],
  issuingOffice: "Colombo DMT Office"
},
{
  licenseNumber: "TEST002",
  nic: "900000002V",
  fullName: "Test Driver Expired",
  dateOfBirth: "1990-01-02",
  address: "Test Address, Kandy",
  licenseIssueDate: "2010-01-01",
  licenseExpiryDate: "2018-01-01",
  licenseStatus: "EXPIRED",
  vehicleClasses: [{ category: "B", issueDate: "2010-01-01", expiryDate: "2018-01-01" }],
  issuingOffice: "Kandy DMT Office"
},
{
  licenseNumber: "TEST003",
  nic: "900000003V",
  fullName: "Test Driver Suspended",
  dateOfBirth: "1990-01-03",
  address: "Test Address, Galle",
  licenseIssueDate: "2014-01-01",
  licenseExpiryDate: "2022-01-01",
  licenseStatus: "SUSPENDED",
  vehicleClasses: [{ category: "B", issueDate: "2014-01-01", expiryDate: "2022-01-01" }],
  issuingOffice: "Galle DMT Office"
},
{
  licenseNumber: "TEST004",
  nic: "199000000458",
  fullName: "Test Driver NIC New Format",
  dateOfBirth: "1990-02-01",
  address: "Test Address, Negombo",
  licenseIssueDate: "2016-03-01",
  licenseExpiryDate: "2024-03-01",
  licenseStatus: "ACTIVE",
  vehicleClasses: [
    { category: "B", issueDate: "2016-03-01", expiryDate: "2024-03-01" },
    { category: "A", issueDate: "2016-03-01", expiryDate: "2024-03-01" }
  ],
  issuingOffice: "Negombo DMT Office"
},
{
  licenseNumber: "TEST005",
  nic: "900000005V",
  fullName: "Test Driver Multi Class",
  dateOfBirth: "1985-06-15",
  address: "Test Address, Matara",
  licenseIssueDate: "2012-07-01",
  licenseExpiryDate: "2020-07-01",
  licenseStatus: "ACTIVE",
  vehicleClasses: [
    { category: "B",  issueDate: "2012-07-01", expiryDate: "2020-07-01" },
    { category: "C",  issueDate: "2012-07-01", expiryDate: "2020-07-01" },
    { category: "B1", issueDate: "2012-07-01", expiryDate: "2020-07-01" }
  ],
  issuingOffice: "Matara DMT Office"
}

Total: 55 real-looking records + 5 test records = 60 records total.

module.exports = licenseRecords;

═══════════════════════════════════════════════════════════════════
FILE 11 — seed/seedRunner.js
═══════════════════════════════════════════════════════════════════
Create a seed script that:

1. require('dotenv').config({ path: '../.env' })  ← load env from parent
2. Connect to MongoDB using MONGODB_URI from env
3. Import DmtLicense model from ../models/dmtLicenseModel
4. Import licenseRecords array from ../data/licenseRecords
5. Drop existing collection: await DmtLicense.deleteMany({})
   Log: "[DMT-SEED] Cleared existing records."
6. Insert all records: await DmtLicense.insertMany(licenseRecords)
   Log: `[DMT-SEED] Successfully seeded ${licenseRecords.length} license records.`
7. Disconnect and process.exit(0)
8. On error: console.error then process.exit(1)

Run command: npm run seed

═══════════════════════════════════════════════════════════════════
FILE 12 — README.md
═══════════════════════════════════════════════════════════════════
Write a professional README.md that covers:

# DMT Server — e-Fine SL
## About
## Tech Stack
## Environment Variables (table: variable name, description, example)
## Setup
  ### 1. Clone Repository
  ### 2. Install Dependencies: npm install
  ### 3. Configure .env
  ### 4. Seed Database: npm run seed
  ### 5. Run Locally: npm run dev
## API Reference
  ### POST /api/dmt/verify-license
    Request Headers, Request Body, Response Examples (200, 404, 400, 401, 500)
  ### GET /health
## Deployment on Render
  Step-by-step guide for deploying this project on Render as a Web Service
## Security
  Note that this server is protected by API key middleware

═══════════════════════════════════════════════════════════════════
ADDITIONAL NOTES:
═══════════════════════════════════════════════════════════════════
- DMT server runs on PORT 6000 locally (separate from e-Fine SL port 5000)
- It uses its OWN MongoDB database: "dmt_db" (not the e-Fine SL database)
- The API key header name is exactly: "x-dmt-api-key"
- All license numbers and NICs are stored and compared in UPPERCASE
- This is a mock/dummy server for demo purposes — it simulates real DMT API
```

---

# 🔧 PART B — Main e-Fine SL Backend Update

**Repository:** `e-fine-sl-traffic-management` (existing)  
**Files to modify:**
- `/backend_api/controllers/authController.js`
- `/backend_api/routes/authRoutes.js`
- `/backend_api/.env`

---

## B.1 — Add DMT Config to Environment

```bash
# Add these two lines to /backend_api/.env:

DMT_SERVER_URL=https://your-dmt-server.onrender.com
DMT_API_KEY=dmt_efinesl_secure_key_2025
```

> ⚠️ `DMT_API_KEY` must be **identical** to the value set in the DMT server's `.env`.

---

## B.2 — Perfect Prompt for Backend Update

```
You are a Senior Node.js Backend Developer working on the existing
e-Fine SL Traffic Management System.

The project is at: https://github.com/e-fine-sl/e-fine-sl-traffic-management
Backend folder: /backend_api

Make the following TARGETED changes. Do NOT touch any other existing code.

═══════════════════════════════════════════════════════════════════
CHANGE 1 — Add verifyWithDMT function to authController.js
═══════════════════════════════════════════════════════════════════
File: /backend_api/controllers/authController.js

Add this new async function BEFORE the module.exports block at the bottom:

const verifyWithDMT = async (req, res) => {
  const { licenseNumber, nic } = req.body;

  // Step 1: Validate input
  if (!licenseNumber || !nic) {
    return res.status(400).json({
      success: false,
      message: 'licenseNumber and nic are required.'
    });
  }

  console.log(`[AUTH/DMT-VERIFY] Checking license: ${licenseNumber}`);

  try {
    // Step 2: Call DMT server with API key in header
    const dmtUrl = `${process.env.DMT_SERVER_URL}/api/dmt/verify-license`;

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10000); // 10 second timeout

    let dmtResponse;
    try {
      dmtResponse = await fetch(dmtUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-dmt-api-key': process.env.DMT_API_KEY
        },
        body: JSON.stringify({
          licenseNumber: licenseNumber.trim().toUpperCase(),
          nic: nic.trim().toUpperCase()
        }),
        signal: controller.signal
      });
    } catch (fetchError) {
      // DMT server unreachable (timeout / connection refused / DNS failure)
      console.error(`[AUTH/DMT-VERIFY] DMT Server unreachable: ${fetchError.message}`);
      return res.status(503).json({
        success: false,
        dmtUnreachable: true,
        message: 'DMT verification service is currently unavailable. Registration is temporarily blocked. Please try again later.'
      });
    } finally {
      clearTimeout(timeout);
    }

    // Step 3: Parse DMT response
    const dmtData = await dmtResponse.json();
    console.log(`[AUTH/DMT-VERIFY] DMT Status: ${dmtResponse.status} for license: ${licenseNumber}`);

    // Step 4: Forward DMT result to Flutter
    if (dmtResponse.status === 200) {
      return res.status(200).json({
        success: true,
        found: true,
        nicMatch: true,
        message: 'License verified successfully in the DMT database.',
        data: dmtData.data
      });
    }

    if (dmtResponse.status === 404) {
      return res.status(404).json({
        success: false,
        found: false,
        message: dmtData.message || 'No driving license record found in DMT database.'
      });
    }

    if (dmtResponse.status === 400) {
      return res.status(400).json({
        success: false,
        found: true,
        nicMatch: false,
        message: dmtData.message || 'NIC Number does not match the license holder record.'
      });
    }

    // Any other DMT error
    return res.status(dmtResponse.status).json({
      success: false,
      message: dmtData.message || 'DMT verification failed.'
    });

  } catch (error) {
    console.error(`[AUTH/DMT-VERIFY] Unexpected error: ${error.message}`);
    return res.status(500).json({
      success: false,
      message: 'Internal server error during DMT verification.',
      error: error.message
    });
  }
};

─── Then ADD verifyWithDMT to the existing module.exports: ───

Find the existing module.exports block and add verifyWithDMT to it.
For example, if it currently ends with:
  module.exports = {
    ...
    checkFieldExistence
  };

Change it to:
  module.exports = {
    ...
    checkFieldExistence,
    verifyWithDMT
  };

═══════════════════════════════════════════════════════════════════
CHANGE 2 — Add new route in authRoutes.js
═══════════════════════════════════════════════════════════════════
File: /backend_api/routes/authRoutes.js

Step 1: Import verifyWithDMT from the controller.
  Find the existing destructured import from authController and add verifyWithDMT:
  const { ..., verifyWithDMT } = require('../controllers/authController');

Step 2: Add this new route after the existing check-exists route:
  // DMT License Verification Proxy (public — no auth required)
  router.post('/verify-dmt', verifyWithDMT);

  This makes the endpoint available at:
  POST /api/auth/verify-dmt

DO NOT add any authentication middleware to this route.
It is called during registration before the user has a token.

═══════════════════════════════════════════════════════════════════
CHANGE 3 — Update /backend_api/.env
═══════════════════════════════════════════════════════════════════
Add these two lines to the .env file:

# DMT Verification Server
DMT_SERVER_URL=https://your-dmt-server.onrender.com
DMT_API_KEY=dmt_efinesl_secure_key_2025

Note: Replace the DMT_SERVER_URL with the actual Render URL after
the DMT server is deployed.

═══════════════════════════════════════════════════════════════════
IMPORTANT NOTES:
═══════════════════════════════════════════════════════════════════
- Use Node.js built-in fetch (Node 18+) — no need to install node-fetch
- The 10-second AbortController timeout prevents hanging requests
- The proxy pattern keeps DMT_API_KEY hidden from the Flutter app
- Flutter never knows the DMT server's URL or API key
- Do NOT modify any other existing function in authController.js
- Do NOT modify any other route in authRoutes.js
```

---

# 📱 PART C — Flutter App Update

**Repository:** `e-fine-sl-traffic-management` (existing)  
**Files to modify:**
- `/mobile_app/lib/config/app_constants.dart`
- `/mobile_app/lib/services/auth_service.dart`
- `/mobile_app/lib/screens/auth/driver_signup_screen.dart`

---

## C.1 — Perfect Prompt for Flutter Changes

```
You are a Senior Flutter Developer working on the existing
e-Fine SL Traffic Management System Flutter app.

The project is at: https://github.com/e-fine-sl/e-fine-sl-traffic-management
Flutter folder: /mobile_app

Make the following TARGETED changes to add DMT license verification
during driver registration. Do NOT touch KYC, police screens,
driver dashboard, or any other file not mentioned here.

Current license check flow (keep this — do not remove):
  User types license → debounce 500ms → checkFieldExists() → show ✓ or error

New flow after changes:
  User types license → debounce 500ms →
    Step 1: checkFieldExists() (existing) → if taken, STOP
    Step 2: verifyLicenseWithDMT() (NEW)  → if fails, STOP or show error

═══════════════════════════════════════════════════════════════════
CHANGE 1 — app_constants.dart
═══════════════════════════════════════════════════════════════════
File: /mobile_app/lib/config/app_constants.dart

Inside the ApiConstants class, add ONE new static constant after the
existing baseUrl and authServiceUrl constants:

  // DMT License Verification Proxy (calls main backend which proxies to DMT)
  static const String dmtVerifyUrl = '$baseUrl/auth/verify-dmt';

No other changes to this file.

═══════════════════════════════════════════════════════════════════
CHANGE 2 — auth_service.dart
═══════════════════════════════════════════════════════════════════
File: /mobile_app/lib/services/auth_service.dart

Add this new method to the AuthService class.
Place it directly after the existing checkFieldExists() method.

  /// Verifies a driving license + NIC combination against the DMT database
  /// via the e-Fine SL backend proxy.
  ///
  /// Returns a Map with:
  ///   success (bool), found (bool), nicMatch (bool),
  ///   dmtUnreachable (bool), message (String), data (Map?) 
  Future<Map<String, dynamic>> verifyLicenseWithDMT({
    required String licenseNumber,
    required String nic,
  }) async {
    try {
      debugPrint('[AuthService] DMT verify: $licenseNumber / $nic');

      final response = await http.post(
        Uri.parse(ApiConstants.dmtVerifyUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'licenseNumber': licenseNumber.trim().toUpperCase(),
          'nic':           nic.trim().toUpperCase(),
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      switch (response.statusCode) {
        case 200:
          return {
            'success':    true,
            'found':      true,
            'nicMatch':   true,
            'message':    data['message'] ?? 'Verified',
            'data':       data['data'],
          };
        case 404:
          return {
            'success':    false,
            'found':      false,
            'message':    data['message'] ?? 'License not found in DMT',
          };
        case 400:
          return {
            'success':    false,
            'found':      true,
            'nicMatch':   false,
            'message':    data['message'] ?? 'NIC does not match this license',
          };
        case 503:
          return {
            'success':        false,
            'dmtUnreachable': true,
            'message':        data['message'] ?? 'DMT service unavailable',
          };
        default:
          return {
            'success': false,
            'message': data['message'] ?? 'DMT verification failed',
          };
      }
    } catch (e) {
      debugPrint('[AuthService] DMT verify error: $e');
      return {
        'success':        false,
        'dmtUnreachable': true,
        'message':        'Unable to reach DMT verification service. Please try again.',
      };
    }
  }

No other changes to this file.

═══════════════════════════════════════════════════════════════════
CHANGE 3 — driver_signup_screen.dart
═══════════════════════════════════════════════════════════════════
File: /mobile_app/lib/screens/auth/driver_signup_screen.dart

─── STEP A: Add 3 new state variables ───

In the _DriverSignupScreenState class, find where other bool state
variables are declared (near _isCheckingLicense, _isLicenseUnique, etc.)
and add these THREE new variables right after them:

  // DMT verification state
  bool   _isDmtVerified  = false;
  bool   _isDmtChecking  = false;
  String? _dmtErrorText;

─── STEP B: Modify _onFieldChanged() for the licenseNumber case ───

Find the existing licenseNumber case inside _onFieldChanged().

Currently it does:
  case 'licenseNumber':
    _isCheckingLicense = false;
    if (isTaken) {
      _licenseErrorText = "License Number is already registered";
    } else {
      _isLicenseUnique = true;
    }

Replace the ENTIRE debounce Timer callback block to this new version:

  _debounce = Timer(const Duration(milliseconds: 500), () async {
    if (!mounted) return;

    // ── Step 1: e-Fine SL uniqueness check (existing — keep) ──────
    final isTaken = await _authService.checkFieldExists(
      'licenseNumber', value.trim(), role: 'driver'
    );

    if (!mounted) return;

    if (isTaken) {
      setState(() {
        _isCheckingLicense = false;
        _isLicenseUnique   = false;
        _isDmtVerified     = false;
        _dmtErrorText      = null;
        _licenseErrorText  = "License Number is already registered in e-Fine SL";
      });
      return; // Stop — do not call DMT
    }

    // ── Step 2: DMT verification (NEW) ────────────────────────────
    setState(() {
      _isCheckingLicense = false;
      _isLicenseUnique   = false;
      _isDmtChecking     = true;
      _dmtErrorText      = null;
    });

    final dmtResult = await _authService.verifyLicenseWithDMT(
      licenseNumber: value.trim(),
      nic:           _nicController.text.trim(),
    );

    if (!mounted) return;

    if (dmtResult['success'] == true) {
      setState(() {
        _isDmtChecking  = false;
        _isDmtVerified  = true;
        _isLicenseUnique = true;
        _licenseErrorText = null;
        _dmtErrorText     = null;
      });
    } else if (dmtResult['dmtUnreachable'] == true) {
      setState(() {
        _isDmtChecking  = false;
        _isDmtVerified  = false;
        _isLicenseUnique = false;
        _dmtErrorText   = "⚠️ DMT verification service is unavailable. "
                          "Registration is blocked. Please try again later.";
      });
    } else if (dmtResult['found'] == false) {
      setState(() {
        _isDmtChecking  = false;
        _isDmtVerified  = false;
        _isLicenseUnique = false;
        _dmtErrorText   = "License Number not found in DMT records. "
                          "Please check your driving license.";
      });
    } else if (dmtResult['nicMatch'] == false) {
      setState(() {
        _isDmtChecking  = false;
        _isDmtVerified  = false;
        _isLicenseUnique = false;
        _dmtErrorText   = "NIC Number does not match this License Number "
                          "in the DMT records. Please check both values.";
      });
    } else {
      setState(() {
        _isDmtChecking  = false;
        _isDmtVerified  = false;
        _isLicenseUnique = false;
        _dmtErrorText   = dmtResult['message'] ?? "DMT verification failed.";
      });
    }
  });

─── STEP C: Reset DMT state when NIC field changes ───

In _onFieldChanged(), find the case for 'nic' field.
Inside the debounce callback where it currently only checks NIC uniqueness,
ADD these resets at the very beginning of the debounce Timer callback:

  // Reset DMT state whenever NIC changes
  // (forces re-verification with new NIC value)
  setState(() {
    _isDmtVerified = false;
    _dmtErrorText  = null;
  });

─── STEP D: Update suffix icon for license number field ───

Find the _buildSuffixIcon() method (or wherever the license field's
suffixIcon is built — look for _isCheckingLicense and _isLicenseUnique).

Replace the existing license suffix icon logic with this updated version
that also accounts for DMT checking and DMT verified states:

  Widget? _buildLicenseSuffixIcon() {
    if (_isCheckingLicense || _isDmtChecking) {
      return const SizedBox(
        width: 20, height: 20,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_isDmtVerified && _isLicenseUnique) {
      return const Icon(Icons.verified, color: AppColors.successGreen);
    }
    if (_dmtErrorText != null || _licenseErrorText != null) {
      return const Icon(Icons.gpp_bad, color: AppColors.errorRed);
    }
    return null;
  }

Then update the license TextFormField's decoration to use:
  suffixIcon: _buildLicenseSuffixIcon(),

─── STEP E: Show DMT error message below the license field ───

Immediately after the license number TextFormField widget,
add this Visibility widget to show the DMT error:

  Visibility(
    visible: _dmtErrorText != null,
    child: Padding(
      padding: const EdgeInsets.only(top: 6, left: 12, right: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: AppColors.errorRed,
            size: 14,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _dmtErrorText ?? '',
              style: const TextStyle(
                color: AppColors.errorRed,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    ),
  ),

─── STEP F: Block KYC / registration if DMT not verified ───

Find the _validateFields() method.
Add this check AFTER the existing license field validation:

  // DMT verification must pass before KYC
  if (!_isDmtVerified) {
    _showError(
      'Your License Number must be verified against the DMT database '
      'before you can proceed with registration.'
    );
    return false;
  }

This ensures the "Verify & Register" button is blocked if:
  - DMT is unreachable
  - License not found in DMT
  - NIC mismatch in DMT

═══════════════════════════════════════════════════════════════════
IMPORTANT NOTES:
═══════════════════════════════════════════════════════════════════
- The existing e-Fine SL check (checkFieldExists) must still run FIRST
- DMT check only runs if the license is NOT already in e-Fine SL
- Do NOT remove or modify any KYC-related code
- Do NOT modify the _registerDriver() function
- Do NOT modify the _openKyc() function
- The _isDmtVerified flag acts as the gate before KYC can start
- If user clears license field, reset all DMT state variables
```

---

# 🔄 Complete New Registration Flow

```
1. User opens Driver Registration Screen

2. User fills:  Name, NIC, License Number, Email, Phone, Password, etc.

3. As user TYPES License Number (500ms after last keystroke):

   ┌────────────────────────────────────────────┐
   │ Spinner appears in license field suffix    │
   │                                            │
   │ CHECK 1: Is it in e-Fine SL already?       │
   │  YES → ❌ "Already registered"  STOP       │
   │  NO  → Continue to CHECK 2                 │
   │                                            │
   │ CHECK 2: Is it valid in DMT?               │
   │  Spinner stays while DMT is checked        │
   │                                            │
   │  Result A: ✅ VERIFIED                     │
   │    → Green verified tick appears           │
   │    → User can proceed                      │
   │                                            │
   │  Result B: ❌ Not found in DMT             │
   │    → Red error below field                 │
   │    → "License not found in DMT records"    │
   │                                            │
   │  Result C: ❌ NIC mismatch                 │
   │    → Red error below field                 │
   │    → "NIC does not match this license"     │
   │                                            │
   │  Result D: ⚠️ DMT Unreachable             │
   │    → Red warning below field               │
   │    → "Registration blocked"                │
   └────────────────────────────────────────────┘

4. User clicks "Verify & Register"
   → _validateFields() checks _isDmtVerified == true
   → If false: shows error dialog, does not proceed
   → If true: opens KYC screen

5. KYC → Liveness Detection → Registration → Success
```

---

# 🧪 Testing Reference

## Test License Numbers (from hardcoded seed data)

| License | NIC | Expected Result |
|---------|-----|-----------------|
| `TEST001` | `900000001V` | ✅ ACTIVE — full verification |
| `TEST002` | `900000002V` | ✅ EXPIRED — verification passes (DMT just confirms existence) |
| `TEST003` | `900000003V` | ✅ SUSPENDED — verification passes |
| `TEST004` | `199000000458` | ✅ New NIC format — verification passes |
| `TEST005` | `900000005V` | ✅ Multi-class license — verification passes |
| `TEST001` | `WRONGNIC123` | ❌ NIC mismatch |
| `FAKE9999` | `900000001V` | ❌ Not found in DMT |

## Scenario Tests

| Scenario | Action | Expected |
|----------|--------|----------|
| Valid license + correct NIC | Type TEST001 + 900000001V | ✅ Green tick |
| License not in DMT | Type FAKE99999 | ❌ "Not found in DMT" |
| License found but wrong NIC | Type TEST001 + wrong NIC | ❌ "NIC mismatch" |
| Already in e-Fine SL | Type registered license | ❌ "Already registered" (no DMT call) |
| DMT server down | Stop DMT server, type any license | ❌ "Registration blocked" |
| Change NIC after verified | Verified ✓, then change NIC field | 🔄 Re-triggers DMT check |

---

# 🗂️ Files Summary

| Component | File | Action | Critical |
|-----------|------|--------|---------|
| **DMT Server** | `server.js` | Create new | ✅ |
| **DMT Server** | `config/db.js` | Create new | ✅ |
| **DMT Server** | `models/dmtLicenseModel.js` | Create new | ✅ |
| **DMT Server** | `middleware/apiKeyMiddleware.js` | Create new | ✅ |
| **DMT Server** | `routes/dmtRoutes.js` | Create new | ✅ |
| **DMT Server** | `controllers/dmtController.js` | Create new | ✅ |
| **DMT Server** | `data/licenseRecords.js` | Create new (60 records) | ✅ |
| **DMT Server** | `seed/seedRunner.js` | Create new | ✅ |
| **DMT Server** | `package.json` | Create new | ✅ |
| **DMT Server** | `.env` | Create new | ✅ |
| **DMT Server** | `README.md` | Create new | ✅ |
| **Main Backend** | `controllers/authController.js` | Add `verifyWithDMT()` | ✅ |
| **Main Backend** | `routes/authRoutes.js` | Add `POST /verify-dmt` | ✅ |
| **Main Backend** | `.env` | Add 2 variables | ✅ |
| **Flutter** | `config/app_constants.dart` | Add `dmtVerifyUrl` | ✅ |
| **Flutter** | `services/auth_service.dart` | Add `verifyLicenseWithDMT()` | ✅ |
| **Flutter** | `screens/auth/driver_signup_screen.dart` | 6 targeted changes | ✅ |

---

# 🚀 Deployment Order

```
Step 1 ─ Create new GitHub repository for DMT server
          Repository name suggestion: e-fine-sl-dmt-server

Step 2 ─ Push DMT server code to new repo

Step 3 ─ Deploy DMT server on Render
          Service Type: Web Service
          Build Command: npm install
          Start Command: node server.js
          Environment Variables: PORT, MONGODB_URI, DMT_API_KEY, NODE_ENV

Step 4 ─ Run seed via Render Shell (one time):
          npm run seed
          Verify log: "[DMT-SEED] Successfully seeded 60 license records."

Step 5 ─ Copy the DMT Render URL
          e.g. https://e-fine-sl-dmt-server.onrender.com

Step 6 ─ Update e-Fine SL main backend .env on Render:
          DMT_SERVER_URL=https://e-fine-sl-dmt-server.onrender.com
          DMT_API_KEY=dmt_efinesl_secure_key_2025
          Restart the main backend service

Step 7 ─ Update Flutter app_constants.dart if needed
          Run: flutter clean && flutter pub get && flutter run

Step 8 ─ End-to-end test using TEST001 / 900000001V
```

---

# 🔐 Security Architecture

| Concern | How It Is Handled |
|---------|------------------|
| DMT API key exposed in Flutter | ✅ Flutter calls main backend only — key stays server-side |
| Unauthorized access to DMT server | ✅ `x-dmt-api-key` header required on every request |
| Brute force license scanning | ✅ Rate limiter: 100 req per 15 min per IP |
| SQL/NoSQL injection | ✅ Mongoose schema strict typing + regex anchored queries |
| Man-in-the-middle | ✅ HTTPS enforced on Render deployments |
| DMT URL leaked from app | ✅ DMT URL is only in main backend `.env` — not in Flutter |

---

**Document Version:** 2.0 (Confirmed Requirements)  
**Last Updated:** 2026-04-26  
**Project:** e-Fine SL Traffic Management System  
**DMT Server:** Separate Repository → Render  
**Dummy Data:** 60 records (55 realistic + 5 test records)  
**Fallback:** Registration blocked if DMT unreachable
