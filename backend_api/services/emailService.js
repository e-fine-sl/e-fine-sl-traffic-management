const nodemailer = require('nodemailer');
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
 * Sends a license status change email to the driver.
 */
const sendLicenseStatusEmail = async (driver, newStatus, reasonNote = null) => {
  const today = formatDate(new Date());
  const isActive = newStatus === LICENSE_STATUS.ACTIVE;

  const subject = isActive
    ? EMAIL.SUBJECTS.LICENSE_ACTIVATED
    : EMAIL.SUBJECTS.LICENSE_SUSPENDED;

  const html = isActive
    ? buildActivationEmail(driver, today)
    : buildSuspensionEmail(driver, today, reasonNote);

  if (process.env.SENDGRID_API_KEY) {
    try {
      await sendEmail({
        email: driver.email,
        subject,
        html,
      });
      console.log(`[EmailService] License status email sent via SendGrid HTTPS to ${driver.email}`);
      return;
    } catch (sgError) {
      console.warn('[EmailService] SendGrid API send failed, trying Nodemailer SMTP fallback:', sgError.message);
    }
  }

  try {
    const transporter = createTransporter();
    await transporter.sendMail({
      from: `"e-Fine SL" <${process.env.EMAIL_USER}>`,
      to: driver.email,
      subject,
      html,
    });
    console.log(`[EmailService] License status email sent via Nodemailer to ${driver.email}`);
  } catch (smtpError) {
    console.error(`[EmailService] Could not send email to ${driver.email}:`, smtpError.message);
  }
};

/**
 * Sends an official Traffic Fine Citation Notice email to the driver.
 */
const sendFineIssuedEmail = async (driver, fine, offenseDetails = {}, demeritDeduction = 0, remainingPoints = 24) => {
  if (!driver || !driver.email) {
    console.warn('[EmailService] sendFineIssuedEmail called without valid driver email');
    return;
  }

  const fineIdShort = (fine._id ? fine._id.toString().slice(-8) : 'CITATION').toUpperCase();
  const subject = `[e-Fine SL] Traffic Fine Notice #${fineIdShort} — ${fine.offenseName || 'Violation'}`;
  const html = buildFineNoticeEmail(driver, fine, offenseDetails, demeritDeduction, remainingPoints);

  if (process.env.SENDGRID_API_KEY) {
    try {
      await sendEmail({
        email: driver.email,
        subject,
        html,
      });
      console.log(`[EmailService] Traffic Fine notice email sent via SendGrid to ${driver.email}`);
      return;
    } catch (sgError) {
      console.warn('[EmailService] SendGrid fine email failed, falling back to Nodemailer:', sgError.message);
    }
  }

  try {
    const transporter = createTransporter();
    await transporter.sendMail({
      from: `"e-Fine SL Traffic Police" <${process.env.EMAIL_USER}>`,
      to: driver.email,
      subject,
      html,
    });
    console.log(`[EmailService] Traffic Fine notice email sent via Nodemailer to ${driver.email}`);
  } catch (smtpError) {
    console.error(`[EmailService] Could not send fine notice email to ${driver.email}:`, smtpError.message);
  }
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
  <tr>
    <td style="background:#2563EB;padding:24px 30px;text-align:center;">
      <h1 style="margin:0;color:#ffffff;font-size:22px;letter-spacing:0.5px;">${APP.NAME}</h1>
      <p style="margin:4px 0 0;color:rgba(255,255,255,0.85);font-size:12px;">Sri Lanka Traffic Fine Management System</p>
    </td>
  </tr>
  <tr>
    <td style="padding:24px 30px;">
      <p style="margin:0 0 14px;color:#333;font-size:15px;">Dear <strong>${driver.name}</strong>,</p>
      <p style="margin:0 0 16px;color:#555;font-size:13px;line-height:1.6;">
        Your driving license (<strong style="font-family:monospace;">${driver.licenseNumber}</strong>) has been successfully
        <strong style="color:#16A34A;">ACTIVATED</strong> by the traffic administration.
      </p>
      <table width="100%" cellpadding="0" cellspacing="0" style="background:#F0FDF4;border-radius:8px;border-left:4px solid #16A34A;margin:0 0 16px;">
        <tr><td style="padding:14px 18px;font-size:13px;color:#333;">
          <p style="margin:0 0 4px;"><strong>Status:</strong> ACTIVE</p>
          <p style="margin:0 0 4px;"><strong>Effective Date:</strong> ${today}</p>
          <p style="margin:0;"><strong>License No:</strong> ${driver.licenseNumber}</p>
        </td></tr>
      </table>
    </td>
  </tr>
  <tr>
    <td style="background:#1E293B;padding:16px 30px;text-align:center;">
      <p style="margin:0;color:#94A3B8;font-size:11px;">e-Fine SL — Department of Motor Traffic, Sri Lanka</p>
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
  <tr>
    <td style="background:#DC2626;padding:24px 30px;text-align:center;">
      <h1 style="margin:0;color:#ffffff;font-size:22px;letter-spacing:0.5px;">${APP.NAME}</h1>
      <p style="margin:4px 0 0;color:rgba(255,255,255,0.85);font-size:12px;">Sri Lanka Traffic Fine Management System</p>
    </td>
  </tr>
  <tr>
    <td style="padding:24px 30px;">
      <p style="margin:0 0 14px;color:#333;font-size:15px;">Dear <strong>${driver.name}</strong>,</p>
      <p style="margin:0 0 16px;color:#555;font-size:13px;line-height:1.6;">
        We regret to inform you that your driving license has been
        <strong style="color:#DC2626;">SUSPENDED</strong> due to traffic offenses or demerit point exhaustion.
      </p>
      <table width="100%" cellpadding="0" cellspacing="0" style="background:#FEF2F2;border-radius:8px;border-left:4px solid #DC2626;margin:0 0 16px;">
        <tr><td style="padding:14px 18px;font-size:13px;color:#333;">
          <p style="margin:0 0 4px;"><strong>Status:</strong> SUSPENDED</p>
          <p style="margin:0 0 4px;"><strong>Effective Date:</strong> ${today}</p>
          <p style="margin:0 0 4px;"><strong>License No:</strong> ${driver.licenseNumber}</p>
          <p style="margin:0;color:#B91C1C;"><strong>Reason:</strong> ${reasonText}</p>
        </td></tr>
      </table>
      <p style="margin:0;color:#DC2626;font-size:12px;line-height:1.5;">
        Driving with a suspended license is a criminal offense under the Sri Lanka Motor Traffic Act.
      </p>
    </td>
  </tr>
  <tr>
    <td style="background:#1E293B;padding:16px 30px;text-align:center;">
      <p style="margin:0;color:#94A3B8;font-size:11px;">e-Fine SL — Department of Motor Traffic, Sri Lanka</p>
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
  sendFineIssuedEmail
};
