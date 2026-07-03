fetch('https://e-fine-sl-traffic-management-1.onrender.com/api/auth/verify-dmt', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    nic: '200107101016',
    licenseNumber: 'B5395114'
  })
}).then(res => res.json()).then(console.log).catch(console.error);
