const nodemailer = require('nodemailer');
const { APP, LICENSE_STATUS, EMAIL } = require('../config/constants');

/**
 * Creates a reusable nodemailer transporter.
 */
const createTransporter = () => {
  return nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASS,
    },
  });
};

/**
 * Formats a date as "24 March 2026"
 */
const formatDate = (date) => {
  return new Date(date).toLocaleDateString('en-GB', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });
};

/**
 * Sends a license status change email to the driver.
 * @param {Object} driver - Driver document { name, email, licenseNumber }
 * @param {'ACTIVE'|'SUSPENDED'} newStatus - The new license status
 * @param {string|null} reasonNote - Optional note explaining the suspension
 */
const sendLicenseStatusEmail = async (driver, newStatus, reasonNote = null) => {
  const transporter = createTransporter();
  const today = formatDate(new Date());
  const isActive = newStatus === LICENSE_STATUS.ACTIVE;

  const subject = isActive
    ? EMAIL.SUBJECTS.LICENSE_ACTIVATED
    : EMAIL.SUBJECTS.LICENSE_SUSPENDED;

  const html = isActive
    ? buildActivationEmail(driver, today)
    : buildSuspensionEmail(driver, today, reasonNote);

  await transporter.sendMail({
    from: `"e-Fine SL" <${process.env.EMAIL_USER}>`,
    to: driver.email,
    subject,
    html,
  });
};

// ─── ACTIVATION EMAIL TEMPLATE ──────────────────────────────────────
function buildActivationEmail(driver, today) {
  return `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f4f4f4;font-family:Arial,Helvetica,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f4f4f4;padding:30px 0;">
<tr><td align="center">
<table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.08);">

  <!-- HEADER -->
  <tr>
    <td style="background:#4CAF50;padding:30px 40px 50px;text-align:center;">
      <h1 style="margin:0;color:#ffffff;font-size:26px;letter-spacing:1px;">${APP.NAME}</h1>
      <p style="margin:6px 0 0;color:rgba(255,255,255,0.85);font-size:13px;">Sri Lanka Traffic Fine Management System</p>
    </td>
  </tr>

  <!-- ICON -->
  <tr>
    <td align="center" style="padding:0;">
      <table cellpadding="0" cellspacing="0"><tr><td style="margin-top:-30px;display:block;">
        <div style="width:64px;height:64px;border-radius:50%;background:#ffffff;border:4px solid #4CAF50;margin:-32px auto 0;text-align:center;line-height:64px;font-size:30px;">✓</div>
      </td></tr></table>
    </td>
  </tr>

  <!-- BODY -->
  <tr>
    <td style="padding:30px 40px;">
      <p style="margin:0 0 16px;color:#333;font-size:16px;">Dear <strong>${driver.name}</strong>,</p>
      <p style="margin:0 0 20px;color:#555;font-size:14px;line-height:1.7;">
        We are pleased to inform you that your driving license has been successfully
        <strong style="color:#4CAF50;">ACTIVATED</strong> by the traffic authority.
        You may now legally operate your vehicle on Sri Lankan roads.
      </p>

      <!-- INFO BOX -->
      <table width="100%" cellpadding="0" cellspacing="0" style="background:#E8F5E9;border-radius:8px;border-left:4px solid #4CAF50;margin:0 0 20px;">
        <tr><td style="padding:16px 20px;">
          <p style="margin:0 0 6px;font-size:14px;color:#333;"><strong>Status:</strong>  ACTIVE</p>
          <p style="margin:0 0 6px;font-size:14px;color:#333;"><strong>Effective:</strong> ${today}</p>
          <p style="margin:0;font-size:14px;color:#333;"><strong>License No:</strong> ${driver.licenseNumber}</p>
        </td></tr>
      </table>

      <p style="margin:0;color:#888;font-size:13px;line-height:1.6;">
        If you believe this is an error, please contact the nearest traffic police station immediately.
      </p>
    </td>
  </tr>

  <!-- FOOTER -->
  <tr>
    <td style="background:#333;padding:20px 40px;text-align:center;">
      <p style="margin:0 0 4px;color:#aaa;font-size:12px;">e-Fine SL — Department of Motor Traffic, Sri Lanka</p>
      <p style="margin:0;color:#777;font-size:11px;">This is an automated message. Do not reply.</p>
    </td>
  </tr>

</table>
</td></tr></table>
</body>
</html>`;
}

