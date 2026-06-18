require('dotenv').config();
const sendEmail = require('./utils/sendEmail');

async function test() {
  console.log('Testing SendGrid email delivery...');
  console.log('SENDGRID_API_KEY set:', !!process.env.SENDGRID_API_KEY);
  console.log('From email:', process.env.EMAIL_USER);

  try {
    await sendEmail({
      email: process.env.EMAIL_USER,
      subject: '✅ SendGrid Test — e-Fine SL',
      html: '<h2>SendGrid is working!</h2><p>This email was sent via SendGrid API from Render.com.</p>'
    });
    console.log('✅ SUCCESS: Email sent via SendGrid!');
    process.exit(0);
  } catch (err) {
    console.error('❌ FAILED:', err?.response?.body || err.message);
    process.exit(1);
  }
}

test();
