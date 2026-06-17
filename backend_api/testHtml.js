require('dotenv').config();
const sendEmail = require('./utils/sendEmail');
const { buildNearbyStationAlertHtml } = require('./utils/nearbyStationAlertEmail');

const html = buildNearbyStationAlertHtml({
  stationName: 'Test Station',
  stationCode: 'TEST',
  distanceKm: 5,
  driverName: 'Test Driver',
  licenseNumber: '12345',
  accidentType: 'Hit & Run',
  latitude: 6.87,
  longitude: 79.87,
  mapsLink: 'https://maps.google.com/?q=6.87,79.87',
  province: 'Western',
  district: 'Colombo',
  division: 'Colombo',
  reportedAt: new Date().toLocaleString()
});

sendEmail({
  email: process.env.EMAIL_USER,
  subject: 'Test HTML',
  html: html
}).then(() => {
  console.log('Success HTML email sent');
  process.exit(0);
}).catch(err => {
  console.error('Failed to send HTML email:', err);
  process.exit(1);
});
