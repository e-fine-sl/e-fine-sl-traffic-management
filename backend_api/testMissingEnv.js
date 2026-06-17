const nodemailer = require('nodemailer');
const t = nodemailer.createTransport({
  host: 'smtp.gmail.com',
  port: 465,
  secure: true,
  auth: {
    user: undefined,
    pass: undefined
  }
});
t.sendMail({from: 'a@a.com', to: 'b@b.com', subject: 'A', text: 'A'})
  .then(() => console.log('OK'))
  .catch(err => {
    console.error('Error name:', err.name);
    console.error('Error message:', err.message);
    process.exit(1);
  });
