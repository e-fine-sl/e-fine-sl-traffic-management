const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const mongoose = require('mongoose');
const IssuedFine = require('./models/issuedFineModel');
const Offense = require('./models/offenseModel');
const { flagPaymentDispute } = require('./controllers/adminPaymentController');

function createMockRes() {
    return {
        statusCode: 200,
        data: null,
        status(c) { this.statusCode = c; return this; },
        json(d) { this.data = d; return this; }
    };
}

async function testDisputeFeature() {
    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log('✅ Connected to MongoDB for Dispute feature test.');

        let offense = await Offense.findOne();
        if (!offense) {
            offense = await Offense.create({ offenseName: 'Test Violation', amount: 1500, demeritValue: 2 });
        }

        const testFine = await IssuedFine.create({
            licenseNumber: 'DISPUTE-TEST-01',
            vehicleNumber: 'WP-TEST-DISP',
            offenseId: offense._id,
            offenseName: offense.offenseName,
            amount: 1500,
            place: 'Colombo Main Street',
            policeOfficerId: 'OP-DISP-01',
            status: 'UNPAID'
        });

        console.log('Created test fine:', testFine._id.toString());

        const mockReq = {
            body: {
                paymentId: testFine._id.toString(),
                disputeCategory: 'DRIVER_APPEAL',
                reason: 'Citizen claims vehicle was under mechanic repair on the violation date.',
                notes: 'Case filed under magistrate inquiry #AP-990.'
            },
            user: { name: 'Admin Officer Perera', role: 'admin_officer' }
        };

        const mockRes = createMockRes();
        await flagPaymentDispute(mockReq, mockRes);

        console.log('Dispute Endpoint Status Code:', mockRes.statusCode);
        console.log('Response Message:', mockRes.data?.message);

        const reloaded = await IssuedFine.findById(testFine._id);
        console.log('Reloaded Status in DB:', reloaded.status);
        console.log('Reloaded Dispute Reason:', reloaded.disputeReason);
        console.log('Reloaded Notes:', reloaded.paymentNotes);

        if (mockRes.statusCode === 200 && reloaded.status === 'DISPUTED' && reloaded.disputeReason.includes('DRIVER_APPEAL')) {
            console.log('✅ TEST PASSED: Manual dispute flagging working seamlessly!');
        } else {
            console.error('❌ TEST FAILED: Dispute was not flagged properly.');
        }

        await IssuedFine.findByIdAndDelete(testFine._id);
        console.log('🧹 Cleaned up test fixture.');
        process.exit(0);

    } catch (err) {
        console.error('❌ Error during dispute feature test:', err);
        process.exit(1);
    }
}

testDisputeFeature();
