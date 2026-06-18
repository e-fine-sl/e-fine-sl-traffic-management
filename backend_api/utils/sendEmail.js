const sgMail = require('@sendgrid/mail');
const { EMAIL } = require('../config/constants');

// Configure SendGrid with API key
// This uses HTTPS (port 443) instead of SMTP — works on Render.com
sgMail.setApiKey(process.env.SENDGRID_API_KEY);

// IMPORTANT: This must match the verified sender on SendGrid dashboard
const SENDGRID_FROM_EMAIL = process.env.SENDGRID_FROM_EMAIL || 'efinesl.support@gmail.com';

const sendEmail = async (options) => {
  const msg = {
    to: options.email,
    from: {
      email: SENDGRID_FROM_EMAIL,
      name: EMAIL.FROM_NAME,
    },
    subject: options.subject,
    text: options.message || options.subject,
    html: options.html,
  };

  await sgMail.send(msg);
};

module.exports = sendEmail;