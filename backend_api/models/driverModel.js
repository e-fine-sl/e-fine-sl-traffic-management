const mongoose = require('mongoose');
const { ROLES, DEMERIT, LICENSE_STATUS } = require('../config/constants');

const driverSchema = mongoose.Schema(
  {
    name: { type: String, required: true },
    nic: { type: String, required: true, unique: true },
    licenseNumber: { type: String, required: true, unique: true }, 
    email: { type: String, required: true, unique: true },
    phone: { type: String, required: true },
    password: { type: String, required: true },
    role: { type: String, default: ROLES.DRIVER }, // 'driver'
    
    // (Demerit Points)
    demeritPoints: { type: Number, default: DEMERIT.DEFAULT_POINTS }, 
    ratingScore: { type: Number, default: 5.0, min: 0.0, max: 5.0 }, // 0.0 - 5.0 Stars
    licenseStatus: {
      type: String,
      enum: [LICENSE_STATUS.ACTIVE, LICENSE_STATUS.SUSPENDED],
      default: LICENSE_STATUS.ACTIVE,
      set: (val) => (val ? String(val).toUpperCase() : LICENSE_STATUS.ACTIVE)
    },
    demeritLevel: { type: String, enum: ['EXCELLENT', 'GOOD', 'FAIR', 'WARNING', 'DANGER', LICENSE_STATUS.SUSPENDED], default: 'EXCELLENT' },
    suspendedAt: { type: Date, default: null },
    suspensionReason: { type: String, default: null },
    fcmToken: { type: String, default: null },
    lastOffenseDate: { type: Date, default: null },

    isVerified: { type: Boolean, default: false },
    kycVerified: { type: Boolean, default: false }, // KYC face-match verification status
    emailIsVerified: { type: Boolean, default: false }, // Email OTP verification status
    profileImage: { type: String }, // Base64 profile photo extracted from KYC selfie
    licenseFrontImage: { type: String }, // Base64 license front side
    licenseBackImage: { type: String }, // Base64 license back side
    // ...
    licenseExpiryDate: { type: String }, 
    licenseIssueDate: { type: String }, // 4a
    dateOfBirth: { type: String }, // 3
    
    addressLine1: { type: String },
    addressLine2: { type: String },
    city: { type: String },
    postalCode: { type: String },
    vehicleNumber: { type: String },
    

    vehicleClasses: [{
        category: String, // A, B, B1
        issueDate: String,
        expiryDate: String
    }],
    // ...
  },
  { timestamps: true }
);

module.exports = mongoose.model('Driver', driverSchema);