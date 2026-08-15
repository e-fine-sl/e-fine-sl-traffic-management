const nodemailer = require('nodemailer');
const fs = require('fs');
const path = require('path');
const { APP, LICENSE_STATUS, EMAIL } = require('../config/constants');
const sendEmail = require('../utils/sendEmail');

/**
 * Creates a reusable nodemailer transporter with short connection timeouts.
 */
const createTransporter = () => {
  return nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASS,
    },
    connectionTimeout: 5000,
    greetingTimeout: 5000,
    socketTimeout: 5000,
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
 * Helper to dispatch email via SendGrid with Nodemailer SMTP fallback.
 */
const dispatchEmail = async (to, subject, html, logContext = 'Email') => {
  if (!to) {
    console.warn(`[EmailService] ${logContext}: Missing recipient email`);
    return false;
  }

  // 1. Try SendGrid HTTPS API first
  if (process.env.SENDGRID_API_KEY) {
    try {
      await sendEmail({
        email: to,
        subject,
        html,
      });
      console.log(`[EmailService] ${logContext} sent via SendGrid HTTPS to ${to}`);
      return true;
    } catch (sgError) {
      console.warn(`[EmailService] SendGrid API failed for ${to}, trying Nodemailer fallback:`, sgError.message);
    }
  }

  // 2. Fallback to Nodemailer SMTP
  try {
    const transporter = createTransporter();
    await transporter.sendMail({
      from: `"e-Fine SL Traffic Authority" <${process.env.EMAIL_USER}>`,
      to,
      subject,
      html,
    });
    console.log(`[EmailService] ${logContext} sent via Nodemailer to ${to}`);
    return true;
  } catch (smtpError) {
    console.error(`[EmailService] Failed to send email to ${to}:`, smtpError.message);
    return false;
  }
};

/**
 * Sends a license status change email to the driver (ACTIVE / SUSPENDED).
 */
const sendLicenseStatusEmail = async (driver, newStatus, reasonNote = null) => {
  const today = formatDate(new Date());
  const isActive = newStatus === LICENSE_STATUS.ACTIVE || newStatus === 'ACTIVE';

  const subject = isActive
    ? `[e-Fine SL] Driving License Restored (ACTIVE) — License #${driver.licenseNumber}`
    : `[e-Fine SL] Driving License Suspended — License #${driver.licenseNumber}`;

  const html = isActive
    ? buildActivationEmail(driver, today)
    : buildSuspensionEmail(driver, today, reasonNote);

  return dispatchEmail(driver.email, subject, html, 'License Status Email');
};

/**
 * Sends an email notification when driver profile information is updated.
 */
const sendProfileUpdatedEmail = async (driver, updatedFields = []) => {
  const today = formatDate(new Date());
  const subject = `[e-Fine SL] Motorist Profile Details Updated — License #${driver.licenseNumber}`;
  const html = buildProfileUpdatedEmail(driver, today, updatedFields);
  return dispatchEmail(driver.email, subject, html, 'Profile Update Email');
};

/**
 * Sends an email notification when driver demerit points are adjusted (manual or automatic).
 */
const sendDemeritAdjustmentEmail = async (driver, previousPoints, newPoints, reason = '', isAutomatic = false) => {
  const today = formatDate(new Date());
  const pointDifference = newPoints - (previousPoints ?? 24);
  const diffStr = pointDifference > 0 ? `+${pointDifference}` : `${pointDifference}`;

  const subject = isAutomatic
    ? `[e-Fine SL] Monthly Good-Driver Point Recovery (${diffStr} Points) — License #${driver.licenseNumber}`
    : `[e-Fine SL] Demerit Points Adjustment Notice (${diffStr} Points) — License #${driver.licenseNumber}`;

  const html = buildDemeritAdjustmentEmail(driver, today, previousPoints, newPoints, pointDifference, reason, isAutomatic);
  return dispatchEmail(driver.email, subject, html, 'Demerit Adjustment Email');
};

