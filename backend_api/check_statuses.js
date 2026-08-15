const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const mongoose = require('mongoose');

async function checkAndNormalize() {
    await mongoose.connect(process.env.MONGO_URI);
    const db = mongoose.connection.db;
    const statuses = await db.collection('issuedfines').distinct('status');
    console.log('Current distinct statuses in DB:', statuses);

    const counts = {};
    for (const st of statuses) {
        counts[st] = await db.collection('issuedfines').countDocuments({ status: st });
    }
    console.log('Counts per status in DB:', counts);

    process.exit(0);
}

checkAndNormalize();
