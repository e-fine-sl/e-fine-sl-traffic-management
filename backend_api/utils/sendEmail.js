const nodemailer = require('nodemailer');
const dns = require('dns');
const { EMAIL } = require('../config/constants');
require('dotenv').config();

// CRITICAL FIX: Force IPv4 globally for this Node process
// This bypasses a severe WSL/Node.js bug where smtp.gmail.com resolves to IPv6 
// and drops all outbound packets, causing endless "Connection timeout" errors.
if (dns.setDefaultResultOrder) {
  dns.setDefaultResultOrder('ipv4first');
}

// We do NOT use pool: true anymore. 
// We create a fresh connection per email, but they are sent SEQUENTIALLY from the controller.
const transporter = nodemailer.createTransport({
  host: 'smtp.gmail.com',
  port: 465,
  secure: true,
  auth: {
    user: process.env.EMAIL_USER, 
    pass: process.env.EMAIL_PASS, 
  },
  tls: {
    // Avoid SSL failures in certain local network environments
    rejectUnauthorized: false
  }
});

const sendEmail = async (options) => {
  const mailOptions = {
    from: `"${EMAIL.FROM_NAME}" <${process.env.EMAIL_USER}>`,
    to: options.email, 
    subject: options.subject, 
    text: options.message, 
    html: options.html,
  };
 
  await transporter.sendMail(mailOptions);
};

module.exports = sendEmail;