/**
 * Sends an official Traffic Fine Citation Notice email to the driver.
 */
const sendFineIssuedEmail = async (driver, fine, offenseDetails = {}, demeritDeduction = 0, remainingPoints = 24) => {
  const fineIdShort = (fine._id ? fine._id.toString().slice(-8) : 'CITATION').toUpperCase();
  const subject = `[e-Fine SL] Traffic Fine Notice #${fineIdShort} — ${fine.offenseName || 'Violation'}`;
  const html = buildFineNoticeEmail(driver, fine, offenseDetails, demeritDeduction, remainingPoints);
  return dispatchEmail(driver.email, subject, html, 'Fine Notice Email');
};

// ─── ACTIVATION EMAIL TEMPLATE ──────────────────────────────────────
function buildActivationEmail(driver, today) {
  return `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f1f5f9;font-family:Arial,Helvetica,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f1f5f9;padding:24px 0;">
<tr><td align="center">
<table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 4px 16px rgba(0,0,0,0.06);border:1px solid #e2e8f0;">
  <tr>
    <td style="background:#16a34a;padding:22px 28px;text-align:left;">
      <h1 style="margin:0;color:#ffffff;font-size:20px;font-weight:bold;letter-spacing:0.5px;">e-Fine SL</h1>
      <p style="margin:3px 0 0;color:#dcfce7;font-size:11px;">Sri Lanka Traffic Police & Department of Motor Traffic</p>
    </td>
  </tr>
  <tr>
    <td style="padding:24px 28px;">
      <p style="margin:0 0 12px;color:#1e293b;font-size:14px;">Dear <strong>${driver.name}</strong>,</p>
      <p style="margin:0 0 16px;color:#475569;font-size:13px;line-height:1.6;">
        We are pleased to inform you that your driving license has been successfully
        <strong style="color:#16a34a;">ACTIVATED & RESTORED</strong> by the Traffic Management Authority. You are authorized to operate your vehicle.
      </p>
      <table width="100%" cellpadding="0" cellspacing="0" style="background:#f0fdf4;border-radius:8px;border-left:4px solid #16a34a;margin:0 0 16px;">
        <tr><td style="padding:14px 18px;font-size:13px;color:#1e293b;">
          <p style="margin:0 0 4px;"><strong>License Status:</strong> <span style="color:#16a34a;font-weight:bold;">ACTIVE</span></p>
          <p style="margin:0 0 4px;"><strong>Effective Date:</strong> ${today}</p>
          <p style="margin:0 0 4px;"><strong>License Number:</strong> <span style="font-family:monospace;font-weight:bold;">${driver.licenseNumber}</span></p>
          <p style="margin:0;"><strong>Demerit Balance:</strong> ${driver.demeritPoints ?? 24} / 24 Points (EXCELLENT)</p>
        </td></tr>
      </table>
      <p style="margin:0;color:#64748b;font-size:12px;line-height:1.5;">
        Please continue to adhere to road traffic safety laws to maintain your good-driver rating.
      </p>
    </td>
  </tr>
  <tr>
    <td style="background:#0f172a;padding:16px 28px;text-align:center;">
      <p style="margin:0 0 4px;color:#94a3b8;font-size:11px;">e-Fine SL — Department of Motor Traffic, Sri Lanka</p>
      <p style="margin:0;color:#64748b;font-size:10px;">This is an official administrative notice. Do not reply.</p>
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
<body style="margin:0;padding:0;background:#f1f5f9;font-family:Arial,Helvetica,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f1f5f9;padding:24px 0;">
<tr><td align="center">
<table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 4px 16px rgba(0,0,0,0.06);border:1px solid #e2e8f0;">
  <tr>
    <td style="background:#dc2626;padding:22px 28px;text-align:left;">
      <h1 style="margin:0;color:#ffffff;font-size:20px;font-weight:bold;letter-spacing:0.5px;">e-Fine SL</h1>
      <p style="margin:3px 0 0;color:#fecaca;font-size:11px;">Sri Lanka Traffic Police & Department of Motor Traffic</p>
    </td>
  </tr>
  <tr>
    <td style="padding:24px 28px;">
      <p style="margin:0 0 12px;color:#1e293b;font-size:14px;">Dear <strong>${driver.name}</strong>,</p>
      <p style="margin:0 0 16px;color:#475569;font-size:13px;line-height:1.6;">
        This is an official notice that your driving license has been
        <strong style="color:#dc2626;">SUSPENDED</strong> by the Traffic Management Authority.
      </p>
      <table width="100%" cellpadding="0" cellspacing="0" style="background:#fef2f2;border-radius:8px;border-left:4px solid #dc2626;margin:0 0 16px;">
        <tr><td style="padding:14px 18px;font-size:13px;color:#1e293b;">
          <p style="margin:0 0 4px;"><strong>License Status:</strong> <span style="color:#dc2626;font-weight:bold;">SUSPENDED</span></p>
          <p style="margin:0 0 4px;"><strong>Effective Date:</strong> ${today}</p>
          <p style="margin:0 0 4px;"><strong>License Number:</strong> <span style="font-family:monospace;font-weight:bold;">${driver.licenseNumber}</span></p>
          <p style="margin:0;color:#b91c1c;"><strong>Reason / Grounds:</strong> ${reasonText}</p>
        </td></tr>
      </table>
      <table width="100%" cellpadding="0" cellspacing="0" style="background:#fffbeb;border-radius:8px;border-left:4px solid #f59e0b;margin:0 0 16px;">
        <tr><td style="padding:12px 16px;font-size:12px;color:#92400e;line-height:1.5;">
          <strong>Legal Warning:</strong> Operating any motor vehicle with a suspended driving license is a serious criminal offense under the Sri Lanka Motor Traffic Act and may lead to impoundment and prosecution.
        </td></tr>
      </table>
      <p style="margin:0;color:#64748b;font-size:12px;line-height:1.5;">
        You may appeal this suspension or check reinstatement eligibility through your regional traffic division.
      </p>
    </td>
  </tr>
  <tr>
    <td style="background:#0f172a;padding:16px 28px;text-align:center;">
      <p style="margin:0 0 4px;color:#94a3b8;font-size:11px;">e-Fine SL — Department of Motor Traffic, Sri Lanka</p>
      <p style="margin:0;color:#64748b;font-size:10px;">This is an official administrative notice. Do not reply.</p>
    </td>
  </tr>
</table>
</td></tr></table>
</body>
</html>`;
}

