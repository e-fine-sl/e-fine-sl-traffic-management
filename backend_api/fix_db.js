require('dotenv').config();
const mongoose = require('mongoose');

// Schema for pre-approved officers
const preApprovedSchema = new mongoose.Schema({
  badgeNumber: String,
  stationCode: String,
  isRegistered: { type: Boolean, default: false },
  registeredAt: { type: Date, default: null },
  notes: String
}, { strict: false, collection: 'preapprovedofficers' });

const PreApprovedOfficer = mongoose.models.PreApprovedOfficer || mongoose.model('PreApprovedOfficer', preApprovedSchema);

// Schema for polices to delete them
const policeSchema = new mongoose.Schema({}, { strict: false, collection: 'polices' });
const Police = mongoose.models.Police || mongoose.model('Police', policeSchema);

async function fixSeed() {
  try {
    await mongoose.connect(process.env.MONGO_URI, { useNewUrlParser: true, useUnifiedTopology: true });
    console.log('--- MongoDB Connected ---');

    // 1. Delete all existing pre-approved officers
    await PreApprovedOfficer.deleteMany({});
    console.log('✅ Deleted all existing pre-approved officers.');

    // 2. Delete all existing registered polices
    await Police.deleteMany({});
    console.log('✅ Deleted all existing records from polices collection.');

    // 3. Create 50 pre-approved officers starting from badge 12000
    const newOfficers = [];
    const stations = [
      { code: 'COL-01', note: 'Auto-generated - Colombo Fort (krasanjana81@gmail.com)' },
      { code: 'COL-03', note: 'Auto-generated - Cinnamon Gardens (krasanjana83@gmail.com)' },
      { code: 'COL-02', note: 'Auto-generated - Maradana (kavishkarasanjana217@gmail.com)' }
    ];

    let badgeStart = 12000;
    for (let i = 0; i < 50; i++) {
      const station = stations[i % 3]; // Round robin across the 3 stations
      newOfficers.push({
        badgeNumber: (badgeStart + i).toString(),
        stationCode: station.code,
        isRegistered: false,
        registeredAt: null,
        notes: station.note
      });
    }

    await PreApprovedOfficer.insertMany(newOfficers);
    console.log(`✅ ${newOfficers.length} Pre-Approved Officers seeded successfully! (12000 to ${12000 + 49})`);

  } catch (error) {
    console.error('Error:', error);
  } finally {
    mongoose.disconnect();
  }
}

fixSeed();
