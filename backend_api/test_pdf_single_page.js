const fs = require('fs');
const path = require('path');
const QRCode = require('qrcode');
const PdfReportService = require('./services/pdfReportService');

async function testReceiptPageCount() {
    const qrBuffer = await QRCode.toBuffer('TEST_QR_DATA', { width: 250, margin: 1 });
    const fine = {
        _id: '6a48a580480915337cad2bdf',
        offenseName: 'Crossing Double Continuous Line',
        amount: 2000,
        vehicleNumber: 'BBM 3157',
        licenseNumber: 'B5395114',
        place: 'No. 190/7A Peter D Perera Ave, Colombo',
        policeOfficerId: '27378',
        demeritPoints: 2,
        status: 'PAID',
        date: new Date()
    };
    const driver = {
        name: 'M A Shashimantha',
        licenseStatus: 'ACTIVE',
        demeritPoints: 24,
        demeritLevel: 'EXCELLENT'
    };

    const doc = PdfReportService.createDocument();
    const outputPath = path.join(__dirname, 'test_receipt_output.pdf');
    const stream = fs.createWriteStream(outputPath);
    doc.pipe(stream);

    PdfReportService.buildReceipt(doc, { fine, driver, qrBuffer });
    const pages = doc.bufferedPageRange();
    console.log('Buffered Page Count before end():', pages.count);
    doc.end();

    stream.on('finish', () => {
        const fileBuffer = fs.readFileSync(outputPath);
        // Count occurrences of /Type /Page (excluding /Type /Pages)
        const pageMatches = fileBuffer.toString('latin1').match(/\/Type\s*\/Page[^s]/g) || [];
        console.log('Physical PDF /Type /Page objects in file:', pageMatches.length);

        if (pages.count === 1 && pageMatches.length === 1) {
            console.log('✅ TEST PASSED: Generated clean 1-page PDF receipt with no spillover pages.');
        } else {
            console.error(`❌ TEST FAILED: Generated ${pageMatches.length} pages.`);
        }
        if (fs.existsSync(outputPath)) fs.unlinkSync(outputPath);
    });
}

testReceiptPageCount();
