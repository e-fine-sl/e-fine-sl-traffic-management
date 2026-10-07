const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const fs = require('fs');
const mongoose = require('mongoose');
const { exportPayments } = require('./controllers/adminPaymentController');

function createMockRes(outputPath) {
    const stream = fs.createWriteStream(outputPath);
    stream.headers = {};
    stream.setHeader = function(k, v) { this.headers[k] = v; };
    stream.status = function(code) { this.statusCode = code; return this; };
    return stream;
}

async function testPdfExport() {
    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log('✅ Connected to MongoDB.');

        const outputPath = path.join(__dirname, 'test_export_output.pdf');
        const mockRes = createMockRes(outputPath);
        const mockReq = {
            query: { status: 'ALL', format: 'pdf' },
            admin: { name: 'Admin Test', role: 'super_admin' }
        };

        await exportPayments(mockReq, mockRes);

        mockRes.on('finish', () => {
            console.log('Export Finished. File Size:', fs.statSync(outputPath).size);
            const content = fs.readFileSync(outputPath, 'latin1');
            const pageMatches = content.match(/\/Type\s*\/Page[^s]/g) || [];
            console.log('Generated PDF Pages:', pageMatches.length);
            console.log('Content Type Header:', mockRes.headers['Content-Type']);

            if (fs.statSync(outputPath).size > 1000 && pageMatches.length >= 1) {
                console.log('✅ TEST PASSED: PDF Statement/Ledger generated successfully!');
            } else {
                console.error('❌ TEST FAILED: PDF generation failed.');
            }
            if (fs.existsSync(outputPath)) fs.unlinkSync(outputPath);
            process.exit(0);
        });

    } catch (err) {
        console.error('❌ Error during PDF export test:', err);
        process.exit(1);
    }
}

testPdfExport();
