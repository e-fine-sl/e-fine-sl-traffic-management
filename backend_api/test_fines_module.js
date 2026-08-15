/**
 * Automated Test Suite for Fines & Citations Management Controller
 * Run with: node backend_api/test_fines_module.js
 */

const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const IssuedFine = require('./models/issuedFineModel');
const Offense = require('./models/offenseModel');
const Driver = require('./models/driverModel');
const adminFineController = require('./controllers/adminFineController');

const mockRes = () => {
    const res = {};
    res.statusCode = 200;
    res.headers = {};
    res.status = function(code) {
        this.statusCode = code;
        return this;
    };
    res.setHeader = function(key, val) {
        this.headers[key] = val;
        return this;
    };
    res.json = function(payload) {
        this.data = payload;
        return this;
    };
    res.send = function(payload) {
        this.data = payload;
        return this;
    };
    return res;
};

async function runTests() {
    console.log('\n======================================================');
    console.log('🧪 RUNNING FINES & CITATIONS CONTROLLER INTEGRATION TESTS');
    console.log('======================================================\n');

    let passed = 0;
    let failed = 0;

    try {
        const mongoUri = process.env.MONGODB_URI || process.env.MONGO_URI || 'mongodb://localhost:27017/efine_db';
        await mongoose.connect(mongoUri);
        console.log('✅ Connected to MongoDB successfully.\n');

        // Test 1: getFineMetrics
        try {
            const req = {};
            const res = mockRes();
            await adminFineController.getFineMetrics(req, res);

            if (res.statusCode === 200 && res.data.success && res.data.data.totalFines !== undefined) {
                console.log(`✅ [1/7] getFineMetrics passed: Total Fines=${res.data.data.totalFines}, Collection Rate=${res.data.data.collectionRate}%`);
                passed++;
            } else {
                throw new Error(`Invalid metrics response: ${JSON.stringify(res.data)}`);
            }
        } catch (e) {
            console.error('❌ [1/7] getFineMetrics failed:', e.message);
            failed++;
        }

        // Test 2: getAllFines (Pagination, Search & Filter)
        try {
            const req = { query: { page: '1', limit: '10', status: 'ALL' } };
            const res = mockRes();
            await adminFineController.getAllFines(req, res);

            if (res.statusCode === 200 && res.data.success && Array.isArray(res.data.data)) {
                console.log(`✅ [2/7] getAllFines passed: returned ${res.data.data.length} fines (total: ${res.data.total})`);
                passed++;
            } else {
                throw new Error(`Failed to list fines: ${JSON.stringify(res.data)}`);
            }
        } catch (e) {
            console.error('❌ [2/7] getAllFines failed:', e.message);
            failed++;
        }

        // Setup mock offense & driver for creation test
        let sampleOffense = await Offense.findOne();
        if (!sampleOffense) {
            sampleOffense = await Offense.create({
                offenseName: 'Test Speeding Violation',
                amount: 3000,
                demeritPoints: 2,
                category: 'SPEEDING',
                sectionOfAct: 'Sec 140'
            });
        }

        // Test 3: createFine (Manual / Court Citation)
        let createdFineId = null;
        try {
            const req = {
                body: {
                    licenseNumber: 'B9999999',
                    vehicleNumber: 'WP-CAD-9999',
                    offenseId: sampleOffense._id.toString(),
                    place: 'Colombo Fort Junction',
                    policeStation: 'Colombo Fort Station',
                    policeOfficerId: 'TEST-OFFICER-001',
                    notes: 'Automated test citation'
                },
                user: { name: 'Test Super Admin', email: 'admin@efine.gov.lk' }
            };
            const res = mockRes();
            await adminFineController.createFine(req, res);

            if (res.statusCode === 201 && res.data.success && res.data.data._id) {
                createdFineId = res.data.data._id;
                console.log(`✅ [3/7] createFine passed: Created fine #${createdFineId}`);
                passed++;
            } else {
                throw new Error(`Failed to create fine: ${JSON.stringify(res.data)}`);
            }
        } catch (e) {
            console.error('❌ [3/7] createFine failed:', e.message);
            failed++;
        }

        // Test 4: getFineById (Deep Citation Profile)
        try {
            if (!createdFineId) throw new Error('No fine ID to test');
            const req = { params: { id: createdFineId.toString() } };
            const res = mockRes();
            await adminFineController.getFineById(req, res);

            if (res.statusCode === 200 && res.data.success && res.data.data._id) {
                console.log(`✅ [4/7] getFineById passed: License=${res.data.data.licenseNumber}, Offense=${res.data.data.offenseName}`);
                passed++;
            } else {
                throw new Error(`Failed to retrieve fine by id: ${JSON.stringify(res.data)}`);
            }
        } catch (e) {
            console.error('❌ [4/7] getFineById failed:', e.message);
            failed++;
        }

        // Test 5: updateFineStatus (Mark as DISPUTED with audit remarks)
        try {
            if (!createdFineId) throw new Error('No fine ID to test');
            const req = {
                params: { id: createdFineId.toString() },
                body: {
                    status: 'DISPUTED',
                    notes: 'Driver filed emergency medical dispute',
                    restoreDemerit: false
                },
                user: { name: 'Test Super Admin' }
            };
            const res = mockRes();
            await adminFineController.updateFineStatus(req, res);

            if (res.statusCode === 200 && res.data.success && res.data.data.status === 'DISPUTED') {
                console.log(`✅ [5/7] updateFineStatus passed: Fine updated to DISPUTED`);
                passed++;
            } else {
                throw new Error(`Failed to update status: ${JSON.stringify(res.data)}`);
            }
        } catch (e) {
            console.error('❌ [5/7] updateFineStatus failed:', e.message);
            failed++;
        }

        // Test 6: exportFines (CSV Ledger)
        try {
            const req = { query: { format: 'csv', status: 'ALL' } };
            const res = mockRes();
            await adminFineController.exportFines(req, res);

            if (res.statusCode === 200 && res.data && typeof res.data === 'string' && res.data.includes('Citation ID')) {
                console.log(`✅ [6/7] exportFines (CSV) passed: Generated ${res.data.split('\n').length} CSV lines`);
                passed++;
            } else {
                throw new Error(`Failed to export CSV: ${res.statusCode}`);
            }
        } catch (e) {
            console.error('❌ [6/7] exportFines failed:', e.message);
            failed++;
        }

        // Test 7: deleteFine (Safe deletion of unpaid/disputed test fine)
        try {
            if (!createdFineId) throw new Error('No fine ID to test');
            const req = { params: { id: createdFineId.toString() } };
            const res = mockRes();
            await adminFineController.deleteFine(req, res);

            if (res.statusCode === 200 && res.data.success) {
                console.log(`✅ [7/7] deleteFine passed: Test citation safely deleted`);
                passed++;
            } else {
                throw new Error(`Failed to delete fine: ${JSON.stringify(res.data)}`);
            }
        } catch (e) {
            console.error('❌ [7/7] deleteFine failed:', e.message);
            failed++;
        }

    } catch (err) {
        console.error('Fatal test error:', err);
    } finally {
        await mongoose.disconnect();
        console.log('\n======================================================');
        console.log(`📊 TEST RESULTS: ${passed} Passed, ${failed} Failed (${Math.round((passed / (passed + failed || 1)) * 100)}%)`);
        console.log('======================================================\n');
        process.exit(failed > 0 ? 1 : 0);
    }
}

runTests();
