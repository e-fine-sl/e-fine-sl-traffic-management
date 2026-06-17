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

// Enable geospatial queries (e.g. find stations within 10km of an accident)
stationSchema.index({ location: '2dsphere' });

module.exports = mongoose.model('Station', stationSchema);