// ─── PROFILE UPDATED EMAIL TEMPLATE ─────────────────────────────────
function buildProfileUpdatedEmail(driver, today, updatedFields = []) {
  const fieldsList = updatedFields.length > 0
    ? updatedFields.join(', ')
    : 'Contact Phone, Address, Vehicle Number, or Profile Particulars';

  return `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f1f5f9;font-family:Arial,Helvetica,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f1f5f9;padding:24px 0;">
<tr><td align="center">
<table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 4px 16px rgba(0,0,0,0.06);border:1px solid #e2e8f0;">
  <tr>
    <td style="background:#2563eb;padding:22px 28px;text-align:left;">
      <h1 style="margin:0;color:#ffffff;font-size:20px;font-weight:bold;letter-spacing:0.5px;">e-Fine SL</h1>
      <p style="margin:3px 0 0;color:#bfdbfe;font-size:11px;">Sri Lanka Traffic Police & Department of Motor Traffic</p>
    </td>
  </tr>
  <tr>
    <td style="padding:24px 28px;">
      <p style="margin:0 0 12px;color:#1e293b;font-size:14px;">Dear <strong>${driver.name}</strong>,</p>
      <p style="margin:0 0 16px;color:#475569;font-size:13px;line-height:1.6;">
        Your driver registration account details on the national traffic management portal have been updated by the Traffic Management Authority.
      </p>
      <table width="100%" cellpadding="0" cellspacing="0" style="background:#f8fafc;border-radius:8px;border:1px solid #e2e8f0;margin:0 0 16px;font-size:12px;">
        <tr style="border-bottom:1px solid #e2e8f0;">
          <td style="padding:10px 14px;color:#64748b;width:35%;">License Number:</td>
          <td style="padding:10px 14px;color:#0f172a;font-weight:bold;font-family:monospace;">${driver.licenseNumber}</td>
        </tr>
        <tr style="border-bottom:1px solid #e2e8f0;">
          <td style="padding:10px 14px;color:#64748b;">Updated Fields:</td>
          <td style="padding:10px 14px;color:#0f172a;">${fieldsList}</td>
        </tr>
        <tr>
          <td style="padding:10px 14px;color:#64748b;">Timestamp:</td>
          <td style="padding:10px 14px;color:#0f172a;">${today}</td>
        </tr>
      </table>
      <p style="margin:0;color:#64748b;font-size:12px;line-height:1.5;">
        If you did not request or authorize this change, please contact the e-Fine SL administrator or your nearest police station immediately.
      </p>
    </td>
  </tr>
  <tr>
    <td style="background:#0f172a;padding:16px 28px;text-align:center;">
      <p style="margin:0 0 4px;color:#94a3b8;font-size:11px;">e-Fine SL — Department of Motor Traffic, Sri Lanka</p>
      <p style="margin:0;color:#64748b;font-size:10px;">This is an automated security notification. Do not reply.</p>
    </td>
  </tr>
</table>
</td></tr></table>
</body>
</html>`;
}

