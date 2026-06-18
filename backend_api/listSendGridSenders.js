require('dotenv').config();
const https = require('https');

const options = {
  hostname: 'api.sendgrid.com',
  path: '/v3/verified_senders',
  method: 'GET',
  headers: {
    'Authorization': `Bearer ${process.env.SENDGRID_API_KEY}`,
    'Content-Type': 'application/json'
  }
};

const req = https.request(options, (res) => {
  let data = '';
  res.on('data', (chunk) => { data += chunk; });
  res.on('end', () => {
    const parsed = JSON.parse(data);
    if (parsed.results && parsed.results.length > 0) {
      console.log('\n✅ Verified Senders:');
      parsed.results.forEach((s, i) => {
        console.log(`  ${i+1}. From Email: "${s.from_email}"  Verified: ${s.verified}`);
      });
    } else {
      console.log('No verified senders found:', JSON.stringify(parsed, null, 2));
    }
    process.exit(0);
  });
});

req.on('error', (err) => {
  console.error('Request error:', err.message);
  process.exit(1);
});

req.end();
