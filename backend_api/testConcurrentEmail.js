require('dotenv').config();
const sendEmail = require('./utils/sendEmail');

async function test() {
  try {
    console.log('Sending 3 emails concurrently...');
    await Promise.allSettled([
      sendEmail({ email: process.env.EMAIL_USER, subject: 'T1', text: 'T1' }),
      sendEmail({ email: process.env.EMAIL_USER, subject: 'T2', text: 'T2' }),
      sendEmail({ email: process.env.EMAIL_USER, subject: 'T3', text: 'T3' })
    ]).then(results => {
      results.forEach((r, i) => {
        if (r.status === 'fulfilled') console.log(`Email ${i+1}: Success`);
        else console.log(`Email ${i+1}: Failed - ${r.reason.message}`);
      });
    });
  } catch (err) {
    console.error('Error:', err);
  }
}

test();
