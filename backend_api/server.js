const express = require('express');
const http = require('http');
const path = require('path');
const { Server } = require('socket.io');
const dotenv = require('dotenv');
const cors = require('cors');
const connectDB = require('./config/db');

dotenv.config();

connectDB();

const app = express();
const server = http.createServer(app);

// Initialize Socket.io
const io = new Server(server, {
  cors: {
    origin: '*', // In production, restrict this to the Admin Portal domain
    methods: ['GET', 'POST', 'PATCH']
  }
});
app.set('io', io);

const { APP } = require('./config/constants');

// Enable CORS
app.use(cors());

app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

// Serve static files (Uploaded Images)
app.use('/uploads', express.static(path.join(__dirname, 'public/uploads')));
// ----------------------------------------------------

// Routes
app.use('/api/auth', require('./routes/authRoutes'));
app.use('/api/stations', require('./routes/stationRoutes'));
app.use('/api/fines', require('./routes/fineRoutes'));
app.use('/api/payment', require('./routes/paymentRoutes')); // New Payment Route
app.use('/api/admin', require('./routes/adminRoutes')); // Admin Routes
app.use('/api/drivers', require('./routes/driverRoutes')); // Driver Demerit Routes
app.use('/api/kyc',     require('./routes/kyc'));           // KYC Face Verification
app.use('/api/sos',     require('./routes/sosRoutes'));     //  SOS Emergency Alert System
app.use('/api/accident', require('./routes/accidentRoutes'));  //  Accident Reports
app.use('/api/police',  require('./routes/policeRoutes'));  // Police Operations (HQ Alerts, etc)
app.use('/api/officer', require('./routes/officerRoutes'));  // Officer Session Tracking

app.get('/', (req, res) => {
  res.send('API is running successfully!');
});

// --- NEW CRITICAL additions for debugging KYC HTML Parsing Error ---

// 1. API 404 handler (forces JSON instead of Express HTML)
app.use((req, res, next) => {
  console.warn(`[404] Route Note Found: ${req.method} ${req.originalUrl}`);
  res.status(404).json({
    success: false,
    message: `API Route not found: ${req.method} ${req.originalUrl}`
  });
});

// 2. Global Error Handler (forces JSON instead of Express HTML on crashes, e.g. multer errors)
app.use((err, req, res, next) => {
  console.error('[GLOBAL ERROR]', {
    message: err.message,
    stack: err.stack,
    method: req.method,
    url: req.originalUrl,
    bodyType: typeof req.body,
    timestamp: new Date().toISOString()
  });

  const statusCode = err.status || err.statusCode || 500;
  res.status(statusCode).json({
    success: false,
    message: err.message || 'Internal Server Error',
    error: process.env.NODE_ENV === 'development' ? err.stack : undefined
  });
});

// -------------------------------------------------------------------

const PORT = process.env.PORT || APP.PORT;

server.listen(PORT, () => {
  console.log(`Server running in ${APP.ENV} mode on port ${PORT}`);
});

// Start cron jobs
require('./jobs/resetDemeritPoints');