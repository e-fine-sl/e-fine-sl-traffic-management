const md5 = require('md5');
const { HTTP, PAYMENT } = require('../config/constants');
const IssuedFine = require('../models/issuedFineModel');
const PaymentTransaction = require('../models/paymentTransactionModel');

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
            payment_id,
            payhere_amount,
            payhere_currency,
            status_code,
            md5sig,
            method,
            status_message,
            card_holder_name,
            card_no
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

        // 3. Idempotency check: if transaction already recorded, respond OK immediately
        const gatewayTxId = payment_id || `${order_id}_${status_code}_${Date.now()}`;
        const existingTx = await PaymentTransaction.findOne({ gatewayPaymentId: gatewayTxId });
        if (existingTx) {
            console.log(`[PAYHERE] Duplicate webhook notification for Transaction: ${gatewayTxId}. Idempotent OK.`);
            return res.status(HTTP.OK).send("OK");
        }

        // 4. Record transaction log
        await PaymentTransaction.create({
            orderId: order_id,
            gatewayPaymentId: gatewayTxId,
            merchantId: merchant_id,
            amount: parseFloat(payhere_amount) || 0,
            currency: payhere_currency || 'LKR',
            statusCode: status_code,
            statusMessage: status_message || 'Payment processed via Webhook',
            paymentMethod: method || 'PAYHERE_GATEWAY',
            cardHolderName: card_holder_name,
            cardNoMasked: card_no,
            md5sig: md5sig,
            rawPayload: req.body,
            processedAt: new Date(),
            isVerified: true
        });

        // 5. Process payment status (2 = Success)
        if (status_code === '2') {
            const fine = await IssuedFine.findById(order_id);
            if (fine) {
                // Strict Price-Tampering Prevention: Validate amount received equals fine amount
                const expectedAmount = parseFloat(fine.amount).toFixed(2);
                const receivedAmount = parseFloat(payhere_amount).toFixed(2);

                if (expectedAmount !== receivedAmount) {
                    console.error(`[FRAUD ALERT] Amount mismatch for fine ${order_id}. Expected: ${expectedAmount}, Got: ${receivedAmount}`);
                    fine.status = 'DISPUTED';
                    fine.disputeReason = `FRAUD_FLAG: Amount mismatch (Expected LKR ${expectedAmount}, Received LKR ${receivedAmount})`;
                    fine.paymentNotes = `Flagged by PayHere Webhook on ${new Date().toISOString()}`;
                    await fine.save();
                    return res.status(HTTP.BAD_REQUEST).send("Amount mismatch detected");
                }

                fine.status = PAYMENT.STATUS.PAID;
                fine.paymentId = payment_id || `PAYHERE-${Date.now()}`;
                fine.gatewayPaymentId = gatewayTxId;
                fine.paymentMethod = method ? `PAYHERE_${method.toUpperCase()}` : 'PAYHERE_GATEWAY';
                fine.paidAt = new Date();
                fine.paymentNotes = `Verified via PayHere IPN Webhook. Gateway Ref: ${gatewayTxId}`;
                await fine.save();
                console.log(`[PAYHERE] Fine ${order_id} marked as PAID with gateway ID: ${fine.paymentId}`);
            } else {
                console.warn(`[PAYHERE] Fine ${order_id} not found in database`);
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

