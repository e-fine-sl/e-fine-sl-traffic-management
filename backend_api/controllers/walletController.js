const Driver = require('../models/driverModel');
const { HTTP } = require('../config/constants');
const https = require('https');

// Helper to use native fetch/https if needed, but since we are mocking, let's proxy to the mock loader
const fetchMockWallet = (nic, licenseNumber) => {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({ nic, licenseNumber });
    const options = {
      hostname: 'efine-mock-data-loader.onrender.com',
      port: 443,
      path: '/api/wallet/verify',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': data.length
      }
    };

    const req = https.request(options, res => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          resolve({ statusCode: res.statusCode, body: JSON.parse(body) });
        } catch (e) {
          reject(e);
        }
      });
    });

    req.on('error', error => reject(error));
    req.write(data);
    req.end();
  });
};

/**
 * @desc    Get the current authenticated user's wallet details
 * @route   GET /api/wallet
 * @access  Private (Driver only)
 */
const getMyWallet = async (req, res) => {
  try {
    // 1. Ensure user is a driver
    if (req.user.role !== 'driver') {
      return res.status(HTTP.FORBIDDEN).json({
        success: false,
        message: 'Only drivers can access the wallet'
      });
    }

    // 2. Fetch driver from DB to get NIC and License Number
    const driver = await Driver.findById(req.user.id || req.user.userId);
    
    if (!driver) {
      return res.status(HTTP.NOT_FOUND).json({
        success: false,
        message: 'Driver profile not found'
      });
    }

    if (!driver.nic || !driver.licenseNumber) {
      return res.status(HTTP.BAD_REQUEST).json({
        success: false,
        message: 'NIC or License Number missing from profile'
      });
    }

    // 3. Proxy request to mock_data_loader to get the wallet data
    // In the future, this will be replaced with real DB queries to emission/insurance APIs
    try {
      const response = await fetchMockWallet(driver.nic, driver.licenseNumber);
      
      if (response.statusCode === 200 && response.body.success) {
        return res.status(HTTP.OK).json({
          success: true,
          wallet: response.body.wallet
        });
      } else {
        return res.status(response.statusCode).json(response.body);
      }
    } catch (proxyError) {
      console.error('[WALLET] Proxy error:', proxyError);
      return res.status(HTTP.SERVER_ERROR).json({
        success: false,
        message: 'Failed to retrieve wallet data from provider (Too many requests or provider is down)'
      });
    }

  } catch (error) {
    console.error('[WALLET] Error fetching wallet:', error);
    res.status(HTTP.SERVER_ERROR).json({
      success: false,
      message: 'Server Error: ' + error.message
    });
  }
};

module.exports = {
  getMyWallet
};
