const mongoose = require('mongoose');

const paymentTransactionSchema = mongoose.Schema({
    orderId: { type: String, required: true, index: true }, // Fine ID
    gatewayPaymentId: { type: String, required: true, unique: true, index: true }, // PayHere payment_id
    merchantId: { type: String, required: true },
    amount: { type: Number, required: true },
    currency: { type: String, default: 'LKR' },
    statusCode: { type: String, required: true },
    statusMessage: { type: String },
    paymentMethod: { type: String },
    cardHolderName: { type: String },
    cardNoMasked: { type: String },
    md5sig: { type: String, required: true },
    rawPayload: { type: Object },
    processedAt: { type: Date, default: Date.now },
    isVerified: { type: Boolean, default: true }
}, {
    timestamps: true
});

module.exports = mongoose.model('PaymentTransaction', paymentTransactionSchema);
