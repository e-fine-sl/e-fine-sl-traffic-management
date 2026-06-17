require('dotenv').config();
const sendEmail = require('./utils/sendEmail');

async function test() {
  try {
    console.log('Attempting to send test email...');
    await sendEmail({
      email: process.env.EMAIL_USER, // send to self
      subject: 'Test Email SMTP Connection',
      message: 'This is a test to verify SMTP connection over port 465.',
      html: '<p>This is a test to verify SMTP connection over port 465.</p>'
    });
    console.log('✅ Test email sent successfully!');
  } catch (err) {
    console.error('❌ Failed to send email:', err);
  }
}

test();
