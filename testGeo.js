require('dotenv').config({ path: 'backend_api/.env' });
const mongoose = require('mongoose');
const Station = require('./backend_api/models/stationModel');

mongoose.connect(process.env.MONGO_URI).then(async () => {
  console.log('Connected to DB');
  
  try {
    const db = mongoose.connection.db;
    const indexes = await db.collection('stations').indexes();
    console.log('Indexes on stations:', JSON.stringify(indexes, null, 2));

    const longitude = 79.877033;
    const latitude = 6.870016;
    const STATION_RADIUS_METERS = 10000;

    const nearbyStations = await Station.find({
      'location.type': 'Point',
      location: {
        $near: {
          $geometry: { type: 'Point', coordinates: [longitude, latitude] },
          $maxDistance: STATION_RADIUS_METERS
        }
      }
    }).select('name stationCode officialEmail location');

    console.log(`Found ${nearbyStations.length} stations`);
    console.log(JSON.stringify(nearbyStations, null, 2));

  } catch (err) {
    console.error('Error during geo query:', err);
  }

  process.exit(0);
}).catch(err => {
  console.error('DB Connection error:', err);
  process.exit(1);
});
