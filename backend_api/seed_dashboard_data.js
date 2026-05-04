#!/usr/bin/env node

/**
 * Seed Dashboard Data - Generate test fines for dashboard testing
 * 
 * Usage:
 *   node seed_dashboard_data.js <badge_number> [count]
 * 
 * Example:
 *   node seed_dashboard_data.js OP-001 5
 */

require('dotenv').config();
const mongoose = require('mongoose');
const Offense = require('./models/offenseModel');
const IssuedFine = require('./models/issuedFineModel');

const BADGE_NUMBER = process.argv[2] || 'OP-001';
const FINE_COUNT = parseInt(process.argv[3]) || 3;

console.log('\n🌱 Seeding Dashboard Test Data...\n');
console.log(`Config:`);
console.log(`  Badge Number: ${BADGE_NUMBER}`);
console.log(`  Fines to Create: ${FINE_COUNT}\n`);

// Sample vehicle numbers and license numbers
const testVehicles = [
  { vehicle: 'ABC-1234', license: 'DL-2020-12345' },
  { vehicle: 'XYZ-5678', license: 'DL-2019-67890' },
  { vehicle: 'PQR-9876', license: 'DL-2021-11111' },
  { vehicle: 'LMN-4321', license: 'DL-2018-22222' },
  { vehicle: 'DEF-8765', license: 'DL-2020-33333' },
];

const testOffenses = [
  'Speeding',
  'Running Red Light',
  'Illegal Parking',
  'No Helmet',
  'Overloading',
];

const testPlaces = [
  'Colombo Main Street',
  'Galle Road Junction',
  'Independence Avenue',
  'Peradeniya Road',
  'Mount Lavinia Beach Road',
];

async function seedData() {
  try {
    // Connect to MongoDB
    console.log(' Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/efine');
    console.log(' Connected!\n');

    // Get available offenses
    console.log(' Fetching available offenses...');
    const offenses = await Offense.find({}).limit(5);
    if (offenses.length === 0) {
      console.log(' No offenses found in database!');
      console.log('   Please add offenses first using the admin panel.\n');
      await mongoose.connection.close();
      return;
    }
    console.log(` Found ${offenses.length} offenses\n`);

    // Generate test fines
    console.log(`� Creating ${FINE_COUNT} test fines...\n`);
    const createdFines = [];

    for (let i = 0; i < FINE_COUNT; i++) {
      const vehicle = testVehicles[i % testVehicles.length];
      const offense = offenses[i % offenses.length];
      
      // Create dates - some today, some recent
      let fineDate = new Date();
      if (i > 0) {
        fineDate.setDate(fineDate.getDate() - i);
      }

      const fineData = {
        licenseNumber: vehicle.license,
        vehicleNumber: vehicle.vehicle,
        offenseId: offense._id,
        offenseName: offense.offenseName,
        amount: offense.amount,
        place: testPlaces[i % testPlaces.length],
        policeOfficerId: BADGE_NUMBER,
        demeritPoints: offense.demeritValue || 0,
        status: i % 3 === 0 ? 'PAID' : (i % 3 === 1 ? 'UNPAID' : 'PENDING'),
        date: fineDate,
      };

      const fine = await IssuedFine.create(fineData);
      createdFines.push(fine);

      console.log(`   ${i + 1}. ${vehicle.vehicle} - ${offense.offenseName}`);
      console.log(`      License: ${vehicle.license}`);
      console.log(`      Amount: Rs.${offense.amount} | Status: ${fineData.status}`);
      console.log(`      Date: ${fineDate.toISOString()}`);
      console.log('');
    }

    // Verify data
    console.log('� Verification:');
    const totalFines = await IssuedFine.countDocuments({ policeOfficerId: BADGE_NUMBER });
    console.log(` Total fines for ${BADGE_NUMBER}: ${totalFines}`);

    // Check today's fines
    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);

    const todayFines = await IssuedFine.find({
      policeOfficerId: BADGE_NUMBER,
      date: { $gte: today, $lt: tomorrow }
    });
    
    console.log(` Fines today: ${todayFines.length}`);

    const totalAmount = todayFines.reduce((sum, fine) => sum + fine.amount, 0);
    console.log(` Total amount today: Rs.${totalAmount}\n`);

    console.log('✨ Seed data created successfully!\n');
    console.log('� Next steps:');
    console.log('   1. Ensure you\'re logged in as officer with badge: ' + BADGE_NUMBER);
    console.log('   2. Go to Police Home Screen');
    console.log('   3. Pull down to refresh dashboard');
    console.log('   4. You should see the test fines!\n');

    await mongoose.connection.close();
  } catch (error) {
    console.error(' Error seeding data:', error.message);
    console.error(error);
    process.exit(1);
  }
}

seedData();
