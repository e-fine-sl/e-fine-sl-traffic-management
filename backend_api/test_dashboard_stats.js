#!/usr/bin/env node

/**
 * Test script for Dashboard Stats API
 * 
 * Usage:
 *   node test_dashboard_stats.js <badge_number> [<authorization_token>]
 * 
 * Example:
 *   node test_dashboard_stats.js OP-001 "eyJhbGc..."
 */

const http = require('http');
const https = require('https');
const mongoose = require('mongoose');
require('dotenv').config();

const API_BASE = process.env.API_URL || 'http://localhost:5000';
const TEST_BADGE = process.argv[2] || 'OP-001';
const TEST_TOKEN = process.argv[3] || 'test-token';

console.log('\n[TEST] Starting Dashboard Stats API Test...\n');
console.log('Config:');
console.log(`  API Base URL: ${API_BASE}`);
console.log(`  Badge Number: ${TEST_BADGE}`);
console.log(`  Token: ${TEST_TOKEN.substring(0, 20)}...\n`);

// Function to make HTTP request
const makeRequest = (url, options) => {
  return new Promise((resolve, reject) => {
    const protocol = url.startsWith('https') ? https : http;
    const req = protocol.get(url, options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body: data ? JSON.parse(data) : null,
            rawBody: data
          });
        } catch (e) {
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body: null,
            rawBody: data
          });
        }
      });
    });
    req.on('error', reject);
  });
};

// Test database connection
const testDatabaseConnection = async () => {
  console.log('Testing Database Connection...');
  try {
    if (mongoose.connection.readyState !== 1) {
      await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/efine');
    }
    console.log('  [OK] Connected to MongoDB\n');
    return true;
  } catch (error) {
    console.log(`  [ERROR] Failed to connect: ${error.message}\n`);
    return false;
  }
};

// Test database data
const testDatabaseData = async () => {
  try {
    const IssuedFine = require('./models/issuedFineModel');
    
    console.log('Database Statistics:');
    const totalFines = await IssuedFine.countDocuments();
    console.log(`  Total fines: ${totalFines}`);
    
    const officers = await IssuedFine.distinct('policeOfficerId');
    console.log(`  Officers with fines: ${officers.join(', ') || 'None'}`);
    
    const finesForOfficer = await IssuedFine.countDocuments({ policeOfficerId: TEST_BADGE });
    console.log(`  Fines for ${TEST_BADGE}: ${finesForOfficer}\n`);
    
    if (finesForOfficer > 0) {
      const samples = await IssuedFine.find({ policeOfficerId: TEST_BADGE })
        .limit(2)
        .select('vehicleNumber offenseName amount date status');
      console.log('  Sample fines:');
      samples.forEach((fine, idx) => {
        console.log(`    ${idx + 1}. ${fine.vehicleNumber} - ${fine.offenseName} - Rs.${fine.amount}`);
      });
      console.log('');
    }
    
    return true;
  } catch (error) {
    console.log(`  [ERROR] Error: ${error.message}\n`);
    return false;
  }
};

// Test API endpoint
const testAPIEndpoint = async () => {
  console.log('Testing API Endpoint:');
  const apiUrl = `${API_BASE}/api/fines/dashboard-stats?policeOfficerId=${TEST_BADGE}`;
  console.log(`  URL: ${apiUrl}`);
  
  const options = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${TEST_TOKEN}`
    }
  };
  
  try {
    const response = await makeRequest(apiUrl, options);
    console.log(`  Status Code: ${response.statusCode}`);
    
    if (response.statusCode === 200) {
      console.log('  [OK] Response received successfully\n');
      console.log('  Response Data:');
      console.log(`    Daily Fines Count: ${response.body.dailyFinesCount || 0}`);
      console.log(`    Daily Total Amount: Rs.${response.body.dailyTotalAmount || 0}`);
      console.log(`    Recent Fines: ${response.body.recentFines?.length || 0}`);
      
      if (response.body.recentFines && response.body.recentFines.length > 0) {
        console.log('\n  Recent Fines Details:');
        response.body.recentFines.forEach((fine, idx) => {
          console.log(`    ${idx + 1}. ${fine.vehicleNumber} - ${fine.offenseName}`);
          console.log(`       Amount: Rs.${fine.amount} | Status: ${fine.status} | Date: ${fine.date}`);
        });
      }
      console.log('');
      return true;
    } else if (response.statusCode === 404) {
      console.log('  [ERROR] Endpoint not found (404)');
      console.log('  [INFO] Make sure the route is registered in fineRoutes.js\n');
      return false;
    } else if (response.statusCode === 400) {
      console.log(`  [ERROR] Bad Request: ${response.body?.message}\n`);
      return false;
    } else if (response.statusCode === 500) {
      console.log(`  [ERROR] Server Error: ${response.body?.message}\n`);
      console.log('  Backend Error Details:', response.body?.error || 'N/A');
      console.log('');
      return false;
    } else {
      console.log(`  [ERROR] Unexpected status code: ${response.statusCode}`);
      console.log('  Response:', response.rawBody || response.body);
      console.log('');
      return false;
    }
  } catch (error) {
    console.log(`  [ERROR] Connection failed: ${error.message}`);
    console.log('  [INFO] Make sure the backend server is running on', API_BASE, '\n');
    return false;
  }
};

// Main test runner
const runTests = async () => {
  const dbConnected = await testDatabaseConnection();
  
  if (dbConnected) {
    await testDatabaseData();
  }
  
  const apiWorking = await testAPIEndpoint();
  
  // Summary
  console.log('Test Summary:');
  console.log(`  Database: ${dbConnected ? '[OK]' : '[FAILED]'}`);
  console.log(`  API Endpoint: ${apiWorking ? '[OK]' : '[FAILED]'}`);
  console.log('');
  
  if (!apiWorking) {
    console.log('Troubleshooting Tips:');
    console.log('  1. Ensure backend server is running: npm start');
    console.log('  2. Check if API_BASE_URL is correct');
    console.log('  3. Verify fines exist in database for this officer');
    console.log('  4. Check backend logs for errors');
    console.log('');
  }
  
  process.exit(apiWorking ? 0 : 1);
};

// Run tests
runTests().catch(error => {
  console.error('Test Error:', error);
  process.exit(1);
});
