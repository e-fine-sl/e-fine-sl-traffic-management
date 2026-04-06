// middleware/adminMiddleware.js
// UPDATED: Delegates token verification to auth-service (same pattern as authMiddleware).
// Also verifies the user has an admin-level role.

const https  = require('https');
const http   = require('http');
const { HTTP } = require('../config/constants');

const callAuthVerify = (authServiceUrl, token) => {
  return new Promise((resolve, reject) => {
    const url = new URL(`${authServiceUrl}/auth/verify`);
    const isHttps = url.protocol === 'https:';
    const lib = isHttps ? https : http;

    const options = {
      hostname: url.hostname,
      port:     url.port || (isHttps ? 443 : 80),
      path:     url.pathname,
      method:   'GET',
      headers:  {
        'Authorization':     `Bearer ${token}`,
        'x-internal-secret': process.env.INTERNAL_SECRET || '',
      },
      rejectUnauthorized: process.env.NODE_ENV === 'production',
    };

    const req = lib.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => { body += chunk; });
      res.on('end', () => {
        try {
          resolve({ statusCode: res.statusCode, body: JSON.parse(body) });
        } catch {
          reject(new Error('Invalid JSON from auth-service'));
        }
      });
    });

    req.on('error', reject);
    req.end();
  });
};

/**
 * protectAdmin — Validates token via auth-service, then checks admin role.
 */
const protectAdmin = async (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(HTTP.UNAUTHORIZED).json({ message: 'Not authorized, no token provided' });
  }

  const token = authHeader.split(' ')[1];
  const authServiceUrl = process.env.AUTH_SERVICE_URL || 'http://localhost:4000';

  try {
    const { statusCode, body } = await callAuthVerify(authServiceUrl, token);

    if (statusCode !== 200 || !body.success) {
      return res.status(HTTP.UNAUTHORIZED).json({ message: body.message || 'Not authorized, invalid token' });
    }

    const adminRoles = ['admin', 'super_admin', 'admin_officer', 'finance_officer'];
    if (!adminRoles.includes(body.user.role)) {
      return res.status(HTTP.FORBIDDEN).json({ message: 'Not authorized, admin not found' });
    }

    req.user = body.user;
    next();

  } catch (error) {
    console.error('[ADMIN/PROTECT] Auth service error:', error.message);
    return res.status(HTTP.UNAUTHORIZED).json({ message: 'Not authorized, invalid token' });
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
