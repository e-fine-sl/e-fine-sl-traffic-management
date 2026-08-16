// config/db.js
const mongoose = require('mongoose');

// Connect to the official e-Fine SL traffic management database
const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGO_URI, {
      dbName: process.env.MONGO_DB_NAME || 'efine_sl_db'
    });

    console.log(`[MongoDB] Connected: ${conn.connection.host}`);
    console.log(`[MongoDB] Active Database: ${conn.connection.name}`);

  } catch (error) {
    console.error(`[MongoDB] Connection Error: ${error.message}`);
    process.exit(1);
  }
};

module.exports = connectDB;