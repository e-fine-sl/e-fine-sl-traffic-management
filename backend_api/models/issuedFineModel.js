const mongoose = require('mongoose');
const { PAYMENT } = require('../config/constants');

const issuedFineSchema = mongoose.Schema({
    licenseNumber: { type: String, required: true, index: true },
    vehicleNumber: { type: String, required: true, index: true },
    offenseId: { type: mongoose.Schema.Types.ObjectId, ref: 'Offense', required: true }, // Fine type
    offenseName: { type: String, required: true }, // Save name for convenience
    amount: { type: Number, required: true },
    place: { type: String, required: true },
    province: { type: String, index: true },
    district: { type: String, index: true },
    policeStation: { type: String, index: true },
    policeOfficerId: { type: String, default: "Officer-001", index: true }, // Officer ID / Badge Number
    status: { 
        type: String, 
        default: PAYMENT.STATUS.UNPAID,
        set: v => (typeof v === 'string' ? v.toUpperCase() : v),
        enum: ['PAID', 'UNPAID', 'PENDING', 'REFUNDED', 'DISPUTED'],
        index: true
    }, // Payment status
    paymentId: { type: String, index: true }, // PayHere / Gateway Payment ID
    paymentMethod: { 
        type: String, 
        default: 'PAYHERE_GATEWAY'
    },
    gatewayFee: { type: Number, default: 0 },
    netAmount: { type: Number },
    gatewayPaymentId: { type: String },
    paidAt: { type: Date, index: true }, // Paid time
    demeritPoints: { type: Number, default: 0 }, // Demerit points associated with the fine
    date: { type: Date, default: Date.now, index: true }, // Time fine was issued
    disputeReason: { type: String },
    refundedAt: { type: Date },
    refundedBy: { type: String },
    refundTreasuryRef: { type: String },
    paymentNotes: { type: String }
}, {
    timestamps: true
});

// Compound indexes for high-performance dashboard search & date range filtering
issuedFineSchema.index({ status: 1, paidAt: -1 });
issuedFineSchema.index({ licenseNumber: 'text', vehicleNumber: 'text', paymentId: 'text', offenseName: 'text' });

module.exports = mongoose.model('IssuedFine', issuedFineSchema);