// ─── SUSPENSION EMAIL TEMPLATE ──────────────────────────────────────
function buildSuspensionEmail(driver, today, reasonNote) {
  const reasonText = reasonNote || driver.suspensionReason || 'Accumulated Demerit Points Exhausted (0 Points)';
  return `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f4f4f4;font-family:Arial,Helvetica,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f4f4f4;padding:30px 0;">
<tr><td align="center">
<table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.08);">

  <!-- HEADER -->
  <tr>
    <td style="background:#F44336;padding:30px 40px 50px;text-align:center;">
      <h1 style="margin:0;color:#ffffff;font-size:26px;letter-spacing:1px;">${APP.NAME}</h1>
      <p style="margin:6px 0 0;color:rgba(255,255,255,0.85);font-size:13px;">Sri Lanka Traffic Fine Management System</p>
    </td>
  </tr>

  <!-- ICON -->
  <tr>
    <td align="center" style="padding:0;">
      <table cellpadding="0" cellspacing="0"><tr><td style="margin-top:-30px;display:block;">
        <div style="width:64px;height:64px;border-radius:50%;background:#ffffff;border:4px solid #F44336;margin:-32px auto 0;text-align:center;line-height:64px;font-size:30px;">⊘</div>
      </td></tr></table>
    </td>
  </tr>

  <!-- BODY -->
  <tr>
    <td style="padding:30px 40px;">
      <p style="margin:0 0 16px;color:#333;font-size:16px;">Dear <strong>${driver.name}</strong>,</p>
      <p style="margin:0 0 20px;color:#555;font-size:14px;line-height:1.7;">
        We regret to inform you that your driving license has been
        <strong style="color:#F44336;">SUSPENDED</strong> by the traffic authority.
      </p>

      <!-- INFO BOX -->
      <table width="100%" cellpadding="0" cellspacing="0" style="background:#FFEBEE;border-radius:8px;border-left:4px solid #F44336;margin:0 0 16px;">
        <tr><td style="padding:16px 20px;">
          <p style="margin:0 0 6px;font-size:14px;color:#333;"><strong>Status:</strong> SUSPENDED</p>
          <p style="margin:0 0 6px;font-size:14px;color:#333;"><strong>Effective:</strong> ${today}</p>
          <p style="margin:0 0 6px;font-size:14px;color:#333;"><strong>License No:</strong> ${driver.licenseNumber}</p>
          <p style="margin:0;font-size:14px;color:#D32F2F;"><strong>Reason / Note:</strong> ${reasonText}</p>
        </td></tr>
      </table>

      <!-- WARNING BOX -->
      <table width="100%" cellpadding="0" cellspacing="0" style="background:#FFF3E0;border-radius:8px;border-left:4px solid #FF9800;margin:0 0 16px;">
        <tr><td style="padding:14px 20px;">
          <p style="margin:0;font-size:13px;color:#E65100;line-height:1.6;">
             Operating a vehicle with a suspended license is a serious criminal offense
            under Sri Lankan traffic law and may result in arrest and prosecution.
          </p>
        </td></tr>
      </table>

      <p style="margin:0 0 16px;color:#555;font-size:14px;line-height:1.6;">
        Your license may be reinstated on the 1st of next month if demerit points are
        restored, or upon successful appeal.
      </p>

      <p style="margin:0;color:#888;font-size:13px;line-height:1.6;">
        If you believe this is an error, please contact the nearest traffic police station immediately.
      </p>
    </td>
  </tr>

  <!-- FOOTER -->
  <tr>
    <td style="background:#333;padding:20px 40px;text-align:center;">
      <p style="margin:0 0 4px;color:#aaa;font-size:12px;">e-Fine SL — Department of Motor Traffic, Sri Lanka</p>
      <p style="margin:0;color:#777;font-size:11px;">This is an automated message. Do not reply.</p>
    </td>
  </tr>

</table>
</td></tr></table>
</body>
</html>`;
}

module.exports = { sendLicenseStatusEmail };
