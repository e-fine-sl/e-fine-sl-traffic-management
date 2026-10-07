const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const mongoose = require('mongoose');

async function migrate() {
    await mongoose.connect(process.env.MONGO_URI);
    const db = mongoose.connection.db;
    
    const unpaids = await db.collection('issuedfines').updateMany(
        { status: { $in: ['Unpaid', 'unpaid', 'pending', 'Pending'] } },
        { $set: { status: 'UNPAID' } }
    );
    console.log(`Migrated ${unpaids.modifiedCount} unpaid fine records to 'UNPAID'.`);

    const paids = await db.collection('issuedfines').updateMany(
        { status: { $in: ['Paid', 'paid'] } },
        { $set: { status: 'PAID' } }
    );
    console.log(`Migrated ${paids.modifiedCount} paid fine records to 'PAID'.`);

    const finalStatuses = await db.collection('issuedfines').distinct('status');
    console.log('Final distinct statuses in database:', finalStatuses);

    process.exit(0);
}

migrate();