// ─── DEMERIT ADJUSTMENT EMAIL TEMPLATE ──────────────────────────────
function buildDemeritAdjustmentEmail(driver, today, previousPoints, newPoints, diff, reason, isAutomatic) {
  const diffDisplay = diff > 0 ? `+${diff} Points` : `${diff} Points`;
  const diffColor = diff > 0 ? '#16a34a' : '#dc2626';

  return `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f1f5f9;font-family:Arial,Helvetica,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f1f5f9;padding:24px 0;">
<tr><td align="center">
<table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 4px 16px rgba(0,0,0,0.06);border:1px solid #e2e8f0;">
  <tr>
    <td style="background:#1e3a8a;padding:22px 28px;text-align:left;">
      <h1 style="margin:0;color:#ffffff;font-size:20px;font-weight:bold;letter-spacing:0.5px;">e-Fine SL</h1>
      <p style="margin:3px 0 0;color:#93c5fd;font-size:11px;">National Demerit Points & Driver Safety System</p>
    </td>
  </tr>
  <tr>
    <td style="padding:24px 28px;">
      <p style="margin:0 0 12px;color:#1e293b;font-size:14px;">Dear <strong>${driver.name}</strong>,</p>
      <p style="margin:0 0 16px;color:#475569;font-size:13px;line-height:1.6;">
        ${isAutomatic
          ? 'Congratulations! You have been rewarded with good-driver conduct recovery points for maintaining a clean driving record.'
          : 'Your driving license safety demerit points balance has been updated by the Traffic Management Authority.'}
      </p>

      <table width="100%" cellpadding="0" cellspacing="0" style="background:#f8fafc;border-radius:8px;border:1px solid #e2e8f0;margin:0 0 16px;font-size:12px;">
        <tr style="border-bottom:1px solid #e2e8f0;">
          <td style="padding:10px 14px;color:#64748b;width:38%;">License Number:</td>
          <td style="padding:10px 14px;color:#0f172a;font-weight:bold;font-family:monospace;">${driver.licenseNumber}</td>
        </tr>
        <tr style="border-bottom:1px solid #e2e8f0;">
          <td style="padding:10px 14px;color:#64748b;">Adjustment:</td>
          <td style="padding:10px 14px;color:${diffColor};font-weight:bold;font-size:13px;">${diffDisplay}</td>
        </tr>
        <tr style="border-bottom:1px solid #e2e8f0;">
          <td style="padding:10px 14px;color:#64748b;">New Demerit Balance:</td>
          <td style="padding:10px 14px;color:#0f172a;font-weight:bold;font-size:14px;">${newPoints} / 24 Points</td>
        </tr>
        <tr style="border-bottom:1px solid #e2e8f0;">
          <td style="padding:10px 14px;color:#64748b;">Safety Tier:</td>
          <td style="padding:10px 14px;color:#0f172a;font-weight:bold;">${driver.demeritLevel || 'EXCELLENT'}</td>
        </tr>
        <tr>
          <td style="padding:10px 14px;color:#64748b;">Reason / Reference:</td>
          <td style="padding:10px 14px;color:#0f172a;">${reason || (isAutomatic ? 'Automated Good-Behavior Recovery Cycle' : 'Administrative Adjustment')}</td>
        </tr>
      </table>

      <p style="margin:0;color:#64748b;font-size:12px;line-height:1.5;">
        You can view your full demerit ledger and traffic history at any time on the e-Fine Driver Mobile App.
      </p>
    </td>
  </tr>
  <tr>
    <td style="background:#0f172a;padding:16px 28px;text-align:center;">
      <p style="margin:0 0 4px;color:#94a3b8;font-size:11px;">e-Fine SL — Department of Motor Traffic, Sri Lanka</p>
      <p style="margin:0;color:#64748b;font-size:10px;">This is an official administrative notice. Do not reply.</p>
    </td>
  </tr>
</table>
</td></tr></table>
</body>
</html>`;
}

