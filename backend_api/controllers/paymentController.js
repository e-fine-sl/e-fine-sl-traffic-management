const md5 = require('md5');
const { HTTP } = require('../config/constants');

const generateHash = (req, res) => {
    try {
        const { order_id, amount, currency } = req.body;

        const merchantSecret = process.env.PAYHERE_SECRET;
        const merchantId = process.env.PAYHERE_MERCHANT_ID;

        if (!merchantSecret || !merchantId) {
            return res.status(HTTP.SERVER_ERROR).json({ error: "PayHere credentials missing in .env" });
        }

        // 1. Hash Merchant Secret (md5)
        const hashedSecret = md5(merchantSecret).toUpperCase();

        // 2. Format Amount (must have 2 decimal places, no commas)
        // ex: 1000 -> 1000.00
        let amountFormatted = parseFloat(amount).toFixed(2);

        // 3. Append other data and Hash again (PayHere Formula)
        // Formula: md5(merchant_id + order_id + amount + currency + hashedSecret)
        const hashString = merchantId + order_id + amountFormatted + currency + hashedSecret;
        const finalHash = md5(hashString).toUpperCase();

        res.json({ hash: finalHash });
    } catch (error) {
        console.error("Hash Gen Error:", error);
        res.status(HTTP.SERVER_ERROR).json({ error: "Hash generation failed" });
    }
};

module.exports = { generateHash };
