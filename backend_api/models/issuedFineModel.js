const mongoose = require('mongoose');
const { PAYMENT } = require('../config/constants');

const issuedFineSchema = mongoose.Schema({
    licenseNumber: { type: String, required: true },
    vehicleNumber: { type: String, required: true },
    offenseId: { type: mongoose.Schema.Types.ObjectId, ref: 'Offense', required: true }, // Fine type
    offenseName: { type: String, required: true }, // Save name for convenience
    amount: { type: Number, required: true },
    place: { type: String, required: true },
    province: { type: String },
    district: { type: String },
    policeStation: { type: String },
    policeOfficerId: { type: String, default: "Officer-001" }, // Officer ID / Badge Number
    status: { type: String, default: PAYMENT.STATUS.UNPAID }, // Payment status
    paymentId: { type: String }, // PayHere Payment ID
    paidAt: { type: Date }, // Paid time
    demeritPoints: { type: Number, default: 0 }, // Demerit points associated with the fine
    date: { type: Date, default: Date.now } // Time fine was issued
}, {
    timestamps: true
});

module.exports = mongoose.model('IssuedFine', issuedFineSchema);