// ─── TRAFFIC FINE NOTICE EMAIL TEMPLATE ─────────────────────────────
function buildFineNoticeEmail(driver, fine, offenseDetails, demeritDeduction, remainingPoints) {
  const fineIdShort = (fine._id ? fine._id.toString().slice(-8) : 'CITATION').toUpperCase();
  const formattedAmount = (fine.amount || 0).toLocaleString();
  const issueDate = new Date(fine.date || Date.now()).toLocaleString('en-GB', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: true
  });

  return `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f1f5f9;font-family:Arial,Helvetica,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f1f5f9;padding:24px 0;">
<tr><td align="center">
<table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 4px 16px rgba(0,0,0,0.06);border:1px solid #e2e8f0;">
  
  <!-- HEADER -->
  <tr>
    <td style="background:#1e3a8a;padding:22px 28px;text-align:left;">
      <table width="100%"><tr>
        <td>
          <h1 style="margin:0;color:#ffffff;font-size:20px;font-weight:bold;letter-spacing:0.5px;">e-Fine SL</h1>
          <p style="margin:3px 0 0;color:#93c5fd;font-size:11px;">Sri Lanka Traffic Police & Department of Motor Traffic</p>
        </td>
        <td align="right">
          <span style="background:#ef4444;color:#ffffff;padding:4px 10px;border-radius:6px;font-size:11px;font-weight:bold;letter-spacing:0.5px;">UNPAID FINE</span>
        </td>
      </tr></table>
    </td>
  </tr>

  <!-- BODY CONTENT -->
  <tr>
    <td style="padding:24px 28px;">
      <p style="margin:0 0 12px;color:#1e293b;font-size:14px;">Dear <strong>${driver.name}</strong>,</p>
      <p style="margin:0 0 18px;color:#475569;font-size:13px;line-height:1.6;">
        A new traffic citation has been recorded against your Driving License (<strong style="font-family:monospace;">${driver.licenseNumber}</strong>) for a traffic violation under the Sri Lanka Motor Traffic Act.
      </p>

      <!-- FINE PARTICULARS TABLE -->
      <table width="100%" cellpadding="0" cellspacing="0" style="background:#f8fafc;border-radius:8px;border:1px solid #e2e8f0;margin:0 0 18px;font-size:12px;">
        <tr style="border-bottom:1px solid #e2e8f0;">
          <td style="padding:10px 14px;color:#64748b;width:38%;">Citation Reference:</td>
          <td style="padding:10px 14px;color:#0f172a;font-weight:bold;font-family:monospace;font-size:13px;">#${fineIdShort}</td>
        </tr>
        <tr style="border-bottom:1px solid #e2e8f0;">
          <td style="padding:10px 14px;color:#64748b;">Vehicle Plate:</td>
          <td style="padding:10px 14px;color:#0f172a;font-weight:bold;font-family:monospace;">${fine.vehicleNumber}</td>
        </tr>
        <tr style="border-bottom:1px solid #e2e8f0;">
          <td style="padding:10px 14px;color:#64748b;">Offense / Violation:</td>
          <td style="padding:10px 14px;color:#0f172a;font-weight:bold;">${fine.offenseName}</td>
        </tr>
        ${offenseDetails.sectionOfAct ? `
        <tr style="border-bottom:1px solid #e2e8f0;">
          <td style="padding:10px 14px;color:#64748b;">Section of Act:</td>
          <td style="padding:10px 14px;color:#0f172a;">${offenseDetails.sectionOfAct}</td>
        </tr>` : ''}
        <tr style="border-bottom:1px solid #e2e8f0;">
          <td style="padding:10px 14px;color:#64748b;">Location & Station:</td>
          <td style="padding:10px 14px;color:#0f172a;">${fine.place} • ${fine.policeStation}</td>
        </tr>
        <tr style="border-bottom:1px solid #e2e8f0;">
          <td style="padding:10px 14px;color:#64748b;">Date & Time:</td>
          <td style="padding:10px 14px;color:#0f172a;">${issueDate}</td>
        </tr>
        <tr style="border-bottom:1px solid #e2e8f0;">
          <td style="padding:10px 14px;color:#64748b;">Fine Amount (LKR):</td>
          <td style="padding:10px 14px;color:#b91c1c;font-weight:bold;font-size:14px;">LKR ${formattedAmount}</td>
        </tr>
        <tr>
          <td style="padding:10px 14px;color:#64748b;">Demerit Points Impact:</td>
          <td style="padding:10px 14px;color:#dc2626;font-weight:bold;">-${demeritDeduction} pts <span style="color:#64748b;font-weight:normal;">(Remaining: ${remainingPoints}/24 pts)</span></td>
        </tr>
      </table>

      <!-- PAYMENT CALLOUT -->
      <table width="100%" cellpadding="0" cellspacing="0" style="background:#eff6ff;border-radius:8px;border-left:4px solid #2563eb;margin:0 0 18px;">
        <tr><td style="padding:14px 18px;">
          <p style="margin:0 0 4px;font-size:13px;font-weight:bold;color:#1e3a8a;">Statutory Payment Notice</p>
          <p style="margin:0;font-size:12px;color:#1e40af;line-height:1.5;">
            Please settle this fine within 14 days to avoid court referral and further penalties. You can pay securely online via the <strong>e-Fine Driver Mobile App</strong> or official payment portal.
          </p>
        </td></tr>
      </table>

      <p style="margin:0;color:#94a3b8;font-size:11px;line-height:1.5;">
        If you wish to dispute this citation, you may contact the issuing police station (${fine.policeStation}) with your citation number #${fineIdShort}.
      </p>
    </td>
  </tr>

  <!-- FOOTER -->
  <tr>
    <td style="background:#0f172a;padding:16px 28px;text-align:center;">
      <p style="margin:0 0 4px;color:#94a3b8;font-size:11px;">e-Fine SL — Sri Lanka Traffic Police & Department of Motor Traffic</p>
      <p style="margin:0;color:#64748b;font-size:10px;">This is an automated legal notification. Please do not reply directly to this email.</p>
    </td>
  </tr>

</table>
</td></tr></table>
</body>
</html>`;
}

module.exports = {
  sendLicenseStatusEmail,
  sendProfileUpdatedEmail,
  sendDemeritAdjustmentEmail,
  sendFineIssuedEmail
};
