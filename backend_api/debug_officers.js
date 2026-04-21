require('dotenv').config();
const mongoose = require('mongoose');
const IssuedFine = require('./models/issuedFineModel');

async function checkOfficers() {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('Connected to MongoDB\n');

    const officers = await IssuedFine.distinct('policeOfficerId');
    const totalCount = await IssuedFine.countDocuments();

    console.log(`Total Fines: ${totalCount}`);
    console.log(`Officers: ${officers.join(', ')}\n`);

    for (const officer of officers) {
      const count = await IssuedFine.countDocuments({ policeOfficerId: officer });
      console.log(`${officer}: ${count} fines`);
    }

    // Show sample fine for each officer
    console.log('\nSample Fines:');
    for (const officer of officers) {
      const sample = await IssuedFine.findOne({ policeOfficerId: officer }).select('vehicleNumber offenseName amount policeOfficerId date');
      console.log(`${officer}: ${sample?.vehicleNumber} - ${sample?.offenseName} - Rs.${sample?.amount}`);
    }

    await mongoose.disconnect();
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

checkOfficers();
