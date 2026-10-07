// middleware/authMiddleware.js
// Verify JWTs locally

const jwt = require('jsonwebtoken');
const { HTTP } = require('../config/constants');
const Police = require('../models/policeModel');
const Driver = require('../models/driverModel');

/**
 * protect — Validates access token locally.
 * Attaches req.user = { id } on success.
 */
const protect = async (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    console.warn(`[AUTH/PROTECT] No token provided for URL: ${req.originalUrl}`);
    return res.status(HTTP.UNAUTHORIZED).json({ message: 'Not authorized, no token' });
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = { id: decoded.id };
    return next();
  } catch (error) {
    console.warn(`[AUTH/PROTECT] Token verification failed: ${error.message}`);
    return res.status(HTTP.UNAUTHORIZED).json({ message: 'Not authorized, token failed' });
  }
};

module.exports = { protect };
