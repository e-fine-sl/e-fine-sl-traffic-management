require('dotenv').config();
const nodemailer = require('nodemailer');
const t = nodemailer.createTransport({
  host: 'smtp.gmail.com',
  port: 587,
  secure: false,
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS
  }
});
t.sendMail({
  from: process.env.EMAIL_USER,
  to: process.env.EMAIL_USER,
  subject: 'Port 587 Test',
  text: '587'
}).then(() => {
  console.log('587 OK');
  process.exit(0);
}).catch(err => {
  console.error(err);
  process.exit(1);
});
