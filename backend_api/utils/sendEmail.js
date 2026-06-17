const nodemailer = require('nodemailer');
const { EMAIL } = require('../config/constants');
require('dotenv').config();

// Create a single global transport pool so we don't spam Gmail with simultaneous AUTH requests
const transporter = nodemailer.createTransport({
  host: 'smtp.gmail.com',
  port: 465,
  secure: true,
  pool: true, // Re-use the same connection for multiple emails
  maxConnections: 3, // Prevent opening too many simultaneous sockets
  auth: {
    user: process.env.EMAIL_USER, 
    pass: process.env.EMAIL_PASS, 
  },
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