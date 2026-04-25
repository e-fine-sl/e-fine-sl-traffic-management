const Station = require('../models/stationModel');
const Verification = require('../models/verificationModel');
const sendEmail = require('../utils/sendEmail');
const bcrypt = require('bcryptjs');
const { randomUUID } = require('crypto');
const Police = require('../models/policeModel');
const generateToken = require('../utils/generateToken');
const Driver = require('../models/driverModel');
const { HTTP, ROLES, AUTH } = require('../config/constants');
const { decryptPassword } = require('../utils/cryptoService'); // RSA decrypt from Flutter


// @desc    Request OTP for Police Registration
// @route   POST /api/auth/request-verification
// @access  Public
const requestVerification = async (req, res) => {
  const { badgeNumber, stationCode } = req.body;

  try {
    const station = await Station.findOne({ stationCode });

    if (!station) {
      return res.status(HTTP.NOT_FOUND).json({ message: 'Police Station not found' });
    }

    const otp = Math.floor(100000 + Math.random() * 900000).toString();

    await Verification.deleteMany({ badgeNumber });

    await Verification.create({
      badgeNumber,
      stationCode,
      otp,
    });

    const htmlMessage = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #e0e0e0; border-radius: 8px; overflow: hidden;">
        <div style="background-color: #003366; padding: 20px; text-align: center;">
          <h2 style="color: #ffffff; margin: 0;">E-Fine SL Verification</h2>
        </div>
        <div style="padding: 20px; background-color: #ffffff;">
          <p style="font-size: 16px; color: #333;">Dear OIC,</p>
          <p style="font-size: 16px; color: #333;">The following officer has requested official registration access:</p>
          <table style="width: 100%; margin-bottom: 20px; background-color: #f9f9f9; padding: 10px; border-radius: 5px;">
            <tr>
              <td style="font-weight: bold; color: #555; padding: 5px;">Badge ID:</td>
              <td style="font-weight: bold; color: #000; padding: 5px;">${badgeNumber}</td>
            </tr>
            <tr>
              <td style="font-weight: bold; color: #555; padding: 5px;">Station:</td>
              <td style="font-weight: bold; color: #000; padding: 5px;">${station.name}</td>
            </tr>
          </table>
          <div style="text-align: center; margin: 30px 0;">
            <p style="margin: 0; font-size: 14px; color: #777;">VERIFICATION CODE (OTP)</p>
            <h1 style="margin: 10px 0; font-size: 40px; color: #003366; letter-spacing: 5px; font-weight: bold;">
              ${otp}
            </h1>
          </div>
          <p style="color: #d9534f; font-size: 14px; text-align: center; font-weight: bold;">
            ⚠️ Please verify the officer's identity before providing this code.
          </p>
        </div>
        <div style="background-color: #eeeeee; padding: 10px; text-align: center; font-size: 12px; color: #777;">
          © 2025 E-Fine SL Project | Secure Verification System
        </div>
      </div>
    `;

    await sendEmail({
      email: station.officialEmail,
      subject: 'Action Required: Officer Verification Code',
      message: `Your Verification Code is: ${otp}`,
      html: htmlMessage,
    });

    res.status(HTTP.OK).json({ success: true, message: `Verification code sent to OIC of ${station.name}` });

  } catch (error) {
    console.error(error);
    res.status(HTTP.SERVER_ERROR).json({ message: 'Server Error', error: error.message });
  }
};

// @desc    Verify OTP
// @route   POST /api/auth/verify-otp
const verifyOTP = async (req, res) => {
  const { badgeNumber, otp } = req.body;

  try {
    const record = await Verification.findOne({ badgeNumber, otp });

    if (!record) {
      return res.status(HTTP.BAD_REQUEST).json({ success: false, message: 'Invalid or Expired OTP' });
    }

    res.status(HTTP.OK).json({ success: true, message: 'OTP Verified Successfully' });

  } catch (error) {
    res.status(HTTP.SERVER_ERROR).json({ message: 'Server Error', error: error.message });
  }
};

// @desc    Register New Police Officer
// @route   POST /api/auth/register-police
const registerPolice = async (req, res) => {
  const { name, badgeNumber, email, password, station, otp, nic, phone, position, profileImage } = req.body;

  try {
    const verifiedRecord = await Verification.findOne({ badgeNumber, otp });
    if (!verifiedRecord) {
      return res.status(HTTP.UNAUTHORIZED).json({ message: 'Unauthorized: Please verify OTP first' });
    }

    const officerExists = await Police.findOne({ 
      $or: [
        { badgeNumber },
        { nic },
        { email },
        { phone }
      ]
    });
    if (officerExists) {
      let duplicateField = 'Officer';
      if (officerExists.badgeNumber === badgeNumber) duplicateField = 'Badge Number';
      else if (officerExists.nic === nic) duplicateField = 'NIC';
      else if (officerExists.email === email) duplicateField = 'Email';
      else if (officerExists.phone === phone) duplicateField = 'Phone Number';
      
      return res.status(HTTP.BAD_REQUEST).json({ message: `${duplicateField} already registered for an officer` });
    }

    // Decrypt RSA-encrypted password sent from Flutter
    let plainPassword;
    try {
      plainPassword = decryptPassword(password);
    } catch (e) {
      console.error('[AUTH/REGISTER-POLICE] RSA decrypt failed:', e.message);
      return res.status(HTTP.BAD_REQUEST).json({ message: 'Invalid encrypted password' });
    }

    const salt = await bcrypt.genSalt(AUTH.BCRYPT_SALT_ROUNDS);
    const hashedPassword = await bcrypt.hash(plainPassword, salt);

    const officer = await Police.create({
      name,
      badgeNumber,
      email,
      nic,
      phone,
      password: hashedPassword,
      station,
      policeStation: station,
      position: position,
      profileImage: profileImage,
      location: { type: 'Point', coordinates: [0.0, 0.0] } // Explicitly satisfy 2dsphere index
    });

    await Verification.deleteMany({ badgeNumber });

    if (officer) {
      res.status(HTTP.CREATED).json({
        success: true,
        _id: officer.id,
        name: officer.name,
        email: officer.email,
        token: generateToken(officer.id),
      });
    } else {
      res.status(HTTP.BAD_REQUEST).json({ message: 'Invalid officer data' });
    }

  } catch (error) {
    console.error("[AUTH/REGISTER-POLICE] Register Error:", error);

    // Mongoose Duplicate Key Error (code 11000)
    if (error.code === 11000) {
      const field = Object.keys(error.keyValue)[0];
      const message = `${field.charAt(0).toUpperCase() + field.slice(1)} already registered.`;
      return res.status(HTTP.BAD_REQUEST).json({ success: false, message });
    }

    // Mongoose Validation Error
    if (error.name === 'ValidationError') {
      const messages = Object.values(error.errors).map(val => val.message);
      return res.status(HTTP.BAD_REQUEST).json({ success: false, message: messages.join(', ') });
    }

    res.status(HTTP.SERVER_ERROR).json({ success: false, message: 'Internal Server Error', error: error.message });
  }
};

// @desc    Register New Driver
// @route   POST /api/auth/register-driver
const registerDriver = async (req, res) => {
  const { 
    name, nic, licenseNumber, email, phone, password, 
    kycVerified, isVerified, licenseIssueDate, licenseExpiryDate, 
    vehicleClasses, profileImage, licenseFrontImage, licenseBackImage,
    addressLine1, addressLine2, city, postalCode
  } = req.body;
  
  console.log(`[AUTH/REGISTER-DRIVER] Incoming request for email: ${email}, nic: ${nic}, kycVerified: ${kycVerified}, isVerified: ${isVerified}`);

  try {
    const driverExists = await Driver.findOne({ 
      $or: [
        { email },
        { nic },
        { licenseNumber },
        { phone }
      ]
    });
    if (driverExists) {
      let duplicateField = 'Driver';
      if (driverExists.email === email) duplicateField = 'Email';
      else if (driverExists.nic === nic) duplicateField = 'NIC';
      else if (driverExists.licenseNumber === licenseNumber) duplicateField = 'License Number';
      else if (driverExists.phone === phone) duplicateField = 'Phone Number';

      console.warn(`[AUTH/REGISTER-DRIVER] Duplicate field attempted: ${duplicateField}`);
      return res.status(HTTP.BAD_REQUEST).json({ message: `${duplicateField} already registered for a driver` });
    }

    // Decrypt RSA-encrypted password sent from Flutter
    console.log(`[AUTH/REGISTER-DRIVER] Decrypting RSA password for: ${email}`);
    let plainPassword;
    try {
      plainPassword = decryptPassword(password);
    } catch (e) {
      console.error('[AUTH/REGISTER-DRIVER] RSA decrypt failed:', e.message);
      return res.status(HTTP.BAD_REQUEST).json({ message: 'Invalid encrypted password' });
    }

    console.log(`[AUTH/REGISTER-DRIVER] Hashing password for: ${email}`);
    const salt = await bcrypt.genSalt(AUTH.BCRYPT_SALT_ROUNDS);
    const hashedPassword = await bcrypt.hash(plainPassword, salt);

    console.log(`[AUTH/REGISTER-DRIVER] Creating driver record for: ${email}`);
    const driver = await Driver.create({
      name,
      nic,
      licenseNumber,
      email,
      phone,
      password: hashedPassword,
      kycVerified: kycVerified === true, // Only store true if explicitly passed
      isVerified: isVerified === true,   // Mark as verified if KYC passed
      licenseIssueDate,
      licenseExpiryDate,
      vehicleClasses: vehicleClasses || [],
      profileImage,
      licenseFrontImage,
      licenseBackImage,
      addressLine1: addressLine1 || '',
      addressLine2: addressLine2 || '',
      city: city || '',
      postalCode: postalCode || '',
      vehicleNumber: req.body.vehicleNumber || ''
    });

    if (driver) {
      console.log(`[AUTH/REGISTER-DRIVER] Successfully created driver ID: ${driver.id}`);
      res.status(HTTP.CREATED).json({
        success: true,
        _id: driver.id,
        name: driver.name,
        email: driver.email,
        role: ROLES.DRIVER,
        kycVerified: driver.kycVerified,
        token: generateToken(driver.id),
      });
    } else {
      console.error(`[AUTH/REGISTER-DRIVER] Driver creation returned null for: ${email}`);
      res.status(HTTP.BAD_REQUEST).json({ message: 'Invalid driver data' });
    }

  } catch (error) {
    console.error("[AUTH/REGISTER-DRIVER] Exception:", {
      message: error.message,
      email: email,
      stack: error.stack
    });

    // Mongoose Duplicate Key Error
    if (error.code === 11000) {
      const field = Object.keys(error.keyValue)[0];
      const message = `${field.charAt(0).toUpperCase() + field.slice(1)} already registered.`;
      return res.status(HTTP.BAD_REQUEST).json({ success: false, message });
    }

    // Mongoose Validation Error
    if (error.name === 'ValidationError') {
      const messages = Object.values(error.errors).map(val => val.message);
      return res.status(HTTP.BAD_REQUEST).json({ success: false, message: messages.join(', ') });
    }

    res.status(HTTP.SERVER_ERROR).json({ success: false, message: 'Internal Server Error', error: error.message });
  }
};

// @desc    Login User (Police or Driver)
// @route   POST /api/auth/login
// --- THIS FUNCTION IS UPDATED ---
const loginUser = async (req, res) => {
  const { email, password } = req.body;

  try {
    let user = null;
    let role = '';

    const officer = await Police.findOne({ email });
    if (officer) {
      user = officer;
      role = officer.role || ROLES.POLICE;
    } else {
      const driver = await Driver.findOne({ email });
      if (driver) {
        user = driver;
        role = ROLES.DRIVER;
      }
    }

    if (user && (await bcrypt.compare(password, user.password))) {
      res.json({
        success: true,
        user: {
          _id: user.id,
          name: user.name,
          email: user.email,
          role: role,
          badgeNumber: user.badgeNumber,
  
          // --- NEW FIELDS RETURNED FOR PROFILE ---
          position: user.position,
          policeStation: user.policeStation,
          profileImage: user.profileImage,
          licenseFrontImage: user.licenseFrontImage,
          licenseBackImage: user.licenseBackImage,
  
          isVerified: user.isVerified,
          licenseNumber: user.licenseNumber,
          nic: user.nic,
          phone: user.phone,
          vehicleNumber: user.vehicleNumber,
        },
        token: generateToken(user.id),
      });
    } else {
      res.status(HTTP.UNAUTHORIZED).json({ message: 'Invalid email or password' });
    }
  } catch (error) {
    res.status(HTTP.SERVER_ERROR).json({ message: 'Server Error', error: error.message });
  }
};

// @desc    Get Current User Data
// @route   GET /api/auth/me
// @access  Private
const getMe = async (req, res) => {
  try {
    const user = await Police.findById(req.user.id).select('-password');

    if (user) {
      res.status(HTTP.OK).json(user);
    } else {
      const driver = await Driver.findById(req.user.id).select('-password');
      if (driver) {
        res.status(HTTP.OK).json(driver);
      } else {
        res.status(HTTP.NOT_FOUND).json({ message: 'User not found' });
      }
    }
  } catch (error) {
    res.status(HTTP.SERVER_ERROR).json({ message: 'Server Error', error: error.message });
  }
};

// @desc    Verify Driver by License Number (For Police)
// @route   PUT /api/auth/verify-driver
// @access  Private
const verifyDriver = async (req, res) => {
  const { licenseNumber } = req.body;

  try {
    const driver = await Driver.findOne({ licenseNumber }).select('-password');

    if (driver) {
      res.status(HTTP.OK).json({ success: true, data: driver });
    } else {
      res.status(HTTP.NOT_FOUND).json({ success: false, message: 'Driver not found' });
    }
  } catch (error) {
    res.status(HTTP.SERVER_ERROR).json({ message: 'Server Error', error: error.message });
  }
};

// @desc    Update Profile Picture
// @route   PUT /api/auth/update-image
// @access  Private
const updateProfileImage = async (req, res) => {
  const id = req.body.id || req.user.id;
  const { profileImage } = req.body;

  try {
    let user = await Police.findByIdAndUpdate(id, { profileImage }, { new: true });

    if (!user) {
      user = await Driver.findByIdAndUpdate(id, { profileImage }, { new: true });
    }

    if (!user) {
      return res.status(HTTP.NOT_FOUND).json({ message: 'User not found' });
    }

    res.status(HTTP.OK).json({ success: true, message: 'Profile image updated successfully' });

  } catch (error) {
    console.error(error);
    res.status(HTTP.SERVER_ERROR).json({ message: 'Server Error', error: error.message });
  }
};

// @desc    Update Driver Profile (Address/City/PostalCode)
// @route   PUT /api/auth/update-profile
// @access  Private
const updateProfile = async (req, res) => {
  const { addressLine1, addressLine2, city, postalCode, vehicleNumber } = req.body;
  const id = req.user.id; // From protect middleware

  try {
    const updatedDriver = await Driver.findByIdAndUpdate(
      id,
      { addressLine1, addressLine2, city, postalCode, vehicleNumber },
      { new: true, runValidators: true }
    ).select('-password');

    if (!updatedDriver) {
      return res.status(HTTP.NOT_FOUND).json({ message: 'Driver not found' });
    }

    res.status(HTTP.OK).json({
      success: true,
      message: 'Profile updated successfully',
      data: updatedDriver
    });

  } catch (error) {
    console.error(`[AUTH/UPDATE-PROFILE] Error: ${error.message}`);
    res.status(HTTP.SERVER_ERROR).json({ message: 'Server Error', error: error.message });
  }
};

// ... Password Reset Functions ...

// ─── DRIVER LICENSE RECOVERY ─────────────────────────────────────────────────
// These 3 endpoints form a driver-only alternative account recovery flow.
// No email/OTP is required — the physical driving license scan is the 2nd factor.
// ─────────────────────────────────────────────────────────────────────────────

// @desc    Step 1 — Look up a driver by their license number
// @route   POST /api/auth/license-recovery/lookup
// @access  Public
const lookupDriverByLicense = async (req, res) => {
  const { licenseNumber } = req.body;

  if (!licenseNumber || licenseNumber.trim() === '') {
    return res.status(HTTP.BAD_REQUEST).json({ success: false, message: 'License number is required.' });
  }

  try {
    // Driver-only check — police officers cannot use this flow
    const driver = await Driver.findOne({
      licenseNumber: { $regex: new RegExp(`^${licenseNumber.trim()}$`, 'i') }
    }).select('name email licenseNumber');

    if (!driver) {
      return res.status(HTTP.NOT_FOUND).json({ success: false, message: 'No driver account found with this license number.' });
    }

    // Mask email: abc***@gmail.com
    const emailParts  = driver.email.split('@');
    const localPart   = emailParts[0];
    const domain      = emailParts[1];
    const maskedLocal = localPart.length <= 3
      ? localPart[0] + '***'
      : localPart.substring(0, 3) + '***';
    const maskedEmail = `${maskedLocal}@${domain}`;

    console.log(`[AUTH/LICENSE-RECOVERY/LOOKUP] Found driver for license: ${licenseNumber}`);

    res.status(HTTP.OK).json({
      success:      true,
      name:         driver.name,
      maskedEmail,
      licenseNumber: driver.licenseNumber,
    });
  } catch (error) {
    console.error('[AUTH/LICENSE-RECOVERY/LOOKUP] Error:', error.message);
    res.status(HTTP.SERVER_ERROR).json({ success: false, message: 'Server Error', error: error.message });
  }
};

// @desc    Step 2 — Verify the scanned license number against the entered one,
//                   then issue a 10-minute server-side recovery token.
// @route   POST /api/auth/license-recovery/verify-scan
// @access  Public
const verifyLicenseScan = async (req, res) => {
  const { licenseNumber, scannedLicenseNumber } = req.body;

  if (!licenseNumber || !scannedLicenseNumber) {
    return res.status(HTTP.BAD_REQUEST).json({ success: false, message: 'Both licenseNumber and scannedLicenseNumber are required.' });
  }

  try {
    // Confirm the driver exists (driver-only)
    const driver = await Driver.findOne({
      licenseNumber: { $regex: new RegExp(`^${licenseNumber.trim()}$`, 'i') }
    }).select('_id licenseNumber');

    if (!driver) {
      return res.status(HTTP.NOT_FOUND).json({ success: false, message: 'Driver not found.' });
    }

    // ── Fuzzy normalisation ────────────────────────────────────────────────
    // Remove all non-alphanumeric characters, uppercase, collapse whitespace.
    // This tolerates common OCR misreads: spaces, dashes, lower-case letters.
    const normalise = (str) =>
      str.toUpperCase().replace(/[^A-Z0-9]/g, '');

    const normEntered  = normalise(licenseNumber);
    const normScanned  = normalise(scannedLicenseNumber);

    // Allow up to 1 character difference for single OCR misreads
    // (e.g., 'B1234567' vs 'B1234S67' — one digit misread)
    const levenshtein = (a, b) => {
      const m = a.length, n = b.length;
      const dp = Array.from({ length: m + 1 }, (_, i) =>
        Array.from({ length: n + 1 }, (_, j) => (i === 0 ? j : j === 0 ? i : 0))
      );
      for (let i = 1; i <= m; i++) {
        for (let j = 1; j <= n; j++) {
          dp[i][j] = a[i - 1] === b[j - 1]
            ? dp[i - 1][j - 1]
            : 1 + Math.min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]);
        }
      }
      return dp[m][n];
    };

    const distance = levenshtein(normEntered, normScanned);
    const isMatch  = distance <= 1; // 0 = exact, 1 = one misread char

    if (!isMatch) {
      console.warn(`[AUTH/LICENSE-RECOVERY/VERIFY-SCAN] Mismatch: entered="${normEntered}" scanned="${normScanned}" distance=${distance}`);
      return res.status(HTTP.BAD_REQUEST).json({
        success: false,
        message: 'Scanned license number does not match. Please ensure the front side of your license is clearly visible and try again.',
      });
    }

    // ── Issue 10-minute recovery token ────────────────────────────────────
    const recoveryToken = randomUUID();

    // Reuse Verification collection — key = licenseNumber, stationCode = 'LICENSE_RECOVERY'
    await Verification.deleteMany({ badgeNumber: licenseNumber.toUpperCase(), stationCode: 'LICENSE_RECOVERY' });
    await Verification.create({
      badgeNumber:  licenseNumber.toUpperCase(),
      stationCode:  'LICENSE_RECOVERY',
      otp:          recoveryToken,
      expiresAt:    new Date(Date.now() + 10 * 60 * 1000), // 10 minutes
    });

    console.log(`[AUTH/LICENSE-RECOVERY/VERIFY-SCAN] Recovery token issued for license: ${licenseNumber} (distance=${distance})`);

    res.status(HTTP.OK).json({
      success:       true,
      recoveryToken,
      message:       'License verified successfully. You may now reset your password.',
    });
  } catch (error) {
    console.error('[AUTH/LICENSE-RECOVERY/VERIFY-SCAN] Error:', error.message);
    res.status(HTTP.SERVER_ERROR).json({ success: false, message: 'Server Error', error: error.message });
  }
};

// @desc    Step 3 — Reset driver password using the recovery token
// @route   POST /api/auth/license-recovery/reset-password
// @access  Public
const resetPasswordByLicense = async (req, res) => {
  const { licenseNumber, recoveryToken, newPassword } = req.body;

  if (!licenseNumber || !recoveryToken || !newPassword) {
    return res.status(HTTP.BAD_REQUEST).json({ success: false, message: 'licenseNumber, recoveryToken and newPassword are required.' });
  }

  try {
    // Validate the recovery token (driver-only, LICENSE_RECOVERY type)
    const record = await Verification.findOne({
      badgeNumber:  licenseNumber.toUpperCase(),
      stationCode:  'LICENSE_RECOVERY',
      otp:          recoveryToken,
    });

    if (!record) {
      return res.status(HTTP.BAD_REQUEST).json({ success: false, message: 'Invalid or expired recovery token. Please restart the recovery process.' });
    }

    // Check expiry (10 minutes)
    if (record.expiresAt && new Date() > new Date(record.expiresAt)) {
      await Verification.deleteMany({ badgeNumber: licenseNumber.toUpperCase(), stationCode: 'LICENSE_RECOVERY' });
      return res.status(HTTP.BAD_REQUEST).json({ success: false, message: 'Recovery token has expired (10 minutes). Please restart.' });
    }

    // Decrypt RSA-encrypted password from Flutter
    let plainNewPassword;
    try {
      plainNewPassword = decryptPassword(newPassword);
    } catch (e) {
      console.error('[AUTH/LICENSE-RECOVERY/RESET] RSA decrypt failed:', e.message);
      return res.status(HTTP.BAD_REQUEST).json({ success: false, message: 'Invalid encrypted password.' });
    }

    const salt           = await bcrypt.genSalt(AUTH.BCRYPT_SALT_ROUNDS);
    const hashedPassword = await bcrypt.hash(plainNewPassword, salt);

    // Update driver password (driver-only — never touches Police model)
    const updated = await Driver.findOneAndUpdate(
      { licenseNumber: { $regex: new RegExp(`^${licenseNumber.trim()}$`, 'i') } },
      { password: hashedPassword }
    );

    if (!updated) {
      return res.status(HTTP.NOT_FOUND).json({ success: false, message: 'Driver not found.' });
    }

    // Clean up the used recovery token
    await Verification.deleteMany({ badgeNumber: licenseNumber.toUpperCase(), stationCode: 'LICENSE_RECOVERY' });

    console.log(`[AUTH/LICENSE-RECOVERY/RESET] Password reset successful for license: ${licenseNumber}`);

    res.status(HTTP.OK).json({ success: true, message: 'Password reset successfully. You can now log in with your new password.' });
  } catch (error) {
    console.error('[AUTH/LICENSE-RECOVERY/RESET] Error:', error.message);
    res.status(HTTP.SERVER_ERROR).json({ success: false, message: 'Server Error', error: error.message });
  }
};

const forgotPassword = async (req, res) => {
  const { email } = req.body;
  try {
    let user = await Police.findOne({ email });
    if (!user) user = await Driver.findOne({ email });

    if (!user) return res.status(HTTP.NOT_FOUND).json({ message: 'User not found with this email' });

    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    await Verification.deleteMany({ badgeNumber: email });
    await Verification.create({ badgeNumber: email, stationCode: 'RESET', otp });

    const message = `You requested a password reset. OTP: ${otp}`;
    await sendEmail({ email: user.email, subject: 'Password Reset Code', message });

    res.status(HTTP.OK).json({ success: true, message: 'OTP sent to email' });
  } catch (error) {
    res.status(HTTP.SERVER_ERROR).json({ message: 'Server Error', error: error.message });
  }
};

const verifyResetOTP = async (req, res) => {
  const { email, otp } = req.body;
  try {
    const record = await Verification.findOne({ badgeNumber: email, otp });
    if (!record) return res.status(HTTP.BAD_REQUEST).json({ success: false, message: 'Invalid OTP' });
    res.status(HTTP.OK).json({ success: true, message: 'OTP Verified' });
  } catch (error) {
    res.status(HTTP.SERVER_ERROR).json({ message: 'Server Error', error: error.message });
  }
};

const resetPassword = async (req, res) => {
  const { email, newPassword, otp } = req.body;
  try {
    const record = await Verification.findOne({ badgeNumber: email, otp });
    if (!record) return res.status(HTTP.BAD_REQUEST).json({ message: 'Invalid OTP' });

    // Decrypt RSA-encrypted new password sent from Flutter
    let plainNewPassword;
    try {
      plainNewPassword = decryptPassword(newPassword);
    } catch (e) {
      return res.status(HTTP.BAD_REQUEST).json({ message: 'Invalid encrypted password' });
    }

    const salt = await bcrypt.genSalt(AUTH.BCRYPT_SALT_ROUNDS);
    const hashedPassword = await bcrypt.hash(plainNewPassword, salt);

    let updated = await Police.findOneAndUpdate({ email }, { password: hashedPassword });
    if (!updated) updated = await Driver.findOneAndUpdate({ email }, { password: hashedPassword });

    if (updated) {
      await Verification.deleteMany({ badgeNumber: email });
      res.status(HTTP.OK).json({ success: true, message: 'Password Reset Successful' });
    } else {
      res.status(HTTP.NOT_FOUND).json({ message: 'User not found' });
    }
  } catch (error) {
    res.status(HTTP.SERVER_ERROR).json({ message: 'Server Error', error: error.message });
  }
};

// @desc    Check if a specific field (nic, email, phone, licenseNumber) already exists in DB
// @route   GET /api/auth/check-exists
// @access  Public
const checkFieldExistence = async (req, res) => {
  const { field, value, role } = req.query;

  if (!field || !value) {
    return res.status(HTTP.BAD_REQUEST).json({ success: false, message: 'Field and value are required.' });
  }

  try {
    const query = {};
    // Regex for case-insensitive exact match
    query[field] = { $regex: new RegExp(`^${value}$`, 'i') };

    let exists = false;
    let existingRecord = null;

    // determine which models to check based on role
    const checkDriver = !role || role === ROLES.DRIVER;
    const checkPolice = !role || role === ROLES.POLICE || role === ROLES.OFFICER;

    if (checkDriver) {
      existingRecord = await Driver.findOne(query).select('_id');
    }
    
    if (!existingRecord && checkPolice) {
      // For badgeNumber, only check Police anyway
      // For others, if role is police or not provided, check Police
      if (field !== 'licenseNumber') {
        existingRecord = await Police.findOne(query).select('_id');
      }
    }

    if (existingRecord) {
      exists = true;
    }

    res.status(HTTP.OK).json({
      success: true,
      exists: exists,
      message: exists ? `${field} already exists.` : `${field} is available.`
    });
  } catch (error) {
    console.error(`[AUTH/CHECK-EXISTS] Error: ${error.message}`);
    res.status(HTTP.SERVER_ERROR).json({ success: false, message: 'Server Error', error: error.message });
  }
};

module.exports = {
  requestVerification,
  verifyOTP,
  registerPolice,
  registerDriver,
  forgotPassword,
  verifyResetOTP,
  resetPassword,
  loginUser,
  getMe,
  verifyDriver,
  updateProfileImage,
  updateProfile,
  checkFieldExistence,
  // Driver License Recovery
  lookupDriverByLicense,
  verifyLicenseScan,
  resetPasswordByLicense,
};