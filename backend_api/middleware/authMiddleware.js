// middleware/authMiddleware.js
// UPDATED: Token validation is now delegated to the Auth Microservice.
// Instead of verifying JWTs locally, this middleware calls GET /auth/verify
// on the auth-service, which validates the token and returns the user payload.
// This ensures single source of truth for auth logic.

const https  = require('https');
const http   = require('http');
const { HTTP } = require('../config/constants');

/**
 * Makes a lightweight HTTP/HTTPS GET request to the auth-service /verify endpoint.
 * Using built-in Node http/https to avoid adding axios dependency.
 */
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
        'Content-Type':      'application/json',
      },
      // Allow self-signed certs in development
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
 * protect — Validates access token via auth-service.
 * Attaches req.user = { id, userId, email, role } on success.
 * Compatible with existing code that uses req.user.id
 */
const protect = async (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    console.warn(`[AUTH/PROTECT] No token provided for URL: ${req.originalUrl}`);
    return res.status(HTTP.UNAUTHORIZED).json({ message: 'Not authorized, no token' });
  }

  const token = authHeader.split(' ')[1];
  const authServiceUrl = process.env.AUTH_SERVICE_URL || 'http://localhost:4000';

  try {
    console.log(`[AUTH/PROTECT] Verifying token via auth-service for: ${req.originalUrl}`);
    const { statusCode, body } = await callAuthVerify(authServiceUrl, token);

    if (statusCode === 200 && body.success) {
      req.user = body.user; // { id, userId, email, role }
      console.log(`[AUTH/PROTECT] Verified — role: ${body.user.role}`);
      return next();
    }

    console.warn(`[AUTH/PROTECT] Auth-service rejected token: ${body.message}`);
    return res.status(HTTP.UNAUTHORIZED).json({ message: body.message || 'Not authorized, token failed' });

  } catch (error) {
    console.error('[AUTH/PROTECT] Failed to reach auth-service:', error.message);
    return res.status(HTTP.UNAUTHORIZED).json({
      message: 'Auth service unavailable. Please try again later.',
    });
  }
};

module.exports = { protect };
