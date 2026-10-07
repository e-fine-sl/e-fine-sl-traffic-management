const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const Police = require('./models/policeModel');
const IssuedFine = require('./models/issuedFineModel');
const Station = require('./models/stationModel');
const {
    getAllOfficers,
    getOfficerMetrics,
    getOfficerById,
    createOfficer,
    updateOfficer,
    toggleOfficerStatus,
    transferOfficerStation,
    resetOfficerCredentials,
    exportOfficers,
    deleteOfficer
} = require('./controllers/adminOfficerController');

function createMockRes() {
    return {
        statusCode: 200,
        headers: {},
        data: null,
        status(c) { this.statusCode = c; return this; },
        json(d) { this.data = d; return this; },
        setHeader(k, v) { this.headers[k] = v; return this; },
        send(d) { this.data = d; return this; }
    };
}

async function runOfficersModuleTests() {
    console.log('====================================================');
    console.log('🧪 RUNNING POLICE OFFICERS MODULE COMPREHENSIVE TESTS');
    console.log('====================================================');

    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log('✅ Connected to MongoDB successfully.');

        // Test 1: Get Metrics
        console.log('\n--- [TEST 1] Testing getOfficerMetrics Aggregation ---');
        const metricsRes = createMockRes();
        await getOfficerMetrics({}, metricsRes);
        console.log('Metrics Response Status:', metricsRes.statusCode);
        console.log('Workforce Metrics:', metricsRes.data?.data);
        if (metricsRes.statusCode !== 200 || !metricsRes.data?.success) throw new Error('Test 1 failed');
        console.log('✅ TEST 1 PASSED: Workforce metrics calculated correctly.');

        // Test 2: Create Officer
        console.log('\n--- [TEST 2] Testing createOfficer ---');
        const uniqueSuffix = Date.now().toString().slice(-6);
        const newOfficerBadge = `TEST-B${uniqueSuffix}`;
        const newOfficerEmail = `test_officer_${uniqueSuffix}@efine.gov.lk`;

        const createReq = {
            body: {
                name: 'Sergeant Nimal Bandara',
                email: newOfficerEmail,
                badgeNumber: newOfficerBadge,
                nic: `2000${uniqueSuffix}V`,
                phone: '0771234567',
                password: 'InitialPassword123!',
                policeStation: 'Colombo Fort Police',
                position: 'Sergeant'
            }
        };
        const createRes = createMockRes();
        await createOfficer(createReq, createRes);
        console.log('Create Officer Status:', createRes.statusCode);
        console.log('Created Officer:', createRes.data?.data);
        if (createRes.statusCode !== 201) throw new Error('Test 2 failed');
        const createdId = createRes.data?.data?.id;
        console.log('✅ TEST 2 PASSED: Officer created successfully.');

        // Test 3: List Officers with Search & Filter
        console.log('\n--- [TEST 3] Testing getAllOfficers with Search ---');
        const listReq = {
            query: {
                search: newOfficerBadge,
                page: '1',
                limit: '10'
            }
        };
        const listRes = createMockRes();
        await getAllOfficers(listReq, listRes);
        console.log('Found Officers:', listRes.data?.count, 'Total:', listRes.data?.total);
        if (listRes.statusCode !== 200 || listRes.data?.count === 0) throw new Error('Test 3 failed');
        console.log('✅ TEST 3 PASSED: Search and pagination working.');

        // Test 4: Get Officer Deep Dossier
        console.log('\n--- [TEST 4] Testing getOfficerById Deep Profile ---');
        const dossierReq = { params: { id: createdId } };
        const dossierRes = createMockRes();
        await getOfficerById(dossierReq, dossierRes);
        console.log('Officer Dossier Name:', dossierRes.data?.data?.name);
        console.log('Enforcement Stats:', dossierRes.data?.data?.enforcementStats);
        if (dossierRes.statusCode !== 200 || !dossierRes.data?.data?.enforcementStats) throw new Error('Test 4 failed');
        console.log('✅ TEST 4 PASSED: Deep profile and stats retrieved.');

        // Test 5: Toggle Status (Suspend)
        console.log('\n--- [TEST 5] Testing toggleOfficerStatus (Suspend/Deactivate) ---');
        const toggleReq = {
            params: { id: createdId },
            body: { isActive: false, reason: 'Pending internal disciplinary inquiry' }
        };
        const toggleRes = createMockRes();
        await toggleOfficerStatus(toggleReq, toggleRes);
        console.log('Toggle Status Result:', toggleRes.data?.message);
        if (toggleRes.statusCode !== 200 || toggleRes.data?.data?.isActive !== false) throw new Error('Test 5 failed');
        console.log('✅ TEST 5 PASSED: Status toggled to SUSPENDED.');

        // Test 6: Transfer Station
        console.log('\n--- [TEST 6] Testing transferOfficerStation ---');
        const transferReq = {
            params: { id: createdId },
            body: { targetStation: 'Kandy HQ Station', transferReason: 'Routine Division Rotation' }
        };
        const transferRes = createMockRes();
        await transferOfficerStation(transferReq, transferRes);
        console.log('Transfer Result:', transferRes.data?.message);
        if (transferRes.statusCode !== 200 || transferRes.data?.data?.currentStation !== 'Kandy HQ Station') throw new Error('Test 6 failed');
        console.log('✅ TEST 6 PASSED: Station transfer executed.');

        // Test 7: Reset Credentials
        console.log('\n--- [TEST 7] Testing resetOfficerCredentials ---');
        const resetReq = {
            params: { id: createdId },
            body: { newPassword: 'NewSecurePass2026!' }
        };
        const resetRes = createMockRes();
        await resetOfficerCredentials(resetReq, resetRes);
        console.log('Reset Credentials Message:', resetRes.data?.message);
        const reloadedOfficer = await Police.findById(createdId);
        const isMatch = await bcrypt.compare('NewSecurePass2026!', reloadedOfficer.password);
        if (!isMatch) throw new Error('Password hash does not match new password');
        console.log('✅ TEST 7 PASSED: Credentials safely reset.');

        // Test 8: CSV Export
        console.log('\n--- [TEST 8] Testing exportOfficers CSV ---');
        const exportReq = { query: { format: 'csv' } };
        const exportRes = createMockRes();
        await exportOfficers(exportReq, exportRes);
        console.log('Export Content Type:', exportRes.headers['Content-Type']);
        if (exportRes.headers['Content-Type'] !== 'text/csv') throw new Error('Test 8 failed');
        console.log('✅ TEST 8 PASSED: CSV export generated.');

        // Test 9: Safe Delete
        console.log('\n--- [TEST 9] Testing deleteOfficer ---');
        const deleteReq = { params: { id: createdId } };
        const deleteRes = createMockRes();
        await deleteOfficer(deleteReq, deleteRes);
        console.log('Delete Result:', deleteRes.data?.message);
        if (deleteRes.statusCode !== 200) throw new Error('Test 9 failed');
        console.log('✅ TEST 9 PASSED: Safe deletion succeeded.');

        console.log('\n====================================================');
        console.log('🎉 ALL 9 POLICE OFFICER MODULE TESTS PASSED (9/9)!');
        console.log('====================================================\n');

        process.exit(0);

    } catch (err) {
        console.error('❌ Test failed with error:', err);
        process.exit(1);
    }
}

runOfficersModuleTests();
