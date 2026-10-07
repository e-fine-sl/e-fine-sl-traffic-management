const mongoose = require('mongoose');
require('dotenv').config();
const Driver = require('./models/driverModel');

mongoose.connect(process.env.MONGO_URI, { useNewUrlParser: true, useUnifiedTopology: true })
  .then(async () => {
    const drivers = await Driver.find().select('name email nic licenseNumber');
    console.log(JSON.stringify(drivers, null, 2));
    process.exit(0);
  })
  .catch(err => {
    console.error(err);
    process.exit(1);
  });
