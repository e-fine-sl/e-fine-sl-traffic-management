const nodemailer = require('nodemailer');
const { EMAIL } = require('../config/constants');

const sendEmail = async (options) => {

  const transporter = nodemailer.createTransport({
    host: 'smtp.gmail.com',
    port: 465,
    secure: true,
    auth: {
      user: process.env.EMAIL_USER, 
      pass: process.env.EMAIL_PASS, 
    },
  });

 
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