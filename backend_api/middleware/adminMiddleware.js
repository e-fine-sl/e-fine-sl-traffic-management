// middleware/adminMiddleware.js
// Verifies the user token locally since admin handles its own JWTs and 2FA.
// Also verifies the user has an admin-level role.

const jwt = require('jsonwebtoken');
const Admin = require('../models/adminModel');
const { HTTP } = require('../config/constants');

/**
 * protectAdmin — Validates local admin token and checks admin role.
 */
const protectAdmin = async (req, res, next) => {
  let token;

  const authHeader = req.headers.authorization;

  if (authHeader && authHeader.startsWith('Bearer ')) {
    try {
      token = authHeader.split(' ')[1];

      // Decode the token using local secret since adminLogin issues local JWTs
      const decoded = jwt.verify(token, process.env.JWT_SECRET);

      // Verify the user exists in Admin database
      req.user = await Admin.findById(decoded.id).select('-password');

      if (!req.user) {
        return res.status(HTTP.FORBIDDEN).json({ message: 'Not authorized, admin not found' });
      }

      const adminRoles = ['admin', 'super_admin', 'admin_officer', 'finance_officer'];
      if (!adminRoles.includes(req.user.role)) {
        return res.status(HTTP.FORBIDDEN).json({ message: 'Not authorized, insufficient role' });
      }

      next();

    } catch (error) {
      console.error('[ADMIN/PROTECT] Token verification error:', error.message);
      return res.status(HTTP.UNAUTHORIZED).json({ message: 'Not authorized, token failed' });
    }
  }

  if (!token) {
    return res.status(HTTP.UNAUTHORIZED).json({ message: 'Not authorized, no token provided' });
  }
};

/**
 * requireRole — Role-based access check middleware.
 * Usage: router.get('/route', protectAdmin, requireRole('super_admin'), handler)
 */
const requireRole = (...roles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(HTTP.UNAUTHORIZED).json({ message: 'Not authorized' });
    }
    if (!roles.includes(req.user.role)) {
      return res.status(HTTP.FORBIDDEN).json({
        message: 'Access denied - insufficient permissions',
        requiredRole: roles,
        userRole: req.user.role,
      });
    }
    next();
  };
};

module.exports = { protectAdmin, requireRole };
