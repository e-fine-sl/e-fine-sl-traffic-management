const md5 = require('md5');
const { HTTP, PAYMENT } = require('../config/constants');
const IssuedFine = require('../models/issuedFineModel');

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

const handlePaymentNotification = async (req, res) => {
    try {
        const {
            merchant_id,
            order_id,
            payhere_amount,
            payhere_currency,
            status_code,
            md5sig
        } = req.body;

        const merchantSecret = process.env.PAYHERE_SECRET;

        // 1. Generate local MD5 signature to verify authenticity
        const hashedSecret = md5(merchantSecret).toUpperCase();
        const localMd5sig = md5(
            merchant_id +
            order_id +
            payhere_amount +
            payhere_currency +
            status_code +
            hashedSecret
        ).toUpperCase();

        // 2. Compare signatures
        if (localMd5sig !== md5sig) {
            console.error(`[PAYHERE] Invalid signature for Order: ${order_id}`);
            return res.status(HTTP.BAD_REQUEST).send("Invalid signature");
        }

        // 3. Process payment status
        if (status_code === '2') {
            // Payment success
            const fine = await IssuedFine.findById(order_id);
            if (fine) {
                fine.status = PAYMENT.STATUS.PAID;
                fine.paymentId = "PAYHERE_WEBHOOK_VERIFIED"; // Note: we could store the actual transaction id if sent
                await fine.save();
                console.log(`[PAYHERE] Fine ${order_id} marked as PAID`);
            } else {
                console.warn(`[PAYHERE] Fine ${order_id} not found`);
            }
        } else {
            console.warn(`[PAYHERE] Payment failed or pending for Order: ${order_id} (Status: ${status_code})`);
        }

        // Must respond with 200 OK so PayHere knows it was received
        res.status(HTTP.OK).send("OK");
    } catch (error) {
        console.error("[PAYHERE] Webhook Error:", error);
        res.status(HTTP.SERVER_ERROR).send("Internal Server Error");
    }
};

module.exports = { generateHash, handlePaymentNotification };
