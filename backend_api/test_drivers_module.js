const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const Driver = require('./models/driverModel');
const IssuedFine = require('./models/issuedFineModel');
const {
    getAllDrivers,
    getDriverMetrics,
    getDriverById,
    createDriver,
    updateDriver,
    suspendDriver,
    activateDriver,
    adjustDriverDemerit,
    resetDriverCredentials,
    exportDrivers,
    deleteDriver
} = require('./controllers/adminDriverController');

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

async function runDriversModuleTests() {
    console.log('====================================================');
    console.log('🧪 RUNNING DRIVERS MANAGEMENT MODULE TESTS');
    console.log('====================================================');

    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log('✅ Connected to MongoDB successfully.');

        // Test 1: Get Driver Metrics
        console.log('\n--- [TEST 1] Testing getDriverMetrics Aggregation ---');
        const metricsRes = createMockRes();
        await getDriverMetrics({}, metricsRes);
        console.log('Driver Metrics Response:', metricsRes.statusCode);
        console.log('Metrics Summary:', metricsRes.data?.data);
        if (metricsRes.statusCode !== 200 || !metricsRes.data?.success) throw new Error('Test 1 failed');
        console.log('✅ TEST 1 PASSED: Driver executive metrics calculated.');

        // Test 2: Create Driver
        console.log('\n--- [TEST 2] Testing createDriver ---');
        const uniqueSuffix = Date.now().toString().slice(-6);
        const testLicense = `B${uniqueSuffix}`;
        const testNic = `1998${uniqueSuffix}V`;
        const testEmail = `driver_${uniqueSuffix}@gmail.com`;

        const createReq = {
            body: {
                name: 'Kavindu Weerasinghe',
                nic: testNic,
                licenseNumber: testLicense,
                email: testEmail,
                phone: '0719876543',
                password: 'DriverSecretPass123!',
                vehicleNumber: 'WP-CAD-4567',
                city: 'Nugegoda',
                addressLine1: '45/2 High Level Road'
            }
        };
        const createRes = createMockRes();
        await createDriver(createReq, createRes);
        console.log('Create Driver Status:', createRes.statusCode);
        console.log('Created Driver:', createRes.data?.data);
        if (createRes.statusCode !== 201) throw new Error('Test 2 failed');
        const createdId = createRes.data?.data?.id;
        console.log('✅ TEST 2 PASSED: Driver created successfully.');

        // Test 3: List Drivers with Search & Pagination
        console.log('\n--- [TEST 3] Testing getAllDrivers with Search ---');
        const listReq = {
            query: {
                search: testLicense,
                page: '1',
                limit: '10'
            }
        };
        const listRes = createMockRes();
        await getAllDrivers(listReq, listRes);
        console.log('Found Drivers:', listRes.data?.count, 'Total:', listRes.data?.total);
        if (listRes.statusCode !== 200 || listRes.data?.count === 0) throw new Error('Test 3 failed');
        console.log('✅ TEST 3 PASSED: Search and driver pagination working.');

        // Test 4: Get Driver Deep Dossier
        console.log('\n--- [TEST 4] Testing getDriverById Deep Profile ---');
        const dossierReq = { params: { id: createdId } };
        const dossierRes = createMockRes();
        await getDriverById(dossierReq, dossierRes);
        console.log('Driver Name:', dossierRes.data?.driver?.name);
        console.log('Enforcement Summary:', dossierRes.data?.driver?.enforcementSummary);
        if (dossierRes.statusCode !== 200 || !dossierRes.data?.driver) throw new Error('Test 4 failed');
        console.log('✅ TEST 4 PASSED: Deep driver dossier retrieved.');

        // Test 5: Suspend Driver License
        console.log('\n--- [TEST 5] Testing suspendDriver ---');
        const suspendReq = {
            params: { id: createdId },
            body: { reason: 'Severe speeding and reckless driving' }
        };
        const suspendRes = createMockRes();
        await suspendDriver(suspendReq, suspendRes);
        console.log('Suspend Result Message:', suspendRes.data?.message);
        if (suspendRes.statusCode !== 200 || suspendRes.data?.driver?.licenseStatus !== 'SUSPENDED') throw new Error('Test 5 failed');
        console.log('✅ TEST 5 PASSED: Driver license suspended.');

        // Test 6: Activate Driver License
        console.log('\n--- [TEST 6] Testing activateDriver ---');
        const activateReq = { params: { id: createdId } };
        const activateRes = createMockRes();
        await activateDriver(activateReq, activateRes);
        console.log('Activate Result Message:', activateRes.data?.message);
        if (activateRes.statusCode !== 200 || activateRes.data?.driver?.licenseStatus !== 'ACTIVE') throw new Error('Test 6 failed');
        console.log('✅ TEST 6 PASSED: Driver license restored to ACTIVE.');

        // Test 7: Adjust Demerit Points
        console.log('\n--- [TEST 7] Testing adjustDriverDemerit ---');
        const adjustReq = {
            params: { id: createdId },
            body: { newPoints: 18, reason: 'Court Appeal #CA-102 Partial Demerit Restoration' }
        };
        const adjustRes = createMockRes();
        await adjustDriverDemerit(adjustReq, adjustRes);
        console.log('Adjust Demerit Result:', adjustRes.data?.message);
        if (adjustRes.statusCode !== 200 || adjustRes.data?.driver?.demeritPoints !== 18) throw new Error('Test 7 failed');
        console.log('✅ TEST 7 PASSED: Demerit points adjusted to 18 (GOOD).');

        // Test 8: Reset Driver Credentials
        console.log('\n--- [TEST 8] Testing resetDriverCredentials ---');
        const resetReq = {
            params: { id: createdId },
            body: { newPassword: 'NewDriverSecurePass2026!' }
        };
        const resetRes = createMockRes();
        await resetDriverCredentials(resetReq, resetRes);
        console.log('Reset Credentials Message:', resetRes.data?.message);
        const reloadedDriver = await Driver.findById(createdId);
        const isMatch = await bcrypt.compare('NewDriverSecurePass2026!', reloadedDriver.password);
        if (!isMatch) throw new Error('Password hash does not match new password');
        console.log('✅ TEST 8 PASSED: Driver credentials reset successfully.');

        // Test 9: Export Drivers CSV
        console.log('\n--- [TEST 9] Testing exportDrivers CSV ---');
        const exportReq = { query: { format: 'csv' } };
        const exportRes = createMockRes();
        await exportDrivers(exportReq, exportRes);
        console.log('Export Content Type:', exportRes.headers['Content-Type']);
        if (exportRes.headers['Content-Type'] !== 'text/csv') throw new Error('Test 9 failed');
        console.log('✅ TEST 9 PASSED: Driver CSV export generated.');

        // Test 10: Safe Delete Driver
        console.log('\n--- [TEST 10] Testing deleteDriver ---');
        const deleteReq = { params: { id: createdId } };
        const deleteRes = createMockRes();
        await deleteDriver(deleteReq, deleteRes);
        console.log('Delete Message:', deleteRes.data?.message);
        if (deleteRes.statusCode !== 200) throw new Error('Test 10 failed');
        console.log('✅ TEST 10 PASSED: Safe delete succeeded.');

        console.log('\n====================================================');
        console.log('🎉 ALL 10 DRIVER MANAGEMENT MODULE TESTS PASSED (10/10)!');
        console.log('====================================================\n');

        process.exit(0);

    } catch (err) {
        console.error('❌ Test failed with error:', err);
        process.exit(1);
    }
}

runDriversModuleTests();
