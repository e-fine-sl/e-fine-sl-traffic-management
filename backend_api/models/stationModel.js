const mongoose = require('mongoose');

const stationSchema = mongoose.Schema(
  {
    stationCode: {
      type: String,
      required: true,
      unique: true, 
      
    },
    name: {
      type: String,
      required: true, 
    },
    district: {
      type: String,
      required: true,
    },
    province: {
      type: String,
      required: false,
    },
    officialEmail: {
      type: String,
      required: true, 
    },
    location: {
      type: {
        type: String,
        enum: ['Point'],
        required: false
      },
      coordinates: {
        type: [Number],
        required: false
      }
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model('Station', stationSchema);