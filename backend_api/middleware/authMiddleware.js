const jwt = require('jsonwebtoken');
const { HTTP, ROLES } = require('../config/constants');
const Driver = require('../models/driverModel');
const Police = require('../models/policeModel');

/**
 * protect — Validates access token locally.
 * Attaches req.user on success.
 */
const protect = async (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    console.warn(`[AUTH/PROTECT] No token provided for URL: ${req.originalUrl}`);
    return res.status(HTTP.UNAUTHORIZED).json({ message: 'Not authorized, no token' });
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'secret123');
    
    let user = await Police.findById(decoded.id).select('-password');
    let role = ROLES.POLICE;

    if (!user) {
      user = await Driver.findById(decoded.id).select('-password');
      role = ROLES.DRIVER;
    }

    if (!user) {
      return res.status(HTTP.UNAUTHORIZED).json({ message: 'Not authorized, user not found' });
    }

    req.user = user;
    req.user.role = user.role || role; 

    console.log(`[AUTH/PROTECT] Verified — role: ${req.user.role}`);
    return next();
  } catch (error) {
    console.error('[AUTH/PROTECT] Token verification failed:', error.message);
    return res.status(HTTP.UNAUTHORIZED).json({
      message: 'Not authorized, token failed',
    });
  }
};

module.exports = { protect };
