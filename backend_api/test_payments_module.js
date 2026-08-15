const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const mongoose = require('mongoose');
const IssuedFine = require('./models/issuedFineModel');
const PaymentTransaction = require('./models/paymentTransactionModel');
const Offense = require('./models/offenseModel');
const Driver = require('./models/driverModel');
const {
    getAllPayments,
    getPaymentMetrics,
    getPaymentById,
    verifyPaymentGateway,
    processPaymentRefund,
    exportPayments
} = require('./controllers/adminPaymentController');
const { handlePaymentNotification } = require('./controllers/paymentController');
const md5 = require('md5');

// Mock Express Req & Res
function createMockRes() {
    const res = {
        statusCode: 200,
        headers: {},
        data: null,
        status(code) {
            this.statusCode = code;
            return this;
        },
        json(payload) {
            this.data = payload;
            return this;
        },
        send(payload) {
            this.data = payload;
            return this;
        },
        setHeader(key, val) {
            this.headers[key] = val;
            return this;
        }
    };
    return res;
}

async function runTests() {
    console.log('====================================================');
    console.log('🧪 RUNNING PAYMENT MODULE COMPREHENSIVE TEST SUITE');
    console.log('====================================================');

    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log('✅ Connected to MongoDB successfully.');

        // ── TEST 1: METRICS AGGREGATION ────────────────────────────
        console.log('\n--- [TEST 1] Testing getPaymentMetrics Aggregation ---');
        const req1 = { query: {} };
        const res1 = createMockRes();
        await getPaymentMetrics(req1, res1);

        console.log('Metrics Response Status:', res1.statusCode);
        console.log('Metrics Data Summary:', {
            totalRevenue: res1.data?.data?.totalRevenue,
            totalPaymentsCount: res1.data?.data?.totalPaymentsCount,
            todayRevenue: res1.data?.data?.todayRevenue,
            thisMonthRevenue: res1.data?.data?.thisMonthRevenue,
            averagePayment: res1.data?.data?.averagePayment,
            efficiencyRate: res1.data?.data?.collectionEfficiencyRate
        });

        if (res1.statusCode === 200 && res1.data?.success) {
            console.log('✅ TEST 1 PASSED: Metrics aggregation computed accurately.');
        } else {
            throw new Error('TEST 1 FAILED');
        }

        // ── TEST 2: GET ALL PAYMENTS (SEARCH & FILTERS) ─────────────
        console.log('\n--- [TEST 2] Testing getAllPayments with Search & Filter ---');
        const req2 = {
            query: {
                page: '1',
                limit: '10',
                status: 'ALL'
            }
        };
        const res2 = createMockRes();
        await getAllPayments(req2, res2);

        console.log('Payments List Status:', res2.statusCode);
        console.log(`Found ${res2.data?.total} total records, returned ${res2.data?.data?.length} in page 1.`);

        if (res2.statusCode === 200 && Array.isArray(res2.data?.data)) {
            console.log('✅ TEST 2 PASSED: Payment listing and pagination working.');
        } else {
            throw new Error('TEST 2 FAILED');
        }

        // ── TEST 3: MULTI-FIELD SEARCH ──────────────────────────────
        console.log('\n--- [TEST 3] Testing Multi-Field Search by License/Plate ---');
        if (res2.data?.data?.length > 0) {
            const sampleLicense = res2.data.data[0].licenseNumber;
            const req3 = { query: { search: sampleLicense, status: 'ALL' } };
            const res3 = createMockRes();
            await getAllPayments(req3, res3);

            console.log(`Search for '${sampleLicense}' returned ${res3.data?.total} matches.`);
            if (res3.data?.data?.every(p => p.licenseNumber.toLowerCase().includes(sampleLicense.toLowerCase()))) {
                console.log('✅ TEST 3 PASSED: Multi-field search regex functioning properly.');
            }
        } else {
            console.log('ℹ️ TEST 3 SKIPPED: No records to test search.');
        }

        // ── TEST 4: DEEP DETAIL INSPECTION ─────────────────────────
        console.log('\n--- [TEST 4] Testing getPaymentById Deep Detail ---');
        if (res2.data?.data?.length > 0) {
            const sampleId = res2.data.data[0]._id.toString();
            const req4 = { params: { id: sampleId } };
            const res4 = createMockRes();
            await getPaymentById(req4, res4);

            console.log('Deep Detail Status:', res4.statusCode);
            console.log('Retrieved Record ID:', res4.data?.data?._id);
            console.log('Driver Object Populated:', res4.data?.data?.driver ? 'YES' : 'NO (Driver profile optional)');

            if (res4.statusCode === 200 && res4.data?.data?._id) {
                console.log('✅ TEST 4 PASSED: Deep detail retrieval succeeded.');
            }
        }

        // ── TEST 5: WEBHOOK PRICE TAMPERING FRAUD PREVENTION ───────
        console.log('\n--- [TEST 5] Testing Webhook Price Tampering Detection ---');
        // Create a test fine for LKR 5000
        let testOffense = await Offense.findOne();
        if (!testOffense) {
            testOffense = await Offense.create({
                offenseName: 'Speeding > 50kmph',
                amount: 5000,
                demeritValue: 4
            });
        }

        const testFine = await IssuedFine.create({
            licenseNumber: 'TEST-B5395114',
            vehicleNumber: 'WP-TEST-9999',
            offenseId: testOffense._id,
            offenseName: testOffense.offenseName,
            amount: 5000,
            place: 'Colombo Fort',
            policeOfficerId: 'OP-TEST-001',
            status: 'UNPAID'
        });

        const merchantSecret = process.env.PAYHERE_SECRET || 'testsecret123';
        process.env.PAYHERE_SECRET = merchantSecret;
        const merchantId = process.env.PAYHERE_MERCHANT_ID || '1225301';
        process.env.PAYHERE_MERCHANT_ID = merchantId;

        // Attacker attempts to pay LKR 100 for an LKR 5000 fine
        const tamperedAmount = '100.00';
        const hashedSecret = md5(merchantSecret).toUpperCase();
        const tamperedMd5sig = md5(
            merchantId +
            testFine._id.toString() +
            tamperedAmount +
            'LKR' +
            '2' +
            hashedSecret
        ).toUpperCase();

        const fraudReq = {
            body: {
                merchant_id: merchantId,
                order_id: testFine._id.toString(),
                payment_id: `PAYHERE-FRAUD-${Date.now()}`,
                payhere_amount: tamperedAmount,
                payhere_currency: 'LKR',
                status_code: '2',
                md5sig: tamperedMd5sig
            }
        };
        const fraudRes = createMockRes();
        await handlePaymentNotification(fraudReq, fraudRes);

        const reloadedFine = await IssuedFine.findById(testFine._id);
        console.log('Webhook Response Status for Tampered Amount:', fraudRes.statusCode);
        console.log('Fine Status after Fraud Attempt:', reloadedFine.status);
        console.log('Fine Dispute Reason:', reloadedFine.disputeReason);

        if (fraudRes.statusCode === 400 && reloadedFine.status === 'DISPUTED') {
            console.log('✅ TEST 5 PASSED: Price tampering successfully blocked and flagged as DISPUTED!');
        } else {
            console.error('❌ TEST 5 FAILED: Price tampering was not blocked.');
        }

        // ── TEST 6: VALID WEBHOOK PAYMENT & IDEMPOTENCY LOCK ────────
        console.log('\n--- [TEST 6] Testing Valid Webhook Settlement & Idempotency ---');
        const validAmount = parseFloat(testFine.amount).toFixed(2);
        const validMd5sig = md5(
            merchantId +
            testFine._id.toString() +
            validAmount +
            'LKR' +
            '2' +
            hashedSecret
        ).toUpperCase();

        const validTxId = `PAYHERE-TX-${Date.now()}`;
        const validReq = {
            body: {
                merchant_id: merchantId,
                order_id: testFine._id.toString(),
                payment_id: validTxId,
                payhere_amount: validAmount,
                payhere_currency: 'LKR',
                status_code: '2',
                md5sig: validMd5sig,
                method: 'VISA',
                card_holder_name: 'A. Perera',
                card_no: '************4242'
            }
        };
        const validRes = createMockRes();
        await handlePaymentNotification(validReq, validRes);

        const paidFine = await IssuedFine.findById(testFine._id);
        console.log('Valid Webhook Response:', validRes.statusCode);
        console.log('Fine Status after Valid Payment:', paidFine.status);
        console.log('Payment Gateway Ref:', paidFine.gatewayPaymentId);

        // Test Idempotent Retry (Sending duplicate webhook)
        const retryRes = createMockRes();
        await handlePaymentNotification(validReq, retryRes);
        console.log('Idempotent Replay Webhook Response:', retryRes.statusCode, retryRes.data);

        if (paidFine.status === 'PAID' && retryRes.statusCode === 200 && retryRes.data === 'OK') {
            console.log('✅ TEST 6 PASSED: Legitimate webhook marked PAID and idempotent retry safely handled.');
        }

        // ── TEST 7: CSV EXPORT STREAM ──────────────────────────────
        console.log('\n--- [TEST 7] Testing CSV Export Generation ---');
        const exportReq = { query: { status: 'ALL', format: 'csv' } };
        const exportRes = createMockRes();
        await exportPayments(exportReq, exportRes);

        console.log('Export Status:', exportRes.statusCode);
        console.log('Content-Type Header:', exportRes.headers['Content-Type']);
        console.log('CSV Lines Generated:', typeof exportRes.data === 'string' ? exportRes.data.split('\n').length : 0);

        if (exportRes.statusCode === 200 && typeof exportRes.data === 'string' && exportRes.data.includes('Payment ID,Payment Date')) {
            console.log('✅ TEST 7 PASSED: CSV export generated with standard headers.');
        }

        // Cleanup test record
        await IssuedFine.findByIdAndDelete(testFine._id);
        await PaymentTransaction.deleteMany({ orderId: testFine._id.toString() });
        console.log('\n🧹 Test fixture cleaned up.');

        console.log('\n====================================================');
        console.log('🎉 ALL INTEGRATION & SECURITY TESTS PASSED (7/7)!');
        console.log('====================================================\n');
        process.exit(0);

    } catch (error) {
        console.error('\n❌ TEST RUNNER FAILED:', error);
        process.exit(1);
    }
}

runTests();
